@{
    RootModule        = 'Module.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '00000000-0000-0000-0000-000000000000' # Update with New-Guid before release
    Author            = 'Contoso Automation Team'
    CompanyName       = 'Contoso'
    Copyright         = "(c) $(Get-Date -Format yyyy) Contoso. All rights reserved."
    Description       = 'Template manifest for AIUOKEEP-compliant PowerShell modules.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RequiredModules   = @()
    RequiredAssemblies= @()
    ScriptsToProcess  = @()
    TypesToProcess    = @()
    FormatsToProcess  = @()
    NestedModules     = @()
    FunctionsToExport = @('Invoke-TemplateFunction')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags        = @('Template', 'AIUOKEEP')
            ProjectUri  = 'https://example.com/aiuokeep'
            LicenseUri  = 'https://example.com/license'
        }
    }
}
