$offerDropLocation = "offers"
New-Item -ItemType Directory -Force -Path $offerDropLocation

$offerNames=(Get-ChildItem -Path . -Directory -Name -Force | Select-String eap.*rhel)
foreach ($offerName in $offerNames) {
    $compress = @{
        LiteralPath      = (Join-Path "$offerName" "scripts"), (Join-Path "$offerName" "createUiDefinition.json"), (Join-Path "$offerName" "mainTemplate.json")
        CompressionLevel = "Fastest"
        DestinationPath  = (Join-Path "$offerDropLocation" "$offerName.zip")
    }
    Compress-Archive @compress -Force
}