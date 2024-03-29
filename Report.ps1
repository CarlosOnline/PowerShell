param (
    [string] $reportJsonFile = $(throw "Missing json report file"),
    [string] $server = "FQSqlEvt01",
    [string] $database = "EventLog",
    [string] $smtpServer = "smtp.$Depot.local", #Other addresses: "10.4.2.128","smtp.$Depot.corpnet.local",
    [string] $userId = "",
    [string] $password = "",
    [string] $networkOutputFolder = "", # "c:\temp\Reports"
    [string] $target = "",
    [switch] $useExisting,
    [switch] $officialMode,
    [switch] $noSendEmail,
    [switch] $noSetup,
    [switch] $noCleanup,
    [switch] $testMode,
    [switch] $firstOnly,

    $lastArg
)
cls
$global:ErrorActionPreference = "Stop"
$scriptFolder = (Split-Path $MyInvocation.MyCommand.Definition).ToString()
. "$scriptFolder\Utility.ps1"
. "$scriptFolder\Report.Utility.ps1"

$temp = "c:\\temp"
$date = Get-Date -format d
$dateTimeStamp = Get-Date -format MM-dd-yyyy
$outputFolder = ""
$report = $null
$global:cleanup =@()
$emailAlias = "$($env:USERNAME)@$Depot.com"

$transcriptFile = "c:\temp\report.ps1.$dateTimeStamp.log"
Start-Transcript-Ex $transcriptFile

function main() {
    Write-Host ""
    Write-Host "Command Line Args ... "
    Write-Host ". Report.ps1 ^ "
    foreach($item in $PSBoundParameters.GetEnumerator()) {
        Write-Host "    -$($item.Key) $($item.Value) ^"
    }
    Write-Host ""

    $jsonFolder = Split-Path $reportJsonFile
    $jsonFolder = $jsonFolder -replace "\\", "\\\\"

    $json = (Get-Content $reportJsonFile) -join "`n"
    $json = $ExecutionContext.InvokeCommand.ExpandString($json)
    $report = $json | ConvertFrom-Json
    if ($report.email -and $report.email.From) {
        $emailAlias = $report.email.From
    }
    $outputFolder = Split-Path $report.OutputFile
    if (-not $useExisting -and (Test-Path $outputFolder)) {
        Remove-Item $outputFolder -force -recurse
    }
    if (!(Test-Path $outputFolder)) {
        $ignore = New-Item $outputFolder -type Directory
    }
    $xmlOutputFolder = $report.OutputFolder
    if (-not $useExisting -and (Test-Path $xmlOutputFolder)) {
        Remove-Item $xmlOutputFolder -force -recurse
    }
    if (!(Test-Path $outputFolder)) {
        $ignore = New-Item $xmlOutputFolder -type Directory
    }

    $cssFileContents = ""
    if (-not (-not $report.CssFile) -and (Test-Path $report.CssFile)) {
        $cssFileContents = (Get-Content $report.CssFile)
    }

    if (-not $noSetup) {
        if (-not $noCleanup) {
            $global:cleanup = $report.cleanup
        }

        if ($report.setup) {
            foreach($expression in $report.setup) {
                try {
                    Write-Host $expression
                    Invoke-Expression $expression
                } catch {
                    Write-Host -foreground Red "Error Ocurred:"
                    Write-Host -foreground Red $error[0].ToString()
                    Write-Host -foreground Red $error[0].InvocationInfo.PositionMessage
                }
            }
        }
    }

    if ((-not $useExisting) -or (!(Test-Path $xmlOutputFolder))) {

        $reportSql = $report.SqlFilePath
        if ($reportSql) {
            $args = (                "-S $server",                "-d $database",                "-i ""$reportSql""",                "-v report_path=""$jsonFolder""",                "-v output_folder=""$xmlOutputFolder"""            )

            if ((-not $userId) -and (-not $password)) {
                $args += " -E"
            } else  {
                $args += " -U $userId"
                $args += " -P $password"
            }

            $exitCode = runExternalProgramEx "sqlcmd.exe" $args
            if ($exitCode -ne 0) {
                throw "sqlCmd.exe failed with exitcode $exitCode"
            }
        }

        if ($report.query) {
            foreach($sqlCmdLineArgs in $report.query) {
                if ((-not $sqlCmdLineArgs) -or ($sqlCmdLineArgs -eq $null)) {
                    continue
                }

                $exitCode = runExternalProgram "sqlcmd.exe" $sqlCmdLineArgs
                if ($exitCode -ne 0) {
                    throw "sqlCmd.exe failed with exitcode $exitCode"
                }
                if ($firstOnly) {
                    Write-Host "-firstOnly turned on, skipping rest of queries" -foreground Yellow
                    break
                }
            }
        }

        if ($report.commands) {
            foreach($cmd in $report.commands) {
                if ((-not $cmd) -or ($cmd -eq $null) -or (-not $cmd.program)) {
                    continue
                }
                $exitCodes = @()
                if ($cmd.exitCodes) {
                    $exitCodes = $cmd.exitCodes
                }

                $useShellExecute = $False
                if ($cmd.program -eq "sqlcmd.exe") {
                    $useShellExecute = $True
                }
                $exitCode = runExternalProgram $cmd.program $cmd.args -UseShellExecute:$useShellExecute
                if ($exitCode -ne 0) {
                    throw $cmd.program + " failed with exitcode $exitCode"
                }
                if ($firstOnly) {
                    Write-Host "-firstOnly turned on, skipping rest of queries" -foreground Yellow
                    break
                }
            }
        }
    }

    if (!(Test-Path $xmlOutputFolder)) {
        throw "Missing output folder: $xmlOutputFolder"
    }

    $xmlFiles = Get-ChildItem "$xmlOutputFolder\*.xml" | Sort-Object -Property CreationTime

    $html = ExpandString((Get-Content $report.TemplateFile))


    foreach ($file in $xmlFiles) {
        Write-Host "Processing $file"

        $table = ""
        try {
            $contents = Get-Content $file | Out-String
            if (-not $contents.Trim()) {
                Write-Host "Empty file $file" -foreground yellow
                continue
            }
            $table += TableFromXmlFile $file
        } catch {
            Write-Host -foreground Red "Error processing $file"
            Write-Host -foreground Red $error[0].ToString()
            Write-Host -foreground Red $error[0].InvocationInfo.PositionMessage
            $contents = (Get-Content $file)
            Write-Host -foreground Red $contents
            continue
        }
        $table += $report.TableInsertHere

        $html = $html -replace $report.TableInsertHere, $table
        $html | Out-File "c:\temp\test.htm" -force
    }

    if (!(Test-Path $outputFolder)) {
        $ignore = New-Item $outputFolder -type Directory
    }
    $html = $html -replace "_x0020_", " "
    $html | Out-File $report.OutputFile -force
    Write-Host "Generated " $report.OutputFile -foreground White
    Write-Host "--------------------"
    Write-Host ""

    if (-not $networkOutputFolder) {
        $networkOutputFolder = $report.NetworkOutputFolder
    }

    if ($networkOutputFolder) {
        #ConnectNetworkDrive $networkOutputFolder $networkUserName $networkPassword
        Write-Host    xcopy /frehicky "$xmlOutputFolder\*"  "$networkOutputFolder\" -ForegroundColor Yellow
                    & xcopy /frehicky "$xmlOutputFolder\*"  "$networkOutputFolder\"
        Write-Host    xcopy /frehicky "$outputFolder\*"  "$networkOutputFolder\" -ForegroundColor Yellow
                    & xcopy /frehicky "$outputFolder\*"  "$networkOutputFolder\"
    }

    if (-not $noSendEmail) {
        if (-not $officialMode) {
            $report.email.To = $report.email.From
            $report.email.Cc = $report.email.From
            #$report.email.From = $report.email.From
        }

        $mailArgs = @{
            To              = $report.email.To;
            Cc              = $report.email.CC;
            From            = $report.email.From;
            Subject         = $report.Subject;
            Body            = $html -join ' ';
            BodyAsHtml      = $True;
            SmtpServer      = $smtpServer;
        }

        if ($report.attachments) {
            $attachments = CopyEmailAttachments $report.attachments
            if ($attachments.Length -gt 0) {
                $mailArgs.Attachments = $attachments
            }
        }
        Write-Host "Sending Email ... to $($report.email.To)"
        Send-MailMessage @mailArgs
        Write-Host "Sent Email"
    }
}

