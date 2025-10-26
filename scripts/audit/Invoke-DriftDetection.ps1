<#!
.SYNOPSIS
    Detects configuration drift across guardrail-critical assets.

.DESCRIPTION
    Invoke-DriftDetection.ps1 evaluates the repository for uncommitted changes
    or deviations from a supplied checksum manifest. The script focuses on
    guardrail-critical paths (policies, schemas, validation scripts, database
    definitions, and audit utilities) to ensure the AI Upkeep Suite operates in a
    known-good state. Findings are returned to the caller and the process exit
    code is set to 1 when drift is detected.

.PARAMETER Repository
    Root path of the Git repository to analyse. Defaults to the current working
    directory.

.PARAMETER CriticalPaths
    Relative paths to monitor for drift when a manifest is not supplied. The
    default list targets guardrail directories and schema files.

.PARAMETER BaselineManifestPath
    Optional JSON manifest describing the expected SHA256 hash for critical
    files. The manifest should contain an object with a `files` array comprised
    of `{ "path": "relative/path", "sha256": "<hash>" }` entries. When
    provided, checksum verification augments Git status checks.

.PARAMETER Strict
    When set, the script flags any tracked changes in the repository even if
    they fall outside CriticalPaths.

.PARAMETER AsJson
    Serialises the final result object to JSON for tooling integration.

.EXAMPLE
    ./Invoke-DriftDetection.ps1 -Repository .. -BaselineManifestPath ./policy/guardrails.manifest.json -AsJson

.NOTES
    Author: AI Upkeep Suite - Stream H
    PowerShell 5.1 or later is required. Git must be available on the PATH for
    status comparisons.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Repository = (Get-Location).Path,

    [string[]]$CriticalPaths = @(
        '.mcp',
        'policy',
        'schemas',
        'scripts/validation',
        'scripts/audit',
        'tools',
        'database/schema.sql',
        'database/seed_data.sql'
    ),

    [string]$BaselineManifestPath,

    [switch]$Strict,

    [switch]$AsJson
)

$resolvedRepository = Resolve-Path -Path $Repository -ErrorAction SilentlyContinue
if (-not $resolvedRepository) {
    throw "Repository path not found: $Repository"
}
$repositoryRoot = $resolvedRepository.Path

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCommand) {
    Write-Verbose 'Git is not available on PATH. Only checksum validation will be performed.'
}

$findings = New-Object System.Collections.Generic.List[object]

function Add-Finding {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $findings.Add([pscustomobject]@{
        path    = $Path
        type    = $Type
        message = $Message
    }) | Out-Null
}

if ($gitCommand) {
    $statusArgs = @('-C', $repositoryRoot, 'status', '--porcelain')
    if (-not $Strict.IsPresent -and $CriticalPaths -and $CriticalPaths.Length -gt 0) {
        $statusArgs += '--'
        $statusArgs += $CriticalPaths
    }

    $statusOutput = & git @statusArgs
    foreach ($line in $statusOutput) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $changeType = $line.Substring(0, 2).Trim()
        $relativePath = $line.Substring(3).Trim()
        Add-Finding -Path $relativePath -Type 'git-status' -Message "Detected change ($changeType)"
    }
}

if ($BaselineManifestPath) {
    $resolvedManifest = Resolve-Path -Path $BaselineManifestPath -ErrorAction SilentlyContinue
    if (-not $resolvedManifest) {
        throw "Baseline manifest not found: $BaselineManifestPath"
    }

    try {
        $manifestContent = Get-Content -Path $resolvedManifest.Path -Raw -ErrorAction Stop
        $manifest = $manifestContent | ConvertFrom-Json -Depth 10
    }
    catch {
        throw "Unable to parse manifest '$BaselineManifestPath': $($_.Exception.Message)"
    }

    if (-not $manifest -or -not $manifest.files) {
        throw 'Baseline manifest must contain a "files" array.'
    }

    foreach ($fileEntry in $manifest.files) {
        $relativePath = [string]$fileEntry.path
        $expectedHash = [string]$fileEntry.sha256
        if ([string]::IsNullOrWhiteSpace($relativePath) -or [string]::IsNullOrWhiteSpace($expectedHash)) {
            continue
        }

        $absolutePath = Join-Path -Path $repositoryRoot -ChildPath $relativePath
        if (-not (Test-Path -Path $absolutePath)) {
            Add-Finding -Path $relativePath -Type 'missing' -Message 'File listed in manifest is missing.'
            continue
        }

        try {
            $fileHash = Get-FileHash -Path $absolutePath -Algorithm SHA256
        }
        catch {
            Add-Finding -Path $relativePath -Type 'hash-error' -Message $_.Exception.Message
            continue
        }

        if ($fileHash.Hash.ToLowerInvariant() -ne $expectedHash.ToLowerInvariant()) {
            Add-Finding -Path $relativePath -Type 'checksum' -Message 'SHA256 hash does not match manifest.'
        }
    }
}

$driftDetected = $findings.Count -gt 0

$result = [pscustomobject]@{
    repository    = $repositoryRoot
    checkedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
    driftDetected = $driftDetected
    findings      = $findings
}

if ($driftDetected) {
    $global:LASTEXITCODE = 1
}
else {
    $global:LASTEXITCODE = 0
}

if ($AsJson.IsPresent) {
    $result | ConvertTo-Json -Depth 16
}
else {
    $result
}
