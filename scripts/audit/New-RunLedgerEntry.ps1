[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LedgerPath,
    [Parameter(Mandatory)]
    [hashtable]$Entry
)

$Entry.timestamp = (Get-Date).ToUniversalTime().ToString('o')
$line = ($Entry | ConvertTo-Json -Depth 6)
Add-Content -Path $LedgerPath -Value $line
