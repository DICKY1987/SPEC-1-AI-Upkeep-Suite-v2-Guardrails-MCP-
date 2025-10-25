# System Architecture Analysis

## Overview

Based on the provided documentation, this is an **AI-Assisted Code Quality Enforcement System** built around the Model Context Protocol (MCP). The system creates a controlled environment where AI agents can generate, modify, and maintain code while being constrained by deterministic guardrails, automated validation pipelines, and policy-as-code enforcement.

### Core Architecture Components

1. **MCP Tool Plane** - Centralized interface for code quality tools (formatters, linters, testers, SAST scanners)
2. **Guardrail Layer** - Pre-prompt constraints, structured output schemas, and runtime validation
3. **SafePatch Pipeline** - Multi-stage validation (format → lint → test → SAST → policy → secrets)
4. **Configuration Management** - Data-driven MCP server configuration with access controls
5. **Audit & Observability** - JSONL ledgers with cryptographic signatures for all operations
6. **CI/CD Integration** - Windows-first validation with cross-platform support

### Technology Stack
- **PowerShell** (5.1 + 7.4) with PSScriptAnalyzer and Pester
- **Python** (3.12) with ruff, black, mypy, pytest
- **TypeScript/JavaScript** with ESLint, Prettier, tsc
- **Semgrep** for SAST
- **OPA/Conftest** for policy validation
- **Git/GitHub Actions** for CI/CD

---

## Missing Files Manifest

Below is a comprehensive list of files needed to implement this system:

### Root Configuration Files

| File | Path | Purpose |
|------|------|---------|
| `.editorconfig` | `/.editorconfig` | Standardizes whitespace, line endings, and encoding across all editors |
| `README.md` | `/README.md` | Project overview, setup instructions, and architecture documentation |
| `CONTRIBUTING.md` | `/CONTRIBUTING.md` | Development guidelines, PR process, and code conventions |
| `.gitignore` | `/.gitignore` | Excludes build artifacts, secrets, and temporary files from version control |
| `LICENSE` | `/LICENSE` | Project licensing terms |

---

### MCP Configuration

| File | Path | Purpose |
|------|------|---------|
| `mcp_servers.json` | `/.mcp/mcp_servers.json` | Authoritative configuration for all MCP servers and tools |
| `access_groups.json` | `/.mcp/access_groups.json` | Defines access control groups (reader, contributor, maintainer) and their tool permissions |
| `Initialize-McpEnvironment.ps1` | `/.mcp/Initialize-McpEnvironment.ps1` | Orchestrator script that reads desired state and configures MCP environment |
| `Get-DesiredStateConfiguration.ps1` | `/.mcp/Get-DesiredStateConfiguration.ps1` | Reads and validates the desired MCP configuration from JSON |
| `Get-McpConfiguration.ps1` | `/.mcp/Get-McpConfiguration.ps1` | Retrieves current MCP configuration state |
| `New-McpConfigurationObject.ps1` | `/.mcp/New-McpConfigurationObject.ps1` | Merges desired and current configurations |
| `Set-McpConfiguration.ps1` | `/.mcp/Set-McpConfiguration.ps1` | Writes merged configuration to mcp.json |
| `Test-McpEnvironment.ps1` | `/.mcp/Test-McpEnvironment.ps1` | Validates that all configured MCP servers are healthy and accessible |

---

### MCP Server Implementations

| File | Path | Purpose |
|------|------|---------|
| `ps_quality_mcp.ps1` | `/mcp-servers/powershell/ps_quality_mcp.ps1` | MCP server exposing PSScriptAnalyzer and Pester as tools |
| `quality_mcp.py` | `/mcp-servers/python/quality_mcp.py` | MCP server exposing ruff, black, mypy, pytest as tools |
| `semgrep_mcp.py` | `/mcp-servers/sast/semgrep_mcp.py` | MCP server wrapper for Semgrep SAST scanning |
| `secrets_mcp.py` | `/mcp-servers/secrets/secrets_mcp.py` | MCP server wrapper for secret scanning (gitleaks) |
| `policy_mcp.py` | `/mcp-servers/policy/policy_mcp.py` | MCP server wrapper for OPA/Conftest policy validation |

---

### Guardrail Schemas & Policies

