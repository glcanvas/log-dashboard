from pyspark import SparkContext
from pyspark.streaming import StreamingContext, DStream
import json
from typing import Callable
from dateutil import parser
import datetime
import os
from json import dumps
from kafka import KafkaProducer, KafkaConsumer

from pyspark.streaming.kafka import KafkaUtils


def dump_to_kafka(producer: KafkaProducer):
    def inner(rdd):
        items = []
        for (k, v) in rdd.collect():
            items.append(producer.send("spark-output", {"key": k, "value": v}))
        for i in items:
            i.get()

    return inner


def print_rdd(rdd):
    rdd = rdd.take(100)
    for i in rdd:
        print(i)


def debug(f):
    def prt(*args):
        print(args)
        return f(*args)

    return prt


UNKNOWN = "unknownCommand"
INITIAL_STATE = "initialState"

LOGIN_INITIAL_REQUEST = "initialRequest"
LOGIN_DB_REQUEST = "dbRequest"
LOGIN_DB_RESPONSE = "dbResponse"
LOGOUT_REQUEST = "logoutRequest"

##################################################
##################################################
##################################################
CATALOG_REQUEST = "CatalogReq"
CATALOG_DB_REQUEST = "CatalogDbReq"
CATALOG_DB_RESPONSE = "CatalogDbRep"

CATALOG_PRODUCT_REQUEST = "CatalogProductReq"
CATALOG_PRODUCT_DB_REQUEST = "CatalogProductDbReq"
CATALOG_PRODUCT_DB_RESPONSE = "CatalogProductDbRep"

CATALOG_LINKED_PRODUCT_DB_REQUEST = "CatalogLinkedProductsDbReq"
CATALOG_LINKED_PRODUCT_DB_RESPONSE = "CatalogLinkedProductsDbRep"

##################################################
##################################################
##################################################

CART_REQUEST_ADD = "CartReqAdd"
CART_DB_REQUEST = "CartDbReq"
CART_DB_RESPONSE = "CartDbRep"

##################################################
##################################################
##################################################

def try_to_parse(l):
    try:
        return True, json.loads(l)
    except:
        return False, l


def map_login_logs_to_state(kv):
    key = kv[0]
    value = kv[1]
    time = parser.parse(value['commonData']['time']).timestamp()

    if value['action'] == "LoginReq":
        return key, (LOGIN_INITIAL_REQUEST, 0, True, time)
    if value['action'] == "LoginDbReq":
        return key, (LOGIN_DB_REQUEST, 1, True, time)
    if value['action'] == "LoginRep":
        return key, (LOGIN_DB_RESPONSE, 2, value['data']['status'] == "Valid", time)
    if value['action'] == "LogoutReq":
        return key, (LOGOUT_REQUEST, 3, True, time)
    return key, (UNKNOWN, 4, False, time)


def map_catalog_logs_to_state(kv):
    key = kv[0]
    value = kv[1]
    time = parser.parse(value['commonData']['time']).timestamp()
    if value['action'] == "CatalogReq":
        return key, (CATALOG_REQUEST, 0, True, time)
    if value['action'] == CATALOG_DB_REQUEST:
        return key, (CATALOG_DB_REQUEST, 1, True, time)
    if value['action'] == CATALOG_DB_RESPONSE:
        return key, (CATALOG_DB_RESPONSE, 2, [i['productId']['productId'] for i in value['data']['products']], time)
    return key, (UNKNOWN, 4, False, time)


def register_login_next_state(new_values, old_state):
    if old_state is None:
        return new_values[0]
    for n_v in new_values:
        if old_state[1] + 1 == n_v[1]:
            old_state = n_v
        else:
            return None
        if old_state[0] == LOGIN_DB_RESPONSE:
            if not old_state[2]:
                return None
        if old_state[0] == LOGOUT_REQUEST:
            return None
    return old_state


def users_login_correctly_state(new_values, old_state):
    if old_state is None:
        return new_values[0]
    for n_v in new_values:
        old_state = n_v
        if old_state[0] == LOGIN_DB_RESPONSE:
            if old_state[2]:
                return old_state
    return None


def users_logout_state(new_values, old_state):
    if old_state is None:
        return new_values[0]
    for n_v in new_values:
        old_state = n_v
        if old_state[0] == LOGOUT_REQUEST:
            return old_state
    return None


