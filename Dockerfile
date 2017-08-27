FROM alpine:edge as builder

RUN apk update

RUN apk add -uUv erlang erlang-asn1 erlang-crypto erlang-dialyzer \
        erlang-public-key erlang-sasl erlang-ssl erlang-tools erlang-dev \
        erlang-inets erlang-syntax-tools erlang-eunit erlang-runtime-tools \
        erlang-parsetools bash elixir

ADD . /root/round1

WORKDIR /root/round1

ENV MIX_ENV=prod

RUN mix do local.hex --force, local.rebar --force
RUN mix deps.clean --all
RUN mix do deps.get, deps.compile, release.clean, release

FROM alpine:edge
WORKDIR /root/round1

RUN apk add -uUv bash

EXPOSE 80

COPY --from=builder /root/round1/_build/prod/rel/round1/releases/0.1.0/round1.tar.gz /root/round1

RUN tar -xzf round1.tar.gz;rm round1.tar.gz

CMD mkdir /tmp/123 && cd /tmp/123 && unzip /tmp/data/data.zip && /root/round1/bin/round1 foreground
