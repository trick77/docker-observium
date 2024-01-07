# agent-local

This repository contains a set of Unix agent scripts designed for monitoring Linux Debian servers with Observium.
The typical location for these scripts on the server to be monitored is `/usr/lib/observium_agent/local`.
Please note that installing the scripts alone isn't sufficient. Refer to [Observium's documentation](https://docs.observium.org/unix_agent/) for
guidance on how to use them.

## Script installation

Use the provided `install.sh` to directly install from this repository without cloning it.

## dpgk

This local agent script supplies package information to Observium. This information is cached for up to 30 minutes
to enhance the efficiency of the poller. No alterations have been applied.

## ioping

The local agent implementation of Observium's `ioping` local agent script was no longer functional as of Debian Bookworm.
This revised implementation addresses the issue and introduces the capability to `ioping` multiple drives simultaneously.
However, it's important to note that ioping remains relatively slow even when executed in parallel.
Customize the `ioping.conf` file based on your requirements.

## smarttemp

This local agent script serves as a replacement for `hddtemp` since it has been abandoned and is no longer available as of Debian Bookworm.
It utilizes a combination of smartmontools' `smartctl` and `jq` to determine the temperature of all hard drives and
mimicks the output of the `hddtemp` local agent script.
