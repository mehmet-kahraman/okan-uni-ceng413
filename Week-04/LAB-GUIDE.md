# Week 4 Lab: Build, Run, Break, Fix

**Course:** CENG413 · **Topic:** Docker essentials · **Time:** about 35 minutes · **Work in pairs if you like.**

By the end of this lab you will have:

- built a Docker image from a Dockerfile,
- run it as a container and called its endpoints,
- seen the build cache save time,
- lost data on purpose, and then kept it with a volume,
- (bonus) called one container from another by name.

> **Rule:** read the error message before you ask for help. Most errors tell you exactly what is wrong.

## 0. Check your setup

Open a terminal (PowerShell on Windows) and run:

```bash
docker version
```

You should see both a *Client* and a *Server* section. If the Server part is missing, start Docker Desktop and wait until it says "running".

> **Windows note:** in PowerShell, `curl` is an alias of another command. Use `curl.exe` instead, or just open the address in your browser.

## 1. Get the code

Go into the folder you cloned (the one with `app.py` and two Dockerfiles). Its name is the repository name:

```bash
cd <repository-folder>
```

Look at the files. Which one is the application? Which ones are Dockerfiles? What does `.dockerignore` do?

The app is a small web service with three endpoints:

| Endpoint | What it does | Stateless? |
|---|---|---|
| `/health` | returns `{"status": "ok"}` | yes |
| `/greet?name=Ada` | returns a greeting | yes |
| `/visit` | counts visits, saved in a file | **no, on purpose** |

## 2. Build the slow version (Dockerfile.v1)

```bash
docker build -f Dockerfile.v1 -t lab:v1 .
```

- `-f` chooses the Dockerfile, `-t` gives the image a name and tag, `.` is the build context.
- Note how long it took (first build downloads a lot).

Check the image:

```bash
docker images lab
```

## 3. Run it and call it

```bash
docker run -d --name lab1 -p 8000:8000 lab:v1
```

Open these in your browser, or use curl:

```bash
curl http://localhost:8000/health
curl "http://localhost:8000/greet?name=YourName"
```

Look at the logs and the running container:

```bash
docker ps
docker logs lab1
```

Clean up:

```bash
docker rm -f lab1
```

> **Port already in use?** Change the left number: `-p 8001:8000`, and use `localhost:8001`.

## 4. Feel the cache (a fair test)

Goal: compare the two Dockerfiles **fairly**. Same machine, same base images, same code change. Open both Dockerfiles side by side first. What is different? (Look at the first line, the order of `COPY` and `RUN`, and the user.)

**4a. Baseline: build both from scratch.** `--no-cache` makes every step run again, so both builds start from the same point. The base images are already on your computer, so this measures the Dockerfile and not your Wi-Fi.

macOS / Linux:

```bash
time docker build --no-cache -f Dockerfile.v1 -t lab:v1 .
time docker build --no-cache -t lab:v2 .
```

Windows PowerShell:

```powershell
Measure-Command { docker build --no-cache -f Dockerfile.v1 -t lab:v1 . | Out-Default }
Measure-Command { docker build --no-cache -t lab:v2 . | Out-Default }
```

Write the two times in the results table below.

**4b. Change the code, then rebuild both.** Add a comment line to `app.py`. This changes the file without breaking the app.

macOS / Linux:

```bash
echo "# change 1" >> app.py
```

Windows PowerShell:

```powershell
Add-Content app.py "# change 1"
```

Rebuild both. `--progress=plain` prints every step, so you can see which ones say `CACHED`:

```bash
time docker build --progress=plain -f Dockerfile.v1 -t lab:v1 .
time docker build --progress=plain -t lab:v2 .
```

(On PowerShell, wrap each build in `Measure-Command { ... | Out-Default }` as above.)

Look at the output of each build:

- Which steps say `CACHED`?
- In which build did `pip install` run again?

Want more evidence? Repeat 4b with `# change 2`.

**4c. Compare the images.**

```bash
docker image ls lab
docker history lab:v1
docker history lab:v2
```