| File | Path | Purpose |
|------|------|---------|
| `changeplan.schema.json` | `/policy/schemas/changeplan.schema.json` | JSON Schema defining required structure for ChangePlan outputs from AI |
| `unifieddiff.schema.json` | `/policy/schemas/unifieddiff.schema.json` | Schema validating unified diff format |
| `changeplan.rego` | `/policy/opa/changeplan.rego` | OPA policy rules for validating ChangePlan compliance |
| `forbidden_apis.rego` | `/policy/opa/forbidden_apis.rego` | OPA rules blocking dangerous API calls (Invoke-Expression, eval, etc.) |
| `delivery_bundle.rego` | `/policy/opa/delivery_bundle.rego` | Validates that code submissions include required files (tests, configs) |
| `semgrep.yml` | `/.semgrep/semgrep.yml` | Semgrep rules for detecting code smells and security issues |
| `semgrep-powershell.yml` | `/.semgrep/semgrep-powershell.yml` | PowerShell-specific Semgrep rules (Write-Host, aliases, etc.) |
| `semgrep-python.yml` | `/.semgrep/semgrep-python.yml` | Python-specific rules (shell=True, print(), eval) |
| `semgrep-secrets.yml` | `/.semgrep/semgrep-secrets.yml` | Secret detection patterns |

---

### Code Quality Tools

| File | Path | Purpose |
|------|------|---------|
| `PSScriptAnalyzerSettings.psd1` | `/tools/PSScriptAnalyzerSettings.psd1` | Configuration for PSScriptAnalyzer with organization-specific rules |
| `Verify.ps1` | `/tools/Verify.ps1` | Local verification script running PSSA + Pester (mirrors CI) |
| `ruff.toml` | `/tools/ruff.toml` | Ruff linter and formatter configuration for Python |
| `mypy.ini` | `/tools/mypy.ini` | MyPy type checker configuration |
| `pytest.ini` | `/tools/pytest.ini` | Pytest configuration with coverage settings |
| `.eslintrc.json` | `/tools/.eslintrc.json` | ESLint configuration for TypeScript/JavaScript |
| `tsconfig.json` | `/tools/tsconfig.json` | TypeScript compiler configuration with strict mode |

---

### Validation Scripts

| File | Path | Purpose |
|------|------|---------|
| `Invoke-SafePatchValidation.ps1` | `/scripts/validation/Invoke-SafePatchValidation.ps1` | Orchestrates the full SafePatch pipeline (format → lint → test → SAST → policy) |
| `Test-UnifiedDiff.ps1` | `/scripts/validation/Test-UnifiedDiff.ps1` | Validates that provided diffs are proper unified format and apply cleanly |
| `Test-ChangePlan.ps1` | `/scripts/validation/Test-ChangePlan.ps1` | Validates ChangePlan JSON against schema and OPA policies |
| `Invoke-FormatCheck.ps1` | `/scripts/validation/Invoke-FormatCheck.ps1` | Runs formatters (black, ruff, prettier) in check mode |
| `Invoke-LintCheck.ps1` | `/scripts/validation/Invoke-LintCheck.ps1` | Runs all linters and collects results |
| `Invoke-TypeCheck.ps1` | `/scripts/validation/Invoke-TypeCheck.ps1` | Runs type checkers (mypy, tsc) |
| `Invoke-UnitTests.ps1` | `/scripts/validation/Invoke-UnitTests.ps1` | Runs test suites in ephemeral sandbox |
| `Invoke-SastScan.ps1` | `/scripts/validation/Invoke-SastScan.ps1` | Runs Semgrep and parses results |
| `Invoke-SecretScan.ps1` | `/scripts/validation/Invoke-SecretScan.ps1` | Runs secret scanner and validates no leaks |
| `Invoke-PolicyCheck.ps1` | `/scripts/validation/Invoke-PolicyCheck.ps1` | Runs OPA/Conftest against artifacts |

---

### Sandbox Scripts

