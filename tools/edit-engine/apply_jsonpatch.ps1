#Requires -Version 7.0
using namespace System.Text.Json
using namespace System.Text.Json.Nodes
<#!
.SYNOPSIS
    Applies an RFC 6902 JSON Patch document to a JSON file.

.DESCRIPTION
    Loads a JSON document and a JSON Patch specification, validates the operations, and applies
    them deterministically. Supports add, remove, replace, move, copy, and test operations and
    writes the updated document back to disk (or to an alternate destination when specified).

.PARAMETER DocumentPath
    Path to the JSON document that will be modified.

.PARAMETER PatchPath
    Path to the JSON Patch document describing the changes to apply.

.PARAMETER OutputPath
    Optional path where the modified document should be written. Defaults to overwriting the
    input document in-place.

.PARAMETER IndentOutput
    Writes the resulting JSON using indented formatting to improve readability. When omitted,
    the document is written without additional whitespace.

.EXAMPLE
    .\apply_jsonpatch.ps1 -DocumentPath state.json -PatchPath updates.json -Verbose

    Applies the patch defined in `updates.json` to `state.json`.

.NOTES
    Part of the AI Upkeep Suite v2 Edit Engine.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DocumentPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PatchPath,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [switch]$IndentOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ExistingFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "File '$Path' was not found."
    }

    return (Get-Item -LiteralPath $resolved -Force).FullName
}

function Get-JsonNodeFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $content = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        return [JsonNode]::Parse($content, [JsonNodeOptions]@{ PropertyNameCaseInsensitive = $false })
    }
    catch {
        throw "Failed to parse JSON file '$Path': $($_.Exception.Message)"
    }
}

function Get-PointerSegments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pointer
    )

    if ($Pointer -eq '') {
        return @()
    }
    if (-not $Pointer.StartsWith('/')) {
        throw "Invalid JSON Pointer '$Pointer'. Pointers must begin with '/'."
    }

    $raw = $Pointer.Substring(1).Split('/')
    $segments = @()
    foreach ($segment in $raw) {
        $segments += $segment.Replace('~1', '/').Replace('~0', '~')
    }

    return $segments
}

function Resolve-JsonPointer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [JsonNode]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Pointer,

        [Parameter()]
        [switch]$AllowMissingLeaf,

        [Parameter()]
        [switch]$AllowArrayAppendToken
    )

    if ($Pointer -eq '') {
        return [pscustomobject]@{ Node = $Root; Parent = $null; Key = $null; Exists = $true }
    }

    $segments = Get-PointerSegments -Pointer $Pointer
    $current = $Root
    $parent = $null
    $key = $null

    for ($i = 0; $i -lt $segments.Count; $i++) {
        $segment = $segments[$i]
        $isLast = ($i -eq $segments.Count - 1)

        if ($current -is [JsonObject]) {
            if ($current.ContainsKey($segment)) {
                if ($isLast) {
                    return [pscustomobject]@{ Node = $current[$segment]; Parent = $current; Key = $segment; Exists = $true }
                }
                $parent = $current
                $current = $current[$segment]
                continue
            }

            if ($isLast -and $AllowMissingLeaf) {
                return [pscustomobject]@{ Node = $null; Parent = $current; Key = $segment; Exists = $false }
            }

            throw "Property '$segment' was not found in JSON pointer '$Pointer'."
        }

        if ($current -is [JsonArray]) {
            if ($segment -eq '-') {
                if (-not ($AllowArrayAppendToken -and $isLast)) {
                    throw "JSON pointer '$Pointer' uses '-' outside of a supported add context."
                }
                return [pscustomobject]@{ Node = $null; Parent = $current; Key = '-'; Exists = $false }
            }

            $index = 0
            if (-not [int]::TryParse($segment, [ref]$index)) {
                throw "JSON pointer segment '$segment' is not a valid array index."
            }

            if ($isLast) {
                if ($index -ge 0 -and $index -lt $current.Count) {
                    return [pscustomobject]@{ Node = $current[$index]; Parent = $current; Key = $index; Exists = $true }
                }
                if ($AllowMissingLeaf -and $index -eq $current.Count) {
                    return [pscustomobject]@{ Node = $null; Parent = $current; Key = $index; Exists = $false }
                }
                throw "Array index '$index' is out of range for JSON pointer '$Pointer'."
            }

            if ($index -lt 0 -or $index -ge $current.Count) {
                throw "Array index '$index' is out of range for JSON pointer '$Pointer'."
            }

            $parent = $current
            $current = $current[$index]
            continue
        }

        throw "JSON pointer '$Pointer' traversed a primitive value before reaching the target."
    }

    throw "Failed to resolve JSON pointer '$Pointer'."
}

