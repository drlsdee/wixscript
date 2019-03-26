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
#        $this.SubFolders = $this.SubItems | Where-Object Attributes -EQ "Directory"
        $this.FillSubItems()
    }
}


$Location = "C:\Users\Administrator\Desktop\AZK_History"

Set-Location $Location
$RootDir = Get-Item $Location
$RootDir = [FSobject]::new($RootDir)
