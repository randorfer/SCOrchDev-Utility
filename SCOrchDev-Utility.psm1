﻿<#
.SYNOPSIS
    Converts an object into a text-based represenation that can easily be written to logs.

.DESCRIPTION
    Format-ObjectDump takes any object as input and converts it to a text string with the 
    name and value of all properties the object's type information.  If the property parameter
    is supplied, only the listed properties will be included in the output.

.PARAMETER InputObject
    The object to convert to a textual representation.

.PARAMETER Property
    An optional list of property names that should be displayed in the output. 
#>
Function Format-ObjectDump
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $True,ValueFromPipeline = $True)]
        [Object]$InputObject,
        [Parameter(Position = 1, Mandatory = $False)] [string[]] $Property = @('*')
    )
    $typeInfo = $InputObject.GetType() | Out-String
    $objList = $InputObject | `
        Format-List -Property $Property | `
        Out-String

    return "$typeInfo`r`n$objList"
}

<#
.SYNOPSIS
    Converts an input string into a boolean value.

.DESCRIPTION
    $values = @($null, [String]::Empty, "True", "False", 
                "true", "false", "    true    ", "0", 
                "1", "-1", "-2", '2', "string", 'y', 'n'
                'yes', 'no', 't', 'f');
    foreach ($value in $values) 
    {
        Write-Verbose -Message "[$($Value)] Evaluated as [`$$(ConvertTo-Boolean -InputString $value)]" -Verbose
    }                                     

    VERBOSE: [] Evaluated as [$False]
    VERBOSE: [] Evaluated as [$False]
    VERBOSE: [True] Evaluated as [$True]
    VERBOSE: [False] Evaluated as [$False]
    VERBOSE: [true] Evaluated as [$True]
    VERBOSE: [false] Evaluated as [$False]
    VERBOSE: [   true   ] Evaluated as [$True]
    VERBOSE: [0] Evaluated as [$False]
    VERBOSE: [1] Evaluated as [$True]
    VERBOSE: [-1] Evaluated as [$True]
    VERBOSE: [-2] Evaluated as [$True]
    VERBOSE: [2] Evaluated as [$True]
    VERBOSE: [string] Evaluated as [$True]
    VERBOSE: [y] Evaluated as [$True]
    VERBOSE: [n] Evaluated as [$False]
    VERBOSE: [yes] Evaluated as [$True]
    VERBOSE: [no] Evaluated as [$False]
    VERBOSE: [t] Evaluated as [$True]
    VERBOSE: [f] Evaluated as [$False]

.PARAMETER InputString
    The string value to convert
#>
Function ConvertTo-Boolean
{
    [OutputType([string])]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [string]
        $InputString
    )

    if(-not [System.String]::IsNullOrEmpty($InputString))
    {
        $res    = $True
        $success = [bool]::TryParse($InputString,[ref]$res)
        if($success)
        {
            return $res
        }
        else
        {
            $InputString = ([string]$InputString).ToLower()
    
            Switch ($InputString)
            {
                'f'     
                {
                    $False 
                }
                'false' 
                {
                    $False 
                }
                'off'   
                {
                    $False 
                }
                'no'    
                {
                    $False 
                }
                'n'     
                {
                    $False 
                }
                default
                {
                    try
                    {
                        return [bool]([int]$InputString)
                    }
                    catch
                    {
                        return [bool]$InputString
                    }
                }
            }
        }
    }
    else
    {
        return $False
    }
}
<#
.SYNOPSIS
    Given a list of values, returns the first value that is valid according to $FilterScript.

.DESCRIPTION
    Select-FirstValid iterates over each value in the list $Value. Each value is passed to
    $FilterScript as $_. If $FilterScript returns true, the value is considered valid and
    will be returned if no other value has been already. If $FilterScript returns false,
    the value is deemed invalid and the next element in $Value is checked.

    If no elements in $Value are valid, returns $Null.

.PARAMETER Value
    A list of values to check for validity.

.PARAMETER FilterScript
    A script block that determines what values are valid. Elements of $Value can be referenced
    by $_. By default, values are simply converted to Bool.
#>
Function Select-FirstValid
{
    # Don't allow values from the pipeline. The pipeline does weird things with
    # nested arrays.
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory = $False)]
        $FilterScript = {
            $_ -As [Bool] 
        }
    )
    ForEach($_ in $Value)
    {
        If($FilterScript.InvokeWithContext($Null, (Get-Variable -Name '_'), $Null))
        {
            Return $_
        }
    }
    Return $Null
}

<#
.SYNOPSIS
    Returns a dictionary mapping the name of a PowerShell command to the file containing its
    definition.

.DESCRIPTION
    Find-DeclaredCommand searches $Path for .ps1 files. Each .ps1 is tokenized in order to
    determine what functions and workflows are defined in it. This information is used to
    return a dictionary mapping the command name to the file in which it is defined.

.PARAMETER Path
    The path to search for command definitions.
#>
function Find-DeclaredCommand
{
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [String]
        $Path
    )
    $RunbookPaths = Get-ChildItem -Path $Path -Include '*.ps1' -Recurse

    $DeclaredCommandMap = @{}
    foreach ($Path in $RunbookPaths) 
    {
        $Tokens = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Path $Path), [ref] $Null)
        For($i = 0 ; $i -lt $Tokens.Count - 1 ; $i++)
        {
            $Token = $Tokens[$i]
            if($Token.Type -eq 'Keyword' -and $Token.Content -in @('function', 'workflow'))
            {
                Write-Debug -Message "Found command $($NextToken.Content) in $Path of type $($Token.Content)"
                $NextToken = $Tokens[$i+1]
                $DeclaredCommandMap."$($NextToken.Content)" = @{
                    'Path' = $Path
                    'Type' = $Token.Content
                }
            }
        }
    }
    return $DeclaredCommandMap
}

