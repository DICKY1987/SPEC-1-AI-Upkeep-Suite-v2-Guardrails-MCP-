[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [string]$DiffFile = 'changes.diff'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedWorkspace = Resolve-Path -Path $Workspace -ErrorAction Stop
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Resolve-DiffPath {
    param(
        [string]$Candidate,
        [System.IO.DirectoryInfo]$WorkspaceInfo
    )

    if ([System.IO.Path]::IsPathRooted($Candidate) -and (Test-Path -Path $Candidate)) {
        return Resolve-Path -Path $Candidate -ErrorAction Stop
    }

    $combined = Join-Path $WorkspaceInfo.FullName $Candidate
    if (Test-Path -Path $combined) {
        return Resolve-Path -Path $combined -ErrorAction Stop
    }

    $fallback = Get-ChildItem -Path $WorkspaceInfo.FullName -File | Where-Object {
        $_.Extension -in '.diff', '.patch'
    } | Select-Object -First 1

    if ($fallback) {
        return Resolve-Path -Path $fallback.FullName -ErrorAction Stop
    }

    throw "Unable to locate a unified diff artifact in $($WorkspaceInfo.FullName)."
}

$diffPath = (Resolve-DiffPath -Candidate $DiffFile -WorkspaceInfo $resolvedWorkspace).Path
$diffContent = Get-Content -Path $diffPath -Raw -ErrorAction Stop

if (-not $diffContent.Trim()) {
    throw "Unified diff file '$diffPath' is empty."
}

if ($diffContent -notmatch "^diff --git ") {
    throw "Unified diff '$diffPath' is not in 'git diff' format."
}

if ($diffContent -match "^Binary files ") {
    throw "Binary patches are not supported by the guardrail pipeline."
}

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    throw "Git CLI is required for unified diff validation but was not found in PATH."
}

Push-Location -Path $repoRoot
try {
    $args = @('apply', '--check', '--stat', $diffPath)
    $gitOutput = & $git.Path @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        $message = "Unified diff validation failed:`n" + ($gitOutput -join [Environment]::NewLine)
        throw $message
    }

    if ($PSBoundParameters.ContainsKey('Verbose') -and $gitOutput) {
        $gitOutput | Write-Verbose
    }
} finally {
    Pop-Location
}

Write-Verbose "Unified diff validation completed successfully for $diffPath"
