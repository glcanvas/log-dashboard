#!/usr/bin/env bash

# set up clickhouse configs
rm -rf clickhouse01 clickhouse02 clickhouse03 clickhouse04
mkdir -p clickhouse01 clickhouse02 clickhouse03 clickhouse04
REPLICA=01 SHARD=01 envsubst < config.xml > clickhouse01/config.xml
REPLICA=02 SHARD=01 envsubst < config.xml > clickhouse02/config.xml
REPLICA=03 SHARD=02 envsubst < config.xml > clickhouse03/config.xml
REPLICA=04 SHARD=02 envsubst < config.xml > clickhouse04/config.xml
cp users.xml clickhouse01/users.xml
cp users.xml clickhouse02/users.xml
cp users.xml clickhouse03/users.xml
cp users.xml clickhouse04/users.xml

# build image for generator dependencies
cd generator-env
docker build -t klntsky/generator-env:1.0 .
cd ..

# build image with generater based on dependencies image
docker build -t klntsky/generator:1.0 .
docker-compose up
