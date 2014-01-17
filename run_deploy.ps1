# run_deploy.ps1 \\ServerName\C$\$Depot\query\ProjectD\DeployTests.xml
#
# \\ServerName\C$\$Depot\query\ProjectD\run_deploy.cmd
# -defFile "Setup\Definitions\ProjectK.xml"
# -defFile "\\ServerName\C$\dev\$Depot\$ProjectFolder\$MainFolder\Setup\Definitions\ProjectK.xml"
# -defFile "\\ServerName\C$\$Depot\query\ProjectD\DeployTests.xml"

param (
    [string] $defFile = $(throw "Missing Setup definition file"),
    [string] $buildVersion = "",
    [string] $target = "QA-NA",
    [string] $buildShare = "\\ServerName\Build\$MainFolder\Main",
    [string] $privateBuildFolder = "\\ServerName\C$\dev\$Depot\$ProjectFolder\$MainFolder",
    [string] $smtpServer = "smtp.$Depot.corpnet.local",
    [switch] $copyBuild,
    [switch] $copyPrivates,
    [switch] $clean,
    [switch] $noSendEmail,
    [switch] $testMode,

    $lastArg
)
cls
$global:ErrorActionPreference = "Stop"
$scriptFolder = (Split-Path $MyInvocation.MyCommand.Definition).ToString()
. "$scriptFolder\Report.Utility.ps1"

$temp = "c:\\temp"
$date = Get-Date -format d
$dateTimeStamp = Get-Date -format MM-dd-yyyy.HH.mm

$transcriptFile = "c:\temp\run_deploy.$dateTimeStamp.log"
Write-Host "Log File: $transcriptFile"
$global:ErrorActionPreference = "SilentlyContinue"
Start-Transcript $transcriptFile -Force -ErrorAction SilentlyContinue
$global:ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Command Line Args ... "
Write-Host ". Report.ps1 ^ "
foreach($item in $PSBoundParameters.GetEnumerator()) {
    Write-Host "    -$($item.Key) $($item.Value) ^"
}
Write-Host ""

if (-not $buildVersion) {
    Write-Host "Getting build from $buildShare"
    $buildVersion = (Get-ChildItem $buildShare  | ? { $_.PSIsContainer } | sort CreationTime)[-1].Name
}

$buildFolder = "$buildShare\$buildVersion"
Write-Host "BuildFolder:          $buildFolder"

if ($clean -eq $True) {
    Write-Host Remove-Item c:\carlos -Recurse -Force -foreground Yellow 
               Remove-Item c:\carlos -Recurse -Force
}

if ((-not $copyBuild.IsPresent) -or ($copyBuild -eq $True)) {
    Write-Host "Copying official build bits from $buildFolder"

    & robocopy /MIR /NP /NFL /NDL /R:2 /W:3  $buildFolder\Release\Binaries        c:\carlos\Release\Binaries
    & robocopy /MIR /NP /NFL /NDL /R:2 /W:3  $buildFolder\Setup              c:\carlos\Setup
    & robocopy /MIR /NP /NFL /NDL /R:2 /W:3  $buildFolder\Database\ProjectD  c:\carlos\Database\ProjectD
    & robocopy /MIR /NP /NFL /NDL /R:2 /W:3  $buildFolder\Release\ProjectJ     c:\carlos\Release\ProjectJ

    & xcopy /frhicky $buildFolder\Database\*                                      c:\carlos\Database\
}

if ($copyPrivates -eq $True) {
    Write-Host "Copying private build bits from $privateBuildFolder"
    & xcopy /frehicky $privateBuildFolder\Release\Binaries\ProjectA        c:\carlos\Release\Binaries\ProjectA\
  # & xcopy /frehicky $privateBuildFolder\Setup\*                              c:\carlos\Setup\
  # & xcopy /frehicky $privateBuildFolder\Database\ProjectD\*                  c:\carlos\Database\ProjectD\
  # & xcopy /frehicky $privateBuildFolder\ProjectJ\ProjectI           c:\carlos\Release\ProjectJ\ProjectI\
}

$logFileBaseName = Split-Path $defFile -Leaf
$logFile = "$logFileBaseName.log"
Write-Host "LogFile: $logFile"

$psArgs = @{
    specificBuild        = "c:\carlos"
    target               = "$target"
    autoRun              = $true
    definitionFile       = "$defFile"
    deployApplications   = $true
    deployDatabases      = $true
    startApplications    = $true
    stopApplications     = $true
    DoParallelSetup = $false
    logFile              = "$logFile"
}

Write-Host "Deploybuild.ps1 Args"
$psArgs
Write-Host ""

pushd c:\carlos\Setup
.\Deploybuild.ps1 @psArgs
popd

Write-Host "LogFile: $logFile"