function Clone-Node {
    [CmdletBinding()]
    param(
        [JsonNode]$Node
    )

    if ($null -eq $Node) {
        return $null
    }

    return $Node.DeepClone()
}

function Set-Value {
    [CmdletBinding()]
    param(
        [JsonNode]$Parent,
        $Key,
        [JsonNode]$Value,
        [switch]$Append,
        [switch]$Replace
    )

    if ($Parent -is [JsonObject]) {
        $Parent[$Key] = Clone-Node -Node $Value
        return
    }

    if ($Parent -is [JsonArray]) {
        if ($Append) {
            $Parent.Add(Clone-Node -Node $Value)
            return
        }

        $index = [int]$Key
        if ($Replace) {
            if ($index -lt 0 -or $index -ge $Parent.Count) {
                throw "Array index '$index' is out of range for replacement."
            }
            $Parent[$index] = Clone-Node -Node $Value
            return
        }

        if ($index -lt 0 -or $index -gt $Parent.Count) {
            throw "Array index '$index' is out of range for assignment."
        }

        if ($index -eq $Parent.Count) {
            $Parent.Add(Clone-Node -Node $Value)
        }
        else {
            $Parent.Insert($index, Clone-Node -Node $Value)
        }
        return
    }

    throw 'Unsupported parent node type encountered while assigning a value.'
}

function Remove-Value {
    [CmdletBinding()]
    param(
        [JsonNode]$Parent,
        $Key
    )

    if ($Parent -is [JsonObject]) {
        if (-not $Parent.Remove($Key)) {
            throw "Property '$Key' does not exist and cannot be removed."
        }
        return
    }

    if ($Parent -is [JsonArray]) {
        $index = [int]$Key
        if ($index -lt 0 -or $index -ge $Parent.Count) {
            throw "Array index '$index' is out of range and cannot be removed."
        }
        $Parent.RemoveAt($index)
        return
    }

    throw 'Unsupported parent node type encountered while removing a value.'
}

$documentFile = Resolve-ExistingFile -Path $DocumentPath
$patchFile = Resolve-ExistingFile -Path $PatchPath

$documentNode = Get-JsonNodeFromFile -Path $documentFile
$patchNode = Get-JsonNodeFromFile -Path $patchFile

if (-not ($patchNode -is [JsonArray])) {
    throw 'JSON Patch documents must be arrays of operations.'
}