| File | Path | Purpose |
|------|------|---------|
| `sandbox_linux.sh` | `/scripts/sandbox/sandbox_linux.sh` | Creates network-isolated sandbox on Linux using network namespaces |
| `sandbox_windows.ps1` | `/scripts/sandbox/sandbox_windows.ps1` | Creates network-restricted environment on Windows using firewall rules |
| `New-EphemeralWorkspace.ps1` | `/scripts/sandbox/New-EphemeralWorkspace.ps1` | Creates temporary Git worktree for isolated validation |
| `Remove-EphemeralWorkspace.ps1` | `/scripts/sandbox/Remove-EphemeralWorkspace.ps1` | Cleans up temporary worktrees after validation |

---

### Code Skeletons & Templates

| File | Path | Purpose |
|------|------|---------|
| `AdvancedFunction.ps1` | `/templates/powershell/AdvancedFunction.ps1` | Self-defensive PowerShell function template with StrictMode, ShouldProcess, etc. |
| `Module.psm1` | `/templates/powershell/Module.psm1` | PowerShell module template with proper manifest |
| `Module.psd1` | `/templates/powershell/Module.psd1` | PowerShell module manifest template |
| `Pester.Tests.ps1` | `/templates/powershell/Pester.Tests.ps1` | Pester test template for PowerShell functions |
| `python_cli.py` | `/templates/python/python_cli.py` | Python CLI template with argparse, logging, type hints |
| `test_template.py` | `/templates/python/test_template.py` | Pytest test template |
| `pyproject.toml` | `/templates/python/pyproject.toml` | Python project configuration template |
| `typescript_module.ts` | `/templates/typescript/typescript_module.ts` | TypeScript module template with strict typing |

---

### Pre-commit Configuration

| File | Path | Purpose |
|------|------|---------|
| `.pre-commit-config.yaml` | `/.pre-commit-config.yaml` | Pre-commit hook configuration running all local validators |
| `install-hooks.ps1` | `/scripts/hooks/install-hooks.ps1` | Script to install Git hooks on developer machines |
| `pre-commit.ps1` | `/scripts/hooks/pre-commit.ps1` | Custom pre-commit logic (can be invoked by .pre-commit-config.yaml) |

---

### CI/CD Workflows

| File | Path | Purpose |
|------|------|---------|
| `quality.yml` | `/.github/workflows/quality.yml` | Main quality gate workflow (PSSA, Pester, linting, SAST, secrets) |
| `powershell-verify.yml` | `/.github/workflows/powershell-verify.yml` | Windows-specific PowerShell validation job |
| `python-verify.yml` | `/.github/workflows/python-verify.yml` | Python validation job (ruff, black, mypy, pytest) |
| `typescript-verify.yml` | `/.github/workflows/typescript-verify.yml` | TypeScript/JavaScript validation job |
| `sast-secrets.yml` | `/.github/workflows/sast-secrets.yml` | Semgrep and secret scanning job |
| `policy-check.yml` | `/.github/workflows/policy-check.yml` | OPA/Conftest policy validation job |
| `drift-detection.yml` | `/.github/workflows/drift-detection.yml` | Nightly job to detect drift in branch protections and guardrails |
| `renovate.json` | `/.github/renovate.json` | Renovate bot configuration for dependency updates |

---

### Audit & Observability

| File | Path | Purpose |
|------|------|---------|
| `New-RunLedgerEntry.ps1` | `/scripts/audit/New-RunLedgerEntry.ps1` | Creates signed JSONL entry for each validation run |
| `Get-RunLedger.ps1` | `/scripts/audit/Get-RunLedger.ps1` | Queries run ledger for analysis |
| `Export-WeeklyReport.ps1` | `/scripts/audit/Export-WeeklyReport.ps1` | Generates weekly quality metrics report |
| `Invoke-DriftDetection.ps1` | `/scripts/audit/Invoke-DriftDetection.ps1` | Checks for configuration drift in repo protections |
| `ledger.schema.json` | `/schemas/ledger.schema.json` | JSON Schema for run ledger entries |

---

### Database Schema

| File | Path | Purpose |
|------|------|---------|
| `schema.sql` | `/database/schema.sql` | SQLite/Postgres schema for access groups, tools, policies, and ledger |
| `seed_data.sql` | `/database/seed_data.sql` | Initial data for access groups and default policies |
| `migrations/` | `/database/migrations/` | Directory for database migration scripts |

---

### File Routing System (from Deterministic System doc)

