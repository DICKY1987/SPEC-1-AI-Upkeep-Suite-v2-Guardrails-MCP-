# Troubleshooting Playbook

Use this playbook to diagnose and resolve issues encountered while operating the
AI-Assisted Code Quality Enforcement System.

## MCP Configuration Issues
- **Symptom:** `Test-McpEnvironment.ps1` reports unreachable servers.
  - Verify host/port configuration in `/.mcp/mcp_servers.json`.
  - Ensure service scripts under `/mcp-servers/` have execution permissions and
    required runtimes installed.
- **Symptom:** Access denied when invoking tools.
  - Confirm the caller's role is mapped in `/.mcp/access_groups.json`.
  - Review recent changes in the ledger to detect unauthorized modifications.

## SafePatch Pipeline Failures
- **Formatting/Linting Errors:** Run `tools/Verify.ps1 -Stage Format` or `-Stage
  Lint` to scope the failure and follow remediation guidance from rule output.
- **Type Errors:** Cross-check mypy configuration in `tools/mypy.ini` and ensure
  stubs are available for external libraries.
- **Test Failures:** Use `tests/Invoke-IntegrationTests.ps1` or language-specific
  test runners with verbose logging.

## Policy & Guardrail Blocks
- **OPA Denials:** Execute `scripts/validation/Invoke-PolicyCheck.ps1 -Verbose`
  to view rule-level decisions. Update ChangePlan metadata or request policy
  exceptions through governance review.
- **Semgrep Findings:** Inspect the SARIF/JSON output captured in the validation
  artifacts. Use rule IDs to find remediation guidance.

## Sandbox Problems
- **Workspace Creation Fails:** Confirm `New-EphemeralWorkspace.ps1` has access to
  the Git remote and required credentials. Inspect temporary directories for
  leftover locks and remove via `Remove-EphemeralWorkspace.ps1 -Force`.
- **Network Isolation Issues:** Validate firewall or namespace rules applied by
  sandbox scripts; ensure tests do not require internet access.

## Audit Discrepancies
- **Missing Ledger Entries:** Run `/scripts/audit/Get-RunLedger.ps1` and compare
  against validation job IDs. Re-run validation with `-AuditOnly` flag to rebuild
  entries without executing tools.
- **Drift Alerts:** Follow `/scripts/audit/Invoke-DriftDetection.ps1` guidance to
  align desired and actual configuration states.

## Escalation
If issues persist after following the steps above, collect logs, ChangePlans,
and validation artifacts, then escalate to the governance team through the
repository issue tracker or designated communication channel.
