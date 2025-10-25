# Contributing Guidelines

Thank you for helping improve the AI-Assisted Code Quality Enforcement System. These guidelines keep contributions consistent with the guardrail model.

## Development Workflow
1. Fork the repository and create a feature branch.
2. Run `./tools/Verify.ps1` to execute formatting, linting, unit tests, SAST, and policy validation before committing.
3. Ensure all changes produce a valid ChangePlan and unified diff when contributed via AI assistants.
4. Submit a pull request referencing relevant tickets or issues.

## Coding Standards
- Follow the formatting and lint rules defined in `tools/`.
- Use strongly-typed PowerShell constructs and avoid aliases.
- Keep Python code type-safe with `mypy` and prefer explicit imports.
- TypeScript must compile under the strict configuration in `tools/tsconfig.json`.

## Commit & PR Requirements
- Keep commits focused and include meaningful messages.
- Pull requests must pass all GitHub Actions workflows and include updated documentation or tests when behaviour changes.
- Include references to audit ledger entries when applicable.

Please open an issue if you have questions about these processes.
