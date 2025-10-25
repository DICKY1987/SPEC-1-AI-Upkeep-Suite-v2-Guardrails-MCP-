"""Placeholder MCP server exposing secret scanning capabilities.

This Phase 2 scaffold should be replaced with an implementation that
wraps the chosen secret scanning tool (e.g., gitleaks) via the MCP
interface.
"""

from __future__ import annotations


def register_secret_scanner() -> None:
    """Register secret scanning commands with the MCP runtime.

    The concrete implementation should publish the available
    secret-scanning actions and handle result formatting.
    """

    raise NotImplementedError("Secret scanning server registration pending implementation")


if __name__ == "__main__":
    register_secret_scanner()
