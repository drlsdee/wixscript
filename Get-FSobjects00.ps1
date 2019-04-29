function GenGuid {
    # There are no parameters, just generate Guid in UPPERCASE
    $newGuid = (New-Guid).Guid.ToUpper()
    return $newGuid
}

class Wix {
    [string]$Type = $this.GetType().Name
    [string]$Id
    [string]$Name
    $Parent
    [array]$SubItems
    [array]$attributeNames

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
    }
}

class Product : Wix {
    [string]$Name
    [string]$Manufacturer
    [string]$UpgradeCode
    [int]$Language
    [int]$Codepage
    [string]$Version

    Product ($main) {
        $this.attributeNames = @("Name", "Manufacturer", "UpgradeCode", "Language", "Codepage", "Version", "Id")
        $this.Name = $main.VersionInfo.ProductName
        $this.Manufacturer = $main.VersionInfo.CompanyName
        $this.UpgradeCode = GenGuid
        $this.Language = [System.Globalization.CultureInfo]::GetCultures("AllCultures").Where({$_.DisplayName -eq $main.VersionInfo.Language}).LCID
        $this.Codepage = [System.Globalization.CultureInfo]::GetCultures("AllCultures").Where({$_.DisplayName -eq $main.VersionInfo.Language}).TextInfo.ANSICodePage
        $this.Version = $main.VersionInfo.FileVersion
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

    Package ($main) {
        $this.attributeNames = @("Comments", "Compressed", "Description", "Id", "InstallerVersion", "Keywords", "Languages", "Manufacturer", "SummaryCodepage")
        $this.Description = $main.FileDescription
        $this.Comments = $main.LegalCopyright
        $this.Manufacturer = $main.CompanyName
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
    [array]$attributeNames = @("Id", "Cabinet", "CompressionLevel", "DiskPrompt", "EmbedCab", "Layout", "Source", "VolumeLabel")
    [ValidatePattern('((\d+)|(\$\(\w+\.(\w|[.])+\)))+', Options = "None")]
    [string]$Id
    [string]$Cabinet
    [ValidateSet("mszip", "high", "low", "medium", "none")]
    [string]$CompressionLevel
    [string]$DiskPrompt
    [ValidateSet("Yes","No")]
    [string]$EmbedCab
    [string]$Layout
    [string]$Source
    [string]$VolumeLabel
}


class ComponentRef : Wix {
    [ValidateSet("yes","no")]
    [string]$Primary
    [array]$attributeNames = @("Id", "Primary")

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

class CreateFolder : Wix {
    [array]$attributeNames
    [string]$Directory

    CreateFolder ($obj) {
        $this.attributeNames += "Directory"
        $this.Directory = $obj.Id
    }
}

class Feature : WixFSObject {
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
    [array]$attributeNames = @("Id", "Absent", "AllowAdvertise", "ConfigurableDirectory", "Description", "Display", "InstallDefault", "Level", "Title", "TypicalDefault")

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

$ComponentRefArray = @()

$RootDir = Get-Item $Location
$RootDir = [Directory]::new($RootDir)

$MainExecutableName = "maincontroller.exe"
$MainExecutable = Get-ChildItem -Path $RootDir.Path -Recurse | Where-Object {$_.Name -eq $MainExecutableName}

$productNameNode = [Directory]::new()
$productNameNode.Id = "ProductId"
$productNameNode.Name = "ProductName"
$productNameNode.SubItems = $RootDir
$RootDir.Parent = $productNameNode

$installLocationNode = [Directory]::new()
$installLocationNode.Id = "ProgramFilesFolder"
$installLocationNode.Name = "PFiles"
$installLocationNode.SubItems = $productNameNode
$productNameNode.Parent = $installLocationNode

$targetDirNode = [Directory]::new()
$targetDirNode.Id = "TARGETDIR"
$targetDirNode.Name = "SourceDir"
$targetDirNode.SubItems = $installLocationNode
$installLocationNode.Parent = $targetDirNode

$packageNode = [Package]::new($MainExecutable)

$mediaNode = [Media]::new()
$mediaNode.Id = "1"

$productNode = [Product]::new($MainExecutable)
$productNode.SubItems += $packageNode
$packageNode.Parent = $productNode

$productNode.SubItems += $mediaNode
$mediaNode.Parent = $productNode

$productNode.SubItems += $targetDirNode
$targetDirNode.Parent = $productNode

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

$productNode.SubItems += $featureNode
$featureNode.Parent = $productNode

$productNode.Parent = $WixRoot

$mainDocument = New-Object -TypeName System.Xml.XmlDocument
$decl = $mainDocument.CreateXmlDeclaration('1.0','windows-1251','')
$WixRoot = $mainDocument.CreateElement("Wix")
$WixRoot.SetAttribute("xmlns",'http://schemas.microsoft.com/wix/2006/wi')
$mainDocument.InsertBefore($decl,$mainDocument.DocumentElement)
$mainDocument.AppendChild($WixRoot)

makeXML $WixRoot $productNode

$prodPath = (Join-Path -Path ($RootDir.Path | Resolve-Path) -ChildPath $MainExecutable.BaseName) + ".wxs"

$mainDocument.Save('C:\mainDocument.xml')
$mainDocument.Save($prodPath)

<#
TODO:
function for creating root node
get attributeSet
get valid childElements
#>