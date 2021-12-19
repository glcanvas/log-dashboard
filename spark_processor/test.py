# python3.7 -m pip install kafka-python
# kafka:9092

from time import sleep
from json import dumps
from kafka import KafkaProducer

producer = KafkaProducer(bootstrap_servers=['0.0.0.0:9092'], value_serializer=lambda x: dumps(x).encode('utf-8'))

for e in range(1000):
    data = {'number': e}
    print(producer.send('numtest', value=data))
    sleep(1)

if __name__ == "__main__":
    pass