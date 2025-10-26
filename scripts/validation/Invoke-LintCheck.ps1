[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [string]$PythonLinter = 'ruff',

    [string]$TypeScriptLinter = 'eslint',

    [string]$PSScriptAnalyzerSettingsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$commonModule = Join-Path $PSScriptRoot 'Validation.Common.psm1'
Import-Module -Name $commonModule -Force

$repoRoot = Resolve-WorkspacePath -Workspace $Workspace
$toolsDirectory = Join-Path $repoRoot 'tools'

if (-not $PSScriptAnalyzerSettingsPath) {
    $PSScriptAnalyzerSettingsPath = Join-Path $toolsDirectory 'PSScriptAnalyzerSettings.psd1'
}

if (-not (Test-Path -LiteralPath $PSScriptAnalyzerSettingsPath)) {
    throw "PSScriptAnalyzer settings file not found at $PSScriptAnalyzerSettingsPath"
}

$psFiles = @(Get-WorkspaceFiles -Workspace $repoRoot -Extensions @('.ps1', '.psm1'))
if ($psFiles.Count -gt 0) {
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        throw 'PSScriptAnalyzer module is required to lint PowerShell code. Install it and retry.'
    }

    Import-Module PSScriptAnalyzer -ErrorAction Stop | Out-Null

    $results = Invoke-ScriptAnalyzer -Path ($psFiles.FullName) -Settings $PSScriptAnalyzerSettingsPath -Recurse -ErrorAction Stop
    $violations = $results | Where-Object { $_.Severity -in @('Warning', 'Error') }
    if ($violations) {
        $formatted = $violations | Sort-Object Path, Line | ForEach-Object {
            $relative = Get-RelativePath -Root $repoRoot -Path $_.Path
            "[$($_.Severity)] $relative:$($_.Line) $($_.RuleName) - $($_.Message)"
        }
        throw "PowerShell lint violations detected:`n" + ($formatted -join "`n")
    }
}

$ruffConfig = Join-Path $toolsDirectory 'ruff.toml'
$pythonFiles = @(Get-WorkspaceFiles -Workspace $repoRoot -Extensions @('.py'))
if (($pythonFiles.Count -gt 0) -and (Test-Path -LiteralPath $ruffConfig)) {
    $arguments = @('check', '--config', $ruffConfig, '--no-cache', '.')
    Invoke-ExternalTool -Tool $PythonLinter -Arguments $arguments -WorkingDirectory $repoRoot
}

$eslintConfig = Join-Path $toolsDirectory '.eslintrc.json'
$tsFiles = @(Get-WorkspaceFiles -Workspace $repoRoot -Extensions @('.ts', '.tsx', '.js', '.jsx'))
if (($tsFiles.Count -gt 0) -and (Test-Path -LiteralPath $eslintConfig)) {
    $arguments = @('--config', $eslintConfig, '--ext', '.ts', '--ext', '.tsx', '--ext', '.js', '--ext', '.jsx', '.')
    Invoke-ExternalTool -Tool $TypeScriptLinter -Arguments $arguments -WorkingDirectory $repoRoot
}

Write-Verbose 'Lint checks completed successfully.'
