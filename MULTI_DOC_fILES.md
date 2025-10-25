**guardrail stack** 

# Guardrail stack (from prompt → PR → main)

## 1) Repo scaffolding & style that tools can enforce

* **EditorConfig** at repo root to lock whitespace, line endings, encodings across editors and OSes. ([spec.editorconfig.org][1])
* **Conventional Commits** for machine-readable history + changelog/semver automation; enforce via a commit-msg hook. ([conventionalcommits.org][2])
* **CODEOWNERS** to route reviews to subject owners automatically. ([GitHub Docs][3])
* **Branch protection rules** so merges require passing checks, reviews, and linear history. ([GitHub Docs][4])

## 2) “Structured output” constraints for AI agents (stop nonsense early)

* Wrap agents with libraries that **constrain generation** to schemas/grammars so they can’t invent shapes or fields:

  * **NVIDIA NeMo Guardrails** (Colang flows, topic & tool-use control). ([NVIDIA Docs][5])
  * **Guardrails AI** (Pydantic/RAIL schemas, validators, JSON guarantees). ([guardrails][6])
  * **Guidance / llguidance** (regex/CFG-level constrained decoding). ([GitHub][7])
  * **Outlines** (type/JSON/grammar-guaranteed decoding; LangChain provider available). ([dottxt-ai.github.io][8])
  * **LMQL** (typed prompts + constraint-guided generation). ([lmql.ai][9])
    These frameworks make the agent **emit only valid JSON/specs/tests** your CI expects, which slashes “made-up cmdlets/functions.”

## 3) Language-specific static analysis (catch errors before runtime)

* **PowerShell**: **PSScriptAnalyzer** in dev and CI; add custom rules (ban aliases, enforce Approved Verbs, module manifests). ([Microsoft Learn][10])
* **Python**: **Ruff** (lint/format) + **mypy** (types). ([Astral Docs][11])
* **TypeScript/JS**: `tsconfig.json` with `"strict": true` (plus ESLint/tsc in CI). ([typescriptlang.org][12])
* **Semgrep** for repo-wide, language-agnostic rules (security & code patterns) that you can tune per policy. ([Semgrep][13])

## 4) Test-first generation and gating

* **PowerShell tests**: **Pester** (unit/integration/mocking) and make agents generate tests with the code. Gate PRs on Pester pass. ([Pester][14])
* Property-based tests (e.g., Hypothesis for Python) and mutation testing (e.g., Stryker for JS) are great upgrades later.

## 5) Pre-commit hooks (local & CI-mirrored)

* Use **pre-commit** to run linters/formatters/secret scans before any commit; mirror the exact hooks in CI so nothing slips in. ([Pre-Commit][15])

## 6) Policy-as-code for configs produced by agents

* **OPA + Conftest**: write Rego policies to validate YAML/JSON/TOML emitted by agents (e.g., “scripts must import approved modules,” “only approved cmdlets,” “no dangerous params”). Run in pre-commit and CI. ([Open Policy Agent][16])

## 7) Dependency hygiene to avoid drift

* **Renovate** bot auto-PRs pin/upgrade dependency versions (monorepos supported). Gate merges on tests. ([Renovate Docs][17])

## 8) Build graph + caching for scale (monorepos)

* If the project grows big: **Nx** (task graph, affected-only runs, caching) or **Bazel** (language-agnostic, hermetic builds/tests). They shrink CI time and ensure everything actually builds. ([Nx][18])

## 9) CI gates that **block hallucinations**

In GitHub Actions (example components & references):

* **PSScriptAnalyzer** step (fail on any error/warn). ([GitHub][19])
* **Run Pester** step with coverage & test artifacts. ([GitHub Docs][20])
* **Semgrep scan** for patterns/security. ([Semgrep][13])
* **pre-commit CI** to re-run exact local hooks server-side. ([Pre-Commit][15])
* **Conftest** policy checks over any generated configs/specs. ([Conftest][21])
* Enforce via **branch protection rules** + **CODEOWNERS** review. ([GitHub Docs][4])

## 10) PowerShell-specific hardening patterns for agents to follow

* Every script/module template should include:
  `#Requires -Version 5.1`, `Set-StrictMode -Version Latest`, `$ErrorActionPreference='Stop'`, **no aliases**, **Approved Verbs**, explicit `param()` with types, and Pester tests for **Import-Module**, **Get-Command** sanity. Enforce via PSScriptAnalyzer rules & tests. ([Microsoft Learn][10])

## 11) “Contract-first” generation to stop made-up functions

* Make agents **generate against contracts**: OpenAPI/JSON-Schema/Pydantic models/TypeScript types. Validate artifacts in CI so any call to a non-existent symbol or wrong shape fails fast (Semgrep rules + type checkers + Pester). (OpenAPI & JSON Schema are the usual contract sources.) ([spec.editorconfig.org][1])

## 12) Runbooks for agents (“how to behave”)

Give each coding agent a short policy it must follow:

* Only use functions/cmdlets that **exist** in this repo or in an allowed allowlist.
* If you propose a new helper, **also generate** its file + tests in the same PR.
* Emit a **change plan JSON** (schema-validated) and Pester tests **before** writing code (tools above will reject non-conforming output).

---

## Minimal, copy-pasteable setup (PowerShell-centric, works cross-lang)

**.editorconfig** (root)

```ini
root = true

[*]
end_of_line = lf
insert_final_newline = true
charset = utf-8
indent_style = space
indent_size = 2
```

**.pre-commit-config.yaml**

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: check-yaml
      - id: end-of-file-fixer
      - id: trailing-whitespace
  - repo: https://github.com/awslabs/git-secrets
    rev: 1.3.0
    hooks:
      - id: git-secrets
  - repo: local
    hooks:
      - id: psscriptanalyzer
        name: PSScriptAnalyzer
        entry: pwsh -NoLogo -NoProfile -Command "Install-Module PSScriptAnalyzer -Scope CurrentUser -Force; Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning; if($LASTEXITCODE -ne 0){exit 1}"
        language: system
        files: \.(ps1|psm1|psd1)$
      - id: semgrep
        name: semgrep
        entry: semgrep scan --config=auto
        language: system
        pass_filenames: false
