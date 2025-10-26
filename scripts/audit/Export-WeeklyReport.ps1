<#!
.SYNOPSIS
    Generates a time-boxed observability report from the run ledger.

.DESCRIPTION
    Export-WeeklyReport.ps1 aggregates validation runs captured in the ledger
    and produces a JSON report summarising pass/fail trends, signature health,
    per-check performance, and recent failures. The command defaults to the last
    seven days of activity but can be pointed at any custom window.

.PARAMETER LedgerPath
    Path to the JSONL ledger created by New-RunLedgerEntry.ps1.

.PARAMETER OutputPath
    Destination path for the generated JSON report. Parent directories are
    created automatically.

.PARAMETER WindowStart
    Optional start of the reporting window. When omitted the window begins
    RollingDays in the past relative to WindowEnd.

.PARAMETER WindowEnd
    Optional end of the reporting window. Defaults to the current UTC timestamp.

.PARAMETER RollingDays
    Number of days in the rolling window when WindowStart is not specified.
    Defaults to 7.

.PARAMETER SigningKeyPath
    Path to the signing key used for ledger entries. Providing a key enables
    signature verification during report generation.

.PARAMETER SigningKey
    SecureString version of the signing key. Mutually exclusive with
    SigningKeyPath.

.EXAMPLE
    ./Export-WeeklyReport.ps1 -LedgerPath ./artifacts/run-ledger.jsonl `
        -OutputPath ./artifacts/reports/weekly.json -RollingDays 14

.NOTES
    Author: AI Upkeep Suite - Stream H
    PowerShell 5.1 or later is required.
#>
[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$LedgerPath,

    [Parameter(Mandatory, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [datetime]$WindowStart,

    [datetime]$WindowEnd,

    [ValidateRange(1, 90)]
    [int]$RollingDays = 7,

    [Parameter(ParameterSetName = 'Path')]
    [ValidateNotNullOrEmpty()]
    [string]$SigningKeyPath,

    [Parameter(ParameterSetName = 'Key')]
    [System.Security.SecureString]$SigningKey
)

if ($PSCmdlet.ParameterSetName -eq 'Path' -and $SigningKey) {
    throw 'Provide either SigningKeyPath or SigningKey, not both.'
}

$resolvedLedger = Resolve-Path -Path $LedgerPath -ErrorAction SilentlyContinue
if (-not $resolvedLedger) {
    throw "Ledger not found: $LedgerPath"
}

if (-not $WindowEnd) {
    $WindowEnd = (Get-Date).ToUniversalTime()
}
else {
    $WindowEnd = $WindowEnd.ToUniversalTime()
}

if (-not $WindowStart) {
    $WindowStart = $WindowEnd.AddDays(-1 * $RollingDays)
}
else {
    $WindowStart = $WindowStart.ToUniversalTime()
}

if ($WindowStart -ge $WindowEnd) {
    throw 'WindowStart must be earlier than WindowEnd.'
}

$readerScript = Join-Path -Path $PSScriptRoot -ChildPath 'Get-RunLedger.ps1'
$readerParams = @{ LedgerPath = $resolvedLedger.Path }
if ($SigningKeyPath) {
    $readerParams['SigningKeyPath'] = $SigningKeyPath
}
elseif ($SigningKey) {
    $readerParams['SigningKey'] = $SigningKey
}

$ledgerEntries = & $readerScript @readerParams

$filteredEntries = $ledgerEntries | Where-Object { $_.Timestamp -ge $WindowStart -and $_.Timestamp -lt $WindowEnd }

$totalRuns = ($filteredEntries | Measure-Object).Count
$passedRuns = ($filteredEntries | Where-Object { $_.Result -eq 'pass' } | Measure-Object).Count
$failedRuns = ($filteredEntries | Where-Object { $_.Result -eq 'fail' } | Measure-Object).Count
$passRate = if ($totalRuns -gt 0) { [math]::Round(($passedRuns / $totalRuns) * 100, 2) } else { 0 }

$signatureCounts = @{
    valid                   = 0
    invalid                 = 0
    missing                 = 0
    'present-not-validated' = 0
    'not-validated'         = 0
    'unsupported-algorithm' = 0
}
foreach ($entry in $filteredEntries) {
    $status = $entry.SignatureStatus
    if (-not $signatureCounts.ContainsKey($status)) {
        $signatureCounts[$status] = 0
    }
    $signatureCounts[$status]++
}

$checkAggregates = @{}
foreach ($entry in $filteredEntries) {
    foreach ($check in $entry.Entry.checks) {
        $name = [string]$check.name
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        if (-not $checkAggregates.ContainsKey($name)) {
            $checkAggregates[$name] = [ordered]@{
                total          = 0
                passed         = 0
                failed         = 0
                skipped        = 0
                durationValues = New-Object System.Collections.Generic.List[double]
                lastFailure    = $null
            }
        }

        $aggregate = $checkAggregates[$name]
        $aggregate.total++

        $status = [string]$check.status
        switch ($status.ToLowerInvariant()) {
            'pass' { $aggregate.passed++ }
            'fail' { $aggregate.failed++; $aggregate.lastFailure = $entry.Timestamp }
            'skipped' { $aggregate.skipped++ }
            default { }
        }

        if ($check.PSObject.Properties.Match('durationMs').Count -gt 0 -and $check.durationMs -ne $null) {
            try {
                $duration = [double]$check.durationMs
                if ($duration -ge 0) {
                    $aggregate.durationValues.Add($duration) | Out-Null
                }
            }
            catch {
                Write-Verbose "Ignoring non-numeric duration for check '$name': $($_.Exception.Message)"
            }
        }
    }
}

$checkSummary = @()
foreach ($key in ($checkAggregates.Keys | Sort-Object)) {
    $data = $checkAggregates[$key]
    $average = 0
    $p95 = 0
    if ($data.durationValues.Count -gt 0) {
        $sortedDurations = @($data.durationValues.ToArray() | Sort-Object)
        $average = [Math]::Round((@($sortedDurations) | Measure-Object -Average).Average, 2)
        $index = [int][Math]::Ceiling(0.95 * $sortedDurations.Count) - 1
        if ($index -lt 0) { $index = 0 }
        if ($index -ge $sortedDurations.Count) { $index = $sortedDurations.Count - 1 }
        $p95 = [Math]::Round($sortedDurations[$index], 2)
    }

    $checkSummary += ,([pscustomobject]@{
        name             = $key
        totalRuns        = $data.total
        passed           = $data.passed
        failed           = $data.failed
        skipped          = $data.skipped
        passRatePercent  = if ($data.total -gt 0) { [Math]::Round(($data.passed / $data.total) * 100, 2) } else { 0 }
        averageDurationMs = $average
        p95DurationMs     = $p95
        lastFailureUtc    = if ($data.lastFailure) { $data.lastFailure.ToString('o') } else { $null }
    })
}

$dailyBreakdown = @()
$groupedByDay = $filteredEntries | Group-Object { $_.Timestamp.Date } | Sort-Object Name
foreach ($group in $groupedByDay) {
    $dayPass = ($group.Group | Where-Object { $_.Result -eq 'pass' } | Measure-Object).Count
    $dayFail = ($group.Group | Where-Object { $_.Result -eq 'fail' } | Measure-Object).Count
    $dailyBreakdown += ,([pscustomobject]@{
        dateUtc      = ([datetime]$group.Name).ToString('yyyy-MM-dd')
        totalRuns    = $group.Count
        passed       = $dayPass
        failed       = $dayFail
        passRatePercent = if ($group.Count -gt 0) { [Math]::Round(($dayPass / $group.Count) * 100, 2) } else { 0 }
    })
}

$recentFailures = $filteredEntries |
    Where-Object { $_.Result -eq 'fail' } |
    Sort-Object -Property Timestamp -Descending |
    Select-Object -First 5 |
    ForEach-Object {
        [pscustomobject]@{
            timestampUtc = $_.Timestamp.ToString('o')
            runId        = if ($_.Entry.metadata -and $_.Entry.metadata.runId) { $_.Entry.metadata.runId } else { $null }
            signature    = $_.SignatureStatus
            failingChecks = (@($_.Entry.checks | Where-Object { $_.status -eq 'fail' } | ForEach-Object { $_.name }))
        }
    }

$report = [ordered]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    window = [ordered]@{
        startUtc = $WindowStart.ToString('o')
        endUtc   = $WindowEnd.ToString('o')
        days     = [Math]::Round(($WindowEnd - $WindowStart).TotalDays, 2)
    }
    totals = [ordered]@{
        runs        = $totalRuns
        passed      = $passedRuns
        failed      = $failedRuns
        passRatePct = $passRate
    }
    signatureHealth = ($signatureCounts.GetEnumerator() | Sort-Object Key | ForEach-Object {
        [pscustomobject]@{ status = $_.Key; count = $_.Value }
    })
    checks = $checkSummary
    daily = $dailyBreakdown
    recentFailures = $recentFailures
}

$reportJson = $report | ConvertTo-Json -Depth 64

$outputDirectory = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($OutputPath))
if (-not [string]::IsNullOrWhiteSpace($outputDirectory) -and -not (Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$reportJson | Set-Content -Path $OutputPath -Encoding UTF8
