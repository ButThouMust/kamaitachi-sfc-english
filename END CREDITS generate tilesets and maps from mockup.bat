prompt $g

@set srcPath=".\src"

@set inputImage=".\end credits\credits mockup tileset attempt 1.png"
@set tileset8=".\end credits\TILESET test credits 8x8.bin"
@set tilemap8=".\end credits\TILEMAP test credits 8x8.bin"
@set tilemap24=".\end credits\TILEMAP test credits 16x24.bin"
@set tileset24=".\end credits\TILESET test credits 16x24.bin"
@set widthInTiles=30
@set heightInTiles=144

@set blockWidth=16
@set blockHeight=24

@set creditsSizes=".\end credits\credits line widths.csv"

.\superfamiconv.exe -i %inputImage% -t %tileset8% -m %tilemap8% -F -B 1
.\superfamiconv.exe -i %inputImage% -m %tilemap24% -F -B 1 -W %blockWidth% -H %blockHeight%

javac %srcPath%\credits_font\Convert8x8TilesetTo24x24Tileset.java
java -classpath %srcPath% credits_font.Convert8x8TilesetTo24x24Tileset %tilemap24% %tilemap8% %tileset8% %tileset24% %widthInTiles% %heightInTiles%

javac %srcPath%\credits_font\ExtractCreditTilemaps.java
java -classpath %srcPath% credits_font.ExtractCreditTilemaps %tilemap24% %creditsSizes%
pause
