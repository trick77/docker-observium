FROM debian:bookworm-slim

ARG PHP_VERSION=8.2
ARG PYTHON_VERSION=3
ARG OBSERVIUM_BINARY=observium-community-23.9.13005.tar.gz

# Install Debian packages required for Observium
RUN apt update && apt -y dist-upgrade
RUN apt install -y libapache2-mod-php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-mysql php${PHP_VERSION}-gd php${PHP_VERSION}-bcmath php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-opcache php${PHP_VERSION}-apcu php${PHP_VERSION}-curl php-json php-pear snmp fping mariadb-server \
    mariadb-client python${PYTHON_VERSION}-mysqldb python-is-python${PYTHON_VERSION} python${PYTHON_VERSION}-pymysql rrdtool \
    graphviz imagemagick apache2 curl && \
    apt-get clean autoclean && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/lib/cache/* /var/lib/log/* /var/lib/apt/lists/*

# Install Observium binary
RUN mkdir -p /opt/observium /opt/observium/logs /opt/observium/rrd
WORKDIR /opt
ADD ${OBSERVIUM_BINARY} ./

WORKDIR /opt/observium
RUN ln -sf /dev/stdout ./logs/observium.log
RUN chown -R www-data:www-data ./

# Configure Apache2 webserver
COPY conf/apache2/site.conf /etc/apache2/sites-enabled/000-default.conf
COPY conf/apache2/conf-enabled/*.conf /etc/apache2/conf-enabled
COPY conf/apache2/ports.conf /etc/apache2/ports.conf
RUN a2enmod rewrite php${PHP_VERSION}
RUN ln -sf /dev/stdout /var/log/apache2/access.log && \
    ln -sf /dev/stderr /var/log/apache2/error.log

VOLUME /opt/observium/rrd
EXPOSE 8080/tcp

COPY bin/create-config.php ./
COPY entrypoint.sh /usr/local/bin

ENTRYPOINT /usr/local/bin/entrypoint.sh
