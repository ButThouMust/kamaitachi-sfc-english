$srcPath=".\src"
$class="tilesets.compression.KamaitachiTilesetRecompression"

echo "Compiling..."
javac .\src\tilesets\compression\*.java .\src\tilesets\constants\*.java .\src\tilesets\tag_bitplane\*.java .\src\tilesets\tag_tile\*.java
pause

java -classpath $srcPath $class "./gfx/new opening credits/credits tiles.bin"
java -classpath $srcPath $class $(ls "decompressed tilesets from JP game/*.bin" | % {"decompressed tilesets from JP game/$($_.Name)"})
# java -classpath $srcPath $class "decompressed tilesets from JP game/decompressed tileset 00.bin"

# source for using wildcards in PowerShell; this was frustrating to find :P
# https://superuser.com/a/899995
