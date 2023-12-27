#!/bin/bash

sleep_interval=60
watch_file=/etc/smokeping/config.d/Targets

restart_smokeping() {
    pkill -f "smokeping --nodaemon"
    exec smokeping --nodaemon &
}

while true; do
    current_hash=$(md5sum "${watch_file}" | awk '{print $1}')
    if [ "$current_hash" != "$prev_hash" ]; then
        echo "* Smokeping needs to be restarted since content of ${watch_file} has changed!"
        restart_smokeping
    fi
    prev_hash=$current_hash
    sleep ${sleep_interval}
done
