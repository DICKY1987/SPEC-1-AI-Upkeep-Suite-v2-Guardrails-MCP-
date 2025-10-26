<#!
.SYNOPSIS
    Creates a cryptographically signed ledger entry for a validation run.

.DESCRIPTION
    New-RunLedgerEntry.ps1 appends a JSON Lines (JSONL) entry to the run ledger that
    captures the end-to-end status of a validation pipeline execution. The script
    normalises check results, validates the entry against the ledger schema, and
    optionally signs the payload using an HMAC-SHA256 key stored on disk or
    provided as a secure string. The resulting ledger enables downstream
    observability tooling to reconstruct historical runs with integrity
    guarantees.

.PARAMETER LedgerPath
    Absolute or relative path to the JSONL ledger file. The parent directory is
    created automatically when it does not already exist.

.PARAMETER Result
    High-level outcome for the run. Allowed values are `pass` and `fail`.

.PARAMETER Checks
    Collection of check dictionaries describing the individual validation
    stages. Each item must expose at minimum a `name` and `status` property.
    Optional properties such as `tool`, `durationMs`, `details`, and
    `evidencePath` are preserved in the ledger.

.PARAMETER Metadata
    Optional hashtable of additional metadata (for example run identifiers,
    commit SHAs, or triggering user). Keys are normalised alphabetically before
    signing to ensure deterministic hashing.

.PARAMETER SigningKeyPath
    Path to a UTF-8 encoded text file containing the shared secret used for
    HMAC-SHA256 signing. The key should be at least 32 characters to ensure
    sufficient entropy.

.PARAMETER SigningKey
    SecureString containing the signing secret. This parameter cannot be used
    together with SigningKeyPath.

.PARAMETER Passthrough
    When specified, the normalised ledger entry object is written to the
    pipeline after it has been persisted.

.EXAMPLE
    $checks = @(
        @{ name = 'PSScriptAnalyzer'; status = 'pass'; durationMs = 1423 },
        @{ name = 'Pester'; status = 'pass'; durationMs = 2890 }
    )

    ./New-RunLedgerEntry.ps1 -LedgerPath ./artifacts/run-ledger.jsonl -Result pass `
        -Checks $checks -Metadata @{ branch = 'main'; commit = 'abc1234' } `
        -SigningKeyPath ~/.config/aiuokeep/hmac.key -Verbose -Passthrough

.NOTES
    Author: AI Upkeep Suite - Stream H
    The script requires PowerShell 5.1 or later. Signing support depends on
    System.Security.Cryptography.HMACSHA256 being available.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$LedgerPath,

    [Parameter(Mandatory, Position = 1)]
    [ValidateSet('pass', 'fail')]
    [string]$Result,

    [Parameter(Mandatory, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [object[]]$Checks,

    [Parameter()]
    [hashtable]$Metadata,

    [Parameter(ParameterSetName = 'Path')]
    [ValidateNotNullOrEmpty()]
    [string]$SigningKeyPath,

    [Parameter(ParameterSetName = 'Key')]
    [System.Security.SecureString]$SigningKey,

    [switch]$Passthrough
)

function ConvertTo-NormalisedObject {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in ($Value.Keys | Sort-Object)) {
            $ordered[$key] = ConvertTo-NormalisedObject -Value $Value[$key]
        }
        return $ordered
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $normalisedList = @()
        foreach ($item in $Value) {
            $normalisedList += ,(ConvertTo-NormalisedObject -Value $item)
        }
        return $normalisedList
    }

    return $Value
}

function ConvertTo-CanonicalJson {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )

    $normalised = ConvertTo-NormalisedObject -Value $InputObject
    return (ConvertTo-Json -InputObject $normalised -Depth 32 -Compress)
}

