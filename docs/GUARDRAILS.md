# Guardrail Principles

The guardrail layer ensures that AI-assisted changes remain deterministic and compliant.

1. **Structured Prompts** — MCP tools require schema-constrained inputs and outputs.
2. **Policy-as-Code** — OPA policies validate ChangePlans and forbid risky APIs.
3. **Full Validation** — SafePatch runs the entire format → lint → test → SAST → policy chain prior to acceptance.
4. **Auditability** — Every run is captured in the ledger defined by `schemas/ledger.schema.json`.
