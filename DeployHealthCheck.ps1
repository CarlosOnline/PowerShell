# \\ServerName\C$\src\ps\CopyTestCheckerCheck.ps1
#

param (
    [string] $testShare = "\\ServerName\TestCheckerCheck",
    [string] $binPath = "bin\Release",
    [string] $branch = "V7.4",
    [string] $buildVersion = "",
    [string] $buildVersionMask = "*.*.*.??",  # get official build versions only: 8.0.924.37
    [string] $buildShare = "\\ServerName\Build\$MainFolder\Main",
    [string] $folders = "", # specify to override default
    [string] $privateBuildFolder = "\\ServerName\C$\dev\$Depot\$ProjectFolder\$MainFolder",
    [string] $smtpServer = "smtp.$Depot.local",
    [string] $sourceSharePath = "\\ServerName\c$",
    [string] $target = "QA-NA",
    [string] $webSharePath = "c:\inetpub\TestCheckerCheck",
    [switch] $clean,
    [string] $copyPrivates = "",
    [switch] $copyBuild,
    [switch] $noSendEmail,
    [switch] $skipCopyWebFolders,
    [switch] $skipCopyTestFolders,
    [switch] $start,
    [switch] $testMode,

    $lastArg
)
cls
$global:ErrorActionPreference = "Stop"
$scriptFolder = (Split-Path $MyInvocation.MyCommand.Definition).ToString()
. "$scriptFolder\Utility.ps1"

$temp = "c:\\temp"
$date = Get-Date -format d
$dateTimeStamp = Get-Date -format MM-dd-yyyy.HH.mm

$transcriptFile = "c:\temp\CopyTestCheckerCheck.log"
Write-Host "Log File: $transcriptFile"
$global:ErrorActionPreference = "SilentlyContinue"
Start-Transcript $transcriptFile -Force -ErrorAction SilentlyContinue
$global:ErrorActionPreference = "Stop"

Write-Host -foreground Yellow "----------------------------------------------------"
Write-Host -foreground Yellow "binPath               : $binPath"
Write-Host -foreground Yellow "branch                : $branch"
Write-Host -foreground Yellow "buildShare            : $buildShare"
Write-Host -foreground Yellow "buildVersion          : $buildVersion"
Write-Host -foreground Yellow "buildVersionMask      : $buildVersionMask"
Write-Host -foreground Yellow "folders               : $folders"
Write-Host -foreground Yellow "privateBuildFolder    : $privateBuildFolder"
Write-Host -foreground Yellow "smtpServer            : $smtpServer"
Write-Host -foreground Yellow "target                : $target"
Write-Host -foreground Yellow "testShare             : $testShare"
Write-Host -foreground Yellow "clean                 : $clean"
Write-Host -foreground Yellow "copyPrivates          : $copyPrivates"
Write-Host -foreground Yellow "copyBuild             : $copyBuild"
Write-Host -foreground Yellow "noSendEmail           : $noSendEmail"
Write-Host -foreground Yellow "testMode              : $testMode"
Write-Host -foreground Yellow "----------------------------------------------------"

if (-not $skipCopyTestFolders) {
    & schtasks.exe /End /TN "TestChecker Check TestExecuter"
    & taskkill /f /IM testexecuter.exe
    & taskkill /f /IM ProjectA.exe
    & taskkill /f /IM TestCheckerCheckMsTest.exe
    & taskkill /f /IM MsTest.exe
}

$buildFolder = "$buildShare\$buildVersion"
$folders = ([string] $folders).Split(",")
$copyPrivates = ([string] $copyPrivates).Split(",")

if (-not $buildVersion) {
    $buildVersion = (@(Get-ChildItem "$buildShare\$buildVersionMask" | ? { $_.PSIsContainer } | sort CreationTime))[-1].Name
}

Write-Host -foreground Green "buildVersion          : $buildVersion"
Write-Host -foreground Green "buildFolder           : $buildFolder"
Write-Host -foreground Green "----------------------------------------------------"
Write-Host

$folderList = @(
    "$sourceSharePath\dev\$Depot\$ProjectFolder\$MainFolder\Test\TestCheckerCheck\TestExecuter",
    "$sourceSharePath\dev\$Depot\$ProjectFolder\$MainFolder\Test\TestCheckerCheck\TestCheckerCheckMsTest",
    "$sourceSharePath\dev\$Depot\$ProjectFolder\$MainFolder\Test\TestCheckerCheckTests",
    "$sourceSharePath\dev\$Depot\$ProjectFolder\$MainFolder\ProjectJ\ProjectI"
)
$testFileList = @{
    "$sourceSharePath\dev\$Depot\$ProjectFolder\Sln\Test\$Depot.Test.Product\Local.testsettings"             = "c:\dev\$Depot\$ProjectFolder\Sln\Test\$Depot.Test.Product\Local.testsettings"
    "C:\dev\$Depot\$ProjectFolder\Sln\Test\$Depot.Test.Product\Local.testsettings"                           = "$testShare\Local.testsettings"
}

