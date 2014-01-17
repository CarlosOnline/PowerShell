function ApplyPendingChangeList($changelistNum)
{
    #param([int]$changelistNum, [string]$destBranch)

    $regex = "^... (//.*)#.* (.*)"
    #$sourceFiles = p4 change -o $changelistNum | select-string $regex | %{$_.matches[0]}
    $sourceFiles = p4 describe -s $changelistNum | select-string $regex | %{$_.matches[0]}
    $sourceFiles 

    $sourceFiles | %{
        $file = $_.groups[1].value.trim()
        $action = $_.groups[2].value.trim()
        
        $localPath = (p4 where $file).split(' ')[2];
        $clientPath = "$file@$changelistNum"
        if ($action -eq "edit") {
            p4 $action $localPath
            Write-Host "p4 print -q -o $localPath $clientPath"
                        p4 print -q -o $localPath $clientPath
        } 
        elseif ($action -eq "add") {
            #UNDONE: - doesnt work
            Write-Host "p4 print -q -o $localPath $clientPath"
                        p4 print -q -o $localPath $clientPath
            p4 add $destPath;
        }
    }
}

ApplyPendingChangeList "39993" "JESSE02"