function Get-SigningKeyBytes {
    param(
        [string]$Path,
        [System.Security.SecureString]$SecureKey
    )

    if ($Path) {
        try {
            $raw = Get-Content -Path $Path -Raw -ErrorAction Stop
        }
        catch {
            throw "Unable to read signing key from '$Path': $($_.Exception.Message)"
        }
    }
    elseif ($SecureKey) {
        $raw = [System.Net.NetworkCredential]::new([string]::Empty, $SecureKey).Password
    }
    else {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw 'Signing key cannot be empty.'
    }

    $trimmed = $raw.Trim()
    if ($trimmed.Length -lt 32) {
        throw 'Signing key must be at least 32 characters long for adequate entropy.'
    }

    return [System.Text.Encoding]::UTF8.GetBytes($trimmed)
}

function ConvertTo-SignatureString {
    param(
        [Parameter(Mandatory)]
        [datetime]$Timestamp,

        [Parameter(Mandatory)]
        [ValidateSet('pass', 'fail')]
        [string]$Outcome,

        [Parameter(Mandatory)]
        [object[]]$CheckItems,

        [hashtable]$MetadataPayload
    )

    $checksForSignature = $CheckItems | ForEach-Object {
        $checkMap = @{}
        foreach ($property in $_.PSObject.Properties) {
            $checkMap[$property.Name] = $property.Value
        }

        $name = $checkMap['name']
        $status = $checkMap['status']
        $duration = if ($checkMap.ContainsKey('durationMs')) { $checkMap['durationMs'] } else { '' }
        $tool = if ($checkMap.ContainsKey('tool')) { $checkMap['tool'] } else { '' }
        $detailsHash = if ($checkMap.ContainsKey('details')) {
            ConvertTo-CanonicalJson -InputObject $checkMap['details']
        }
        else {
            ''
        }
        '{0}|{1}|{2}|{3}|{4}' -f $name, $status, $duration, $tool, $detailsHash
    }

    $metadataHash = if ($MetadataPayload) {
        ConvertTo-CanonicalJson -InputObject $MetadataPayload
    }
    else {
        ''
    }

    return '{0}|{1}|{2}|{3}' -f $Timestamp.ToString('o'), $Outcome, ($checksForSignature -join ';'), $metadataHash
}

if ($PSBoundParameters.ContainsKey('SigningKeyPath') -and $PSBoundParameters.ContainsKey('SigningKey')) {
    throw 'Provide either SigningKeyPath or SigningKey, not both.'
}

$resolvedLedgerPath = Resolve-Path -Path $LedgerPath -ErrorAction SilentlyContinue
if (-not $resolvedLedgerPath) {
    $resolvedLedgerPath = [System.IO.Path]::GetFullPath($LedgerPath)
}
else {
    $resolvedLedgerPath = $resolvedLedgerPath.Path
}

$ledgerDirectory = [System.IO.Path]::GetDirectoryName($resolvedLedgerPath)
if (-not [string]::IsNullOrWhiteSpace($ledgerDirectory) -and -not (Test-Path -Path $ledgerDirectory)) {
    New-Item -ItemType Directory -Path $ledgerDirectory -Force | Out-Null
}

$timestamp = (Get-Date).ToUniversalTime()

$normalisedChecks = @()
foreach ($rawCheck in $Checks) {
    if (-not $rawCheck) {
        throw 'Check entries cannot be null.'
    }

    $dictionary = if ($rawCheck -is [System.Collections.IDictionary]) {
        $rawCheck
    }
    else {
        $map = @{}
        foreach ($property in $rawCheck.PSObject.Properties) {
            $map[$property.Name] = $property.Value
        }
        $map
    }

    if (-not $dictionary.ContainsKey('name') -or [string]::IsNullOrWhiteSpace([string]$dictionary['name'])) {
        throw 'Each check must include a non-empty "name" property.'
    }
    if (-not $dictionary.ContainsKey('status') -or [string]::IsNullOrWhiteSpace([string]$dictionary['status'])) {
        throw "Check '$($dictionary['name'])' is missing a non-empty status property."
    }

    $checkRecord = [ordered]@{
        name   = [string]$dictionary['name']
        status = [string]$dictionary['status']
    }

    if ($dictionary.ContainsKey('tool') -and -not [string]::IsNullOrWhiteSpace([string]$dictionary['tool'])) {
        $checkRecord['tool'] = [string]$dictionary['tool']
    }
    if ($dictionary.ContainsKey('durationMs') -and $dictionary['durationMs'] -ne $null) {
        try {
            $durationValue = [double]$dictionary['durationMs']
            if ($durationValue -lt 0) {
                throw 'Duration cannot be negative.'
            }
            $checkRecord['durationMs'] = [Math]::Round($durationValue, 3)
        }
        catch {
            throw "Check '$($dictionary['name'])' has an invalid durationMs value: $($_.Exception.Message)"
        }
    }
    if ($dictionary.ContainsKey('details') -and $dictionary['details'] -ne $null) {
        $checkRecord['details'] = $dictionary['details']
    }
    if ($dictionary.ContainsKey('evidencePath') -and -not [string]::IsNullOrWhiteSpace([string]$dictionary['evidencePath'])) {
        $checkRecord['evidencePath'] = [string]$dictionary['evidencePath']
    }
    if ($dictionary.ContainsKey('notes') -and $dictionary['notes']) {
        $checkRecord['notes'] = $dictionary['notes']
    }

    $normalisedChecks += ,([pscustomobject]$checkRecord)
}

