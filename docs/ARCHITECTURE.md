# Architecture Overview

This document summarizes the major components of the AI-Assisted Code Quality Enforcement System:

- **MCP Tool Plane** provides protocol-compliant servers for quality tooling.
- **Guardrail Layer** enforces deterministic change plans and diff validation.
- **SafePatch Pipeline** orchestrates formatting, linting, testing, SAST, policy, and secret scanning.
- **Audit & Observability** records validation runs in signed ledgers with reporting scripts.
