# Round1

This is a solution for [highloadcup.ru](http://highloadcup.ru).

## Technology

I am using [Elixir](https://elixir-lang.ru). Not actually using there Elixir-specific stuff, so you could say it's just [Erlang](https://www.erlang.org/).

Data is stored in `ets`, there's some data redundancy to avoid `:ets.select`s, which are too slow. No extra caching or any hardcore optimizations.

[cowboy](https://github.com/ninenines/cowboy) is doing all the serving, being helped by [Plug](https://hexdocs.pm/plug/readme.html); JSON is done with [jiffy](https://github.com/davisp/jiffy).

## Building image

Alpine

    % docker build -f Dockerfile-alpine -t round1_alpine --build-arg bust="`date`" .

Ubuntu, you guessed right

    % docker build -f Dockerfile-ubuntu -t round1_ubuntu --build-arg bust="`date`" .

`bust` argument is for bumping image, you can safely omit it if code actually changed.

## Running image

First checkout the [repo](https://github.com/sat2707/hlcupdocs), go to `TRAIN` or `FULL` data (i.e., `hlcupdocs/data/TRAIN/data`) and create an archive

    % zip data *json

Then you are set to go

    % docker run -p 8080:80 -v /path/to/hlcupdocs/data/TRAIN/data/:/tmp/data/ -t round1_alpine

Replace path and tag with appropriate values.

## Caveats

Alpine image doesn't work at [highloadcup.ru](http://highloadcup.ru).
