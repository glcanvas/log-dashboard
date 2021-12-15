from pyspark import SparkContext, StorageLevel
from pyspark.streaming import StreamingContext, DStream
import tempfile
import os
import threading
import shutil
import json
from typing import Callable
import time


def print_rdd(rdd):
    rdd = rdd.take(100)
    for i in rdd:
        print(i)


def debug(f):
    def prt(*args):
        print(args)
        return f(*args)

    return prt


INITIAL_STATE = "initialState"
UNKNOWN = "unknownCommand"
LOGIN_INITIAL_REQUEST = "initialRequest"
LOGIN_DB_REQUEST = "dbRequest"
LOGIN_DB_RESPONSE = "dbResponse"
LOGOUT_REQUEST = "logoutRequest"


def map_login_logs_to_state(kv):
    key = kv[0]
    value = kv[1]
    if value['action'] == "LoginReq":
        return key, (LOGIN_INITIAL_REQUEST, 0, True)
    if value['action'] == "LoginDbReq":
        return key, (LOGIN_DB_REQUEST, 1, True)
    if value['action'] == "LoginRep":
        return key, (LOGIN_DB_RESPONSE, 2, value['data']['status'] == "Valid")
    if value['action'] == "LogoutReq":
        return key, (LOGOUT_REQUEST, 3, True)
    return key, (UNKNOWN, 4, False)


def register_login_next_state(new_values, old_state):
    if old_state is None:
        return new_values[0]
    for n_v in new_values:
        if old_state[1] + 1 == n_v[1]:
            old_state = n_v
        else:
            return UNKNOWN, 4, False
        if old_state[1] == 2:
            if not old_state[2]:
                return None
        if old_state[1] == 3:
            return None
    return old_state


def count_online_users(login_stream: DStream):
    login_stream.map((lambda x: (x['commonData']['userId']['userId'], x))) \
        .map(map_login_logs_to_state) \
        .map(lambda kv: (kv[0], [i for i in kv[1]])) \
        .filter(lambda kv: len(kv[1]) > 0) \
        .updateStateByKey(lambda new_value, old_state: register_login_next_state(new_value, old_state)) \
        .filter(lambda kv: kv[1][0] == LOGIN_DB_RESPONSE) \
        .count() \
        .foreachRDD(print_rdd)


def initialize_spark(master, input_builder: Callable[[StreamingContext], DStream], terminations=None, app_name=None):
    sc = SparkContext(master, app_name)
    acc = sc.accumulator(0)
    ssc = StreamingContext(sc, 1)
    ssc.checkpoint("/Users/nduginets/PycharmProjects/log-dashboard/checkpoints")
    stream = input_builder(ssc)

    json_stream = stream.map(json.loads)
    login_stream = json_stream.filter(lambda x: x["commonData"]["serverName"] == "Login")
    count_online_users(login_stream)
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
