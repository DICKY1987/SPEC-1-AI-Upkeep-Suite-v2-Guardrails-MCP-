[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [string]$PythonTypeChecker = 'mypy',

    [string]$TypeScriptCompiler = 'tsc'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$commonModule = Join-Path $PSScriptRoot 'Validation.Common.psm1'
Import-Module -Name $commonModule -Force

$repoRoot = Resolve-WorkspacePath -Workspace $Workspace
$toolsDirectory = Join-Path $repoRoot 'tools'

$pythonSources = @(Get-WorkspaceFiles -Workspace $repoRoot -Extensions @('.py'))
$mypyConfig = Join-Path $toolsDirectory 'mypy.ini'
if (($pythonSources.Count -gt 0) -and (Test-Path -LiteralPath $mypyConfig)) {
    $arguments = @('--config-file', $mypyConfig)
    Invoke-ExternalTool -Tool $PythonTypeChecker -Arguments $arguments -WorkingDirectory $repoRoot
}

$tsSources = @(Get-WorkspaceFiles -Workspace $repoRoot -Extensions @('.ts', '.tsx'))
$tsConfig = Join-Path $toolsDirectory 'tsconfig.json'
if (($tsSources.Count -gt 0) -and (Test-Path -LiteralPath $tsConfig)) {
    $arguments = @('--project', $tsConfig, '--noEmit')
    Invoke-ExternalTool -Tool $TypeScriptCompiler -Arguments $arguments -WorkingDirectory $repoRoot
}

Write-Verbose 'Type checks completed successfully.'
