param(
    [string[]]$Args
)

Write-Output (
    [pscustomobject]@{
        server = 'powershell-quality'
        status = 'stub'
        message = 'Implement PSScriptAnalyzer and Pester MCP interface here.'
    } | ConvertTo-Json -Depth 4
)
