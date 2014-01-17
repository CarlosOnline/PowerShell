Add-Type -AssemblyName System.Web

function TR($content, $class="") {

    $html = ""
    if (-not $class) {
        $html = @"
        <tr>`n
"@
    } else {
        $class = $class.Replace("_x0020_", "-")
        $html = @"
        <tr class='$class'>`n
"@
    }

    $html += $content
    $html += @"
        </tr>`n
"@
    return $html
}

function SPAN($content) {
    return "<span>" + $content + "</span>"
}

function PRE($content) {
    return "<pre>" + $content + "</pre>"
}
function TEXTAREA($content) {
    return "<textarea>" + $content + "</textarea>"
}
function INPUT($content) {
    return "<input type='text' value='$content' />"
}
function TD($content, $class="") {
    if (-not $class) {
        return "            <td>" + $content + "</td>`n"
    } else {
        $class = $class.Replace("_x0020_", "-")
        return "            <td class='$class'>" + $content + "</td>`n"
    }
}

function TH($content, $class="") {
    if (-not $class) {
        return "            <th>" + $content + "</th>`n"
    } else {
        $class = $class.Replace("_x0020_", "-")
        return "            <th class='$class'>" + $content + "</th>`n"
    }
}

function COLGROUP($content) {
    $html = @"
        <colgroup>`n
"@
    $html += $content
    $html += @"
        </colgroup>`n
"@
    return $html
}

function COL($className) {
    $className = $className -replace '_x0020_', '-'
    return "            <col class='$className' />`n"
}

function TableFromXmlFile($xmlFile) {
    $fileInfo = Get-ChildItem $xmlFile
    $tableName = $fileInfo.BaseName
    $className = $tableName -replace ' ', ''

    $html = @"

    <h1>$tableName</h1>`n
    <table class='$className'>`n
"@

    $xml = new-object xml
    $xml.PreserveWhitespace = $True
    $xml.Load($xmlFile)

    $columns = @()
    $htmlCol = ""
    $htmlColHeader = ""
    # Event can be an array, or single item
    $firstRow = $xml.Table.Event[0]
    if (-not $firstRow) {
        $firstRow = $xml.Table.Event
    }
    foreach ($item in $firstRow.Attributes) {
        $columns += $item.Name
        $htmlColHeader += TH $item.Name "$className-$($item.Name)"
        $htmlCol += COL $item.Name
    }
    $html += COLGROUP $htmlCol
    $html += TR $htmlColHeader "header-$className"

    foreach ($event in $xml.Table.Event) {
        $htmlColumns = ""
        foreach ($column in $columns) {
            $value = $event.($column)
            $value = [System.Web.HttpUtility]::HtmlEncode($value)
            if ((-not $value) -or ($value -eq $null)) {
                $htmlColumns += TD (PRE "") "$className-$column"
            } else {
                $htmlColumns += TD (PRE $value.Trim()) "$className-$column"
            }
        }
        $html += TR $htmlColumns $className
    }

    $html += @"
    </table>`n
"@
    return $html
}
