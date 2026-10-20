# Week 5 Lab: Services that find each other by name

**Goal:** run an app and a database as two containers, make them talk by **name**, and prove that the app container is **stateless**.

Time: about 35 minutes. Work with a partner in the lab (HW-2 is individual). Türkçe rehber: `LAB-GUIDE.tr.md`.

> Windows PowerShell: use `curl.exe` instead of `curl`. Everything else is the same.

## 0. Check your setup

```bash
docker version
docker compose version
```

You should see a Client and a Server, and a Compose version. If not, raise your hand.

Get the lab files (go to your clone of the course repository):

```bash
git pull
cd Week-05
```

## 1. Why names? (without Compose)

Containers get IP addresses that change. We want to say `cache`, not `172.18.0.2`.

**1a. Default network: no names.**

```bash
docker run -d --name cache redis:7-alpine
docker run --rm --entrypoint ping redis:7-alpine -c1 -W2 cache
```

The second command fails with `bad address 'cache'`. Remove the container:

```bash
docker rm -f cache
```

**1b. Your own network: names work.**

```bash
docker network create app-net
docker run -d --name cache --network app-net redis:7-alpine
docker run --rm --network app-net --entrypoint ping redis:7-alpine -c1 cache
```

Now `cache` answers with an IP address. A **user-defined network** has a small DNS server inside. Clean up:

```bash
docker rm -f cache
docker network rm app-net
```

Question for your partner: why was this not a problem with a single container in Week 4?

## 2. The same thing with Compose

Open `compose.yaml`. Find: the two services (`app`, `cache`), the volume `redisdata`, the `healthcheck`, and the line `REDIS_HOST: cache`. There is **no** network section. Compose creates one for us.

Start everything:

```bash
docker compose up -d --build
docker compose ps
```

You should see **two** services, `app` and `cache`, both `Up`. `docker compose ps` (like `docker ps`) shows only **running** containers. If `app` is missing, it started and then stopped. Find out why:

```bash
docker compose ps -a              # also shows stopped containers and their exit code
docker compose logs app --tail=30 # the app's output: the error is usually in the LAST lines
```

> **Two ways to read logs.** `docker compose logs <service>` uses the **service name** from `compose.yaml` (`app`, `cache`). `docker logs <container>` uses the **container name** from `docker ps -a` (for example `week-05-app-1`). Both show the same output. Add `-f` to follow the log live, `Ctrl+C` to stop.

If the last log line says `PermissionError: [Errno 13] Permission denied: '/app/app.py'`, see **Troubleshooting** at the end.

Call the app three times:

```bash
curl http://localhost:8000/visit
curl http://localhost:8000/visit
curl http://localhost:8000/visit
curl http://localhost:8000/whoami
```

You should see `"storage":"redis"` and the counter going 1, 2, 3. The app found Redis by the name `cache`.

Look inside:

```bash
docker compose logs app
docker compose logs cache --tail=5
docker logs <app-container-name>   # same as the first line; take the name from docker compose ps
docker network ls
```

In the `app` log you see gunicorn starting (`Listening at: http://0.0.0.0:8000`), and in the `cache` log Redis says `Ready to accept connections`. You can see a network named `<folder>_default` that Compose created.

## 3. Prove that the app is stateless

In Week 4 the counter was lost when we removed the container. Now the state lives in Redis, in a volume. Try three things and **predict the counter before each one**:

```bash
# A. Remove ONLY the app container and start it again
docker compose rm -sf app
docker compose up -d app
curl http://localhost:8000/visit
docker compose logs app --tail=5   # a NEW gunicorn start: this is a fresh container
```

```bash
# B. Stop and remove everything, but keep volumes
docker compose down
docker compose up -d
curl http://localhost:8000/visit
```

```bash
# C. Remove everything including the volume
docker compose down -v
docker compose up -d
curl http://localhost:8000/visit
```

Write your results here:

| Test | Counter you predicted | Counter you saw |
|---|---|---|
| A. remove app only | | |
| B. `down` | | |
| C. `down -v` | | |

What you should see: A continues the count, B continues the count, C starts again from 1. The **app** container is disposable. The **data** lives in the volume.

## 4. Configuration from outside

```bash
APP_GREETING=Merhaba docker compose up -d
curl "http://localhost:8000/greet?name=YourName"
```

(PowerShell: `$env:APP_GREETING="Merhaba"; docker compose up -d`.) The image did not change, but the behavior did.

## 5. Optional: your own registry

An image is only useful if others can get it. A **registry** stores images. We will run a tiny one on your own computer.

```bash
docker run -d --name registry -p 5000:5000 registry:2
docker build -t localhost:5000/ceng413/lab:v3 .
docker push localhost:5000/ceng413/lab:v3
curl http://localhost:5000/v2/_catalog
```

Delete the local image and pull it back:

```bash
docker rmi localhost:5000/ceng413/lab:v3
docker pull localhost:5000/ceng413/lab:v3
```

The name format is `registry-host:port/namespace/image:tag`. For Docker Hub it is `username/image:tag`. Pushing to Docker Hub or GitHub needs an account, so we only do that as a demo.

## 6. Clean up

```bash
docker compose down -v
docker rm -f registry
```

## Reflection questions (discuss with your partner)

1. Why did name resolution fail on the default network and work on `app-net`?
2. Which container is stateless here, and which one is not? How can you tell?
3. What is the difference between `docker compose down` and `docker compose down -v`?
4. `depends_on` with `condition: service_healthy` waits for the healthcheck. Why is "the container started" not the same as "the service is ready"?
5. If you ran three copies of the app behind one address, would the visit counter still be correct? Why?

## Troubleshooting

| Problem | What to try |
|---|---|
| `app` is not in `docker compose ps`, or shows `Exited` | It crashed at start. `docker compose ps -a` for the exit code, then `docker compose logs app --tail=30` and read the last lines |
| Log ends with `PermissionError: [Errno 13] Permission denied: '/app/app.py'` | The container runs as `appuser` (not root) and cannot read your files. macOS/Linux: run `chmod -R a+rX .` in the `Week-05` folder, then `docker compose up -d --build` |
| `port is already allocated` | Another container uses port 8000. `docker ps`, then `docker rm -f <name>` |
| `Cannot connect to the Docker daemon` | Start Docker Desktop and wait until it says running |
| App returns an error on `/visit` | `docker compose ps`: is `cache` healthy? `docker compose logs cache` |
| Compose says `no configuration file provided` | You are in the wrong folder. `cd Week-05` |
| Changes in `app.py` are not visible | `docker compose up -d --build` |
