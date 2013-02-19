async   = require("async")
coffee  = require("coffee-script")
domain  = require("domain")
express = require("express")
log     = require("./lib/logger").init("pb.web")
net     = require("net")
redis   = require("redis-url").connect(process.env.OPENREDIS_URL)
redisps = require("redis-url").connect(process.env.OPENREDIS_URL)
uuid    = require("node-uuid")

delay = (ms, cb) -> setTimeout  cb, ms
every = (ms, cb) -> setInterval cb, ms

connections = {}
buffers = {}

port = (process.env.PORT or 5000)

class Connection

  constructor: (@connection) ->
    @id     = uuid.v4()
    @buffer = ""
    @ended  = false
    @acked  = false
    @domain = domain.create()
    @domain.on "error", (err) ->
      console.log "connection.error", err
      @connection.end()
    @connection.on "data", (data) => @data data
    @connection.on "end",         => @end()
    @setup_redis()

  ack: ->
    unless @acked
      @acked = true
      if @buffer.length > 0
        @publish "data", @buffer, (err) -> #console.log "ack.buffer"
      if @ended
        @publish "end", "end", (err) -> #console.log "ack.end"

  publish: (type, data, cb) ->
    redis.publish "pb.connection.#{@id}.out.#{type}", (new Buffer(data, "binary").toString("base64")), @domain.intercept(cb)

  data: (data) ->
    log.start "request.data", (log) =>
      console.log "data", data.toString(), @acked
      if @acked
        @publish "data", data, (err) => log.success id:@id, length:data.length
      else
        @buffer += data
        log.success id:@id

  end: ->
    log.start "request.end", (log) =>
      if @acked
        @publish "end", "end", (err) => log.success id:@id
      else
        @ended = true
        log.success id:@id

  write: (data) ->
    @connection.write data, "binary"

  close: ->
    @connection.end()

  setup_redis: ->
    redisps.subscribe "pb.connection.#{@id}.in.data"
    redisps.subscribe "pb.connection.#{@id}.in.end"
    log.start "request", (log) =>
      redis.lpush "pb.connections", @id, @domain.intercept (err) =>
        log.success id:@id


redis.flushdb ->

  redisps.subscribe "pb.ack"

  redisps.on "message", (channel, data) ->
    if channel is "pb.ack"
      connection = connections[data]
      connection.ack()
    else if match = /^pb.connection.([0-9a-f-]+).in.data/.exec(channel)
      connections[match[1]].write new Buffer(data, "base64").toString("binary"), "binary"
    else if match = /^pb.connection.([0-9a-f-]+).in.end/.exec(channel)
      connections[match[1]].close()

  server = net.createServer (conn) ->
    connection = new Connection(conn)
    connections[connection.id] = connection

  log.start "listen", port:port, (log) ->
    server.listen port, ->
      log.success()
