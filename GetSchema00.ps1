# Get WIX XML schema from URL
$xsdURL = Invoke-WebRequest -Uri https://raw.githubusercontent.com/icsharpcode/SharpDevelop/master/data/schemas/wix.xsd
$wixSchema = $xsdURL.Content

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