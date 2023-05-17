function Import-FunctionToHereString {
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
    [string]$Function
  )
#TODO: Remove comments from imported function
#TODO: Remove blank lines from imported function
#TODO: Trim CR/LF/Whitespace in front of { or } from imported function

Begin {
  }

  Process {
    $ScriptText = @'
'@
    $ScriptText += ("Function $($(Get-Command $($Function)).Name) {")
    $ScriptText += (((Get-Command $Function).Definition))
    $ScriptText += ("}`r`n")
    $ScriptText
  }

  End {
  }

}
