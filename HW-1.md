# HW-1: Containerize a Small App

**Course:** CENG413 · **Week assigned:** 4 (13 October 2026) · **Due:** before class on Tuesday, 20 October 2026, 14:00 · **Submission:** [LMS / repository link, to be confirmed] · **Individual work** (no pairs)

## Goal

Take a small web application and package it as a Docker image that anyone can build and run in the same way. Show that you understand *why* each line of your Dockerfile is there.

## The application

Choose one:

- Your own small web app (any language) with at least two endpoints, **or**
- The lab app from class, extended with one new endpoint of your choice.

The app must listen on a port, answer a `/health` request, and read at least one setting from an **environment variable**.

> **Compiled languages (Java, .NET, Go, ...)?** You are welcome to use them. You must use a **multi-stage build** (see the section "If your language needs compiling" below). Interpreted languages (Python, Node.js, ...) can use a single stage.

## What to deliver

A Git repository (or zip) containing:

1. The application source code.
2. A `Dockerfile`.
3. A `.dockerignore`.
4. A `README.md` that explains in five lines or less how to build and run the app (exact commands).
5. A screenshot showing `docker images` and the running container answering a request.
6. A file `ANSWERS.md` with short answers (3 to 6 sentences each) to the questions below.

## Written questions (ANSWERS.md)

1. Explain the order of the instructions in your Dockerfile. What would happen to build time if you changed the order of two of them?
2. What happens to data written inside a container when the container is removed? How would you keep the data, and where should an application keep important state?
3. Why is the `latest` tag a risk for reproducibility? What did you use instead?

## Quality requirements (what we check)

- [ ] The image builds from a **clean clone** with one command.
- [ ] The base image version is **pinned** (no `latest`).
- [ ] Dependencies are installed **before** the application code is copied (cache-friendly order). For compiled languages: the dependency restore step (`dotnet restore`, `mvn dependency:go-offline`, `go mod download`) comes before copying the source.
- [ ] Compiled languages only: **multi-stage build**. The final image contains the runtime and the build output, **not** the SDK, compiler or source code.
- [ ] The container runs as a **non-root** user.
- [ ] **No secrets** (passwords, keys, tokens) are inside the image or the repository.
- [ ] A `.dockerignore` keeps unneeded files out of the image.
- [ ] The app follows the README: the commands work exactly as written.
- [ ] Configuration comes from environment variables.

## Grading

| Part | Points |
|---|---|
| Image builds and runs as documented | 30 |
| Quality checklist (pinning, order, non-root, no secrets, .dockerignore) | 30 |
| README and screenshot | 10 |
| Written answers | 20 |
| Code and repository hygiene | 10 |
| **Total** | **100** |

## Bonus (optional)

- Add a unit test and run it during the build or in a separate stage.
- Interpreted languages: use a multi-stage build to make the final image smaller (required for compiled languages).
- Add a `HEALTHCHECK` instruction.

## If your language needs compiling (Java, .NET, Go)

Compiling needs a big toolbox (SDK, Maven, compiler). Running needs only a small runtime. A **multi-stage build** uses two `FROM` lines: the first stage builds, the second stage copies only the result. The SDK stays behind, so the final image is smaller and has less to attack.

The rules from the lab still apply. Pin versions, restore dependencies before copying source, run as non-root, keep configuration in environment variables.

These are **starting points**. Change the versions and names to match your project. Pin the major version your project targets (for example `8.0` or `10.0` for .NET, `21` for Java).

**.NET**

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY *.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /out --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /out .
USER $APP_UID
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "YourApp.dll"]
```

**Java (Maven)**

```dockerfile
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -q dependency:go-offline
COPY src ./src
RUN mvn -q package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/target/*.jar app.jar
RUN useradd --create-home --uid 10001 appuser
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Go**

```dockerfile
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/app .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
EXPOSE 8080
ENTRYPOINT ["/app"]
```

Things to watch:

- **Port and environment variables.** Read the port and settings from the environment (Spring Boot reads `SERVER_PORT`; ASP.NET uses `ASPNETCORE_HTTP_PORTS`). Publish it with `-p 8080:8080`.
- **`.dockerignore`.** Exclude build output (`bin/`, `obj/`, `target/`) so your local build files do not enter the image.
- **Check your final image.** Run `docker image ls` and compare the size with your build stage. Add the result to ANSWERS.md as a short note (one or two sentences).
- **Tests in the build.** Do not skip tests in your real project. In this homework `-DskipTests` only keeps the build fast.
- **Stuck?** Ask in the lab. Compiled-language Dockerfiles are harder, so we are happy to help.

## Notes on using AI assistants

You may use an AI assistant. But you must understand and be able to explain every line you submit. You may be asked to explain your Dockerfile in class.

In `ANSWERS.md`, add one or two sentences: did you use an AI assistant, and for what (for example: "I asked it to explain a build error")? Your written answers must be in your own words.

## Hints

- Start from the Dockerfile in the lab and change it step by step.
- Run `docker history <image>` to see your layers.
- If something fails, read the error message first, then search it, then ask.
