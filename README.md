# docker-observium

[![Docker build](https://github.com/trick77/docker-observium/actions/workflows/build-images.yaml/badge.svg)](https://github.com/trick77/docker-observium/actions/workflows/build-images.yaml)

This repository delivers [Observium](https://www.observium.org/), a network monitoring powerhouse, in a sleek Dockerized package. Spin up Observium in a flash within a containerized realm for seamless operation.

![Observium screenshot](/screenshot.png?raw=true)

## Features

- **Molds** Observium's behavior on-the-fly by defining config settings through environment variables in the `.env` file, seamlessly translated to PHP at runtime.
- **Embraces** container-based scheduling wizardry with [Ofelia](https://github.com/mcuadros/ofelia), waving goodbye to the mundane Linux cron jobs.
- **Bids farewell** to supervisord, reveling in a streamlined setup free from its clutches.
- **Says no** to log file clutter and rotation headaches – witness everything elegantly flowing to stdout.
- **Safeguards** your data with daily backups, ensuring your digital fortress stands resilient.
- **Feels the pulse** with [Smokeping](https://oss.oetiker.ch/smokeping), adding rhythm to your network monitoring symphony.

## Disclaimer

Just a heads up, this project is fine-tuned to dance with my specific monitoring needs. It skips a beat on
things like RANCID, CollectD, rrdcached, and ARM64 love. While I'm currently not open to extending the functionality through
contributions, I welcome bugfix pull requests. Hit me up if you spot anything wonky.

## Prerequisites

1. Docker
1. Devices you want to monitor using SNMP and maybe even Observium's Unix agent

## Usage

1. Copy `.env.example` to `.env` and set passwords and other configuration details
1. Copy `observium/conf/observium/snmp-devices.txt.example` to `snmp-devices.txt` and add SNMP devices to import during startup
1. Start the containers with a single `docker compose up -d` in the base directory
1. Monitor for errors with `docker compose logs -f`

## Configuration

To configure Observium's PHP settings using Docker Compose, adhere to the guidelines below.
Only environment variables in the `.env` file with the `OBSERVIUM__` prefix will be utilized to generate the PHP configuration in the `config.php` file.

### Mapping environment variables to Observium's configuration

Add or overwrite Observium settings in the `.env` file using the `OBSERVIUM__` prefix. Follow these mapping instructions:

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

Ensure that environment variables are configured appropriately, taking into account the specific syntax requirements outlined above. For a debugging
tip, once the UI is up, check the "Full dump" and "Changed dump" in "Global Settings" to view how the environment variables were mapped to
Observium's configuration.

For further details on these configurations and their impact on Observium's behavior, consult the Observium documentation
or the comments provided in the `.env.example` file. Adjust the settings according to your deployment needs.

## TODO

- [ ] Show how to use the entrypoint to add/remove/rename devices
- [x] Explain the `__` and `___` in .env
- [x] Alerts have to be added manually and that there is no import mechanism, at least not in CE. Maybe provide a template?
- [ ] Maybe provide a generate-env.sh to generate the basic settings?
- [x] Easy variable debugging using the Full Dump menu option in Observium's UI
- [x] Explain why there is no issues tab for this project
- [ ] Add a license
- [ ] Restore instructions
- [ ] Updating
- [ ] SNMP client config including distro script
- [ ] Unix agent client config with xinetd
- [ ] Links to contributors/projects