Example from the instructor's laptop:

```
IMAGE      ID             DISK USAGE   CONTENT SIZE
lab:v1     a43a57dfbd87   1.63GB       407MB
lab:v2     274e7f106ce6   226MB        49.1MB
```

Same application, and v2 is about **7 times smaller** on disk (and 8 times less to download). Only a few lines of the Dockerfile are different. *Disk usage* is the space on your disk. *Content size* is the compressed data you would download or upload to a registry. Older Docker versions show a single `SIZE` column.

**Fill in your results:**

| Test | v1 (`Dockerfile.v1`) | v2 (`Dockerfile`) |
|---|---|---|
| 4a baseline, time with `--no-cache` | | |
| 4b rebuild after code change, time | | |
| 4b steps marked `CACHED` | | |
| Image size (`docker image ls lab`) | | |

**What you should see:**

- **Baseline (4a):** similar times, because every step runs in both builds.
- **After a code change (4b):** in v1 `pip install` runs again. In v2 the `pip install` step says `CACHED`.
- **Size (4c):** v2 is several times smaller.

> **Not seeing a big time difference?** That is normal here. This app has only two small dependencies, so reinstalling them takes a few seconds. In a real project with dozens of libraries, that step can take minutes, and the cache saves all of it. In this lab, the strongest evidence is the `CACHED` lines and the image size.

**4d. Configuration from outside the image.** Run v2 with an environment variable:

```bash
docker run -d --name lab2 -p 8000:8000 -e APP_GREETING=Merhaba lab:v2
curl "http://localhost:8000/greet?name=YourName"
docker rm -f lab2
```

The image did not change, but the behavior did. This is how we configure containers.

## 5. Lose data, then keep it

**5a. Data inside the container.**

```bash
docker run -d --name lab2 -p 8000:8000 lab:v2
curl http://localhost:8000/visit
curl http://localhost:8000/visit
curl http://localhost:8000/visit
```

You should get 1, 2, 3. Now remove the container and start a new one:

```bash
docker rm -f lab2
docker run -d --name lab2 -p 8000:8000 lab:v2
curl http://localhost:8000/visit
```

What number do you get? Where did the data go?

**5b. Data in a volume.**

```bash
docker rm -f lab2
docker run -d --name lab3 -p 8000:8000 -v labdata:/data lab:v2
curl http://localhost:8000/visit
curl http://localhost:8000/visit
curl http://localhost:8000/visit
docker rm -f lab3
docker run -d --name lab3 -p 8000:8000 -v labdata:/data lab:v2
curl http://localhost:8000/visit
```

This time the number continues (4). The container was disposable, the data was not. Look at your volumes:

```bash
docker volume ls
```

## 6. Bonus: containers talking by name

```bash
docker rm -f lab3
docker network create app-net
docker run -d --name api --network app-net lab:v2
docker run --rm --network app-net curlimages/curl curl -s http://api:8000/health
```

The second container reached the first one using the name `api`. We never published a port.

## 7. Clean up

```bash
docker rm -f api lab1 lab2 lab3
docker network rm app-net
docker volume rm labdata
```

## Reflection questions (discuss with your partner)

1. Why did we copy `requirements.txt` before the rest of the code?
2. What is the difference between an image and a container, in your own words?
3. Why is the `/visit` endpoint a problem if we want to run five copies of this app? How would you fix the design?
4. Which items from the quality checklist does `Dockerfile` (v2) apply that `Dockerfile.v1` does not?
5. Why were the baseline times similar, but the rebuild times different? What does the `CACHED` word tell you?

## Troubleshooting

| Problem | Likely cause and fix |
|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop is not running. Start it and wait. |
| `port is already allocated` | Another program uses that port. Change the left number in `-p`. |
| `name is already in use` | Old container exists. Run `docker rm -f <name>`. |
| `permission denied` (Linux) | Use `sudo`, or add your user to the `docker` group. |
| Build is very slow | First build downloads the base image. Later builds are faster. |
| `curl` does not work (Windows) | Use `curl.exe` or your browser. |
