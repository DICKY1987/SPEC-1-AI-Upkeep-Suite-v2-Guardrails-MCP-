[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LedgerPath,
    [Parameter(Mandatory)]
    [string]$OutputPath
)

$entries = & (Join-Path $PSScriptRoot 'Get-RunLedger.ps1') -LedgerPath $LedgerPath
$summary = [pscustomobject]@{
    totalRuns = ($entries | Measure-Object).Count
    generated = (Get-Date).ToUniversalTime().ToString('o')
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath -Encoding UTF8
