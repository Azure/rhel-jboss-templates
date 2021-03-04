$offerDropLocation = "offers"
New-Item -ItemType Directory -Force -Path $offerDropLocation

$offerNames=(Get-ChildItem -Path . -Directory -Force -ErrorAction SilentlyContinue | Select-String eap)
foreach ($offerName in $offerNames) {
    $compress = @{
        LiteralPath      = "$offerName\scripts\", "$offerName\createUiDefinition.json", "$offerName\mainTemplate.json"
        CompressionLevel = "Fastest"
        DestinationPath  = "$offerDropLocation\$offerName.zip"
    }
    Compress-Archive @compress
}