try {
    main
} catch {
    Write-Host -foreground Red "Error Ocurred:"
    Write-Host -foreground Red $error[0].ToString()
    Write-Host -foreground Red $error[0].InvocationInfo.PositionMessage
    if (-not $noSendEmail) {
        SendErrorMessage "$reportJsonFile" "Failed to process $reportJsonFile"
    }
}

# Cleanup
try {
    if ($global:cleanup) {
        Write-Host "Cleaning up"
        foreach($expression in $global:cleanup) {
            try {
                Write-Host $expression
                Invoke-Expression $expression
            } catch {
                Write-Host -foreground Red "Error Ocurred:"
                Write-Host -foreground Red $error[0].ToString()
                Write-Host -foreground Red $error[0].InvocationInfo.PositionMessage
            }
        }
    }
} catch {
    Write-Host -foreground Red "Error Ocurred:"
    Write-Host -foreground Red $error[0].ToString()
    Write-Host -foreground Red $error[0].InvocationInfo.PositionMessage
}

try {
    Stop-Transcript-Ex

    $jsonName = Split-Path $reportJsonFile -leaf
    $jsonFolder = Split-Path $reportJsonFile
    $jsonFolderName = Split-Path $jsonFolder -leaf
    $logFile = "$temp\Report.$jsonFolderName.$jsonName.$dateTimeStamp.log"
    Write-Host  Copy-Item $transcriptFile $logFile
                Copy-Item $transcriptFile $logFile
    $transcriptFile = $logFile

    if ($report -ne $null) {
        $outputFolder = Split-Path $report.OutputFile
        $logFile = "$outputFolder\Report.$jsonFolderName.$jsonName.$dateTimeStamp.log"
        Write-Host  Copy-Item $transcriptFile $logFile
                    Copy-Item $transcriptFile $logFile
        $transcriptFile = $logFile
    }
} catch {
    Write-Host -foreground Red "Error Ocurred:"
    Write-Host -foreground Red $error[0].ToString()
    Write-Host -foreground Red $error[0].InvocationInfo.PositionMessage
    if (-not $noSendEmail) {
        SendErrorMessage "$reportJsonFile" "Failed to process $reportJsonFile"
    }
}
Write-Host "Log File: $logFile"

