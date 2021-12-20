FROM klntsky/generator-env:1.0
COPY ./generator /generator
RUN apt-get -y update
RUN apt-get -y install librdkafka-dev
WORKDIR "/generator"
RUN stack build && stack install
ENTRYPOINT generator -c config.yaml