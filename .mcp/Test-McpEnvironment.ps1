function Test-McpEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Configuration
    )

    foreach ($server in $Configuration.Servers) {
        Write-Verbose "Validating MCP server '$($server.name)'"
        if (-not (Test-Path $server.entryPoint)) {
            throw "Entry point not found: $($server.entryPoint)"
        }
    }

    foreach ($group in $Configuration.AccessGroups) {
        Write-Verbose "Checking access group '$($group.name)'"
        if ($group.tools -eq $null) {
            throw "Access group '$($group.name)' must define tools array"
        }
    }

    Write-Verbose 'MCP environment validation completed successfully.'
    return $true
}
Export-ModuleMember -Function Test-McpEnvironment
