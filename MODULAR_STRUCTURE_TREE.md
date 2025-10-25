# Modular Structure File Tree

```
/
├── .editorconfig
├── .gitignore
├── .pre-commit-config.yaml
├── LICENSE
├── README.md
├── CONTRIBUTING.md
├── AIUOKEEP.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── GUARDRAILS.md
│   ├── MCP_INTEGRATION.md
│   ├── VALIDATION_PIPELINE.md
│   ├── AGENT_GUIDELINES.md
│   ├── TROUBLESHOOTING.md
│   └── conventions.md
├── .github/
│   ├── renovate.json
│   └── workflows/
│       ├── quality.yml
│       ├── powershell-verify.yml
│       ├── python-verify.yml
│       ├── typescript-verify.yml
│       ├── sast-secrets.yml
│       ├── policy-check.yml
│       └── drift-detection.yml
├── .mcp/
│   ├── access_groups.json
│   ├── mcp_servers.json
│   ├── Get-DesiredStateConfiguration.ps1
│   ├── Get-McpConfiguration.ps1
│   ├── Initialize-McpEnvironment.ps1
│   ├── New-McpConfigurationObject.ps1
│   ├── Set-McpConfiguration.ps1
│   └── Test-McpEnvironment.ps1
├── mcp-servers/
│   ├── powershell/
│   │   └── ps_quality_mcp.ps1
│   ├── python/
│   │   └── quality_mcp.py
│   ├── sast/
│   │   └── semgrep_mcp.py
│   ├── secrets/
│   │   └── secrets_mcp.py
│   └── policy/
│       └── policy_mcp.py
├── policy/
│   ├── schemas/
│   │   ├── changeplan.schema.json
│   │   └── unifieddiff.schema.json
│   ├── opa/
│   │   ├── changeplan.rego
│   │   ├── delivery_bundle.rego
│   │   └── forbidden_apis.rego
├── .semgrep/
│   ├── semgrep.yml
│   ├── semgrep-powershell.yml
│   ├── semgrep-python.yml
│   └── semgrep-secrets.yml
├── tools/
│   ├── Verify.ps1
│   ├── PSScriptAnalyzerSettings.psd1
│   ├── ruff.toml
│   ├── mypy.ini
│   ├── pytest.ini
│   ├── .eslintrc.json
│   ├── tsconfig.json
│   └── edit-engine/
│       ├── apply_patch.ps1
│       ├── apply_jsonpatch.ps1
│       ├── run_comby.ps1
│       ├── run_ast_mod.ps1
│       └── regenerate.ps1
├── scripts/
│   ├── validation/
│   │   ├── Invoke-FormatCheck.ps1
│   │   ├── Invoke-LintCheck.ps1
│   │   ├── Invoke-PolicyCheck.ps1
│   │   ├── Invoke-SafePatchValidation.ps1
│   │   ├── Invoke-SastScan.ps1
│   │   ├── Invoke-SecretScan.ps1
│   │   ├── Invoke-TypeCheck.ps1
│   │   ├── Invoke-UnitTests.ps1
│   │   ├── Test-ChangePlan.ps1
│   │   └── Test-UnifiedDiff.ps1
│   ├── sandbox/
│   │   ├── New-EphemeralWorkspace.ps1
│   │   ├── Remove-EphemeralWorkspace.ps1
│   │   ├── sandbox_linux.sh
│   │   └── sandbox_windows.ps1
│   ├── hooks/
│   │   ├── install-hooks.ps1
│   │   └── pre-commit.ps1
│   └── audit/
│       ├── Export-WeeklyReport.ps1
│       ├── Get-RunLedger.ps1
│       ├── Invoke-DriftDetection.ps1
│       └── New-RunLedgerEntry.ps1
├── schemas/
│   └── ledger.schema.json
├── database/
│   ├── schema.sql
│   ├── seed_data.sql
│   └── migrations/
├── file-routing/
│   ├── FileRouter_Watcher.ps1
│   ├── Naming_Convention_Guide.md
│   └── file_router.config.json
├── templates/
│   ├── powershell/
│   │   ├── AdvancedFunction.ps1
│   │   ├── Module.psd1
│   │   ├── Module.psm1
│   │   └── Pester.Tests.ps1
│   ├── python/
│   │   ├── pyproject.toml
│   │   ├── python_cli.py
│   │   └── test_template.py
│   └── typescript/
│       └── typescript_module.ts
├── tests/
│   ├── fixtures/
│   ├── integration/
│   ├── unit/
│   └── Invoke-IntegrationTests.ps1
```

*Note: Files listed are derived from `AIUOKEEP.md` and represent the desired modular architecture of the system.*
