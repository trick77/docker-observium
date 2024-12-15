FROM debian:bookworm-slim

ARG PHP_VERSION=8.2
ARG PYTHON_VERSION=3
ARG OBSERVIUM_BINARY=observium-community-24.4.tar.gz

RUN apt update && \
    apt -y dist-upgrade && \
    apt install -y libapache2-mod-php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-mysql php${PHP_VERSION}-gd php${PHP_VERSION}-bcmath php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-opcache php${PHP_VERSION}-apcu php${PHP_VERSION}-curl php-json php-pear snmp fping mariadb-server \
    mariadb-client python${PYTHON_VERSION}-mysqldb python-is-python${PYTHON_VERSION} python${PYTHON_VERSION}-pymysql rrdtool \
    graphviz imagemagick apache2 curl && \
    apt-get clean autoclean && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/lib/cache/* /var/lib/log/* /var/lib/apt/lists/*

RUN mkdir -p /opt/observium /opt/observium/logs /opt/observium/rrd
WORKDIR /opt
ADD ${OBSERVIUM_BINARY} ./

WORKDIR /opt/observium

# Don't like the Apple icon ;-)
RUN sed -i 's/icon-apple/icon-laptop/g' /opt/observium/html/includes/functions.inc.php || true
# Patching a bug when using file import
RUN sed -i 's/\($snmp_v3_args\s*=\s*array_slice(\$argv, 4);\)/$snmp_v3_args = array_slice($add, 3);/' ./add_device.php || true

RUN ln -sf /dev/stdout ./logs/observium.log
RUN chown -R -v www-data:www-data ./

COPY conf/apache2/site.conf /etc/apache2/sites-enabled/000-default.conf
COPY conf/apache2/conf-enabled/*.conf /etc/apache2/conf-enabled
COPY conf/apache2/ports.conf /etc/apache2/ports.conf
RUN a2enmod rewrite php${PHP_VERSION} && \
    ln -sf /dev/stdout /var/log/apache2/access.log && \
    ln -sf /dev/stderr /var/log/apache2/error.log

COPY bin/generate-config.php ./entrypoint.sh /usr/local/bin/
VOLUME /opt/observium/rrd
EXPOSE 8080

ENTRYPOINT /usr/local/bin/entrypoint.sh
