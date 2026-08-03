includefrom "kamaitachi text printing hacks.asm"

; ------------------------------------------------------------------------------

; ASM hacks for printing text on the file select bookmarks

; Printing the names for Tooru and Mari
!ListTextXYPosNamesForFile = $01818d

org $01dea5
PrintTextForAllBookmarksOnFileSelect01DEA5:
    stz.w $15e3

; start with save file 1
    ldx #$0001
; get the two byte value in save file N at position $078
  - txa
    brk #$1c
    db $17
; if 0, skip to next file
    cmp #$0000
    beq +

    jsr.w PrintTooruAndMariToVramForBookmark01DECC
    jsr.w PrintNumPlaythroughsForFileN
    jsr.w PrintChapterNumberForBookmark
; if the chapter number is 0, do not print the chapter title
    cpy #$0000
    beq +
    jsr.w PrintChapterTitleOnBookmark

  + inx
    cpx.w #$0003+1
    bne -
    rts

; ----------------------------

; this one has [0E 00; 00 00]
!ListByteOffsetsForWritingNamesForFileSelect = $018193

; fix char spacing for printing <Tooru>&<Mari> ('&' was originally 'と')
; need to update branch lengths, and TODO change to 1-byte encoding
PrintTooruAndMariToVramForBookmark01DECC:
    phd
    cop #$00
    db $45
    phx : pha

; get X/Y position based on bookmark number
    dec : asl : tax
    lda.w !ListTextXYPosNamesForFile,x
    sta.w TextXPos

    lda $01,s
    jsr.w GetNamesFromSaveFileIntoTooruAndMari
  ; jsr.w GetXPosToWriteCenteredOneByteEncText ; do one byte encoding
    jsr.w GetXPosToWriteCenteredBookmarkText   ; do two byte encoding
    dec.w TextXPos
    dec.w TextXPos

    ldy #$0002
LoopGetIndexForNameToPrint:
    ldx.w !ListByteOffsetsForWritingNamesForFileSelect,y
LoopPrintName:
    ; get a letter; FFFF is end of name, otherwise print the letter
    lda.b $28,x
    bmi DoneWithPrintingOneName
    jsl ReadFontDataDoTextDma
    ; remove this DEC (originally made char spacing 1 pixel) to save 3 bytes
  ; dec TextXPos
    inx #2
    bra LoopPrintName

DoneWithPrintingOneName:
    ; done with printing one name; check if both names are done
    dey #2
    bmi DoneWithBothNames

    ; advance X pos after Tooru's name for the '&'
    inc.w TextXPos
    inc.w TextXPos
    ; print the &
    lda.b $44
    jsl ReadFontDataDoTextDma

    ; advance X pos after the '&' for Mari's name
    inc.w TextXPos
    ; use space from removing the DEC above to put in another spacing increment
    inc.w TextXPos
    bra LoopGetIndexForNameToPrint

DoneWithBothNames:
    pla : plx : pld
    rts

; ----------

; this one has [00 00; 0E 00]
!ListOffsetsForWritingBookmarkNames018197 = $018197

GetNamesFromSaveFileIntoTooruAndMari:
; get Tooru's name into $28-$35
    pha
    ldy #$0000
    jsr WriteNameFromScratchpadInto1001ForFileSelect
; get Mari's name into $36-$43
    pla
    ldy #$0002
    jsr WriteNameFromScratchpadInto1001ForFileSelect
; write the ampersand (originally "と") after her name
; fix how address of character is hard-coded
    lda.w read2($01DF26)
    sta.b $44
; copy "[Tooru]FFFF[Mari]&" to "[Tooru]&[Mari]FFFF" at $00 for width calc
  ; jsr CombineNamesAndAmpersandIntoOneString
  ; rts
    jmp CombineNamesAndAmpersandIntoOneString

WriteNameFromScratchpadInto1001ForFileSelect:
; use Y reg to read name into RAM
    brk #$1c
    db $15
