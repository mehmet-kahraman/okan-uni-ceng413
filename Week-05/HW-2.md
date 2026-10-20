# HW-2: Two Services with Docker Compose

**Course:** CENG413 · **Week assigned:** 5 (20 October 2026) · **Due:** before class on Tuesday, 27 October 2026, 14:00 *(proposed, confirm)* · **Submission:** same place as HW-1 · **Individual work** (no pairs) · **AI assistants allowed** (same rule as HW-1)

## Goal

Run your application **together with a second service** (a database or a cache) using Docker Compose. Show that the two services find each other **by name**, that your app container is **stateless**, and that no secrets are stored in the repository.

## What to build

Start from **your HW-1 app**, or from the Week 5 lab app. Any language is fine (compiled languages: use your multi-stage Dockerfile from HW-1).

Your `compose.yaml` must have:

1. A service `app`, built from your own `Dockerfile`.
2. A **second service** that your app really uses. Examples: Redis, PostgreSQL, MySQL, MongoDB. Use an official image with a **pinned tag** (no `latest`).
3. A **named volume** for the second service's data.
4. A **healthcheck** on the second service, and `depends_on` with `condition: service_healthy` for the app.
5. Configuration through **environment variables**. The app connects to the other service by its **service name** (not an IP address, not `localhost`).

The app must keep **some state in the second service** (for example a counter, a list of notes, or a to-do list). The app container itself must not store data on its own disk.

## Secrets

If your second service needs a password (PostgreSQL does), do **not** write it in `compose.yaml` or in the code. Use a `.env` file that is listed in `.gitignore`, and commit a `.env.example` with fake values. Reading `.env` in Compose looks like this: `POSTGRES_PASSWORD: ${DB_PASSWORD}`.

## What to deliver

A Git repository (or zip) containing:

1. The application source code and its `Dockerfile` and `.dockerignore`.
2. `compose.yaml`.
3. `.env.example` (only if you use secrets) and a `.gitignore` that excludes `.env`.
4. `README.md`: how to start the whole system in five lines or less (exact commands).
5. A screenshot showing `docker compose ps` (both services running, the second one healthy) and one request that proves the state works.
6. `ANSWERS.md` with short answers (3 to 6 sentences each) to the questions below.

## Written questions (ANSWERS.md)

1. Your app calls the second service by name. How does that work, and why does the same name not work between two containers on the default `docker run` network?
2. Which of your services is stateless and which is not? Show the evidence: what did you do, and what happened to your data (for example `docker compose rm -sf app` and then `docker compose down`, and `docker compose down -v`)?
3. Where should a database password come from, and why is it a problem to commit it to Git, even in a private repository?

## Quality requirements (what we check)

- [ ] `docker compose up -d --build` starts the whole system from a **clean clone**.
- [ ] Both services run. The second service is **healthy**. The app starts only after it.
- [ ] The app reaches the other service by **service name**.
- [ ] Data survives `docker compose rm -sf app` and `docker compose down`, and is gone after `docker compose down -v` (you tested and wrote it in ANSWERS.md).
- [ ] Images are **pinned** (no `latest`) and the app still runs as a **non-root** user (HW-1 rules still apply).
- [ ] **No secrets** in the repository (`.env` is ignored, `.env.example` has fake values).
- [ ] The README commands work exactly as written.

## Grading

| Part | Points |
|---|---|
| Compose system starts and works as documented | 30 |
| Quality checklist (names, healthcheck, volume, pinning, non-root, no secrets) | 30 |
| README and screenshot | 10 |
| Written answers | 20 |
| Code and repository hygiene | 10 |
| **Total** | **100** |

## Bonus (optional)

- Run a local registry (`registry:2`), push your app image to it, and make `compose.yaml` use `image: localhost:5000/...` instead of `build:`. Write down what changed.
- Add a third service (for example a small admin page or a reverse proxy).
- Run three copies with `docker compose up -d --scale app=3` (remove the fixed host port `8000:8000` first, or the copies fight for the same port). Explain what happens to your data and why state belongs outside the app.

## Notes on using AI assistants

You may use an AI assistant. You must understand and be able to explain every line you submit, and you may be asked to explain your `compose.yaml` in class. In `ANSWERS.md`, add one or two sentences about how you used an assistant. Your written answers must be in your own words.

## Hints

- Start from `Week-05/compose.yaml` and change it step by step.
- `docker compose logs <service>` is your best friend. Read the error first, then search it, then ask.
- `docker compose down -v` deletes volumes. Use it on purpose, not by accident.
- The second service may need a few seconds. That is exactly what the healthcheck is for.
