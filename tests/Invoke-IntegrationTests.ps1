[CmdletBinding()]
param(
    [string]$Workspace = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedWorkspace = Resolve-Path -Path $Workspace
Write-Verbose "Running integration test suite from $($resolvedWorkspace.Path)"

$repoRoot = Split-Path -Parent $PSScriptRoot
$pytestConfig = Join-Path $repoRoot 'tools/pytest.ini'
$python = Get-Command python -ErrorAction Stop

$arguments = @(
    '-m',
    'pytest',
    '-c',
    (Resolve-Path -Path $pytestConfig).Path,
    'tests/integration'
)

& $python.Path @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Integration tests failed with exit code $LASTEXITCODE"
}

Write-Verbose 'Integration tests completed successfully.'