foreach ($operation in $patchNode) {
    if (-not ($operation -is [JsonObject])) {
        throw 'Each JSON Patch operation must be an object.'
    }

    if (-not $operation.ContainsKey('op')) {
        throw 'JSON Patch operation is missing the "op" property.'
    }

    $op = $operation['op'].GetValue[string]().ToLowerInvariant()
    $path = if ($operation.ContainsKey('path')) { $operation['path'].GetValue[string]() } else { '' }

    switch ($op) {
        'add' {
            if (-not $operation.ContainsKey('value')) {
                throw 'The add operation requires a "value" property.'
            }
            $value = $operation['value']

            if ($path -eq '') {
                $documentNode = Clone-Node -Node $value
                break
            }

            $context = Resolve-JsonPointer -Root $documentNode -Pointer $path -AllowMissingLeaf -AllowArrayAppendToken
            if ($null -eq $context.Parent) {
                throw 'Unable to resolve parent for add operation.'
            }

            if ($context.Parent -is [JsonArray]) {
                if ($context.Key -eq '-') {
                    Set-Value -Parent $context.Parent -Key $context.Parent.Count -Value $value -Append
                }
                else {
                    Set-Value -Parent $context.Parent -Key ([int]$context.Key) -Value $value
                }
            }
            else {
                Set-Value -Parent $context.Parent -Key $context.Key -Value $value
            }
        }
        'remove' {
            if ($path -eq '') {
                throw 'Cannot remove the document root.'
            }
            $context = Resolve-JsonPointer -Root $documentNode -Pointer $path
            if ($null -eq $context.Parent) {
                throw 'Unable to resolve parent for remove operation.'
            }
            Remove-Value -Parent $context.Parent -Key $context.Key
        }
        'replace' {
            if (-not $operation.ContainsKey('value')) {
                throw 'The replace operation requires a "value" property.'
            }
            if ($path -eq '') {
                $documentNode = Clone-Node -Node $operation['value']
                break
            }
            $context = Resolve-JsonPointer -Root $documentNode -Pointer $path
            if ($null -eq $context.Parent) {
                throw 'Unable to resolve parent for replace operation.'
            }
            Set-Value -Parent $context.Parent -Key $context.Key -Value $operation['value'] -Replace
        }
        'move' {
            if (-not $operation.ContainsKey('from')) {
                throw 'The move operation requires a "from" property.'
            }
            $fromPath = $operation['from'].GetValue[string]()
            $fromContext = Resolve-JsonPointer -Root $documentNode -Pointer $fromPath
            if ($null -eq $fromContext.Parent -and $fromPath -ne '') {
                throw 'Unable to resolve source for move operation.'
            }

            if ($fromPath -eq $path) {
                continue
            }

            $valueToMove = Clone-Node -Node $fromContext.Node

            if ($fromPath -eq '') {
                if ($path -ne '') {
                    throw 'Moving the document root to a nested path is not supported.'
                }
            }
            else {
                Remove-Value -Parent $fromContext.Parent -Key $fromContext.Key
            }

            if ($path -eq '') {
                $documentNode = $valueToMove
                break
            }

            $destinationContext = Resolve-JsonPointer -Root $documentNode -Pointer $path -AllowMissingLeaf -AllowArrayAppendToken
            if ($null -eq $destinationContext.Parent) {
                throw 'Unable to resolve destination for move operation.'
            }

            if ($destinationContext.Parent -is [JsonArray]) {
                if ($destinationContext.Key -eq '-') {
                    Set-Value -Parent $destinationContext.Parent -Key $destinationContext.Parent.Count -Value $valueToMove -Append
                }
                else {
                    Set-Value -Parent $destinationContext.Parent -Key ([int]$destinationContext.Key) -Value $valueToMove
                }
            }
            else {
                Set-Value -Parent $destinationContext.Parent -Key $destinationContext.Key -Value $valueToMove
            }
        }
        'copy' {
            if (-not $operation.ContainsKey('from')) {
                throw 'The copy operation requires a "from" property.'
            }
            $fromPath = $operation['from'].GetValue[string]()
            $fromContext = Resolve-JsonPointer -Root $documentNode -Pointer $fromPath
            $valueToCopy = Clone-Node -Node $fromContext.Node

            if ($path -eq '') {
                $documentNode = $valueToCopy
                break
            }

            $destinationContext = Resolve-JsonPointer -Root $documentNode -Pointer $path -AllowMissingLeaf -AllowArrayAppendToken
            if ($null -eq $destinationContext.Parent) {
                throw 'Unable to resolve destination for copy operation.'
            }

            if ($destinationContext.Parent -is [JsonArray]) {
                if ($destinationContext.Key -eq '-') {
                    Set-Value -Parent $destinationContext.Parent -Key $destinationContext.Parent.Count -Value $valueToCopy -Append
                }
                else {
                    Set-Value -Parent $destinationContext.Parent -Key ([int]$destinationContext.Key) -Value $valueToCopy
                }
            }
            else {
                Set-Value -Parent $destinationContext.Parent -Key $destinationContext.Key -Value $valueToCopy
            }
        }
        'test' {
            if (-not $operation.ContainsKey('value')) {
                throw 'The test operation requires a "value" property.'
            }
            $context = Resolve-JsonPointer -Root $documentNode -Pointer $path
            if (-not [JsonNode]::DeepEquals($context.Node, $operation['value'])) {
                throw "JSON Patch test operation failed for path '$path'."
            }
        }
        default {
            throw "Unsupported JSON Patch operation '$op'."
        }
    }
}

$destination = if ($OutputPath) { $OutputPath } else { $documentFile }
$destinationDir = Split-Path -Path $destination -Parent
if ([string]::IsNullOrWhiteSpace($destinationDir)) {
    $destinationDir = Get-Location
}
if (-not (Test-Path -LiteralPath $destinationDir -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $destinationDir -Force)
}

$writeOptions = [JsonSerializerOptions]::new()
$writeOptions.WriteIndented = $IndentOutput.IsPresent

if ($PSCmdlet.ShouldProcess($destination, 'Write patched JSON document')) {
    $json = $documentNode.ToJsonString($writeOptions)
    Set-Content -LiteralPath $destination -Value $json -Encoding utf8NoBom -Force
}
