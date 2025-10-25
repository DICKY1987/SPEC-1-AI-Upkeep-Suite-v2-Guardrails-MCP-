# System Architecture

The AI-Assisted Code Quality Enforcement System orchestrates deterministic tooling,
policy guardrails, and orchestration logic so autonomous agents can collaborate on
software changes without bypassing governance. The architecture combines
PowerShell-first automation with polyglot validation services exposed through the
Model Context Protocol (MCP).

## Context Diagram

1. **Client Agents** generate change plans and diffs and submit them through the MCP
   tool plane.
2. **MCP Servers** broker requests to language-specific tooling (PowerShell,
   Python, TypeScript) and shared services (Semgrep, secret scanning, policy).
3. **SafePatch Pipeline** validates proposed changes in a hardened workspace using
   formatter, linter, type, test, SAST, policy, and secret gates.
4. **Guardrail Layer** enforces schemas, OPA policies, and deterministic edit
   engines before changes reach Git.
5. **Audit & Observability** persists every validation run to an append-only
   ledger and publishes operational reports.

## Core Components

### MCP Tool Plane
- Hosts discrete MCP servers for PowerShell (`ps_quality_mcp.ps1`), Python
  (`quality_mcp.py`), policy, SAST, and secrets.
- Access controlled via `/.mcp/access_groups.json` to restrict tool invocation.
- Desired-state configuration managed through `Initialize-McpEnvironment.ps1` and
  supporting scripts.

### Guardrail Layer
- JSON Schemas (`changeplan.schema.json`, `unifieddiff.schema.json`) validate AI
  output structure.
- OPA policies and Semgrep rules enforce business constraints, forbidden APIs,
  and required delivery bundles.
- Edit engine scripts in `/tools/edit-engine/` apply deterministic transformations.

### SafePatch Pipeline
- Primary orchestrator: `Invoke-SafePatchValidation.ps1`.
- Executes formatters, linters, type checkers, tests, SAST, policy, and secret
  scanners in sequence, capturing artifacts for audit.
- Supports local execution (`tools/Verify.ps1`) and CI/CD workflows under
  `/.github/workflows/`.

### Audit & Observability
- Ledger schema defined in `/schemas/ledger.schema.json` with storage in the
  database schema.
- Scripts under `/scripts/audit/` create, query, and export ledger entries and
  weekly reports.
- Seed data (`/database/seed_data.sql`) provisions baseline telemetry records.

## Data Flow Summary
1. Developer or agent submits a ChangePlan and diff bundle.
2. Guardrail checks validate schema and policy compliance.
3. SafePatch pipeline clones an ephemeral workspace, applies diffs, and runs
   quality tooling via MCP servers.
4. Results, logs, and artifacts are captured and signed before being written to
   the ledger.
5. Approved changes are handed back to the calling workflow or CI/CD pipeline for
   merge.

## Operational Considerations
- **Environment Parity:** PowerShell 7.4 and Python 3.12 must be available across
  local, sandbox, and CI environments.
- **Security:** OPA and Semgrep rules are version-controlled and reviewed to
  prevent policy drift.
- **Extensibility:** Additional languages can be supported by adding new MCP
  servers and wiring them into the SafePatch pipeline and guardrail schemas.
