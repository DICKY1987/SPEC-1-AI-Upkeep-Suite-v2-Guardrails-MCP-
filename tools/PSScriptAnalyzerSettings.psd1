@{
    IncludeDefaultRules = $true
    Rules = @{
        PSAvoidUsingWriteHost = @{ Enable = $true }
        PSAvoidUsingCmdletAliases = @{ Enable = $true }
    }
}
