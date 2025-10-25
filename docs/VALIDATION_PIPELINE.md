# SafePatch Validation Pipeline

The SafePatch pipeline enforces a deterministic gauntlet of quality checks before
changes can merge. Each stage runs inside a temporary workspace managed by
sandbox scripts to maintain isolation and reproducibility.

## Pipeline Overview
1. **Workspace Preparation**
   - `New-EphemeralWorkspace.ps1` clones the target repo at the requested ref.
   - ChangePlans are applied using edit engine utilities to ensure deterministic
     patch application.
2. **Formatting Stage**
   - PowerShell: PSScriptAnalyzer formatting rules.
   - Python: `ruff` and `black` in check mode.
   - TypeScript: Prettier via ESLint configuration.
3. **Linting Stage**
   - PowerShell: PSScriptAnalyzer rule sets from `tools/PSScriptAnalyzerSettings.psd1`.
   - Python: Ruff linting tiers.
   - TypeScript: ESLint with security plugins.
4. **Type Checking Stage**
   - PowerShell: Optional static analysis via Script Analyzer warnings-as-errors.
   - Python: `mypy` with `tools/mypy.ini` settings.
   - TypeScript: `tsc --noEmit` with `tools/tsconfig.json`.
5. **Unit Testing Stage**
   - PowerShell: `Invoke-Pester` suites seeded from `/templates/`.
   - Python: `pytest` using repo-specific fixtures.
   - TypeScript: `npm test` or `vitest` depending on project configuration.
6. **SAST Stage**
   - Semgrep scans via `/.semgrep/*.yml` rule packs.
   - Additional scanners can be added through MCP servers.
7. **Policy Stage**
   - OPA (`policy_mcp.py`) validates ChangePlans, diffs, and supporting metadata.
   - Checks for forbidden APIs, missing tests/docs, and environment violations.
8. **Secret Scanning Stage**
   - Secret scanners (e.g., gitleaks) run via the secrets MCP server.
9. **Results & Cleanup**
   - Artifacts are aggregated, signed, and stored according to the ledger schema.
   - `Remove-EphemeralWorkspace.ps1` tears down the workspace.

## Automation Entry Points
- **Local:** `tools/Verify.ps1`
- **Scripts:** `scripts/validation/Invoke-SafePatchValidation.ps1`
- **CI/CD:** `/.github/workflows/quality.yml` orchestrates jobs that mirror local
  stages for parity.

## Extending the Pipeline
- Add new stages by extending `Invoke-SafePatchValidation.ps1` and updating the
  audit schema to capture additional artifacts.
- Integrate third-party scanners by exposing them via MCP servers so the pipeline
  can call them uniformly.
- Update templates under `/templates/` to ensure new projects adopt the latest
  validation expectations by default.
