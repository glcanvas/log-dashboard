# This image is needed just to build dependencies once.

FROM fpco/stack-build
COPY ./generator-env /generator-env
RUN apt-get -y update
RUN apt-get -y install librdkafka-dev
WORKDIR "/generator-env"
RUN stack build
