[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LedgerPath
)

if (-not (Test-Path $LedgerPath)) {
    throw "Ledger not found: $LedgerPath"
}

Get-Content -Path $LedgerPath | ForEach-Object { $_ | ConvertFrom-Json }
