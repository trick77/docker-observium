# docker-observium

[![Docker build](https://github.com/trick77/docker-observium/actions/workflows/build-images.yml/badge.svg)](https://github.com/trick77/docker-observium/actions/workflows/build-images.yml)

This repository delivers [Observium](https://www.observium.org/), a network monitoring powerhouse, in a sleek Dockerized package. Spin up Observium in a flash within a containerized realm for seamless operation.

![Observium screenshot](/screenshot.png?raw=true)

## Features

- **Molds** Observium's behavior on-the-fly by defining config settings through environment variables in the `observium/.env` file, seamlessly translated to PHP at runtime.
- **Embraces** a container-based scheduling wizardry with [Ofelia](https://github.com/mcuadros/ofelia), waving goodbye to the mundane Linux cron jobs.
- **Bids farewell** to supervisord, reveling in a streamlined setup free from its clutches.
- **Says no** to log file clutter and rotation headaches – witness everything elegantly flowing to stdout.
- **Rides** the Traefik wave for a hassle-free ACME certificate ballet, courtesy of a savvy reverse-proxy.
- **Safeguards** your data with daily backups, ensuring your digital fortress stands resilient.
- **Feels the pulse** with [Smokeping](https://oss.oetiker.ch/smokeping), adding rhythm to your network monitoring symphony.

## Disclaimer

Just a heads up, this project is fine-tuned to dance with my specific monitoring groove and hardware vibes. It skips a beat on
things like RANCID, CollectD, rrdcached, and ARM64 love. If you're feeling the need for extra spice or tweaks, fork this repo and jam out your version.
No issues tab here – keeping it streamlined. Open to bugfix pull requests – hit me up if you spot anything wonky.

I am not keen on providing pre-built docker images. Hence this is a build-your-own-image project.

## Prerequisites

1. Docker
1. Traefik reverse-proxy (example configruation provided below)
1. Devices you want to monitor using SNMP and maybe even Observium's Unix agent

## Usage

1. Edit `observium/.env` to set passwords and other configuration details
1. Edit `observium/conf/observium/devices.txt` to add SNMP devices that should be imported during container startup
1. Start the containers with a single `docker compose up -d` in the base directory
1. Monitor for errors with `docker compose logs -f`

## Configuration

To configure Observium's PHP settings using Docker Compose, adhere to the guidelines below.
Only environment variables in the `observium/.env` file with the `OBSERVIUM__` prefix will be utilized to generate the PHP configuration in the `config.php` file.

### Mapping environment variables to Observium's configuration

Add or overwrite Observium settings in the `observium/.env` file using the `OBSERVIUM__` prefix. Follow these mapping instructions:

| Syntax                          | Description                                                               |
|---------------------------------|---------------------------------------------------------------------------|
| `_`                             | Using a single underscore will include an underscore in the key.          |
| `__`                            | Using a double underscore will add the value to an associative array.     |
| `___`                           | To represent a dash in the key, escape it using triple underscores.       |
| `__0`                           | Using a double underscore with a number will add the value to sequential array at the indicated position. |

Refer to the example below:
``` env
OBSERVIUM__base_url=https://${OBSERVIUM_FQDN}
OBSERVIUM__ping__retries=5
OBSERVIUM__poller___wrapper__threads=2
OBSERVIUM__unix___agent__port=6556
OBSERVIUM__web_mouseover=false
OBSERVIUM__bad_if__0=docker0
OBSERVIUM__bad_if__1=lo
OBSERVIUM__bad_if_regexp__0='/^veth.*/'
OBSERVIUM__bad_if_regexp__1='/^br-.*/'
```
Should be translated during container startup to the equivalent of:
``` php
$config['base_url'] = "https://observium.abba.net/";
$config['ping_retries'] = 5;
$config['poller-wrapper]['threads'] = 2;
$config['unix-agent']['port'] = 6556;
$config['web_mouseover'] = FALSE;
$config['bad_if'][] = "docker0";
$config['bad_if'][] = "lo";
$config['bad_if_regexp'][] = "/^veth.*/";
$config['bad_if_regexp'][] = "/^br-.*/";
```

Ensure that environment variables are configured appropriately, taking into account the specific syntax requirements outlined above.

For further details on these configurations and their impact on Observium's behavior, consult the Observium documentation
or the comments provided in the `observium/.env`  file. Adjust the settings according to your deployment needs.

## Traefik reverse-proxy example

Set up Traefik as your guardian for Observium and any Docker web app you desire to flaunt securely on the vast expanse of the Internet.

In this service configuration, behold:

- Forcefully nudging insecure requests towards the safer realms of HTTPS.
- Elevate the Traefik dashboard to its majestic throne, guarded by the impenetrable shield of basic authentication (credentials: traefik/traefik).
- Harness the power of the ACME TLS challenge to effortlessly summon certificates for your esteemed domains.
- Witness the eloquent dance of access logs gracefully streaming into the container's stdout.
- Equip your setup with the nimble ability to absorb environment variables from the sacred tome known as the `.env` file.

The required Docker bridge is defined externally and has to created with `docker network create traefik`. It's also possible to add IPv6 network support this way (not shown here).

``` yml
version: '3.9'

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

## TODO

- [ ] Show how to use the entrypoint to add/remove/rename devices
- [x] Explain the `__` and `___` in .env
- [ ] Alerts have to be added manually and that there is no import mechanism, at least not in CE. Maybe provide a template?
- [ ] Maybe provide a generate-env.sh to generate the basic settings?
- [ ] Easy variable debugging using the Full Dump menu option in Observium's UI
- [x] Explain why there is no issues tab for this project
- [x] Provide a Traefik example since those are somewhat hard to find
- [x] Show how to create the required traefik network using `docker network traefik create` or something
- [ ] Add a license
- [ ] Restore instructions
- [ ] Updating
- [ ] SNMP client config including distro script
- [ ] Unix agent client config with xinetd
- [ ] Links to contributors/projects

