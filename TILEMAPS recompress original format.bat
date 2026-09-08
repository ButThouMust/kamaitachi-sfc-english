:: turn off printing the full path to current directory
prompt $g

@set srcPath=".\src"

javac .\src\tilemaps\decompression\KamaitachiTilemapDumper.java .\src\tilemaps\compression\KamaitachiTilemapRecompression.java .\src\tilemaps\constants\TilemapCompConstants.java .\src\tilemaps\compression\*Tag.java .\src\tilemaps\compression\*Type.java
pause

:: java -classpath %srcPath% tilemaps.compression.KamaitachiTilemapRecompression
:: java -classpath %srcPath% tilemaps.compression.KamaitachiTilemapRecompression "./recompressed tilemaps/$46C1B8 combined tilemap.bin"
java -classpath %srcPath% tilemaps.compression.KamaitachiTilemapRecompression "./gfx/new opening credits/credits map.bin"
