# MCP Integration Guide

1. Define desired servers in `.mcp/mcp_servers.json` and access groups in `.mcp/access_groups.json`.
2. Run `.mcp/Initialize-McpEnvironment.ps1` to merge desired and current state.
3. Implement each server in `mcp-servers/` to expose tool commands via MCP.
4. Validate the environment with `.mcp/Test-McpEnvironment.ps1` before enabling CI workflows.
