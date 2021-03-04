$offername = "eap73-rhel8-byos"
$offerDropLocation = "offers"

New-Item -ItemType Directory -Force -Path $offerDropLocation

$compress = @{
    LiteralPath      = "$offername\scripts\", "$offername\createUiDefinition.json", "$offername\mainTemplate.json"
    CompressionLevel = "Fastest"
    DestinationPath  = "$offerDropLocation\$offername.zip"
}
Compress-Archive @compress


$offername = "eap73-rhel8-byos-multivm"
$compress = @{
    LiteralPath      = "$offername\scripts\", "$offername\createUiDefinition.json", "$offername\mainTemplate.json"
    CompressionLevel = "Fastest"
    DestinationPath  = "$offerDropLocation\$offername.zip"
}
Compress-Archive @compress


$offername = "eap73-rhel8-byos-vmss"
$compress = @{
    LiteralPath      = "$offername\scripts\", "$offername\createUiDefinition.json", "$offername\mainTemplate.json"
    CompressionLevel = "Fastest"
    DestinationPath  = "$offerDropLocation\$offername.zip"
}
Compress-Archive @compress


$offername = "eap73-rhel8-payg"
$compress = @{
    LiteralPath      = "$offername\scripts\", "$offername\createUiDefinition.json", "$offername\mainTemplate.json"
    CompressionLevel = "Fastest"
    DestinationPath  = "$offerDropLocation\$offername.zip"
}
Compress-Archive @compress

$offername = "eap73-rhel8-payg-multivm"
$compress = @{
    LiteralPath      = "$offername\scripts\", "$offername\createUiDefinition.json", "$offername\mainTemplate.json"
    CompressionLevel = "Fastest"
    DestinationPath  = "$offerDropLocation\$offername.zip"
}
Compress-Archive @compress

$offername = "eap73-rhel8-payg-vmss"
$compress = @{
    LiteralPath      = "$offername\scripts\", "$offername\createUiDefinition.json", "$offername\mainTemplate.json"
    CompressionLevel = "Fastest"
    DestinationPath  = "$offerDropLocation\$offername.zip"
}
Compress-Archive @compress