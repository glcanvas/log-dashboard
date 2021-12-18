from pyspark import SparkContext, StorageLevel
from pyspark.streaming import StreamingContext, DStream
import tempfile
import os
import threading
import shutil
import json
from typing import Callable
import time
from dateutil import parser


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

CATALOG_REQUEST = "CatalogReq"
CATALOG_DB_REQUEST = "CatalogDbReq"
CATALOG_DB_RESPONSE = "CatalogDbRep"


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
        .foreachRDD(print_rdd)


def users_spend_time_online(login_stream: DStream):
    log_in = login_stream \
        .updateStateByKey(lambda new_value, old_state: users_login_correctly_state(new_value, old_state))

    log_out = login_stream \
        .updateStateByKey(lambda new_value, old_state: users_logout_state(new_value, old_state))

    log_in.join(log_out).map(lambda kv: (kv[0], abs(kv[1][0][3] - kv[1][1][3]))).foreachRDD(print_rdd)


def fail_login(login_stream: DStream):
    login_stream \
        .filter(lambda kv: kv[1][0] == LOGIN_DB_RESPONSE and kv[1][2] is False) \
        .groupByKeyAndWindow(30, 1) \
        .map(lambda kv: (kv[0], len([i for i in kv[1]]))) \
        .filter(lambda kv: kv[1] > 3) \
        .foreachRDD(print_rdd)


def catalog_main_page(catalog_stream: DStream):
    pass


def initialize_spark(master, input_builder: Callable[[StreamingContext], DStream], terminations=None, app_name=None):
    sc = SparkContext(master, app_name)
    ssc = StreamingContext(sc, 1)
    ssc.checkpoint("/Users/nduginets/PycharmProjects/log-dashboard/checkpoints")
    stream = input_builder(ssc)

    raw_stream = stream.map(try_to_parse)
    json_stream = raw_stream.filter(lambda x: x[0]).map(lambda x: x[1])

    # stream to report of incorrect messages
    incorrect_data_stream = raw_stream.filter(lambda x: not x[0]).map(lambda x: x[1]).foreachRDD(print_rdd)

    # streams of online users, and failures
    login_stream = json_stream.filter(lambda x: x["commonData"]["serverName"] == "Login") \
        .map((lambda x: (x['commonData']['userId']['userId'], x))) \
        .map(map_login_logs_to_state) \
        .map(lambda kv: (kv[0], [i for i in kv[1]])) \
        .filter(lambda kv: len(kv[1]) > 0)
    count_online_users(login_stream)
    fail_login(login_stream)
    users_spend_time_online(login_stream)
    # todo add view time

    catalog_stream = json_stream.filter(lambda x: x["commonData"]["serverName"] == "Catalog") \
        .map((lambda x: (x['commonData']['userId']['userId'], x))) \
        .map(map_catalog_logs_to_state)

    # catalog_stream = json_stream.filter(lambda x: x["commonData"]["serverName"] == "Catalog")

    # login_stream.foreachRDD(terminations['login'])
    # catalog_stream.foreachRDD(print_rdd)

    ssc.start()

    return ssc


if __name__ == "__main__":
    # Create a local StreamingContext with two working thread and batch interval of 1 second
    env_dir = tempfile.mkdtemp()

    spark = initialize_spark("local[2]", lambda context: context.textFileStream("file:" + env_dir), {
        "login": print_rdd
    }, "log-dashboard-spark")

    with open("/Users/nduginets/PycharmProjects/log-dashboard/test/correct_login_test.txt", "r") as f:
        lines = f.readlines()

    for idx, l in enumerate(lines):
        test_file = os.path.join(env_dir, "{}_test.txt".format(idx))
        with open(test_file, "w") as w:
            w.write(l)
        time.sleep(1)

    print("finish write  to file")

    spark.awaitTermination(10)
    shutil.rmtree(env_dir)
