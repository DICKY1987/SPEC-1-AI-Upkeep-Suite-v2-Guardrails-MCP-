[CmdletBinding()]
param(
    [string]$Workspace = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedWorkspace = Resolve-Path -LiteralPath $Workspace -ErrorAction Stop
$scriptDirectory = $PSScriptRoot

function Invoke-ValidationStep {
    param(
        [Parameter(Mandatory)][string]$ScriptName,
        [Parameter(Mandatory)][string]$Description
    )

    $scriptPath = Join-Path $scriptDirectory $ScriptName
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Validation script '$ScriptName' was not found at $scriptPath."
    }

    Write-Verbose "Starting $Description"
    & $scriptPath -Workspace $resolvedWorkspace.ProviderPath
}

Invoke-ValidationStep -ScriptName 'Invoke-FormatCheck.ps1' -Description 'formatting checks'
Invoke-ValidationStep -ScriptName 'Invoke-LintCheck.ps1' -Description 'lint checks'
Invoke-ValidationStep -ScriptName 'Invoke-TypeCheck.ps1' -Description 'static type checks'
Invoke-ValidationStep -ScriptName 'Invoke-UnitTests.ps1' -Description 'unit tests'
Invoke-ValidationStep -ScriptName 'Invoke-SastScan.ps1' -Description 'SAST scan'
Invoke-ValidationStep -ScriptName 'Invoke-SecretScan.ps1' -Description 'secret scan'
Invoke-ValidationStep -ScriptName 'Test-ChangePlan.ps1' -Description 'ChangePlan validation'
Invoke-ValidationStep -ScriptName 'Test-UnifiedDiff.ps1' -Description 'unified diff validation'

Write-Verbose 'SafePatch validation pipeline completed successfully.'
