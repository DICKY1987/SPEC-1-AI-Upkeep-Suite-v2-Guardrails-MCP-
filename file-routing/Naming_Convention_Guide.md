# File Routing Naming Convention Guide

## Purpose
The file router powers automated ingest of AI generated artifacts into the SPEC-1 AI Upkeep Suite.  Every artifact that lands in the monitored drop directory must encode enough metadata in its filename for the router to deterministically calculate a destination, detect duplicates, and produce audit entries.  This guide documents the contract enforced by `FileRouter_Watcher.ps1` and the configuration defined in `file_router.config.json`.

## Canonical Pattern
```
PROJECT-AREA-SUBFOLDER__name__timestamp__version__ulid__sha8.ext
```

| Segment      | Description                                                                                  | Character Set / Format                                         | Example                              |
|--------------|----------------------------------------------------------------------------------------------|----------------------------------------------------------------|--------------------------------------|
| `PROJECT`    | Repository or solution identifier. Routes to a configured project root.                      | Uppercase letters, numbers, and dashes (`[A-Z0-9-]+`).         | `SPEC-1`                             |
| `AREA`       | High level capability grouping used by the router to select an area map.                     | Uppercase letters and numbers (`[A-Z0-9]+`).                   | `DOC`, `POL`, `TOOLS`                |
| `SUBFOLDER`  | Alias for a concrete directory beneath the area.                                             | Uppercase letters and numbers (`[A-Z0-9]+`).                   | `GUIDE`, `SCHEMA`, `VALIDATION`      |
| `name`       | Human friendly slug describing the payload.                                                  | Lowercase letters, numbers, and hyphen (`[a-z0-9-]+`).         | `opa-policy-refresh`                |
| `timestamp`  | UTC timestamp captured when the asset was produced.                                          | `yyyyMMddTHHmmssZ` (ISO 8601 basic format).                    | `20250218T132455Z`                  |
| `version`    | Semantic or incremental version for repeated deliveries of the same asset.                   | `vMajor.Minor.Patch` or `rN` (`v1.0.0`, `r02`).                |
| `ulid`       | 26 character ULID ensuring global uniqueness even when timestamps collide.                   | Crockford Base32 ULID (`[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}`). | `01J8NV8ZRN6AJF7S6A9E6JZ2QP` |
| `sha8`       | First eight hexadecimal characters of the SHA-256 hash of the *source* artifact.             | Hexadecimal (`[a-f0-9]{8}`).                                   | `4f7b2c1a`                          |
| `ext`        | Standard file extension for the payload.                                                     | Anything allowed by the OS (config whitelists apply).          | `ps1`, `json`, `md`                 |

The double underscore (`__`) separates major metadata components.  Hyphens inside components have semantic meaning:

* Hyphen between `PROJECT`, `AREA`, and `SUBFOLDER` keeps routing fields compact.
* Hyphen within `name` should be treated as word separators and is preserved when the file is routed.

## Formal Validation Rules
`FileRouter_Watcher.ps1` validates filenames with the following regular expression (documented here for build tooling and unit tests):

```
^(?<project>[A-Z0-9-]+)-(?<area>[A-Z0-9]+)-(?<subfolder>[A-Z0-9]+)__(?<name>[a-z0-9-]+)__(?<timestamp>\d{8}T\d{6}Z)__(?<version>v\d+\.\d+\.\d+|r\d{2})__(?<ulid>[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26})__(?<sha8>[a-f0-9]{8})(?<extension>\.[A-Za-z0-9._-]+)$
```

* `timestamp` must represent a valid UTC date/time; invalid dates (e.g., `20250230T120000Z`) are quarantined.
* `version` accepts both semantic tags (`v1.2.3`) and release counters (`r03`).  Additional patterns can be enabled in configuration if needed.
* `ulid` is verified for canonical length and alphabet; fully validating its monotonic properties is optional.
* `sha8` is compared against the computed SHA-256 hash of the payload to detect corruption.

## Routing Semantics
1. **Project root lookup** – The `PROJECT` segment selects an entry in `routing.projects` within `file_router.config.json`. Each project entry specifies a root path (relative paths are resolved relative to the configuration file).  If the project is unknown, the file is moved to the configured quarantine directory.
2. **Area map resolution** – Within a project, the `AREA` code selects a logical area (e.g., `DOC` → documentation, `POL` → policy, `OPS` → operational scripts).
3. **Subfolder alias** – The `SUBFOLDER` code resolves to a concrete path under the area (e.g., `POL` + `SCHEMA` → `policy/schemas`).  Subfolders allow tight control without exposing raw directory names to AI agents.
4. **Destination assembly** – The router builds the target directory by combining the project root, area base path, and subfolder path.  Directories are created on demand with strict permissions inherited from the parent tree.
5. **Filename preservation** – The routed file keeps its original filename so downstream systems can trace provenance.

