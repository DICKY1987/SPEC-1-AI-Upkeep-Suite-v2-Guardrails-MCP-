#requires -Version 5.1
function Set-McpConfiguration {
    <#
    .SYNOPSIS
    Persists the supplied MCP configuration object to disk.

    .DESCRIPTION
    Set-McpConfiguration writes the provided MCP configuration to a JSON state file. The
    function ensures the destination directory exists and produces verbose output describing
    the write operation. A byte-order-mark free UTF8 encoding is used for compatibility with
    cross-platform tooling.

    .PARAMETER Configuration
    The configuration object returned by New-McpConfigurationObject.

    .PARAMETER OutputPath
    Optional path to the destination JSON state file. Defaults to mcp_state.json alongside
    the script.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [psobject]$Configuration,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath = (Join-Path $PSScriptRoot 'mcp_state.json')
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $outputDirectory)) {
        [void](New-Item -ItemType Directory -Path $outputDirectory -Force)
    }

    $json = $Configuration | ConvertTo-Json -Depth 10

    if ($PSCmdlet.ShouldProcess($OutputPath, 'Persist MCP configuration state')) {
        $utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
        [System.IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)
        Write-Verbose "MCP configuration written to $OutputPath"
    }
}

Export-ModuleMember -Function Set-McpConfiguration
