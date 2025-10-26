[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [string]$SecretScanner = 'gitleaks',

    [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$commonModule = Join-Path $PSScriptRoot 'Validation.Common.psm1'
Import-Module -Name $commonModule -Force

$repoRoot = Resolve-WorkspacePath -Workspace $Workspace

if (-not $ConfigPath) {
    $defaultConfig = Join-Path (Join-Path $repoRoot 'tools') 'gitleaks.toml'
    if (Test-Path -LiteralPath $defaultConfig) {
        $ConfigPath = $defaultConfig
    }
}

$arguments = @('detect', '--source', $repoRoot, '--no-banner', '--redact', '--exit-code', '1')
if ($ConfigPath) {
    $resolvedConfig = Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop
    $arguments += @('--config', $resolvedConfig.ProviderPath)
}

$exitCode = Invoke-ExternalTool -Tool $SecretScanner -Arguments $arguments -WorkingDirectory $repoRoot -AllowedExitCodes @(0, 1)
if ($exitCode -eq 1) {
    throw 'Secret scan detected potential credential exposure. Review the gitleaks report for details.'
}

Write-Verbose 'Secret scan completed successfully.'
