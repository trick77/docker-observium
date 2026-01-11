#!/bin/bash

set -o pipefail
set -e

if [ "${DEBUG_MODE,,}" == "true" ]; then
  set -o xtrace
fi

# Validate required environment variables
required_vars="DB_USER DB_PASSWORD DB_NAME OBSERVIUM_ADMIN_USER OBSERVIUM_ADMIN_PASSWORD"
for var in $required_vars; do
  # Use indirect expansion instead of eval for security
  value="${!var}"
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
  # Use information_schema to reliably count tables (avoids header issues with 'show tables')
  table_count=$(mariadb --user ${DB_USER} -D ${DB_NAME} -h ${db_hostname} -N -B -e \
    "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${DB_NAME}'")

  if [ "$table_count" -eq 0 ]; then
    echo "Database schema initialization required..."

    # Acquire database lock to prevent concurrent initialization (timeout: 10 seconds)
    lock_acquired=$(mariadb --user ${DB_USER} -D ${DB_NAME} -h ${db_hostname} -N -B -e \
      "SELECT GET_LOCK('observium_init', 10)")

    if [ "$lock_acquired" != "1" ]; then
      echo "ERROR: Failed to acquire database initialization lock. Another container may be initializing."
      echo "Waiting for initialization to complete..."
      sleep 5

      # Check again if tables exist (initialization may have completed)
      table_count=$(mariadb --user ${DB_USER} -D ${DB_NAME} -h ${db_hostname} -N -B -e \
        "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${DB_NAME}'")

      if [ "$table_count" -eq 0 ]; then
        echo "ERROR: Database still not initialized and lock acquisition failed"
        exit 1
      else
        echo "Database initialization completed by another container"
        ./discovery.php -u
        return 0
      fi
    fi

    # Double-check tables don't exist (race condition protection)
    table_count=$(mariadb --user ${DB_USER} -D ${DB_NAME} -h ${db_hostname} -N -B -e \
      "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${DB_NAME}'")

    if [ "$table_count" -eq 0 ]; then
      echo "Initializing database schema..."
      ./discovery.php -u
      echo "Creating admin user..."
      ./adduser.php "${OBSERVIUM_ADMIN_USER}" "${OBSERVIUM_ADMIN_PASSWORD}" 10
      echo "Database initialization complete"
    else
      echo "Database already initialized by another process"
      ./discovery.php -u
    fi

    # Release the lock
    mariadb --user ${DB_USER} -D ${DB_NAME} -h ${db_hostname} -N -B -e "SELECT RELEASE_LOCK('observium_init')" > /dev/null
  else
    echo "Database schema already initialized (${table_count} tables found)"
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
    if python3 /usr/local/bin/generate_config.py > ./config.php; then
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
