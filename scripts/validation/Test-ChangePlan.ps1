[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [string]$PolicyDir
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

$effectivePolicyDir = if ($PSBoundParameters.ContainsKey('PolicyDir')) {
    Resolve-Path -Path $PolicyDir -ErrorAction Stop
} else {
    Resolve-Path -Path (Join-Path $repoRoot 'policy/opa') -ErrorAction Stop
}

if (-not (Test-Path -Path $effectivePolicyDir.Path)) {
    throw "OPA policy directory not found at $($effectivePolicyDir.Path)"
}

$conftest = Get-Command conftest -ErrorAction SilentlyContinue
if (-not $conftest) {
    throw "Conftest CLI is required for policy evaluation but was not found in PATH."
}

$changeplanFile = (Resolve-Path -Path $changePlanPath).Path
$conftestArgs = @(
    'test',
    $changeplanFile,
    '--policy',
    $effectivePolicyDir.Path,
    '--namespace',
    'guardrails.changeplan',
    '--output',
    'json'
)

$policyOutput = & $conftest.Path @conftestArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    $policyMessages = @()
    try {
        $parsed = $policyOutput | ConvertFrom-Json -ErrorAction Stop
        if ($parsed.results) {
            foreach ($result in $parsed.results) {
                foreach ($failure in $result.failures) {
                    $policyMessages += "{0}: {1}" -f $result.filename, $failure.msg
                }
            }
        }
    } catch {
        $policyMessages = @($policyOutput -join [Environment]::NewLine)
    }

    if (-not $policyMessages) {
        $policyMessages = @('ChangePlan policy evaluation failed for an unknown reason.')
    }

    $message = "ChangePlan policy evaluation failed:`n" + ($policyMessages -join [Environment]::NewLine)
    throw $message
}

Write-Verbose 'ChangePlan validation completed successfully.'
