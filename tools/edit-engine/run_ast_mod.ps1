#Requires -Version 5.1
<#!
.SYNOPSIS
    Executes a deterministic PowerShell AST modification script against one or more files.

.DESCRIPTION
    Loads a provided PowerShell script that implements an AST transformation function (default
    name: Invoke-AstModification) and invokes it for each target file. The script enforces
    StrictMode, validates inputs, and surfaces errors if the expected function is not defined or
    fails during execution.

.PARAMETER ScriptPath
    Path to the PowerShell script that exports the AST modification function.

.PARAMETER TargetPath
    One or more file paths that should be processed by the AST modifier.

.PARAMETER Parameters
    Optional hashtable passed to the AST function for parameterized transformations.

.PARAMETER FunctionName
    Name of the function within the script to invoke. Defaults to Invoke-AstModification.

.PARAMETER PassThru
    Returns the aggregated results produced by each invocation of the AST modification function.

.EXAMPLE
    .\run_ast_mod.ps1 -ScriptPath .\modify.ps1 -TargetPath src\module.ps1 -Verbose

.NOTES
    Part of the AI Upkeep Suite v2 Edit Engine.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ScriptPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$TargetPath,

    [Parameter()]
    [hashtable]$Parameters,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FunctionName = 'Invoke-AstModification',

    [Parameter()]
    [switch]$PassThru
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
        throw "File '$Path' was not found."
    }

    return (Get-Item -LiteralPath $resolved -Force)
}

$scriptFile = Resolve-ExistingFile -Path $ScriptPath

$importBlock = [scriptblock]::Create(". '$($scriptFile.FullName.Replace("'", "''"))'")
& $importBlock

$astCommand = Get-Command -Name $FunctionName -CommandType Function -ErrorAction SilentlyContinue
if (-not $astCommand) {
    throw "Function '$FunctionName' was not found after loading script '$($scriptFile.FullName)'."
}

$results = @()
foreach ($path in $TargetPath) {
    $targetFile = Resolve-ExistingFile -Path $path

    if (-not $PSCmdlet.ShouldProcess($targetFile.FullName, "Invoke $FunctionName")) {
        continue
    }

    $arguments = @{ Path = $targetFile.FullName }
    if ($Parameters) {
        $arguments['Parameters'] = $Parameters
    }

    try {
        $result = & $astCommand @arguments
        if ($PassThru.IsPresent) {
            $results += $result
        }
    }
    catch {
        throw "AST modification failed for '$($targetFile.FullName)': $($_.Exception.Message)"
    }
}

if ($PassThru.IsPresent) {
    return $results
}
