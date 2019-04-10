enum YesNoType {
    yes
    no
}

class FSobject {
    [string]$Id
    [string]$Name
    [string]$Path
    [string]$Source
    [string]$Type # TODO ValidateSet
    [array]$SubItems
    [int]$Depth

    [void] GetChildItems () {
        $count = 0
        while ($count -lt $this.SubItems.Count) {
            $item = Get-Item ($this.SubItems[$count] | Resolve-Path -Relative)
            $item = $this::new($item)
            $this.SubItems[$count] = $item
            $count++
        }
    }

    [void] GetItemsRecursively () {
        Write-Host "Current OBJECT is" $this.Name
        $this.GetChildItems()
        $items = $this.SubItems
        Write-Host $items.Name
        if ($items.Count -gt $null) {
            $count = 0
            while ($count -lt $items.Count) {
                $items[$count].GetChildItems()
                Write-Host $items[$count].Name
                $count++
            }
            foreach ($item in $items) {
                $item.GetItemsRecursively()
            }
        }
    }

    FSObject(){
    }

    FSObject($obj){
        $this.Id = $obj.BaseName
        $this.Name = $obj.Name
        $this.Path = $obj | Resolve-Path -Relative
        $this.Depth = 1
        If (Test-Path -Path $obj -PathType Container) {
            $this.Type = "folder"
            $this.Source = $null
            $this.SubItems = Get-ChildItem -Path $this.Path #| Where-Object {$_.Attributes -notmatch $ignoreList}
        } Else {
            $this.Type = "file"
            $this.Source = $this.Path -creplace '^[^\\]*\\', ''
            $this.SubItems = $null
        }
        $this.GetChildItems()
        if ($this.SubItems) {
            $subItemDepth = $this.SubItems | Measure-Object -Property Depth -Maximum
            $this.Depth += $subItemDepth.Maximum
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

#$MainExecName = "maincontroller.exe"

#$ignoreList = @("ReparsePoint")

$Location = "C:\Users\Administrator\Desktop\AZK_History\1"
#$MainExecutable = Get-ChildItem -Path $Location -Recurse -Filter $MainExecName
Set-Location $Location
$RootDir = Get-Item $Location
$RootDir = [FSobject]::new($RootDir)
$testXMLDoc = New-Object -TypeName System.Xml.XmlDocument

$tempOut = $RootDir | ConvertTo-Xml -Depth $RootDir.Depth -NoTypeInformation -As String
$tempOut
$testXMLDoc.LoadXml($tempOut)
$testXMLDoc.Save('C:\testXMLdoc.xml')
