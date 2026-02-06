prompt $g

@set srcPath=".\src"

javac .\src\tilesets\decompression\KamaitachiTileDumper.java .\src\tilesets\constants\*.java
java -classpath %srcPath% tilesets.decompression.KamaitachiTileDumper
pause
