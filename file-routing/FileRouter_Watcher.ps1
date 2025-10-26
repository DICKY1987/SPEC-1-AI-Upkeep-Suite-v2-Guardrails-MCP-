#Requires -Version 5.1
using namespace System.IO
using namespace System.Collections.Generic

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath,

    [Parameter()]
    [switch]$RunOnce
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
trap {
    Write-Error -ErrorRecord $_
    exit 1
}

function Resolve-ConfiguredPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$BasePath,

        [Parameter()]
        [switch]$EnsureExists
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ($expanded.StartsWith('~')) {
        $expanded = Join-Path -Path ([Environment]::GetFolderPath('UserProfile')) -ChildPath $expanded.TrimStart('~', [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    }

    if (-not [IO.Path]::IsPathRooted($expanded)) {
        $expanded = Join-Path -Path $BasePath -ChildPath $expanded
    }

    $fullPath = [IO.Path]::GetFullPath($expanded)

    if ($EnsureExists -and -not (Test-Path -LiteralPath $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    }

    return $fullPath
}

function New-RouterContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    $resolvedConfigPath = Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop
    $configDirectory = Split-Path -Parent $resolvedConfigPath
    $raw = Get-Content -LiteralPath $resolvedConfigPath -Raw -ErrorAction Stop
    $config = $raw | ConvertFrom-Json -Depth 20

    if (-not $config) {
        throw "Configuration at '$resolvedConfigPath' is empty or invalid JSON."
    }

    if (-not $config.schemaVersion) {
        throw "Configuration is missing 'schemaVersion'."
    }

    if (-not $config.routing) {
        throw "Configuration is missing the 'routing' section."
    }

    if (-not $config.watchers) {
        throw "Configuration must define at least one watcher entry."
    }

    $pattern = if ($config.fileNameContract.pattern) {
        [regex]::new($config.fileNameContract.pattern, [System.Text.RegularExpressions.RegexOptions]::Compiled)
    } else {
        throw "Configuration must provide fileNameContract.pattern."
    }

    $allowedExtensions = @()
    if ($config.filters -and $config.filters.allowedExtensions) {
        $allowedExtensions = $config.filters.allowedExtensions | ForEach-Object { $_.ToLowerInvariant() }
    }

    $paths = [ordered]@{
        ConfigPath         = $resolvedConfigPath
        ConfigDirectory    = $configDirectory
        Ledger             = Resolve-ConfiguredPath -Path ($config.logging.ledgerPath) -BasePath $configDirectory -EnsureExists
        Quarantine         = Resolve-ConfiguredPath -Path ($config.defaults.quarantineDirectory) -BasePath $configDirectory -EnsureExists
        Duplicates         = Resolve-ConfiguredPath -Path ($config.defaults.duplicatesDirectory) -BasePath $configDirectory -EnsureExists
        Staging            = Resolve-ConfiguredPath -Path ($config.defaults.stagingDirectory) -BasePath $configDirectory -EnsureExists
    }

    $watchers = @()
    foreach ($watcher in $config.watchers) {
        if (-not $watcher.path) {
            throw "Watcher entry is missing required 'path' property."
        }

        $watchPath = Resolve-ConfiguredPath -Path $watcher.path -BasePath $configDirectory
        if (-not (Test-Path -LiteralPath $watchPath)) {
            throw "Configured watch path '$watchPath' does not exist."
        }

        $watchers += [pscustomobject]@{
            Name                    = if ($watcher.name) { $watcher.name } else { $watchPath }
            Path                    = $watchPath
            Filter                  = if ($watcher.filter) { $watcher.filter } else { '*.*' }
            IncludeSubdirectories   = [bool]$watcher.includeSubdirectories
            ProcessExistingOnStart  = [bool]$watcher.processExistingOnStart
        }
    }

    $ledgerMutex = [System.Threading.Mutex]::new($false)

    return [pscustomobject]@{
        Config           = $config
        Pattern          = $pattern
        AllowedExtensions = $allowedExtensions
        Paths            = $paths
        Watchers         = $watchers
        LedgerMutex      = $ledgerMutex
    }
}

function Write-RouterLedgerEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Context,

        [Parameter(Mandatory)]
        [ValidateSet('Routed','DuplicateContent','Conflicted','Quarantined','Error')]
        [string]$EventType,

        [Parameter()]
        [hashtable]$Metadata,

        [Parameter()]
        [string]$SourcePath,

        [Parameter()]
        [string]$DestinationPath,

        [Parameter()]
        [string]$Hash,

        [Parameter()]
        [string]$Message
    )

    $entry = [ordered]@{
        timestampUtc  = [DateTime]::UtcNow.ToString('o')
        configVersion = $Context.Config.schemaVersion
        eventType     = $EventType
        sourcePath    = $SourcePath
        destinationPath = $DestinationPath
        hash          = $Hash
        metadata      = $Metadata
        message       = $Message
    }

    $json = $entry | ConvertTo-Json -Depth 8

    $mutex = $Context.LedgerMutex
    $taken = $false
    try {
        $taken = $mutex.WaitOne([TimeSpan]::FromSeconds(5))
        if (-not $taken) {
            throw "Unable to acquire ledger mutex for writing."
        }

        Add-Content -LiteralPath $Context.Paths.Ledger -Value $json -Encoding UTF8
    }
    finally {
        if ($taken) {
            $mutex.ReleaseMutex() | Out-Null
        }
    }
}

