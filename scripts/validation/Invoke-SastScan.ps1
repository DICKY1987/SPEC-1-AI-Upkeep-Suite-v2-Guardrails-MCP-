[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [string]$SastScanner = 'semgrep'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$commonModule = Join-Path $PSScriptRoot 'Validation.Common.psm1'
Import-Module -Name $commonModule -Force

$repoRoot = Resolve-WorkspacePath -Workspace $Workspace
$semgrepDirectory = Join-Path $repoRoot '.semgrep'

if (-not (Test-Path -LiteralPath $semgrepDirectory)) {
    throw "Semgrep configuration directory not found at $semgrepDirectory"
}

$configFiles = @(
    'semgrep.yml',
    'semgrep-python.yml',
    'semgrep-powershell.yml'
) | ForEach-Object { Join-Path $semgrepDirectory $_ } | Where-Object { Test-Path -LiteralPath $_ }

if ($configFiles.Count -eq 0) {
    throw 'No Semgrep configuration files were discovered. Add at least one ruleset before running SAST checks.'
}

foreach ($config in $configFiles) {
    $arguments = @('--config', $config, '--error', '--strict', '--metrics', 'off', $repoRoot)
    Invoke-ExternalTool -Tool $SastScanner -Arguments $arguments -WorkingDirectory $repoRoot
}

Write-Verbose 'SAST scan completed successfully.'
