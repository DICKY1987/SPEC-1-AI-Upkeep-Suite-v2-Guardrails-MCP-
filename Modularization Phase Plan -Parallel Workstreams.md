         1 +  # Modularization Phase Plan - Parallel Workstreams
         2 +
         3 +  ## Executive Summary
         4 +
         5 +  This document provides a phased approach to modularizing the AI Upkeep Suite v2 codebase using the **5-Category PowerShell
           + Framework**:
         6 +
         7 +  1. **Data Acquisition** - Read-only external interactions
         8 +  2. **Data Transformation** - Pure functions with no side effects
         9 +  3. **State Change** - CUD operations with idempotence
        10 +  4. **Configuration/Validation** - Policy enforcement without remediation
        11 +  5. **Orchestration** - Workflow coordination
        12 +
        13 +  **Timeline**: 6-8 weeks for core modularization
        14 +  **Parallel Streams**: 7 independent workstreams in Phase 1
        15 +  **Team Size**: Optimized for 4-8 developers (scalable to 11+)
        16 +
        17 +  ---
        18 +
        19 +  ## Phase 0: Foundation & Analysis (Week 1)
        20 +
        21 +  **Goal**: Establish the foundation for parallel modularization work
        22 +
        23 +  ### 0.1 Codebase Audit & Categorization
        24 +  **Owner**: Lead Architect
        25 +  **Duration**: 2-3 days
        26 +
        27 +  **Tasks**:
        28 +  - Inventory all existing `.ps1`, `.py`, and `.ts` files
        29 +  - Classify each script/function into one of the 5 categories
        30 +  - Document current dependencies and coupling points
        31 +  - Identify scripts that span multiple categories (candidates for refactoring)
        32 +
        33 +  **Deliverables**:
        34 +  - `docs/CODEBASE_INVENTORY.md` - Complete file categorization
        35 +  - `docs/DEPENDENCY_MAP.md` - Cross-component dependencies
        36 +  - `docs/REFACTORING_TARGETS.md` - Scripts needing decomposition
        37 +
        38 +  ### 0.2 Module Structure & Scaffolding
        39 +  **Owner**: DevOps Engineer
        40 +  **Duration**: 2 days
        41 +
        42 +  **Tasks**:
        43 +  - Create standardized module directory structure:
        44 +    ```
        45 +    /modules
        46 +      /<ModuleName>
        47 +        /Public          # Exported functions
        48 +        /Private         # Internal helpers
        49 +        /Tests           # Pester/pytest tests
        50 +        <ModuleName>.psd1  # Manifest
        51 +        <ModuleName>.psm1  # Root module
        52 +    ```
        53 +  - Generate module manifest templates (`.psd1`) for PowerShell modules
        54 +  - Create `pyproject.toml` templates for Python modules
        55 +  - Set up `tsconfig.json` for TypeScript modules
        56 +
        57 +  **Deliverables**:
        58 +  - `/modules` directory structure
        59 +  - Module template scaffolding scripts
        60 +  - `/templates/module-templates/` with boilerplate
        61 +
        62 +  ### 0.3 Shared Testing Infrastructure
        63 +  **Owner**: QA Lead
        64 +  **Duration**: 2 days
        65 +
        66 +  **Tasks**:
        67 +  - Configure shared Pester test framework with module discovery
        68 +  - Set up pytest configuration for Python modules
        69 +  - Create test fixtures and mocking utilities by category
        70 +  - Define code coverage thresholds (80% for Acquisition/Transformation, 95% for State Change)
        71 +
        72 +  **Deliverables**:
        73 +  - `/tests/shared/` - Shared test utilities
        74 +  - `Invoke-ModuleTests.ps1` - Unified test runner
        75 +  - Updated `.github/workflows/module-quality.yml`
        76 +
        77 +  ### 0.4 Module Publishing Pipeline
        78 +  **Owner**: DevOps Engineer
        79 +  **Duration**: 1-2 days
        80 +
        81 +  **Tasks**:
        82 +  - Set up private PowerShell repository (Azure Artifacts or GitHub Packages)
        83 +  - Configure semantic versioning automation
        84 +  - Create module publishing workflow
        85 +  - Set up dependency resolution for inter-module references
        86 +
        87 +  **Deliverables**:
        88 +  - `scripts/publishing/Publish-Module.ps1`
        89 +  - `.github/workflows/module-publish.yml`
        90 +  - Private repository configuration
        91 +
        92 +  **Phase 0 Parallel Work**: Tasks 0.1, 0.2, 0.3 can run concurrently. Task 0.4 depends on 0.2.
        93 +
        94 +  ---
        95 +
        96 +  ## Phase 1: Parallel Module Development (Weeks 2-4)
        97 +
        98 +  **Goal**: Convert existing scripts into categorized modules across 7 independent workstreams
        99 +
       100 +  ### Stream A: Data Acquisition Module (DataAcquisition.MCP)
       101 +  **Category**: Data Acquisition
       102 +  **Owner**: Developer 1
       103 +  **Duration**: 2 weeks
       104 +  **Dependencies**: None
       105 +
       106 +  **Scope**: Read-only functions for retrieving configuration and state
       107 +
       108 +  **Functions to Modularize**:
       109 +  1. `Get-McpConfiguration` - Retrieves current MCP config from `mcp.json`
       110 +  2. `Get-DesiredStateConfiguration` - Reads desired state from `mcp_servers.json`
       111 +  3. `Get-RunLedger` - Queries run ledger JSONL files
       112 +  4. `Get-McpServerHealth` - Checks MCP server availability
       113 +  5. `Get-GitRepositoryState` - Reads Git status, branch info, remotes
       114 +  6. `Get-DriftState` - Compares desired vs actual configuration
       115 +
       116 +  **Module Structure**:
       117 +  ```
       118 +  /modules/DataAcquisition.MCP
       119 +    /Public
       120 +      Get-McpConfiguration.ps1
       121 +      Get-DesiredStateConfiguration.ps1
       122 +      Get-RunLedger.ps1
       123 +      Get-McpServerHealth.ps1
       124 +    /Private
       125 +      Read-JsonConfiguration.ps1
       126 +      Parse-LedgerEntry.ps1
       127 +    /Tests
       128 +      Get-McpConfiguration.Tests.ps1
       129 +      Get-DesiredStateConfiguration.Tests.ps1
       130 +    DataAcquisition.MCP.psd1
       131 +    DataAcquisition.MCP.psm1
       132 +  ```
       133 +
       134 +  **Acceptance Criteria**:
       135 +  - All functions are pure (no side effects)
       136 +  - 100% read-only operations
       137 +  - Comprehensive error handling for missing files
       138 +  - Mock-based unit tests (no real file I/O in tests)
       139 +  - 80%+ code coverage
       140 +  - Passes PSScriptAnalyzer with strict settings
       141 +  - Semantic versioning (start at 0.1.0)
       142 +
       143 +  ---
       144 +
       145 +  ### Stream B: Data Transformation Module (DataTransformation.MCP)
       146 +  **Category**: Data Transformation
       147 +  **Owner**: Developer 2
       148 +  **Duration**: 2 weeks
       149 +  **Dependencies**: None
       150 +
       151 +  **Scope**: Pure functions for data manipulation with no side effects
       152 +
       153 +  **Functions to Modularize**:
       154 +  1. `New-McpConfigurationObject` - Merges desired and current configurations
       155 +  2. `ConvertTo-UnifiedDiff` - Parses and normalizes unified diff format
       156 +  3. `ConvertFrom-ChangePlan` - Deserializes and validates ChangePlan JSON
       157 +  4. `Merge-AccessGroups` - Combines access control group definitions
       158 +  5. `Format-LedgerEntry` - Structures ledger data for export
       159 +  6. `ConvertTo-SafePatchReport` - Transforms validation results into structured reports
       160 +
       161 +  **Module Structure**:
       162 +  ```
       163 +  /modules/DataTransformation.MCP
       164 +    /Public
       165 +      New-McpConfigurationObject.ps1
       166 +      ConvertTo-UnifiedDiff.ps1
       167 +      ConvertFrom-ChangePlan.ps1
       168 +      Format-LedgerEntry.ps1
       169 +    /Private
       170 +      Merge-Hashtable.ps1
       171 +      Validate-DiffSyntax.ps1
       172 +    /Tests
       173 +      New-McpConfigurationObject.Tests.ps1
       174 +      ConvertTo-UnifiedDiff.Tests.ps1
       175 +    DataTransformation.MCP.psd1
       176 +    DataTransformation.MCP.psm1
       177 +  ```
       178 +
       179 +  **Acceptance Criteria**:
       180 +  - All functions are pure (deterministic, no I/O)
       181 +  - Idempotent (same input always yields same output)
       182 +  - Comprehensive property-based testing (Pester with randomized inputs)
       183 +  - 85%+ code coverage
       184 +  - Input validation with `[ValidateScript()]` and `[ValidateSet()]`
       185 +  - Performance benchmarks for large datasets (10k+ entries)
       186 +
       187 +  ---
       188 +
       189 +  ### Stream C: State Change Module (StateChange.MCP)
       190 +  **Category**: State Change
       191 +  **Owner**: Developer 3
       192 +  **Duration**: 2.5 weeks
       193 +  **Dependencies**: Stream A (Data Acquisition)
       194 +
       195 +  **Scope**: CUD operations with idempotence and transaction safety
       196 +
       197 +  **Functions to Modularize**:
       198 +  1. `Set-McpConfiguration` - Writes merged configuration to `mcp.json`
       199 +  2. `New-RunLedgerEntry` - Appends signed JSONL entry to ledger
       200 +  3. `New-EphemeralWorkspace` - Creates temporary Git worktree
       201 +  4. `Remove-EphemeralWorkspace` - Cleans up temporary worktrees
       202 +  5. `Invoke-GitOperation` - Wrapper for Git commands with rollback
       203 +  6. `Set-FirewallRule` - Configures Windows Firewall for sandbox isolation
       204 +
       205 +  **Module Structure**:
       206 +  ```
       207 +  /modules/StateChange.MCP
       208 +    /Public
       209 +      Set-McpConfiguration.ps1
       210 +      New-RunLedgerEntry.ps1
       211 +      New-EphemeralWorkspace.ps1
       212 +      Remove-EphemeralWorkspace.ps1
       213 +      Invoke-GitOperation.ps1
       214 +    /Private
       215 +      Test-WritePermission.ps1
       216 +      Backup-Configuration.ps1
       217 +      Invoke-Rollback.ps1
       218 +    /Tests
       219 +      Set-McpConfiguration.Tests.ps1
       220 +      New-RunLedgerEntry.Tests.ps1
       221 +    StateChange.MCP.psd1
       222 +    StateChange.MCP.psm1
       223 +  ```
       224 +
       225 +  **Acceptance Criteria**:
       226 +  - All functions use `[CmdletBinding(SupportsShouldProcess=$true)]`
       227 +  - Idempotent operations (can run multiple times safely)
       228 +  - Atomic transactions with rollback on failure
       229 +  - Backup creation before destructive operations
       230 +  - 95%+ code coverage with idempotence tests
       231 +  - `-WhatIf` support for all functions
       232 +  - Integration tests using real (isolated) file system
       233 +
       234 +  ---
       235 +
       236 +  ### Stream D: Validation Module (Validation.MCP)
       237 +  **Category**: Configuration/Validation
       238 +  **Owner**: Developer 4
       239 +  **Duration**: 2.5 weeks
       240 +  **Dependencies**: Stream A, Stream B
       241 +
       242 +  **Scope**: Policy enforcement and validation without remediation
       243 +
       244 +  **Functions to Modularize**:
       245 +  1. `Test-McpEnvironment` - Validates MCP server health and accessibility
       246 +  2. `Test-ChangePlan` - Validates ChangePlan JSON against schema and OPA policies
       247 +  3. `Test-UnifiedDiff` - Validates diff format and applicability
       248 +  4. `Test-FormatCompliance` - Runs formatters in check mode (black, ruff, prettier)
       249 +  5. `Test-LintCompliance` - Runs linters and aggregates results
       250 +  6. `Test-TypeCompliance` - Runs type checkers (mypy, tsc)
       251 +  7. `Test-PolicyCompliance` - Runs OPA/Conftest against artifacts
       252 +
       253 +  **Module Structure**:
       254 +  ```
       255 +  /modules/Validation.MCP
       256 +    /Public
       257 +      Test-McpEnvironment.ps1
       258 +      Test-ChangePlan.ps1
       259 +      Test-UnifiedDiff.ps1
       260 +      Test-FormatCompliance.ps1
       261 +      Test-LintCompliance.ps1
       262 +      Test-PolicyCompliance.ps1
       263 +    /Private
       264 +      Invoke-SchemaValidation.ps1
       265 +      Invoke-OpaCheck.ps1
       266 +    /Tests
       267 +      Test-ChangePlan.Tests.ps1
       268 +      Test-UnifiedDiff.Tests.ps1
       269 +    Validation.MCP.psd1
       270 +    Validation.MCP.psm1
       271 +  ```
       272 +
       273 +  **Acceptance Criteria**:
       274 +  - All functions return structured validation results (pass/fail + details)
       275 +  - No remediation logic (detect only, no auto-fix)
       276 +  - Comprehensive schema validation using JSON Schema
       277 +  - OPA policy tests with example violations
       278 +  - 90%+ code coverage
       279 +  - Performance benchmarks (validation should complete in <10s per artifact)
       280 +
       281 +  ---
       282 +
       283 +  ### Stream E: MCP Server Modules (Python/TypeScript)
       284 +  **Category**: Mixed (Acquisition + State Change)
       285 +  **Owner**: Developer 5
       286 +  **Duration**: 3 weeks
       287 +  **Dependencies**: None (parallel with PowerShell streams)
       288 +
       289 +  **Scope**: Modularize MCP server implementations for Python and TypeScript tools
       290 +
       291 +  **Modules to Create**:
       292 +
       293 +  #### 1. `quality_mcp` (Python)
       294 +  **File**: `/mcp-servers/python/quality_mcp.py`
       295 +  **Tools Exposed**:
       296 +  - `ruff_check` - Run ruff linter
       297 +  - `ruff_format` - Run ruff formatter
       298 +  - `black_check` - Run black in check mode
       299 +  - `mypy_check` - Run mypy type checker
       300 +  - `pytest_run` - Execute pytest with coverage
       301 +
       302 +  **Module Structure**:
       303 +  ```python
       304 +  /mcp-servers/python/quality_mcp
       305 +    /quality_mcp
       306 +      __init__.py
       307 +      server.py          # MCP server entry point
       308 +      tools.py           # Tool definitions
       309 +      runners.py         # Tool execution logic
       310 +    /tests
       311 +      test_tools.py
       312 +      test_runners.py
       313 +    pyproject.toml
       314 +    README.md
       315 +  ```
       316 +
       317 +  #### 2. `semgrep_mcp` (Python)
       318 +  **File**: `/mcp-servers/sast/semgrep_mcp.py`
       319 +  **Tools Exposed**:
       320 +  - `semgrep_scan` - Run Semgrep SAST
       321 +  - `semgrep_baseline` - Generate baseline for ignored findings
       322 +
       323 +  #### 3. `policy_mcp` (Python)
       324 +  **File**: `/mcp-servers/policy/policy_mcp.py`
       325 +  **Tools Exposed**:
       326 +  - `conftest_validate` - Run Conftest policy checks
       327 +  - `opa_eval` - Execute OPA policy evaluation
       328 +
       329 +  **Acceptance Criteria**:
       330 +  - Type hints for all functions (mypy strict mode)
       331 +  - Async support for long-running operations
       332 +  - Structured logging with correlation IDs
       333 +  - 85%+ test coverage with pytest
       334 +  - Error handling with retries for transient failures
       335 +  - Published to private PyPI repository
       336 +
       337 +  ---
       338 +
       339 +  ### Stream F: Validation Pipeline Module (Orchestration.SafePatch)
       340 +  **Category**: Orchestration
       341 +  **Owner**: Developer 6
       342 +  **Duration**: 2.5 weeks
       343 +  **Dependencies**: Streams A, B, C, D
       344 +
       345 +  **Scope**: Orchestrate the SafePatch validation pipeline
       346 +
       347 +  **Functions to Modularize**:
       348 +  1. `Invoke-SafePatchValidation` - Orchestrates full pipeline (format → lint → test → SAST → policy)
       349 +  2. `Invoke-FormatCheck` - Step 1: Format validation
       350 +  3. `Invoke-LintCheck` - Step 2: Linting
       351 +  4. `Invoke-TypeCheck` - Step 3: Type checking
       352 +  5. `Invoke-UnitTests` - Step 4: Test execution in sandbox
       353 +  6. `Invoke-SastScan` - Step 5: SAST scanning
       354 +  7. `Invoke-SecretScan` - Step 6: Secret scanning
       355 +  8. `Invoke-PolicyCheck` - Step 7: Policy validation
       356 +
       357 +  **Module Structure**:
       358 +  ```
       359 +  /modules/Orchestration.SafePatch
       360 +    /Public
       361 +      Invoke-SafePatchValidation.ps1
       362 +      Invoke-FormatCheck.ps1
       363 +      Invoke-LintCheck.ps1
       364 +      Invoke-UnitTests.ps1
       365 +      Invoke-SastScan.ps1
       366 +    /Private
       367 +      New-ValidationContext.ps1
       368 +      Write-PipelineLog.ps1
       369 +      ConvertTo-PipelineReport.ps1
       370 +    /Tests
       371 +      Invoke-SafePatchValidation.Tests.ps1
       372 +    Orchestration.SafePatch.psd1
       373 +    Orchestration.SafePatch.psm1
       374 +  ```
       375 +
       376 +  **Acceptance Criteria**:
       377 +  - Orchestration logic is thin (delegates to category-specific modules)
       378 +  - Pipeline steps are configurable (can skip/enable individual validators)
       379 +  - Fail-fast mode for CI optimization
       380 +  - Structured logging at each pipeline stage
       381 +  - Rollback on validation failure
       382 +  - 85%+ code coverage with integration tests
       383 +  - Performance optimization (parallel validation where possible)
       384 +
       385 +  ---
       386 +
       387 +  ### Stream G: MCP Configuration Module (Orchestration.MCP)
       388 +  **Category**: Orchestration
       389 +  **Owner**: Developer 7
       390 +  **Duration**: 2 weeks
       391 +  **Dependencies**: Streams A, B, C, D
       392 +
       393 +  **Scope**: Orchestrate MCP environment initialization and drift detection
       394 +
       395 +  **Functions to Modularize**:
       396 +  1. `Initialize-McpEnvironment` - Orchestrates MCP setup (reads desired state → validates → applies configuration)
       397 +  2. `Export-WeeklyReport` - Generates quality metrics reports from ledger
       398 +  3. `Invoke-DriftDetection` - Detects configuration drift in repo protections and guardrails
       399 +
       400 +  **Module Structure**:
       401 +  ```
       402 +  /modules/Orchestration.MCP
       403 +    /Public
       404 +      Initialize-McpEnvironment.ps1
       405 +      Export-WeeklyReport.ps1
       406 +      Invoke-DriftDetection.ps1
       407 +    /Private
       408 +      Write-OrchestrationLog.ps1
       409 +    /Tests
       410 +      Initialize-McpEnvironment.Tests.ps1
       411 +    Orchestration.MCP.psd1
       412 +    Orchestration.MCP.psm1
       413 +  ```
       414 +
       415 +  **Acceptance Criteria**:
       416 +  - Thin orchestration layer (delegates to DataAcquisition, StateChange, Validation modules)
       417 +  - Idempotent initialization
       418 +  - Comprehensive error handling with rollback
       419 +  - Integration tests with mocked dependencies
       420 +  - 80%+ code coverage
       421 +
       422 +  ---
       423 +
       424 +  ## Phase 1 Dependency Matrix
       425 +
       426 +  ```
       427 +  Stream A (DataAcquisition.MCP)    ──┐
       428 +                                       ├──> Stream C (StateChange.MCP)
       429 +  Stream B (DataTransformation.MCP) ──┘                │
       430 +                                                        │
       431 +                                       ┌────────────────┴────────────┐
       432 +                                       │                             │
       433 +                                       ↓                             ↓
       434 +  Stream A + Stream B ────────────> Stream D (Validation.MCP) ──> Stream F (Orchestration.SafePatch)
       435 +                                                                     ↓
       436 +  Stream A + B + C + D ──────────────────────────────────────────> Stream G (Orchestration.MCP)
       437 +
       438 +  Stream E (MCP Server Modules - Python/TS) ──> Independent (can run fully parallel)
       439 +  ```
       440 +
       441 +  **Critical Path**: A/B → D → F → G (5 weeks)
       442 +  **Parallel Opportunities**: Streams A, B, E run concurrently in Week 2-3
       443 +
       444 +  ---
       445 +
       446 +  ## Phase 2: Integration & Wiring (Week 5)
       447 +
       448 +  **Goal**: Wire modules together and update existing scripts to use modular functions
       449 +
       450 +  ### 2.1 Module Import & Dependency Resolution
       451 +  **Owner**: Lead Architect
       452 +  **Duration**: 2 days
       453 +
       454 +  **Tasks**:
       455 +  - Update module manifests with `RequiredModules` dependencies
       456 +  - Configure module auto-loading in PowerShell profile
       457 +  - Set up Python package dependencies in `pyproject.toml`
       458 +  - Validate module resolution and import order
       459 +
       460 +  **Deliverables**:
       461 +  - Updated `.psd1` manifests with dependency chains
       462 +  - `/scripts/Initialize-ModuleEnvironment.ps1` for developer setup
       463 +
       464 +  ### 2.2 Script Migration
       465 +  **Owner**: All Developers (parallel)
       466 +  **Duration**: 3 days
       467 +
       468 +  **Tasks**:
       469 +  - Replace inline logic in existing scripts with module function calls
       470 +  - Update `.mcp/Initialize-McpEnvironment.ps1` to use `Orchestration.MCP` module
       471 +  - Update validation scripts to use `Validation.MCP` and `Orchestration.SafePatch` modules
       472 +  - Refactor MCP server entry points to use modular Python packages
       473 +
       474 +  **Example Migration**:
       475 +  ```powershell
       476 +  # Before (monolithic script)
       477 +  $currentConfig = Get-Content mcp.json | ConvertFrom-Json
       478 +  $desiredConfig = Get-Content .mcp/mcp_servers.json | ConvertFrom-Json
       479 +  $merged = @{}
       480 +  foreach ($key in $desiredConfig.PSObject.Properties.Name) {
       481 +      $merged[$key] = $desiredConfig.$key
       482 +  }
       483 +  $merged | ConvertTo-Json | Set-Content mcp.json
       484 +
       485 +  # After (using modules)
       486 +  Import-Module DataAcquisition.MCP
       487 +  Import-Module DataTransformation.MCP
       488 +  Import-Module StateChange.MCP
       489 +
       490 +  $currentConfig = Get-McpConfiguration
       491 +  $desiredConfig = Get-DesiredStateConfiguration
       492 +  $merged = New-McpConfigurationObject -Current $currentConfig -Desired $desiredConfig
       493 +  Set-McpConfiguration -Configuration $merged
       494 +  ```
       495 +
       496 +  **Deliverables**:
       497 +  - All scripts in `/scripts` updated to use modules
       498 +  - Zero inline logic duplication
       499 +
       500 +  ### 2.3 Integration Testing
       501 +  **Owner**: QA Lead
       502 +  **Duration**: 2 days
       503 +
       504 +  **Tasks**:
       505 +  - Run full SafePatch validation pipeline with modular components
       506 +  - Test MCP environment initialization end-to-end
       507 +  - Validate drift detection workflow
       508 +  - Test module publishing and versioning
       509 +
       510 +  **Deliverables**:
       511 +  - `/tests/integration/Test-ModularPipeline.ps1` - Full pipeline test
       512 +  - `/tests/integration/Test-McpInitialization.ps1` - MCP setup test
       513 +  - Integration test results report
       514 +
       515 +  ---
       516 +
       517 +  ## Phase 3: CI/CD & Quality Gates (Week 6)
       518 +
       519 +  **Goal**: Update CI/CD pipelines to use modular architecture
       520 +
       521 +  ### 3.1 GitHub Actions Workflow Updates
       522 +  **Owner**: DevOps Engineer
       523 +  **Duration**: 2 days
       524 +
       525 +  **Tasks**:
       526 +  - Update `.github/workflows/quality.yml` to use `Orchestration.SafePatch` module
       527 +  - Add module installation steps to workflows
       528 +  - Configure module caching for faster builds
       529 +  - Update branch protection rules
       530 +
       531 +  **Deliverables**:
       532 +  - Updated workflow files
       533 +  - Module caching configuration
       534 +  - CI performance benchmarks
       535 +
       536 +  ### 3.2 Pre-commit Hook Updates
       537 +  **Owner**: Developer 1
       538 +  **Duration**: 1 day
       539 +
       540 +  **Tasks**:
       541 +  - Update `.pre-commit-config.yaml` to use modular validation scripts
       542 +  - Update `scripts/hooks/pre-commit.ps1` to import modules
       543 +  - Test pre-commit hooks on developer machines
       544 +
       545 +  **Deliverables**:
       546 +  - Updated pre-commit configuration
       547 +  - `/scripts/hooks/install-hooks.ps1` updated for module dependencies
       548 +
       549 +  ### 3.3 Comprehensive Testing
       550 +  **Owner**: All Developers
       551 +  **Duration**: 2 days
       552 +
       553 +  **Tasks**:
       554 +  - Run full test suite (unit + integration)
       555 +  - Execute SafePatch validation on real code changes
       556 +  - Test MCP server health checks
       557 +  - Validate drift detection
       558 +  - Performance benchmarking
       559 +
       560 +  **Deliverables**:
       561 +  - Test results report
       562 +  - Performance comparison (modular vs. monolithic)
       563 +  - Coverage reports (should meet 85%+ average)
       564 +
       565 +  ---
       566 +
       567 +  ## Phase 4: Documentation & Knowledge Transfer (Week 7)
       568 +
       569 +  **Goal**: Document the modular architecture and train the team
       570 +
       571 +  ### 4.1 Module Documentation
       572 +  **Owner**: Technical Writer + Developers
       573 +  **Duration**: 3 days
       574 +
       575 +  **Tasks**:
       576 +  - Generate module reference documentation (Get-Help comment-based help)
       577 +  - Create `/docs/MODULAR_ARCHITECTURE.md` explaining the 5-category design
       578 +  - Document module versioning and publishing process
       579 +  - Create troubleshooting guides for common module issues
       580 +
       581 +  **Deliverables**:
       582 +  - Comment-based help for all exported functions
       583 +  - `/docs/MODULAR_ARCHITECTURE.md`
       584 +  - `/docs/MODULE_PUBLISHING.md`
       585 +  - `/docs/MODULE_TROUBLESHOOTING.md`
       586 +
       587 +  ### 4.2 Developer Training
       588 +  **Owner**: Lead Architect
       589 +  **Duration**: 2 days
       590 +
       591 +  **Tasks**:
       592 +  - Conduct training sessions on the 5-category framework
       593 +  - Demonstrate module development workflow
       594 +  - Review best practices for each category
       595 +  - Q&A sessions
       596 +
       597 +  **Deliverables**:
       598 +  - Training materials
       599 +  - Developer quick reference guides
       600 +  - Recorded training sessions
       601 +
       602 +  ### 4.3 Migration Retrospective
       603 +  **Owner**: All Team Members
       604 +  **Duration**: 1 day
       605 +
       606 +  **Tasks**:
       607 +  - Conduct retrospective on modularization process
       608 +  - Document lessons learned
       609 +  - Identify technical debt for future sprints
       610 +  - Update project roadmap
       611 +
       612 +  **Deliverables**:
       613 +  - Retrospective notes
       614 +  - `/docs/LESSONS_LEARNED.md`
       615 +  - Updated roadmap
       616 +
       617 +  ---
       618 +
       619 +  ## Resource Allocation & Scaling
       620 +
       621 +  ### 4-Developer Team
       622 +  - **Developer 1**: Stream A + C (Data Acquisition + State Change)
       623 +  - **Developer 2**: Stream B + D (Data Transformation + Validation)
       624 +  - **Developer 3**: Stream E (MCP Server Modules - Python/TypeScript)
       625 +  - **Developer 4**: Stream F + G (Orchestration modules)
       626 +
       627 +  **Timeline**: 6 weeks (some sequential dependencies extend timeline)
       628 +
       629 +  ### 8-Developer Team (Recommended)
       630 +  - **Developer 1**: Stream A (Data Acquisition)
       631 +  - **Developer 2**: Stream B (Data Transformation)
       632 +  - **Developer 3**: Stream C (State Change)
       633 +  - **Developer 4**: Stream D (Validation)
       634 +  - **Developer 5**: Stream E (MCP Server Modules)
       635 +  - **Developer 6**: Stream F (Orchestration.SafePatch)
       636 +  - **Developer 7**: Stream G (Orchestration.MCP)
       637 +  - **Developer 8**: Testing + Integration (Phases 2-3)
       638 +
       639 +  **Timeline**: 5 weeks (optimal parallelization)
       640 +
       641 +  ### 11+ Developer Team
       642 +  - Same as 8-developer team, plus:
       643 +  - **Developer 9-10**: Documentation (Phase 4 runs parallel with Phases 2-3)
       644 +  - **Developer 11**: DevOps (CI/CD updates run parallel with Phase 1)
       645 +
       646 +  **Timeline**: 4 weeks (maximum parallelization)
       647 +
       648 +  ---
       649 +
       650 +  ## Success Metrics
       651 +
       652 +  ### Code Quality Metrics
       653 +  - **Test Coverage**: 85%+ average across all modules
       654 +    - Data Acquisition: 80%+
       655 +    - Data Transformation: 85%+
       656 +    - State Change: 95%+
       657 +    - Validation: 90%+
       658 +    - Orchestration: 80%+
       659 +  - **PSScriptAnalyzer**: Zero errors, zero warnings
       660 +  - **Type Safety**: 100% type hints in Python, strict mode in TypeScript
       661 +  - **Linting**: Zero violations
       662 +
       663 +  ### Performance Metrics
       664 +  - **SafePatch Pipeline**: <2 minutes for typical change (20% improvement over monolithic)
       665 +  - **Module Load Time**: <500ms per module
       666 +  - **CI Build Time**: <5 minutes total (with caching)
       667 +
       668 +  ### Maintainability Metrics
       669 +  - **Cyclomatic Complexity**: <10 per function (average <5)
       670 +  - **Function Length**: <50 lines (average <30)
       671 +  - **Module Coupling**: Low (modules can be tested independently)
       672 +  - **Code Duplication**: <3% (measured with Semgrep)
       673 +
       674 +  ### Process Metrics
       675 +  - **Deployment Frequency**: Modules can be versioned/released independently
       676 +  - **Lead Time**: Reduced by 30% (smaller, focused changes)
       677 +  - **Change Failure Rate**: <5% (high test coverage prevents regressions)
       678 +  - **MTTR**: <1 hour (modular isolation simplifies debugging)
       679 +
       680 +  ---
       681 +
       682 +  ## Risk Mitigation
       683 +
       684 +  ### Risk 1: Module Dependency Hell
       685 +  **Probability**: Medium
       686 +  **Impact**: High
       687 +  **Mitigation**:
       688 +  - Enforce semantic versioning strictly
       689 +  - Use dependency range constraints (e.g., `RequiredModules = @{ModuleName='DataAcquisition.MCP'; ModuleVersion='0.1.0'}`)
       690 +  - Automated dependency graph validation in CI
       691 +  - Lock files for Python dependencies
       692 +
       693 +  ### Risk 2: Breaking Changes During Migration
       694 +  **Probability**: High
       695 +  **Impact**: Medium
       696 +  **Mitigation**:
       697 +  - Run parallel validation (old monolithic + new modular) during Phase 2
       698 +  - Feature flags to toggle between implementations
       699 +  - Comprehensive integration tests before cutover
       700 +  - Rollback plan documented
       701 +
       702 +  ### Risk 3: Performance Regression
       703 +  **Probability**: Low
       704 +  **Impact**: Medium
       705 +  **Mitigation**:
       706 +  - Benchmark before/after modularization
       707 +  - Profile module load times
       708 +  - Optimize hot paths (e.g., ledger parsing for large files)
       709 +  - Lazy loading for non-critical modules
       710 +
       711 +  ### Risk 4: Knowledge Silos
       712 +  **Probability**: Medium
       713 +  **Impact**: Medium
       714 +  **Mitigation**:
       715 +  - Cross-training during Phase 1 (developers review each other's modules)
       716 +  - Comprehensive documentation (Phase 4)
       717 +  - Recorded training sessions
       718 +  - Pair programming on complex modules
       719 +
       720 +  ---
       721 +
       722 +  ## Post-Modularization Roadmap
       723 +
       724 +  ### Short-term (Weeks 8-12)
       725 +  1. **Module Versioning & Releases**
       726 +     - Establish release cadence (e.g., bi-weekly)
       727 +     - Automate changelog generation
       728 +     - Publish modules to private repository
       729 +
       730 +  2. **Template Enhancements**
       731 +     - Update `/templates` with modular examples
       732 +     - Create Plaster templates for new modules
       733 +     - AI agent prompt libraries for each category
       734 +
       735 +  3. **Advanced Testing**
       736 +     - Property-based testing for Data Transformation
       737 +     - Chaos engineering for State Change (simulate failures)
       738 +     - Contract testing between modules
       739 +
       740 +  ### Medium-term (Months 4-6)
       741 +  1. **Cross-Language Modules**
       742 +     - Create Python equivalents for PowerShell modules (for Linux CI agents)
       743 +     - TypeScript modules for browser-based tools
       744 +     - Shared schema validation library
       745 +
       746 +  2. **Observability Enhancements**
       747 +     - Structured logging with correlation IDs across modules
       748 +     - Performance monitoring for pipeline stages
       749 +     - Distributed tracing for orchestration flows
       750 +
       751 +  3. **Policy Expansion**
       752 +     - Additional OPA policies for module compliance
       753 +     - Automated policy testing framework
       754 +     - Policy-as-code versioning
       755 +
       756 +  ### Long-term (Months 7-12)
       757 +  1. **Ecosystem Growth**
       758 +     - Community contributions (if open-sourced)
       759 +     - Plugin architecture for custom validators
       760 +     - Marketplace for third-party MCP servers
       761 +
       762 +  2. **AI Agent Optimization**
       763 +     - Fine-tuned prompts per module category
       764 +     - Automated code generation using templates
       765 +     - Self-healing pipelines (auto-remediation for common failures)
       766 +
       767 +  ---
       768 +
       769 +  ## Appendix A: Module Naming Conventions
       770 +
       771 +  ### PowerShell Modules
       772 +  - **Format**: `<Category>.<Subsystem>`
       773 +  - **Examples**:
       774 +    - `DataAcquisition.MCP`
       775 +    - `StateChange.MCP`
       776 +    - `Orchestration.SafePatch`
       777 +
       778 +  ### Python Packages
       779 +  - **Format**: `<subsystem>_<category>_mcp`
       780 +  - **Examples**:
       781 +    - `quality_mcp` (MCP server for Python quality tools)
       782 +    - `semgrep_mcp` (MCP server for Semgrep)
       783 +
       784 +  ### Function Naming
       785 +  - **PowerShell**: Verb-Noun (e.g., `Get-McpConfiguration`, `Set-McpConfiguration`)
       786 +  - **Python**: snake_case (e.g., `get_mcp_configuration`, `set_mcp_configuration`)
       787 +
       788 +  ---
       789 +
       790 +  ## Appendix B: Module Version Matrix
       791 +
       792 +  | Module | Initial Version | Stability | Dependencies |
       793 +  |--------|----------------|-----------|--------------|
       794 +  | DataAcquisition.MCP | 0.1.0 | Alpha | None |
       795 +  | DataTransformation.MCP | 0.1.0 | Alpha | None |
       796 +  | StateChange.MCP | 0.1.0 | Alpha | DataAcquisition.MCP |
       797 +  | Validation.MCP | 0.1.0 | Alpha | DataAcquisition.MCP, DataTransformation.MCP |
       798 +  | Orchestration.SafePatch | 0.1.0 | Alpha | All above |
       799 +  | Orchestration.MCP | 0.1.0 | Alpha | All above |
       800 +  | quality_mcp (Python) | 0.1.0 | Alpha | None (external: ruff, black, mypy, pytest) |
       801 +
       802 +  **Versioning Strategy**:
       803 +  - **0.x.x**: Alpha/Beta (breaking changes allowed)
       804 +  - **1.x.x**: Stable (semver guarantees, deprecation warnings for breaking changes)
       805 +
       806 +  ---
       807 +
       808 +  ## Appendix C: Testing Checklist by Category
       809 +
       810 +  ### Data Acquisition
       811 +  - [ ] Mock all external file reads
       812 +  - [ ] Test error handling for missing files
       813 +  - [ ] Test error handling for malformed JSON/data
       814 +  - [ ] Verify read-only behavior (no writes)
       815 +  - [ ] Test with empty datasets
       816 +  - [ ] Test with large datasets (performance)
       817 +
       818 +  ### Data Transformation
       819 +  - [ ] Property-based testing (randomized inputs)
       820 +  - [ ] Idempotence tests (f(f(x)) == f(x))
       821 +  - [ ] Determinism tests (same input → same output)
       822 +  - [ ] Edge case testing (nulls, empty arrays, deeply nested objects)
       823 +  - [ ] Performance benchmarks
       824 +
       825 +  ### State Change
       826 +  - [ ] Idempotence tests (run twice, same result)
       827 +  - [ ] `-WhatIf` support verification
       828 +  - [ ] Rollback tests (simulate failure mid-operation)
       829 +  - [ ] Permission tests (read-only filesystem)
       830 +  - [ ] Concurrent modification tests
       831 +  - [ ] Integration tests with real filesystem (isolated)
       832 +
       833 +  ### Validation
       834 +  - [ ] True positive tests (detect actual violations)
       835 +  - [ ] True negative tests (pass valid inputs)
       836 +  - [ ] False positive prevention (edge cases that look invalid but aren't)
       837 +  - [ ] Schema validation tests
       838 +  - [ ] OPA policy tests with example violations
       839 +  - [ ] Performance tests (validate large codebases)
       840 +
       841 +  ### Orchestration
       842 +  - [ ] Integration tests with mocked dependencies
       843 +  - [ ] Error propagation tests (downstream failures handled correctly)
       844 +  - [ ] Rollback orchestration tests
       845 +  - [ ] Configuration override tests
       846 +  - [ ] Logging and observability tests
       847 +
       848 +  ---
       849 +
       850 +  ## Conclusion
       851 +
       852 +  This phased modularization plan transforms the AI Upkeep Suite v2 from a monolithic script collection into a **professionally
           + modular, testable, and maintainable codebase** aligned with the **5-Category PowerShell Framework**.
       853 +
       854 +  **Key Benefits**:
       855 +  1. **Parallel Development**: 7 independent streams enable team scaling
       856 +  2. **Testability**: Category-specific testing strategies ensure 85%+ coverage
       857 +  3. **Maintainability**: Separation of concerns reduces coupling
       858 +  4. **Reusability**: Modules can be composed for new workflows
       859 +  5. **AI-Friendly**: Structured modules align with AI agent tool design
       860 +
       861 +  **Next Steps**:
       862 +  1. Review and approve this plan with stakeholders
       863 +  2. Assign developers to streams (Phase 1)
       864 +  3. Kick off Phase 0 (Week 1)
       865 +  4. Begin parallel development (Week 2)
       866 +
       867 +  For questions or clarifications, refer to `/docs/MODULAR_ARCHITECTURE.md` (to be created in Phase 4).