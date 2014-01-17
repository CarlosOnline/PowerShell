# run_deploy.ps1 \\ServerName\C$\$Depot\query\ProjectD\DeployTests.xml
#
# \\ServerName\C$\$Depot\query\ProjectD\run_deploy.cmd
# -defFile "Setup\Definitions\ProjectK.xml"
# -defFile "\\ServerName\C$\dev\$Depot\$ProjectFolder\$MainFolder\Setup\Definitions\ProjectK.xml"
# -defFile "\\ServerName\C$\$Depot\query\ProjectD\DeployTests.xml"

param (
    [string] $defFile = $(throw "Missing Setup definition file"),
    [string] $branch = "V7.4",
    [string] $buildVersion = "",
    [string] $target = "QA-NA",
    [string] $buildShare = "\\ServerName\Build\$MainFolder\Main",
    [string] $privateBuildFolder = "\\ServerName\C$\dev\$Depot\$ProjectFolder\$MainFolder",
    [string] $smtpServer = "smtp.$Depot.local",
    [string] $buildVersionMask = "*.*.*.??",  # get official build versions only: 8.0.924.37
    [string] $features = "default",
    [string] $privateFeatures = "default",
    [switch] $copyPrivates,
    [switch] $skipCopyBuild,
    [switch] $skipDeploy,
    [switch] $copyOnly,
    [switch] $clean,
    [switch] $noSendEmail,
    [switch] $testMode,
    [switch] $terse,
    [switch] $verbose,

    $lastArg
)
cls
$global:ErrorActionPreference = "Stop"
$scriptFolder = (Split-Path $MyInvocation.MyCommand.Definition).ToString()
. "$scriptFolder\Utility.ps1"

$temp = "c:\\temp"
$date = Get-Date -format d
$dateTimeStamp = Get-Date -format MM-dd-yyyy.HH.mm

$transcriptFile = "c:\temp\run_deploy.$dateTimeStamp.log"
Write-Host "Log File: $transcriptFile"
$global:ErrorActionPreference = "SilentlyContinue"
Start-Transcript $transcriptFile -Force -ErrorAction SilentlyContinue
$global:ErrorActionPreference = "Stop"

