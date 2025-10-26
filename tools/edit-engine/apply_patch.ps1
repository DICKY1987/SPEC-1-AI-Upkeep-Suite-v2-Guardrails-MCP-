#Requires -Version 5.1
<#!
.SYNOPSIS
    Applies a unified diff patch to the repository in a deterministic manner.

.DESCRIPTION
    Validates and applies a unified diff patch file using Git when available, with an optional
    fallback to the POSIX `patch` utility. The script performs a dry run first to ensure the
    patch can be applied cleanly before modifying any files. Execution fails fast on any error
    to avoid leaving the working tree in an indeterminate state.

.PARAMETER PatchPath
    Path to the unified diff patch file to apply.

.PARAMETER WorkingDirectory
    Repository root (or target directory) where the patch should be applied. Defaults to the
    current directory.

.PARAMETER CheckOnly
    Performs validation without modifying the working tree.

.PARAMETER AllowWhitespaceFixes
    Allows Git to auto-correct whitespace errors while applying the patch. When omitted,
    whitespace violations result in an error.

.PARAMETER StripComponents
    Number of leading path components to strip when falling back to the POSIX `patch`
    utility. Defaults to 1, matching the typical format emitted by git diff.

.PARAMETER UsePatchUtility
    Forces the use of the POSIX `patch` utility instead of Git.

.EXAMPLE
    .\apply_patch.ps1 -PatchPath ..\changes.diff -Verbose

    Applies the patch defined in `changes.diff` to the current repository.

.NOTES
    Part of the AI Upkeep Suite v2 Edit Engine.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PatchPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$WorkingDirectory = (Get-Location).Path,

    [Parameter()]
    [switch]$CheckOnly,

    [Parameter()]
    [switch]$AllowWhitespaceFixes,

    [Parameter()]
    [ValidateRange(0, 10)]
    [int]$StripComponents = 1,

    [Parameter()]
    [switch]$UsePatchUtility
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ExistingFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Patch file '$Path' was not found or is not a file."
    }

    $fileInfo = Get-Item -LiteralPath $resolved -Force
    if ($fileInfo.Length -le 0) {
        throw "Patch file '$($fileInfo.FullName)' is empty."
    }

    return $fileInfo.FullName
}

function Resolve-ExistingDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Directory '$Path' was not found or is not accessible."
    }

    return (Get-Item -LiteralPath $resolved -Force).FullName
}

function Invoke-ExternalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter()]
        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    Write-Verbose "Executing: $FilePath $($ArgumentList -join ' ')"

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.UseShellExecute = $false

    foreach ($arg in $ArgumentList) {
        [void]$startInfo.ArgumentList.Add($arg)
    }

    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
    }
    finally {
        $process.Dispose()
    }

    if ($stdout) {
        Write-Verbose $stdout.TrimEnd()
    }
    if ($stderr) {
        Write-Verbose $stderr.TrimEnd()
    }

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut   = $stdout
        StdErr   = $stderr
    }
}

$patchFile = Resolve-ExistingFile -Path $PatchPath
$repoRoot = Resolve-ExistingDirectory -Path $WorkingDirectory

function Test-GitAvailable {
    [CmdletBinding()]
    param()

    return (Get-Command -Name git -ErrorAction SilentlyContinue) -ne $null
}

function Invoke-GitApplyCheck {
    [CmdletBinding()]
    param(
        [string]$PatchFile,
        [string]$RepositoryRoot,
        [switch]$AllowWhitespaceFixes
    )

    $arguments = @('--check')
    if ($AllowWhitespaceFixes) {
        $arguments += '--whitespace=fix'
    }
    else {
        $arguments += '--whitespace=error-all'
    }
    $arguments += $PatchFile

    $result = Invoke-ExternalCommand -FilePath 'git' -ArgumentList $arguments -WorkingDirectory $RepositoryRoot
    if ($result.ExitCode -ne 0) {
        throw "git apply --check failed with exit code $($result.ExitCode).`n$($result.StdErr)"
    }
}

function Invoke-GitApply {
    [CmdletBinding()]
    param(
        [string]$PatchFile,
        [string]$RepositoryRoot,
        [switch]$AllowWhitespaceFixes
    )

    $arguments = @()
    if ($AllowWhitespaceFixes) {
        $arguments += '--whitespace=fix'
    }
    else {
        $arguments += '--whitespace=error-all'
    }
    $arguments += $PatchFile

    $result = Invoke-ExternalCommand -FilePath 'git' -ArgumentList $arguments -WorkingDirectory $RepositoryRoot
    if ($result.ExitCode -ne 0) {
        throw "git apply failed with exit code $($result.ExitCode).`n$($result.StdErr)"
    }
}

function Invoke-PatchUtility {
    [CmdletBinding()]
    param(
        [string]$PatchFile,
        [string]$RepositoryRoot,
        [int]$StripCount,
        [switch]$DryRun
    )

    $patchCommand = Get-Command -Name patch -ErrorAction SilentlyContinue
    if (-not $patchCommand) {
        throw 'The POSIX patch utility is not available on this system. Install it or run with Git available.'
    }

    $arguments = @("-p$StripCount", '-s', '-N', '-i', $PatchFile)
    if ($DryRun) {
        $arguments = @("-p$StripCount", '--dry-run', '-s', '-N', '-i', $PatchFile)
    }

    $result = Invoke-ExternalCommand -FilePath $patchCommand.Source -ArgumentList $arguments -WorkingDirectory $RepositoryRoot
    if ($result.ExitCode -ne 0) {
        $commandLabel = if ($DryRun) { 'patch --dry-run' } else { 'patch' }
        throw "$commandLabel failed with exit code $($result.ExitCode).`n$($result.StdErr)"
    }
}

if ($CheckOnly.IsPresent) {
    if (-not $UsePatchUtility.IsPresent -and (Test-GitAvailable)) {
        Invoke-GitApplyCheck -PatchFile $patchFile -RepositoryRoot $repoRoot -AllowWhitespaceFixes:$AllowWhitespaceFixes.IsPresent
    }
    else {
        Write-Verbose 'Performing validation with the patch utility (no modifications will be made).'
        Invoke-PatchUtility -PatchFile $patchFile -RepositoryRoot $repoRoot -StripCount $StripComponents -DryRun
    }

    Write-Verbose 'Patch validation succeeded (check only).'
    return
}

if ($PSCmdlet.ShouldProcess($repoRoot, "Apply patch '$patchFile'")) {
    if (-not $UsePatchUtility.IsPresent -and (Test-GitAvailable)) {
        Invoke-GitApplyCheck -PatchFile $patchFile -RepositoryRoot $repoRoot -AllowWhitespaceFixes:$AllowWhitespaceFixes.IsPresent
        Invoke-GitApply -PatchFile $patchFile -RepositoryRoot $repoRoot -AllowWhitespaceFixes:$AllowWhitespaceFixes.IsPresent
    }
    else {
        Write-Verbose 'Falling back to the POSIX patch utility.'
        Invoke-PatchUtility -PatchFile $patchFile -RepositoryRoot $repoRoot -StripCount $StripComponents -DryRun
        Invoke-PatchUtility -PatchFile $patchFile -RepositoryRoot $repoRoot -StripCount $StripComponents
    }

    Write-Verbose "Patch '$patchFile' applied successfully to '$repoRoot'."
}