; write Tooru's name to offset 0, Mari's name to offset E
    ldx.w !ListOffsetsForWritingBookmarkNames018197,y
    ldy #$0000
  - lda.w $1656,y
    bmi +           ; check FFFF terminator in name
    sta $28,x
    inx #2
    iny #2
    cpy #$000c      ; hard limit of 6 chars
    bne -
  + lda #$ffff
    sta $28,x
    rts

; ----------

!ListOffsetsForWritingBookmarkNames01819B = $01819b

CombineNamesAndAmpersandIntoOneString:
    ldy #$fffe

; this is a little convoluted: start with Tooru's name, then do Mari's name
; the data at the pointer is [0E 00 ; 00 00]
    ldx #$0002
LoopPrepToWriteOneName:
    lda.w !ListOffsetsForWritingBookmarkNames01819B,x
    phx
    tax
LoopWriteCharsOfOneName:
    iny #2
; get char value, check for terminator
    lda $28,x
    bmi DoneWithOneName

    phx
    tyx
    sta.b $00,x
    plx
    inx #2
    bra LoopWriteCharsOfOneName

DoneWithOneName:
; write the ampersand after the name
    tyx
    lda $44
    sta.b $00,x
    plx
; check if need to write Mari's name
    dex #2
    bpl LoopPrepToWriteOneName

; if already wrote Mari's name, overwrite the second ampersand with terminator
    tyx
    lda #$ffff
    sta.b $00,x
    rts

; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------

; change the printing logic for the playthrough counter
; print "#NNN" instead of "NNN回"

; !PtrToPoundSign = $01ac5d
!ListTextXYPosPlaythrus = $01819f

!ConvertHexValInAToBCD = $01dfbb
!GetDigitCharsFromBCDBytes = $01e23d
; !SubtractWidthOfStringFromXPos = $01e1d7

; X positions for playthrough counter were originally $30, $70, $b0
; these were for the "回" in "NNN回"; just update to raw position to write to

pushpc
!YPosForPlaythruCtr = $40
org !ListTextXYPosPlaythrus
    db $20,!YPosForPlaythruCtr
    db $60,!YPosForPlaythruCtr
    db $a0,!YPosForPlaythruCtr

pullpc
PrintNumPlaythroughsForFileN:
    phd
    cop #$00
    db $2b
    phx : pha
    dec : asl : tax
    lda.w !ListTextXYPosPlaythrus,x
    sta.w TextXPos

  ; lda.w !PtrToPoundSign
    lda.w PlaythruCtrPoundSign
    jsl ReadFontDataDoTextDma
    inc.w TextXPos

; A <- min(playthrough counter, 999)
    lda $01,s
    brk #$1c
    db $19
    jsr.w !ConvertHexValInAToBCD

    lda #$0003
    jsr.w !GetDigitCharsFromBCDBytes

; original ASM code would subtract the digits' width before printing the 回, so
; that it right aligns the digits to the left of the 回; I'm choosing to forgo
; this and print all the characters left-aligned, partly to simplify stuff here,
; but also since this is the only use for this subroutine
  ; jsr.w !SubtractWidthOfStringFromXPos

    ldx #$0000
LoopPrintDigitsPlaythru:
; print char encodings for digits, FFFF terminated
    lda $00,x
    bmi DonePrintingPlaythruDigits
    jsl ReadFontDataDoTextDma
; remove DEC that reduced inter-char spacing from 2 pixels to 1 pixel
  ; dec.w TextXPos
    inx #2
    bra LoopPrintDigitsPlaythru

DonePrintingPlaythruDigits:
    pla : plx : pld
    rts

assert pc() <= !ConvertHexValInAToBCD
fillbyte $ff
fill !ConvertHexValInAToBCD-pc()

; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------

; change the printing logic for the line with the chapter number
; instead of "第N章", print "Chapter N"

; OLD: need to get the 24-bit pointer that Atlas wrote
; !PtrToChapterChar = $01ac5f
; !PtrToChapterChar = read3($01e005)

ChapNumTextBufferSize = $28

