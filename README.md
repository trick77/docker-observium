# docker-observium

This repository provides a Dockerized version of Observium, a network monitoring platform. It allows you to quickly set up and run Observium in a containerized environment.

## Features

- Observium configuration settings can be defined using environment variables in the `observium/.env` file and get translated to PHP at runtime
- Uses container-based scheduling mechanism using Ofelia instead of Linux OS cron
- Does not use supervisord
- No log files, no log file rotation - everything is sent to stdout
- Smokeping!
- Traefik reverse-proxy ready for easy ACME certificate generation

Unfortunatley, no proper docs at this time...

## Usage

1. Edit `observium/.env` and set passwords and stuff
1. Edit `devices.txt` to add one or more devices during container startup
1. Start the containers with `docker compose up -d`
1. Watch for errors with `docker compose logs -f`

## TODO's

- Show how to use the entrypoint to add/remove/rename devices
- Explain __ and ___ in .env
- Alerts have to be added manually and that there is no import mechanism, at least not in CE. Maybe provide a template?
- Maybe provide a generate-config.sh?
- Easy variable debugging using the Full Dump menu option in Observium's UI
- Explain why there is no issues tab for this project
