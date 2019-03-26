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
    [array]$Files
    [array]$Subdirs
    [array]$SubItems

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
        If ($obj.Attributes -eq "Directory") {
            $this.Type = "folder"
            $this.Source = $null
            $this.SubItems = Get-ChildItem -Path $this.Path
        } Else {
            $this.Type = "file"
            $this.Source = $this.Path -creplace '^[^\\]*\\', ''
            $this.SubItems = $null
        }

    }
}


$Location = "C:\Users\Administrator\Desktop\AZK_History\1"

Set-Location $Location
$RootDir = Get-Item $Location
$RootDir = [FSobject]::new($RootDir)

$RootDir.FillSubItems()

$RootDir.SubItems