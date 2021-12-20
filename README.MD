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

### Generator


### Kafka

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
