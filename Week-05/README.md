# CENG413 Week 5 Lab: Docker Compose

The Week 4 service, now with a Redis container next to it. The two containers find each other **by name**.

| Endpoint | What it does |
|---|---|
| `/health` | `{"status": "ok"}` |
| `/greet?name=Ada` | greeting (word from `APP_GREETING`) |
| `/visit` | counter kept in Redis when `REDIS_HOST` is set, otherwise in a file |
| `/whoami` | hostname of the container that answered |

## Quick start

```bash
git pull
cd Week-05
docker compose up -d --build
docker compose ps                    # app and cache must both be Up
curl http://localhost:8000/visit
docker compose down -v
```

If `app` is not running: `docker compose ps -a` and `docker compose logs app --tail=30`. See the Troubleshooting table in `LAB-GUIDE.md`.

## Files

| File | Purpose |
|---|---|
| `compose.yaml` | the two services, the volume, the healthcheck |
| `Dockerfile` | the improved Week 4 Dockerfile (pinned, cache-friendly, non-root) |
| `app.py`, `test_app.py`, `requirements.txt` | the application and its unit tests |
| `.dockerignore`, `.gitignore` | keep files out of the image / out of Git |
| `LAB-GUIDE.md`, `LAB-GUIDE.tr.md` | step-by-step lab (English / Türkçe) |

## Configuration (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `APP_GREETING` | `Hello` | word used by `/greet` |
| `REDIS_HOST` | unset | Redis host name (`cache` in Compose) |
| `REDIS_PORT` | `6379` | Redis port |
| `DATA_DIR` | `/data` | folder for the file counter (without Redis) |

Run the tests: `pip install -r requirements.txt pytest`, then `pytest`.