org $0181a5
ListTextXYPosChapterNum:
    db $20,$4f  ; $1c,$4f = (VRAM) text pos for top
    db $60,$4f  ; $5c,$4f = (VRAM) text pos for middle
    db $a0,$4f  ; $9c,$4f = (VRAM) text pos for bottom

org $01DFE1
PrintChapterNumberForBookmark:
    phd
    cop #$00
    db $2b
    phx : pha
; copy first 0x78 bytes of save file N to scratchpad
; get chapter number; if 0, do nothing
    brk #$1c
    db $09
    tay
    beq +

    jsr.w !ConvertHexValInAToBCD
    lda #$0003
    jsr.w !GetDigitCharsFromBCDBytes
    lda $01,s
    jsr WriteScreenTextForChapterNumberOfBookmarkN

  + pla : plx : pld
    rts

WriteScreenTextForChapterNumberOfBookmarkN:
    phd
    cop #$00                            ; make room on direct page for text
    db ChapNumTextBufferSize-1
    pha                                 ; push bookmark # (1-3)

; OLD: write text "[Ch.] ", copy digit encodings to after "[Ch.][space]"
  ; lda.l !PtrToChapterChar
  ; sta $00
  ; stz $02
  ; ldx #$fffe
  ; ldy #$0004

; fancier option: expand "Ch. " to "Chapter "; need to place text "Chapter[00]"
; in ROM and do a loop to copy it to the buffer

; this code block is slightly cursed in order to fit all the code and the text
; itself in the original space; 00 is terminator, increment X/Y first before
; reading/writing character value; another consequence is having to shift the
; letters more left in VRAM so that the C's won't overflow on the left side if
; printing a two-digit number
    ldx.w #$fffe
    ldy.w #$ffff
  - inx #2
    iny
    lda.w ChapterTextSpelledOut,y
    and.w #$00ff
    sta.b $00,x
    bne -
    inx #2
    txy
    ldx.w #$fffe

; copy in the digits of the chapter number
-   inx #2
    lda.b ChapNumTextBufferSize,X       ; read digit's char encoding
    bmi +                               ; check FFFF terminator
    phx
    tyx                                 ; copy digit to char buffer
    sta $00,X
    plx
    iny #2
    bra -

+   tyx
  ; lda.l chapter_kanji_char            ; REMOVED: write char encoding for 章
  ; sta $00,x
  ; lda #$FFFF                          ; write FFFF terminator
    sta $00,x

    lda $01,s                           ; get text X/Y position from bookmark #
    dec : asl : tax
    lda.w ListTextXYPosChapterNum,X
    sta.w TextXPos

    jsr.w GetXPosToWriteCenteredBookmarkText
    ; try seeing if leaving these out make the text look better
  ; dec.w TextXPos
  ; dec.w TextXPos

; read font for chapter number line's text
    ldx #$0000
-   lda $00,X
    bmi +
    jsl ReadFontDataDoTextDma
    inx #2
    bra -
+   pla : pld
    rts

ChapterTextSpelledOut:
    incbin "script/chapter text spelled out.bin"
    db $00

; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------

; code for printing chapter title on the bookmark comes right after, so move it
; back and repoint JSRs to it; originally at $01E051

; OLD: the DEC at $01E076 reduces the character spacing to 1 pixel, which we
; already took care of. So either NOP it out, or repurpose its bytes.
; !CopyDecompedTextToDirectPageBuffer = $01e081
; org $01e076
  ; dec.w TextXPos
    ; nop #3

; expand char limit for printing the chapter title on the bookmark
; longest translated chapter title is "Fight to the Death in the Lounge", 32
; simple test: increase the size of the COP = how far back to move direct page
BookmarkChapterTitleCharLimit = 38 ; originally $14 = twenty

PrintChapterTitleOnBookmark:
    phd
    cop #$00
    db BookmarkChapterTitleCharLimit*2-1
    phx : pha

    ; get X/Y position for printing the chapter title
    dec : asl : tax
    lda.w TextXY_PosChapterTitles,x
    sta.w TextXPos

    ; read title of most recent chapter into script buffer at $0500, then to DP
    lda $01,s
    brk #$1c
    db $11

    ; Move subroutine's code here, it's only ever used once in bank 01.
    ; Leaving in the JSR/RTS as comments if you do need to reuse it elsewhere.
  ; jsr CopyDecompedTextToDirectPageBuffer
