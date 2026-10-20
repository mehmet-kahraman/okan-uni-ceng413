"""Demo web service for the Week 5 lab (Docker Compose).

Same service as Week 4, with two changes:
  * /visit keeps its counter in Redis when REDIS_HOST is set, so the app
    container itself stays STATELESS (the state lives in another service).
    Without REDIS_HOST it falls back to a file, exactly like Week 4.
  * /whoami returns the container's hostname.

Endpoints
  GET /health        -> {"status": "ok"}
  GET /greet?name=X  -> {"message": "Hello, X!"}
  GET /visit         -> {"visits": N, "storage": "redis" | "file"}
  GET /whoami        -> {"hostname": "<container id>"}

Configuration comes from environment variables (12-factor style):
  APP_GREETING  default "Hello"
  DATA_DIR      default "/data"   (file counter, used only without Redis)
  REDIS_HOST    default unset     (for example "cache" inside Compose)
  REDIS_PORT    default 6379
"""
import os
import socket
from pathlib import Path

from flask import Flask, jsonify, request

app = Flask(__name__)

GREETING = os.environ.get("APP_GREETING", "Hello")
DATA_DIR = Path(os.environ.get("DATA_DIR", "/data"))
REDIS_HOST = os.environ.get("REDIS_HOST")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))

_redis = None


def get_redis():
    """Create the Redis client once, only if REDIS_HOST is set."""
    global _redis
    if REDIS_HOST and _redis is None:
        import redis

        _redis = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, socket_connect_timeout=2)
    return _redis


def _counter_file() -> Path:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    return DATA_DIR / "visits.txt"


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.get("/greet")
def greet():
    name = request.args.get("name", "world")
    return jsonify(message=f"{GREETING}, {name}!")


@app.get("/visit")
def visit():
    client = get_redis()
    if client is not None:
        return jsonify(visits=int(client.incr("visits")), storage="redis")
    f = _counter_file()
    current = int(f.read_text()) if f.exists() else 0
    current += 1
    f.write_text(str(current))
    return jsonify(visits=current, storage="file")


@app.get("/whoami")
def whoami():
    return jsonify(hostname=socket.gethostname())


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