function Resolve-RouterDestination {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Context,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter(Mandatory)]
        [string]$Area,

        [Parameter(Mandatory)]
        [string]$Subfolder
    )

    $projectConfig = $Context.Config.routing | Where-Object { $_.project -eq $Project }
    if (-not $projectConfig) {
        return [pscustomobject]@{ Status = 'UnknownProject'; Destination = $null }
    }

    $projectRoot = Resolve-ConfiguredPath -Path $projectConfig.root -BasePath $Context.Paths.ConfigDirectory -EnsureExists

    $route = $null
    if ($projectConfig.routes) {
        $route = $projectConfig.routes | Where-Object { $_.area -eq $Area -and $_.subfolder -eq $Subfolder }
    }

    if (-not $route -and $projectConfig.defaults) {
        $route = $projectConfig.routes | Where-Object { $_.area -eq $projectConfig.defaults.area -and $_.subfolder -eq $Subfolder }
        if (-not $route -and $projectConfig.defaults.destination) {
            $route = [pscustomobject]@{ destination = $projectConfig.defaults.destination }
        }
    }

    if (-not $route) {
        return [pscustomobject]@{ Status = 'UnknownRoute'; Destination = $null }
    }

    $destinationRoot = $projectRoot
    $relativePath = $route.destination
    if (-not $relativePath) {
        $relativePath = $projectConfig.defaults.destination
    }

    if (-not $relativePath) {
        return [pscustomobject]@{ Status = 'UnknownRoute'; Destination = $null }
    }

    $destinationPath = Join-Path -Path $destinationRoot -ChildPath $relativePath
    New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null

    return [pscustomobject]@{
        Status = 'Success'
        Destination = [IO.Path]::GetFullPath($destinationPath)
    }
}

function Get-FileMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Context,

        [Parameter(Mandatory)]
        [IO.FileInfo]$File
    )

    $name = $File.Name
    $match = $Context.Pattern.Match($name)
    if (-not $match.Success) {
        return $null
    }

    $metadata = [ordered]@{
        project   = $match.Groups['project'].Value
        area      = $match.Groups['area'].Value
        subfolder = $match.Groups['subfolder'].Value
        name      = $match.Groups['name'].Value
        timestamp = $match.Groups['timestamp'].Value
        version   = $match.Groups['version'].Value
        ulid      = $match.Groups['ulid'].Value
        sha8      = $match.Groups['sha8'].Value
        extension = $match.Groups['extension'].Value
    }

    return $metadata
}

function Test-TimestampValidity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Timestamp,

        [Parameter(Mandatory)]
        [string]$Format
    )

    try {
        [void][DateTime]::ParseExact(
            $Timestamp,
            $Format,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
        )
        return $true
    }
    catch {
        return $false
    }
}

function Wait-ForFileReady {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    for ($i = 0; $i -lt 10; $i++) {
        try {
            $stream = [File]::Open($Path, [FileMode]::Open, [FileAccess]::Read, [FileShare]::Read)
            $stream.Close()
            return
        }
        catch {
            Start-Sleep -Milliseconds 250
        }
    }

    throw "File '$Path' remained locked after multiple attempts."
}

