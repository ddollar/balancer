# balancer

Unicorn-style proxy in front of multiple app servers. Currently only works with `thin`.

## Installation

Copy these files into your app. Make sure your have an `OPENREDIS_URL`.

## How it Works

`balancer` adds a proxy that will listen as your new `web` process. Your app will be started as multiple `app` processes.

    === app: `vendor/balancer/bin/app -n 1 -c 'bundle exec thin start --socket %socket%'`
    app.1: up 2013/02/19 13:19:23 (~ 3h ago)
    app.2: up 2013/02/19 13:19:23 (~ 3h ago)
    app.3: up 2013/02/19 13:19:23 (~ 3h ago)
    app.4: up 2013/02/19 13:19:22 (~ 3h ago)
    app.5: up 2013/02/19 13:19:27 (~ 3h ago)

    === web: `vendor/balancer/bin/web`
    web.1: up 2013/02/19 13:19:04 (~ 3h ago)

You can scale `web` and `app` independently.

## Usage

Change the `web` entry in your Procfile and add an `app` entry:

    web: vendor/balancer/bin/web
    app: vendor/balancer/bin/app

## License

MIT
