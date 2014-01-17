
$newCID = 0
$newCLFormat = p4 change -o | select-string -pattern change, client, status
$newCLFormat += "Description: " + $myDescription
#$newCLFormat | p4 change -i
$newCLFormat | p4 change -i | %{ $_.split()[1] } | Out-File -Encoding Ascii "c:\temp\changelist.txt"
Write-Host "c:\temp\changelist.txt"
$newCLFormat
