#!/bin/sh
mv config/config.exs config/config.exs.bak
cp config/config.prod.exs config/config.exs
docker build -f Dockerfile-ubuntu -t round1_ubuntu:elli -t stor.highloadcup.ru/travels/known_guest:elli --build-arg bust="`date`" --rm=false .
# docker build -f Dockerfile-ubuntu -t round1_ubuntu -t stor.highloadcup.ru/travels/known_guest:elli --build-arg bust="`date`" .
mv config/config.exs.bak config/config.exs
