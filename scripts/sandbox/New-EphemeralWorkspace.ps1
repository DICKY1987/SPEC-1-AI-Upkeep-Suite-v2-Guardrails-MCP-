<#
.SYNOPSIS
    Creates a git worktree backed ephemeral workspace for isolated validation.

.DESCRIPTION
    Provisions a clean git worktree rooted under the repository's `.sandboxes`
    directory. The workspace is suitable for running destructive validation
    tasks (formatting, linting, patch application) without affecting the main
    working tree. Metadata about the workspace is captured in
    `.aiuokeep_workspace.json` to aid automation.

.PARAMETER RepositoryRoot
    Path to the git repository. When omitted, the script attempts to discover
    the root using `git rev-parse --show-toplevel` from the current directory.

.PARAMETER Ref
    Commit-ish used to seed the workspace. Defaults to `HEAD`.

.PARAMETER Name
    Optional friendly name for the workspace directory. When not supplied a
    timestamped name is generated.

.PARAMETER Branch
    Optional branch name to create for the workspace. When provided the new
    worktree is attached to the branch instead of a detached HEAD.

.PARAMETER Force
    Allows reuse of an existing workspace directory by removing it prior to
    creation. Also passes `--force` to `git worktree add`.

.EXAMPLE
    .\New-EphemeralWorkspace.ps1 -Ref origin/main -Name validation

    Creates `.sandboxes/validation` from the `origin/main` ref and outputs the
    workspace metadata object.
#>
Set-StrictMode -Version Latest

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$RepositoryRoot,

    [string]$Ref = 'HEAD',

    [string]$Name,

    [string]$Branch,

    [switch]$Force
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
    $utf8Encoding = if ($PSVersionTable.PSVersion.Major -ge 6) { 'utf8NoBOM' } else { 'utf8' }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git must be available in PATH to create an ephemeral workspace.'
    }

    if (-not $RepositoryRoot) {
        $output = Invoke-Git -Arguments @('rev-parse', '--show-toplevel') -WorkingDirectory (Get-Location).Path
        $RepositoryRoot = $output[0]
    }

    $RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot -ErrorAction Stop).Path
    $repoItem = Get-Item -LiteralPath $RepositoryRoot -ErrorAction Stop
    if (-not (Test-Path -LiteralPath (Join-Path $repoItem.FullName '.git'))) {
        throw "'$RepositoryRoot' does not appear to be a git repository."
    }

    if (-not $Name) {
        $Name = 'workspace_{0:yyyyMMdd_HHmmss}' -f (Get-Date)
    }

    $invalidChars = [IO.Path]::GetInvalidFileNameChars()
    if ($Name.IndexOfAny($invalidChars) -ge 0) {
        throw "Workspace name '$Name' contains invalid characters."
    }

    $sandboxRoot = Join-Path -Path $repoItem.FullName -ChildPath '.sandboxes'
    if (-not (Test-Path -LiteralPath $sandboxRoot)) {
        $null = New-Item -ItemType Directory -Path $sandboxRoot -Force
    }

    $workspacePath = Join-Path -Path $sandboxRoot -ChildPath $Name

    if (Test-Path -LiteralPath $workspacePath) {
        if (-not $Force) {
            throw "Workspace '$workspacePath' already exists. Use -Force to replace it."
        }

        try {
            Invoke-Git -Arguments @('worktree', 'remove', '--force', $workspacePath) -WorkingDirectory $repoItem.FullName | Out-Null
        } catch {
            Write-Warning "Failed to deregister existing worktree for '$workspacePath': $($_.Exception.Message)"
        }

        Remove-Item -LiteralPath $workspacePath -Recurse -Force -ErrorAction SilentlyContinue
    }

    $worktreeArgs = @('worktree', 'add')
    if ($Force) { $worktreeArgs += '--force' }

    if ($Branch) {
        $worktreeArgs += @('-b', $Branch)
    } else {
        $worktreeArgs += '--detach'
    }

    $Ref = $Ref.Trim()
    $worktreeArgs += @($workspacePath, $Ref)
    Invoke-Git -Arguments $worktreeArgs -WorkingDirectory $repoItem.FullName | Out-Null

    $metadata = [PSCustomObject]@{
        RepositoryRoot = $repoItem.FullName
        WorkspacePath  = $workspacePath
        Ref            = $Ref
        Branch         = if ($Branch) { $Branch } else { $null }
        CreatedAtUtc   = [DateTime]::UtcNow
    }

    $metadataFile = Join-Path -Path $workspacePath -ChildPath '.aiuokeep_workspace.json'
    $metadata | ConvertTo-Json -Depth 5 | Set-Content -Path $metadataFile -Encoding $utf8Encoding

    Write-Verbose "Created workspace at '$workspacePath' targeting ref '$Ref'."
    $script:WorkspaceMetadata = $metadata
}

end {
    $WorkspaceMetadata
}
