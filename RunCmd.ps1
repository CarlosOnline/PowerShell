param (
    [string] $cmdLine = "",
    [string] $cmdLines = @(),
    [string] $subjectName = "RunCmd",
    [string] $smtpServer = "smtp.$Depot.local", #Other addresses: "10.4.2.128","smtp.$Depot.corpnet.local",
    [switch] $noSendEmail,
    #[string] $emailAlias = "",
    [switch] $testMode,
    [switch] $terse,
    [switch] $verbose,

    $lastArg
)
#cls
$global:ErrorActionPreference = "Stop"
$scriptFolder = (Split-Path $MyInvocation.MyCommand.Definition).ToString()
. "$scriptFolder\Utility.ps1"


if ((-not $cmdLine) -and ($cmdLines.Length -eq 0)) {
    throw "Missing command line to run.  Specify -cmdLine or -cmdLines"
}

if ($cmdLines.Length -gt 0) {
    $cmdLines = [array]$cmdLines.Split(",")
} else {
    $cmdLines = @( $cmdLine )
}

$temp = "c:\\temp"
$date = Get-Date -format d
$dateTimeStamp = Get-Date -format MM-dd-yyyy
$outputFolder = ""
if (-not $emailAlias -and "$env:P4USER" -ne "") {
    $emailAlias = "$($env:P4USER)@$Depot.com"
}
if (-not $emailAlias) {
    $emailAlias = "$($env:USERNAME)@$Depot.com"
}

$transcriptFile = "$temp\RunCmd.ps1.$dateTimeStamp.log"
Start-Transcript-Ex $transcriptFile

function main() {
    Verbose ""
    Verbose "Command Line Args ... "
    Verbose ". RunCmd.ps1 ^ "
    foreach($item in $PSBoundParameters.GetEnumerator()) {
        Verbose "    -$($item.Key) $($item.Value) ^"
    }
    Verbose ""

    foreach ($cmdLine in $cmdLines) {
        $exitCode = runExternalProgram "cmd.exe" "/c $cmdLine"
        if ($exitCode -ne 0) {
            Write-Host
            throw "command line failed with exitCode: $exitCode"
        }
    }

    $cmdLinesoutput = [string]::Join("</pre>`n<pre>", $cmdLines)
    $body = "<h2>Commands</h2>`n<pre>$cmdLinesoutput</pre>`n`n"
    SendResultEmail $transcriptFile $body $subjectName
}

try {
    main
} catch {
    Write-Host -foreground Red "Error Ocurred:"
    Write-Host -foreground Red $error[0].ToString()
    Write-Host -foreground Red $error[0].InvocationInfo.PositionMessage
    if (-not $noSendEmail) {
        SendErrorMessage "$subjectName Error" "Failed to run command line"
    }
}


try { Stop-Transcript-Ex } catch {}
Verbose "Log File: $transcriptFile"
