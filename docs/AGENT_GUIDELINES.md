# Agent Guidelines

These guidelines outline how AI or human-in-the-loop agents should interact with
this repository to maintain compliance with AIUOKEEP guardrails.

## Behavioral Expectations
- **Plan Before Acting:** Produce a ChangePlan referencing file paths and actions
  prior to running commands or editing files.
- **Respect Directory Scopes:** Follow naming and placement conventions defined in
  `docs/conventions.md` and `file-routing/Naming_Convention_Guide.md`.
- **Use Provided Tooling:** Run validation scripts (`tools/Verify.ps1`,
  `scripts/validation/*.ps1`) instead of custom commands.
- **Cite Sources:** When documenting or summarizing changes, reference files and
  command output using the standardized citation format.

## Command Execution Rules
- Prefer PowerShell scripts under `scripts/` for automation on Windows and the
  provided shell scripts for Linux sandbox operations.
- Avoid network access unless explicitly granted; sandbox scripts default to
  network isolation.
- Do not install additional system packages; rely on repository-managed tools.

## Validation Workflow
1. Draft ChangePlan and review guardrail documents relevant to the change.
2. Apply modifications via deterministic edit engine scripts or well-scoped
   patches.
3. Execute `tools/Verify.ps1` locally; ensure SafePatch stages pass.
4. Attach validation results and ledger references in review or PR descriptions.

## Documentation Requirements
- Update relevant documentation (this folder and `README.md`) whenever modifying
  guardrail behavior, validation pipelines, or MCP integrations.
- Include rationale for changes and reference affected scripts or policies.

## Escalation Path
- If a guardrail blocks progress and cannot be satisfied, capture the failure
  logs, articulate the risk, and submit an issue for policy review.
- Use `/scripts/audit/Export-WeeklyReport.ps1` to surface recurring failures or
  drift trends to the governance team.
