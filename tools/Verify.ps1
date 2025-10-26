[CmdletBinding()]
param(
    [string]$Workspace = (Get-Location).Path,
    [switch]$VerboseOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$validationScripts = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/validation'
$validationEntryPoint = Join-Path $validationScripts 'Invoke-SafePatchValidation.ps1'

if (-not (Test-Path -LiteralPath $validationEntryPoint)) {
    throw "SafePatch validation entry point not found at $validationEntryPoint"
}

$verbosePreference = if ($VerboseOutput) { 'Continue' } else { 'SilentlyContinue' }
Invoke-Command -ScriptBlock {
    param($entryPoint, $workspace, $verbosePref)
    $VerbosePreference = $verbosePref
    & $entryPoint -Workspace $workspace
} -ArgumentList $validationEntryPoint, (Resolve-Path -LiteralPath $Workspace).ProviderPath, $verbosePreference

Write-Host '✔ All verification checks passed.' -ForegroundColor Green
