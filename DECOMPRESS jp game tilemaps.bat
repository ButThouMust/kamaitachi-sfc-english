prompt $g

@set srcPath=".\src"

javac .\src\tilemaps\decompression\KamaitachiTilemapDumper.java .\src\tilemaps\constants\*.java
java -classpath %srcPath% tilemaps.decompression.KamaitachiTilemapDumper
pause