<#
.SYNOPSIS
    A wrapper around [String]::IsNullOrWhiteSpace.

.DESCRIPTION
    Provides a PowerShell function wrapper around [String]::IsNullOrWhiteSpace,
    since PowerShell Workflow will not allow a direct method call.

.PARAMETER String
    The string to pass to [String]::IsNullOrWhiteSpace.
#>
Function Test-IsNullOrWhiteSpace
{
    [OutputType([bool])]
    Param([Parameter(Mandatory = $True, ValueFromPipeline = $True)]
    [AllowNull()]
    $String)
    Return [String]::IsNullOrWhiteSpace($String)
}

<#
.SYNOPSIS
    A wrapper around [String]::IsNullOrEmpty.

.DESCRIPTION
    Provides a PowerShell function wrapper around [String]::IsNullOrEmpty,
    since PowerShell Workflow will not allow a direct method call.

.PARAMETER String
    The string to pass to [String]::IsNullOrEmpty.
#>
Function Test-IsNullOrEmpty
{
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [AllowNull()]
        $String
    )
    Return [String]::IsNullOrEmpty($String)
}
<#
.Synopsis
    Takes a pscustomobject and converts into a IDictionary.
    Translates all membertypes into keys for the IDictionary
    
.Parameter InputObject
    The input pscustomobject object to convert

.Parameter MemberType
    The membertype to change into a key property

.Parameter KeyFilterScript
    A script to run to manipulate the keyname during grouping.
#>
Function ConvertFrom-PSCustomObject
{
    [OutputType([hashtable])] 
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)] 
        $InputObject,

        [Parameter(Mandatory = $False)]
        [System.Management.Automation.PSMemberTypes]
        $MemberType = [System.Management.Automation.PSMemberTypes]::NoteProperty,

        [Parameter(Mandatory = $False)]
        [ScriptBlock] 
        $KeyFilterScript = {
            Param($KeyName) $KeyName 
        }
    ) 
    
    $outputObj = @{}   
    
    foreach($KeyName in ($InputObject | Get-Member -MemberType $MemberType).Name) 
    {
        $KeyName = Invoke-Command $KeyFilterScript -ArgumentList $KeyName
        if(-not (Test-IsNullOrEmpty $KeyName))
        {
            if($outputObj.ContainsKey($KeyName))
            {
                $outputObj += $InputObject."$KeyName"
            }
            else
            {
                $Null = $outputObj.Add($KeyName, $InputObject."$KeyName")
            } 
        }
    } 
    return $outputObj 
} 

<#
.Synopsis
    Converts an object or array of objects into a hashtable
    by grouping them by the target key property
    
.Parameter InputObject
    The object or array of objects to convert

.Parameter KeyName
    The name of the property to group the objects by

.Parameter KeyFilterScript
    A script to run to manipulate the keyname during grouping.
#>
Function ConvertTo-Hashtable
{
    [OutputType([hashtable])]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        $InputObject,

        [Parameter(Mandatory = $True)][string]
        
        $KeyName,
        [Parameter(Mandatory = $False)][ScriptBlock]
        $KeyFilterScript = {
            Param($Key) $Key 
        }
    )
    $outputObj = @{}
    foreach($Object in $InputObject)
    {
        $Key = $Object."$KeyName"
        $Key = Invoke-Command $KeyFilterScript -ArgumentList $Key
        if(-not (Test-IsNullOrEmpty $Key))
        {
            if($outputObj.ContainsKey($Key))
            {
                $outputObj[$Key] += $Object
            }
            else
            {
                $Null = $outputObj.Add($Key, @($Object))
            }
        }
    }
    return $outputObj
}
<#
    .Synopsis
    Updates the local powershell environment path. Sets the target path as a part
    of the environment path if it does not already exist there
    
    .Parameter Path
    The path to add to the system environment variable 'path'. Only adds if it is not already there            
#>
Function Add-PSEnvironmentPathLocation
{
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        $Path
    )
    
    $CurrentPSModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath')
    if($CurrentPSModulePath.ToLower().Contains($Path.ToLower()))
    {
        Write-Verbose -Message "The path [$Path] was not in the environment path [$CurrentPSModulePath]. Adding."
        [Environment]::SetEnvironmentVariable( 'PSModulePath', "$CurrentPSModulePath;$Path", [System.EnvironmentVariableTarget]::Machine )
    }
}
<#
    .Synopsis
        Looks for the tag workflow in a file and returns the next string
    
    .Parameter FilePath
        The path to the file to search
#>
Function Get-WorkflowNameFromFile
{
    Param([Parameter(Mandatory=$true)][string] $FilePath)

    $DeclaredCommands = Find-DeclaredCommand -Path $FilePath
    Foreach($Command in $DeclaredCommands.Keys)
    {
        if($DeclaredCommands.$Command.Type -eq 'Workflow') 
        { 
            return $Command -as [string]
        }
    }
    $FileContent = Get-Content $FilePath
    Throw-Exception -Type 'WorkflowNameNotFound' `
                        -Message 'Could not find the workflow tag and corresponding workflow name' `
                        -Property @{ 'FileContent' = "$FileContent" }
}
Export-ModuleMember -Function * -Verbose:$False -Debug:$False