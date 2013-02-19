async   = require("async")
coffee  = require("coffee-script")
domain  = require("domain")
express = require("express")
log     = require("./lib/logger").init("pb.app")
net     = require("net")
redis   = require("redis-url").connect(process.env.OPENREDIS_URL)
redisps = require("redis-url").connect(process.env.OPENREDIS_URL)
spawn   = require("child_process").spawn
uuid    = require("node-uuid")

delay = (ms, cb) -> setTimeout  cb, ms
every = (ms, cb) -> setInterval cb, ms

socket = "/tmp/thin.#{uuid.v4()}.sock"

server = spawn "bundle", ["exec", "thin", "start", "-S", socket], stdio:"inherit"

clients = {}

redisps.on "message", (channel, data) ->
  if match = /^pb.connection.([0-9a-f-]+).out.data/.exec(channel)
    clients[match[1]].write new Buffer(data, "base64").toString("binary"), "binary"
  else if match = /^pb.connection.([0-9a-f-]+).out.end/.exec(channel)
    clients[match[1]].end()

wait_for_connection = ->
  log.start "response", (log) ->
    redis.blpop "pb.connections", 0, (err, connection) ->
      id = connection[1]
      redisps.subscribe "pb.connection.#{id}.out.data"
      redisps.subscribe "pb.connection.#{id}.out.end"
      redis.publish "pb.ack", id
      client = net.createConnection socket, ->
        clients[id] = client
      client.on "data", (data) ->
        log.write_status "data.success", id:id, length:data.length
        redis.publish "pb.connection.#{id}.in.data", new Buffer(data, "binary").toString("base64")
      client.on "end", ->
        log.write_status "end.success", id:id
        redis.publish "pb.connection.#{id}.in.end", "end"
        wait_for_connection()
      client.on "error", (err) ->
        console.log "cc.err", err
      log.success id:id

log.start "start", (log) ->
  pulse = every 100, ->
    tester = net.createConnection socket, ->
      clearInterval pulse
      tester.end()
      log.success()
      wait_for_connection()

    tester.on "error", (err) ->
      # not connected yet, keep trying
