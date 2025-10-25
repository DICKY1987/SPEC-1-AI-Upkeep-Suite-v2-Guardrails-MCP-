# # Development Order - Parallel Streams Strategy

## Phase 0: Foundation (Sequential - Must Complete First)

**Duration Estimate: 2-3 days**

These files establish the project structure and core schemas that other streams depend on.

### Core Repository Structure
1. `.gitignore`
2. `.editorconfig`
3. `README.md` (basic structure only)
4. `LICENSE`
5. `/docs/` directory structure
6. `/tests/` directory structure
7. `/scripts/` directory structure
8. `/tools/` directory structure
9. `/.mcp/` directory structure
10. `/policy/` directory structure

### Schema Definitions (Critical for all streams)
11. `/policy/schemas/changeplan.schema.json`
12. `/policy/schemas/unifieddiff.schema.json`
13. `/schemas/ledger.schema.json`
14. `/database/schema.sql`

### Basic Documentation
15. `/docs/conventions.md` (code standards)
16. `CONTRIBUTING.md` (development workflow)

---

## Phase 1: Parallel Development Streams

**Duration Estimate: 1-2 weeks per stream**

These streams can be developed simultaneously by different teams/developers.

### 🟦 Stream A: MCP Configuration System
**Owner: Team A / Developer 1**

**Dependencies:** Phase 0 complete

**Files (in order):**
1. `/.mcp/mcp_servers.json` (example config)
2. `/.mcp/access_groups.json`
3. `/.mcp/Get-McpConfiguration.ps1`
4. `/.mcp/Get-DesiredStateConfiguration.ps1`
5. `/.mcp/New-McpConfigurationObject.ps1`
6. `/.mcp/Set-McpConfiguration.ps1`
7. `/.mcp/Test-McpEnvironment.ps1`
8. `/.mcp/Initialize-McpEnvironment.ps1` (orchestrator)

**Deliverable:** Functional MCP configuration management system

---

### 🟩 Stream B: Guardrail & Policy System
**Owner: Team B / Developer 2**

**Dependencies:** Phase 0 complete

**Files (in order):**
1. `/policy/opa/changeplan.rego`
2. `/policy/opa/forbidden_apis.rego`
3. `/policy/opa/delivery_bundle.rego`
4. `/.semgrep/semgrep.yml` (base config)
5. `/.semgrep/semgrep-powershell.yml`
6. `/.semgrep/semgrep-python.yml`
7. `/.semgrep/semgrep-secrets.yml`
8. `/scripts/validation/Test-ChangePlan.ps1`
9. `/scripts/validation/Test-UnifiedDiff.ps1`
10. `/scripts/validation/Invoke-PolicyCheck.ps1`

**Deliverable:** Policy enforcement system with OPA and Semgrep rules

---

### 🟨 Stream C: Code Quality Tools Configuration
**Owner: Team C / Developer 3**

**Dependencies:** Phase 0 complete

**Files (in order):**

**PowerShell:**
1. `/tools/PSScriptAnalyzerSettings.psd1`
2. `/tools/Verify.ps1`

**Python:**
3. `/tools/ruff.toml`
4. `/tools/mypy.ini`
5. `/tools/pytest.ini`

**TypeScript:**
6. `/tools/.eslintrc.json`
7. `/tools/tsconfig.json`

**Validation Scripts:**
8. `/scripts/validation/Invoke-FormatCheck.ps1`
9. `/scripts/validation/Invoke-LintCheck.ps1`
10. `/scripts/validation/Invoke-TypeCheck.ps1`
11. `/scripts/validation/Invoke-UnitTests.ps1`
12. `/scripts/validation/Invoke-SastScan.ps1`
13. `/scripts/validation/Invoke-SecretScan.ps1`

**Deliverable:** Complete toolchain for format/lint/type/test validation

---

### 🟧 Stream D: Templates & Code Skeletons
**Owner: Team D / Developer 4**

**Dependencies:** Phase 0 complete (conventions.md specifically)

**Files (in order):**

**PowerShell:**
1. `/templates/powershell/AdvancedFunction.ps1`
2. `/templates/powershell/Module.psm1`
3. `/templates/powershell/Module.psd1`
4. `/templates/powershell/Pester.Tests.ps1`

