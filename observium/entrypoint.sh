#!/bin/bash

set -o pipefail
set -e

if [ "${DEBUG_MODE,,}" == "true" ]; then
  set -o xtrace
fi

# Validate required environment variables
required_vars="DB_USER DB_PASSWORD DB_NAME OBSERVIUM_ADMIN_USER OBSERVIUM_ADMIN_PASSWORD"
for var in $required_vars; do
  eval value=\$$var
  if [ -z "$value" ]; then
    echo "ERROR: Required environment variable $var is not set"
    exit 1
  fi
done

db_hostname=mariadb
# Make database connection timeout configurable (default: 60 seconds)
DB_CONNECTION_TIMEOUT=${DB_CONNECTION_TIMEOUT:-60}

# Use MYSQL_PWD to avoid password in process list
export MYSQL_PWD="${DB_PASSWORD}"

show_observium_info() {
  echo "****************************************************"
  echo "* VERSION: $(cat ./VERSION)"
  echo "* OBSERVIUM_ADMIN_USER: ${OBSERVIUM_ADMIN_USER}"
  echo "* OBSERVIUM_ADMIN_PASSWORD: ${OBSERVIUM_ADMIN_PASSWORD}"
  echo "****************************************************"
}

check_db_connection() {
  attempt=0
  max_attempts=${DB_CONNECTION_TIMEOUT}
  rc=1
  while [ $rc -ne 0 ] && [ $attempt -lt $max_attempts ]
  do
     let attempt++
     echo "Attempt ${attempt}/${max_attempts} trying to connect to database..."
     mariadb --user ${DB_USER} -D ${DB_NAME} -h ${db_hostname} -e "select 1" > /dev/null 2>&1
     rc=$?
     [ $rc -ne 0 ] && sleep 1
  done
  if [ $rc -ne 0 ]; then
    echo "ERROR: Failed to connect to database after ${max_attempts} attempts. Exiting."
    exit 1
  fi
  echo "Successfully connected to database!"
}

set_dir_permissions() {
  chown -R www-data:www-data ./rrd
}

init_if_required() {
  tables=$(mariadb --user ${DB_USER} -D ${DB_NAME} -h ${db_hostname} -e "show tables")
  if [ -z "${tables}" ]
  then
     echo "Database schema initialization required..."
     ./discovery.php -u
     echo "Creating admin user..."
     ./adduser.php "${OBSERVIUM_ADMIN_USER}" "${OBSERVIUM_ADMIN_PASSWORD}" 10
  else
    echo "Database schema already initialized, no initialization required!"
     ./discovery.php -u
  fi
}

create_config() {
  export OBSERVIUM__db_host='mariadb'
  export OBSERVIUM__db_name="${DB_NAME}"
  export OBSERVIUM__db_user="${DB_USER}"
  export OBSERVIUM__db_pass="${DB_PASSWORD}"

  echo "Generating Observium configuration..."
  attempt=0
  max_attempts=3
  success=0

  while [ $attempt -lt $max_attempts ] && [ $success -eq 0 ]; do
    let attempt++
    if python3 /usr/local/bin/generate_config.py > ./config.php 2>/dev/null; then
      success=1
      echo "Configuration generated successfully!"
    else
      echo "WARNING: Config generation attempt ${attempt}/${max_attempts} failed"
      [ $attempt -lt $max_attempts ] && sleep 1
    fi
  done

  if [ $success -eq 0 ]; then
    echo "ERROR: Failed to generate configuration after ${max_attempts} attempts"
    exit 1
  fi

  if [ "$SHOW_GENERATED_CONFIG_DURING_STARTUP" = "yes" ]; then
    echo "Created Observium's config.php with the following settings:"
    cat ./config.php
  fi
}

import_snmp_devices() {
  devices_file="/conf/snmp-devices.txt"
  if [ -e "${devices_file}" ]; then
    echo "Importing SNMP devices from ${devices_file}..."
    if php ./add_device.php "${devices_file}" 2>&1; then
      echo "Successfully imported SNMP devices!"
    else
      echo "WARNING: Some devices may have failed to import. Check the output above for details."
    fi
  else
    echo "Skipping SNMP device import - ${devices_file} does not exist"
  fi
}

import_alert_checks_if_required() {
  count_alerts=$(mariadb --user ${DB_USER} -D ${DB_NAME} -h ${db_hostname} -N -B -e "select count(*) from alert_tests")
  if [ -z "$count_alerts" -o "$count_alerts" -eq 0 ]; then
    echo "No alert checks found, importing some alert checks..."
    mariadb --user ${DB_USER} -D ${DB_NAME} -h ${db_hostname} < /conf/alert-checks.sql
    echo "Successfully imported alert checks"
  else
    echo "Not importing alert checks, checks already exist."
  fi
}

generate_smokeping_config() {
  if [ ! -f ./scripts/generate-smokeping.php ]; then
    echo "WARNING: Smokeping config generator script not found, skipping"
    return 0
  fi

  echo "Generating Smokeping configuration..."
  if php ./scripts/generate-smokeping.php > /etc/smokeping/config.d/Targets 2>&1; then
    echo "Successfully generated Smokeping configuration"
  else
    echo "WARNING: Failed to generate Smokeping configuration. Smokeping integration may not work properly."
  fi
}

check_db_connection
create_config
init_if_required
import_snmp_devices
generate_smokeping_config
set_dir_permissions
import_alert_checks_if_required
show_observium_info

if [ "$1" != "" ]; then
    echo "Executing '$@'"
    exec "$@"
elif [ -f "/usr/sbin/apache2ctl" ]; then
    echo "Starting httpd..."
    exec apache2ctl -D FOREGROUND
else
    echo "Unknown instructions. Exiting..."
    exit 1
fi