```

(Pre-commit runs locally; we mirror these steps in CI.) ([Pre-Commit][15])

**.github/workflows/ci.yml** (GitHub Actions)

```yaml
name: CI
on:
  pull_request:
  push: { branches: [main] }
jobs:
  ps:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup PowerShell modules
        run: |
          Set-PSRepository PSGallery -InstallationPolicy Trusted
          Install-Module PSScriptAnalyzer -Force
          Install-Module Pester -Force
      - name: Lint (PSScriptAnalyzer)
        uses: microsoft/psscriptanalyzer-action@v1.0
        with:
          path: .\
          recurse: true
          output: results.sarif
      - name: Test (Pester)
        uses: PSModule/Invoke-Pester@v1
        with:
          Script: ./tests
          EnableExit: true
  semgrep:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pipx install semgrep && semgrep scan --config=auto
```

([GitHub][19])

**CODEOWNERS** (example)

```
# PowerShell modules
src/powershell/**  @your-org/ps-core-team
# CI & policies
.github/**         @your-org/devex
```

([GitHub Docs][3])

**Branch protection**: Require “CI” workflow success + 1+ CODEOWNERS review; disallow force-pushes. ([GitHub Docs][4])

**Conftest** (policy example for generated task JSON)
`policy/tasks.rego`

```rego
package tasks

deny[msg] {
  input.name == ""
  msg := "task.name is required"
}

deny[msg] {
  not input.owner
  msg := "task.owner is required"
}
```

Run: `conftest test artifacts/tasks/*.json`. ([Conftest][21])

**Renovate** (dependency drift) – add `renovate.json` and enable the bot. ([Renovate Docs][17])

---

## How this stops “made-up cmdlets” & symbol drift

1. **Constrained generation** (Guardrails/Outlines/Guidance/LMQL) prevents invalid shapes and enforces the plan/test schema before code is written. ([guardrails][6])
2. **PSScriptAnalyzer + custom rules** flag unapproved verbs, aliases, missing module manifests, etc. ([Microsoft Learn][10])
3. **Pester** asserts that referenced functions/cmdlets actually exist (`Get-Command` checks), and modules import cleanly. ([Pester][14])
4. **Semgrep** bans anti-patterns or forbidden APIs across the repo. ([Semgrep][13])
5. **Conftest** rejects malformed agent outputs (work plans, configs) **before** they reach code. ([Conftest][21])
6. **Branch protection + CODEOWNERS** make it impossible to merge until all checks pass and owners sign off. ([GitHub Docs][4])

---

## Recommended tools (shortlist)

* **PowerShell**: PSScriptAnalyzer, Pester (with GitHub Actions integrations). ([Microsoft Learn][10])
* **Cross-language**: pre-commit, Semgrep, OPA/Conftest, Renovate. ([Pre-Commit][15])
* **Monorepo scale**: Nx or Bazel for build/test graphing & caching. ([Nx][18])
* **AI guardrails**: NeMo Guardrails, Guardrails AI, Guidance/Outlines/LMQL. ([NVIDIA Docs][5])

---

## Quick start order (you can do this today)

1. Add **.editorconfig**, **CODEOWNERS**, **Conventional Commits** note in CONTRIBUTING. ([editorconfig.org][22])
2. Install **pre-commit** and enable PSScriptAnalyzer + Semgrep hooks. ([Pre-Commit][15])
3. Add the **CI workflow** above + enable **branch protection** on `main`. ([GitHub][19])
4. Introduce **Pester tests** for every new script (agents must generate tests). ([Pester][14])
5. Wrap your AI agents with **Guardrails/Outlines/Guidance** so they can only emit your JSON “work plan” + test stubs. ([guardrails][6])
6. Add **Conftest** policies to reject malformed plans/configs. ([Conftest][21])
7. Turn on **Renovate** to eliminate dependency drift. ([Renovate Docs][17])



[1]: https://spec.editorconfig.org/index.html?utm_source=chatgpt.com "EditorConfig Specification — EditorConfig Specification 0.17.2 ..."
[2]: https://www.conventionalcommits.org/en/v1.0.0/?utm_source=chatgpt.com "Conventional Commits"
[3]: https://docs.github.com/articles/about-code-owners?utm_source=chatgpt.com "About code owners"
[4]: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule?utm_source=chatgpt.com "Managing a branch protection rule"
[5]: https://docs.nvidia.com/nemo-guardrails/index.html?utm_source=chatgpt.com "NVIDIA NeMo Guardrails"
[6]: https://www.guardrailsai.com/docs?utm_source=chatgpt.com "Introduction | Your Enterprise AI needs Guardrails"
[7]: https://github.com/guidance-ai/guidance?utm_source=chatgpt.com "A guidance language for controlling large language models."
[8]: https://dottxt-ai.github.io/outlines/?utm_source=chatgpt.com "Outlines"
[9]: https://lmql.ai/docs/?utm_source=chatgpt.com "Getting Started"
[10]: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules&utm_source=chatgpt.com "PSScriptAnalyzer module - PowerShell"
[11]: https://docs.astral.sh/ruff/?utm_source=chatgpt.com "Ruff - Astral Docs"
[12]: https://www.typescriptlang.org/tsconfig/strict.html?utm_source=chatgpt.com "TSConfig Option: strict"
[13]: https://semgrep.dev/docs/semgrep-code/overview?utm_source=chatgpt.com "Semgrep Code overview"
[14]: https://pester.dev/docs/quick-start?utm_source=chatgpt.com "Quick Start | Pester"
[15]: https://pre-commit.com/?utm_source=chatgpt.com "pre-commit"
[16]: https://openpolicyagent.org/docs?utm_source=chatgpt.com "Introduction"
[17]: https://docs.renovatebot.com/?utm_source=chatgpt.com "Renovate Docs"
[18]: https://nx.dev/?utm_source=chatgpt.com "Nx: Smart Repos · Fast Builds"
[19]: https://github.com/microsoft/psscriptanalyzer-action?utm_source=chatgpt.com "microsoft/psscriptanalyzer-action"
[20]: https://docs.github.com/actions/automating-builds-and-tests/building-and-testing-powershell?utm_source=chatgpt.com "Building and testing PowerShell"
[21]: https://www.conftest.dev/?utm_source=chatgpt.com "Conftest"
[22]: https://editorconfig.org/?utm_source=chatgpt.com "EditorConfig"


END OF DOCUMENT 

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

front_load refactoring 
 
# How devs refactor & optimize—and how to shift it left

## 1) Start from a hardened template (pre-bakes many refactors)

Use an **advanced-function** template with: `Set-StrictMode -Version Latest`, `$ErrorActionPreference='Stop'`, approved verb naming, parameter validation, pipeline support, comment-based help, and structured error handling. Microsoft’s guidance on advanced functions, approved verbs, parameters, and try/catch spells out the patterns you want in every new script. ([Microsoft Learn][1])

**Why this reduces later refactoring:** you avoid renames (unapproved verbs), inconsistent parameter behavior, and brittle error paths—classic “code smells” you’d otherwise fix post-hoc. Refactoring literature (Fowler’s catalog; code-smell guides) backs this “design for clarity first” approach. ([refactoring.com][2])

## 2) Make tests part of creation (design for testability)

Insist that every new script ships with **Pester** tests (import, parameter validation, behavior). Have your agent generate tests first (or alongside code) and block saves/PRs unless tests pass. Pester is the standard PowerShell test & mock framework. ([Pester][3])

**What to test up front**

* `Import-Module`/dot-sourcing succeeds.
* `Get-Command` finds the function and verb is approved.
* Inputs: parameter sets, `Validate*` attributes, pipeline input.
* Error paths: throws on invalid input; emits useful messages.

## 3) Lint on save; fail on commit (static analysis)

Run **PSScriptAnalyzer** as-you-type (VS Code) and again in pre-commit/CI. Enforce rules like **UseApprovedVerbs**, avoid aliases, require help, and module manifests for anything shared. This catches “made-up cmdlets/functions” and stylistic drift before the file ever leaves your editor. ([Microsoft Learn][4])

## 4) Ship modules, not loose scripts, when reuse is likely

If it’s used more than once, put it in a module with a proper **module manifest** (`New-ModuleManifest`) and validate with `Test-ModuleManifest`. This normalizes exports, dependencies, and versioning at day one. ([Microsoft Learn][5])

## 5) Encode refactoring heuristics as guardrails

Common refactorings (“Extract Function,” “Introduce Parameter Object,” “Replace Magic Number with Constant,” etc.) can be **prompted** and **automated**:

* Teach your agents a refactoring checklist (from Fowler’s catalog) and **require** they apply 2–3 where relevant before finalizing code. ([refactoring.com][2])
* Add **Semgrep** / PSScriptAnalyzer custom rules to flag smells (long functions, unused parameters, aliases) so agents must fix them immediately. (Semgrep is general; PSSA is PS-specific.) ([SonarSource][6])

## 6) Error handling is a design choice, not an afterthought

Adopt consistent **try/catch/finally** patterns and terminate on failures (`-ErrorAction Stop`) so errors are testable and predictable. Microsoft’s deep dive makes the behaviors explicit—have agents follow it. ([Microsoft Learn][7])

---

# A “First-Attempt Quality” creation pipeline (copy this flow)

1. **Scaffold** from your company template (advanced function + header + help + tests folder). Patterns taken from MS docs above. ([Microsoft Learn][1])
2. **Generate tests first** (Pester) for inputs/outputs & failure cases. ([Pester][3])
3. **Constrain the agent’s output**: require it to emit only code that passes PSScriptAnalyzer (fail the run if diagnostics exist) and uses approved verbs; reject non-conforming output. ([Microsoft Learn][4])
4. **Run PSSA + Pester automatically** on file save (editor), on commit (pre-commit), and in CI (PR). ([Microsoft Learn][4])
5. **Package as a module** when reuse is expected; validate `*.psd1`. ([Microsoft Learn][5])
6. **Refactor checklist pass**: before finalizing, agent must apply small, behavior-preserving refactors from a short list (e.g., extract helper; rename to approved verb; add parameter validation; document error behavior). ([refactoring.com][2])

---

# Tools & settings that make this automatic

* **PSScriptAnalyzer** (lint/format; VS Code + CLI). Set rules to error on violations; include UseApprovedVerbs. ([Microsoft Learn][4])
* **Pester** (unit & integration tests with mocks). Make “red → green → refactor” the default loop. ([Pester][3])
* **Module manifests** via `New-ModuleManifest` + `Test-ModuleManifest` for predictable exports/versioning. ([Microsoft Learn][5])
* **Refactoring catalogs** (Fowler, Refactoring.Guru) to teach agents named refactors and code-smell vocabulary. ([refactoring.com][2])
* **Semgrep (optional)** for cross-language policy & smell checks if your repo mixes PS with other languages. ([SonarSource][6])

---

# Tiny, practical “front-load” checklist for every new script

* [ ] Name uses **Approved Verb-Noun** (e.g., `Get-`, `Set-`, `New-`). ([Microsoft Learn][8])
* [ ] `param()` has **types** + `Validate*` attributes; supports **pipeline** if appropriate. ([Microsoft Learn][9])
* [ ] `Set-StrictMode`, `$ErrorActionPreference='Stop'`, **try/catch** with meaningful messages. ([Microsoft Learn][10])
* [ ] Comment-based **help** section present. ([Microsoft Learn][1])
* [ ] **Pester tests** exist and pass (import, parameters, behavior, errors). ([Pester][3])
* [ ] **PSScriptAnalyzer** passes with zero warnings/errors (local + CI). ([Microsoft Learn][4])
* [ ] If reusable, **module + manifest** created and validated. ([Microsoft Learn][5])


[1]: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced?view=powershell-7.5&utm_source=chatgpt.com "about_Functions_Advanced - PowerShell"
[2]: https://refactoring.com/catalog/?utm_source=chatgpt.com "Catalog of Refactorings"
[3]: https://pester.dev/docs/quick-start?utm_source=chatgpt.com "Quick Start | Pester"
[4]: https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules&utm_source=chatgpt.com "PSScriptAnalyzer module - PowerShell"
[5]: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/new-modulemanifest?view=powershell-7.5&utm_source=chatgpt.com "New-ModuleManifest - PowerShell"
[6]: https://www.sonarsource.com/resources/library/code-smells/?utm_source=chatgpt.com "What is a Code Smell? Definition Guide, Examples & ..."
[7]: https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-exceptions?view=powershell-7.5&utm_source=chatgpt.com "Everything you wanted to know about exceptions"
[8]: https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.5&utm_source=chatgpt.com "Approved Verbs for PowerShell Commands"
[9]: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters?view=powershell-7.5&utm_source=chatgpt.com "about_Functions_Advanced_Par..."
[10]: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally?view=powershell-7.5&utm_source=chatgpt.com "about_Try_Catch_Finally - PowerShell"




END OF DOCUMENT 

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**when to use AI**

---

# A quick decision rule (use this before every task)

**Pick the *smallest* agent that can do the job predictably.**

1. **Straightforward/Repeatable (low ambiguity) →** shell/PowerShell scripts + templates (no AI).
2. **Structured generation (tests/specs/changelogs) →** AI that outputs **schema-constrained JSON** you validate in CI (reject on mismatch). Tools like Guardrails/Outlines/Guidance/LMQL do this. ([Semgrep][1])
3. **Code edits inside a repo with diffs →** lightweight, local, git-aware assistants (Aider, Continue CLI) *with pre-commit & CI gates*. ([Aider][2])
4. **Big, multi-step changes touching tools/commands →** a full “computer-use” agent (OpenHands or Open Interpreter) in a **sandboxed workspace**/**worktree**, still gated by tests. ([GitHub][3])
5. **Security/dep hygiene →** let specialized bots do it (Semgrep Assistant for autofix, Renovate for deps). ([Semgrep][4])