**Python:**
5. `/templates/python/python_cli.py`
6. `/templates/python/test_template.py`
7. `/templates/python/pyproject.toml`

**TypeScript:**
8. `/templates/typescript/typescript_module.ts`

**Deliverable:** Reusable templates for all supported languages

---

### 🟪 Stream E: Sandbox System
**Owner: Team E / Developer 5**

**Dependencies:** Phase 0 complete

**Files (in order):**
1. `/scripts/sandbox/sandbox_linux.sh`
2. `/scripts/sandbox/sandbox_windows.ps1`
3. `/scripts/sandbox/New-EphemeralWorkspace.ps1`
4. `/scripts/sandbox/Remove-EphemeralWorkspace.ps1`

**Deliverable:** Network-isolated sandbox environments

---

### 🟥 Stream F: File Routing System (Completely Independent)
**Owner: Team F / Developer 6**

**Dependencies:** None - can start immediately

**Files (in order):**
1. `/file-routing/Naming_Convention_Guide.md`
2. `/file-routing/file_router.config.json`
3. `/file-routing/FileRouter_Watcher.ps1`

**Deliverable:** Automated file routing from Downloads

---

### 🟫 Stream G: Edit Engine (Completely Independent)
**Owner: Team G / Developer 7**

**Dependencies:** None - can start immediately

**Files (in order):**
1. `/tools/edit-engine/apply_patch.ps1`
2. `/tools/edit-engine/apply_jsonpatch.ps1`
3. `/tools/edit-engine/run_comby.ps1`
4. `/tools/edit-engine/run_ast_mod.ps1`
5. `/tools/edit-engine/regenerate.ps1`

**Deliverable:** Deterministic code modification toolkit

---

### ⬜ Stream H: Audit & Observability
**Owner: Team H / Developer 8**

**Dependencies:** Phase 0 (schema.sql, ledger.schema.json)

**Files (in order):**
1. `/database/seed_data.sql`
2. `/scripts/audit/New-RunLedgerEntry.ps1`
3. `/scripts/audit/Get-RunLedger.ps1`
4. `/scripts/audit/Export-WeeklyReport.ps1`
5. `/scripts/audit/Invoke-DriftDetection.ps1`

**Deliverable:** Logging and reporting infrastructure

---

## Phase 2: Integration & Orchestration

**Duration Estimate: 1 week**

**Dependencies:** Streams A, B, C, D, E must be complete

These components integrate the parallel streams.

### Integration Point 1: SafePatch Pipeline
**Owner: Integration Team or Developer 9**

**Files (in order):**
1. `/scripts/validation/Invoke-SafePatchValidation.ps1` (orchestrates all validation steps)

### Integration Point 2: MCP Server Implementations
**Owner: Team A (MCP experts) + Team C (tool experts)**

**Files (in order):**
1. `/mcp-servers/powershell/ps_quality_mcp.ps1`
2. `/mcp-servers/python/quality_mcp.py`
3. `/mcp-servers/sast/semgrep_mcp.py`
4. `/mcp-servers/secrets/secrets_mcp.py`
5. `/mcp-servers/policy/policy_mcp.py`

### Integration Point 3: Pre-commit Hooks
**Owner: Team C (quality tools) + Team B (policy)**

**Files (in order):**
1. `/.pre-commit-config.yaml`
2. `/scripts/hooks/install-hooks.ps1`
3. `/scripts/hooks/pre-commit.ps1`

---

## Phase 3: CI/CD & Testing

**Duration Estimate: 1 week**

**Dependencies:** Phase 2 complete

### CI/CD Workflows
**Owner: DevOps Team or Developer 10**

**Files (in order):**
1. `/.github/workflows/powershell-verify.yml`
2. `/.github/workflows/python-verify.yml`
3. `/.github/workflows/typescript-verify.yml`
4. `/.github/workflows/sast-secrets.yml`
5. `/.github/workflows/policy-check.yml`
6. `/.github/workflows/quality.yml` (main orchestrator)
7. `/.github/workflows/drift-detection.yml`
8. `/.github/renovate.json`

### Testing Infrastructure
**Owner: QA Team or Developer 11**

