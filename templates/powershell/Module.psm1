<#!
    PowerShell module template aligned with AIUOKEEP guardrails.
    - Enables StrictMode and error trapping
    - Exposes public functions explicitly via Export-ModuleMember
    - Provides module initialization hook
!>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Module Initialization
function Initialize-Module {
    [CmdletBinding()]
    param()

    Write-Verbose -Message 'Initializing module template'
    # TODO: Load configuration, establish connections, or validate prerequisites.
}
#endregion

#region Public Functions
. $PSScriptRoot/AdvancedFunction.ps1
#endregion

Initialize-Module

Export-ModuleMember -Function @(
    'Invoke-TemplateFunction'
)
