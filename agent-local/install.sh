#!/bin/bash

set -eo pipefail

destination_dir=/usr/lib/observium_agent/local

 copy_and_set_permissions() {
    local script_name=$1
    read -p "Install ${script_name} script? (y/n): " copy_script
    if [[ $copy_script =~ ^[Yy]$ ]]; then
      cp ./${script_name}* "${destination_dir}" && chmod +x "${destination_dir}/${script_name}"
      echo "${script_name} script copied and permissions set."
    fi
  }

if [ -w "${destination_dir}" ]; then
  copy_and_set_permissions "dpkg"
  copy_and_set_permissions "ioping"
  copy_and_set_permissions "smarttemp"

  echo "Installation complete."
  if [ -f "${destination_dir}/ioping.conf" ]; then
    echo "Don't forget to edit ${destination_dir}/ioping.conf"
  fi
else
  echo "Error: local agent scripts directory does not exist at ${destination_dir} or is not writeable"
  exit 1
fi
