#requires -Version 5.1
function Test-McpEnvironment {
    <#
    .SYNOPSIS
    Validates that the MCP configuration is healthy and executable on the current host.

    .DESCRIPTION
    Test-McpEnvironment inspects the merged MCP configuration to ensure all referenced
    entry points exist, required tool definitions are present, and group/tool relationships
    are consistent. Additional checks confirm that scripts have the appropriate file
    extensions for their declared platform. The function throws terminating errors when
    issues are detected, allowing callers to halt orchestration early.

    .PARAMETER Configuration
    The MCP configuration object produced by New-McpConfigurationObject.

    .PARAMETER RepositoryRoot
    Optional path to the repository root. Defaults to the parent directory of the .mcp folder.

    .OUTPUTS
    Returns $true when validation succeeds.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$Configuration,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $resolvedRepositoryRoot = Resolve-Path -LiteralPath $RepositoryRoot

    $validExtensions = @{
        powershell = '.ps1'
        python     = '.py'
        node       = '.js'
    }

    $serverTools = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($server in $Configuration.Servers) {
        if ([string]::IsNullOrWhiteSpace($server.name)) {
            throw 'Server entries must include a name.'
        }

        Write-Verbose "Validating MCP server '$($server.name)'"

        $entryPointPath = Join-Path -Path $resolvedRepositoryRoot -ChildPath $server.entryPoint
        if (-not (Test-Path -LiteralPath $entryPointPath)) {
            throw "Entry point not found for server '$($server.name)': $entryPointPath"
        }

        $expectedExtension = $validExtensions[$server.platform]
        if ($expectedExtension -and ([System.IO.Path]::GetExtension($entryPointPath) -ne $expectedExtension)) {
            throw "Server '$($server.name)' entry point extension does not match platform '$($server.platform)'."
        }

        if (-not $server.tools -or $server.tools.Count -eq 0) {
            throw "Server '$($server.name)' must expose at least one tool."
        }

        foreach ($tool in $server.tools) {
            [void]$serverTools.Add($tool)
        }
    }

    foreach ($group in $Configuration.AccessGroups) {
        if ([string]::IsNullOrWhiteSpace($group.name)) {
            throw 'Access group entries must include a name.'
        }

        Write-Verbose "Checking access group '$($group.name)'"

        if ($null -eq $group.tools) {
            throw "Access group '$($group.name)' must define a tools array (may be empty)."
        }

        foreach ($tool in $group.tools) {
            if (-not $serverTools.Contains($tool)) {
                throw "Access group '$($group.name)' references unknown tool '$tool'."
            }
        }
    }

    Write-Verbose 'MCP environment validation completed successfully.'
    return $true
}

Export-ModuleMember -Function Test-McpEnvironment
