Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ExcludedDirectories = @(
    '.git',
    '.github',
    '.mypy_cache',
    '.pytest_cache',
    '.ruff_cache',
    '.tox',
    '.venv',
    '.idea',
    '.vscode',
    'build',
    'coverage',
    'dist',
    'node_modules',
    'out',
    'tmp',
    '__pycache__'
)

function Resolve-WorkspacePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Workspace
    )

    if ([string]::IsNullOrWhiteSpace($Workspace)) {
        throw 'Workspace path cannot be empty.'
    }

    $resolved = Resolve-Path -LiteralPath $Workspace -ErrorAction Stop
    return $resolved.ProviderPath
}

function Test-IsExcludedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $normalized = $Path -replace '\\', '/'
    foreach ($exclude in $script:ExcludedDirectories) {
        $pattern = "/$([regex]::Escape($exclude))(?:/|$)"
        if ($normalized -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-WorkspaceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Workspace,

        [string[]]$Extensions
    )

    $root = Resolve-WorkspacePath -Workspace $Workspace
    $files = Get-ChildItem -Path $root -File -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $files) {
        if (Test-IsExcludedPath -Path $file.FullName) {
            continue
        }

        if ($Extensions -and ($Extensions -notcontains $file.Extension.ToLowerInvariant())) {
            continue
        }

        $file
    }
}

function Get-RelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    $resolvedRoot = Resolve-Path -LiteralPath $Root -ErrorAction Stop
    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop

    $rootPath = $resolvedRoot.ProviderPath.TrimEnd([IO.Path]::DirectorySeparatorChar, '/')
    $targetPath = $resolvedPath.ProviderPath

    if ($targetPath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
        $relative = $targetPath.Substring($rootPath.Length)
        return $relative.TrimStart([IO.Path]::DirectorySeparatorChar, '/')
    }

    return $targetPath
}

function Invoke-ExternalTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Tool,

        [string[]]$Arguments = @(),

        [string]$WorkingDirectory,

        [int[]]$AllowedExitCodes = @(0)
    )

    $command = Get-Command -Name $Tool -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required tool '$Tool' was not found in PATH. Install it or update your environment before re-running the validation."
    }

    $resolvedWorkingDirectory = if ($WorkingDirectory) {
        Resolve-WorkspacePath -Workspace $WorkingDirectory
    } else {
        (Get-Location).ProviderPath
    }

    $startProcessParameters = @{
        FilePath         = $command.Source
        ArgumentList     = $Arguments
        WorkingDirectory = $resolvedWorkingDirectory
        Wait             = $true
        PassThru         = $true
    }

    Write-Verbose ("Executing: {0} {1}" -f $command.Source, ($Arguments -join ' '))
    $process = Start-Process @startProcessParameters

    if ($AllowedExitCodes -notcontains $process.ExitCode) {
        throw "Command '$Tool' failed with exit code $($process.ExitCode)."
    }

    return $process.ExitCode
}

Export-ModuleMember -Function Resolve-WorkspacePath, Get-WorkspaceFiles, Get-RelativePath, Invoke-ExternalTool
