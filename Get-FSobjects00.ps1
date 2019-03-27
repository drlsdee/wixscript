enum FSItemType {
    file
    folder
}

enum YesNoType {
    yes
    no
}

class FSobject {
    [string]$Id
    [string]$Name
    [string]$Path
    [string]$Source
    [FSItemType]$Type
    [array]$SubItems
    [int]$Depth

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
        $this.Depth = 1
        $this.FillSubItems()
        if (($this.SubItems | Where-Object Type -EQ "folder").Count) {
            $this.Depth += $this.SubItems[0].Depth
        }
    }
}

class Product {
    [string]$Name
    [string]$Manufacturer
    [string]$Id
    [string]$UpgradeCode
    [int]$Language
    [int]$Codepage
    [string]$Version
}

class Package {
    [string]$Id
    [string]$Keywords
    [string]$Description
    [string]$Comments
    [string]$Manufacturer
    [string]$InstallerVersion
    [int]$Languages
    [YesNoType]$Compressed
    [int]$SummaryCodepage
}

$MainExecName = "maincontroller.exe"

$Location = "C:\Users\Administrator\Desktop\AZK_History\1"
$MainExecutable = Get-ChildItem -Path $Location -Recurse -Filter $MainExecName
Set-Location $Location
$RootDir = Get-Item $Location
$RootDir = [FSobject]::new($RootDir)

$RootDir.Depth