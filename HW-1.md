# HW-1: Containerize a Small App

**Course:** CENG413 · **Week assigned:** 4 (13 October 2026) · **Due:** [before the lecture on 20 October 2026] · **Submission:** [LMS / repository link, to be confirmed] · **Pairs allowed:** [no]

## Goal

Take a small web application and package it as a Docker image that anyone can build and run in the same way. Show that you understand *why* each line of your Dockerfile is there.

## The application

Choose one:

- Your own small web app (any language) with at least two endpoints, **or**
- The lab app from class, extended with one new endpoint of your choice.

The app must listen on a port, answer a `/health` request, and read at least one setting from an **environment variable**.

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
- [ ] Dependencies are installed **before** the application code is copied (cache-friendly order).
- [ ] The container runs as a **non-root** user.
- [ ] **No secrets** (passwords, keys, tokens) are inside the image or the repository.
- [ ] A `.dockerignore` keeps unneeded files out of the image.
- [ ] The app follows the README: the commands work exactly as written.
- [ ] Configuration comes from environment variables.

## Suggested grading (draft, adjust with the course team)

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
- Use a multi-stage build to make the final image smaller.
- Add a `HEALTHCHECK` instruction.

## Notes on using AI assistants

[You may use an AI assistant, but you must understand and be able to explain every line you submit. You may be asked to explain your Dockerfile in class.]

## Hints

- Start from the Dockerfile in the lab and change it step by step.
- Run `docker history <image>` to see your layers.
- If something fails, read the error message first, then search it, then ask.