---

# Agent roles that *pay for themselves* (use only the ones you need)

* **Spec-and-Tests First Buddy**
  Prompts agent to generate: user story → acceptance tests (Pester) → function skeleton. CI rejects code that doesn’t satisfy tests. (Pester is the PowerShell standard.) ([pester.dev][5])

* **Git-Aware Code Editor (diff-only)**
  Runs in your terminal/IDE, edits only files you’ve “added,” commits atomic diffs. (Great for controlled, low-drift edits.) Aider and Continue excel here. ([Aider][2])

* **Computer-Use Agent (sandboxed)**
  For tasks that need running commands, building, or quick E2E exploration; limit it to a **throwaway worktree/container** and snapshot results. (OpenHands, Open Interpreter.) ([GitHub][3])

* **Static-Analysis Autofix**
  Let Semgrep Assistant propose/fix issues in PRs; you review & merge. It reduces “error-modification loops” on security/style rules. ([Semgrep][4])

* **Dependency Upgrader**
  Renovate opens PRs with pinned, test-gated updates—no general-purpose AI needed. ([GitHub][6])

---

# Guardrails that keep AI honest (the “constraint ladder”)

1. **Schema-constrain outputs** (plans/tests/JSON config) so the model *must* produce valid shapes—reject otherwise. (Guardrails-style libraries.) ([Semgrep][1])
2. **Pre-commit hooks**: run PSScriptAnalyzer, tests, secret scans locally before any commit. Mirror the same checks in CI to block drift. ([GitHub][7])
3. **CI gates**: on every PR, run PSScriptAnalyzer + Pester; fail on any error/warn. ([GitHub][7])
4. **Sandbox edits**: require agents to work in git worktrees/branches; only merge via PR after checks. (Works especially well with Aider/Continue.) ([Aider][2])
5. **Specialized bots** for security/deps instead of general AI (Semgrep Assistant, Renovate). ([Semgrep][4])

