#requires -Version 5.1
function New-McpConfigurationObject {
    <#
    .SYNOPSIS
    Builds the merged MCP configuration object used to drive state reconciliation.

    .DESCRIPTION
    New-McpConfigurationObject merges the desired configuration with the currently persisted
    state, retaining desired definitions while preserving metadata such as the previous
    configuration hash when appropriate. The resulting object includes a deterministic hash
    that captures the desired configuration content for downstream integrity checks.

    .PARAMETER Desired
    Desired state object containing Servers, AccessGroups, and Version members.

    .PARAMETER Current
    Existing configuration state returned by Get-McpConfiguration.

    .OUTPUTS
    PSCustomObject representing the merged configuration along with metadata.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$Desired,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$Current
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $payload = [pscustomobject]@{
        Version      = $Desired.Version
        Servers      = $Desired.Servers
        AccessGroups = $Desired.AccessGroups
    }

    $serializedPayload = $payload | ConvertTo-Json -Depth 10
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($serializedPayload))
    }
    finally {
        $sha256.Dispose()
    }

    $configurationHash = ([BitConverter]::ToString($hashBytes)) -replace '-', ''

    return [pscustomobject]@{
        Version           = $Desired.Version
        Servers           = $Desired.Servers
        AccessGroups      = $Desired.AccessGroups
        LastUpdated       = (Get-Date).ToUniversalTime().ToString('o')
        PreviousHash      = if ($Current.ConfigurationHash) { [string]$Current.ConfigurationHash } else { $null }
        ConfigurationHash = $configurationHash
    }
}

Export-ModuleMember -Function New-McpConfigurationObject
