<#
.SYNOPSIS
    Launches a Windows Sandbox session with networking disabled for safe validation.

.DESCRIPTION
    Generates a transient Windows Sandbox (.wsb) configuration that disables networking,
    optionally maps a host workspace directory, and executes a provided PowerShell command
    on startup. The sandbox is ideal for evaluating untrusted code changes or running the
    SafePatch pipeline without exposing corporate networks.

    The script requires Windows 10/11 Professional or Enterprise with the Windows Sandbox
    feature enabled.

.PARAMETER Command
    PowerShell command (or script path) to execute automatically when the sandbox starts.

.PARAMETER WorkspacePath
    Optional host directory to expose inside the sandbox. If omitted, a new temporary
    directory is created and mapped read/write to the sandbox.

.PARAMETER ReadOnly
    When provided, the mapped workspace is exposed as read-only inside the sandbox.

.PARAMETER SandboxFolder
    Destination path inside the sandbox where the workspace is mounted. Defaults to
    'C:\workspace'.

.PARAMETER KeepWorkspace
    Prevents deletion of a temporary workspace directory created by this script.

.PARAMETER Launch
    When specified, the sandbox is launched immediately after the configuration file is
    created. Otherwise, the path to the .wsb file is returned for manual execution.

.EXAMPLE
    .\sandbox_windows.ps1 -Command "Invoke-SafePatchValidation" -Launch

    Creates a temporary workspace, generates a sandbox configuration, and launches the
    sandbox with networking disabled.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$WorkspacePath,

    [switch]$ReadOnly,

    [string]$SandboxFolder = 'C:\workspace',

    [switch]$KeepWorkspace,

    [switch]$Launch
)

begin {
    if (-not $IsWindows) {
        throw "sandbox_windows.ps1 can only be executed on Windows hosts."
    }

    $sandboxExecutable = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsSandbox.exe'
    if (-not (Test-Path -LiteralPath $sandboxExecutable)) {
        throw 'Windows Sandbox is not installed. Enable the feature via "Turn Windows features on or off".'
    }

    $utf8Encoding = if ($PSVersionTable.PSVersion.Major -ge 6) { 'utf8NoBOM' } else { 'utf8' }

    if (-not $PSBoundParameters.ContainsKey('WorkspacePath')) {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'AIUOKEEP'
        if (-not (Test-Path -LiteralPath $tempRoot)) {
            $null = New-Item -ItemType Directory -Path $tempRoot -Force
        }

        $WorkspacePath = New-Item -ItemType Directory -Path (Join-Path $tempRoot ([System.IO.Path]::GetRandomFileName())) -Force
    }

    $workspaceItem = Get-Item -LiteralPath $WorkspacePath -ErrorAction Stop
    if (-not $workspaceItem.PSIsContainer) {
        throw "WorkspacePath '$WorkspacePath' is not a directory."
    }

    if (-not $workspaceItem.Attributes.HasFlag([IO.FileAttributes]::Directory)) {
        throw "WorkspacePath '$WorkspacePath' must be a directory."
    }

    if (-not (Test-Path -LiteralPath $workspaceItem.FullName -PathType Container)) {
        throw "Workspace directory '$WorkspacePath' could not be resolved."
    }

    $createdWorkspace = -not $PSBoundParameters.ContainsKey('WorkspacePath')
    if ($createdWorkspace -and -not $KeepWorkspace) {
        Write-Verbose "Created temporary workspace at '$WorkspacePath'."
    }

    $logonCommand = "PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Set-ExecutionPolicy Bypass -Scope Process -Force; Set-Location -Path '$SandboxFolder'; $Command`""
    $escapedCommand = [System.Security.SecurityElement]::Escape($logonCommand)
    $escapedHostFolder = [System.Security.SecurityElement]::Escape($workspaceItem.FullName)
    $escapedSandboxFolder = [System.Security.SecurityElement]::Escape($SandboxFolder)

    $readOnlyValue = if ($ReadOnly) { 'true' } else { 'false' }

    $configuration = @"
<Configuration>
  <VGpu>Disable</VGpu>
  <Networking>Disable</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$escapedHostFolder</HostFolder>
      <SandboxFolder>$escapedSandboxFolder</SandboxFolder>
      <ReadOnly>$readOnlyValue</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>$escapedCommand</Command>
  </LogonCommand>
</Configuration>
"@

    $configPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("aiuokeep_sandbox_{0}.wsb" -f ([System.Guid]::NewGuid()))
    $configuration | Set-Content -Path $configPath -Encoding $utf8Encoding

    $result = [PSCustomObject]@{
        ConfigurationPath = $configPath
        WorkspacePath     = $workspaceItem.FullName
        SandboxFolder     = $SandboxFolder
        Networking        = 'Disabled'
        ReadOnly          = [bool]$ReadOnly
    }

    if ($Launch) {
        Write-Verbose "Launching Windows Sandbox with configuration '$configPath'."
        $process = Start-Process -FilePath $sandboxExecutable -ArgumentList @($configPath) -PassThru
        $result | Add-Member -MemberType NoteProperty -Name ProcessId -Value $process.Id
    }

    $script:SandboxResult = $result
}

end {
    if ($SandboxResult) {
        $SandboxResult
    }

    if ($createdWorkspace -and -not $KeepWorkspace) {
        Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PSEngineEvent]::Exiting) -MessageData $WorkspacePath -Action {
            param($sender, $eventArgs)
            $workspace = $event.MessageData
            try {
                Remove-Item -LiteralPath $workspace -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Warning "Failed to clean temporary workspace '$workspace': $($_.Exception.Message)"
            }
        } | Out-Null
    }
}
