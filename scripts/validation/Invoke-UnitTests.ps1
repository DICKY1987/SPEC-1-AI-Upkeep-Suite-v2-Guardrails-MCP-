[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [string]$PythonTestRunner = 'pytest',

    [string]$PowerShellTestModule = 'Pester'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$commonModule = Join-Path $PSScriptRoot 'Validation.Common.psm1'
Import-Module -Name $commonModule -Force

$repoRoot = Resolve-WorkspacePath -Workspace $Workspace
$toolsDirectory = Join-Path $repoRoot 'tools'

$pytestConfig = Join-Path $toolsDirectory 'pytest.ini'
if (Test-Path -LiteralPath $pytestConfig) {
    $arguments = @('-c', $pytestConfig)
    Invoke-ExternalTool -Tool $PythonTestRunner -Arguments $arguments -WorkingDirectory $repoRoot
}

$testsDirectory = Join-Path $repoRoot 'tests'
$powershellTests = @()
if (Test-Path -LiteralPath $testsDirectory) {
    $powershellTests = @(Get-WorkspaceFiles -Workspace $testsDirectory -Extensions @('.ps1', '.psm1'))
}

if ($powershellTests.Count -gt 0) {
    if (-not (Get-Module -ListAvailable -Name $PowerShellTestModule)) {
        throw "PowerShell test module '$PowerShellTestModule' is required to execute tests. Install it and retry."
    }

    Import-Module -Name $PowerShellTestModule -ErrorAction Stop | Out-Null
    $pesterConfiguration = [PesterConfiguration]::Default
    $pesterConfiguration.Run.Path = $testsDirectory
    $pesterConfiguration.Run.Exit = $true
    $pesterConfiguration.TestResult.Enabled = $false
    Invoke-Pester -Configuration $pesterConfiguration
}

Write-Verbose 'Unit tests completed successfully.'
