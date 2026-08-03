:: turn off printing the full path to current directory
prompt $g

@set srcPath=".\src"

@javac .\src\lzss\LZSSRecompress.java
java -classpath %srcPath% lzss.LZSSRecompress --offsets 04C004 04DD73 5F8000 5FC9A2 5FCE57 5FD15B 5FD564 5FD7E7 5FA34C 5FA37A 5FA3C4 5FA42A 5FA4AE 5FA548 5FA600 5FA6D0 5FA7BE 5FA8C7 5FA9EC 5FAB2F 5FAC8B 5FADF6
:: java -classpath %srcPath% lzss.LZSSRecompress --files "gfx/LZ decompress $5E8000.bin"
java -classpath %srcPath% lzss.LZSSRecompress --files "font/kamaitachi font - name entry char grid data.bin"