function GenGuid {
    # There are no parameters, just generate Guid in UPPERCASE
    $newGuid = (New-Guid).Guid.ToUpper()
    return $newGuid
}

class Wix {
    [string]$Type = $this.GetType().Name
    [string]$Id
    [string]$Name
    [string]$xmlns
    $Parent
    [array]$SubItems
    [array]$attributeNames = @("xmlns")

    [void] IDasGUID () {
        if ($this.Id -eq $null) {
            $this.Id = GenGuid
        }
    }

    [void] IDbyName () {
        $cleaned = (GenGUID) -replace "-", "_"
        if ($this.BaseName) {
            $this.Id = ("_", $this.BaseName -join "_")
        } elseif ($this.Name) {
            $this.Id = ("_", $this.Name -join "_")
        } else {
            $this.Id = "_", $cleaned -join "_"
        }
    }

    Wix () {
        $this.IDasGUID()
        $this.xmlns = "http://schemas.microsoft.com/wix/2006/wi"
    }
}

class Product : Wix {
    [array]$attributeNames = @(
        "Name",
        "Manufacturer",
        "UpgradeCode",
        "Language",
        "Codepage",
        "Version",
        "Id"
        )
    [string]$Name
    [string]$Manufacturer
    [string]$UpgradeCode
    [int]$Language
    [int]$Codepage
    [string]$Version

    Product ($main) {
        $this.Name = $main.VersionInfo.ProductName
        $this.Manufacturer = $main.VersionInfo.CompanyName
        $this.UpgradeCode = GenGuid
        $this.Language = [System.Globalization.CultureInfo]::GetCultures("AllCultures").Where({$_.DisplayName -eq $main.VersionInfo.Language}).LCID
        $this.Codepage = [System.Globalization.CultureInfo]::GetCultures("AllCultures").Where({$_.DisplayName -eq $main.VersionInfo.Language}).TextInfo.ANSICodePage
        $this.Version = $main.VersionInfo.FileVersion
    }
}

class Package : Wix {
    [array]$attributeNames = @(
        "Comments",
        "Compressed",
        "Description",
        "Id",
        "InstallerVersion",
        "Keywords",
        "Languages",
        "Manufacturer",
        "SummaryCodepage"
        )
    [string]$Keywords
    [string]$Description
    [string]$Comments
    [string]$Manufacturer
    [string]$InstallerVersion
    [int]$Languages
    [ValidateSet("yes","no")]
    [string]$Compressed = "yes"
    [int]$SummaryCodepage

    Package ($main) {
        $this.Description = $main.VersionInfo.FileDescription
        $this.Comments = $main.VersionInfo.LegalCopyright
        $this.Manufacturer = $main.VersionInfo.CompanyName
        $this.Languages = [System.Globalization.CultureInfo]::GetCultures("AllCultures").Where({$_.DisplayName -eq $main.VersionInfo.Language}).LCID
        $this.SummaryCodepage = [System.Globalization.CultureInfo]::GetCultures("AllCultures").Where({$_.DisplayName -eq $main.VersionInfo.Language}).TextInfo.ANSICodePage
        $this.Id = "*" # TODO: If parent is "Product", Id = *; if parent is "Module", Id = GUID
    }
}

class Component : Wix {
    [string]$Guid
    [array]$attributeNames = @(
        "Id",
        "Guid"
    )

    Component ($obj) {
        $this.Guid = GenGuid
        $this.IDbyName()
    }
}

class Media : Wix {
    [array]$attributeNames = @(
        "Id",
        "Cabinet",
        "CompressionLevel",
        "DiskPrompt",
        "EmbedCab",
        "Layout",
        "Source",
        "VolumeLabel"
        )
    [ValidatePattern('((\d+)|(\$\(\w+\.(\w|[.])+\)))+', Options = "None")]
    [string]$Id
    [string]$Cabinet = "cabinet.cab"
    [ValidateSet("mszip", "high", "low", "medium", "none")]
    [string]$CompressionLevel = "mszip"
    [string]$DiskPrompt
    [ValidateSet("yes","no")]
    [string]$EmbedCab = "yes"
    [string]$Layout
    [string]$Source
    [string]$VolumeLabel
}


class ComponentRef : Wix {
    [array]$attributeNames = @(
        "Id",
        "Primary"
        )
    [ValidateSet("yes","no")]
    [string]$Primary

    ComponentRef ($obj) {
        $this.Id = $obj.Id
    }
}

class WixFSObject : Wix {
    [string]$Path
    [string]$Source

    [void] GetName ($object) {
        $this.Name = $object.Name
        if (Test-Path -Path $object) {
            $this.Path = $object | Resolve-Path -Relative
        } else {
            $this.Path = $null
        }
        $this.IDbyName()
    }

    [void] GetChildItems ($property, $class) {
        $count = 0
        while ($count -lt $property.Count) {
            $item = Get-Item ($property[$count] | Resolve-Path -Relative)
            $item = $class::new($item)
            $item.Parent = $this
            $property[$count] = $item
            $count++
        }
    }

