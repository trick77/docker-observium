# docker-observium

This repository provides a Dockerized version of Observium, a network monitoring platform. It allows you to quickly set up and run Observium in a containerized environment.

## Features

- Observium configuration settings can be defined using environment variables in the `.env` file and get translated to PHP at runtime
- Uses container-based scheduling mechanism using Ofelia instead of Linux OS cron
- Does not use supervisord
- No log files, no log file rotation - everything is sent to stdout
- Smokeping!
- Traefik reverse-proxy ready for easy ACME certificate generation

Unfortunatley, no proper docs at this time...
