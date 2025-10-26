#requires -Version 5.1
function Get-DesiredStateConfiguration {
    <#
    .SYNOPSIS
    Reads the authoritative MCP configuration definition from JSON and performs validation.

    .DESCRIPTION
    Get-DesiredStateConfiguration loads the MCP server and access group definitions from the
    repository's desired state JSON files. The function validates the documents for structural
    correctness, ensuring every server and access group contains the expected properties and
    that group tool assignments map to available servers. A strongly typed PowerShell object
    describing the desired configuration is returned for downstream orchestration.

    .PARAMETER ConfigurationPath
    Full or relative path to the mcp_servers.json document containing server definitions.

    .PARAMETER AccessGroupsPath
    Full or relative path to the access_groups.json document describing role assignments.

    .OUTPUTS
    PSCustomObject representing the desired configuration state.

    .EXAMPLE
    Get-DesiredStateConfiguration -ConfigurationPath './mcp_servers.json' -AccessGroupsPath './access_groups.json'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AccessGroupsPath
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $resolvedConfigurationPath = Resolve-Path -LiteralPath $ConfigurationPath
    $resolvedAccessGroupsPath = Resolve-Path -LiteralPath $AccessGroupsPath

    $configurationJson = Get-Content -Path $resolvedConfigurationPath -Raw
    if (-not (Test-Json -Json $configurationJson)) {
        throw "Configuration JSON is not valid: $resolvedConfigurationPath"
    }

    $accessGroupsJson = Get-Content -Path $resolvedAccessGroupsPath -Raw
    if (-not (Test-Json -Json $accessGroupsJson)) {
        throw "Access group JSON is not valid: $resolvedAccessGroupsPath"
    }

    $configurationDocument = $configurationJson | ConvertFrom-Json -Depth 10
    $accessGroupsDocument = $accessGroupsJson | ConvertFrom-Json -Depth 10

    if (-not $configurationDocument.servers) {
        throw 'The configuration document must include a "servers" array.'
    }

    $serverNames = @{}
    $serverToolSet = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($server in $configurationDocument.servers) {
        if (-not $server) {
            throw 'Server entries cannot be null.'
        }

        if ([string]::IsNullOrWhiteSpace($server.name)) {
            throw 'Each server entry must define a non-empty "name" property.'
        }

        if ($serverNames.ContainsKey($server.name)) {
            throw "Duplicate server name detected: $($server.name)"
        }

        $serverNames[$server.name] = $true

        if ([string]::IsNullOrWhiteSpace($server.entryPoint)) {
            throw "Server '$($server.name)' must define an entryPoint."
        }

        if (-not $server.tools -or $server.tools.Count -eq 0) {
            throw "Server '$($server.name)' must expose at least one tool."
        }

        foreach ($tool in $server.tools) {
            if ([string]::IsNullOrWhiteSpace($tool)) {
                throw "Server '$($server.name)' defines an empty tool name."
            }

            [void]$serverToolSet.Add($tool.ToString())
        }

        $validPlatforms = 'powershell', 'python', 'node'
        if ($server.platform -and ($server.platform -notin $validPlatforms)) {
            throw "Server '$($server.name)' platform must be one of: $($validPlatforms -join ', ')."
        }
    }

    if (-not $accessGroupsDocument.groups) {
        throw 'The access group document must include a "groups" array.'
    }

    $accessGroupNames = @{}
    foreach ($group in $accessGroupsDocument.groups) {
        if ([string]::IsNullOrWhiteSpace($group.name)) {
            throw 'Each access group must define a non-empty name.'
        }

        if ($accessGroupNames.ContainsKey($group.name)) {
            throw "Duplicate access group detected: $($group.name)"
        }

        $accessGroupNames[$group.name] = $true

        if ($null -eq $group.tools) {
            throw "Access group '$($group.name)' must specify a tools array (may be empty)."
        }

        foreach ($tool in $group.tools) {
            if (-not $serverToolSet.Contains($tool)) {
                throw "Access group '$($group.name)' references unknown tool '$tool'."
            }
        }
    }

    return [pscustomobject]@{
        Version      = if ($configurationDocument.version) { [string]$configurationDocument.version } else { '1.0.0' }
        Servers      = $configurationDocument.servers
        AccessGroups = $accessGroupsDocument.groups
    }
}

Export-ModuleMember -Function Get-DesiredStateConfiguration