if ($folders.Length -ne 0 -and $folders -ne "") {
    $folderList = ([string] $folders).Split(",")
}

if ($clean -eq $True) {
    if ((-not $skipCopyTestFolders) -and (Test-Path $testShare)) {
        Write-Host Remove-Item $testShare -Recurse -Force -foreground Cyan
                   Remove-Item $testShare -Recurse -Force

        New-Item $testShare -type Directory
        & net share TestCheckerCheck /d
        & net share TestCheckerCheck=$testShare /GRANT:EVERYONE,FULL
    }

    if ((-not $skipCopyWebFolders) -and (Test-Path $webSharePath)) {
        #Write-Host Remove-Item $webSharePath -Recurse -Force -foreground Cyan
        #           Remove-Item $webSharePath -Recurse -Force
    }
}

$webFolderList = @{
    "$sourceSharePath\dev\$Depot\$ProjectFolder\$MainFolder\Test\TestCheckerCheck\Monitor"          = "$webSharePath"
}

if (-not $skipCopyWebFolders) {
    & attrib -r /s "$webSharePath\*"

    foreach ($item in $webFolderList.GetEnumerator()) {
        $source = $item.Name
        $dest = $item.Value

        Write-Host $source -foreground Cyan
        if (!(Test-Path $source)) {
            Write-Host "ERROR: Mising $source" -ForegroundColor Red
            continue
        }

        if ($source -eq $dest) {
            Write-Host "Skipping $source -eq $dest"
        } elseif ((Test-Path $source -PathType Container)) {
            Write-Host    robocopy /MIR /NP /NFL /NDL /R:2 /W:3 $source $dest -ForegroundColor Cyan
                        & robocopy /MIR /NP /NFL /NDL /R:2 /W:3 $source $dest /XD TestResults
        } else {
            try {
            Write-Host  Copy-Item $source $dest -Force -Recurse -Verbose -ForegroundColor Cyan
                        Copy-Item $source $dest -Force -Recurse -Verbose -ea SilentlyContinue
            } catch {}
        }
    }

    Write-Host C:\Windows\System32\inetsrv\appcmd.exe recycle apppool /apppool.name:"ASP.NET v4.0"
    & C:\Windows\System32\inetsrv\appcmd.exe recycle apppool /apppool.name:"ASP.NET v4.0"
}

if (-not $skipCopyTestFolders) {
    & attrib -r /s "$testShare\*"
    & schtasks.exe /End /TN "TestChecker Check TestExecuter"
    & taskkill /f /IM testexecuter.exe
    & taskkill /f /IM ProjectA.exe
    & taskkill /f /IM TestCheckerCheckMsTest.exe
    & taskkill /f /IM MsTest.exe

    foreach ($folder in $folderList) {
        Write-Host $folder -foreground Cyan
        if (-not $folder) { continue }

        if (!(Test-Path $folder)) {
            Write-Host "ERROR: Mising $folder\$binPath" -ForegroundColor Red
            continue
        }

        $folderName = Split-Path $folder -leaf

        $sourceBinPath = "$folder\$binPath"
        if (!(Test-Path $sourceBinPath)) {
            $sourceBinPath = "$folder\bin"
        }

        if (!(Test-Path $sourceBinPath)) {
            Write-Host "ERROR: Mising $folder\$binPath" -ForegroundColor Red
            continue
        }

        if ((Test-Path $sourceBinPath\TestResults)) {
            & Remove-Item "$sourceBinPath\TestResults" -Recurse -Force
        }
        Write-Host    robocopy /MIR /NP /NFL /NDL /R:2 /W:3 $sourceBinPath $testShare\$folderName /XD TestResults -ForegroundColor Cyan
                    & robocopy /MIR /NP /NFL /NDL /R:2 /W:3 $sourceBinPath $testShare\$folderName /XD TestResults
    }

    foreach ($item in $testFileList.GetEnumerator()) {
        $source = $item.Name
        $dest = $item.Value
         Write-Host $source -foreground Cyan
        if (!(Test-Path $source)) {
            Write-Host "ERROR: Mising $source" -ForegroundColor Red
            continue
        }

        if ($source -eq $dest) {
            Write-Host "Skipping $source -eq $dest"
        } elseif ((Test-Path $source -PathType Container)) {
            Write-Host    robocopy /MIR /NP /NFL /NDL /R:2 /W:3 $source $dest -ForegroundColor Cyan
                        & robocopy /MIR /NP /NFL /NDL /R:2 /W:3 $source $dest /XD TestResults
        } else {
            try {
            Write-Host  Copy-Item $source $dest -Force -Recurse -Verbose -ForegroundColor Cyan
                        Copy-Item $source $dest -Force -Recurse -Verbose -ea SilentlyContinue
            } catch {}
        }
    }

    if ($start -eq $True) {
        & $testShare\TestExecuter\TestExecuter.exe
    } else {
        & schtasks.exe /RUN /I /TN "TestChecker Check TestExecuter"
    }
}