**Files (in order):**
1. `/tests/fixtures/` (sample files for testing)
2. `/tests/unit/` (unit tests for individual components)
3. `/tests/integration/` (integration tests)
4. `/tests/Invoke-IntegrationTests.ps1`

---

## Phase 4: Documentation & Refinement

**Duration Estimate: 3-5 days**

**Dependencies:** Phases 1-3 complete

**Can be done in parallel by documentation team**

### Documentation Files
**Owner: Documentation Team**

**Files (any order):**
1. `/docs/ARCHITECTURE.md`
2. `/docs/GUARDRAILS.md`
3. `/docs/MCP_INTEGRATION.md`
4. `/docs/VALIDATION_PIPELINE.md`
5. `/docs/AGENT_GUIDELINES.md`
6. `/docs/TROUBLESHOOTING.md`
7. `README.md` (complete version)

---

## Parallel Development Timeline

### Visual Timeline

```
Week 1-2: Phase 0 Foundation (Sequential)
├─ Core structure
├─ Schemas
└─ Basic docs

Week 3-4: Phase 1 Parallel Streams (Simultaneous)
├─ 🟦 Stream A: MCP Config        [Dev 1]
├─ 🟩 Stream B: Guardrails        [Dev 2]
├─ 🟨 Stream C: Quality Tools     [Dev 3]
├─ 🟧 Stream D: Templates         [Dev 4]
├─ 🟪 Stream E: Sandbox           [Dev 5]
├─ 🟥 Stream F: File Routing      [Dev 6] ← Can start Week 1
├─ 🟫 Stream G: Edit Engine       [Dev 7] ← Can start Week 1
└─ ⬜ Stream H: Audit/Observability [Dev 8]

Week 5: Phase 2 Integration
├─ SafePatch Pipeline      [Dev 9]
├─ MCP Server Impls        [Dev 1 + Dev 3]
└─ Pre-commit Integration  [Dev 2 + Dev 3]

Week 6: Phase 3 CI/CD & Testing
├─ GitHub Workflows        [Dev 10]
└─ Test Infrastructure     [Dev 11]

Week 6-7: Phase 4 Documentation (Parallel with Phase 3)
└─ All documentation       [Docs team]
```

---

## Development Stream Dependencies Matrix

| Stream | Depends On | Can Start After | Team Size | Priority |
|--------|-----------|-----------------|-----------|----------|
| **Phase 0** | None | Day 1 | 1-2 | CRITICAL |
| Stream A (MCP) | Phase 0 | Week 3 | 1 | HIGH |
| Stream B (Policy) | Phase 0 | Week 3 | 1 | HIGH |
| Stream C (Quality Tools) | Phase 0 | Week 3 | 1 | HIGH |
| Stream D (Templates) | Phase 0 | Week 3 | 1 | HIGH |
| Stream E (Sandbox) | Phase 0 | Week 3 | 1 | MEDIUM |
| Stream F (File Routing) | None | Day 1 | 1 | LOW |
| Stream G (Edit Engine) | None | Day 1 | 1 | LOW |
| Stream H (Audit) | Phase 0 | Week 3 | 1 | MEDIUM |
| **Phase 2** | A,B,C,D,E | Week 5 | 2-3 | HIGH |
| **Phase 3** | Phase 2 | Week 6 | 2 | HIGH |
| **Phase 4** | Phase 3 | Week 6 | 1-2 | MEDIUM |

---

## Resource Optimization Strategies

### Minimum Team (4 developers)
- **Dev 1**: Phase 0 → Stream A → Stream D → Phase 2 MCP
- **Dev 2**: Stream F → Stream B → Phase 2 Policy
- **Dev 3**: Stream G → Stream C → Phase 2 Pre-commit → Phase 3 CI
- **Dev 4**: Stream H → Stream E → Phase 3 Testing → Phase 4 Docs

### Optimal Team (8 developers)
- Assign one developer per stream in Phase 1
- Collaborate on Phase 2 integration
- Split Phase 3 and 4 work

### Large Team (11+ developers)
- One developer per stream
- Dedicated integration team for Phase 2
- Dedicated DevOps for Phase 3
- Dedicated docs team for Phase 4
- Parallel execution of all streams

---

## Critical Path

The **critical path** (longest dependency chain) is:

