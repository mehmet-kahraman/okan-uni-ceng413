import importlib

import pytest


class FakeRedis:
    """Tiny in-memory stand-in so the tests need no Redis server."""

    def __init__(self):
        self.data = {}

    def incr(self, key):
        self.data[key] = self.data.get(key, 0) + 1
        return self.data[key]


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("DATA_DIR", str(tmp_path))
    monkeypatch.setenv("APP_GREETING", "Hello")
    monkeypatch.delenv("REDIS_HOST", raising=False)
    import app as app_module

    importlib.reload(app_module)
    return app_module.app.test_client()


@pytest.fixture()
def redis_client(tmp_path, monkeypatch):
    monkeypatch.setenv("DATA_DIR", str(tmp_path))
    monkeypatch.setenv("REDIS_HOST", "cache")
    import app as app_module

    importlib.reload(app_module)
    monkeypatch.setattr(app_module, "_redis", FakeRedis())
    return app_module.app.test_client()


def test_health(client):
    assert client.get("/health").get_json() == {"status": "ok"}


def test_greet_name(client):
    assert client.get("/greet?name=Ada").get_json() == {"message": "Hello, Ada!"}


def test_visit_file_fallback(client):
    assert client.get("/visit").get_json() == {"visits": 1, "storage": "file"}
    assert client.get("/visit").get_json() == {"visits": 2, "storage": "file"}


def test_visit_uses_redis_when_configured(redis_client):
    assert redis_client.get("/visit").get_json() == {"visits": 1, "storage": "redis"}
    assert redis_client.get("/visit").get_json() == {"visits": 2, "storage": "redis"}


def test_whoami_returns_hostname(client):
    assert "hostname" in client.get("/whoami").get_json()
