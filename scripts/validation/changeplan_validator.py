"""Utilities for validating ChangePlan artifacts.

This module performs lightweight schema checks to ensure ChangePlan JSON
documents produced by AI assistants meet the guardrail requirements. The
validation logic mirrors the repository's JSON Schema and OPA policy rules
without introducing additional runtime dependencies.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
import sys
from typing import Any, Iterable, Mapping


class ChangePlanValidationError(RuntimeError):
    """Raised when ChangePlan validation fails."""


@dataclass(frozen=True)
class ChangePlanArtifact:
    """Represents a ChangePlan document loaded from disk."""

    path: Path
    data: Mapping[str, Any]


def _load_json(path: Path) -> Mapping[str, Any]:
    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise ChangePlanValidationError(
            f"ChangePlan file not found: {path}"
        ) from exc
    except OSError as exc:  # pragma: no cover - defensive guard
        raise ChangePlanValidationError(
            f"Failed to read ChangePlan file {path}: {exc}"
        ) from exc

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ChangePlanValidationError(
            f"Invalid JSON in ChangePlan file {path}: {exc}"
        ) from exc

    if not isinstance(data, Mapping):
        raise ChangePlanValidationError(
            "ChangePlan root must be a JSON object."
        )

    return data


def _require_keys(
    payload: Mapping[str, Any], required: Iterable[str], context: str
) -> None:
    missing = [key for key in required if key not in payload]
    if missing:
        missing_list = ", ".join(sorted(missing))
        raise ChangePlanValidationError(
            f"Missing required key(s) {missing_list} in {context}."
        )


def _validate_changes(changes: Any) -> None:
    if not isinstance(changes, list):
        raise ChangePlanValidationError("ChangePlan.changes must be an array.")

    for index, change in enumerate(changes):
        if not isinstance(change, Mapping):
            raise ChangePlanValidationError(
                f"Change entry at index {index} must be an object."
            )

        _require_keys(change, ["path", "description"], f"change[{index}]")

        path_value = change.get("path")
        if not isinstance(path_value, str) or not path_value.strip():
            raise ChangePlanValidationError(
                f"Change entry {index} has an empty or non-string path."
            )

        description_value = change.get("description")
        if not isinstance(description_value, str) or not description_value.strip():
            raise ChangePlanValidationError(
                f"Change entry {index} has an empty or non-string description."
            )

        tests_value = change.get("tests")
        if tests_value is None:
            continue

        if not isinstance(tests_value, list):
            raise ChangePlanValidationError(
                f"Change entry {index} has invalid tests field; expected an array."
            )

        for test_index, test_name in enumerate(tests_value):
            if not isinstance(test_name, str) or not test_name.strip():
                raise ChangePlanValidationError(
                    "Each declared test must be a non-empty string "
                    f"(issue found at change {index}, test {test_index})."
                )


def _validate_validation_block(validation: Any) -> None:
    if not isinstance(validation, Mapping):
        raise ChangePlanValidationError(
            "ChangePlan.validation must be an object with tool results."
        )

    required_flags = ("format", "lint", "test")
    _require_keys(validation, required_flags, "validation")

    optional_flags = ("sast", "policy")

    for flag in (*required_flags, *optional_flags):
        if flag not in validation:
            continue
        value = validation[flag]
        if not isinstance(value, bool):
            raise ChangePlanValidationError(
                f"Validation flag '{flag}' must be boolean."
            )


def _resolve_schema_path(schema: Path | None) -> Path:
    if schema is not None:
        return schema

    repo_root = Path(__file__).resolve().parents[2]
    default_schema = repo_root / "policy" / "schemas" / "changeplan.schema.json"
    return default_schema


def validate_changeplan(
    workspace: Path, schema_path: Path | None = None
) -> ChangePlanArtifact:
    """Validate the ChangePlan JSON artefact located in *workspace*.

    Parameters
    ----------
    workspace:
        Directory that should contain ``changeplan.json``.
    schema_path:
        Optional path to the JSON Schema used for structure validation. When
        omitted the repository's canonical schema is used.

    Returns
    -------
    ChangePlanArtifact
        The parsed ChangePlan document.

    Raises
    ------
    ChangePlanValidationError
        If the ChangePlan is missing or violates any structural requirement.
    """

    workspace = workspace.expanduser().resolve()
    if not workspace.exists() or not workspace.is_dir():
        raise ChangePlanValidationError(
            f"Workspace does not exist or is not a directory: {workspace}"
        )

    changeplan_path = workspace / "changeplan.json"
    schema_path = _resolve_schema_path(schema_path).resolve()

    if not schema_path.exists():
        raise ChangePlanValidationError(
            f"ChangePlan schema not found: {schema_path}"
        )

    data = _load_json(changeplan_path)

    schema_data = _load_json(schema_path)

    required_root = schema_data.get("required", [])
    if isinstance(required_root, list):
        _require_keys(data, required_root, "ChangePlan root")

    summary = data.get("summary")
    if not isinstance(summary, str) or not summary.strip():
        raise ChangePlanValidationError("ChangePlan.summary must be a non-empty string.")

    _validate_changes(data.get("changes"))
    _validate_validation_block(data.get("validation"))

    return ChangePlanArtifact(path=changeplan_path, data=data)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate ChangePlan artifacts produced by AI agents."
    )
    parser.add_argument(
        "--workspace",
        type=Path,
        required=True,
        help="Workspace directory that contains changeplan.json",
    )
    parser.add_argument(
        "--schema",
        type=Path,
        required=False,
        help="Optional path to the ChangePlan JSON Schema file.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    try:
        validate_changeplan(args.workspace, args.schema)
    except ChangePlanValidationError as exc:
        print(f"ChangePlan validation failed: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":  # pragma: no cover - CLI entry point
    sys.exit(main())

