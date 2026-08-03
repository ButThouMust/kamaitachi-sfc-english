:: create the file if it does not already exist
copy /y NUL "font/list of chars for name entry.bin" >> NUL
atlas "font/list of chars for name entry.bin" "script/ATLAS name entry char GFX lookup table.txt"