---

# Cost model: when a paid agent is cheaper than “avoid tokens”

Use this quick triage:

* **Local/open-source first** for *narrow* edits (Aider/Continue CLI). If it passes in one shot, you spent near-zero. ([Aider][2])
* **Escalate to paid** only when:

  * The change spans **many files** or requires **tool execution** to iterate (integration failures).
  * You need **security-grade remediation** (Semgrep Assistant in CI can save hours). ([Semgrep][4])
  * You’ve hit **two failed local attempts**; further retries will cost *more* time/tokens than a stronger single pass.
* **Always cap**: set max-turn and cost ceilings per run; force agents to emit a **plan JSON** first; abort if plan size/scope explodes.

---

# A minimal, low-drift pipeline you can run today

1. **Pre-commit**: PSScriptAnalyzer + tests (Pester). If it doesn’t pass locally, it can’t be committed. ([GitHub][7])
2. **Local agent** (Aider or Continue CLI) edits only selected files; you approve diffs. ([Aider][2])
3. **PR checks**: PSScriptAnalyzer action + Pester on Windows runner; optional Semgrep Assistant review comments. ([GitHub][7])
4. **Background hygiene**: Renovate PRs for dependencies; you merge when CI is green. ([GitHub][6])
5. **Escalation**: If 1–2 cycles fail, spin a *sandboxed* OpenHands/Open Interpreter run in a throwaway worktree, then PR the diffs. ([GitHub][3])

---

# Concrete agent/tool picks (open-source heavy, vendor-neutral)

* **Aider (terminal pair-programmer, git-aware)** – great for scoped edits with atomic commits; lightweight token usage. ([Aider][2])
* **Continue (IDE + CLI, build your own agents)** – open-source, model-agnostic, runs in IDE/terminal/CI; easy to codify your rules. ([Continue][8])
* **Open Interpreter (local “computer-use”)** – lets the model run code/commands locally; pair with a sandbox. ([GitHub][9])
* **OpenHands (full software-dev agent)** – can edit code, run commands, browse; use only in sandboxes with strict gates. ([GitHub][3])
* **Semgrep Assistant** – AI remediation & autofix suggestions in PRs. ([Semgrep][4])
* **Renovate** – dependency PRs, schedules, monorepo support; free/open-source. ([GitHub][6])
* **PSScriptAnalyzer + Pester** – your must-have PowerShell lint + test duo. ([GitHub][7])

---

# Put this into practice (copy/paste playbook)

* **Always start** with a small, local agent (Aider/Continue) on a **branch** with **pre-commit** enabled. Escalate only if two attempts fail. ([Aider][2])
* **Force plan→tests→code**: agent must output a **plan JSON** and **Pester tests** first; you validate/trim scope; only then allow code. (Pester docs for quick scaffolds.) ([pester.dev][5])
* **Gates, not vibes**: PR must pass PSScriptAnalyzer + Pester; optional Semgrep Assistant comments must be addressed. ([GitHub][7])
* **Keep hygiene on rails**: Renovate handles deps; no general AI needed. ([GitHub][6])



