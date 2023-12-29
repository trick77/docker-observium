#!/bin/bash

set -o pipefail
set +e

if [ "${DEBUG_MODE,,}" == "true" ]; then
    set -o xtrace
fi

show_observium_info() {
  echo "****************************************************"
  echo "* VERSION: $(cat ./VERSION)"
  echo "* OBSERVIUM_ADMIN_USER: ${OBSERVIUM_ADMIN_USER}"
  echo "* OBSERVIUM_ADMIN_PASSWORD: ${OBSERVIUM_ADMIN_PASSWORD}"
  echo "****************************************************"
}

check_db_connect() {
  attempt=0
  rc=1
  while [ $rc -ne 0 ]
  do
     let attempt++
     echo "* Attempt ${attempt} trying to connect to database..."
     mysql -h db -u ${DB_USER} --password=${DB_PASSWORD} -e "select 1" ${DB_NAME} >/dev/null
     rc=$?
     [ $rc -ne 0 ] && sleep 1
  done
  echo "* Successfully connected to database"
}

set_dir_permissions() {
     chown -R www-data:www-data ./rrd
}

init_if_required() {
  tables=`mysql -h db -u ${DB_USER} --password=${DB_PASSWORD} -e "show tables" ${DB_NAME} 2>/dev/null`
  if [ -z "$tables" ]
  then
     echo "* Database schema initialization required..."
     ./discovery.php -u
     echo "* Creating admin user..."
     ./adduser.php "${OBSERVIUM_ADMIN_USER}" "${OBSERVIUM_ADMIN_PASSWORD}" 10
  else
    echo "* Database schema already initializied, no initialization required!"
  fi
}

create_config() {
    export OBSERVIUM__db_host='db'
    export OBSERVIUM__db_name="${DB_NAME}"
    export OBSERVIUM__db_user="${DB_USER}"
    export OBSERVIUM__db_pass="${DB_PASSWORD}"
    echo "$(php ./generate-config.php)" > ./config.php
    if [ "$SHOW_GENERATED_CONFIG_DURING_STARTUP" = "yes" ]; then
      echo "* Created Observium's config.php with the following settings:"
      cat ./config.php
    fi
}

import_devices() {
    devices_file="/conf/devices.txt"
    if [ -e "${devices_file}" ]; then
        echo "* Trying to import devices from devices-import file ${devices_file}..."
        while read -r params || [ -n "$params" ]; do
            php ./add_device.php ${params} || true
        done < <(grep -v "^#\|^$" "${devices_file}")
    else
    echo "* Devices-import file ${devices_file} does not exist, not importing any devices"
    fi
}

generate_smokeping_config() {
    php /opt/observium/scripts/generate-smokeping.php > /etc/smokeping/config.d/Targets
}

check_db_connect
create_config
init_if_required
import_devices
generate_smokeping_config
set_dir_permissions
show_observium_info

if [ "$1" != "" ]; then
    echo "* Executing '$@'"
    exec "$@"
elif [ -f "/usr/sbin/apache2ctl" ]; then
    echo "* Starting httpd..."
    exec apache2ctl -D FOREGROUND
else
    echo "Unknown instructions. Exiting..."
    exit 1
fi
