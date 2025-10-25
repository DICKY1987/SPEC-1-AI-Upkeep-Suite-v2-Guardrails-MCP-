# Guardrail Framework

Guardrails prevent autonomous or assisted workflows from bypassing the quality and
policy expectations defined in the AIUOKEEP specification. They work together to
ensure that every code change is transparent, reviewable, and deterministic.

## Categories of Guardrails

### 1. Input & Prompt Guardrails
- **Pre-prompt constraints**: Instructional content (AGENT_GUIDELINES.md) dictates
  allowed operations, language preferences, and testing expectations.
- **ChangePlan Requirements**: Agents must propose work items and diffs instead of
  editing files directly.

### 2. Structural Guardrails
- **JSON Schemas** (`changeplan.schema.json`, `unifieddiff.schema.json`) validate
  structured outputs such as change plans, diffs, and test reports.
- **Directory Conventions** (`docs/conventions.md`) centralize naming and
  placement expectations for repositories, scripts, and templates.

### 3. Policy Guardrails
- **OPA Policies** (`/policy/opa/`) inspect ChangePlans and diff metadata to block
  risky operations (e.g., `Invoke-Expression`, unsafe shell escapes) and to enforce
  delivery completeness (tests + docs).
- **Semgrep Rule Packs** (`/.semgrep/`) detect language-specific anti-patterns and
  security issues across PowerShell, Python, and TypeScript.

### 4. Execution Guardrails
- **SafePatch Validation** ensures proposed diffs pass format, lint, type, test,
  SAST, policy, and secret checks before merge.
- **Sandbox Scripts** (`/scripts/sandbox/`) spin up isolated workspaces that block
  outbound network access, preventing data exfiltration.

### 5. Audit Guardrails
- **Ledger Entries** recorded via `/scripts/audit/` create tamper-evident logs of
  who executed what validation steps and when.
- **Drift Detection** scripts flag divergence between desired and actual MCP
  configurations or guardrail policies.

## How Guardrails Interact
1. Agents follow documented behavior guides when planning changes.
2. Proposed artifacts must validate against schemas before execution begins.
3. SafePatch orchestrations run in sandboxed environments and call MCP servers for
   tool execution.
4. Policy engines review both the change intent and results, enforcing allow/deny
   outcomes.
5. Audit routines publish immutable records and weekly summaries for compliance.

## Extending Guardrails
- Add new schemas for additional artifact types (e.g., Terraform plans) and wire
  them into `Test-ChangePlan.ps1`.
- Extend OPA policies with business-specific rules while maintaining regression
  suites in `/tests/policy/`.
- Include new Semgrep rule sets or external SAST providers by wrapping them with an
  MCP server that participates in SafePatch.
