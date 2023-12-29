# docker-observium

[![Docker build](https://github.com/trick77/docker-observium/actions/workflows/build-images.yml/badge.svg)](https://github.com/trick77/docker-observium/actions/workflows/build-images.yml)

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
1. Traefik reverse-proxy (example configruation provided below)
1. Devices you want to monitor using SNMP and maybe even Observium's Unix agent

## Usage

1. Edit `observium/.env` to set passwords and other configuration details
1. Edit `observium/conf/observium/devices.txt` to add SNMP devices that should be imported during container startup
1. Start the containers with `docker compose up -d`
1. Monitor for errors with `docker compose logs -f`

## Configuration

To configure Observium's PHP settings using Docker Compose, adhere to the guidelines below.
Only environment variables in the `observium/.env` file with the `OBSERVIUM__` prefix will be utilized to generate the PHP configuration in the `config.php` file.

### Mapping environment variables to Observium's configuration

Add or overwrite Observium settings in the `observium/.env` file using the `OBSERVIUM__` prefix. Follow these mapping instructions:

- Using a single underscore (`_`) will include an underscore in the key (e.g., `OBSERVIUM__int_core=0`).
- Using a double underscore (`__`) will add the value to an associative array with the given key.
- Using a double underscore with a number (`__0`) will add the value to an indexed/sequential array.
- Dashes cannot be used in environment variables. To represent a dash in the key, escape it using triple underscores (`___`).

Refer to the example below:
```env
OBSERVIUM__base_url=https://${OBSERVIUM_FQDN}
OBSERVIUM__ping__retries=5
OBSERVIUM__poller___wrapper__threads=2
OBSERVIUM__unix___agent__port=6556
OBSERVIUM__snmp__max___rep=true
OBSERVIUM__web_mouseover=false
OBSERVIUM__bad_if__0=docker0
OBSERVIUM__bad_if__1=lo
OBSERVIUM__bad_if_regexp__0='/^veth.*/'
OBSERVIUM__bad_if_regexp__1='/^br-.*/'
```

Ensure that environment variables are configured appropriately, taking into account the specific syntax requirements outlined above.

For further details on these configurations and their impact on Observium's behavior, consult the Observium documentation
or the comments provided in the `observium/.env`  file. Adjust the settings according to your deployment needs.

## Traefik reverse-proxy example

Here's how to run Traefik in front of Observium and probably every Docker web app you want to securely expose on the Interwebs.

The service configuration below features:
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

- [ ] Show how to use the entrypoint to add/remove/rename devices
- [x] Explain the `__` and `___` in .env
- [ ] Alerts have to be added manually and that there is no import mechanism, at least not in CE. Maybe provide a template?
- [ ] Maybe provide a generate-env.sh to generate the basic settings?
- [ ] Easy variable debugging using the Full Dump menu option in Observium's UI
- [ ] Explain why there is no issues tab for this project
- [x] Provide a Traefik example since those are somewhat hard to find
- [x] Show how to create the required traefik network using `docker network traefik create` or something
- [ ] Add a license
- [ ] Restore instructions
- [ ] Updating
- [ ] Links to contributors/projects

