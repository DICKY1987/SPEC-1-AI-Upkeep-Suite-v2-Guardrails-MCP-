<#
.SYNOPSIS
    Removes a git worktree created for ephemeral validation.

.DESCRIPTION
    Deregisters a git worktree and deletes the associated directory. This is
    the counterpart to `New-EphemeralWorkspace.ps1` and ensures temporary
    sandboxes do not accumulate on developer machines or CI agents.

.PARAMETER WorkspacePath
    Path to the worktree that should be removed.

.PARAMETER RepositoryRoot
    Optional path to the git repository that owns the worktree. When omitted
    the script resolves the root from the worktree itself.

.PARAMETER Force
    Forces removal even if the worktree contains uncommitted changes.

.PARAMETER Prune
    Invokes `git worktree prune` after removal to clean stale metadata.

.EXAMPLE
    .\Remove-EphemeralWorkspace.ps1 -WorkspacePath .\.sandboxes\workspace_20240101_120000 -Force -Prune
#>
Set-StrictMode -Version Latest

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$WorkspacePath,

    [string]$RepositoryRoot,

    [switch]$Force,

    [switch]$Prune
)

function Invoke-Git {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$WorkingDirectory
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    foreach ($arg in $Arguments) {
        [void]$psi.ArgumentList.Add($arg)
    }
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($psi)
    try {
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    } finally {
        $process.Dispose()
    }

    if ($exitCode -ne 0) {
        throw "git command failed (exit $exitCode): $stderr"
    }

    return ($stdout.TrimEnd(), $stderr.TrimEnd())
}

begin {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git must be available in PATH to remove an ephemeral workspace.'
    }

    $WorkspacePath = (Resolve-Path -LiteralPath $WorkspacePath -ErrorAction Stop).Path

    if (-not $RepositoryRoot) {
        $output = Invoke-Git -Arguments @('-C', $WorkspacePath, 'rev-parse', '--show-toplevel') -WorkingDirectory $WorkspacePath
        $RepositoryRoot = $output[0]
    }

    $RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot '.git'))) {
        throw "'$RepositoryRoot' does not appear to be a git repository."
    }

    if (-not (Test-Path -LiteralPath $WorkspacePath)) {
        Write-Warning "Workspace '$WorkspacePath' does not exist."
        return
    }

    $porcelain = Invoke-Git -Arguments @('worktree', 'list', '--porcelain') -WorkingDirectory $RepositoryRoot
    $isRegistered = $false
    foreach ($line in $porcelain[0] -split "`n") {
        if ($line -like 'worktree *') {
            $path = $line.Substring(9)
            if ([string]::Equals($path, $WorkspacePath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $isRegistered = $true
                break
            }
        }
    }

    if (-not $isRegistered) {
        Write-Warning "Workspace '$WorkspacePath' is not registered with git. Proceeding with filesystem cleanup only."
    }

    $removeArgs = @('worktree', 'remove')
    if ($Force) { $removeArgs += '--force' }
    $removeArgs += $WorkspacePath

    if ($PSCmdlet.ShouldProcess($WorkspacePath, 'Remove git worktree')) {
        if ($isRegistered) {
            try {
                Invoke-Git -Arguments $removeArgs -WorkingDirectory $RepositoryRoot | Out-Null
            } catch {
                if (-not $Force) {
                    throw
                }
                Write-Warning "git worktree remove reported an error but will continue removing files: $($_.Exception.Message)"
            }
        }

        if (Test-Path -LiteralPath $WorkspacePath) {
            Remove-Item -LiteralPath $WorkspacePath -Recurse -Force -ErrorAction Stop
        }

        if ($Prune) {
            Invoke-Git -Arguments @('worktree', 'prune') -WorkingDirectory $RepositoryRoot | Out-Null
        }

        Write-Verbose "Removed workspace '$WorkspacePath'."
    }
}
