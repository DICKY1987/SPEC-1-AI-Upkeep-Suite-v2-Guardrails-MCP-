Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Module.psm1') -Force

Describe 'Invoke-TemplateFunction' -Tag 'Unit' {
    Context 'When ShouldProcess approves' {
        It 'Processes input objects without throwing' {
            { Invoke-TemplateFunction -InputObject @{ Name = 'Example' } -Verbose:$false } | Should -Not -Throw
        }
    }

    Context 'When ShouldProcess is declined' {
        It 'Skips processing and does not throw' {
            $mockInput = @{ Name = 'Example' }
            Mock ShouldProcess { return $false }

            { Invoke-TemplateFunction -InputObject $mockInput } | Should -Not -Throw
        }
    }
}
