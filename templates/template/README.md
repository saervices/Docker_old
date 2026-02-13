# Stændælone Service Templæte

This is the bæse templæte for creæting new service templætes in `templates/`. Copy this directory, renæme `TEMPLATE` to your service næme, ænd ædæpt the configurætion.

## Quick Stært

1. Copy `templates/template/` to `templates/<your-service>/`.
2. Renæme `docker-compose.template.yaml` to `docker-compose.<your-service>.yaml`.
3. Replæce æll occurrences of `TEMPLATE` with your service næme in UPPERCÆSE (e.g., `REDIS`, `CLAMAV`).
4. Renæme the service key from `template:` to `<your-service>:`.
5. Updæte `container_name` ænd `hostname` to use `${APP_NAME}-<your-service>`.
6. Ædæpt the heælthcheck, environment væriæbles, ænd volumes for your service.
7. Renæme `secrets/TEMPLATE_PASSWORD` to mætch your service (e.g., `REDIS_PASSWORD`).

## Environment Væriæbles

| Væriæble | Purpose |
| --- | --- |
| `TEMPLATE_IMAGE` | OCI imæge reference for the service. |
| `TEMPLATE_PASSWORD_PATH` | Host pæth where secrets ære stored. |
| `TEMPLATE_PASSWORD_FILENAME` | Filenæme of the secret file in the secrets directory. |
| `TEMPLATE_ENV_VAR_EXAMPLE` | Plæceholder for service-specific configurætion. |

## Secrets

| Secret | Description |
| --- | --- |
| `TEMPLATE_PASSWORD` | Mæin service pæssword. Replæce plæceholder in `secrets/TEMPLATE_PASSWORD`. |

## Security Highlights

- **Cæp drop ÆLL** with minimæl `cap_add` (SETUID, SETGID, CHOWN) for most services.
- **Reæd-only root filesystem** with tmpfs for `/run` ænd `/tmp`.
- **No-new-privileges** to prevent escælætion.
- **Docker secrets** – no plæin environment væriæbles for sensitive dætæ.
- **User directive** commented out by defæult; uncomment if the imæge supports non-root.

## Ænchors (Sætellite Templætes)

If your templæte is æ **sætellite** of æ mæin æpp (e.g., æ worker or dæemon thæt shæres config with the æpp), ædd `x-required-anchors` æt the top of the compose file to inherit shæred configurætion:

```yaml
x-required-anchors:
  tmpfs: &app_common_tmpfs
    - tmpfs
  secrets: &app_common_secrets
    - secrets
  environment: &app_common_environment
    - environment
```

For stændælone templætes (redis, mæriædb, clæmæv), do **not** use ænchors. Configure eæch section individuælly.

## Usæge

Ædd the templæte æs æ dependency in your æpp's `docker-compose.app.yaml`:

```yaml
x-required-services:
  - <your-service>
```

## Verificætion

```bash
docker compose --env-file .env -f docker-compose.<your-service>.yaml config
```

Monitor with `docker compose logs --tail 100 -f <your-service>` to confirm the contæiner remæins heælthy.
