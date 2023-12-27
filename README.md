# docker-observium

This repository provides a Dockerized version of Observium, a network monitoring platform. It allows you to quickly set up and run Observium in a containerized environment.

## Features

- Observium configuration settings can be defined using environment variables in the `observium/.env` file and get translated to PHP at runtime
- Uses container-based scheduling mechanism using Ofelia instead of Linux crontab/cron jobs
- Does not use supervisord
- No log files, no log file rotation - everything is sent to stdout
- Uses Traefik reverse-proxy for easy ACME certificate generation
- Smokeping!

## Prerequisites
1. Docker
1. Probably Traefik
1. Devices you can monitor using SNMP and maybe even Observium's UNIX agent

## Usage

1. Edit `observium/.env` and set passwords and stuff
1. Edit `observium/devices.txt` to add one or more devices during container startup
1. Start the containers with `docker compose up -d`
1. Watch for errors with `docker compose logs -f`

## Documentation TODO's

Unfortunatley, no proper docs at this time...

- Show how to use the entrypoint to add/remove/rename devices
- Explain the `__` and `___` in .env
- Alerts have to be added manually and that there is no import mechanism, at least not in CE. Maybe provide a template?
- Maybe provide a generate-config.sh?
- Easy variable debugging using the Full Dump menu option in Observium's UI
- Explain why there is no issues tab for this project
- Provide a Traefik example since those are somewhat hard to find
- Show how to create the required traefik network using `docker network traefik create` or something
- Why not LibreNMS?
- Links to contributors/projects

