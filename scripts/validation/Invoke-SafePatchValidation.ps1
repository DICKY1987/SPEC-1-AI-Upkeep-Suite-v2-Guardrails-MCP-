[CmdletBinding()]
param(
    [string]$Workspace = (Get-Location).Path
)

Write-Verbose "Starting SafePatch validation for $Workspace"
& (Join-Path $PSScriptRoot 'Invoke-FormatCheck.ps1') -Workspace $Workspace
& (Join-Path $PSScriptRoot 'Invoke-LintCheck.ps1') -Workspace $Workspace
& (Join-Path $PSScriptRoot 'Test-ChangePlan.ps1') -Workspace $Workspace
& (Join-Path $PSScriptRoot 'Test-UnifiedDiff.ps1') -Workspace $Workspace
Write-Verbose 'SafePatch validation pipeline completed.'
