# docker-observium

[![Docker build](https://github.com/trick77/docker-observium/actions/workflows/build-images.yaml/badge.svg)](https://github.com/trick77/docker-observium/actions/workflows/build-images.yaml)

Production-ready Docker deployment of [Observium](https://www.observium.org/) Community Edition with MariaDB, Smokeping latency monitoring, and automated scheduling.

![Observium screenshot](/screenshot.png?raw=true)

## Overview

This project provides a containerized Observium Community Edition 24.12 network monitoring platform with:

- **Auto-provisioned infrastructure**: MariaDB database, Apache web server, Smokeping integration
- **Environment-driven configuration**: Configure Observium via `.env` file - automatically translated to PHP config
- **Container-native operations**: Logging to stdout/stderr, graceful shutdown handling, health checks
- **Automated scheduling**: Container-based job scheduler (Ofelia) replaces traditional cron
- **Data protection**: Automated daily backups of database and RRD files
- **Production-ready**: Race condition prevention, configurable timeouts, retry logic

## Features

- **Dynamic PHP Configuration**: Generate Observium config.php from environment variables with automatic type conversion (boolean, integer, string)
- **Container-Based Scheduling**: Ofelia job scheduler handles discovery, polling, housekeeping, and backups
- **Centralized Logging**: All services log to stdout/stderr for easy monitoring with `docker compose logs`
- **Automated Backups**: Daily backups of database and RRD files, automatically retains last 10
- **Smokeping Integration**: Built-in latency monitoring with automatic config generation
- **Graceful Shutdown**: Proper SIGTERM handling for clean container stops
- **Database Safety**: Initialization locking prevents race conditions when scaling
- **Configurable Timeouts**: Database connection timeout and config generation retry logic
- **Enhanced Observability**: Startup messages show config processing, warnings, and errors

## Architecture

### Services

- **httpd**: Observium web interface and backend (Apache + PHP 8.2)
- **mariadb**: MySQL-compatible database (MariaDB 11)
- **smokeping**: Network latency monitoring
- **ofelia**: Container-based job scheduler

### Volumes

- `observium-rrd`: RRD graph databases (persistent)
- `observium-logs`: Application logs
- `observium-db`: MariaDB data files
- `smokeping-data`: Smokeping RRD files
- `smokeping-config`: Smokeping configuration

### Initialization Sequence

1. **Database check**: Wait for MariaDB to be ready (configurable timeout)
2. **Config generation**: Create PHP config from environment variables
3. **Schema initialization**: If database is empty, create tables and admin user (with distributed locking)
4. **Device import**: Import SNMP devices from `snmp-devices.txt` if present
5. **Smokeping config**: Generate Targets configuration
6. **Start services**: Launch Apache and Smokeping

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- SNMP-enabled devices to monitor
- (Optional) Observium Unix agent deployed on monitored systems

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/trick77/docker-observium.git
cd docker-observium

# 2. Configure environment
cp .env.example .env
# Edit .env and set:
#   - MARIADB_ROOT_PASSWORD
#   - DB_PASSWORD
#   - OBSERVIUM_ADMIN_PASSWORD
#   - OBSERVIUM_FQDN

# 3. (Optional) Add SNMP devices to import on first startup
cp observium/conf/snmp-devices.txt.example observium/conf/snmp-devices.txt
# Edit snmp-devices.txt with your devices

# 4. Start services
docker compose up -d

# 5. Monitor startup (wait for "Successfully connected to database!")
docker compose logs -f httpd

# 6. Access web interface
# Navigate to: https://<OBSERVIUM_FQDN>
# Login: admin / <OBSERVIUM_ADMIN_PASSWORD>
```

First startup takes 2-3 minutes for database initialization. Subsequent startups are faster.

## Configuration

### Core Environment Variables

Edit `.env` to configure the deployment:

| Variable | Description | Default |
| -------- | ----------- | ------- |
| `MARIADB_ROOT_PASSWORD` | MariaDB root password | `changeme` |
| `DB_NAME` | Database name | `observium` |
| `DB_USER` | Database user | `observium` |
| `DB_PASSWORD` | Database password | `changeme` |
| `OBSERVIUM_ADMIN_USER` | Web UI admin username | `admin` |
| `OBSERVIUM_ADMIN_PASSWORD` | Web UI admin password | `changeme` |
| `OBSERVIUM_FQDN` | Fully qualified domain name | `changeme.foobar.com` |
| `DB_CONNECTION_TIMEOUT` | Database connection timeout (seconds) | `60` |
| `DEBUG_MODE` | Enable debug logging | `false` |
| `SHOW_GENERATED_CONFIG_DURING_STARTUP` | Show config in logs (⚠️ exposes secrets) | `yes` |
| `TZ` | Container timezone | `Europe/Berlin` |

### Observium Configuration Mapping

Configure Observium settings by adding environment variables with the `OBSERVIUM__` prefix to `.env`. These are automatically translated to PHP configuration at container startup.

#### Mapping Rules

| Pattern | Description | Example |
| ------- | ----------- | ------- |
| `OBSERVIUM__key` | Simple value | `OBSERVIUM__base_url=https://obs.example.com` → `$config['base_url']` |
| `OBSERVIUM__key1__key2` | Nested array | `OBSERVIUM__ping__retries=5` → `$config['ping']['retries']` |
| `OBSERVIUM__key___name` | Dash in key name | `OBSERVIUM__unix___agent__port=6556` → `$config['unix-agent']['port']` |
| `OBSERVIUM__key__0` | Indexed array | `OBSERVIUM__bad_if__0=docker0` → `$config['bad_if'][0]` |

#### Type Conversion

Values are automatically converted to appropriate PHP types:

- `true` / `false` → PHP boolean (`TRUE` / `FALSE`)
- Numeric strings → PHP integers
- Strings with leading zeros → Kept as strings (e.g., `007`)
- All other values → PHP strings

#### Example Configuration

```env
# Web interface
OBSERVIUM__base_url=https://${OBSERVIUM_FQDN}
OBSERVIUM__web_mouseover=false
OBSERVIUM__web_show_locations=1

# Polling
OBSERVIUM__ping__retries=5
OBSERVIUM__poller___wrapper__threads=2

# Interface filtering (ignore these)
OBSERVIUM__bad_if__0=docker0
OBSERVIUM__bad_if__1=lo
OBSERVIUM__bad_if_regexp__0='/^veth.*/'
OBSERVIUM__bad_if_regexp__1='/^br-.*/'

# Email notifications
OBSERVIUM__email__enable=true
OBSERVIUM__email__backend=smtp
OBSERVIUM__email__smtp_host=smtp.example.com
OBSERVIUM__email__smtp_port=587
```

Translates to:

```php
$config['base_url'] = 'https://observium.example.com';
$config['web_mouseover'] = FALSE;
$config['web_show_locations'] = 1;
$config['ping']['retries'] = 5;
$config['poller-wrapper']['threads'] = 2;
$config['bad_if'][0] = 'docker0';
$config['bad_if'][1] = 'lo';
$config['bad_if_regexp'][0] = '/^veth.*/';
$config['bad_if_regexp'][1] = '/^br-.*/';
$config['email']['enable'] = TRUE;
$config['email']['backend'] = 'smtp';
$config['email']['smtp_host'] = 'smtp.example.com';
$config['email']['smtp_port'] = 587;
```

#### Validation

During startup, the config generator reports:

```text
INFO: Processing 45 OBSERVIUM__ environment variables
Configuration generated successfully!
```

To debug configuration mapping, set `SHOW_GENERATED_CONFIG_DURING_STARTUP=yes` in `.env` and check container logs. **Warning**: This exposes database credentials in logs.

You can also view the final configuration in Observium's web UI under **Global Settings** > **Full dump** or **Changed dump**.

### SNMP Device Import

Add devices to monitor by creating `observium/conf/snmp-devices.txt`:

```text
# Format: hostname|community|v2c|port|transport|description
192.168.1.1|public|v2c|161|udp|Router
192.168.1.10|secret|v2c|161|udp|Switch
```

Devices are automatically imported on container startup. Check logs:

```bash
docker compose logs httpd | grep "Importing SNMP devices"
```

To add devices after initial startup:

```bash
# Restart container to trigger import
docker compose restart httpd

# Or add manually via web UI: Devices > Add Device
```

## Scheduled Jobs

Ofelia scheduler manages background tasks:

| Job | Schedule | Description |
| --- | -------- | ----------- |
| **discover-all** | Every 6 hours | Full discovery of all devices |
| **discover-new** | Every 5 minutes | Discover new devices |
| **poll** | Every 5 minutes | Poll all devices for metrics |
| **cleanup-logs** | Daily at 05:13 | Clean up old log entries |
| **cleanup-rrds** | Daily at 04:47 | Clean up old RRD files |
| **smokeping-config** | Every 5 minutes | Regenerate Smokeping targets |
| **backup-rrd** | Daily | Backup RRD and Smokeping data |
| **backup-db** | Daily | Backup MariaDB database |

Backups are stored in `/backup/destination/` inside the container. The most recent 10 backups are retained.

To persist backups, map a host directory:

```yaml
# compose.override.yaml
services:
  httpd:
    volumes:
      - ./backups:/backup/destination
```

## Monitoring & Logs

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f httpd
docker compose logs -f mariadb
docker compose logs -f smokeping

# Filter by message type
docker compose logs httpd | grep "INFO:"
docker compose logs httpd | grep "WARNING:"
docker compose logs httpd | grep "ERROR:"

# Follow startup sequence
docker compose logs -f httpd | grep -E "(Attempt|Successfully|generated|initialized)"
```

### Health Checks

Check service status:

```bash
# Service overview
docker compose ps

# Detailed health status
docker compose ps httpd

# MariaDB ready check
docker compose exec mariadb mariadb -uroot -p${MARIADB_ROOT_PASSWORD} -e "SELECT 1"
```

### Container Resource Usage

```bash
# CPU and memory usage
docker stats

# Disk usage
docker compose exec httpd du -sh /opt/observium/rrd
docker compose exec mariadb du -sh /var/lib/mysql
```

## Troubleshooting

### Container Won't Start

**Symptoms**: Container exits immediately after startup

**Diagnosis**:

```bash
docker compose logs httpd | grep ERROR
```

**Common Causes**:

- **Missing environment variables**: Check for `ERROR: Required environment variable ... is not set`
  - Solution: Ensure `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `OBSERVIUM_ADMIN_USER`, and `OBSERVIUM_ADMIN_PASSWORD` are set in `.env`

- **Database connection failure**: Check for `ERROR: Failed to connect to database after 60 attempts`
  - Solution: Verify MariaDB is running: `docker compose ps mariadb`
  - Solution: Increase timeout: `DB_CONNECTION_TIMEOUT=120` in `.env`

- **Configuration generation failure**: Check for `ERROR: Failed to generate configuration after 3 attempts`
  - Solution: Check Python script syntax: `docker compose run --rm httpd python3 /usr/local/bin/generate_config.py`

### Database Initialization Fails

**Symptoms**: `ERROR: Database still not initialized and lock acquisition failed`

**Cause**: Multiple containers trying to initialize simultaneously (race condition)

**Solution**:

1. Stop all containers: `docker compose down`
2. Remove database volume: `docker volume rm docker-observium_observium-db`
3. Start single httpd instance: `docker compose up httpd`
4. Wait for "Database initialization complete"
5. Start remaining services: `docker compose up -d`

### Smokeping Not Working

**Diagnosis**:

```bash
# Check if Targets file exists
docker compose exec smokeping cat /etc/smokeping/config.d/Targets

# Check smokeping logs
docker compose logs smokeping

# Verify smokeping process
docker compose exec smokeping ps aux | grep smokeping
```

**Common Issues**:

- **Empty Targets file**: No devices configured for Smokeping
  - Solution: Add devices in Observium UI, wait 5 minutes for config regeneration

- **Smokeping not running**: Check for startup errors
  - Solution: Restart: `docker compose restart smokeping`

### Configuration Changes Not Applied

**Symptoms**: Changed `.env` but Observium still uses old config

**Solution**:

```bash
# Restart container to regenerate config
docker compose restart httpd

# Verify config regeneration in logs
docker compose logs httpd | grep "Configuration generated"

# View generated config (⚠️ contains secrets)
SHOW_GENERATED_CONFIG_DURING_STARTUP=yes docker compose up httpd
```

### Web Interface Shows Blank Page

**Diagnosis**:

```bash
# Check Apache logs
docker compose logs httpd | grep -E "(error|Error|ERROR)"

# Check PHP errors
docker compose exec httpd cat /var/log/apache2/error.log

# Verify database connection
docker compose exec httpd mariadb -u${DB_USER} -p${DB_PASSWORD} -h mariadb ${DB_NAME} -e "SHOW TABLES"
```

**Common Causes**:

- **Database not initialized**: No tables in database
  - Solution: Check initialization logs: `docker compose logs httpd | grep initialization`

- **Wrong base_url**: Config doesn't match accessed URL
  - Solution: Set correct `OBSERVIUM__base_url` in `.env`

## Upgrading

To upgrade to a newer version of Observium:

### 1. Backup Current Data

```bash
# Create backup directory
mkdir -p backups/$(date +%Y%m%d)

# Backup database
docker compose exec mariadb mariadb-dump -uroot -p${MARIADB_ROOT_PASSWORD} ${DB_NAME} | gzip > backups/$(date +%Y%m%d)/db_backup.sql.gz

# Backup RRD files
docker compose exec httpd tar czf /tmp/rrd_backup.tar.gz /opt/observium/rrd
docker compose cp httpd:/tmp/rrd_backup.tar.gz backups/$(date +%Y%m%d)/rrd_backup.tar.gz
```

### 2. Update Repository

```bash
git pull origin master
```

### 3. Rebuild Images

```bash
docker compose build --no-cache
```

### 4. Restart Services

```bash
docker compose down
docker compose up -d
```

### 5. Verify Upgrade

```bash
# Check version
docker compose logs httpd | grep "VERSION:"

# Watch for migration messages
docker compose logs -f httpd

# Verify web interface loads
curl -I https://${OBSERVIUM_FQDN}
```

## Development

### Project Scope

This project is optimized for specific monitoring needs and intentionally excludes:

- RANCID integration
- CollectD support
- rrdcached
- ARM64 support

**Pull Requests**: Bugfix PRs are welcome. Feature requests will be considered on a case-by-case basis.

### Recent Improvements

**Version 24.12** (Current)

- Updated to Observium Community Edition 24.12
- **Security**: Replaced `eval` with safe indirect expansion
- **Reliability**: Database initialization locking prevents race conditions
- **Observability**: Enhanced logging with INFO/WARNING/ERROR messages
- **Containers**: Graceful shutdown handling (SIGTERM)
- **Configuration**: Improved type conversion and validation
- **Error Handling**: Retry logic for config generation

### Building Locally

```bash
# Build all images
docker compose build

# Build specific service
docker compose build httpd

# Build without cache
docker compose build --no-cache

# Test build
docker compose up -d
docker compose logs -f
```

## Contributing

Found a bug? Please [open an issue](https://github.com/trick77/docker-observium/issues).

## License

[MIT License](LICENSE) - See LICENSE file for details

## Acknowledgments

- [Observium](https://www.observium.org/) - Network monitoring platform
- [Ofelia](https://github.com/mcuadros/ofelia) - Docker job scheduler
- [Smokeping](https://oss.oetiker.ch/smokeping/) - Latency monitoring
- All contributors to this project
