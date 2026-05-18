FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository universe && \
    apt-get update && \
    apt-get install -y --no-install-recommends asterisk && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 5060/udp
EXPOSE 10000-20000/udp

CMD ["asterisk", "-f"]