[1]: https://semgrep.dev/docs/semgrep-assistant/overview?utm_source=chatgpt.com "Semgrep Assistant overview"
[2]: https://aider.chat/?utm_source=chatgpt.com "Aider - AI Pair Programming in Your Terminal"
[3]: https://github.com/All-Hands-AI/OpenHands?utm_source=chatgpt.com "OpenHands: Code Less, Make More"
[4]: https://semgrep.dev/blog/2024/ai-assisted-remediation?utm_source=chatgpt.com "Announcing AI-assisted remediation guidance on every PR"
[5]: https://pester.dev/docs/quick-start?utm_source=chatgpt.com "Quick Start | Pester"
[6]: https://github.com/renovatebot/renovate?utm_source=chatgpt.com "renovatebot/renovate: Home of the Renovate CLI"
[7]: https://github.com/microsoft/psscriptanalyzer-action?utm_source=chatgpt.com "microsoft/psscriptanalyzer-action"
[8]: https://www.continue.dev/?utm_source=chatgpt.com "Continue.dev"
[9]: https://github.com/openinterpreter/open-interpreter?utm_source=chatgpt.com "openinterpreter/open-interpreter: A natural language ..."

END OF DOCUMENT 

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 four “shapes” of edits 
 
 
# The edit “ladder” (from smallest → biggest)

1. **Structured field edits (configs)**

   * Use **JSON Patch (RFC 6902)** for precise operations like add/replace/remove on JSON (and YAML via JSON->YAML adapters). Great when you know exactly which keys change. ([IETF Datatracker][1])
   * Use **JSON Merge Patch (RFC 7386)** for simple “overlay” updates when you don’t need array ops. Smaller payloads, easier to read. ([IETF Datatracker][2])
   * Why it’s efficient: tiny payloads, deterministic application, easy to validate and roll back.

2. **Text/code line edits**

   * Standardize on **Unified Diff (unidiff)** and **apply via git**. Ask agents to output *only* unified diffs with correct file paths; you apply with `git apply --index` (or `git am` if you want to preserve commit metadata). ([GNU][3])
   * Why it’s efficient: smallest change-set, native to Git/CI/code review, trivial to revert. (And every tool understands it.) ([Wikipedia][4])

3. **Structure-aware refactors (many files, mechanical changes)**

   * Use language-agnostic **structural search/replace** tools like **Comby** for template-based rewrites across a codebase. ([comby.dev][5])
   * For syntax-aware changes, use **AST-based codemods** (e.g., **ast-grep** for many languages; PowerShell’s own **AST** via `System.Management.Automation.Language.Parser`). ([ast-grep.github.io][6])
   * Why it’s efficient: deterministic, repeatable “programmatic” edits; ideal for rename rules, API migrations, modifier/verb fixes, etc.

4. **Full-file rewrites**

   * Reserve for when the file is tiny, a template, or easier to regenerate than to patch. Most costly; highest risk of drift.

---

## When to use which

* **Config tweaks only?** → JSON Patch/Merge Patch (fastest, smallest). ([IETF Datatracker][1])
* **Small code fixes or PR feedback?** → Unified diff. ([GNU][3])
* **Repo-wide, mechanical change (rename verb, replace API, add param validations)?** → Comby or AST-based codemods, then commit the diffs they produce. ([comby.dev][5])
* **Large redesign or unreadable legacy script?** → Full rewrite (but still deliver as a diff).

---

## How to make this deterministic (tool-friendly)

1. **Pick standard schemas**

   * **Code/text:** unified diff (required). ([GNU][3])
   * **JSON/YAML configs:** RFC 6902 (JSON Patch) or RFC 7386 (Merge Patch). ([IETF Datatracker][1])

2. **Force agents to emit those schemas**

   * “When proposing changes, output either a unified diff or a JSON Patch array—no raw prose.”
   * Validate JSON Patches with a schema; reject on parse error.

3. **Apply changes with first-class tools**

   * `git apply --index file.patch` for code; preserves reviewability and makes reverts trivial. ([Git][7])
   * Use a JSON-Patch library/CLI to apply RFC-6902 atomically (many exist in PS/Python/Node).

4. **Automated safety nets**

   * **Semgrep** with **autofix** to turn findings into deterministic edits (pair this with diffs). ([Semgrep][8])
   * **PSScriptAnalyzer** (PowerShell) to fail builds on unapproved verbs/aliases; combine with AST or Comby codemods to auto-fix. ([Microsoft Learn][9])

---

## Concrete edit options you can standardize

* **Minimal line change:** unified diff (preferred for most scripts). Example hunk:

  ```
  --- a/scripts/Invoke-Thing.ps1
  +++ b/scripts/Invoke-Thing.ps1
  @@
  - Write-Host "Done"
  + Write-Output "Done"
  ```

  Apply with Git. Deterministic, reviewable. ([GNU][3])

* **Config change:** JSON Patch

  ```json
  [
    {"op":"replace","path":"/Logging/Level","value":"Information"},
    {"op":"add","path":"/Features/EnableTelemetry","value":false}
  ]
  ```

  Small, explicit, machine-verifiable. ([IETF Datatracker][1])

* **Mechanical refactor:** Comby pattern

  ```
  comby 'Write-Host :[x]' 'Write-Output :[x]' -matcher .ps1 -in .
  ```

  Or **ast-grep** rule to match/replace nodes safely across thousands of files. ([comby.dev][5])

* **PowerShell-specific AST pass:** parse the script to a `ScriptBlockAst`, find specific nodes, rewrite, and re-emit—great for enforcing **Approved Verbs**, adding `Set-StrictMode`, etc. ([Microsoft Learn][9])

---

## Efficiency & cost tips

* Prefer **patches over prose**: smaller tokens, less rework.
* For AI: require **“plan → patch”**. The model outputs a brief plan, then a **unified diff or JSON Patch only**. If it can’t, abort.
* Batch small fixes via **Semgrep autofix** or **Comby** (one PR). Save the “big model” for cases that truly need reasoning. ([Semgrep][8])

---

## A simple, repeatable flow you can adopt today

1. Open a feature branch/worktree.
2. Ask your agent: “Produce a **unified diff** for X” (or JSON Patch for config).
3. Apply: `git apply --index` (or JSON Patch tool). ([Git][7])
4. Run gates: **PSScriptAnalyzer**, tests, and (optional) **Semgrep autofix**. ([Microsoft Learn][9])
5. Commit → PR. If checks fail, prefer another **patch** over free-form rewrites.


