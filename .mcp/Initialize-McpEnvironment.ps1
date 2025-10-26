#requires -Version 5.1
Set-StrictMode -Version Latest

<#
.SYNOPSIS
Synchronizes the local MCP environment with the desired configuration state.

.DESCRIPTION
Initialize-McpEnvironment orchestrates the end-to-end reconciliation process for the MCP
configuration system. The script loads the desired state definition, compares it with the
persisted configuration, generates a merged object, validates the environment, and optionally
writes the updated state file. Errors are surfaced immediately to ensure the calling pipeline
halts when prerequisites are not satisfied.

.PARAMETER ConfigurationPath
Path to the desired state configuration JSON file (mcp_servers.json).

.PARAMETER AccessGroupsPath
Path to the access groups JSON file (access_groups.json).

.PARAMETER StateFilePath
Destination path for the persisted MCP state file (mcp_state.json).

.PARAMETER RepositoryRoot
Root directory of the repository. Defaults to the parent of the .mcp directory.

.PARAMETER ValidateOnly
Skips writing the state file and only performs validation. Useful for CI checks.

.EXAMPLE
./Initialize-McpEnvironment.ps1 -Verbose
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigurationPath = (Join-Path $PSScriptRoot 'mcp_servers.json'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$AccessGroupsPath = (Join-Path $PSScriptRoot 'access_groups.json'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$StateFilePath = (Join-Path $PSScriptRoot 'mcp_state.json'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [Parameter()]
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Get-DesiredStateConfiguration.ps1')
. (Join-Path $PSScriptRoot 'Get-McpConfiguration.ps1')
. (Join-Path $PSScriptRoot 'New-McpConfigurationObject.ps1')
. (Join-Path $PSScriptRoot 'Set-McpConfiguration.ps1')
. (Join-Path $PSScriptRoot 'Test-McpEnvironment.ps1')

try {
    $desired = Get-DesiredStateConfiguration -ConfigurationPath $ConfigurationPath -AccessGroupsPath $AccessGroupsPath
    $current = Get-McpConfiguration -StateFilePath $StateFilePath
    $merged = New-McpConfigurationObject -Desired $desired -Current $current

    Test-McpEnvironment -Configuration $merged -RepositoryRoot $RepositoryRoot | Out-Null

    if ($ValidateOnly.IsPresent) {
        Write-Verbose 'Validation completed successfully; state file not modified because -ValidateOnly was specified.'
        return $merged
    }

    if ($PSCmdlet.ShouldProcess($StateFilePath, 'Update MCP configuration state')) {
        $emitVerbose = $PSBoundParameters.ContainsKey('Verbose')
        Set-McpConfiguration -Configuration $merged -OutputPath $StateFilePath -Verbose:$emitVerbose
    }

    return $merged
}
catch {
    throw
}