function Resolve-DestinationFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DestinationDirectory,

        [Parameter(Mandatory)]
        [IO.FileInfo]$SourceFile,

        [Parameter(Mandatory)]
        [string]$SourceHash,

        [Parameter(Mandatory)]
        $Context
    )

    $targetPath = Join-Path -Path $DestinationDirectory -ChildPath $SourceFile.Name
    if (-not (Test-Path -LiteralPath $targetPath)) {
        return [pscustomobject]@{
            Path = $targetPath
            EventType = 'Routed'
            ExistingHash = $null
        }
    }

    $existingHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
    if ($existingHash -eq $SourceHash) {
        $duplicatesDir = $Context.Paths.Duplicates
        $duplicatePath = Join-Path -Path $duplicatesDir -ChildPath $SourceFile.Name
        $suffixIndex = 1
        while (Test-Path -LiteralPath $duplicatePath) {
            $duplicatePath = Join-Path -Path $duplicatesDir -ChildPath ("{0}--dup{1}{2}" -f $SourceFile.BaseName, $suffixIndex, $SourceFile.Extension)
            $suffixIndex++
        }

        return [pscustomobject]@{
            Path = $duplicatePath
            EventType = 'DuplicateContent'
            ExistingHash = $existingHash
        }
    }

    $suffixFormat = if ($Context.Config.duplicatePolicy.suffixFormat) { $Context.Config.duplicatePolicy.suffixFormat } else { '--dup{0}' }
    $maxAttempts = if ($Context.Config.duplicatePolicy.maxSuffixAttempts) { [int]$Context.Config.duplicatePolicy.maxSuffixAttempts } else { 10 }
    for ($i = 1; $i -le $maxAttempts; $i++) {
        $candidateName = "{0}{1}{2}" -f $SourceFile.BaseName, ($suffixFormat -f $i), $SourceFile.Extension
        $candidatePath = Join-Path -Path $DestinationDirectory -ChildPath $candidateName
        if (-not (Test-Path -LiteralPath $candidatePath)) {
            return [pscustomobject]@{
                Path = $candidatePath
                EventType = 'Conflicted'
                ExistingHash = $existingHash
            }
        }
    }

    throw "Exceeded maximum duplicate suffix attempts for '$($SourceFile.Name)'."
}

function Move-FileSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter()]
        [switch]$AllowOverwrite
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source path '$Source' does not exist."
    }

    $destinationDirectory = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    $force = if ($AllowOverwrite.IsPresent) { $true } else { $false }

    if ($PSCmdlet.ShouldProcess($Destination, "Move '$Source'")) {
        Move-Item -LiteralPath $Source -Destination $Destination -Force:$force
    }
}

function Quarantine-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Context,

        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$Reason
    )

    $file = Get-Item -LiteralPath $SourcePath -ErrorAction Stop
    $destination = Join-Path -Path $Context.Paths.Quarantine -ChildPath $file.Name
    $suffix = 1
    while (Test-Path -LiteralPath $destination) {
        $destination = Join-Path -Path $Context.Paths.Quarantine -ChildPath ("{0}--{1}{2}" -f $file.BaseName, $suffix, $file.Extension)
        $suffix++
    }

    Move-FileSafe -Source $file.FullName -Destination $destination -AllowOverwrite
    Write-RouterLedgerEntry -Context $Context -EventType 'Quarantined' -Metadata @{ reason = $Reason } -SourcePath $SourcePath -DestinationPath $destination -Message $Reason
}

