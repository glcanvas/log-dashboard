SELECT cluster, shard_num, host_name, host_address, port, is_local FROM system.clusters;

CREATE DATABASE db ON CLUSTER webshop;

CREATE TABLE IF NOT EXISTS db.request_trace ON CLUSTER webshop
(
    trace_id Int64,
    time DateTime,
    log String
)
ENGINE = MergeTree()
PARTITION BY toYear(time)
ORDER BY (time);

CREATE TABLE db.distr_request_trace
ON CLUSTER webshop AS db.request_trace
  ENGINE = Distributed(webshop, db, request_trace, xxHash64(trace_id));

CREATE TABLE db.distr_request_trace_kafka AS db.distr_request_trace
ENGINE = Kafka()
SETTINGS
  kafka_broker_list = 'kafka:9092,kafka:9094',
  kafka_topic_list = 'request_trace',
  kafka_group_name = 'main',
  kafka_format = 'JSONEachRow',
  kafka_max_block_size = 1000;


CREATE MATERIALIZED VIEW
  db.distr_request_trace_kafka_consumer
TO db.distr_request_trace
AS SELECT *
FROM db.distr_request_trace_kafka;

-- { trace_id: 123, time: "2018-07-10T12:30:18.749Z", log: "bruh" }

-- TMP: actions. TODO: remove, or it will eat messages instead of spark!


CREATE TABLE IF NOT EXISTS db.gen_logs ON CLUSTER webshop
(
        action String
)
ENGINE = MergeTree()
PARTITION BY action
ORDER BY (action);

CREATE TABLE db.distr_gen_logs
ON CLUSTER webshop AS db.gen_logs
  ENGINE = Distributed(webshop, db, gen_logs, xxHash64(action));

CREATE TABLE db.distr_gen_logs_kafka AS db.distr_gen_logs
ENGINE = Kafka()
SETTINGS
  kafka_broker_list = 'kafka:9092,kafka:9094',
  kafka_topic_list = 'gen-logs',
  kafka_group_name = 'main',
  kafka_format = 'JSONEachRow',
  kafka_max_block_size = 1000;

CREATE MATERIALIZED VIEW
  db.distr_gen_logs_kafka_consumer
TO db.distr_gen_logs
AS SELECT *
FROM db.distr_gen_logs_kafka;

SET stream_like_engine_allow_direct_select = true;

SELECT * FROM db.distr_gen_logs;
