FROM bitnami/spark:3
USER root
RUN rm -rf /opt/bitnami/python
RUN apt update
RUN apt install -y software-properties-common
RUN apt install -y python3-pip
RUN python3.7 -m pip install python-dateutil
RUN python3.7 -m pip install pyspark==2.4.4
RUN python3.7 -m pip install findspark
COPY ./launcher.sh ./launcher.sh
COPY ./main.py ./main.py
#ENTRYPOINT ["/bin/sh"]
#CMD ["/opt/bitnami/spark/launcher.sh"]