try {
    Write-Host -foreground Yellow "----------------------------------------------------"
    Write-Host -foreground Yellow "defFile               : $defFile"
    Write-Host -foreground Yellow "branch                : $branch"
    Write-Host -foreground Yellow "buildVersion          : $buildVersion"
    Write-Host -foreground Yellow "target                : $target"
    Write-Host -foreground Yellow "buildShare            : $buildShare"
    Write-Host -foreground Yellow "privateBuildFolder    : $privateBuildFolder"
    Write-Host -foreground Yellow "smtpServer            : $smtpServer"
    Write-Host -foreground Yellow "buildVersionMask      : $buildVersionMask"
    Write-Host -foreground Yellow "copyPrivates          : $copyPrivates"
    Write-Host -foreground Yellow "skipCopyBuild         : $skipCopyBuild"
    Write-Host -foreground Yellow "skipDeploy            : $skipDeploy"
    Write-Host -foreground Yellow "clean                 : $clean"
    Write-Host -foreground Yellow "noSendEmail           : $noSendEmail"
    Write-Host -foreground Yellow "testMode              : $testMode"
    Write-Host -foreground Yellow "terse                 : $terse"
    Write-Host -foreground Yellow "verbose               : $verbose"
    Write-Host -foreground Yellow "----------------------------------------------------"

    if (-not $buildVersion) {
        $buildVersion = (@(Get-ChildItem "$buildShare\$buildVersionMask" | ? { $_.PSIsContainer } | sort CreationTime))[-1].Name
    }

    $features = [array]$features.Split(",")
    $privateFeatures = [array]$privateFeatures.Split(",")
    $buildFolder = "$buildShare\$buildVersion"

    if ($skipDeploy -eq $True) {
        if ($clean -eq $True) {
            throw "Error -clean and -skipDeploy cannot be used together"
        }
        $copyBuild = $False
        $copyPrivates = $False
        $skipCopyBuild = $True
    }

    Write-Host -foreground Green "buildVersion          : $buildVersion"
    Write-Host -foreground Green "buildFolder           : $buildFolder"
    Write-Host -foreground Green "----------------------------------------------------"
    Write-Host


    if ($clean -eq $True) {
        Write-Host Remove-Item c:\carlos -Recurse -Force -foreground Cyan
                   Remove-Item c:\carlos -Recurse -Force
    }

    if (-not $skipCopyBuild) {
        Write-Host -foreground Cyan "Copying official build bits from $buildFolder"

        & robocopy /MIR /NP /NFL /NDL /R:2 /W:3  $buildFolder\Release\Binaries        c:\carlos\Release\Binaries
        & robocopy /MIR /NP /NFL /NDL /R:2 /W:3  $buildFolder\Setup              c:\carlos\Setup
        & robocopy /MIR /NP /NFL /NDL /R:2 /W:3  $buildFolder\Release\ProjectJ     c:\carlos\Release\ProjectJ
        & xcopy /frhicky $buildFolder\Database\*                                      c:\carlos\Database\

        # Dtn
        if ($features.Contains("*") -or $features.Contains("dtn")) {
            & robocopy /MIR /NP /NDL /R:2 /W:3  $buildFolder\Database\ProjectD  c:\carlos\Database\ProjectD
        }

        #ProjectF Stuff
        if ($features.Contains("*") -or $features.Contains("refdefs") -or $features.Contains("ProjectF")) {
            & robocopy /MIR /NP /NFL /NDL /R:2 /W:3  $buildFolder\Database\ProjectC  c:\carlos\Database\ProjectC
            & robocopy /MIR /NP /NFL /NDL /R:2 /W:3  $buildFolder\Database\ProjectF            c:\carlos\Database\ProjectF
        }

        #ProjectH Stuff
        if ($features.Contains("*") -or $features.Contains("ProjectH")) {
            & robocopy /MIR /NP /NFL /NDL /R:2 /W:3  $buildFolder\Database\ProjectH  c:\carlos\Database\ProjectH
        }

        #ProjectG Stuff
        if ($features.Contains("*") -or $features.Contains("ProjectG")) {
            & robocopy /MIR /NP /NFL /NDL /R:2 /W:3  $buildFolder\Database\ProjectG  c:\carlos\Database\ProjectG
        }

        & attrib -r /s c:\carlos\*
    }

    if (($copyPrivates -ne $False) -and ($copyPrivates -ne $null)) {
        Write-Host -foreground Cyan "Copying private build bits from $privateBuildFolder - $privateFeatures"

        # Common
        & echo xcopy /frdhicky   $privateBuildFolder\Setup\Database\SetupData\*                   c:\carlos\Setup\Database\SetupData\
        &      xcopy /frdhicky   $privateBuildFolder\Setup\Database\SetupData\*                   c:\carlos\Setup\Database\SetupData\
        & echo xcopy /frhicky    $privateBuildFolder\Setup\*                                          c:\carlos\Setup\
        &      xcopy /frhicky    $privateBuildFolder\Setup\*                                          c:\carlos\Setup\

        # CS
        if ($privateFeatures.Contains("*") -or $privateFeatures.Contains("cs")) {
            & echo xcopy /frehicky   $privateBuildFolder\Setup\Database\SetupData\*                   c:\carlos\Setup\Database\SetupData\
            &      xcopy /frehicky   $privateBuildFolder\Setup\Database\SetupData\*                   c:\carlos\Setup\Database\SetupData\
        }

        # ProjectA
        if ($privateFeatures.Contains("*") -or $privateFeatures.Contains("ti") -or $privateFeatures.Contains("tiplugin") -or $privateFeatures.Contains("ProjectA")) {
            & xcopy /frehicky   $privateBuildFolder\Server\projects\ProjectA\bin\Release\*         c:\carlos\Release\Binaries\ProjectA\
            & xcopy /frehicky   $privateBuildFolder\Server\projects\CSegNas\bin\Release\*                   c:\carlos\Release\Binaries\ProjectA\Plugins\
            & xcopy /frehicky   $privateBuildFolder\Server\projects\EdgeNas\bin\Release\*                   c:\carlos\Release\Binaries\ProjectA\Plugins\
            & xcopy /frehicky   $privateBuildFolder\Server\projects\ClosureDetector\bin\Release             c:\carlos\Release\Binaries\ProjectA\Plugins\
        }

        # ProjectH
        if ($privateFeatures.Contains("*") -or $privateFeatures.Contains("ProjectH")) {
            & echo xcopy /frehicky   $privateBuildFolder\Database\ProjectH\*                                    c:\carlos\Database\ProjectH\
            &      xcopy /frehicky   $privateBuildFolder\Database\ProjectH\*                                    c:\carlos\Database\ProjectH\
            & xcopy /frehicky   $privateBuildFolder\Server\projects\ProjectA\bin\Release\*         c:\carlos\Release\Binaries\ProjectA\
            & xcopy /frehicky   $privateBuildFolder\Server\projects\CSegNas\bin\Release\*                   c:\carlos\Release\Binaries\ProjectA\Plugins\
            & xcopy /frehicky   $privateBuildFolder\Server\projects\EdgeNas\bin\Release\*                   c:\carlos\Release\Binaries\ProjectA\Plugins\
        }

        # Database
        if ($privateFeatures.Contains("*") -or $privateFeatures.Contains("database")) {
            & echo xcopy /frhicky    $privateBuildFolder\Database\*                                            c:\carlos\Database\
            &      xcopy /frhicky    $privateBuildFolder\Database\*                                            c:\carlos\Database\
        }

        # ProjectB Items
        if ($privateFeatures.Contains("*") -or $privateFeatures.Contains("ie") -or $privateFeatures.Contains("ProjectB")) {
            & echo xcopy /frehicky  $privateBuildFolder\Server\projects\ProjectB\bin\Release\*       c:\carlos\Release\Binaries\ProjectB\
            &      xcopy /frehicky  $privateBuildFolder\Server\projects\ProjectB\bin\Release\*       c:\carlos\Release\Binaries\ProjectB\
            #& xcopy /frehicky   \\ServerName\c$\dev\$Depot\Main\$MainFolder\Server\projects\ProjectB\bin\Release\* c:\carlos\Release\Binaries\ProjectB\
        }

        # Dtn
        if ($privateFeatures.Contains("*") -or $privateFeatures.Contains("dtn")) {
            & xcopy /frehicky   $privateBuildFolder\Server\projects\ProjectA\bin\Release\*       c:\carlos\Release\Binaries\ProjectA\
            & xcopy /frehicky   $privateBuildFolder\Server\projects\ProjectD\bin\Release\*           c:\carlos\Release\Binaries\ProjectA\Plugins\
            & xcopy /frehicky   $privateBuildFolder\Server\projects\PredictionCollator\bin\Release\*      c:\carlos\Release\Binaries\ProjectA\Plugins\
            & xcopy /frehicky   $privateBuildFolder\ProjectJ\ProjectI                       c:\carlos\Release\ProjectJ\ProjectI\
        }

        #ProjectF Stuff
        if ($privateFeatures.Contains("*") -or $privateFeatures.Contains("refdefs") -or $privateFeatures.Contains("ProjectF")) {
            & xcopy /redhicky   $privateBuildFolder\Database\ProjectC\*                              c:\carlos\$ProjectFolder\Database\ProjectC\
            & xcopy /redhicky   $privateBuildFolder\Database\ProjectF\*                                        c:\carlos\$ProjectFolder\Database\ProjectF\
            & xcopy /frdhicky   $privateBuildFolder\Database\*                                            c:\carlos\$ProjectFolder\Database\
        }
    }

    if (-not $copyOnly) {
        $logFileBaseName = Split-Path $defFile -Leaf
        $logFile = "$logFileBaseName.log"
        Write-Host "LogFile: $logFile"

        $psArgs = @{
            branch               = $branch
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

        $body = "<h2>DeployBuild.ps1</h2>`n"
        foreach($arg in $psArgs.GetEnumerator()) {
            $body += "<pre>$($arg.Name) : $($arg.Value)</pre>`n"
        }
        $body += "`n`n"

        SendResultEmail $transcriptFile $body "RunDeploy $target $buildVersion $features $privateFeatures"
    }

} catch {
    Write-Host -foreground Red "Error Ocurred:"
    Write-Host -foreground Red $error[0].ToString()
    Write-Host -foreground Red $error[0].InvocationInfo.PositionMessage
    if (-not $noSendEmail) {
        SendErrorMessage "RunDeploy Error $target $buildVersion $features $privateFeatures" "Failed to deploy"
    }
}

try { Stop-Transcript-Ex } catch {}
Verbose "Log File: $transcriptFile"

Write-Host -foreground Cyan "LogFile: c:\Carlos\Setup\$logFile"
