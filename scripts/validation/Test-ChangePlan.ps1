[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Workspace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedWorkspace = Resolve-Path -Path $Workspace -ErrorAction Stop
Write-Verbose "Validating ChangePlan schema and policies for $($resolvedWorkspace.Path)"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$schemaPath = Join-Path $repoRoot 'policy/schemas/changeplan.schema.json'

if (-not (Test-Path -Path $schemaPath)) {
    throw "ChangePlan schema not found at $schemaPath"
}

$changePlanPath = Join-Path $resolvedWorkspace.Path 'changeplan.json'
if (-not (Test-Path -Path $changePlanPath)) {
    throw "Expected ChangePlan artifact at $changePlanPath"
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    throw "Python runtime not found in PATH. ChangePlan validation requires python."
}

$arguments = @(
    '-m',
    'scripts.validation.changeplan_validator',
    '--workspace',
    $resolvedWorkspace.Path,
    '--schema',
    (Resolve-Path -Path $schemaPath).Path
)

$null = & $python.Path @arguments
if ($LASTEXITCODE -ne 0) {
    throw "ChangePlan validation failed with exit code $LASTEXITCODE"
}

Write-Verbose 'ChangePlan validation completed successfully.'
