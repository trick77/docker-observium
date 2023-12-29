# docker-observium

This repository provides a Dockerized version of Observium, a network monitoring platform. It allows you to quickly set up and run Observium in a containerized environment.

## Features

- Observium configuration settings can be defined using environment variables in the `observium/.env` file and get translated to PHP at runtime
- Uses container-based scheduling mechanism using Ofelia instead of Linux crontab/cron jobs
- Does not use supervisord
- No log files, no log file rotation - everything is sent to stdout
- Uses Traefik reverse-proxy for easy ACME certificate generation
- Creates daily backups
- Smokeping!

## Prerequisites
1. Docker
1. Traefik
1. Devices you want to monitor using SNMP and maybe even Observium's Unix agent

## Usage

1. Edit `observium/.env` and set passwords and stuff
1. Edit `observium/conf/observium/devices.txt` to add one or more devices during container startup
1. Start the containers with `docker compose up -d`
1. Watch for errors with `docker compose logs -f`

## Traefik reverse-proxy

Here's how to run Traefik in front of Observium and probably every Docker web app you want to securely expose on the Interwebs.

This service config features:
- Redirects insecure requests to HTTPS
- Runs the Traefik dashboard on its own FQDN, protected by basic authentication (use credentials traefik/traefik)
- Utilizes ACME TLS challenge to automatically fetch certificates for your domains
- Dumps access logs to the container's stdout
- Reads environment variables from an `.env` file

The required Docker bridge is defined externally and has to created with `docker network create traefik`. It's also possible to add IPv6 network support this way (not shown).

**`compose.yml`**
``` yml
version: '3'

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: always
    environment:
      - PUID=65534
      - PGID=65534
      - TZ=${TIMEZONE}
      - LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
    command:
      - "--log.level=INFO"
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=traefik"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.websecure.asDefault=true"
      - "--entrypoints.websecure.http.tls.certresolver=letsencrypt"
      - "--certificatesresolvers.letsencrypt.acme.email=${LETSENCRYPT_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      #- "--certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--accesslog=true"
      - "--accessLog.fields.headers.names.User-Agent=keep"
      - "--ping"
      - "--global.checkNewVersion=true"
      - "--global.sendAnonymousUsage=false"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mydashboard.rule=Host(`${TRAEFIK_DASHBOARD_FQDN}`)"
      - "traefik.http.routers.mydashboard.service=api@internal"
      - "traefik.http.routers.mydashboard.middlewares=myauth"
      - "traefik.http.middlewares.myauth.basicauth.users=traefik:$$2y$$05$$uuzfkHu9qpLnslD9reMTEu7KsTKaM5Gzy2jD77/5ciGO7mcVXxHB2"
    healthcheck:
      test: "traefik healthcheck --ping"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    networks:
      - traefik

networks:
  traefik:
    external: true

```

## Documentation TODO's

Unfortunatley, no proper docs at this time...

- Show how to use the entrypoint to add/remove/rename devices
- Explain the `__` and `___` in .env
- Alerts have to be added manually and that there is no import mechanism, at least not in CE. Maybe provide a template?
- Maybe provide a generate-env.sh to generate the basic settings?
- Easy variable debugging using the Full Dump menu option in Observium's UI
- Explain why there is no issues tab for this project
- Provide a Traefik example since those are somewhat hard to find
- Show how to create the required traefik network using `docker network traefik create` or something
- Why not LibreNMS?
- Add a license
- Restore instructions
- Updating
- Links to contributors/projects

