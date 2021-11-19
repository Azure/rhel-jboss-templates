$offerDropLocation = "offers"
New-Item -ItemType Directory -Force -Path $offerDropLocation

$offerNames=(Get-ChildItem -Path . -Include mainTemplate.json -Recurse -Name | Split-Path)
foreach ($offerName in $offerNames) {
    $compress = @{
        LiteralPath      = (Join-Path "$offerName" "scripts"), (Join-Path "$offerName" "createUiDefinition.json"), (Join-Path "$offerName" "mainTemplate.json")
        CompressionLevel = "Fastest"
        DestinationPath  = (Join-Path "$offerDropLocation" "$offerName.zip")
    }
    Compress-Archive @compress -Force
}