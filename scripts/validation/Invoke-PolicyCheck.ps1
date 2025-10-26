[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [string]$PolicyDir,

    [string[]]$OptionalInputs = @('delivery_bundle.json', 'api_usage.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedWorkspace = Resolve-Path -Path $Workspace -ErrorAction Stop
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
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

function Get-ConftestMessages {
    param([string[]]$Output)

    $messages = @()
    try {
        $parsed = $Output | ConvertFrom-Json -ErrorAction Stop
        if ($parsed.results) {
            foreach ($result in $parsed.results) {
                foreach ($failure in $result.failures) {
                    $messages += "{0}: {1}" -f $result.filename, $failure.msg
                }
                foreach ($warning in $result.warnings) {
                    $messages += "{0}: WARNING {1}" -f $result.filename, $warning.msg
                }
            }
        }
    } catch {
        if ($Output) {
            $messages = @($Output -join [Environment]::NewLine)
        }
    }

    if (-not $messages) {
        $messages = @('Policy evaluation failed with no diagnostic output.')
    }

    return $messages
}

function Resolve-Namespace {
    param([string]$Descriptor)

    if ($Descriptor -match '::') {
        return $Descriptor.Split('::')[0]
    }

    $normalized = $Descriptor.ToLowerInvariant()
    switch -Wildcard ($normalized) {
        'delivery*' { return 'guardrails.delivery' }
        'bundle*' { return 'guardrails.delivery' }
        'api*' { return 'guardrails.forbidden' }
        'forbidden*' { return 'guardrails.forbidden' }
        'changeplan*' { return 'guardrails.changeplan' }
        default { throw "Unable to derive policy namespace for input '$Descriptor'. Provide it as namespace::filename." }
    }
}

function Resolve-InputPath {
    param([string]$Descriptor)

    if ($Descriptor -match '::') {
        return $Descriptor.Split('::')[1]
    }

    return $Descriptor
}

$targets = @(
    [PSCustomObject]@{
        Namespace = 'guardrails.changeplan'
        Path = Join-Path $resolvedWorkspace.Path 'changeplan.json'
        Required = $true
    }
)

foreach ($descriptor in $OptionalInputs) {
    $namespace = Resolve-Namespace -Descriptor $descriptor
    $relativePath = Resolve-InputPath -Descriptor $descriptor
    $absolutePath = Join-Path $resolvedWorkspace.Path $relativePath

    $targets += [PSCustomObject]@{
        Namespace = $namespace
        Path = $absolutePath
        Required = $false
    }
}

$failures = @()

foreach ($target in $targets) {
    if (-not (Test-Path -Path $target.Path)) {
        if ($target.Required) {
            throw "Required policy input missing: $($target.Path)"
        }

        Write-Verbose "Skipping optional policy namespace $($target.Namespace) because $($target.Path) was not found."
        continue
    }

    $resolvedTarget = (Resolve-Path -Path $target.Path -ErrorAction Stop).Path
    $args = @(
        'test',
        $resolvedTarget,
        '--policy',
        $effectivePolicyDir.Path,
        '--namespace',
        $target.Namespace,
        '--output',
        'json'
    )

    Write-Verbose "Evaluating policy namespace $($target.Namespace) for $resolvedTarget"

    $output = & $conftest.Path @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        $messages = Get-ConftestMessages -Output $output
        $failures += [PSCustomObject]@{
            Namespace = $target.Namespace
            Target = $resolvedTarget
            Messages = $messages
        }
    } elseif ($PSBoundParameters.ContainsKey('Verbose') -and $output) {
        $output | Write-Verbose
    }
}

if ($failures) {
    $lines = foreach ($failure in $failures) {
        $joined = $failure.Messages -join ([Environment]::NewLine)
        "[{0}] {1}" -f $failure.Namespace, $joined
    }

    $errorMessage = "Policy evaluation failed:`n" + ($lines -join ([Environment]::NewLine + [Environment]::NewLine))
    throw $errorMessage
}

Write-Verbose 'All policy checks succeeded.'
