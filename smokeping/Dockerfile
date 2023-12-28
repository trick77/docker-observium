FROM debian:bookworm-slim

RUN apt update && apt -y dist-upgrade
RUN apt-get update && \
    apt-get install -y smokeping apache2- && \
    apt-get clean autoclean && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/lib/cache/* /var/lib/log/* /var/lib/apt/lists/*

RUN mkdir /run/smokeping

VOLUME /var/lib/smokeping /etc/smokeping/config.d

COPY entrypoint.sh /usr/local/bin/
ENTRYPOINT entrypoint.sh


