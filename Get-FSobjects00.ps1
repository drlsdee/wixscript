enum YesNoType {
    yes
    no
}

class FSobject {
    [string]$Id
    [string]$Name
    [string]$Path
    [string]$Source
    [ValidateSet("File","Directory")]
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
            $this.Type = "Directory"
            $this.Source = $null
            $this.SubItems = Get-ChildItem -Path $this.Path #| Where-Object {$_.Attributes -notmatch $ignoreList}
        } Else {
            $this.Type = "File"
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
#$MainExecutable = Get-ChildItem -Path $Location -Recurse -Filter $MainExecName

function makeXML {
    param (
        [System.Xml.XmlElement]$parentNode,
        [FSobject]$class
    )
    $attributeNames = @(
        "ID",
        "Name",
        "Source"#,
        #"Type"
    )
    $attributeSet = $class.PSObject.Properties | Where-Object {($_.Name -in $attributeNames) -and ($_.Value)}
    $d = $parentNode.OwnerDocument.CreateElement($class.Type)
    foreach ($attribute in $attributeSet) {
        $d.SetAttribute($attribute.Name,$attribute.Value)
        $parentNode.AppendChild($d)
    }
    if ($class.SubItems) {
        foreach ($item in $class.SubItems) {
            makeXML $d $item
        }
    }
}

$Location = "C:\Users\Administrator\Desktop\AZK_History\1\azkplan"
Set-Location $Location
$RootDir = Get-Item $Location
$RootDir = [FSobject]::new($RootDir)
$testXMLDoc = New-Object -TypeName System.Xml.XmlDocument

$tempOut = $RootDir | ConvertTo-Xml -Depth $RootDir.Depth -NoTypeInformation -As String
$testXMLDoc.LoadXml($tempOut)
$testXMLDoc.Save('C:\testXMLdoc.xml')

$mainDocument = New-Object -TypeName System.Xml.XmlDocument
$mainDocument.LoadXml("<Wix></Wix>")
$mainElement = $mainDocument.SelectSingleNode("/Wix")
$mainElement.SetAttribute("xmlns",'http://schemas.microsoft.com/wix/2006/wi')
$fileElement = $mainElement.OwnerDocument.CreateElement("Directory")
$fileElement.SetAttribute("ID","TARGETDIR")
$fileElement.SetAttribute("Name","SourceDir")
$mainElement.AppendChild($fileElement)
$installLocation = $fileElement.OwnerDocument.CreateElement("Directory")
$installLocation.SetAttribute("ID","ProgramFilesFolder")
$installLocation.SetAttribute("Name","PFiles")
$fileElement.AppendChild($installLocation)
$productDir = $installLocation.OwnerDocument.CreateElement("Directory")
$productDir.SetAttribute("ID","ProductID")
$productDir.SetAttribute("Name","ProductName")
$installLocation.AppendChild($productDir)

makeXML $productDir $RootDir

$mainDocument.Save('C:\mainDocument.xml')
<#
TODO:
function for creating root node
get product name
#>