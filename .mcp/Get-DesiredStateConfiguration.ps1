function Get-DesiredStateConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationPath,
        [Parameter(Mandatory)]
        [string]$AccessGroupsPath
    )

    if (-not (Test-Path $ConfigurationPath)) {
        throw "Configuration file not found: $ConfigurationPath"
    }

    if (-not (Test-Path $AccessGroupsPath)) {
        throw "Access groups file not found: $AccessGroupsPath"
    }

    $servers = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
    $groups = Get-Content -Path $AccessGroupsPath -Raw | ConvertFrom-Json

    return [pscustomobject]@{
        Servers      = $servers.servers
        AccessGroups = $groups.groups
        Version      = $servers.version
    }
}
Export-ModuleMember -Function Get-DesiredStateConfiguration
