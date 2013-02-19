# balancer

Unicorn-style proxy in front of multiple app servers. Currently only works with `thin`.

## Installation

Copy these files into your app. Make sure your have an `OPENREDIS_URL`.

## Usage

Change the `web` entry in your Procfile and add an `app` entry:

    web: vendor/balancer/bin/web
    app: vendor/balancer/bin/app

The `app` process type now acts like your old `web` process type. Scale it to get more copies of your app.

The `web` process can be scaled individually, but probably won't nmeed it.

## License

MIT
