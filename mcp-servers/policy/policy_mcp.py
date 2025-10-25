"""Stub MCP server for OPA/Conftest policy validation."""

from __future__ import annotations

import json
from typing import Dict


def main() -> None:
    payload: Dict[str, object] = {
        "server": "policy-validation",
        "status": "stub",
        "tools": ["conftest"],
        "message": "Wire up Conftest execution against policy bundles and schemas.",
    }
    print(json.dumps(payload))


if __name__ == "__main__":
    main()
