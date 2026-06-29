import pytest
from fastapi.testclient import TestClient
import json
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from api import app as app_module


class DummyProcess:
    def __init__(self, returncode=0, stdout=b"", stderr=b""):
        self.returncode = returncode
        self._stdout = stdout
        self._stderr = stderr

    async def communicate(self):
        return self._stdout, self._stderr


@pytest.fixture
def client_with_test_db(tmp_path, monkeypatch):
    db_path = tmp_path / "test_simulations.db"
    engine = create_engine(
        f"sqlite:///{db_path}",
        connect_args={"check_same_thread": False},
    )
    TestingSessionLocal = sessionmaker(bind=engine)

    app_module.Base.metadata.create_all(engine)
    monkeypatch.setattr(app_module, "engine", engine)
    monkeypatch.setattr(app_module, "SessionLocal", TestingSessionLocal)
    monkeypatch.setattr(app_module, "VALID_API_KEYS", {"test-key": "local"})

    with TestClient(app_module.app) as client:
        yield client

    engine.dispose()


@pytest.fixture
def client_with_broken_db(tmp_path, monkeypatch):
    db_path = tmp_path / "broken_simulations.db"
    engine = create_engine(
        f"sqlite:///{db_path}",
        connect_args={"check_same_thread": False},
    )
    BrokenSessionLocal = sessionmaker(bind=engine)

    # Intentionally do NOT create tables to simulate DB dependency failure.
    monkeypatch.setattr(app_module, "engine", engine)
    monkeypatch.setattr(app_module, "SessionLocal", BrokenSessionLocal)
    monkeypatch.setattr(app_module, "VALID_API_KEYS", {"test-key": "local"})

    with TestClient(app_module.app, raise_server_exceptions=False) as client:
        yield client

    engine.dispose()


def test_root_status_ok(client_with_test_db):
    response = client_with_test_db.get("/")

    assert response.status_code == 200
    assert response.json() == {"engine": "Julia", "ready": True}


def test_run_simulation_happy_path_returns_job_id(client_with_test_db, monkeypatch):
    payload = {
        "data_points": [
            {"Energy": 1.0, "Transmission": 0.25},
            {"Energy": 2.0, "Transmission": 0.5},
        ]
    }

    async def fake_create_subprocess_shell(*args, **kwargs):
        return DummyProcess(returncode=0, stdout=json.dumps(payload).encode(), stderr=b"")

    monkeypatch.setattr(app_module.asyncio, "create_subprocess_shell", fake_create_subprocess_shell)

    response = client_with_test_db.post(
        "/run_simulation",
        headers={"api-key": "test-key"},
        json={},
    )

    assert response.status_code == 200
    body = response.json()
    assert "job_id" in body
    assert body["status"] == "running"


def test_run_simulation_end_to_end_completed_with_data_points(client_with_test_db, monkeypatch):
    payload = {
        "data_points": [
            {"Energy": 10.0, "Transmission": 0.1},
            {"Energy": 20.0, "Transmission": 0.2},
        ]
    }

    async def fake_create_subprocess_shell(*args, **kwargs):
        return DummyProcess(returncode=0, stdout=json.dumps(payload).encode(), stderr=b"")

    monkeypatch.setattr(app_module.asyncio, "create_subprocess_shell", fake_create_subprocess_shell)

    start_response = client_with_test_db.post(
        "/run_simulation",
        headers={"api-key": "test-key"},
        json={},
    )
    job_id = start_response.json()["job_id"]

    status_response = client_with_test_db.get(
        f"/simulation_status/{job_id}",
        params={"include_data_points": "true"},
    )

    assert status_response.status_code == 200
    body = status_response.json()
    assert body["job_id"] == job_id
    assert body["status"] == "completed"
    assert body["message"] == "Successfully finished the job"
    assert body["data_points"] == payload["data_points"]


def test_simulation_status_without_data_points_field(client_with_test_db, monkeypatch):
    payload = {
        "data_points": [{"Energy": 3.0, "Transmission": 0.3}],
    }

    async def fake_create_subprocess_shell(*args, **kwargs):
        return DummyProcess(returncode=0, stdout=json.dumps(payload).encode(), stderr=b"")

    monkeypatch.setattr(app_module.asyncio, "create_subprocess_shell", fake_create_subprocess_shell)

    start_response = client_with_test_db.post(
        "/run_simulation",
        headers={"api-key": "test-key"},
        json={},
    )
    job_id = start_response.json()["job_id"]

    status_response = client_with_test_db.get(f"/simulation_status/{job_id}")

    assert status_response.status_code == 200
    body = status_response.json()
    assert body["job_id"] == job_id
    assert body["status"] == "completed"
    assert "data_points" not in body


def test_run_simulation_rejects_invalid_api_key(client_with_test_db):
    response = client_with_test_db.post(
        "/run_simulation",
        headers={"api-key": "wrong-key"},
        json={},
    )

    assert response.status_code == 401
    assert response.json() == {
        "error_code": "UNAUTHORIZED",
        "message": "Invalid API Key",
        "details": None,
    }


def test_db_down_on_run_simulation_returns_server_error(client_with_broken_db):
    response = client_with_broken_db.post(
        "/run_simulation",
        headers={"api-key": "test-key"},
        json={},
    )

    assert response.status_code == 500


def test_db_down_on_get_simulation_status_returns_server_error(client_with_broken_db):
    response = client_with_broken_db.get("/simulation_status/1")

    assert response.status_code == 500


def test_simulation_backend_failure_marks_job_failed(client_with_test_db, monkeypatch):
    async def fake_create_subprocess_shell(*args, **kwargs):
        return DummyProcess(returncode=1, stdout=b"", stderr=b"julia unavailable")

    monkeypatch.setattr(app_module.asyncio, "create_subprocess_shell", fake_create_subprocess_shell)

    start_response = client_with_test_db.post(
        "/run_simulation",
        headers={"api-key": "test-key"},
        json={},
    )
    job_id = start_response.json()["job_id"]

    status_response = client_with_test_db.get(f"/simulation_status/{job_id}")
    body = status_response.json()

    assert status_response.status_code == 200
    assert body["status"] == "failed"
    assert body["message"] == "Failed to parse JSON output from Julia."


def test_simulation_backend_invalid_json_marks_job_failed(client_with_test_db, monkeypatch):
    async def fake_create_subprocess_shell(*args, **kwargs):
        return DummyProcess(returncode=0, stdout=b"not-json", stderr=b"")

    monkeypatch.setattr(app_module.asyncio, "create_subprocess_shell", fake_create_subprocess_shell)

    start_response = client_with_test_db.post(
        "/run_simulation",
        headers={"api-key": "test-key"},
        json={},
    )
    job_id = start_response.json()["job_id"]

    status_response = client_with_test_db.get(f"/simulation_status/{job_id}")
    body = status_response.json()

    assert status_response.status_code == 200
    assert body["status"] == "failed"
    assert body["message"] == "Failed to parse JSON output from Julia."


def test_simulation_status_unknown_job_returns_404(client_with_test_db):
    response = client_with_test_db.get("/simulation_status/999999")

    assert response.status_code == 404
    assert response.json() == {
        "error_code": "NOT_FOUND",
        "message": "Simulation not found",
        "details": None,
    }
