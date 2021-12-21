### Intro

Given a web platform for online sales.
Users may visit and view different pages on the platform’s website and perform various operations,
mainly: reserving, buying, refunding, canceling reservations.
The platform is implemented as a fleet of micro services and to perform financial transactions may communicate
with external services depending on the user’s prefered way and provider to make payment.
Multiple micro-services participate in processing every operation thus it is guaranteed that each has a unique
ID associated with it, staying preserved across all microservices.
Users may make mistakes when they reserve or buy, external services may be temporarily unavailable or overloaded to
process payment requests.
The platform’s software and the external services also may contain bugs that lead to various errors.
This fleet constantly  generates logs, metrics and database records.
The business wants these logs and metrics to be collected to calculate various statistics and to check for performance problems, errors and anomalies.


### Docker

We use docker-compose to deploy the network simulation and services. Everything is put in a single network.

Containers we use: `zookeeper`, `kafka`, `kafka-ui` (to inspect messages in live mode via a web interface), `clickhouse` (4 instances), `generator` (see below), `grafana` and `pyspark`.

Everything is built using `./build.sh` script. It should be enough to call it, assuming `docker-compose` is installed.

For generator, we build two images: one that contains all its haskell dependencies and another that builds the source code. This is done to not lose build artifacts that can be reused.

### Generator


### Kafka

Kafka is used to transfer data from generator to spark and from it to clickhouse.

Generator binary writes everything to a single topic, and then this data is split into topics corresponding to particular ClickHouse tables.

## Clickhouse

There are 5 tables containing various types of events happening in the system.

## request_trace

Traces everything that is happening.

## user_trace

Traces every event related to users.

## online_user

Traces users becoming active (online) on site.

## failed_login

Traces login failures (login responses with failing status)

## users\_spend\_time\_online

Traces how much time is spent between login and logout on the site.

`clickhouse-client` docker container creates the database schema, which includes distributed (and replicated) tables, kafka tables and materialized views to transfer the data from kafka to distributed ones.

### Spark
We use spark to process all incoming amount of data.
All incoming data processes by Spark streams, storages and then pushes to Kafka topic.
To fetch logs we use Kafka, Spark subscribes to Kafka topic, reads from it and load into RDD streams.

List of implemented operations:
* Trace by request id
* Trace by user id
* Count user online
* User login failure
* Spend time on site by user
* Count viewing by product
* Count viewing by product and user

### Grafana
We use Grafana with Kafka and Clickhouse for UI and analytics.
Grafana is also launched by the Docker and use preconfigured provisioning settings.
