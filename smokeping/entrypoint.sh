#!/bin/bash

set -e
set -o pipefail

sleep_interval=60
watch_file=/etc/smokeping/config.d/Targets
smokeping_pid=""
shutdown_requested=false

# Graceful shutdown handler
shutdown() {
    echo "Received shutdown signal, stopping smokeping..."
    shutdown_requested=true
    if [ -n "$smokeping_pid" ] && kill -0 "$smokeping_pid" 2>/dev/null; then
        kill -TERM "$smokeping_pid" 2>/dev/null || true
        wait "$smokeping_pid" 2>/dev/null || true
    fi
    echo "Smokeping stopped gracefully"
    exit 0
}

# Trap SIGTERM and SIGINT for graceful shutdown
trap shutdown SIGTERM SIGINT

start_smokeping() {
    # Stop existing smokeping if running
    if [ -n "$smokeping_pid" ] && kill -0 "$smokeping_pid" 2>/dev/null; then
        echo "Stopping existing smokeping process (PID: $smokeping_pid)..."
        kill -TERM "$smokeping_pid" 2>/dev/null || true
        wait "$smokeping_pid" 2>/dev/null || true
    fi

    echo "Starting smokeping..."
    smokeping --nodaemon &
    smokeping_pid=$!
    echo "Smokeping started with PID: $smokeping_pid"
}

# Initial start
start_smokeping

# Monitor loop with config file watching
while [ "$shutdown_requested" = false ]; do
    # Check if smokeping is still running
    if ! kill -0 "$smokeping_pid" 2>/dev/null; then
        echo "WARNING: Smokeping process died unexpectedly, restarting..."
        start_smokeping
    fi

    # Check if config file changed
    current_hash=$(md5sum "${watch_file}" 2>/dev/null | awk '{print $1}' || echo "")
    if [ -n "$current_hash" ] && [ "$current_hash" != "$prev_hash" ] && [ -n "$prev_hash" ]; then
        echo "Smokeping config changed (${watch_file}), restarting..."
        start_smokeping
    fi
    prev_hash=$current_hash

    # Sleep with ability to wake on signal
    sleep ${sleep_interval} &
    wait $! 2>/dev/null || true
done
