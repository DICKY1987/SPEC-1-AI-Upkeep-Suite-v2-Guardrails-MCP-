[CmdletBinding()]
param(
    [string]$ConfigurationPath = (Join-Path $PSScriptRoot 'mcp_servers.json'),
    [string]$AccessGroupsPath = (Join-Path $PSScriptRoot 'access_groups.json')
)

. (Join-Path $PSScriptRoot 'Get-DesiredStateConfiguration.ps1')
. (Join-Path $PSScriptRoot 'Get-McpConfiguration.ps1')
. (Join-Path $PSScriptRoot 'New-McpConfigurationObject.ps1')
. (Join-Path $PSScriptRoot 'Set-McpConfiguration.ps1')
. (Join-Path $PSScriptRoot 'Test-McpEnvironment.ps1')

$desired = Get-DesiredStateConfiguration -ConfigurationPath $ConfigurationPath -AccessGroupsPath $AccessGroupsPath
$current = Get-McpConfiguration
$merged = New-McpConfigurationObject -Desired $desired -Current $current
Set-McpConfiguration -Configuration $merged
Test-McpEnvironment -Configuration $merged
