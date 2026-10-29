import pytest
from fastapi.testclient import TestClient

import main


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(main, "APP_VERSION", "v1")
    monkeypatch.setattr(main, "FAULT_ERROR_RATE", 0.0)
    return TestClient(main.app)


def test_root_returns_version(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.json()["version"] == "v1"


def test_health_endpoints(client):
    assert client.get("/healthz").status_code == 200
    assert client.get("/readyz").status_code == 200


def test_metrics_count_user_traffic_only(client):
    client.get("/")
    client.get("/healthz")
    body = client.get("/metrics").text
    assert 'http_requests_total{method="GET",path="/",status="200"}' in body
    assert 'path="/healthz"' not in body


def test_fault_injection_returns_500(client, monkeypatch):
    monkeypatch.setattr(main, "FAULT_ERROR_RATE", 1.0)
    resp = client.get("/")
    assert resp.status_code == 500
    assert resp.json()["error"] == "injected fault"
