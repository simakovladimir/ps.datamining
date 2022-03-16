#! /usr/bin/env pwsh

<#
.NAME
  Get-UriAttrib
.SYNOPSIS
  A toolbox for extracting various attributes from URI contents
.SYNTAX
  Get-UriAttrib
    [-Uris] <String[]>
    [-Attrib] {abstract($Tag, $Script, $Prop) | canonical | title}
    [-Format <String>]
    [-Progress]
    [<CommonParameters>]
.DESCRIPTION
  For  each $Uri in $Uris array, Get-UriAttrib retrieves its HTML code
  and  extracts  appropriate $Value corresponding to specified $Attrib
  parameter (see below). Next, according to the $Format specification,
  a  new  string  is  being  generated  which  is then appended to the
  current pipeline. $Format represents a raw string typically combined
  of  '$Uri'  and  '$Value' keywords (by default, '$Value <<< $Uri' is
  assumed).  Please  note  that  you may put into $Format any variable
  locally  available  within  execution context, including these self-
  explained  counters  declared  for maintaining verbose output during
  main loop: $Index, $Count, $Percent. Internal low-level $Html object
  (containig  parsed  HTML  code) is also availble, however, it is not
  recommended   for   explicit  usage.  Optional  $Progress  parameter
  specifies  whether a progress bar will be displayed. Finally, common
  cmdlet parameters (such as $Verbose switch) are also applicable
  Supported $Attrib items:
    (*) abstract($Tag, $Script, $Prop):  custom macro definition which
      enables processing the most generic HTML query. Specifically, it
      retrieves the first appearance of the $Prop attribute located in
      $Tag  for which a $Script (a string with conditional expression)
      applies. All other $Attrib patterns are based on this construct.
      Please note that all quoted strings as arguments MUST be escaped
    (*) canonical: canonical URL counterpart for the given $Uri (if it
      can be located within the HTML contents);
    (*) title: title of the HTML page
.INPUTS
  String[]. $Uris may be piped into the cmdlet to be processed
.OUTPUTS
  String[]. Result is piped to stdout for further redirection
.EXAMPLE
  PS> Get-UriAttrib.ps1
  ### This  will  import  the script into current PS session (the same
  ### command line arguments applicable as to the eponymous function)
  PS> $Uris = Get-Content -Path .\INPUT.TXT
  PS> $Result = Get-UriAttrib -Uris $Uris -Attrib title
  PS> Set-Content -Value $Results -Encoding UTF8 -Path .\OUTPUT.TXT
  ### This  will  load  the list of URIs from an input file into $Uris
  ### variable,  execute Get-UriAttrib configured for title extraction
  ### and save output into both variable $Result and .\OUTPUT.TXT file
.LINK
  About_CommonParameters
.NOTES
  License: MIT

Copyright 2017 Vladimir Simakov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.

TODO:
  
****: DOCUMENT DEPENDENCIES!!! minimal PoweShell version
 
****: DOCUMENT EXPORTED ALIAS
 
DONE: end {} section: turn back modified Parameter variables ($ProgressPreference) >>> Return result of cmdlet in the end {} section (FULL array, not a single $Value)
 
DONE: Put parsing abstract / canonical / title into begin {} section; put parameter validation to select_abstract
 
DONE: Create cmdlet-local (not global) variable with expanded abstract() arguments as an array
 
DONE: Invert $Args.Length logic in "main" section
 
DONE: Replace globally Where / Select / ForEach with Where-Object / Select-Object / ForEach-Object
 
****: ADD to .DESCRIPTION >>> abstract $Attrib MUST be enquoted with aux characters escaped
 
#>

function Get-UriAttrib {
  [CmdletBinding(PositionalBinding = $False)]
  Param(
    [Parameter(
      Mandatory = $True,
      ValueFromPipeline = $True,
      Position = 0)]
    [ValidateNotNullOrEmpty()]
    [String[]]
    $Uris,
    [Parameter(
      Mandatory = $True,
      Position = 1)]
    [ValidateScript({
      $_.Trim() -Like "abstract(*)" -Or
      $_.Trim() -In "canonical", "title"
    })]
    [String]
    $Attrib,
    [Parameter(Mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Format = '$Value <<< $Uri',
    [Parameter(Mandatory = $False)]
    [Switch]
    $Progress)
  begin {
    [Int] $Count = $Uris.Length
    [Int] $Index = 0
    [Int] $Percent = 0
    [String] $OldProgressPreference = $ProgressPreference
    [String[]] $CmdLine = @()
    [String[]] $Result = @()
    if($Progress.IsPresent) {
      $ProgressPreference = "Continue"
    }
    else {
      $ProgressPreference = "SilentlyContinue"
    }
    switch -WildCard ($Attrib.Trim()) {
      "abstract(*)" {
        $_ -Match '\(.*\)'
        Invoke-Expression -Command "@$($Matches[0])" |
        Set-Variable -Name CmdLine
        break
      }
      "canonical" {
        @("link", "rel -Eq 'canonical'", "href") |
        Set-Variable -Name CmdLine -Scope 1
        break
      }
      "title" {
        @("title", "tagName -Eq 'TITLE'", "innerText") |
        Set-Variable -Name CmdLine -Scope 1
        break
      }
    }
    function select_abstract {
      Param(
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Tag,
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Script,
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Prop,
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.__ComObject]
        $Html)
      (
        (
          $Html.GetElementsByTagName($Tag) |
          Where-Object `
            -FilterScript [ScriptObject]::Create("`$_.$Script") |
          Select-Object -Property $Prop)[0] |
        Format-Table -HideTableHeaders |
        Out-String).Trim()
    }
  }
  process {
    foreach($Uri in $Uris) {
      $Percent = [Math]::Round(100 * $Index++ / $Count)
      Write-Progress `
        -Activity "Parsing in progress" `
        -Status "$Percent% complete" `
        -PercentComplete $Percent
      Write-Verbose -Message "Processing $Index/$Count"
      [Console]::Out.Flush()
      try {
        $Html = (Invoke-WebRequest -Uri $Uri).ParsedHtml
        $CmdLine += $Html
        $Value = select_abstract @CmdLine
      }
      catch {
        $Value = "n/a"
      }
      $Result += $ExecutionContext.InvokeCommand.ExpandString($Format)
    }
  }
  end {
    $ProgressPreference = $OldProgressPreference
    $Result
  }
}

if($Args.Length -Gt 0) {
  Get-UriAttrib @Args
}
else {
  Set-Alias -Name guatt -Value Get-UriAttrib -Option Constant
}
