SELECT cluster, shard_num, host_name, host_address, port, is_local FROM system.clusters;

drop database if exists db on cluster webshop;
CREATE DATABASE db ON CLUSTER webshop;

-- request_trace

CREATE TABLE IF NOT EXISTS db.request_trace ON CLUSTER webshop
(
    request_id Int64,
    time DateTime,
    log String
)
ENGINE = MergeTree()
PARTITION BY toYear(time)
ORDER BY (time);

CREATE TABLE db.distr_request_trace
ON CLUSTER webshop AS db.request_trace
  ENGINE = Distributed(webshop, db, request_trace, xxHash64(request_id));

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

-- user_trace

CREATE TABLE IF NOT EXISTS db.user_trace ON CLUSTER webshop
(
    user_id Int64,
    time DateTime,
    log String
)
ENGINE = MergeTree()
PARTITION BY toYear(time)
ORDER BY (time);

CREATE TABLE db.distr_user_trace
ON CLUSTER webshop AS db.user_trace
  ENGINE = Distributed(webshop, db, user_trace, xxHash64(user_id));

CREATE TABLE db.distr_user_trace_kafka AS db.distr_user_trace
ENGINE = Kafka()
SETTINGS
  kafka_broker_list = 'kafka:9092,kafka:9094',
  kafka_topic_list = 'user_trace',
  kafka_group_name = 'main',
  kafka_format = 'JSONEachRow',
  kafka_max_block_size = 1000;

CREATE MATERIALIZED VIEW
  db.distr_user_trace_kafka_consumer
TO db.distr_user_trace
AS SELECT *
FROM db.distr_user_trace_kafka;

-- online_user

CREATE TABLE IF NOT EXISTS db.online_user ON CLUSTER webshop
(
    user_id Int64,
    time DateTime
)
ENGINE = MergeTree()
PARTITION BY toYear(time)
ORDER BY (time);

CREATE TABLE db.distr_online_user
ON CLUSTER webshop AS db.online_user
  ENGINE = Distributed(webshop, db, online_user, xxHash64(user_id));


-- To test run:

-- SELECT * FROM db.distr_online_user LIMIT 10;

CREATE TABLE db.distr_online_user_kafka AS db.distr_online_user
ENGINE = Kafka()
SETTINGS
  kafka_broker_list = 'kafka:9092,kafka:9094',
  kafka_topic_list = 'online_user',
  kafka_group_name = 'main',
  kafka_format = 'JSONEachRow',
  kafka_max_block_size = 1000;

CREATE MATERIALIZED VIEW
  db.distr_online_user_kafka_consumer
TO db.distr_online_user
AS SELECT *
FROM db.distr_online_user_kafka;

-- failed_login

CREATE TABLE IF NOT EXISTS db.failed_login ON CLUSTER webshop
(
    user_id Int64,
    time DateTime
)
ENGINE = MergeTree()
PARTITION BY toYear(time)
ORDER BY (time);

CREATE TABLE db.distr_failed_login
ON CLUSTER webshop AS db.failed_login
  ENGINE = Distributed(webshop, db, failed_login, xxHash64(user_id));

CREATE TABLE db.distr_failed_login_kafka AS db.distr_failed_login
ENGINE = Kafka()
SETTINGS
  kafka_broker_list = 'kafka:9092,kafka:9094',
  kafka_topic_list = 'failed_login',
  kafka_group_name = 'main',
  kafka_format = 'JSONEachRow',
  kafka_max_block_size = 1000;

CREATE MATERIALIZED VIEW
  db.distr_failed_login_kafka_consumer
TO db.distr_failed_login
AS SELECT *
FROM db.distr_failed_login_kafka;

-- users_spend_time_online

CREATE TABLE IF NOT EXISTS db.users_spend_time_online ON CLUSTER webshop
(
    user_id Int64,
    time DateTime,
    spent Int64
)
ENGINE = MergeTree()
PARTITION BY toYear(time)
ORDER BY (time);

CREATE TABLE db.distr_users_spend_time_online
ON CLUSTER webshop AS db.users_spend_time_online
  ENGINE = Distributed(webshop, db, users_spend_time_online, xxHash64(user_id));

CREATE TABLE db.distr_users_spend_time_online_kafka AS db.distr_users_spend_time_online
ENGINE = Kafka()
SETTINGS
  kafka_broker_list = 'kafka:9092,kafka:9094',
  kafka_topic_list = 'users_spend_time_online',
  kafka_group_name = 'main',
  kafka_format = 'JSONEachRow',
  kafka_max_block_size = 1000;

CREATE MATERIALIZED VIEW
  db.distr_users_spend_time_online_kafka_consumer
TO db.distr_users_spend_time_online
AS SELECT *
FROM db.distr_users_spend_time_online_kafka;


-- this table moves logs directly. we don't use it. we inserted spark between logs and our CH tables.

-- CREATE TABLE IF NOT EXISTS db.gen_logs ON CLUSTER webshop
-- (
--         action String
-- )
-- ENGINE = MergeTree()
-- PARTITION BY action
-- ORDER BY (action);

-- CREATE TABLE db.distr_gen_logs
-- ON CLUSTER webshop AS db.gen_logs
--   ENGINE = Distributed(webshop, db, gen_logs, xxHash64(action));

-- CREATE TABLE db.distr_gen_logs_kafka AS db.distr_gen_logs
-- ENGINE = Kafka()
-- SETTINGS
--   kafka_broker_list = 'kafka:9092,kafka:9094',
--   kafka_topic_list = 'gen-logs',
--   kafka_group_name = 'main',
--   kafka_format = 'JSONEachRow',
--   kafka_max_block_size = 1000;

-- CREATE MATERIALIZED VIEW
--   db.distr_gen_logs_kafka_consumer
-- TO db.distr_gen_logs
-- AS SELECT *
-- FROM db.distr_gen_logs_kafka;


-- SELECT * FROM db.distr_gen_logs;

-- Use this to test kafka:
-- it will allow running SELECT on kafka streams as tables

-- SET stream_like_engine_allow_direct_select = true;

-- DEMO:
-- SELECT * FROM db.distr_online_user LIMIT 10;
-- SELECT * FROM db.distr_user_trace LIMIT 10;
-- SELECT * FROM db.distr_request_trace LIMIT 10;
-- SELECT * FROM db.distr_users_spend_time_online LIMIT 10;
-- SELECT * FROM db.distr_failed_login LIMIT 10;