[1]: https://datatracker.ietf.org/doc/html/rfc6902?utm_source=chatgpt.com "RFC 6902 - JavaScript Object Notation (JSON) Patch"
[2]: https://datatracker.ietf.org/doc/html/rfc7386?utm_source=chatgpt.com "RFC 7386 - JSON Merge Patch"
[3]: https://www.gnu.org/s/diffutils/manual/html_node/Unified-Format.html?utm_source=chatgpt.com "Unified Format (Comparing and Merging Files)"
[4]: https://en.wikipedia.org/wiki/Diff?utm_source=chatgpt.com "Diff"
[5]: https://comby.dev/?utm_source=chatgpt.com "Comby · Structural code search and replace for ~every ..."
[6]: https://ast-grep.github.io/?utm_source=chatgpt.com "ast-grep | structural search/rewrite tool for many languages"
[7]: https://git-scm.com/docs/git-apply?utm_source=chatgpt.com "Git - git-apply Documentation"
[8]: https://semgrep.dev/docs/writing-rules/autofix?utm_source=chatgpt.com "Autofix"
[9]: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.language.parser?view=powershellsdk-7.4.0&utm_source=chatgpt.com "Parser Class (System.Management.Automation.Language)"



END OF DOCUMENT 

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**deterministic, repeatable, auditable** ways to modify files
 
 
# Your goals (translated into mechanics)

* **Deterministic** → same inputs always produce the same output (pin tool versions, no randomness).
* **Repeatable** → one command can be re-run safely (idempotent or safely re-runnable).
* **Auditable** → every change leaves a machine-readable trail (diff, logs, hash, who/when/why).
* **Minimal AI** → prefer scripted edits; reserve AI for the few tasks that truly need it.

---

# The edit menu (from smallest → biggest)

## 1) Config-level edits (JSON/YAML/TOML)

**How:** Use RFC-standard patches instead of prose.

* **JSON Patch (RFC 6902)**: `add | remove | replace` specific fields and array items.
* **JSON Merge Patch (RFC 7386)**: overlay structure for simple “set these fields”.
* **Why deterministic:** schema-valid, tiny, exact; can validate before applying.
* **Typical flow:** patch file → schema validate → commit the resulting diff.

**Good for:** flags, thresholds, paths, version bumps.
**Speed:** ⭐⭐⭐⭐ (very fast) **Cost:** near-zero **Risk:** low

---

## 2) Text/line-level code edits (unified diff)

**How:** Have tools/scripts emit **unified diff** (`.patch`) files; apply with Git:

```
git apply --index edits/0001-fix.ps.patch
```

* **Why deterministic:** you’re applying exact hunks (line numbers + context).
* **Great for:** one-liners, small bugfixes, doc tweaks, PR feedback.
* **Tip:** keep patches small and focused (one atomic concern per patch).

**Speed:** ⭐⭐⭐⭐ **Cost:** near-zero **Risk:** low (native to Git/CI/review)

---

## 3) Structure-aware bulk refactors (mechanical, many files)

Two solid styles that don’t need AI:

* **Template/regex search–replace (language-aware):**
  Tools like **Comby** do structural patterns (safer than raw regex) across thousands of files.
* **AST codemods (syntax tree):**
  Use an AST tool for your language (e.g., PowerShell’s built-in AST, or generic tools like **ast-grep**). You write a small rule to “find X → rewrite to Y”.

**Why deterministic:** same pattern = same rewrite everywhere; no “interpretation.”
**Great for:** rename cmdlets to **Approved Verbs**, replace deprecated APIs, inject `Set-StrictMode`, add parameter validation, etc.

**Speed:** ⭐⭐⭐ (fast for big repos) **Cost:** near-zero **Risk:** low if rules are tested

---

## 4) Full-file regeneration (templates/scaffolds)

**How:** Keep golden templates for common script types (advanced functions, modules, tests). When a file is too messy to patch safely, **regenerate** from a template with parameters (author, module name, approved verb, etc.).
**Why deterministic:** templates are versioned; parameters are explicit.

**Great for:** brand-new files, ancient unfixable scripts.
**Speed:** ⭐⭐ (depends on template) **Cost:** near-zero **Risk:** moderate (bigger change set)

---

# Choosing quickly: a simple decision rule

1. **Is it a config field?** → JSON/merge patch.
2. **Is it a tiny code fix?** → unified diff.
3. **Is it the same change everywhere?** → Comby/AST codemod.
4. **Is the file beyond repair (or new)?** → regenerate from template.

When in doubt, start smaller (patch) and escalate only if needed.

---

# Make it **structured, repeatable, auditable**

## Standardize your inputs/outputs

* **Inputs**:

  * `*.patch` files (unified diff) for code/text.
  * `*.jsonpatch` (RFC 6902) or `*.mergepatch.json` (RFC 7386) for configs.
  * `codemods/*.rule` for Comby/AST rules.
  * `templates/*.tpl` + a parameters JSON for regeneration.
* **Outputs** (always machine-readable):

  * Git commits (one atomic change per commit).
  * A **change manifest** (JSONL) per run: timestamp, tool, version, file list, before/after hashes, exit codes.

## Pin versions and run modes

* Package your edit tools in a portable runner (PowerShell script or Makefile/Taskfile) that prints its **tool versions** at start.
* Add a **dry-run** flag for every operation; log the preview diff.

## Idempotency & safety

* For patches: check if patch is already applied; skip with a friendly message.
* For codemods: write rules so re-running has no effect (lookup the transformed shape).
* Always `git stash --keep-index` / `git worktree add` so failed runs don’t pollute your main branch.

---

# Example: a small, deterministic “Edit Engine” layout

```
/tools
  apply_patch.ps1          # git apply wrapper + logging
  apply_jsonpatch.ps1      # RFC 6902 apply + schema validate
  run_comby.ps1            # structural refactors
  run_ast_mod.ps1          # PowerShell AST codemods
  regenerate.ps1           # template -> file with params

/policies
  pssa.rules.psd1          # PSScriptAnalyzer rules
  semgrep.yml              # optional cross-lang safety rules

/edits
  0001-replace-host-with-output.patch
  0002-logging-level.mergepatch.json
  rename-unapproved-verbs.comby
  add-strictmode.ast.rule.json

/logs
  edits-2025-10-15.jsonl   # append-only manifest for audits
```

