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

# Get elements with complexType
$compTypes = $schemaElements.element.Where({$_.complexType})

# Get other elements
$otherTypes = $schemaElements.element.Where({!$_.complexType})
$otherTypes

# Get attributes with simpleType
$compTypes[62].complexType.attribute.Where({!$_.type})

# Get attributes with simple defined types
$compTypes[62].complexType.attribute.Where({$_.type})

# Get attribute names for other elements
$otherTypes[5].Attributes.Value

function getAttributeNames {
    param (
        [string]$elementType
    )
    $el = $schemaElements.element.Where({$_.name -eq $elementType})
    $nameArr = @()
    if ($el.complexType) {
        $nameArr += $el.complexType.attribute.name
    } else {
        $nameArr += $el.Attributes.Value
    }
    return $nameArr
}

$testArr = getAttributeNames "Product"
$testArr