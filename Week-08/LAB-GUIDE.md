# Week 8 Lab: Build a pipeline, then make it green

**Time:** 40 minutes. **Work in pairs.** **Where:** a Killercoda Ubuntu playground in your browser (https://killercoda.com/playgrounds). Nothing to install on your computer.
**Nothing to hand in today.** This lab is not graded.

## What you will do

You get a small Flask app with six planted problems and a script, `pipeline.sh`, that runs the same stages a CI server runs: lint, test, SAST, secret scan, dependency scan, Dockerfile rules. At the start the **quality gate is red**. You fix one stage at a time until it is green.

**Rule of the lab: predict first.** Before you run a stage, say aloud to your partner whether it will pass or fail, and why.

| Stage | Tool | Question it answers |
|---|---|---|
| lint | ruff | Is the code clean (unused imports, unused variables)? |
| test | pytest + coverage | Does the code do what the tests say? Is enough of it tested? |
| sast | bandit | Does the source code contain risky patterns? |
| secrets | detect-secrets | Did someone commit a key or a password? |
| deps | pip-audit | Do our libraries have known vulnerabilities? |
| docker | two small rules | Is the base image pinned? Does it run as non-root? |

## Part 0: Set up (5 min)

Open a Killercoda Ubuntu playground. Then:

```bash
python3 --version
python3 -m venv .venv-lab && . .venv-lab/bin/activate
```

If `venv` is missing: `apt-get update && apt-get install -y python3-venv`, then repeat the second line.

Create the project. The long block below writes all files into a folder `ci-lab` (copy all of it, paste it once):

```bash
#!/usr/bin/env bash
# Creates the Week 8 lab project in ./ci-lab (a small Flask app with planted problems).
set -e
mkdir -p ci-lab && cd ci-lab
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'LAB_EOF'
# The same stages as pipeline.sh, now on a CI server (GitHub Actions).
name: CI

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.13"
          cache: pip
      - name: Install dependencies
        run: pip install -r requirements.txt -r requirements-dev.txt
      - name: Lint
        run: ./pipeline.sh lint
      - name: Test
        run: ./pipeline.sh test
      - name: SAST
        run: ./pipeline.sh sast
      - name: Secret scan
        run: ./pipeline.sh secrets
      - name: Dependency scan
        run: ./pipeline.sh deps
      - name: Dockerfile rules
        run: ./pipeline.sh docker

  build:
    needs: quality
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t ci-lab:${{ github.sha }} .
LAB_EOF
cat > .gitignore <<'LAB_EOF'
.venv/
__pycache__/
.pytest_cache/
.ruff_cache/
.coverage
.env
LAB_EOF
cat > Dockerfile <<'LAB_EOF'
FROM python:latest
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
LAB_EOF
cat > app.py <<'LAB_EOF'
"""CI lab app: a tiny Flask service. It has a few planted problems on purpose."""
import hashlib
import os
import sys

from flask import Flask, jsonify, request

app = Flask(__name__)

API_KEY = "AKIAIOSFODNN7EXAMPLE"


@app.get("/health")
def health():
    started = True
    return jsonify(status="ok")


@app.get("/square")
def square():
    try:
        n = int(request.args.get("n", ""))
    except ValueError:
        return jsonify(error="n must be an integer"), 400
    return jsonify(n=n, square=n * 2)


@app.get("/fingerprint")
def fingerprint():
    text = request.args.get("text", "")
    return jsonify(sha=hashlib.md5(text.encode()).hexdigest())


@app.get("/whoami")
def whoami():
    return jsonify(has_key=bool(API_KEY), env=os.environ.get("APP_ENV", "dev"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
LAB_EOF
cat > pipeline.sh <<'LAB_EOF'
#!/usr/bin/env bash
# A tiny local pipeline: the same stages a CI server would run.
# Every stage runs; the build FAILS at the end if any stage failed (the quality gate).
# Usage: ./pipeline.sh            (all stages)
#        ./pipeline.sh lint test  (only some stages)

set -u
cd "$(dirname "$0")" || exit 1

FAILED=()
RESULTS=()

stage() {  # stage NAME COMMAND...
  local name="$1"; shift
  echo
  echo "=== STAGE: $name ==="
  if "$@"; then
    RESULTS+=("PASS  $name")
  else
    RESULTS+=("FAIL  $name")
    FAILED+=("$name")
  fi
}

want() {  # want NAME: true if no stage list was given, or NAME is in it
  [ "$#" -eq 1 ] && return 0
  local n="$1"; shift
  for s in "$@"; do [ "$s" = "$n" ] && return 0; done
  return 1
}

stage_lint()    { ruff check . ; }
stage_test()    { python -m pytest --cov=app --cov-report=term-missing --cov-fail-under=80 -q ; }
stage_sast()    { bandit -q -r app.py -ll -f custom --msg-template "{relpath}:{line}  {test_id} {severity}: {msg}" ; }
stage_secrets() {
  # detect-secrets always exits 0, so we read its report and fail if anything was found.
  detect-secrets scan --all-files --exclude-files '(\.venv|\.git|\.pytest_cache|\.ruff_cache|__pycache__|tests)/.*' . > /tmp/ci-secrets.json || return 1
  python - <<'PY'
import json, sys
found = json.load(open("/tmp/ci-secrets.json"))["results"]
for path, items in found.items():
    for item in items:
        print(f"{path}:{item['line_number']}  {item['type']}")
sys.exit(1 if found else 0)
PY
}
stage_deps()    { pip-audit -r requirements.txt ; }
stage_docker()  {
  # Two cheap rules for the Dockerfile: a pinned base image, and a non-root user.
  local ok=0
  if grep -Eq '^FROM +[^ ]+:latest|^FROM +[^: ]+( |$)' Dockerfile; then
    echo "Dockerfile: base image is not pinned to a version tag"; ok=1
  fi
  if ! grep -Eq '^USER +[^ ]+' Dockerfile; then
    echo "Dockerfile: no USER line, the container runs as root"; ok=1
  fi
  return $ok
}

ALL=(lint test sast secrets deps docker)
for s in "${ALL[@]}"; do
  if want "$s" "$@"; then stage "$s" "stage_$s"; fi
done

echo
echo "=== SUMMARY ==="
printf '%s\n' "${RESULTS[@]}"
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo
  echo "QUALITY GATE: FAILED (${#FAILED[@]} stage(s): ${FAILED[*]})"
  exit 1
fi
echo
echo "QUALITY GATE: PASSED"
LAB_EOF
cat > pytest.ini <<'LAB_EOF'
[pytest]
pythonpath = .
testpaths = tests
LAB_EOF
cat > requirements-dev.txt <<'LAB_EOF'
# Tools for the pipeline (not shipped in the image). Left unpinned on purpose for the lab.
pytest
pytest-cov
ruff
bandit
pip-audit
detect-secrets
LAB_EOF
cat > requirements.txt <<'LAB_EOF'
flask==3.0.0
gunicorn==23.0.0
LAB_EOF
mkdir -p tests
cat > tests/test_app.py <<'LAB_EOF'
import pytest

import app as app_module


@pytest.fixture()
def client():
    return app_module.app.test_client()


def test_health(client):
    assert client.get("/health").get_json() == {"status": "ok"}


def test_square(client):
    assert client.get("/square?n=7").get_json() == {"n": 7, "square": 49}


def test_square_rejects_text(client):
    assert client.get("/square?n=abc").status_code == 400


def test_fingerprint_is_stable(client):
    a = client.get("/fingerprint?text=hi").get_json()["sha"]
    b = client.get("/fingerprint?text=hi").get_json()["sha"]
    assert a == b


def test_whoami(client):
    assert "has_key" in client.get("/whoami").get_json()
LAB_EOF
chmod +x pipeline.sh
echo "Created ci-lab. Next: cd ci-lab"
```

Then install the app libraries and the pipeline tools:

```bash
cd ci-lab
pip install -r requirements.txt -r requirements-dev.txt
```

Look at the files: `ls -la` and `cat app.py`. Do not fix anything yet.

## Part 1: Run the pipeline and read the red (5 min)

**Predict:** how many of the six stages will fail? Write your number down.

```bash
./pipeline.sh
```

Read the **SUMMARY** at the bottom. The script runs *all* stages, then fails at the end if any stage failed. That is the **quality gate**: no green, no release.

You can run one stage alone, for example `./pipeline.sh lint`, or several: `./pipeline.sh lint test`.

## Part 2: Fix the stages (20 min)

Work in this order. For every stage: read the message first, try to fix it yourself, and open the hint only if you are stuck. Run the single stage after each fix.

### 2a. lint

`./pipeline.sh lint` reports an unused import and an unused variable in `app.py`.

<details><summary>Hint (fix)</summary>

```bash
sed -i '/^import sys$/d;/started = True/d' app.py
./pipeline.sh lint
```
</details>

### 2b. test

`./pipeline.sh test` shows one failing test. **Read the diff.** Which one is wrong, the test or the code?

<details><summary>Hint (fix)</summary>

The test is right: 7 squared is 49. The code multiplies by 2.

```bash
sed -i 's/square=n \* 2/square=n * n/' app.py
./pipeline.sh test
```
</details>

Look at the coverage table: the pipeline also fails if less than 80% of the lines are covered. Coverage says how much code the tests *run*, not how good the tests are.

### 2c. sast

`./pipeline.sh sast` lists risky patterns with an ID such as B324. Look the ID up in the bandit documentation if you want to know why it matters.

Two problems here: a weak hash (MD5) and a Flask debug server that binds to all interfaces. The debug server is only for development; in the container we use gunicorn.

<details><summary>Hint (fix)</summary>

```bash
sed -i 's/hashlib.md5/hashlib.sha256/' app.py
sed -i '/^if __name__/,$d' app.py
./pipeline.sh sast
```
</details>

### 2d. secrets

`./pipeline.sh secrets` finds a key in `app.py`. **Discuss with your partner:** if this were a real key that was already pushed to Git, is deleting the line enough? (See reflection question 3.)

<details><summary>Hint (fix)</summary>

The key must come from the environment, not from the code.

```bash
sed -i 's|^API_KEY = .*|API_KEY = os.environ.get("API_KEY", "")|' app.py
./pipeline.sh secrets
```
</details>

### 2e. deps

`./pipeline.sh deps` lists known vulnerabilities in the version of Flask we pinned. The "Fix Versions" column tells you what to use. (It needs internet access; Killercoda has it.)

<details><summary>Hint (fix)</summary>

```bash
sed -i 's/flask==3.0.0/flask==3.1.3/' requirements.txt
pip install -r requirements.txt
./pipeline.sh deps
```

If a newer fix version is listed, use that one instead and tell your instructor: the list changes over time.
</details>

### 2f. docker

`./pipeline.sh docker` checks two rules in the Dockerfile: the base image has a version tag (not `latest`), and there is a `USER` line.

<details><summary>Hint (fix)</summary>

```bash
sed -i 's|^FROM python:latest|FROM python:3.13-slim|' Dockerfile
sed -i 's|^CMD|RUN useradd --create-home appuser\nUSER appuser\nCMD|' Dockerfile
cat Dockerfile
./pipeline.sh docker
```
</details>

## Part 3: Green gate (3 min)

```bash
./pipeline.sh
```

You want to see `QUALITY GATE: PASSED`. If one stage is still red, read its message again.

## Part 4: The same pipeline on a CI server (5 min)

Open the workflow file and read it with your partner:

```bash
cat .github/workflows/ci.yml
```

Find these ideas: the **trigger** (`on:`), the **job** and its **steps**, the **permissions** line, `needs: quality` (the image is built only after the quality job is green). This file is what you put in a Git repository on GitHub, in the folder `.github/workflows/`. We do not run it today because Killercoda is not GitHub.

**Supply chain: make a bill of materials (SBOM).** An SBOM is a list of every library inside your software.

```bash
pip-audit -r requirements.txt -f cyclonedx-json -o sbom.json
python3 -c "import json; d=json.load(open('sbom.json')); print(len(d['components']), 'components'); [print(' ', c['name'], c['version']) for c in d['components']]"
```

You pinned **2** libraries. How many components are there? The difference is the libraries your libraries bring with them.

## Part 5: Clean up

Close the playground. Nothing else is needed.

## Reflection questions (write 2 or 3 sentences each, for yourself)

1. Which stage failed first in your head, and which one surprised you?
2. A teammate adds `# nosec` to silence bandit. When is that acceptable, and what should you ask in the pull request?
3. The key was pushed to Git before the scan ran. Why is deleting the line not enough? What do you do first?
4. Your pipeline needs 20 minutes. Which stages would you run on every push, and which only before a release?
5. Coverage is 100%. Does that mean the app has no bugs?

## Troubleshooting

- **`pip: command not found` or "externally managed environment":** use the virtual environment from Part 0 (`. .venv-lab/bin/activate`).
- **`./pipeline.sh: Permission denied`:** `chmod +x pipeline.sh`.
- **`ruff`, `bandit` or another tool "not found":** the virtual environment is not active. Run `. ../.venv-lab/bin/activate` from inside `ci-lab`.
- **`deps` stage fails with a network error:** the playground has no internet right now. Wait a minute and retry, or tell your instructor.
- **You broke the files:** run the setup block again in a new empty folder.

## Command summary

| Command | What it does |
|---|---|
| `./pipeline.sh` | run all stages and the quality gate |
| `./pipeline.sh lint test` | run only some stages |
| `ruff check .` | lint |
| `python -m pytest --cov=app` | tests with coverage |
| `bandit -r app.py -ll` | SAST, medium and high only |
| `pip-audit -r requirements.txt` | known vulnerabilities in dependencies |
| `pip-audit -r requirements.txt -f cyclonedx-json -o sbom.json` | SBOM |
