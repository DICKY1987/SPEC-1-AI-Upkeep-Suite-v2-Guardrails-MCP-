function Get-McpConfiguration {
    [CmdletBinding()]
    param(
        [string]$StateFile = (Join-Path $PSScriptRoot 'mcp_state.json')
    )

    if (-not (Test-Path $StateFile)) {
        return [pscustomobject]@{
            Servers      = @()
            AccessGroups = @()
            Version      = "0.0.0"
        }
    }

    return Get-Content -Path $StateFile -Raw | ConvertFrom-Json
}
Export-ModuleMember -Function Get-McpConfiguration
