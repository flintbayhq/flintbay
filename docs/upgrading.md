# Upgrading RCH

RCH uses a single Docker image with an embedded database. Upgrades are simple: pull the new image and restart.

## Standard Upgrade

```bash
# 1. Create a backup (recommended)
docker exec rch /usr/local/bin/backup.sh

# 2. Pull the latest image
docker compose pull

# 3. Restart with the new image
docker compose up -d
```

That's it. Database migrations run automatically on startup. `docker compose up -d`
recreates the container when its image or environment changes; `docker restart`
alone does not apply new environment values.

## What Happens on Startup

1. PostgreSQL starts (embedded in the container)
2. Redis starts (embedded in the container)
3. Database migrations run automatically (Alembic)
4. API server starts

## Data Persistence

All data lives in the `rch_data` Docker volume:
- PostgreSQL database
- Redis persistence (RDB snapshots)
- JWT secret key
- PostgreSQL password
- Backup files

As long as you don't delete the volume, your data survives any upgrade.

## Breaking Changes

### The image now publishes a live-video port

Camera Sources are delivered as WebRTC, which cannot share the HTTP port, so the
image exposes `8189` (UDP and TCP) in addition to `19580`. Nothing breaks if you
upgrade without changing your Compose file — the port simply is not published,
and camera playback uses the LL-HLS fallback over `19580` with about a second
more latency. To get the low-latency path, add:

```yaml
    ports:
      - "19580:19580"
      - "8189:8189/udp"
      - "8189:8189/tcp"
```

and open the port in the host firewall or cloud security group. See
[Live video](environment.md#live-video).

### `RCH_SUPERADMIN_USERNAMES` was replaced

It named a comma-separated set of accounts and configured nothing else, which left
the deployment administrator unrecoverable without a shell if its password was
lost. It is replaced by two variables:

```yaml
environment:
  RCH_SUPERADMIN_USERNAME: admin         # one account, not a list
  RCH_SUPERADMIN_PASSWORD: change-me     # defaults to "admin"
```

The old name is **not** accepted as an alias, because its meaning changed. Startup
logs a warning while it is still present in the environment, so a Compose file that
sets it says so at boot rather than at the first unexplained 403.

Upgrading is safe without editing anything: both new variables default to `admin`,
and the first boot **adopts** an existing `admin` account without touching its
password. If your administrator account has a different name, set
`RCH_SUPERADMIN_USERNAME` to it before restarting — otherwise that account keeps
working but stops being the deployment administrator, and an `admin` account is
created alongside it.

From then on the account is reconciled with the environment on every start: created
if absent, reactivated if disabled, and its password reapplied whenever
`RCH_SUPERADMIN_PASSWORD` changes. That last part is the recovery path — lost the
password, change the variable and restart.

## Backup Before Upgrade

```bash
# Create backup
docker exec rch /usr/local/bin/backup.sh

# Backups are stored in the volume at /var/lib/rch/backups/
# List backups:
docker exec rch ls -la /var/lib/rch/backups/
```

Backups are auto-pruned after 7 days.

## Restore from Backup

If something goes wrong:

```bash
docker exec rch bash -c 'gunzip -c /var/lib/rch/backups/pg_YYYYMMDD_HHMMSS.sql.gz | \
  PGPASSWORD=$(cat /var/lib/rch/.postgres_password) \
  /usr/lib/postgresql/17/bin/psql -h localhost -U rch -d rch'
```

## Pinning a Version

If you want to stay on a specific version instead of `latest`:

```yaml
services:
  rch:
    image: ghcr.io/kwaadx/rch:1.2.0  # pin to specific version
```

## ARM64 (Jetson / Raspberry Pi)

ARM64 is published under a separate tag. Architecture tags may be built and
published at different times, so verify the intended release/digest before
pulling; do not assume `latest-arm64` is synchronized with amd64 `latest`.
Then select the ARM64 tag explicitly:

```yaml
services:
  rch:
    image: ghcr.io/kwaadx/rch:latest-arm64
```

```bash
docker compose pull
docker compose up -d
```

## Troubleshooting Upgrades

| Problem | Fix |
|---------|-----|
| Container won't start after upgrade | Check logs: `docker logs rch` — usually a migration issue |
| "relation does not exist" | Migration didn't run — restart the container |
| Lost data after upgrade | You deleted the volume. Restore from backup if available |
| Want to rollback | Stop container, change image tag to previous version, start |