You’d run:

```
pwsh tools\apply_patch.ps1 edits\0001-replace-host-with-output.patch
pwsh tools\apply_jsonpatch.ps1 edits\0002-logging-level.mergepatch.json
pwsh tools\run_comby.ps1 edits\rename-unapproved-verbs.comby
pwsh tools\run_ast_mod.ps1 edits\add-strictmode.ast.rule.json
```

Each script: prints versions, does dry-run preview, applies, then writes a JSONL record.

---

# Where AI still helps (tightly constrained)

* **Generate the *patch* (not prose):** Ask the model for a **unified diff** only, or a **JSON Patch**. Your scripts validate & apply.
* **Draft codemod rules:** Let AI propose a Comby/AST rule; you test in dry-run.
* **Template filling:** Provide parameters; AI fills comments/help sections—your template controls structure.

> Key idea: AI proposes **inputs to your deterministic engine**, not raw file rewrites.

---

# Efficiency & speed: what’s usually faster?

| Approach             | Typical use                  |                        Speed | Determinism | Effort |
| -------------------- | ---------------------------- | ---------------------------: | :---------: | :----: |
| JSON/merge patch     | Config tweaks                |                         ⭐⭐⭐⭐ |     ⭐⭐⭐⭐    |    ⭐   |
| Unified diff         | Small code fixes             |                         ⭐⭐⭐⭐ |     ⭐⭐⭐⭐    |    ⭐   |
| Comby/AST codemods   | Repo-wide mechanical changes |                          ⭐⭐⭐ |     ⭐⭐⭐⭐    |   ⭐⭐   |
| Full regeneration    | New/irreparable files        |                           ⭐⭐ |     ⭐⭐⭐     | ⭐⭐–⭐⭐⭐ |
| AI free-form rewrite | Complex reasoning            | ⭐ (often slower from rework) |      ⭐      |   ⭐⭐⭐  |

In practice: **patches and codemods** are the sweet spot for speed + determinism. Full rewrites and unconstrained AI are last resorts.

---

# Minimal guardrails you should always enable

* **Pre-commit**: run PSScriptAnalyzer (PowerShell), tests (Pester), optional secret scans. Fail locally before commit.
* **CI gates**: re-run the same checks on PR; block merges unless green.
* **Branch/worktree**: apply edits on a feature branch/worktree; never on `main`.
* **Logging**: append-only JSONL manifest per run (who/what/when/versions/exit codes).
* **Rollback**: all changes are Git commits; `git revert` is your friend.


END OF DOCUMENT 

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Deterministic System


1. Use a **filename convention** that encodes project + subfolder + identity.
2. Run a small **PowerShell watcher** that looks at your Downloads folder, parses the name, and **moves the file to the right project path**—with hashing, duplicate handling, and JSONL audit logs.
3. Keep everything **repeatable and auditable** (no AI needed).

# Download the starter kit

* [Naming_Convention_Guide.md](sandbox:/mnt/data/file-routing-starter/Naming_Convention_Guide.md)
* [file_router.config.json](sandbox:/mnt/data/file-routing-starter/file_router.config.json)
* [FileRouter_Watcher.ps1](sandbox:/mnt/data/file-routing-starter/FileRouter_Watcher.ps1)
* [README.txt](sandbox:/mnt/data/file-routing-starter/README.txt)

# How it works (plain English)

* Name files like:
  `HUEY-PS-SCRIPTS__flatten-directory__20251015T081530Z__v1.0.0__u01JAB8...__s7a1c9e2.ps1`
  This tells the router: **project = HUEY**, **area = PS**, **subfolder alias = SCRIPTS**.
* The watcher parses that name, looks up a mapping in `file_router.config.json` (e.g., `HUEY → C:\Repos\HUEY_P`, `SCRIPTS → src\powershell`) and moves it there.
* It computes a **SHA256 hash (first 8 chars)** to detect duplicates:

  * If same content exists → file goes to a `Duplicates` folder (logged).
  * If different content exists → it adds `--dupN` suffix (configurable).
* Every action is written to an **append-only JSONL log** with timestamp, source, destination, and hash so you can audit everything later.

# Quick start (2 minutes)

1. Open `file_router.config.json` and set:

   * Your Downloads path, log/archive paths.
   * Each project root (`"HUEY": "C:\\Repos\\HUEY_P"`, etc.).
   * Subfolder **aliases** per project (`"SCRIPTS": "src\\powershell"`, `"DOC": "docs"`, etc.).
2. Run the watcher:
   `pwsh -File .\FileRouter_Watcher.ps1 -ConfigPath .\file_router.config.json`
3. Drop a properly named file into Downloads and watch it route automatically.

# Why this is deterministic and fast

* **Deterministic:** The route is computed from the filename + a versioned config map. Same name → same destination, every time.
* **Repeatable:** Re-running the watcher is safe; it will skip or dedupe when appropriate.
* **Auditable:** JSONL logs capture who/what/when/where (with content hash).
* **No AI required:** All logic is rule-based and Windows-friendly.

# Customizing the convention

Open the guide: it includes the exact **regex**, field definitions, examples, and why each piece (timestamp, version, ULID, sha8) helps with traceability and de-duplication. You can simplify (e.g., drop `AREA`) or extend (e.g., add ticket IDs).

END OF DOCUMENT 

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Modularity Gatekeeper (fast, local, low-token)

## 1) What runs, when

* **On file save** (editor task) and **on pre-commit** (Git hook):

  1. **Deterministic checks** (no AI): lint, AST rules, structure checks.
  2. **Deterministic auto-fixers** (no AI): safe rewrites (headers, comment-help, param attributes, standard logging scaffold, function splitting by thresholds).
  3. **Only if still failing** → **AI refactor pass** (patch mode, token-budgeted).

This guarantees “rework” happens immediately, and most passes cost **0 tokens**.

## 2) Gate design (PowerShell example, adapt for Python similarly)

**Pass/Fail rules (examples you can enforce locally):**

