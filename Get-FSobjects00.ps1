enum FSItemType {
    file
    folder
}

class FSobject {
    [string]$Id
    [string]$Name
    [string]$Path
    [string]$Source
    [FSItemType]$Type
    [array]$SubItems
#    [array]$SubFolders

    [void]FillSubItems(){
        $i = 0
        While ($i -lt $this.SubItems.Count) {
            $j = Get-Item ($this.SubItems[$i] | Resolve-Path -Relative)
            $j = $this::new($j)
            $this.SubItems[$i] = $j
            $i++
        }
    }

    FSObject(){
    }

    FSObject($obj){
        $this.Id = $obj.BaseName
        $this.Name = $obj.Name
        $this.Path = $obj | Resolve-Path -Relative
        If (Test-Path -Path $obj -PathType Container) {
            $this.Type = "folder"
            $this.Source = $null
            $this.SubItems = Get-ChildItem -Path $this.Path
        } Else {
            $this.Type = "file"
            $this.Source = $this.Path -creplace '^[^\\]*\\', ''
            $this.SubItems = $null
        }
        $this.FillSubItems()
    }
}


$Location = "C:\Users\Administrator\Desktop\AZK_History\1"

Set-Location $Location
$RootDir = Get-Item $Location
$RootDir = [FSobject]::new($RootDir)

function GetDepth ($object) {
    $maxdepth = $maxdepth
    $depth++
    if ($maxdepth -lt $depth) {
        $maxdepth = $depth
    } else {
        $maxdepth = $maxdepth
    }
    $subfolders = $object.SubItems | Where-Object Type -EQ "folder"
    $count = $subfolders.Count
    Write-Host "Object" $object.Path "contains" $count "subitems. Current depth is" $depth
    if ($count -gt 0) {
        $i = 0
        while ($i -lt $count) {
            $item = $subfolders[$i]
            $subitemsNotEmpty = $item.Subitems | Where-Object SubItems -NE $null
            $subcount = $subitemsNotEmpty.Count
            Write-Host "Current item is" $item.Path "and contains" $subcount "items. Current depth is" $depth "and maximal is" $maxdepth
            if ($subcount -gt 0) {
                GetDepth $item
            } else {
                Write-Host "Nothing to do!"
            }
            $i++
        }
    }
    Write-Host "Executed. Maximal depth is" $maxdepth
}

GetDepth $RootDir