function New-McpConfigurationObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Desired,
        [Parameter(Mandatory)]
        [psobject]$Current
    )

    return [pscustomobject]@{
        Servers      = $Desired.Servers
        AccessGroups = $Desired.AccessGroups
        Version      = $Desired.Version
        LastUpdated  = (Get-Date).ToUniversalTime().ToString('o')
    }
}
Export-ModuleMember -Function New-McpConfigurationObject
