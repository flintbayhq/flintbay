# Upgrading Flintbay

Flintbay uses a single Docker image with an embedded database. Upgrades are simple: pull the new image and restart.

## Standard Upgrade

```bash
# 1. Create a backup (recommended)
docker exec flintbay /usr/local/bin/backup.sh

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

All data lives in the `flintbay_data` Docker volume:
- PostgreSQL database
- Redis persistence (RDB snapshots)
- JWT secret key
- PostgreSQL password
- Backup files

As long as you don't delete the volume, your data survives any upgrade — with one
exception, for volumes first created before 2026-07-25. See
[Volumes created before 2026-07-25](#volumes-created-before-2026-07-25).

## Breaking Changes

### Volumes created before 2026-07-25

During alpha, the migration history was squashed into a single baseline and
numbering restarted. Revision numbers before and after that change therefore mean
different migrations, and the database records only the number. A volume first
created before 2026-07-25 cannot be upgraded: continuing would either fail part-way
or, worse, skip migrations silently and leave the schema incomplete.

Startup now detects this and stops before changing anything, with a message naming
the recorded version. If you see it, nothing has been damaged — the old container
image still runs against that volume.

To keep your data, export what you need through the API while running the old
image, then start a current release on a fresh volume and re-import. To discard it,
remove the volume and start clean:

```bash
docker compose down
docker volume rm flintbay_data
docker compose up -d
```

A PostgreSQL dump taken from the old volume is **not** a shortcut here: it restores
the old schema, which is what the guard refuses. The export has to go through the
API.

Volumes created on or after 2026-07-25 upgrade normally, and this will not apply to
any future release — numbering is stable now.

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

### `FLINTBAY_SUPERADMIN_USERNAMES` was replaced

It named a comma-separated set of accounts and configured nothing else, which left
the deployment administrator unrecoverable without a shell if its password was
lost. It is replaced by two variables:

```yaml
environment:
  FLINTBAY_SUPERADMIN_USERNAME: admin         # one account, not a list
  FLINTBAY_SUPERADMIN_PASSWORD: change-me     # defaults to "admin"
```

The old name is **not** accepted as an alias, because its meaning changed. Startup
logs a warning while it is still present in the environment, so a Compose file that
sets it says so at boot rather than at the first unexplained 403.

Upgrading is safe without editing anything: both new variables default to `admin`,
and the first boot **adopts** an existing `admin` account without touching its
password. If your administrator account has a different name, set
`FLINTBAY_SUPERADMIN_USERNAME` to it before restarting — otherwise that account keeps
working but stops being the deployment administrator, and an `admin` account is
created alongside it.

From then on the account is reconciled with the environment on every start: created
if absent, reactivated if disabled, and its password reapplied whenever
`FLINTBAY_SUPERADMIN_PASSWORD` changes. That last part is the recovery path — lost the
password, change the variable and restart.

## Backup Before Upgrade

```bash
# Create backup
docker exec flintbay /usr/local/bin/backup.sh

# Backups are stored in the volume at /var/lib/flintbay/backups/
# List backups:
docker exec flintbay ls -la /var/lib/flintbay/backups/
```

Backups are auto-pruned after 7 days.

## Restore from Backup

The dump contains no `DROP` statements, so the schema has to be cleared first —
restoring straight over a populated database fails on the first `CREATE`. Both
commands read the container's own datastore credentials, so they work whether
PostgreSQL is embedded or external:

```bash
docker exec flintbay sh -c '. /etc/flintbay-datastore.env; PGPASSWORD="$PG_PASS" \
  psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_NAME" \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"'

docker exec flintbay sh -c '. /etc/flintbay-datastore.env; gzip -dc \
  /var/lib/flintbay/backups/pg_YYYYMMDD_HHMMSS.sql.gz | PGPASSWORD="$PG_PASS" \
  psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_NAME" -v ON_ERROR_STOP=1'

docker restart flintbay
```

`ON_ERROR_STOP=1` matters: without it `psql` reports success after skipping
statements it could not apply.

## Pinning a Version

`latest` moves when a stable version is published, and pulling it does not update
a running container — a locally cached image may be older than the tag suggests.
Pin an explicit version in production:

```yaml
services:
  flintbay:
    image: ghcr.io/flintbayhq/flintbay:0.2.0
```

Version tags are immutable: `0.2.0` is never rebuilt or overwritten. For a
guarantee that survives even a registry mistake, pin the index digest instead:

```yaml
    image: ghcr.io/flintbayhq/flintbay@sha256:...
```

Resolve the digest for a tag with `docker buildx imagetools inspect
ghcr.io/flintbayhq/flintbay:0.2.0`. When you pin, update the pin deliberately
whenever a security release is published.

### Verifying the image

Each published version is signed with cosign through GitHub OIDC:

```bash
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github\.com/flintbayhq/flintbay-core/\.github/workflows/build\.yml@' \
  ghcr.io/flintbayhq/flintbay:0.2.0
```

After upgrading, confirm the container is running what you intended:

```bash
docker exec flintbay cat /app/release.json
```

## ARM64 (Jetson / Raspberry Pi)

Nothing to select. Each version is one multi-architecture index covering
`linux/amd64` and `linux/arm64`, so both architectures share the tag and the
digest, and Docker pulls the variant matching the host. The upgrade procedure at
the top of this page is the whole story on ARM64 too.

If an ARM host reports `no matching manifest`, it is pulling through something
that flattened the index — check for a mirror or a proxy in front of the
registry, and confirm the platform with:

```bash
docker buildx imagetools inspect ghcr.io/flintbayhq/flintbay:0.2.0
```

## Troubleshooting Upgrades

| Problem | Fix |
|---------|-----|
| Container won't start after upgrade | Check logs: `docker logs flintbay` — usually a migration issue |
| "cannot be upgraded by this version" | The volume predates 2026-07-25. See [Volumes created before 2026-07-25](#volumes-created-before-2026-07-25) — do not restart, it will not help |
| "relation does not exist" during migration | Restarting repeats the same failure. Check `docker logs flintbay` for the recorded schema version and compare against the section above |
| Lost data after upgrade | You deleted the volume. Restore from backup if available |
| Want to rollback | Stop container, change image tag to previous version, start |
