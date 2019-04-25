class Wix {
    [string]$Type = $this.GetType().Name
    [string]$ID
    [string]$Name
    [array]$SubItems
    [array]$attributeNames
}

class Product : Wix {
    [string]$Name
    [string]$Manufacturer
    [string]$UpgradeCode
    [int]$Language
    [int]$Codepage
    [string]$Version
}

class Component : Wix {
    [string]$GUID
    [array]$attributeNames = @(
        "ID",
        "GUID"
    )

    Component ($obj) {
        $this.GUID = (New-Guid).Guid.ToUpper()
        $this.ID = $obj.ID, $this.GUID -join "+"
    }
}

class Package : Wix {
    [string]$Keywords
    [string]$Description
    [string]$Comments
    [string]$Manufacturer
    [string]$InstallerVersion
    [int]$Languages
    [ValidateSet("Yes","No")]
    [string]$Compressed
    [int]$SummaryCodepage
}

class WixFSObject : Wix {
    [string]$Path
    [string]$Source

    [void] GetName ($object) {
        $this.ID = $object.BaseName
        $this.Name = $object.Name
        if (Test-Path -Path $object) {
            $this.Path = $object | Resolve-Path -Relative
        } else {
            $this.Path = $null
        }
    }

    [void] GetChildItems ($property, $class) {
        $count = 0
        while ($count -lt $property.Count) {
            $item = Get-Item ($property[$count] | Resolve-Path -Relative)
            $item = $class::new($item)
            $property[$count] = $item
            $count++
        }
    }

    WixFSObject(){
    }

    WixFSObject($obj){
        $this.GetName($obj)
        $this.GetSubElements($obj)
        $this.GetChildItems()
    }
}

class CreateFolder : Wix {
    [array]$attributeNames
    [string]$Directory

    CreateFolder ($obj) {
        $this.attributeNames += "Directory"
        $this.Directory = $obj.Name
    }
}


class Directory : WixFSObject {
    [array]$attributeNames = @(
        "ID",
        "Name"
    )
    [array]$childFiles
    [array]$childDirs
    [array]$childComponents
    [array]$createdFolders

    [void]CreateComponent () {
        if ($this.childFiles) {
            $comp = [Component]::new($this)
            $comp.SubItems = $this.childFiles
            $this.childComponents += $comp
        }
    }

    [void]SortItems () {
        $count = 0
        while ($count -lt $this.SubItems.Count) {
            $item = $this.SubItems[$count]
            if ($item.PsIsContainer) {
                $this.childDirs += $item
                $this.createdFolders += $item
            } else {
                $this.childFiles += $item
            }
            $count++
        }
    }

    [void]CollectItems () {
        $items = @($this.childComponents, $this.createdFolders, $this.childDirs)
        $out = @()
        foreach ($item in $items -ne $null) {
            $out += $item
        }
        $this.SubItems = $out
    }

    Directory () {
    }

    Directory ($obj) {
        $this.GetName($obj)
        $this.SubItems = Get-ChildItem -Path $this.Path
        $this.SortItems()
        $this.GetChildItems($this.childDirs, [Directory])
        $this.GetChildItems($this.childFiles, [File])
        $this.GetChildItems($this.createdFolders, [CreateFolder])
        $this.CreateComponent()
        $this.CollectItems()
    }
}

class File : WixFSObject {
    [array]$attributeNames = @(
        "ID",
        "Name",
        "Source"
    )
    File ($obj) {
        $this.GetName($obj)
        $this.Source = $this.Path
    }
}

function makeXML {
    param (
        [System.Xml.XmlElement]$parentNode,
        $wixItem
    )
    $attributeNames = $wixItem.attributeNames
    $attributeSet = $wixItem.PSObject.Properties | Where-Object {($_.Name -in $attributeNames) -and ($_.Value)}
    $d = $parentNode.OwnerDocument.CreateElement($wixItem.Type)
    foreach ($attribute in $attributeSet) {
        $d.SetAttribute($attribute.Name,$attribute.Value)
        $parentNode.AppendChild($d)
    }
    if ($wixItem.SubItems) {
        foreach ($item in $wixItem.SubItems) {
            makeXML $d $item
        }
    }
}

$Location = "C:\Users\Administrator\Desktop\AZK_History\1\azkplan"
Set-Location $Location
$RootDir = Get-Item $Location
$RootDir = [Directory]::new($RootDir)

$productNameNode = [Directory]::new()
$productNameNode.ID = "ProductID"
$productNameNode.Name = "ProductName"
$productNameNode.SubItems = $RootDir

$installLocationNode = [Directory]::new()
$installLocationNode.ID = "ProgramFilesFolder"
$installLocationNode.Name = "PFiles"
$installLocationNode.SubItems = $productNameNode

$targetDirNode = [Directory]::new()
$targetDirNode.ID = "TARGETDIR"
$targetDirNode.Name = "SourceDir"
$targetDirNode.SubItems = $installLocationNode

$mainDocument = New-Object -TypeName System.Xml.XmlDocument
$decl = $mainDocument.CreateXmlDeclaration('1.0','windows-1251','')
$WixRoot = $mainDocument.CreateElement("Wix")
$WixRoot.SetAttribute("xmlns",'http://schemas.microsoft.com/wix/2006/wi')
$mainDocument.InsertBefore($decl,$mainDocument.DocumentElement)
$mainDocument.AppendChild($WixRoot)

makeXML $WixRoot $targetDirNode

$mainDocument.Save('C:\mainDocument.xml')
<#
TODO:
function for creating root node
get product name
get attributeSet
#>