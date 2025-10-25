from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "scripts" / "validation" / "Test-ChangePlan.ps1"
FIXTURE_DIR = REPO_ROOT / "tests" / "fixtures"


@pytest.fixture(name="pwsh_executable")
def fixture_pwsh_executable() -> str:
    pwsh = shutil.which("pwsh")
    if not pwsh:
        pytest.skip("PowerShell (pwsh) is required for integration tests")
    return pwsh


@pytest.mark.integration
@pytest.mark.usefixtures("pwsh_executable")
def test_changeplan_validation_succeeds(tmp_path: Path, pwsh_executable: str) -> None:
    workspace = tmp_path / "workspace-valid"
    workspace.mkdir(parents=True)
    (workspace / "changeplan.json").write_bytes(
        (FIXTURE_DIR / "changeplan_valid.json").read_bytes()
    )

    result = subprocess.run(
        [
            pwsh_executable,
            "-NoLogo",
            "-NoProfile",
            "-File",
            str(SCRIPT_PATH),
            "-Workspace",
            str(workspace),
            "-Verbose",
        ],
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stderr


@pytest.mark.integration
@pytest.mark.usefixtures("pwsh_executable")
def test_changeplan_validation_fails_for_invalid_payload(
    tmp_path: Path, pwsh_executable: str
) -> None:
    workspace = tmp_path / "workspace-invalid"
    workspace.mkdir(parents=True)
    (workspace / "changeplan.json").write_bytes(
        (FIXTURE_DIR / "changeplan_invalid_missing_fields.json").read_bytes()
    )

    result = subprocess.run(
        [
            pwsh_executable,
            "-NoLogo",
            "-NoProfile",
            "-File",
            str(SCRIPT_PATH),
            "-Workspace",
            str(workspace),
            "-Verbose",
        ],
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode != 0
    assert "ChangePlan validation failed" in result.stderr
