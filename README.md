# AI-Assisted Code Quality Enforcement System

This repository implements the reference architecture described in `AIUOKEEP.md` for a deterministic, policy-driven guardrail platform that mediates AI-generated code changes.

## Key Capabilities
- Model Context Protocol (MCP) servers that expose language-specific quality tools
- SafePatch validation pipeline covering formatting, linting, testing, SAST, policy, and secrets
- Policy-as-code enforcement using Open Policy Agent and JSON Schemas
- Comprehensive audit trail with signed ledger entries and reporting utilities

## Getting Started
1. Install PowerShell 7.4 (or later) and Python 3.12.
2. Clone the repository and review the files in `tools/` for formatter, linter, and test configuration.
3. Use `./tools/Verify.ps1` to run the local quality gate before committing changes.
4. Configure MCP servers with `.mcp/mcp_servers.json` and initialize the environment using `./.mcp/Initialize-McpEnvironment.ps1`.

## Repository Layout
- `.mcp/` — Desired state configuration and helper scripts for MCP servers
- `mcp-servers/` — MCP server implementations for PowerShell, Python, SAST, secrets, and policy
- `policy/` — JSON Schemas, OPA policies, and Semgrep rule bundles
- `tools/` — Local development tooling configuration and edit engine utilities
- `scripts/` — Validation and audit automation
- `docs/` — Architecture and guardrail documentation
- `tests/` — Fixtures, unit, and integration suites supporting the SafePatch pipeline

Refer to the documentation in `docs/` for in-depth guidance on system setup and operation.
