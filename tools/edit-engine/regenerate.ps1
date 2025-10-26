#Requires -Version 5.1
<#!
.SYNOPSIS
    Regenerates a file from a template by performing token substitution with validated inputs.

.DESCRIPTION
    Loads a template file, replaces all placeholders of the form {{TokenName}} with values supplied
    via a hashtable, and writes the result to the specified destination. Missing tokens raise an
    error to prevent partially rendered outputs. The script creates destination directories as
    needed and respects existing files unless -Force is supplied.

.PARAMETER Template
    Path to the template file containing token placeholders.

.PARAMETER Destination
    Path where the rendered file will be written.

.PARAMETER Parameters
    Hashtable of token values keyed by token name.

.PARAMETER Force
    Overwrites the destination file if it already exists.

.PARAMETER Encoding
    Output encoding (utf8, utf8NoBom, utf16, ascii). Defaults to utf8NoBom.

.PARAMETER PassThru
    Returns the rendered content to the pipeline after writing the file.

.EXAMPLE
    .\regenerate.ps1 -Template templates\module.txt -Destination out\module.ps1 -Parameters @{ Name = 'Module' }

.NOTES
    Part of the AI Upkeep Suite v2 Edit Engine.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Template,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Destination,

    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [hashtable]$Parameters,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [ValidateSet('utf8', 'utf8NoBom', 'utf16', 'ascii')]
    [string]$Encoding = 'utf8NoBom',

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
        throw "Template file '$Path' was not found."
    }

    return (Get-Item -LiteralPath $resolved -Force)
}

function Get-EncodingObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    switch ($Name) {
        'utf8' { return New-Object System.Text.UTF8Encoding($true) }
        'utf8NoBom' { return New-Object System.Text.UTF8Encoding($false) }
        'utf16' { return [System.Text.Encoding]::Unicode }
        'ascii' { return [System.Text.Encoding]::ASCII }
        default { throw "Unsupported encoding '$Name'." }
    }
}

$templateFile = Resolve-ExistingFile -Path $Template

if ([System.IO.Path]::IsPathRooted($Destination)) {
    $destinationFullPath = [System.IO.Path]::GetFullPath($Destination)
}
else {
    $destinationFullPath = [System.IO.Path]::GetFullPath((Join-Path -Path (Get-Location).Path -ChildPath $Destination))
}

$destinationDir = [System.IO.Path]::GetDirectoryName($destinationFullPath)
if (-not [string]::IsNullOrEmpty($destinationDir) -and -not (Test-Path -LiteralPath $destinationDir -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $destinationDir -Force)
}

if ((Test-Path -LiteralPath $destinationFullPath -PathType Leaf) -and -not $Force.IsPresent) {
    throw "Destination file '$Destination' already exists. Use -Force to overwrite."
}

$templateContent = Get-Content -LiteralPath $templateFile.FullName -Raw
$tokenPattern = [regex]'{{\s*([A-Za-z0-9_.-]+)\s*}}'

$missingTokens = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$rendered = $tokenPattern.Replace($templateContent, {
        param($match)
        $token = $match.Groups[1].Value
        if (-not $Parameters.ContainsKey($token)) {
            $missingTokens.Add($token) | Out-Null
            return $match.Value
        }
        $value = $Parameters[$token]
        if ($null -eq $value) {
            return ''
        }
        return [string]$value
    })

if ($missingTokens.Count -gt 0) {
    $missingList = $missingTokens -join ', '
    throw "Template rendering failed. Missing values for token(s): $missingList"
}

$encodingObj = Get-EncodingObject -Name $Encoding

if ($PSCmdlet.ShouldProcess($destinationFullPath, 'Write regenerated file')) {
    [System.IO.File]::WriteAllText($destinationFullPath, $rendered, $encodingObj)
}

if ($PassThru.IsPresent) {
    return $rendered
}