* File must be a **module unit** (one “thing”): `Public/Private` functions live in `Functions/` with predictable names.
* Each public function:

  * Has `[CmdletBinding()]`, `param()` with **typed** params and validation.
  * Has **Comment-Based Help** and examples.
  * Calls **Write-StructuredLog** (your logging shim) and uses **Try/Catch** with error records.
  * **No side effects** on import; idempotent behavior.
* **Function size**: hard cap (e.g., 60–80 LOC) => recommend split.
* **No mixed concerns**: data access, IO, and orchestration separated (detected via simple heuristics).
* **No global state**: disallow `$global:` and implicit module-scope mutations.
* **Return contracts**: objects, not strings; enforce via basic schema check (PSCustomObject keys).
* **Tests exist** for public functions (e.g., `tests/<FunctionName>.Tests.ps1`).

## 3) How to implement the “no-token” layer

* **PSScriptAnalyzer** with a custom ruleset for your standards.
* **AST rules** (PowerShell has `System.Management.Automation.Language.Parser.ParseInput()`):

  * Detect oversize functions, missing cbh, missing validation attributes, forbidden patterns.
* **Deterministic auto-fixers** (PowerShell scripts):

  * Inject/normalize **Comment-Based Help** header if missing.
  * Add `[CmdletBinding()]` and standard `param()` scaffolds.
  * Wrap bodies with `try { … } catch { … }` using your logging.
  * Split long functions by simple heuristics (e.g., extract inner blocks into `Private\_SplitX.ps1`).
  * Insert `Write-StructuredLog` calls at entry/exit.

> Result: 70–90% of violations are fixed **without AI**.

## 4) When to let AI touch it (and keep it cheap)

Trigger AI **only if**:

* Function still fails size/concern gates after one deterministic attempt.
* Naming/abstraction is genuinely ambiguous (needs semantic refactor).
* Tests can’t be auto-generated trivially.

**Cost controls:**

* **Patch-mode prompts**: feed *only* the function text + failing rules → ask for a minimal diff.
* **Hard limits**: N tokens/file; N files/commit; stop on first success.
* **Local/light models first** (Ollama/DeepSeek-Coder local) → fall back to cloud only on repeated failures.
* **Batch violations**: one AI pass addresses multiple flagged items within a single file.
* **Refusal policy**: if AI can’t pass gates in 1–2 tries, quarantine the change and open a ticket.

## 5) Simple, concrete wiring

### A) File-save (fast feedback)

* VS Code task or Watcher (`powershell`/`fswatch`/`watchdog`) runs:

  ```
  script-analyze.ps1 -> script-autofix.ps1 -> script-verify.ps1
  ```
* Shows a concise summary (✅/❌, rule IDs, quick links).

### B) Pre-commit (hard gate)

* `.git/hooks/pre-commit` (PowerShell on Windows):

  1. Collect changed `.ps1/.psm1`.
  2. Run analyzer + auto-fixers.
  3. If still failing → optional `ai_refactor.ps1` with budget.
  4. Re-run analyzer; if fail → **block commit** with actionable report and a one-liner to auto-split.

### C) Config you can drop in now

`modularity.rules.yaml` (drive behavior without editing scripts):

```yaml
function_max_loc: 80
require_cmdletbinding: true
require_comment_help: true
require_param_validation: true
forbid_globals: true
require_try_catch: true
require_structured_log: true
enforce_return_shape:
  enabled: true
  required_keys: [Status, Data, Message]
ai:
  enabled: true
  local_first: true
  max_tokens_per_file: 1200
  max_attempts: 1
  stop_after_first_pass: true
```

### D) Minimal pre-commit hook (Windows-friendly)

```powershell
# .git/hooks/pre-commit (make executable)
$files = git diff --cached --name-only | Where-Object { $_ -match '\.ps1$|\.psm1$' }
if (-not $files) { exit 0 }

$failed = $false
foreach ($f in $files) {
  pwsh -NoProfile -File .\.det-tools\script-analyze.ps1 -Path $f -Rules .\modularity.rules.yaml || {
    pwsh -NoProfile -File .\.det-tools\script-autofix.ps1 -Path $f -Rules .\modularity.rules.yaml
    git add $f
    pwsh -NoProfile -File .\.det-tools\script-verify.ps1 -Path $f -Rules .\modularity.rules.yaml || {
      pwsh -NoProfile -File .\.det-tools\ai_refactor.ps1 -Path $f -Rules .\modularity.rules.yaml -Budget "tokens=1200" || ($failed=$true)
      if (-not $failed) {
        git add $f
        pwsh -NoProfile -File .\.det-tools\script-verify.ps1 -Path $f -Rules .\modularity.rules.yaml || ($failed=$true)
      }
    }
  }
}
if ($failed) {
  Write-Host "❌ Modularity gates failed. See .det-logs/latest.jsonl" -ForegroundColor Red
  exit 1
}
Write-Host "✅ Modularity gates passed." -ForegroundColor Green
exit 0
```

### E) Deterministic logs (for auditability)

* Append **JSONL** records to `.det-logs/modularity.jsonl`:

  * `{ ts, file, rule_id, severity, outcome, autofix_applied, ai_used, tokens, duration_ms }`
* This lets you prove cost savings and spot repeated issues.

## 6) Efficiency & token math (why this makes sense)

* In practice, most violations are structural and **auto-fixable**. Your **AI spend becomes exceptional**, not routine.
* Early catch → small diffs → tiny prompts → **low tokens** when AI is needed.
* Hard gate + deterministic fixes ensure consistency, reduce review time, and prevent late-stage rewrites.

## 7) Where scripts beat AI (use these first)

* Scaffolding (module headers, help blocks, logging shims)
* Enforcing param attributes & validation
* Wrapping error handling
* Splitting by simple thresholds (size/regions)
* Normalizing naming and file paths
* Generating stub tests from templates

## 8) Where AI earns its keep

* Extracting coherent sub-functions with meaningful names when logic is tangled
* Untangling mixed concerns (IO + orchestration + domain) gracefully
* Harmonizing return contracts across call chains

---

## Bottom line

* **Yes, do it.** A post-generation **Modularity Gatekeeper** is the right place to enforce your framework.
* **Make AI the *fallback*, not the default.** Most passes cost **0 tokens**.
* **Wire it to save/commit** so rework is immediate and cheap.
* **Log everything** so you can prove determinism, quality, and cost control.


