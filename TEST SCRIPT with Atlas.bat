
:: turn off printing the full path to current directory
prompt $g

:: @set srcPath=".\src"

:: @javac .\src\generate_font\*.java .\src\header_files\*.java

:: #############################################################################
:: #############################################################################
:: #############################################################################

:: generate files related to the font:
:: - font in the game's expected format
:: - table files for the font (both big and little endian) 
:: - a binary file w/ character encodings that should trigger auto line breaks

:: java -classpath %srcPath% generate_font/FontInserterDriver "./font/otogirisou font dimensions left align.tbl" "./font/otogirisou font.png" 000000 16 16

:: #############################################################################
:: #############################################################################
:: #############################################################################

:: Set several variables to hopefully keep the batch file easier to understand
:: and maintain/edit.

@set jpROM=".\rom\Kamaitachi no Yoru (Japan).sfc"
@set uncompScriptROM=".\rom\Kamaitachi no Yoru - EN uncompress.sfc"
@set scriptTranslationFile=".\script\script dump.txt"

:: #############################################################################
:: #############################################################################
:: #############################################################################

:: use the new table file with Atlas to get the script in uncompressed format
@copy /y %jpROM% %uncompScriptROM%
atlas.exe %uncompScriptROM% %scriptTranslationFile%
pause

@del %uncompScriptROM%
