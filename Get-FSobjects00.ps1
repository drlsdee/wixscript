enum YesNoType {
    yes
    no
}

class FSobject {
    [ValidateSet("File","Directory")]
    [string]$Type
    [string]$Id
    [string]$Name
    [array]$SubItems
    [string]$Path
    [string]$Source
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
        if (Test-Path -Path $obj) {
            $this.Path = $obj | Resolve-Path -Relative
        } else {
            $this.Path = $null
        }
        $this.Depth = 1
        If (Test-Path -Path $obj -PathType Container) {
            $this.Type = "Directory"
            $this.Source = $null
            $this.SubItems = Get-ChildItem -Path $this.Path #| Where-Object {$_.Attributes -notmatch $ignoreList}
        } Else {
            $this.Type = "File"
            $this.Source = $this.Path
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
    [string]$Id
    [string]$Name
    [string]$Manufacturer
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
    [ValidateSet("Yes","No")]
    [string]$Compressed
    [int]$SummaryCodepage
}

function makeXML {
    param (
        [System.Xml.XmlElement]$parentNode,
        $class
    )
    $attributeNames = @(
        "ID",
        "Name",
        "Source"
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

$productNameNode =  [FSobject]::new()
$productNameNode.Type = "Directory"
$productNameNode.Id = "ProductID"
$productNameNode.Name = "ProductName"
$productNameNode.SubItems = $RootDir

$installLocationNode = [FSobject]::new()
$installLocationNode.Type = "Directory"
$installLocationNode.Id = "ProgramFilesFolder"
$installLocationNode.Name = "PFiles"
$installLocationNode.SubItems = $productNameNode

$targetDirNode = [FSobject]::new()
$targetDirNode.Type = "Directory"
$targetDirNode.Id = "TARGETDIR"
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
create XML element "Component" for files and create XML element "CreateFolder" for subfolders
#>