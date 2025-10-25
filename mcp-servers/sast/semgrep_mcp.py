"""Stub MCP server wrapping Semgrep for SAST scanning."""

from __future__ import annotations

import json
from typing import Dict


def main() -> None:
    payload: Dict[str, object] = {
        "server": "semgrep-sast",
        "status": "stub",
        "tools": ["semgrep"],
        "message": "Integrate Semgrep execution and SARIF output conversion.",
    }
    print(json.dumps(payload))


if __name__ == "__main__":
    main()
