if (-not $emailAlias -and "$env:P4USER" -ne "") {
    $emailAlias = "$($env:P4USER)@$Depot.com"
}
if (-not $emailAlias) {
    $emailAlias = "$($env:USERNAME)@$Depot.com"
}
if ($emailAlias.ToLower() -eq "carlosg@$Depot.com") {
    $emailAlias = "Carlos.Gomes@$Depot.com"
}

function Start-Transcript-Ex($transcriptFile, [switch] $append) {
    $global:ErrorActionPreference = "SilentlyContinue"
    try {
        #Write-Host Start-Transcript $transcriptFile -Append:$append -Force -ErrorAction SilentlyContinue
                   Start-Transcript $transcriptFile -Append:$append -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host -foreground Red "Error Ocurred:"
        Write-Host -foreground Red $error[0].ToString()
        Write-Host -foreground Red $error[0].InvocationInfo.PositionMessage
    }
    $global:ErrorActionPreference = "Stop"
}

function Stop-Transcript-Ex() {
    $global:ErrorActionPreference = "SilentlyContinue"
    try {
        Stop-Transcript
    } catch {}
    $global:ErrorActionPreference = "Stop"
}

function Pause() {
    Write-Host "Press any key to continue ..."
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
}

function ExpandString($lines) {

    if ($lines -is [system.array]) {
        $output = @()
        foreach($line in $lines) {
            $output += $ExecutionContext.InvokeCommand.ExpandString($line)
        }
        return $output
    } else {
        return $ExecutionContext.InvokeCommand.ExpandString($lines)
    }
}

function runExternalProgram (
    [string] $Program = (throw "Please provide the program name to run"),
    [string] $Arg = "",
    [int] $ExpectedExitCode = 0,
    [string] $WorkingDirectory = "",
    $UseShellExecute = $False)
{
    Write-Host "$Program $Arg" -foreground Yellow
    $cmdArgs = $Arg

    if ( $WorkingDirectory -eq "" )
    {
        $WorkingDirectory = $scriptDirectory
    }

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo.Filename = $Program

    $proc.StartInfo.WorkingDirectory = $WorkingDirectory
    $proc.StartInfo.Arguments = $cmdArgs
    #$proc.StartInfo.WindowStyle = "Minimized"
    #$proc.StartInfo.WindowStyle = "Hidden"
    $proc.StartInfo.UseShellExecute = $UseShellExecute

    Write-Host "Running program: $Program $Arg [@$WorkingDirectory, $Retries retries]"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    [void]$proc.Start()
    $proc.WaitForExit()
    [int]$exitCode = $proc.ExitCode
    Write-Host "Exiting program: $exitCode (Time taken: $($sw.Elapsed.ToString())) [$Program $Arg]"

    $proc.dispose()
    return $exitCode
}

function runExternalProgramEx (
    [string] $Program = (throw "Please provide the program name to run"),
    $ArgArray = @(),
    [int] $ExpectedExitCode = 0,
    [string] $WorkingDirectory = "",
    $UseShellExecute = $False)
{
    #Write-Host "$Program $Arg ^" -color Yellow
    #foreach($item in $ArgArray) {
    #    Write-Host "        $item ^"
    #}
    #Write-Host ""

    $cmdArgs = [string]::join(" ", $ArgArray)
    runExternalProgram $Program $cmdArgs $ExpectedExitCode $WorkingDirectory -UseShellExecute:$UseShellExecute
}

function CopyEmailAttachments($srcAttachments = @()) {
    if (-not $srcAttachments -or $srcAttachments.Length -eq 0) {
        return @()
    }

    $attachments = @()
    $idx = 0
    foreach($attachment in $srcAttachments) {
        if (!(Test-Path $attachment)) {
            continue;
        }

        $idx++
        $fileInfo = Get-ChildItem $attachment
        $baseName = $fileInfo.BaseName
        $ext = $fileInfo.Extension

        $localFile = "$temp\$baseName.$idx$ext"
        # Get tail of attachment if its too big
        if ($fileInfo.Length -gt 20 * 1024) {
            Write-Host "Copying large attachment $attachment ..."
            $content = (Get-Content $attachment)
            $content = ($content | Select-Object -First 100) + "`n`n`n`n`n`n`n...`n`n`n`n`n`n`n" + ($content | Select-Object -Last 100)
            $content | Out-File $localFile
        } else {
            Copy-Item $attachment $localFile
        }
        $attachments += $localFile
    }

    return $attachments
}

function SendEmail($from, $to, $CC, $subject, $body, $attachments=@(), $smtpServer="smtp.$Depot.local") {

    $htmlBody = $body
    if ($htmlBody -is [system.array]) {
        $htmlBody = $body -join ' '
    }

    Send-MailMessage -To $to -Cc $CC -From $from -Subject $subject -Body $htmlBody -BodyAsHtml -SmtpServer $smtpServer -Attachments $attachments
    Write-Host "Sent Email $to $subject"
}

function SendErrorMessage($subject, $body) {
    $logFile = "$transcriptFile.mail.log"
    Write-Host  Copy-Item $transcriptFile $logFile
                Copy-Item $transcriptFile $logFile
    $logMsg = (Get-Content $logFile) -join "`n<br/>"
    $logMsg = "<span>$logMsg</span>"

    $attachments = @(
        $logFile
    )

    $positionMessage = $error[0].InvocationInfo.PositionMessage
    $positionMessage = $positionMessage -replace '\+', '<br/>'
    $errorMessage = ""
    if ($error -and $error[0]) {
        $errorMessage = '<h3 style="color:red;">' + $error[0].ToString() + '</h3> ' + $positionMessage + '<br/> '
    }
    if (-not $emailAlias) {
        $emailAlias = "$($env:USERNAME)@$Depot.com"
    }
    SendEmail -from $emailAlias `
              -to $emailAlias `
              -CC $emailAlias `
              -subject "Report Error - $subject" `
              -body "$body<br/>`n ERRORs:<br/>`n $errorMessage<br/>$logMsg" `
              -attachments $attachments
}

function SendResultEmail(
    [string] $transcriptFile = $(throw "Missing transcriptFile"), 
    [string] $body = $(throw "Missing body"), 
    [string] $subjectName="",
    [array] $attachments = @()) {

    if ($noSendEmail) {
        return;
    }

    try {
        $lines = (Get-Content $transcriptFile)
        $output = [string]::Join("</pre>`n<pre>", $lines)

        $body = "$body<h4>Output</h4>`n<pre>$output</pre><br/>"

        $mailArgs = @{
            To              = $emailAlias;
            #Cc              = "";
            From            = $emailAlias;
            Subject         = "$subjectName Completed";
            Body            = $body;
            BodyAsHtml      = $True;
            SmtpServer      = $smtpServer;
        }

        $attachments += $transcriptFile
        $attachments = CopyEmailAttachments $attachments
        if ($attachments.Length -gt 0) {
            $mailArgs.Attachments = $attachments
        }

        Verbose "Sending Email ... to $emailAlias"
        Send-MailMessage @mailArgs
        Verbose "Sent Email"

    } catch {
        Write-Host -foreground Red "Send Email Error Ocurred:"
        Write-Host -foreground Red $error[0].ToString()
        Write-Host -foreground Red $error[0].InvocationInfo.PositionMessage
        if (-not $noSendEmail) {
            SendErrorMessage "$subjectName Error" "Failed to send command line email"
        }
    }
}

function Terse() {
    if (-not $terse) {
        return;
    }

    Write-Host $args
}

function Verbose() {
    if (-not $verbose) {
        return;
    }

    Write-Host $args
}

