from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from scripts.validation import (  # noqa: E402  pylint: disable=wrong-import-position
    ChangePlanValidationError,
    validate_changeplan,
)


def _schema_path() -> Path:
    return REPO_ROOT / "policy" / "schemas" / "changeplan.schema.json"


def _write_changeplan(tmp_path: Path, payload: dict) -> Path:
    workspace = tmp_path
    workspace.joinpath("changeplan.json").write_text(
        json.dumps(payload, indent=2),
        encoding="utf-8",
    )
    return workspace


def test_validate_changeplan_success(tmp_path: Path) -> None:
    payload = {
        "summary": "Update validation pipeline",
        "changes": [
            {
                "path": "scripts/validation/Test-ChangePlan.ps1",
                "description": "Invoke Python validator",
                "tests": ["pytest"],
            }
        ],
        "validation": {
            "format": True,
            "lint": True,
            "test": True,
            "sast": True,
            "policy": True,
        },
    }
    workspace = _write_changeplan(tmp_path, payload)

    artifact = validate_changeplan(workspace, _schema_path())

    assert artifact.data["summary"] == payload["summary"]
    assert artifact.path.name == "changeplan.json"


def test_validate_changeplan_missing_summary(tmp_path: Path) -> None:
    payload = {
        "summary": " ",
        "changes": [
            {
                "path": "scripts/validation/Test-ChangePlan.ps1",
                "description": "Invoke Python validator",
            }
        ],
        "validation": {"format": True, "lint": True, "test": True},
    }
    workspace = _write_changeplan(tmp_path, payload)

    with pytest.raises(ChangePlanValidationError) as exc:
        validate_changeplan(workspace, _schema_path())

    assert "summary" in str(exc.value)


def test_validate_changeplan_invalid_change_entry(tmp_path: Path) -> None:
    payload = {
        "summary": "Tighten change validation",
        "changes": [
            {
                "path": "scripts/validation/Test-ChangePlan.ps1",
                "description": "",
            }
        ],
        "validation": {"format": True, "lint": True, "test": True},
    }
    workspace = _write_changeplan(tmp_path, payload)

    with pytest.raises(ChangePlanValidationError) as exc:
        validate_changeplan(workspace, _schema_path())

    assert "description" in str(exc.value)


def test_validate_changeplan_requires_validation_flags(tmp_path: Path) -> None:
    payload = {
        "summary": "Ensure validation flags exist",
        "changes": [
            {
                "path": "scripts/validation/Test-ChangePlan.ps1",
                "description": "Add validation enforcement",
            }
        ],
        "validation": {"format": True, "lint": True},
    }
    workspace = _write_changeplan(tmp_path, payload)

    with pytest.raises(ChangePlanValidationError) as exc:
        validate_changeplan(workspace, _schema_path())

    assert "validation" in str(exc.value)

