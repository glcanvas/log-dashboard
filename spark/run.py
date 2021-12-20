#!/usr/bin/env python
# coding: utf-8

# Run ingestion

# In[1]:


import os
import json
import time
import socket
from pyspark import SparkConf, SparkContext, SQLContext
from pyspark.streaming import StreamingContext
from pyspark.sql import SparkSession
from pyspark.sql.functions import udf, length, when, col
from pyspark.sql.types import BooleanType, IntegerType, LongType, StringType, ArrayType, FloatType, StructType, StructField, DoubleType, TimestampType
import pyspark.sql.functions as F
from pyspark.sql.functions import pandas_udf, from_json, to_json
from pyspark.sql.functions import PandasUDFType
from jinja2 import Environment, FileSystemLoader
from kafka import KafkaConsumer, KafkaProducer


APP_NAME = "jupsparkapp-1"
NORMALIZED_APP_NAME = APP_NAME.replace('/', '_').replace(':', '_')
SPARK_ADDRESS = "local[4]"
LOCAL_IP = socket.gethostbyname(socket.gethostname())
env = Environment(loader=FileSystemLoader('/opt'))
# run spark
spark = SparkSession    .builder    .appName(APP_NAME)    .master(SPARK_ADDRESS)    .config("spark.driver.host", LOCAL_IP)    .config("spark.driver.bindAddress", "0.0.0.0")    .config("spark.executor.instances", "2")    .config("spark.executor.cores", '1')    .config("spark.memory.fraction", "0.1")    .config("spark.memory.storageFraction", "0.3")    .config("spark.executor.memory", '1g')    .config("spark.driver.memory", "1g")    .config("spark.driver.maxResultSize", "500m")    .config("spark.kubernetes.memoryOverheadFactor", "0.3")    .getOrCreate()

print("Web UI: {}".format(spark.sparkContext.uiWebUrl))

consumer = KafkaConsumer(bootstrap_servers="kafka:9092", consumer_timeout_ms=1000)
consumer.subscribe("gen-logs")

producer = KafkaProducer(bootstrap_servers='kafka:9092', value_serializer=lambda v: json.dumps(v).encode('utf-8'))


logged_in = {}

while(True):
    for msg in consumer:
        message = json.loads(msg.value)
        cd = message['commonData']
        data = message['data']
        ts = cd['time'][:19]
        if message['action'] == 'LoginReq':
            payload = { 'user_id': cd['userId'], 'time': ts }
            logged_in[cd['userId']] = int(time.time())
            producer.send('online_user', payload)
            print('online_user')
        elif message['action'] == 'LogoutReq':
            if cd['userId'] in logged_in:
                spent = int(time.time()) - logged_in[cd['userId']]
                payload = { 'user_id': cd['userId'], 'time': ts, 'spent': spent }
                producer.send('users_spend_time_online', payload)
                print('users_spend_time_online')
        elif message['action'] == 'LoginRep':
            if data['status'] == 'Invalid':
                payload = { 'user_id': cd['userId'], 'time': ts }
                producer.send('failed_login', payload)
                print('failed_login')
        payload = {
            'user_id': cd['userId'],
            'time': ts,
            'log': message['action']
        }
        producer.send('user_trace', payload)
        payload = {
            'request_id': cd['requestId'],
            'time': ts,
            'log': message['action']
        }
        producer.send('request_trace', payload)
        print('trace', msg.value[:40])
        producer.flush()

# # sc = SparkContext(appName="PysparkStreaming")
# ssc = StreamingContext(spark, 3)
# # lines = ssc.textFileStream('log/')  #'log/ mean directory name
# # counts = lines.flatMap(lambda line: line.split(" ")) \
# #     .map(lambda x: (x, 1)) \
# #     .reduceByKey(lambda a, b: a + b)
# # counts.pprint()
# # ssc.start()
# # ssc.awaitTermination()


# online_stream = KafkaUtils.createStream(
#     spark.sparkContext,
#         "{0}:{1}".format(
#             'zookeper',
#             '2181',
#         'main',
#         'online_user')




# df = spark   .readStream   .format("kafka")   .option("kafka.bootstrap.servers", "kafka:9092")   .option("subscribe", "gen-logs")   .load()
