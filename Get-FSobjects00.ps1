function GenGuid {
    # There are no parameters, just generate Guid in UPPERCASE
    $newGuid = (New-Guid).Guid.ToUpper()
    return $newGuid
}

# Get WIX XML Schema from local path
$xsdPath = "C:\wix.xsd"
# Get WIX XML schema from URL
$xsdURL = Invoke-WebRequest -Uri https://raw.githubusercontent.com/icsharpcode/SharpDevelop/master/data/schemas/wix.xsd

if ($xsdURL.Content) {
    $wixSchema = $xsdURL.Content
} else {
    $wixSchema = Get-Content -Path $xsdPath
}

# Load schema
$wiXSD = New-Object -TypeName System.Xml.XmlDocument
$wiXSD.LoadXml($wixSchema)

# Select elements
$schemaElements = $wiXSD.ChildNodes.Where({$_.NodeType -eq "Element"})

class Wix {
    $schemaEl = $schemaElements
    [string]$Type = $this.GetType().Name
    [string]$Id
    [string]$Name
    [string]$xmlns = "http://schemas.microsoft.com/wix/2006/wi"
    $Parent
    [array]$SubItems
    [array]$attributeNames = @()

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

    [void] getValidAttributes ([string]$elementType, $schema) {
        $el = $schema.element.Where({$_.name -eq $elementType})
        if ($elementType -eq "Wix") {
            $this.attributeNames += "xmlns"
        }
        if ($el.complexType) {
            $this.attributeNames += $el.complexType.attribute.name
        } else {
            $this.attributeNames += $el.Attributes.Value
        }
    }

    Wix () {
        $this.IDasGUID()
        $this.getValidAttributes($this.Type, $this.schemaEl)
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
    [ValidateSet("yes","no")]
    [string]$Compressed #= "yes"
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

    Component ($obj) {
        $this.Guid = GenGuid
        $this.IDbyName()
    }
}

class Media : Wix {
    [ValidatePattern('((\d+)|(\$\(\w+\.(\w|[.])+\)))+', Options = "None")]
    [string]$Id
    [string]$Cabinet #= "cabinet.cab"
    [ValidateSet("mszip", "high", "low", "medium", "none")]
    [string]$CompressionLevel #= "mszip"
    [string]$DiskPrompt
    [ValidateSet("yes","no")]
    [string]$EmbedCab #= "yes"
    [string]$Layout
    [string]$Source
    [string]$VolumeLabel
}

class ComponentRef : Wix {
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
    [string]$Directory

    CreateFolder ($obj) {
        $this.GetName($obj)
        $this.Directory = $this.Id
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

    Feature () {
        $this.IDbyName()
    }
}


class Directory : WixFSObject {
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
    File ($obj) {
        $this.GetName($obj)
        $this.Source = $this.Path
    }
}

function makeXML {
    param (
        [System.Xml.XmlElement]$xmlNode,
        [System.Object]$wixObject
    )
    [array]$attributeNames = $wixObject.attributeNames
    [array]$attributeSet = $wixObject.PSObject.Properties | Where-Object {($_.Name -in $attributeNames) -and ($_.Value)}
    foreach ($attributePair in $attributeSet) {
        $xmlNode.SetAttribute($attributePair.Name, $attributePair.Value)
    }
    if ($wixObject.SubItems) {
        foreach ($item in $wixObject.SubItems) {
            $childNode = $xmlNode.OwnerDocument.CreateElement($item.Type)
            $xmlNode.AppendChild($childNode)
            makeXML $childNode $item
        }
    }
}

$Location = "C:\Users\Administrator\Desktop\AZK_History\1\"
Set-Location $Location

$MainExecutableName = "maincontroller.exe"

$MainExecutable = $null
$MainExecutable = Get-ChildItem -Path $Location.Path -Recurse | Where-Object {$_.Name -eq $MainExecutableName}
$RootDir = Get-Item $MainExecutable.Directory
$RootDir = [Directory]::new($RootDir)

function assignParent {
    param (
        [System.Object]$parent,
        [System.Object]$child
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

$ComponentRefArray = @()
$ComponentRefArray = CollectComponents $RootDir

$featureNode.SubItems = foreach ($refId in $ComponentRefArray) {
    [ComponentRef]::new($refId)
}
foreach ($item in $featureNode.SubItems) {$item.Parent = $featureNode}

assignParent $productNode $featureNode

$WX = [Wix]::new()
assignParent $WX $productNode

$mainDocument = New-Object -TypeName System.Xml.XmlDocument
$decl = $mainDocument.CreateXmlDeclaration('1.0','windows-1251','')
$WixRoot = $mainDocument.CreateElement($WX.Type)

$mainDocument.InsertBefore($decl,$mainDocument.DocumentElement)
$mainDocument.AppendChild($WixRoot)

makeXML $WixRoot $WX

$prodPath = (Join-Path -Path $Location -ChildPath $MainExecutable.BaseName) + ".wxs"

$mainDocument.Save('C:\mainDocument.xml')
$mainDocument.Save($prodPath)

<#
TODO:
function for creating root node
method for creating childitem
work with shortcuts
separate "Directory" and "File" elements with "DirectoryRef"
get valid childElements
#>