function Process-RoutedFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Context,

        [Parameter(Mandatory)]
        [string]$FullPath,

        [Parameter()]
        [string]$Trigger
    )

    if (-not (Test-Path -LiteralPath $FullPath)) {
        return
    }

    Wait-ForFileReady -Path $FullPath

    $file = Get-Item -LiteralPath $FullPath -ErrorAction Stop

    if ($Context.AllowedExtensions.Count -gt 0) {
        $extension = $file.Extension.ToLowerInvariant()
        if (-not $Context.AllowedExtensions.Contains($extension)) {
            Quarantine-File -Context $Context -SourcePath $file.FullName -Reason "Extension '$extension' not allowed"
            return
        }
    }

    $metadata = Get-FileMetadata -Context $Context -File $file
    if (-not $metadata) {
        Quarantine-File -Context $Context -SourcePath $file.FullName -Reason 'InvalidName'
        return
    }

    $timestampFormat = $Context.Config.fileNameContract.timestampFormat
    if (-not (Test-TimestampValidity -Timestamp $metadata.timestamp -Format $timestampFormat)) {
        Quarantine-File -Context $Context -SourcePath $file.FullName -Reason 'InvalidTimestamp'
        return
    }

    $hashInfo = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
    if ($hashInfo.Hash.Substring(0, [int]$Context.Config.fileNameContract.checksumLength) -ne $metadata.sha8) {
        Quarantine-File -Context $Context -SourcePath $file.FullName -Reason 'ChecksumMismatch'
        return
    }

    $destinationInfo = Resolve-RouterDestination -Context $Context -Project $metadata.project -Area $metadata.area -Subfolder $metadata.subfolder
    if ($destinationInfo.Status -ne 'Success') {
        Quarantine-File -Context $Context -SourcePath $file.FullName -Reason $destinationInfo.Status
        return
    }

    $destinationFile = Resolve-DestinationFileName -DestinationDirectory $destinationInfo.Destination -SourceFile $file -SourceHash $hashInfo.Hash -Context $Context

    Move-FileSafe -Source $file.FullName -Destination $destinationFile.Path -AllowOverwrite:($destinationFile.EventType -eq 'DuplicateContent')

    $metadata['trigger'] = $Trigger

    Write-RouterLedgerEntry -Context $Context -EventType $destinationFile.EventType -Metadata $metadata -SourcePath $file.FullName -DestinationPath $destinationFile.Path -Hash $hashInfo.Hash -Message $Trigger
}

function Invoke-InitialSweep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Context,

        [Parameter(Mandatory)]
        $WatcherConfig
    )

    Get-ChildItem -LiteralPath $WatcherConfig.Path -Filter $WatcherConfig.Filter -File -Recurse:$WatcherConfig.IncludeSubdirectories |
        Sort-Object -Property LastWriteTime |
        ForEach-Object {
            Process-RoutedFile -Context $Context -FullPath $_.FullName -Trigger 'InitialSweep'
        }
}

function Start-RouterWatcher {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Context,

        [Parameter(Mandatory)]
        $WatcherConfig
    )

    $watcher = [FileSystemWatcher]::new($WatcherConfig.Path, $WatcherConfig.Filter)
    $watcher.IncludeSubdirectories = $WatcherConfig.IncludeSubdirectories
    $watcher.EnableRaisingEvents = $true

    $action = {
        param($sender, $eventArgs)
        $context = $Event.MessageData.Context
        $trigger = $Event.MessageData.Trigger
        try {
            Process-RoutedFile -Context $context -FullPath $eventArgs.FullPath -Trigger $trigger
        }
        catch {
            Write-RouterLedgerEntry -Context $context -EventType 'Error' -Metadata @{ error = $_.Exception.Message } -SourcePath $eventArgs.FullPath -Message $trigger
        }
    }

    $subscriptions = @()
    $subscriptions += Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier "FileRouter.Created.$($WatcherConfig.Name)" -Action $action -MessageData @{ Context = $Context; Trigger = 'Created' }
    $subscriptions += Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier "FileRouter.Renamed.$($WatcherConfig.Name)" -Action $action -MessageData @{ Context = $Context; Trigger = 'Renamed' }

    return [pscustomobject]@{
        Watcher        = $watcher
        Subscriptions  = $subscriptions
    }
}

function Stop-RouterWatcher {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Registration
    )

    foreach ($subscription in $Registration.Subscriptions) {
        Unregister-Event -SourceIdentifier $subscription.SourceIdentifier -ErrorAction SilentlyContinue
        Remove-Event -SourceIdentifier $subscription.SourceIdentifier -ErrorAction SilentlyContinue
    }

    $Registration.Watcher.EnableRaisingEvents = $false
    $Registration.Watcher.Dispose()
}

$routerContext = New-RouterContext -ConfigPath $ConfigPath

$registrations = @()
try {
    foreach ($watcherConfig in $routerContext.Watchers) {
        if ($watcherConfig.ProcessExistingOnStart) {
            Invoke-InitialSweep -Context $routerContext -WatcherConfig $watcherConfig
        }

        if (-not $RunOnce.IsPresent) {
            $registrations += Start-RouterWatcher -Context $routerContext -WatcherConfig $watcherConfig
        }
    }

    if ($RunOnce.IsPresent) {
        return
    }

    $statusMessage = "File router watching {0} location(s). Press Ctrl+C to stop." -f $routerContext.Watchers.Count
    Write-Information -MessageData $statusMessage -InformationAction Continue
    Write-Verbose -Message $statusMessage
    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    foreach ($registration in $registrations) {
        Stop-RouterWatcher -Registration $registration
    }
}