```
Phase 0 (2-3 days)
  ↓
Stream C: Quality Tools (1-2 weeks)
  ↓
Phase 2: SafePatch Pipeline (3-5 days)
  ↓
Phase 3: CI/CD (3-5 days)
  ↓
Phase 4: Documentation (3-5 days)
```

**Total Critical Path: 5-6 weeks**

With parallelization, **total project duration: 6-7 weeks** vs. **20+ weeks sequential**

---

## Milestone Checkpoints

### Checkpoint 1 (End of Week 2): Foundation Complete
- [ ] All Phase 0 files exist
- [ ] Schemas validated
- [ ] Development teams can start parallel work

### Checkpoint 2 (End of Week 4): Core Streams Complete
- [ ] MCP configuration system functional
- [ ] Policy system enforcing rules
- [ ] Quality tools configured
- [ ] Templates available
- [ ] Sandbox working

### Checkpoint 3 (End of Week 5): Integration Complete
- [ ] SafePatch pipeline orchestrating all tools
- [ ] MCP servers exposing all capabilities
- [ ] Pre-commit hooks working locally

### Checkpoint 4 (End of Week 6): CI/CD Live
- [ ] All GitHub Actions workflows passing
- [ ] Branch protections enabled
- [ ] Integration tests passing

### Checkpoint 5 (End of Week 7): Production Ready
- [ ] Documentation complete
- [ ] Training materials available
- [ ] Rollout plan approved

---

## Risk Mitigation

### High-Risk Dependencies
1. **Schema Changes**: If Phase 0 schemas change, multiple streams affected
   - **Mitigation**: Lock schemas in design phase; version changes
   
2. **MCP Server Interface**: If MCP protocol changes, all servers need updates
   - **Mitigation**: Use stable MCP SDK version; test interfaces early

3. **Tool Integration**: Tools may have unexpected behaviors
   - **Mitigation**: Stream C should produce mock implementations for Phase 2 testing

### Communication Protocol
- **Daily standups** for stream leads
- **Integration meetings** before Phase 2 starts
- **Shared Slack channel** for cross-stream questions
- **Wiki** for design decisions and interface contracts

This parallel development strategy reduces time-to-production by **~70%** while maintaining quality and enabling team scalability.

## Phase 0: Foundation (Sequential - Must Complete First)

**Duration Estimate: 2-3 days**

These files establish the project structure and core schemas that other streams depend on.

### Core Repository Structure
1. `.gitignore`
2. `.editorconfig`
3. `README.md` (basic structure only)
4. `LICENSE`
5. `/docs/` directory structure
6. `/tests/` directory structure
7. `/scripts/` directory structure
8. `/tools/` directory structure
9. `/.mcp/` directory structure
10. `/policy/` directory structure

### Schema Definitions (Critical for all streams)
11. `/policy/schemas/changeplan.schema.json`
12. `/policy/schemas/unifieddiff.schema.json`
13. `/schemas/ledger.schema.json`
14. `/database/schema.sql`

### Basic Documentation
15. `/docs/conventions.md` (code standards)
16. `CONTRIBUTING.md` (development workflow)

---

## Phase 1: Parallel Development Streams

**Duration Estimate: 1-2 weeks per stream**

These streams can be developed simultaneously by different teams/developers.

### 🟦 Stream A: MCP Configuration System
**Owner: Team A / Developer 1**

**Dependencies:** Phase 0 complete

**Files (in order):**
1. `/.mcp/mcp_servers.json` (example config)
2. `/.mcp/access_groups.json`
3. `/.mcp/Get-McpConfiguration.ps1`
4. `/.mcp/Get-DesiredStateConfiguration.ps1`
5. `/.mcp/New-McpConfigurationObject.ps1`
6. `/.mcp/Set-McpConfiguration.ps1`
7. `/.mcp/Test-McpEnvironment.ps1`
8. `/.mcp/Initialize-McpEnvironment.ps1` (orchestrator)

**Deliverable:** Functional MCP configuration management system

---

### 🟩 Stream B: Guardrail & Policy System
**Owner: Team B / Developer 2**

**Dependencies:** Phase 0 complete

