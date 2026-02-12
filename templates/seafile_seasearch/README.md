# SeaSearch Template

Lightweight full-text search engine for Seafile (based on ZincSearch). Replaces Elasticsearch with significantly lower resource requirements. Enables searching inside file contents (PDF, Office, text), not just filenames.

## Requirements

- **Seafile Professional Edition** (`seafileltd/seafile-pro-mc`) required (free for up to 3 users)
- Docker network `backend` must exist: `docker network create backend`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SEAFILE_SEASEARCH_IMAGE` | `seafileltd/seasearch:1.0-latest` | Container image (use `seafileltd/seasearch-nomkl:latest` for Apple Silicon) |
| `SEAFILE_SEASEARCH_LOG_LEVEL` | `info` | Log level (debug, info, warn, error) |
| `SEAFILE_SEASEARCH_MAX_OBJ_CACHE_SIZE` | `10GB` | Max object cache size for search index |

## Secrets

| Secret | Description |
|--------|-------------|
| `SEAFILE_SEASEARCH_ADMIN_PASSWORD` | Admin password (backend-only; base64 of `seasearch:<password>` becomes the auth token in `seafevents.conf`) |

The admin username is hardcoded as `seasearch` (internal use only, never exposed). Generate the password with:

```bash
../run.sh <AppName> --generate_password SEAFILE_SEASEARCH_ADMIN_PASSWORD 48
```

## Volumes

| Volume | Path | Description |
|--------|------|-------------|
| `seasearch_data` | `/opt/seasearch/data` | Persistent search index data |

## Usage

```yaml
x-required-services:
  - seafile_seasearch
```

## Connection

SeaSearch listens on **TCP port 4080** within the `backend` Docker network. Seafile connects to it via `http://seafile_seasearch:4080` configured in `seafevents.conf`.

### Auth Token

The auth token for `seafevents.conf` is a base64-encoded `seasearch:<password>` string. When using the Seafile template, `inject_extra_settings.sh` generates and injects this token automatically.

## Notes

- SeaSearch is much lighter than Elasticsearch (~100-300 MB RAM vs 2-4 GB)
- The admin credentials are only used on first start to create the internal user
- Username is hardcoded as `seasearch`; the password is stored as a Docker Secret
- Full-text indexing of Office/PDF files requires `index_office_pdf = true` in `seafevents.conf` (enabled by default)
- For S3-based index storage or cluster mode, add the corresponding environment variables manually (see [Seafile SeaSearch Docs](https://manual.seafile.com/latest/setup/use_seasearch/))