def count_online_users(login_stream: DStream):
    login_stream \
        .updateStateByKey(lambda new_value, old_state: register_login_next_state(new_value, old_state)) \
        .filter(lambda kv: kv[1][0] == LOGIN_DB_RESPONSE) \
        .count() \
        .map(lambda c: (datetime.datetime.now(), c)) \
        .foreachRDD(dump_to_kafka)


def users_spend_time_online(login_stream: DStream):
    log_in = login_stream \
        .updateStateByKey(lambda new_value, old_state: users_login_correctly_state(new_value, old_state))

    log_out = login_stream \
        .updateStateByKey(lambda new_value, old_state: users_logout_state(new_value, old_state))

    log_in.join(log_out).map(lambda kv: (kv[0], datetime.datetime.now(), abs(kv[1][0][3] - kv[1][1][3]))) \
        .foreachRDD(dump_to_kafka)


def fail_login(login_stream: DStream):
    login_stream \
        .filter(lambda kv: kv[1][0] == LOGIN_DB_RESPONSE and kv[1][2] is False) \
        .groupByKeyAndWindow(30, 1) \
        .map(lambda kv: (kv[0], datetime.datetime.now(), len([i for i in kv[1]]))) \
        .filter(lambda kv: kv[2] > 3) \
        .foreachRDD(dump_to_kafka)


def catalog_main_page_look_up_times(catalog_stream: DStream):
    catalog_stream \
        .updateStateByKey(lambda new_value, old_value: 1 if old_value is None else old_value + 1) \
        .map(lambda c: (datetime.datetime.now(), c)) \
        .foreachRDD(dump_to_kafka)


def cart_add(catalog_stream: DStream):
    catalog_stream \
        .updateStateByKey(lambda new_value, old_value: 1 if old_value is None else old_value + 1) \
        .map(lambda c: (datetime.datetime.now(), c)) \
        .foreachRDD(dump_to_kafka)


def trace_logs(json_stream: DStream):
    json_stream.map(
        lambda x: (x['commonData']['requestId']['requestId'], parser.parse(x['commonData']['time']).timestamp(), x)) \
        .foreachRDD(dump_to_kafka)


def trace_user(json_stream: DStream):
    json_stream.map(
        lambda x: (x['commonData']['userId']['userId'], parser.parse(x['commonData']['time']).timestamp(), x)) \
        .foreachRDD(dump_to_kafka)


def initialize_spark(master, input_builder: Callable[[StreamingContext], DStream], app_name, producer: KafkaProducer):
    sc = SparkContext(master, app_name)
    ssc = StreamingContext(sc, 1)
    ssc.checkpoint("checkpoints")
    stream = input_builder(ssc)

    raw_stream = stream.map(try_to_parse)
    json_stream = raw_stream.filter(lambda x: x[0]).map(lambda x: x[1])
    trace_logs(json_stream)
    trace_user(json_stream)

    # stream to report of incorrect messages
    raw_stream.filter(lambda x: not x[0]).map(lambda x: x[1]).foreachRDD(dump_to_kafka)

    # streams of online users, and failures
    login_stream = json_stream.filter(lambda x: x["commonData"]["serverName"] == "Login") \
        .map((lambda x: (x['commonData']['userId']['userId'], x))) \
        .map(map_login_logs_to_state) \
        .map(lambda kv: (kv[0], [i for i in kv[1]])) \
        .filter(lambda kv: len(kv[1]) > 0)
    count_online_users(login_stream)
    fail_login(login_stream)
    users_spend_time_online(login_stream)

    catalog_stream = json_stream.filter(lambda x: x["commonData"]["serverName"] == "Catalog") \
        .map((lambda x: (x['commonData']['userId']['userId'], x))) \
        .map(map_catalog_logs_to_state)

    catalog_main_page_look_up_times(catalog_stream)

    cart_stream = json_stream.filter(lambda x: x["commonData"]["serverName"] == "Cart") \
        .map((lambda x: (x['commonData']['userId']['userId'], x))) \
        .map(map_catalog_logs_to_state)

    catalog_main_page_look_up_times(cart_stream)

    ssc.start()

    return ssc


if __name__ == "__main__":
    kafka_paths = os.environ['KAFKA_PATH']
    spark_path = os.environ['SPARK_PATH']
    consumer = KafkaProducer(bootstrap_servers=kafka_paths.split(","),
                             value_serializer=lambda x: dumps(x).encode('utf-8'))

    builder = lambda context: KafkaUtils.createStream(context, kafka_paths, "logs", {"log-topic": 1})

    spark = initialize_spark(spark_path, builder, "log-dashboard-spark", consumer)

    spark.awaitTermination()
