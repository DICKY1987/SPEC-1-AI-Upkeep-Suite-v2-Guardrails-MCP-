# Troubleshooting

## MCP server fails to start
- Ensure the entry point path exists and is executable.
- Validate `.mcp/mcp_servers.json` with `Get-DesiredStateConfiguration.ps1`.

## SafePatch validation fails
- Review logs from `tools/Verify.ps1` to identify failing stage.
- Confirm Semgrep and policy bundles are installed locally.