CopyDecompedTextToDirectPageBuffer:
    ldx #$0000
-   lda $0500,x
    bmi +
    sta $00,x
    inx #2
    bra -
; below code only checks if value at $00 buffer is negative, and if we got here,
; that must be true, so just write the script value itself
+ ; lda #$ffff
    sta $00,x
  ; rts

    jsr.w GetXPosToWriteCenteredBookmarkText

    inc.w TextXPos  ; add this here if you want
; loop to read font data for chapter title
    ldx #$0000
-   lda $00,x
    bmi +
    jsl ReadFontDataDoTextDma
  ; dec.w TextXPos  ; see note above about character spacing with this DEC
    inx #2
    bra -

+   pla : plx : pld
    rts

assert pc() <= $01e095
fillbyte $ff
fill $01e095-pc()

; org $01dec2
    ; jsr PrintChapterTitleOnBookmark

; optional: change X pos to use for centering chapter titles in VRAM tileset
org $0181ab
TextXY_PosChapterTitles:
!ChapterTitleXPos = $5d ; originally $5c
;   db !ChapterTitleXPos,$60
;   db !ChapterTitleXPos,$70
;   db !ChapterTitleXPos,$80

; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------

; $01e19b is the subroutine that does "get X position to write centered text for
; the bookmark" like "Tooru & Mari", the chapter number, or the chapter title

; just before it is an opportunity to cut out several bytes in the subroutine at
; $01E175; the code from $01E183-$01E196 is an exact match for the code from
; $01E14A-$01E15D
org $01e14a
    -
org $01e183
  ; PHP
  ; REP #$30
  ; PHA : PHX : PHY
  ; BRK #$0C
  ; BRK #$00
  ; dw $0008
  ; REP #$30
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS
    bra -

!GetWidthOfCharInA = $01e20d

; there is one call to here from bank 02 for the chapter list
JslHereToGetXPosForCenteredBookmarkText:
    jsr.w GetXPosToWriteCenteredBookmarkText
    rtl
pushpc
org $02a3ef
    jsl JslHereToGetXPosForCenteredBookmarkText
pullpc

GetXPosToWriteCenteredBookmarkText:
; $00 = accumulator for widths of characters, $02 = buffer for text to print
    phd
    cop #$02
    dw $0000
    db $01
    php
    rep #$30
    pha : phx : phy

; $00 <- sum of widths of all the characters in the FFFF-terminated string
    ldx #$fffe
-   inx #2
    lda $02,x
    bmi +
    jsr.w !GetWidthOfCharInA
  ; clc
    sec
    adc $00
    sta $00
    ; inc $00   ; cut out this instruction's two bytes
    bra -

GotWidthOfTextForCenteredPosCalculation:
+   dec $00
    lsr $00
  ; sep #$20
    sep #$21    ; M=1, set carry
    lda.w TextXPos
  ; sec         ; cut out this byte
    sbc $00
    sta.w TextXPos

    rep #$30
    ply : plx : pla : plp : pld
    rts

; ----------

; make another version of this code that operates on 1-byte encoding strings
; purpose: eventual hack for names in the 1-byte encoding

GetXPosToWriteCenteredOneByteEncText:
; $00 = accumulator for widths of characters, $02 = buffer for text to print
    phd
    cop #$02
    dw $0000
    db $01
    php
    rep #$30
    pha : phx : phy

; $00 <- sum of widths of all the characters in the FF-terminated string
    ldx #$ffff
-   inx
    lda $02,x
    and #$00ff
    cmp #$00ff
    beq GotWidthOfTextForCenteredPosCalculation
    jsr.w !GetWidthOfCharInA
    sec
    adc $00
    sta $00
    bra -

; ----------

; clear out space originally for the "right align text" subroutine
assert pc() <= !GetWidthOfCharInA
fillbyte $ff
fill !GetWidthOfCharInA-pc()