**Files (in order):**
1. `/policy/opa/changeplan.rego`
2. `/policy/opa/forbidden_apis.rego`
3. `/policy/opa/delivery_bundle.rego`
4. `/.semgrep/semgrep.yml` (base config)
5. `/.semgrep/semgrep-powershell.yml`
6. `/.semgrep/semgrep-python.yml`
7. `/.semgrep/semgrep-secrets.yml`
8. `/scripts/validation/Test-ChangePlan.ps1`
9. `/scripts/validation/Test-UnifiedDiff.ps1`
10. `/scripts/validation/Invoke-PolicyCheck.ps1`

**Deliverable:** Policy enforcement system with OPA and Semgrep rules

---

### 🟨 Stream C: Code Quality Tools Configuration
**Owner: Team C / Developer 3**

**Dependencies:** Phase 0 complete

**Files (in order):**

**PowerShell:**
1. `/tools/PSScriptAnalyzerSettings.psd1`
2. `/tools/Verify.ps1`

**Python:**
3. `/tools/ruff.toml`
4. `/tools/mypy.ini`
5. `/tools/pytest.ini`

**TypeScript:**
6. `/tools/.eslintrc.json`
7. `/tools/tsconfig.json`

**Validation Scripts:**
8. `/scripts/validation/Invoke-FormatCheck.ps1`
9. `/scripts/validation/Invoke-LintCheck.ps1`
10. `/scripts/validation/Invoke-TypeCheck.ps1`
11. `/scripts/validation/Invoke-UnitTests.ps1`
12. `/scripts/validation/Invoke-SastScan.ps1`
13. `/scripts/validation/Invoke-SecretScan.ps1`

**Deliverable:** Complete toolchain for format/lint/type/test validation

---

### 🟧 Stream D: Templates & Code Skeletons
**Owner: Team D / Developer 4**

**Dependencies:** Phase 0 complete (conventions.md specifically)

**Files (in order):**

**PowerShell:**
1. `/templates/powershell/AdvancedFunction.ps1`
2. `/templates/powershell/Module.psm1`
3. `/templates/powershell/Module.psd1`
4. `/templates/powershell/Pester.Tests.ps1`

**Python:**
5. `/templates/python/python_cli.py`
6. `/templates/python/test_template.py`
7. `/templates/python/pyproject.toml`

**TypeScript:**
8. `/templates/typescript/typescript_module.ts`

**Deliverable:** Reusable templates for all supported languages

---

### 🟪 Stream E: Sandbox System
**Owner: Team E / Developer 5**

**Dependencies:** Phase 0 complete

**Files (in order):**
1. `/scripts/sandbox/sandbox_linux.sh`
2. `/scripts/sandbox/sandbox_windows.ps1`
3. `/scripts/sandbox/New-EphemeralWorkspace.ps1`
4. `/scripts/sandbox/Remove-EphemeralWorkspace.ps1`

**Deliverable:** Network-isolated sandbox environments

---

### 🟥 Stream F: File Routing System (Completely Independent)
**Owner: Team F / Developer 6**

**Dependencies:** None - can start immediately

**Files (in order):**
1. `/file-routing/Naming_Convention_Guide.md`
2. `/file-routing/file_router.config.json`
3. `/file-routing/FileRouter_Watcher.ps1`

**Deliverable:** Automated file routing from Downloads

---

### 🟫 Stream G: Edit Engine (Completely Independent)
**Owner: Team G / Developer 7**

**Dependencies:** None - can start immediately

**Files (in order):**
1. `/tools/edit-engine/apply_patch.ps1`
2. `/tools/edit-engine/apply_jsonpatch.ps1`
3. `/tools/edit-engine/run_comby.ps1`
4. `/tools/edit-engine/run_ast_mod.ps1`
5. `/tools/edit-engine/regenerate.ps1`

**Deliverable:** Deterministic code modification toolkit

---

### ⬜ Stream H: Audit & Observability
**Owner: Team H / Developer 8**

**Dependencies:** Phase 0 (schema.sql, ledger.schema.json)

**Files (in order):**
1. `/database/seed_data.sql`
2. `/scripts/audit/New-RunLedgerEntry.ps1`
3. `/scripts/audit/Get-RunLedger.ps1`
4. `/scripts/audit/Export-WeeklyReport.ps1`
5. `/scripts/audit/Invoke-DriftDetection.ps1`

