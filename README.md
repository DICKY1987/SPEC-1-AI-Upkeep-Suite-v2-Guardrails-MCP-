# AI-Assisted Code Quality Enforcement System

This repository implements the AIUOKEEP reference architecture: a deterministic,
policy-driven guardrail platform that mediates AI-generated code changes through
MCP tooling, SafePatch validation, and audit governance.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Operational Workflows](#operational-workflows)
- [Repository Layout](#repository-layout)
- [Documentation](#documentation)
- [Contributing](#contributing)

## Overview
The system enables autonomous agents and developers to collaborate safely by
combining:
- **Model Context Protocol (MCP) servers** that expose language-specific quality
  tooling and shared services.
- **SafePatch validation pipeline** that runs formatting, linting, typing,
  testing, SAST, policy, and secret gates.
- **Policy and schema guardrails** that enforce deterministic ChangePlans and
  block disallowed operations.
- **Audit and observability** features that capture immutable records for every
  validation run.

## Architecture
A detailed component breakdown, data flow, and operational considerations are
available in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

Key elements:
- **MCP Tool Plane:** Configured via `/.mcp/` scripts and `/mcp-servers/` runtime
  implementations.
- **Guardrails:** JSON Schemas, OPA policies, and Semgrep rule packs defined under
  `/policy/` and `/.semgrep/`.
- **SafePatch Pipeline:** Validation orchestration script at
  `scripts/validation/Invoke-SafePatchValidation.ps1` with CI parity through
  `/.github/workflows/`.
- **Audit Layer:** Ledger schema in `/schemas/ledger.schema.json` and PowerShell
  utilities under `/scripts/audit/`.

## Getting Started
1. **Install Dependencies**
   - PowerShell 7.4+
   - Python 3.12+
   - Node.js (for TypeScript tooling)
2. **Clone Repository** and review configuration files in `/.mcp/`.
3. **Initialize MCP Environment** via `./.mcp/Initialize-McpEnvironment.ps1` and
   validate using `./.mcp/Test-McpEnvironment.ps1`.
4. **Run Local Validation** with `./tools/Verify.ps1` before submitting changes.
5. **Review Guardrails** in `docs/GUARDRAILS.md` to understand enforced policies.

## Operational Workflows
- **Developers/Agents** author ChangePlans, apply deterministic patches, and run
  SafePatch locally before creating PRs.
- **CI/CD** executes workflows in `/.github/workflows/` to mirror local checks and
  publish ledger entries.
- **Governance Teams** monitor `/scripts/audit/Export-WeeklyReport.ps1` outputs to
  detect drift or recurring failures.

## Repository Layout
- `.mcp/` — Desired-state configuration and automation scripts for MCP servers.
- `mcp-servers/` — MCP server implementations (PowerShell, Python, SAST, secrets,
  policy).
- `policy/` — JSON Schemas, OPA policies, and Semgrep configurations.
- `tools/` — Local development tooling, including edit-engine utilities and
  validation orchestrators.
- `scripts/` — Validation, audit, sandbox, and hook scripts.
- `docs/` — Architecture, guardrail, MCP integration, validation pipeline, agent
  guidelines, and troubleshooting references.
- `tests/` — Fixtures and test suites supporting SafePatch enforcement.

## Documentation
Additional guidance is available in:
- [`docs/MCP_INTEGRATION.md`](docs/MCP_INTEGRATION.md): Configure and operate MCP
  servers.
- [`docs/VALIDATION_PIPELINE.md`](docs/VALIDATION_PIPELINE.md): Understand
  SafePatch stages.
- [`docs/AGENT_GUIDELINES.md`](docs/AGENT_GUIDELINES.md): Behavioral standards for
  agents.
- [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md): Common issues and fixes.
- [`docs/GUARDRAILS.md`](docs/GUARDRAILS.md): Guardrail taxonomy and extensions.

## Contributing
See [`CONTRIBUTING.md`](CONTRIBUTING.md) for branching strategy, code review
requirements, and validation expectations. All contributions must pass SafePatch
validation and include relevant documentation updates.
