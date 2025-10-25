# SafePatch Validation Pipeline

1. **Formatting** — Invoke language-specific formatters in check mode.
2. **Linting** — Run static analysis via Ruff, PSScriptAnalyzer, ESLint, etc.
3. **Testing** — Execute unit and integration suites using Pytest and Pester.
4. **SAST** — Scan with Semgrep rulesets under `.semgrep/`.
5. **Policy** — Evaluate ChangePlan and diff outputs against schemas and OPA policies.
6. **Secrets** — Detect credentials with the secrets MCP server.