## Duplicate Handling
* The router calculates the SHA-256 hash of both the inbound file and any existing file with the same destination name.
* **Same hash** – The file is moved to the `duplicatesDirectory` and logged as `DuplicateContent`. This prevents overwriting identical artifacts while keeping an auditable trail.
* **Different hash** – The router appends a deterministic suffix (`--dupN`) before the extension and deposits the file alongside the existing asset.  The ledger entry captures both hashes.

## Audit & Ledger Expectations
Every routing decision emits a JSONL record containing:

* `timestampUtc` – ISO 8601 timestamp when the action completed.
* `eventType` – `Routed`, `DuplicateContent`, `Conflicted`, `Quarantined`, or `Error`.
* `sourcePath` / `destinationPath` – Absolute paths before and after the move.
* `metadata` – Parsed fields (project, area, subfolder, name, timestamp, version, ulid, sha8, extension).
* `hash` – SHA-256 of the payload (full value, not just `sha8`).
* `configVersion` – `schemaVersion` from the configuration file to aid drift detection.

The ledger path is defined in `logging.ledgerPath`.  It is append-only and rolled manually when size thresholds (configurable) are hit.

## Example Filenames
| Purpose                                      | Example Filename                                                                                  | Destination (per default config)                   |
|----------------------------------------------|----------------------------------------------------------------------------------------------------|----------------------------------------------------|
| Update documentation spec                    | `SPEC-1-DOC-GUIDE__architecture-update__20250218T132455Z__v1.0.0__01J8NV8ZRN6AJF7S6A9E6JZ2QP__4f7b2c1a.md` | `docs/guides`                                      |
| Refresh OPA policy                           | `SPEC-1-POL-SCHEMA__changeplan-policy__20250218T134200Z__v2.1.0__01J8NVF6QH8XF4Y6HCQY9Z5T4M__c2d4e6f8.rego` | `policy/schemas` (rego stored alongside schemas)   |
| Deliver validation PowerShell script update  | `SPEC-1-OPS-VALIDATION__invoke-lintcheck__20250218T140102Z__v3.0.0__01J8NVG3PQX4FSV9AF08WY4T4R__6b8d9c0e.ps1` | `scripts/validation`                               |
| Provide sandbox shell tweak                  | `SPEC-1-OPS-SANDBOX__sandbox-linux__20250218T143015Z__v1.2.0__01J8NVJ4QW9F6SXEJ7J3MZZ6JY__aa11bb22.sh`       | `scripts/sandbox`                                  |
| Introduce Python template                    | `SPEC-1-DEV-PYMOD__python-cli-template__20250218T150500Z__v1.0.0__01J8NVQJ7BE9WRK1SDE8XH2FPG__3d5f7a9b.py`    | `templates/python`                                 |

## Operational Checklist
1. **Ensure clocks are synchronized.**  The timestamp is used in audit reports and determines chronological ordering.
2. **Compute the SHA before renaming.**  The `sha8` segment must match the file’s content; the watcher recomputes the full hash to confirm integrity.
3. **Keep the configuration versioned.**  Update `schemaVersion` whenever the routing table or duplicate policy changes.  Commit the JSON to Git so auditors can reconstruct historical routing rules.
4. **Rotate ledgers regularly.**  For high volume teams, pipe JSONL files into centralized storage weekly.
5. **Extend aliases intentionally.**  When new directories are added (e.g., additional MCP assets), introduce new `SUBFOLDER` aliases instead of reusing existing ones to preserve traceability.

## Non-conformant Files
Files that fail any validation step are moved to the `quarantineDirectory`.  The ledger entry captures the rejection reason (`InvalidName`, `UnknownProject`, `UnknownRoute`, or `ChecksumMismatch`).  Operators should review quarantined items, rename them correctly, and re-introduce them to the watch path once corrected.

## Change Control
Changes to this convention must be synchronized with:

* `file_router.config.json` – to register new projects, area aliases, or duplicate-handling policies.
* `FileRouter_Watcher.ps1` – to update validation logic or checksum enforcement.
* Downstream automation (CI ingestion, SafePatch ledger analytics) that parse filename metadata.

Treat updates as configuration changes: raise a change plan, review with the Quality Engineering team, and land updates alongside regression tests for the router.
