# CENG413 Lab App (Week 4: Docker Essentials)

A tiny Flask web service used in the Week 4 Docker lab and as the starting point for HW-1.

| Endpoint | What it does | Stateless? |
|---|---|---|
| `/health` | returns `{"status": "ok"}` | yes |
| `/greet?name=Ada` | returns a greeting | yes |
| `/visit` | counts visits, saved in a file | no, on purpose |

## Quick start

```bash
git clone https://github.com/mehmet-kahraman/okan-uni-ceng413.git
cd [repo folder]

# slow version first, then the improved one
docker build -f Dockerfile.v1 -t lab:v1 .
docker build -t lab:v2 .

docker run -d --name lab -p 8000:8000 lab:v2
curl http://localhost:8000/health
```

## Files

| File | Purpose |
|---|---|
| `app.py` | the application |
| `test_app.py` | unit tests (`pip install pytest flask`, then `pytest`) |
| `requirements.txt` | pinned dependencies |
| `Dockerfile.v1` | naive Dockerfile (slow rebuilds, runs as root) |
| `Dockerfile` | improved Dockerfile (pinned slim base, cache-friendly, non-root) |
| `.dockerignore` | files kept out of the image |
| `LAB-GUIDE.md` | step-by-step lab (English) |
| `LAB-GUIDE.tr.md` | step-by-step lab (Turkish) |

## Configuration (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `APP_GREETING` | `Hello` | word used by `/greet` |
| `DATA_DIR` | `/data` | folder where `/visit` stores its counter |

Start with **LAB-GUIDE.md** (English) or **LAB-GUIDE.tr.md** (Turkish).
