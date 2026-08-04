:: turn off printing the full path to current directory
prompt $g

@set srcPath=".\src"

javac .\src\tilemaps\decompression\KamaitachiTilemapDumper.java .\src\tilemaps\compression\KamaitachiTilemapRecompressionImproveRanges.java .\src\tilemaps\constants\TilemapCompConstants.java
pause
java -classpath %srcPath% tilemaps.compression.KamaitachiTilemapRecompressionImproveRanges
java -classpath %srcPath% tilemaps.compression.KamaitachiTilemapRecompressionImproveRanges "./recompressed tilemaps/$46C1B8 combined tilemap.bin"
java -classpath %srcPath% tilemaps.compression.KamaitachiTilemapRecompressionImproveRanges "./gfx/new opening credits/credits map.bin"