if (-not $normalisedChecks) {
    throw 'At least one check result must be supplied.'
}

$metadataBlock = $Metadata
if ($metadataBlock -and $metadataBlock -isnot [System.Collections.IDictionary]) {
    $converted = @{}
    foreach ($property in $metadataBlock.PSObject.Properties) {
        $converted[$property.Name] = $property.Value
    }
    $metadataBlock = $converted
}

if (-not $metadataBlock) {
    $metadataBlock = @{}
}

if (-not $metadataBlock.ContainsKey('runId') -or [string]::IsNullOrWhiteSpace([string]$metadataBlock['runId'])) {
    $metadataBlock['runId'] = [guid]::NewGuid().ToString()
}

if (-not $metadataBlock.ContainsKey('generatedBy') -or [string]::IsNullOrWhiteSpace([string]$metadataBlock['generatedBy'])) {
    $candidate = $env:USERNAME
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = $env:USER
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = 'unknown'
    }
    $metadataBlock['generatedBy'] = $candidate
}

if (-not $metadataBlock.ContainsKey('schemaVersion')) {
    $metadataBlock['schemaVersion'] = '1.0'
}

$entry = [ordered]@{
    version   = '1.0'
    timestamp = $timestamp.ToString('o')
    result    = $Result
    checks    = $normalisedChecks
    metadata  = $metadataBlock
}

$schemaPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath '..'
$schemaPath = Join-Path -Path (Resolve-Path -Path $schemaPath).Path -ChildPath 'schemas/ledger.schema.json'

$entryJson = ConvertTo-Json -InputObject $entry -Depth 64
if (-not (Test-Json -Json $entryJson -SchemaFile $schemaPath)) {
    throw 'Generated ledger entry failed schema validation.'
}

$signingKeyBytes = Get-SigningKeyBytes -Path $SigningKeyPath -SecureKey $SigningKey
if ($signingKeyBytes) {
    $sortedChecks = $normalisedChecks | Sort-Object -Property name
    $signaturePayload = ConvertTo-SignatureString -Timestamp $timestamp -Outcome $Result -CheckItems $sortedChecks -MetadataPayload $metadataBlock
    $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($signaturePayload)
    $hmac = [System.Security.Cryptography.HMACSHA256]::new($signingKeyBytes)
    try {
        $signatureBytes = $hmac.ComputeHash($payloadBytes)
    }
    finally {
        $hmac.Dispose()
    }
    $entry['signature'] = 'hmacsha256:' + ([Convert]::ToBase64String($signatureBytes))
}

$entryJsonLine = ConvertTo-Json -InputObject $entry -Depth 64 -Compress

if ($PSCmdlet.ShouldProcess($resolvedLedgerPath, 'Append new ledger entry')) {
    [System.IO.File]::AppendAllText($resolvedLedgerPath, $entryJsonLine + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
}

if ($Passthrough.IsPresent) {
    $entry | ConvertTo-Json -Depth 32 | ConvertFrom-Json
}
