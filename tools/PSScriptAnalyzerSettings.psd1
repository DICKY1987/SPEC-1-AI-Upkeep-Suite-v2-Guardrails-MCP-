@{
    IncludeDefaultRules = $true
    Recurse             = $true

    Severity = @{
        PSAvoidUsingCmdletAliases             = 'Warning'
        PSAvoidUsingWriteHost                 = 'Warning'
        PSUseDeclaredVarsMoreThanAssignments  = 'Error'
        PSUseConsistentIndentation            = 'Error'
        PSMisleadingBacktick                 = 'Error'
    }

    Rules = @{
        PSAvoidLongLines = @{
            Enable            = $true
            MaximumLineLength = 140
        }
        PSAvoidTrailingWhitespace = @{ Enable = $true }
        PSPlaceOpenBrace = @{
            Enable       = $true
            OnSameLine   = $true
            NewLineAfter = $true
        }
        PSPlaceCloseBrace = @{
            Enable             = $true
            NewLineAfter       = $false
            NoEmptyLineBefore  = $true
        }
        PSUseConsistentWhitespace = @{
            Enable                            = $true
            CheckInnerBrace                   = $true
            CheckOperator                     = $true
            CheckOpenBrace                    = $true
            CheckPipe                         = $true
            CheckPipeForRedundantWhitespace   = $true
            CheckSeparator                    = $true
        }
        PSUseConsistentIndentation = @{
            Enable                 = $true
            IndentationSize        = 4
            IndentationType        = 'Space'
            PipelineIndentation    = 'IncreaseIndentationAfterEveryPipeline'
        }
        PSPossibleIncorrectComparisonWithNull = @{ Enable = $true }
        PSPossibleIncorrectUsageOfAssignmentOperator = @{ Enable = $true }
        PSUseBOMForUnicodeEncodedFile = @{ Enable = $true }
        PSUseCompatibleSyntax = @{
            Enable      = $true
            TargetVersions = @('5.1', '7.4')
        }
    }
}
