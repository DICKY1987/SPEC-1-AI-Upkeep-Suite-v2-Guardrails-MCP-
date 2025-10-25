function Set-McpConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Configuration,
        [string]$OutputPath = (Join-Path $PSScriptRoot 'mcp_state.json')
    )

    $Configuration | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Verbose "MCP configuration written to $OutputPath"
}
Export-ModuleMember -Function Set-McpConfiguration
