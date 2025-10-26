[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [string]$PythonFormatter = 'ruff',

    [string]$NodeFormatter = 'prettier',

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

$psFiles = @(Get-WorkspaceFiles -Workspace $repoRoot -Extensions @('.ps1', '.psm1', '.psd1'))
if ($psFiles.Count -gt 0) {
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        throw 'PSScriptAnalyzer module is required to validate PowerShell formatting. Install it and retry.'
    }

    Import-Module PSScriptAnalyzer -ErrorAction Stop | Out-Null
    if (-not (Get-Command -Name Invoke-Formatter -Module PSScriptAnalyzer -ErrorAction SilentlyContinue)) {
        throw 'Invoke-Formatter command not found. Update PSScriptAnalyzer to version 1.21 or later.'
    }

    $nonCompliant = @()
    foreach ($file in $psFiles) {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        $formatted = Invoke-Formatter -ScriptDefinition $content -Settings $PSScriptAnalyzerSettingsPath -FilePath $file.FullName -ErrorAction Stop
        if ($formatted -is [array]) {
            $formatted = $formatted -join [Environment]::NewLine
        }

        $normalizedOriginal = $content -replace "`r`n", "`n"
        $normalizedFormatted = $formatted -replace "`r`n", "`n"

        if ($normalizedOriginal -ne $normalizedFormatted) {
            $nonCompliant += Get-RelativePath -Root $repoRoot -Path $file.FullName
        }
    }

    if ($nonCompliant.Count -gt 0) {
        $message = "PowerShell files require formatting:`n - " + ($nonCompliant -join "`n - ")
        throw $message
    }
}

$ruffConfig = Join-Path $toolsDirectory 'ruff.toml'
$pythonFiles = @(Get-WorkspaceFiles -Workspace $repoRoot -Extensions @('.py'))
if (($pythonFiles.Count -gt 0) -and (Test-Path -LiteralPath $ruffConfig)) {
    $arguments = @('format', '--config', $ruffConfig, '--check', '.', '--exit-non-zero-on-fix')
    Invoke-ExternalTool -Tool $PythonFormatter -Arguments $arguments -WorkingDirectory $repoRoot
}

$typescriptExtensions = @('.ts', '.tsx', '.js', '.jsx', '.json', '.cjs', '.mjs', '.cts', '.mts')
$tsFiles = @(Get-WorkspaceFiles -Workspace $repoRoot -Extensions $typescriptExtensions)
if ($tsFiles.Count -gt 0) {
    $arguments = @('--check', '.')
    Invoke-ExternalTool -Tool $NodeFormatter -Arguments $arguments -WorkingDirectory $repoRoot
}

Write-Verbose 'Formatting checks completed successfully.'