    WixFSObject(){
    }

    WixFSObject($obj){
        $this.GetName($obj)
        $this.GetChildItems()
    }
}

class CreateFolder : WixFSObject {
    [array]$attributeNames = @("Directory")
    [string]$Directory

    CreateFolder ($obj) {
        $this.GetName($obj)
        $this.Directory = $this.Id
    }
}

class Feature : WixFSObject {
    [array]$attributeNames = @(
        "Id",
        "Absent",
        "AllowAdvertise",
        "ConfigurableDirectory",
        "Description", "Display",
        "InstallDefault",
        "Level",
        "Title",
        "TypicalDefault"
        )
    [ValidateSet("allow","disallow")]
    [string]$Absent
    [ValidateSet("no","system","yes")]
    [string]$AllowAdvertise
    [string]$ConfigurableDirectory
    [string]$Description
    [ValidateSet("collapse","expand","hidden")]
    [string]$Display
    [ValidateSet("followParent","local","source")]
    [string]$InstallDefault
    [int]$Level
    [string]$Title
    [ValidateSet("advertise","install")]
    [string]$TypicalDefault

    Feature () {
        $this.IDbyName()
    }
}


class Directory : WixFSObject {
    [array]$attributeNames = @(
        "Id",
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
            foreach ($subFolder in $this.createdFolders) {
                $comp.SubItems += $subFolder
            }
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
        $items = @($this.childComponents, $this.childDirs)
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
        "Id",
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
        [System.Object]$wixItem
    )
    [array]$attributeNames = $wixItem.attributeNames
    [array]$attributeSet = $wixItem.PSObject.Properties | Where-Object {($_.Name -in $attributeNames) -and ($_.Value)}
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

function makeXML2 {
    param (
        [System.Xml.XmlElement]$xmlNode,
        [System.Object]$wixObject
    )
    [array]$attributeNames = $wixObject.attributeNames
    [array]$attributeSet = $wixObject.PSObject.Properties | Where-Object {($_.Name -in $attributeNames) -and ($_.Value)}
    foreach ($attributePair in $attributeSet) {
        $xmlNode.SetAttribute($attributePair.Name, $attributePair.Value)
    }
}

$Location = "C:\Users\Administrator\Desktop\AZK_History\1\"
Set-Location $Location

$ComponentRefArray = @()

$MainExecutableName = "maincontroller.exe"
$MainExecutable = Get-ChildItem -Path $Location.Path -Recurse | Where-Object {$_.Name -eq $MainExecutableName}
$RootDir = Get-Item $MainExecutable.Directory
$RootDir = [Directory]::new($RootDir)

function assignParent {
    param (
        $parent,
        $child
    )
    $parent.SubItems += $child
    $child.Parent = $parent
}

$packageNode = [Package]::new($MainExecutable)

$productNameNode = [Directory]::new()
$productNameNode.Id = "ProductId"
$productNameNode.Name = $productNode.Name

assignParent $productNameNode $RootDir

$installLocationNode = [Directory]::new()
$installLocationNode.Id = "ProgramFilesFolder"
$installLocationNode.Name = "PFiles"

assignParent $installLocationNode $productNameNode

$targetDirNode = [Directory]::new()
$targetDirNode.Id = "TARGETDIR"
$targetDirNode.Name = "SourceDir"

assignParent $targetDirNode $installLocationNode

$mediaNode = [Media]::new()
$mediaNode.Id = "1"

$productNode = [Product]::new($MainExecutable)

assignParent $productNode $packageNode

assignParent $productNode $mediaNode

assignParent $productNode $targetDirNode

$featureNode = [Feature]::new()

function CollectComponents {
    param (
        $parentItem
    )
    foreach ($childcomp in $parentItem.childComponents) {
        $comps += $childcomp
    }
    if ($parentItem.childDirs) {
        foreach ($dir in $parentItem.childDirs) {
            CollectComponents $dir
        }
    }
    return $comps
}

$ComponentRefArray = CollectComponents $RootDir

$featureNode.SubItems = foreach ($refId in $ComponentRefArray) {
    [ComponentRef]::new($refId)
}
foreach ($item in $featureNode.SubItems) {$item.Parent = $featureNode}

assignParent $productNode $featureNode

$WX = [Wix]::new()

$mainDocument = New-Object -TypeName System.Xml.XmlDocument
$decl = $mainDocument.CreateXmlDeclaration('1.0','windows-1251','')
$WixRoot = $mainDocument.CreateElement($WX.Type)
makeXML2 $WixRoot $WX
$mainDocument.InsertBefore($decl,$mainDocument.DocumentElement)
$mainDocument.AppendChild($WixRoot)

makeXML $WixRoot $productNode

$prodPath = (Join-Path -Path $Location -ChildPath $MainExecutable.BaseName) + ".wxs"

$mainDocument.Save('C:\mainDocument.xml')
$mainDocument.Save($prodPath)

<#
TODO:
function for creating root node
get attributeSet
get valid childElements
#>