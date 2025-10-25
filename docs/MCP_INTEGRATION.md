# MCP Integration Guide

This guide explains how to configure and operate the MCP tool plane that powers
quality enforcement across PowerShell, Python, TypeScript, and shared services.

## Components
- `/.mcp/mcp_servers.json`: authoritative configuration describing each MCP
  server endpoint, supported tools, and invocation parameters.
- `/.mcp/access_groups.json`: maps roles (reader, contributor, maintainer) to
  allowed tools and servers.
- `/.mcp/*.ps1` scripts: automation helpers for initializing, testing, and
  updating the MCP environment.
- `/mcp-servers/`: runtime implementations exposing language tooling via MCP.

## Setup Workflow

1. **Author Desired State**
   - Populate `mcp_servers.json` with server IDs, transport details, and
     underlying command invocations.
   - Define access control lists in `access_groups.json` using least-privilege.

2. **Initialize Environment**
   - Run `./.mcp/Initialize-McpEnvironment.ps1` to materialize configuration
     files, secrets, and certificates.
   - The script leverages `Get-DesiredStateConfiguration.ps1` to load JSON and
     `Set-McpConfiguration.ps1` to persist merged state.

3. **Validate Configuration**
   - Execute `./.mcp/Test-McpEnvironment.ps1` to verify each server responds and
     required tools are available.
   - Use `Get-McpConfiguration.ps1` to compare runtime state against desired
     configuration snapshots.

4. **Operate MCP Servers**
   - PowerShell server (`ps_quality_mcp.ps1`) surfaces PSScriptAnalyzer, Pester,
     formatting, and edit engine operations.
   - Python server (`quality_mcp.py`) exposes ruff, black, mypy, and pytest.
   - Additional servers provide Semgrep-based SAST, secret scanning, and OPA
     policy evaluation.

5. **Integrate with Workflows**
   - SafePatch pipeline calls MCP tools when executing validation stages.
   - CI/CD workflows run MCP-based commands on runners to maintain parity with
     local validation.

## Operational Tips
- Version control the desired-state JSON files and review changes via PR.
- When adding a new tool, create or update the corresponding MCP server script
  under `/mcp-servers/` and reference it in `mcp_servers.json`.
- Use the audit scripts to log MCP configuration changes to the ledger for
  traceability.
