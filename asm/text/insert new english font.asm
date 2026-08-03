includefrom "asm/MAIN insert text.asm"

; insert the new font and its metadata tables

!FontPtrTableFile = "font/font pointer table.bin"

NewFontDataLocation:
    incbin "font/new font data.bin"
NewFontGroupSizesTable:
    incbin "font/font size table.bin"
NewFontDimensionsTable:
; even bytes pack 4-bit W and 4-bit H
    incbin "font/font dimension table.bin"
; odd bytes contain product W*H
!NewFontSizesInBitsTable = NewFontDimensionsTable+1

NewFontPtrTable:
    !NumFontPtrs #= filesize("!FontPtrTableFile")/3
    ; !NumFontPtrs #= !NumFontPtrs/3
    for i = 0..!NumFontPtrs
        FontPtr!i = readfile3("!FontPtrTableFile",3*!i)
        dl pctosnes(snestopc(NewFontDataLocation)+FontPtr!i)
    endfor

pushpc

; ----------

; repoint the metadata tables

; font group sizes were originally at $01A736
org $00a04e
    ; clear font data for "wait for input" icon, either cursor or next page
    dw NewFontGroupSizesTable
org $00a31e
    ; add char width to text position
    dw NewFontGroupSizesTable
org $01e22c
    ; get char width in A register
    dw NewFontGroupSizesTable
org $02a03b
    ; read raw character data
    dw NewFontGroupSizesTable
; org $049561
    ; for centering char in 0xF-pixel-wide region
    ; dw NewFontGroupSizesTable
; org $04956a
    ; for centering char in 0xF-pixel-wide region
    ; dw NewFontGroupSizesTable

; font dimensions were originally at $01A7A0
org $00a057
    ; clear font data for "wait for input" icon, either cursor or next page
    dw NewFontDimensionsTable
org $00a329
    ; add char width to text position
    dw NewFontDimensionsTable
org $01e233
    ; get char width in A register
    dw NewFontDimensionsTable
org $02a048
    ; read raw character data
    dw NewFontDimensionsTable
; org $049574
    ; read width for centering char in 0xF-pixel-wide region
    ; dw NewFontDimensionsTable

; font sizes in bits were originally at $01A7A1
org $02a057
    ; calculate W*H * (# chars in range) to get offset to raw character data
    dw !NewFontSizesInBitsTable
org $02a07a
    ; calculate value (W*H / 8) + 2
    dw !NewFontSizesInBitsTable

; font ptr table was originally at $01A80A
; both of these updated pointers are for reading raw character data
org $02a088
    dw NewFontPtrTable
org $02a090
    dw NewFontPtrTable+1

; ------------------------------------------------------------------------------

pullpc
print "PC after font metadata tables: $",hex(pc())
