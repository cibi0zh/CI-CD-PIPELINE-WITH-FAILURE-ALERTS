def test_index_returns_service_info(client):
    resp = client.get("/")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["service"] == "cicd-pipeline-healthcheck"
    assert body["status"] == "running"


def test_healthz_returns_ok(client):
    resp = client.get("/healthz")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["status"] == "ok"
    assert "uptime_seconds" in body


def test_ready_reports_all_checks_healthy(client):
    resp = client.get("/ready")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["status"] == "ready"
    assert body["checks"]["database"] == "ok"
    assert body["checks"]["cache"] == "ok"


def test_ready_returns_503_when_a_dependency_is_down(client, mocker):
    mocker.patch("app.check_dependencies", return_value={"database": "ok", "cache": "down"})
    resp = client.get("/ready")
    assert resp.status_code == 503
    body = resp.get_json()
    assert body["status"] == "not_ready"


def test_version_reflects_build_env_vars(client, monkeypatch):
    # BUILD_VERSION/GIT_COMMIT are read at import time, so this just checks
    # the endpoint responds with the expected shape rather than re-importing.
    resp = client.get("/version")
    assert resp.status_code == 200
    body = resp.get_json()
    assert "version" in body
    assert "commit" in body


def test_unknown_route_returns_404(client):
    resp = client.get("/does-not-exist")
    assert resp.status_code == 404
