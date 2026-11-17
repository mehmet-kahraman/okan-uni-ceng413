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
