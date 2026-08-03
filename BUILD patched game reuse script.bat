:: turn off printing the full path to current directory
prompt $g

@set jpROM=".\rom\Kamaitachi no Yoru (Japan).sfc"
@set targetROM=".\rom\Kamaitachi no Yoru (test patched game).sfc"

copy /y %jpROM% %targetROM%

:: create the files if they do not already exist
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

tools\asar.exe "asm/MAIN recompress repoint gfx.asm" %targetROM%
tools\Atlas.exe %targetROM% ".\script\ATLAS uncomp text, useful constants.txt" > ".\logs\atlas log special chars.txt"
tools\asar.exe "asm\MAIN insert text.asm" %targetROM%

tools\flips.exe --create --bps-delta %jpROM% %targetROM% "patches\kamaitachi_sfc_english.bps"
