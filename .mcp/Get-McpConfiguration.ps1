#requires -Version 5.1
function Get-McpConfiguration {
    <#
    .SYNOPSIS
    Loads the persisted MCP configuration state from disk if present.

    .DESCRIPTION
    Get-McpConfiguration retrieves the current MCP configuration snapshot used to drive
    environment comparisons. If the state file has not been created yet the function
    returns an empty configuration object. The JSON payload is validated before being
    deserialized to ensure downstream consumers can rely on the shape of the data.

    .PARAMETER StateFilePath
    Optional override for the configuration state file path. Defaults to mcp_state.json
    located alongside the script.

    .OUTPUTS
    PSCustomObject containing the current configuration state.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$StateFilePath = (Join-Path $PSScriptRoot 'mcp_state.json')
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    if (-not (Test-Path -LiteralPath $StateFilePath)) {
        return [pscustomobject]@{
            Version      = '0.0.0'
            Servers      = @()
            AccessGroups = @()
            LastUpdated  = $null
            ConfigurationHash = $null
        }
    }

    $stateJson = Get-Content -Path $StateFilePath -Raw
    if (-not (Test-Json -Json $stateJson)) {
        throw "Existing MCP state file is not valid JSON: $StateFilePath"
    }

    $stateObject = $stateJson | ConvertFrom-Json -Depth 10

    if (-not $stateObject.Servers -or -not ($stateObject.Servers -is [System.Collections.IEnumerable])) {
        throw 'Persisted MCP state is missing the Servers collection.'
    }

    if ($null -eq $stateObject.AccessGroups) {
        throw 'Persisted MCP state is missing the AccessGroups collection.'
    }

    return $stateObject
}

Export-ModuleMember -Function Get-McpConfiguration
