# Agent Guidelines

- Always generate a ChangePlan that conforms to `policy/schemas/changeplan.schema.json`.
- Provide unified diffs that match `policy/schemas/unifieddiff.schema.json`.
- Run `tools/Verify.ps1` or the equivalent MCP commands before proposing commits.
- Reference audit ledger entries when handing over work to human maintainers.
