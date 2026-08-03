:: turn off printing the full path to current directory
prompt $g

@set jpROM=".\rom\Kamaitachi no Yoru (Japan).sfc"
@set uncompScriptROM=".\rom\Kamaitachi no Yoru (uncompressed script).sfc"
@set targetROM=".\rom\Kamaitachi no Yoru (test patched game).sfc"
@set translationTableFile=".\tables\inserted font.tbl"
@set srcPath=".\src"

:: @javac .\src\huffman\*.java .\src\generate_font\*.java .\src\header_files\*.java
:: @javac .\src\generate_font\*.java

:: #############################################################################
:: #############################################################################
:: #############################################################################

:: generate files related to the font:
:: - font in the game's expected format
:: - table files for the font (both big and little endian) 
:: - a binary file w/ character encodings that should trigger auto line breaks
:: - a file for the grid of characters in the name entry screen (unique format)

javac %srcPath%\font\*.java %srcPath%\huffman\*.java %srcPath%\header_files\*.java
java -classpath %srcPath% font.FontInserterDriver "./font/kamaitachi font dimensions left align.tbl" "./font/kamaitachi font.png" 000000 16 16

javac .\src\lzss\LZSSRecompress.java
java -classpath %srcPath% lzss.LZSSRecompress --files "font/kamaitachi font - name entry char grid data.bin"

copy /y %jpROM% %uncompScriptROM%
tools\Atlas.exe %uncompScriptROM% "script/script dump.txt"

@echo(
@echo Please ensure there were no errors with Atlas
pause

:: :askforinput1
:: @set /P uncompScriptEndPos="Enter the hex offset of the end of the uncompressed script in 'rom/Kamaitachi no Yoru (uncompressed script).sfc': "

:: Be sure to delete the previous Huffman script so that the new script gets
:: written into a completely fresh, blank file. Avoids instances where the
:: new script is smaller than previous, and the remaining bytes from the old
:: script remain after the end of the new script.
del ".\script\huffman script.bin"

java -classpath %srcPath% huffman.GenerateHuffmanScript %uncompScriptROM% %translationTableFile% 300000
:: java -classpath %srcPath% GenerateHuffmanScript %uncompScriptROM% %translationTableFile% 300000 %uncompScriptEndPos%
:: @if %errorlevel% neq 0 @echo( & goto :askforinput1

pause
del %uncompScriptROM%

copy /y %jpROM% %targetROM%
tools\asar "asm/MAIN recompress repoint gfx.asm" %targetROM%
:: tools\asar "asm/edit data for silh ctrl code inputs 2dd 2de.asm" %targetROM%

pause

:: create the file if it does not already exist
@copy /y NUL "script/chapter text spelled out.bin" >> NUL
@copy /y NUL "script/fake out choice text.bin" >> NUL
@copy /y NUL "script/bank 04 punctuation.bin" >> NUL
@copy /y NUL "script/tooru default name.bin" >> NUL
@copy /y NUL "script/mari default name.bin" >> NUL
@copy /y NUL "script/name entry char data.bin" >> NUL
@copy /y NUL "script/culprit names text data.bin" >> NUL
tools\Atlas.exe "script/chapter text spelled out.bin" "script/ATLAS chapter spelled out for bookmark.txt" >> NUL
tools\Atlas.exe "script/fake out choice text.bin" "script/fake out choice text.txt" >> NUL
tools\Atlas.exe "script/bank 04 punctuation.bin" "script/ATLAS punctuation pointed to in bank 04.txt" >> NUL
tools\Atlas.exe "script/tooru default name.bin" "script/ATLAS tooru default name.txt" >> NUL
tools\Atlas.exe "script/mari default name.bin" "script/ATLAS mari default name.txt" >> NUL
tools\Atlas.exe "script/name entry char data.bin" "script/ATLAS name entry char TEXT encodings.txt" >> NUL
tools\Atlas.exe "script/culprit names text data.bin" "script/ATLAS culprit name lists.txt" >> NUL

tools\Atlas.exe %targetROM% ".\script\ATLAS uncomp text, useful constants.txt" > ".\logs\atlas log special chars.txt"
tools\asar.exe "asm\MAIN insert text.asm" %targetROM%

:askforinput1
@set /P huffScriptEndPos="Enter the hex offset of the end of the Huffman script in 'rom/Kamaitachi no Yoru (test patched game).sfc': "

java -classpath %srcPath% huffman.HuffScriptDumper %targetROM% %translationTableFile% 22618 %huffScriptEndPos%

@if %errorlevel% neq 0 @echo( & goto :askforinput1

tools\flips.exe --create --bps-delta %jpROM% %targetROM% "patches\kamaitachi_sfc_english.bps"
