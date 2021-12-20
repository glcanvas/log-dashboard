# python3.7 -m pip install kafka-python
# kafka:9092

from time import sleep
from json import dumps
from kafka import KafkaProducer

producer = KafkaProducer(bootstrap_servers=['0.0.0.0:9092', '0.0.0.0:9093', '0.0.0.0:9094'],
                         value_serializer=lambda x: dumps(x).encode('utf-8'))

a = {"action": "LoginReq",
     "commonData": {"logLevel": "Info", "serverName": "Login", "time": "2021-12-01T14:00:56.768422Z",
                    "userId": {"userId": 332902}, "requestId": {"requestId": 66240}}, "data": {"passwordHash": "􊂂"}}
b = {"action": "LoginDbReq",
     "commonData": {"logLevel": "Info", "serverName": "Login", "time": "2021-12-01T14:00:56.768422Z",
                    "userId": {"userId": 332902}, "requestId": {"requestId": 66240}},
     "data": {"query": "selassword_hash = "}}
c = {"action": "LoginRep",
     "commonData": {"logLevel": "Info", "serverName": "Login", "time": "2021-12-01T14:00:56.768422Z",
                    "userId": {"userId": 332902}, "requestId": {"requestId": 66240}}, "data": {"status": "Valid"}}

print(producer.send("logs-topic", a).get(10))
print(producer.send("logs-topic", b).get(10))
print(producer.send("logs-topic", c).get(10))

if __name__ == "__main__":
    pass
