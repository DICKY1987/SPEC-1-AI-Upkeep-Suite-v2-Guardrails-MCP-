#Requires -Version 5.1
<#!
.SYNOPSIS
    Runs Comby structural search-and-replace operations in a controlled manner.

.DESCRIPTION
    Invokes the Comby CLI with deterministic settings, supporting dry-run previews and optional
    file filtering. The script validates parameters, ensures that the Comby binary is available,
    and surfaces detailed errors when transformations fail.

.PARAMETER Match
    The Comby match pattern.

.PARAMETER Rewrite
    The Comby rewrite pattern that replaces matches.

.PARAMETER TargetPath
    File or directory to process. Directories are processed recursively unless -NoRecursive is
    specified via the FileFilter parameter.

.PARAMETER Matcher
    Comby matcher to use (defaults to '.generic').

.PARAMETER Include
    Optional glob pattern passed to Comby's -include flag to limit files processed when operating
    on a directory.

.PARAMETER DryRun
    Emits the transformed output without modifying files.

.PARAMETER CombyPath
    Path to the comby executable. Defaults to 'comby' assuming it is available on PATH.

.PARAMETER TimeoutSeconds
    Maximum number of seconds to allow Comby to execute before aborting.

.EXAMPLE
    .\run_comby.ps1 -Match 'foo' -Rewrite 'bar' -TargetPath src -Include '*.ts'

.NOTES
    Part of the AI Upkeep Suite v2 Edit Engine.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Match,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Rewrite,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Matcher = '.generic',

    [Parameter()]
    [string]$Include,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [string]$CombyPath = 'comby',

    [Parameter()]
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ExistingPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    return (Get-Item -LiteralPath $resolved -Force)
}

function Invoke-ExternalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter()]
        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds
    )

    Write-Verbose "Executing: $FilePath $($ArgumentList -join ' ')"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    foreach ($arg in $ArgumentList) {
        [void]$psi.ArgumentList.Add($arg)
    }

    $process = [System.Diagnostics.Process]::Start($psi)
    try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try {
                $process.Kill()
            }
            catch {
                Write-Warning "Failed to terminate process $FilePath after timeout."
            }
            throw "Command '$FilePath' exceeded the timeout of $TimeoutSeconds seconds."
        }

        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut   = $stdout
            StdErr   = $stderr
        }
    }
    finally {
        $process.Dispose()
    }
}

$comby = Get-Command -Name $CombyPath -ErrorAction SilentlyContinue
if (-not $comby) {
    throw "Comby executable '$CombyPath' was not found. Install Comby or provide the full path using -CombyPath."
}

$targetItem = Resolve-ExistingPath -Path $TargetPath
$arguments = @($Match, $Rewrite)

if ($targetItem.PSIsContainer) {
    $arguments += '-matcher'
    $arguments += $Matcher
    $arguments += '-d'
    $arguments += $targetItem.FullName
    if ($Include) {
        $arguments += '-include'
        $arguments += $Include
    }
}
else {
    $arguments += $targetItem.FullName
    $arguments += '-matcher'
    $arguments += $Matcher
}

if (-not $DryRun.IsPresent) {
    $arguments += '-in-place'
}

if ($PSCmdlet.ShouldProcess($targetItem.FullName, 'Run Comby transformation')) {
    $result = Invoke-ExternalCommand -FilePath $comby.Source -ArgumentList $arguments -WorkingDirectory (Get-Location).Path -TimeoutSeconds $TimeoutSeconds
    if ($result.StdOut) {
        Write-Verbose $result.StdOut.TrimEnd()
    }
    if ($result.StdErr) {
        Write-Verbose $result.StdErr.TrimEnd()
    }

    if ($result.ExitCode -ne 0) {
        throw "Comby exited with code $($result.ExitCode).`n$($result.StdErr)"
    }

    if ($DryRun.IsPresent -and $result.StdOut) {
        Write-Output $result.StdOut
    }
}