**Deliverable:** Logging and reporting infrastructure

---

## Phase 2: Integration & Orchestration

**Duration Estimate: 1 week**

**Dependencies:** Streams A, B, C, D, E must be complete

These components integrate the parallel streams.

### Integration Point 1: SafePatch Pipeline
**Owner: Integration Team or Developer 9**

**Files (in order):**
1. `/scripts/validation/Invoke-SafePatchValidation.ps1` (orchestrates all validation steps)

### Integration Point 2: MCP Server Implementations
**Owner: Team A (MCP experts) + Team C (tool experts)**

**Files (in order):**
1. `/mcp-servers/powershell/ps_quality_mcp.ps1`
2. `/mcp-servers/python/quality_mcp.py`
3. `/mcp-servers/sast/semgrep_mcp.py`
4. `/mcp-servers/secrets/secrets_mcp.py`
5. `/mcp-servers/policy/policy_mcp.py`

### Integration Point 3: Pre-commit Hooks
**Owner: Team C (quality tools) + Team B (policy)**

**Files (in order):**
1. `/.pre-commit-config.yaml`
2. `/scripts/hooks/install-hooks.ps1`
3. `/scripts/hooks/pre-commit.ps1`

---

## Phase 3: CI/CD & Testing

**Duration Estimate: 1 week**

**Dependencies:** Phase 2 complete

### CI/CD Workflows
**Owner: DevOps Team or Developer 10**

**Files (in order):**
1. `/.github/workflows/powershell-verify.yml`
2. `/.github/workflows/python-verify.yml`
3. `/.github/workflows/typescript-verify.yml`
4. `/.github/workflows/sast-secrets.yml`
5. `/.github/workflows/policy-check.yml`
6. `/.github/workflows/quality.yml` (main orchestrator)
7. `/.github/workflows/drift-detection.yml`
8. `/.github/renovate.json`

### Testing Infrastructure
**Owner: QA Team or Developer 11**

**Files (in order):**
1. `/tests/fixtures/` (sample files for testing)
2. `/tests/unit/` (unit tests for individual components)
3. `/tests/integration/` (integration tests)
4. `/tests/Invoke-IntegrationTests.ps1`

---

## Phase 4: Documentation & Refinement

**Duration Estimate: 3-5 days**

**Dependencies:** Phases 1-3 complete

**Can be done in parallel by documentation team**

### Documentation Files
**Owner: Documentation Team**

**Files (any order):**
1. `/docs/ARCHITECTURE.md`
2. `/docs/GUARDRAILS.md`
3. `/docs/MCP_INTEGRATION.md`
4. `/docs/VALIDATION_PIPELINE.md`
5. `/docs/AGENT_GUIDELINES.md`
6. `/docs/TROUBLESHOOTING.md`
7. `README.md` (complete version)

---

## Parallel Development Timeline

### Visual Timeline

```
Week 1-2: Phase 0 Foundation (Sequential)
├─ Core structure
├─ Schemas
└─ Basic docs

Week 3-4: Phase 1 Parallel Streams (Simultaneous)
├─ 🟦 Stream A: MCP Config        [Dev 1]
├─ 🟩 Stream B: Guardrails        [Dev 2]
├─ 🟨 Stream C: Quality Tools     [Dev 3]
├─ 🟧 Stream D: Templates         [Dev 4]
├─ 🟪 Stream E: Sandbox           [Dev 5]
├─ 🟥 Stream F: File Routing      [Dev 6] ← Can start Week 1
├─ 🟫 Stream G: Edit Engine       [Dev 7] ← Can start Week 1
└─ ⬜ Stream H: Audit/Observability [Dev 8]

Week 5: Phase 2 Integration
├─ SafePatch Pipeline      [Dev 9]
├─ MCP Server Impls        [Dev 1 + Dev 3]
└─ Pre-commit Integration  [Dev 2 + Dev 3]

Week 6: Phase 3 CI/CD & Testing
├─ GitHub Workflows        [Dev 10]
└─ Test Infrastructure     [Dev 11]

Week 6-7: Phase 4 Documentation (Parallel with Phase 3)
└─ All documentation       [Docs team]
```

---

## Development Stream Dependencies Matrix