| File | Path | Purpose |
|------|------|---------|
| `file_router.config.json` | `/file-routing/file_router.config.json` | Configuration mapping project codes to directory paths |
| `FileRouter_Watcher.ps1` | `/file-routing/FileRouter_Watcher.ps1` | Watches Downloads folder and routes files based on naming convention |
| `Naming_Convention_Guide.md` | `/file-routing/Naming_Convention_Guide.md` | Documentation of file naming convention (PROJECT-AREA-SUBFOLDER__name__timestamp__version__ulid__sha8) |

---

### Edit Engine (from deterministic edits doc)

| File | Path | Purpose |
|------|------|---------|
| `apply_patch.ps1` | `/tools/edit-engine/apply_patch.ps1` | Applies unified diff patches with logging |
| `apply_jsonpatch.ps1` | `/tools/edit-engine/apply_jsonpatch.ps1` | Applies RFC 6902 JSON Patch with schema validation |
| `run_comby.ps1` | `/tools/edit-engine/run_comby.ps1` | Runs structural refactors using Comby |
| `run_ast_mod.ps1` | `/tools/edit-engine/run_ast_mod.ps1` | Runs PowerShell AST-based codemods |
| `regenerate.ps1` | `/tools/edit-engine/regenerate.ps1` | Regenerates files from templates with parameters |

---

### Documentation

| File | Path | Purpose |
|------|------|---------|
| `ARCHITECTURE.md` | `/docs/ARCHITECTURE.md` | Detailed system architecture documentation |
| `GUARDRAILS.md` | `/docs/GUARDRAILS.md` | Comprehensive guardrail documentation and rationale |
| `MCP_INTEGRATION.md` | `/docs/MCP_INTEGRATION.md` | Guide to MCP server integration and configuration |
| `VALIDATION_PIPELINE.md` | `/docs/VALIDATION_PIPELINE.md` | SafePatch validation pipeline documentation |
| `AGENT_GUIDELINES.md` | `/docs/AGENT_GUIDELINES.md` | Best practices for AI agent usage with this system |
| `TROUBLESHOOTING.md` | `/docs/TROUBLESHOOTING.md` | Common issues and solutions |
| `conventions.md` | `/docs/conventions.md` | Code conventions for PowerShell, Python, and TypeScript |

---

### Testing Infrastructure

| File | Path | Purpose |
|------|------|---------|
| `fixtures/` | `/tests/fixtures/` | Directory containing test fixtures and golden data |
| `integration/` | `/tests/integration/` | Integration tests for the validation pipeline |
| `unit/` | `/tests/unit/` | Unit tests for individual components |
| `Invoke-IntegrationTests.ps1` | `/tests/Invoke-IntegrationTests.ps1` | Runs full integration test suite |

---

## Key Assumptions

1. **Multi-language Support**: System supports PowerShell, Python, and TypeScript with extensibility for other languages
2. **Windows-First**: Primary development on Windows with PowerShell, but cross-platform CI support
3. **GitHub-Based**: CI/CD assumes GitHub Actions, though adaptable to other platforms
4. **Local-First Validation**: Developers run the same validation locally that runs in CI
5. **Audit Trail**: All operations are logged to append-only JSONL with cryptographic signatures
6. **MCP as Interface**: All code quality tools are accessed through MCP servers with access controls
7. **Policy-Driven**: Enforcement rules are declarative (OPA/Conftest) rather than imperative
8. **No Network in Validation**: Sandboxes run offline to prevent data exfiltration and ensure determinism

---

## Integration Points

The files work together in this flow:

```
Developer writes code
    ↓
Pre-commit hooks trigger (.pre-commit-config.yaml)
    ↓
Local validation (Verify.ps1, format, lint, test)
    ↓
AI agent proposes changes via MCP tools
    ↓
ChangePlan validated against schema/policy
    ↓
SafePatch pipeline in ephemeral sandbox
    ↓
All gates pass → commit allowed
    ↓
CI runs same validation (quality.yml)
    ↓
Branch protection + CODEOWNERS review
    ↓
Merge to main
    ↓
Run ledger entry created
    ↓
Weekly reports generated
```

This architecture ensures **deterministic, repeatable, auditable** code quality enforcement while giving AI agents safe, constrained tools to assist development.