# Week 8: From a green laptop to a trusted pipeline (CI/CD and DevSecOps)

**Class:** Tuesday 17 November 2026 (confirm). **Language:** slides in English, lab help in Turkish (`LAB-GUIDE.tr.md`).

## The idea in four lines

1. **CI/CD** means a machine runs the same steps every time: build, test, package, deploy.
2. A **quality gate** is a rule the machine enforces: if a stage is red, the change does not go on.
3. **DevSecOps** moves security checks *left*, into the same pipeline: code scan (SAST), dependency scan, secret scan, a list of what is inside (SBOM).
4. A check you can skip is not a gate. A check that blocks everything for no reason will be turned off. Both are failures.

## What is in this folder

| File | What it is |
|---|---|
| `LAB-GUIDE.md` | The lab, in English |
| `LAB-GUIDE.tr.md` | The lab, in Turkish |
| `setup-lab.sh` | Creates the lab project `ci-lab` (the same block is inside the guide) |

## The lab in one picture

```
lint -> test -> sast -> secrets -> deps -> docker  ==>  QUALITY GATE
```

You start with a red gate (six problems on purpose) and fix one stage at a time until it is green. Then you read the same pipeline written for GitHub Actions and make an SBOM.

## Tools used (all free)

ruff (lint), pytest and pytest-cov (tests and coverage), bandit (SAST), detect-secrets (secret scan), pip-audit (dependency scan and SBOM). Real teams use others for the same jobs; the ideas are the same.

## How this connects to the other weeks

| Earlier | Today |
|---|---|
| Week 4-5: Dockerfile, non-root, pinned base image | The `docker` stage checks exactly these rules |
| HW-1: `test_app.py` | The `test` stage runs tests like those, with a coverage gate |
| HW-2: `.env` not in Git | The `secrets` stage finds keys that slipped in |
| Week 6-7: Deployments, Secrets, probes | CD (deploy) is the last stage after the gate |

## Roadmap

- Week 8 (today): CI/CD stages, quality gates, DevSecOps checks.
- Next: VibeHub, where the platform runs a pipeline like this for your project.