| Stream | Depends On | Can Start After | Team Size | Priority |
|--------|-----------|-----------------|-----------|----------|
| **Phase 0** | None | Day 1 | 1-2 | CRITICAL |
| Stream A (MCP) | Phase 0 | Week 3 | 1 | HIGH |
| Stream B (Policy) | Phase 0 | Week 3 | 1 | HIGH |
| Stream C (Quality Tools) | Phase 0 | Week 3 | 1 | HIGH |
| Stream D (Templates) | Phase 0 | Week 3 | 1 | HIGH |
| Stream E (Sandbox) | Phase 0 | Week 3 | 1 | MEDIUM |
| Stream F (File Routing) | None | Day 1 | 1 | LOW |
| Stream G (Edit Engine) | None | Day 1 | 1 | LOW |
| Stream H (Audit) | Phase 0 | Week 3 | 1 | MEDIUM |
| **Phase 2** | A,B,C,D,E | Week 5 | 2-3 | HIGH |
| **Phase 3** | Phase 2 | Week 6 | 2 | HIGH |
| **Phase 4** | Phase 3 | Week 6 | 1-2 | MEDIUM |

---

## Resource Optimization Strategies

### Minimum Team (4 developers)
- **Dev 1**: Phase 0 → Stream A → Stream D → Phase 2 MCP
- **Dev 2**: Stream F → Stream B → Phase 2 Policy
- **Dev 3**: Stream G → Stream C → Phase 2 Pre-commit → Phase 3 CI
- **Dev 4**: Stream H → Stream E → Phase 3 Testing → Phase 4 Docs

### Optimal Team (8 developers)
- Assign one developer per stream in Phase 1
- Collaborate on Phase 2 integration
- Split Phase 3 and 4 work

### Large Team (11+ developers)
- One developer per stream
- Dedicated integration team for Phase 2
- Dedicated DevOps for Phase 3
- Dedicated docs team for Phase 4
- Parallel execution of all streams

---

## Critical Path

The **critical path** (longest dependency chain) is:

```
Phase 0 (2-3 days)
  ↓
Stream C: Quality Tools (1-2 weeks)
  ↓
Phase 2: SafePatch Pipeline (3-5 days)
  ↓
Phase 3: CI/CD (3-5 days)
  ↓
Phase 4: Documentation (3-5 days)
```

**Total Critical Path: 5-6 weeks**

With parallelization, **total project duration: 6-7 weeks** vs. **20+ weeks sequential**

---

## Milestone Checkpoints

### Checkpoint 1 (End of Week 2): Foundation Complete
- [ ] All Phase 0 files exist
- [ ] Schemas validated
- [ ] Development teams can start parallel work

### Checkpoint 2 (End of Week 4): Core Streams Complete
- [ ] MCP configuration system functional
- [ ] Policy system enforcing rules
- [ ] Quality tools configured
- [ ] Templates available
- [ ] Sandbox working

### Checkpoint 3 (End of Week 5): Integration Complete
- [ ] SafePatch pipeline orchestrating all tools
- [ ] MCP servers exposing all capabilities
- [ ] Pre-commit hooks working locally

### Checkpoint 4 (End of Week 6): CI/CD Live
- [ ] All GitHub Actions workflows passing
- [ ] Branch protections enabled
- [ ] Integration tests passing

### Checkpoint 5 (End of Week 7): Production Ready
- [ ] Documentation complete
- [ ] Training materials available
- [ ] Rollout plan approved

---

## Risk Mitigation

### High-Risk Dependencies
1. **Schema Changes**: If Phase 0 schemas change, multiple streams affected
   - **Mitigation**: Lock schemas in design phase; version changes
   
2. **MCP Server Interface**: If MCP protocol changes, all servers need updates
   - **Mitigation**: Use stable MCP SDK version; test interfaces early

3. **Tool Integration**: Tools may have unexpected behaviors
   - **Mitigation**: Stream C should produce mock implementations for Phase 2 testing

### Communication Protocol
- **Daily standups** for stream leads
- **Integration meetings** before Phase 2 starts
- **Shared Slack channel** for cross-stream questions
- **Wiki** for design decisions and interface contracts

This parallel development strategy reduces time-to-production by **~70%** while maintaining quality and enabling team scalability.