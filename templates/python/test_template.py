"""Pytest template aligned with AIUOKEEP standards."""
from __future__ import annotations

import pathlib

import pytest

from python_cli import main as cli_main


@pytest.fixture(name="fixture_path")
def fixture_path(tmp_path: pathlib.Path) -> pathlib.Path:
    """Provide a temporary resource path for tests."""
    sample_file = tmp_path / "sample.txt"
    sample_file.write_text("example", encoding="utf-8")
    return sample_file


def test_cli_executes_successfully(monkeypatch: pytest.MonkeyPatch, fixture_path: pathlib.Path) -> None:
    """Ensure the CLI exits with code 0 when logic succeeds."""
    monkeypatch.setattr("python_cli.execute", lambda input_path: 0)
    exit_code = cli_main(["--input", str(fixture_path)])
    assert exit_code == 0


def test_cli_reports_failures(monkeypatch: pytest.MonkeyPatch, fixture_path: pathlib.Path) -> None:
    """Ensure non-zero exit codes propagate to the shell."""
    monkeypatch.setattr("python_cli.execute", lambda input_path: 3)
    exit_code = cli_main(["--input", str(fixture_path)])
    assert exit_code == 3
