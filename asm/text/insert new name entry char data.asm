includefrom "MAIN insert text.asm"

; ------------------------------------------------------------------------------

!RowsPerScreen = $9
!CharsPerRow = $A
!BytesPerChar = $2
!BytesPerCharRow = !CharsPerRow*!BytesPerChar
!BytesPerCharScreen = !RowsPerScreen*!BytesPerCharRow

!StartOfKanjiPtrTable = $01B0D3
!EndOfKanjiPtrTable = $01B129

; pre-fill the character encoding list with all spaces (0000)
org $01b12b
StartOfNameEntryCharData:
    fillbyte $00
    fill $01bbb3-pc()

; 1st character in data block is a space; write the character to use as "char
; slot not filled in yet" for the name
org StartOfNameEntryCharData+$2
UnderscoreInNameEntryCharData:
    dw readfile2("script/bank 04 punctuation.bin", $2)

; for some reason, original JP game had the letters A-F here but don't use them;
; in the interest of not having to repoint, sacrifice 12 bytes of empty space
skip $2*$6

; fill in new char data for the former hiragana and katakana screens
assert filesize("script/name entry char data.bin") == 2*!BytesPerCharScreen
Page1NameEntryCharData:
    incbin "script/name entry char data.bin"

; 
; org $01b0ad
; NameEntryPtrTable:
    ; dw StartOfNameEntryCharData
    ; dw Page1NameEntryCharData

; for row = 1..2*!RowsPerScreen*!CharsPerRow
    ; dw !row*!BytesPerCharRow+read2(NameEntryPtrTable+2*!row)
; endfor
