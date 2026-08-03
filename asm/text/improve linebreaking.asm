includefrom "MAIN insert text.asm"

CalculatedXPos = $0395
BufferPosOfLastSpaceChar = $0397
BackUpOfCalculatedXPos = $039d
BackUpOfBufferPosOfLastSpaceChar = $039f
; MostRecentChar = $03a5 ; for kerning, to be added later
FLAG_PrevText1_CurrText0_PrevChap8000 = $03c1
HuffmanTextBuffer = $0500

!TextBufferSize = $0400

!StartXPosForNormalText = $000c
!StartXPosForChoiceText = $0020
; !TextRightMargin = $00f8  ; see ASM file about $00A0DD jump table

!FlagPrintingChoice = $8000
; !FlagDoNotCalculateXPos = $4000
!SentinelNoPositionForSpace = $0fff

!InitHuffmanBuffer = $009a4a
!WriteCharToTextBuffer0500 = $009b46

; ------------------------------------------------------------------------------

; repurpose a few blocks in memory originally for controller input data for
; players 3 and 4 (why even have them?)
org $00859c
  ; ldx.b #$06
    ldx.b #$02

; ------------------------------------------------------------------------------

org $00953a
    REP #$30
    STZ.B $19
    STZ.B $1b
    STZ.B $1d
    STZ.B $1f
    STZ.B $04
    STZ.B $06
  ; LDX.W #$001a
    jsr.w InitializeTextCalculationGlobals
  - STZ.B $23,x
    DEX #2
    BPL -
  - JSR.W $9a06
    JSR.W $9559
    BRA -
assert pc() == $009559

org $00eb80
InitializeTextCalculationGlobals:
    lda.w #!SentinelNoPositionForSpace
    sta.w BufferPosOfLastSpaceChar
    lda.w #!StartXPosForNormalText
    sta.w CalculatedXPos
  ; stz.w MostRecentChar
    LDX.W #$001A
    rts

; ------------------------------------------------------------------------------

; pushpc
; org $009a10
    ; jsr.w InitTextCalculationGlobalsAndHuffmanBuffer
; org $009c9f
    ; jsr.w InitTextCalculationGlobalsAndHuffmanBuffer

; pullpc
; InitTextCalculationGlobalsAndHuffmanBuffer:
    ; jsr.w InitializeTextCalculationGlobals
    ; jmp.w !InitHuffmanBuffer

; InitializeTextCalculationGlobals:
    ; php
    ; rep #$20
    ; lda.w BufferPosOfLastSpaceChar
    ; and.w #!FlagPrintingChoice
    ; ora.w #!SentinelNoPositionForSpace
    ; sta.w BufferPosOfLastSpaceChar
  ; ; stz.w MostRecentChar
    ; plp
    ; rts

; ------------------------------------------------------------------------------

; replace JSRs to "write decompressed character in $040D to text buffer" to also
; simulate calculating the text X position; assume that value in A is char value

pushpc
; for writing punctuation characters and their control codes to buffer
; see below notes about delay code input after commas
org $0099a9
    jsr.w UseDecompressedEncodingToCalculateXPosAndWriteToBuffer

; for writing upcoming text
org $009a20
    jsr.w UseDecompressedEncodingToCalculateXPosAndWriteToBuffer

; for reading chapter titles for the list (while playing the game?)
; when first loading into it, it will use the current X position as a base, and
; we do NOT want to replace spaces with the bytes [100E] and load a garbage font
org $009c9f
  ; jsr.w !InitHuffmanBuffer
    jsr.w InitTextXForChapterTitleAndInitHuffmanBuffer
org $009ca9
    jsr.w UseDecompressedEncodingToCalculateXPosAndWriteToBuffer

; for reading a previous chapter's text after a NEW CHAPTER 24 until a CLEAR 25
org $009cd2
    jsr.w UseDecompressedEncodingToCalculateXPosAndWriteToBuffer

; ------------------

; These next two should get updated when doing the one-byte encoding name hack,
; but still documenting their locations here.

; for writing character names for normal text
org $0098e4
    jsr.w UseEncodingToCalculateXPosAndWriteToBuffer

; for printing names for either previous text or printing a chapter title
org $009f8e
    jsr.w SetValueAsDecompressedEncodingBeforeCalculatingXPosAndWritingToBuffer

; ------------------------------------------------------------------------------

pullpc
SetValueAsDecompressedEncodingBeforeCalculatingXPosAndWritingToBuffer:
    sta.b $0d
UseDecompressedEncodingToCalculateXPosAndWriteToBuffer:
    lda.b $0d
UseEncodingToCalculateXPosAndWriteToBuffer:
    phx
; BRK #$16 checks if the value in A would be a control code (N flag set if yes)
; and if it is also a choice code (V flag set if yes)
    brk #$16
    bpl GotCharacter    ; if N flag clear, got a character
    bvs GotChoiceCode   ; if V flag set, got a choice
; check for LINE
    cmp.w #$100e
    beq GotLine
; check for CLEAR
    cmp.w #$1025
    beq GotClear
; optional? if got "skip text when picked", set flag to not calculate X position
  ; cmp #$1016
  ; beq GotSkipTextWhenPicked
; similar: if got "end choice", set flag to resume calculating the X position
  ; cmp #$1015
  ; beq GotEndChoice
; check for SET X POS
    cmp.w #$1019
; otherwise, just move on to writing control code to the buffer
    bne +

GotSetX:
; if got SET X POS code, we must forget the last position of a space character
; however, keep the flag for if in a choice or not
  ; lda.w BufferPosOfLastSpaceChar
  ; and.w #!FlagPrintingChoice
  ; ora.w #!SentinelNoPositionForSpace
  ; sta.w BufferPosOfLastSpaceChar
    lda.w #!SentinelNoPositionForSpace
    tsb.w BufferPosOfLastSpaceChar
  + jmp.w WriteEncodingToBuffer

; GotClear:
; - OLD LOGIC: if got CLEAR code, we must forget the last position of a space
;   character, and also forcibly disable flag for printing text for a choice
;   lda.w #!StartXPosForNormalText
;   sta.w CalculatedXPos
;   lda.w #!SentinelNoPositionForSpace
; + sta.w BufferPosOfLastSpaceChar
;   bra WriteEncodingToBuffer

; the above worked fine except for a particular edge case: the chapter name
; "Mystery Pension" is in the middle of a selectable choice and is terminated
; with a CLEAR code (same deal with "Bloodstains at the Back Door" and "A Face
; Floating in the Window", but no issues popped up with them)
; conclusion: you do have to preserve the "in choice" flag if got a CLEAR code;
; it gets cleared once you pick an option with InitializeTextCalculationGlobals,
; because that's when the Huffman buffer gets reinitialized

GotChoiceCode:
; enable flag for printing text for a choice, forget last position of a space;
; EDGE CASE: if you scroll back onto a page that includes a choice code, the
; "in choice" flag gets set, and you DON'T want to calculate X pos for previous
; text as if it was being printed for a choice
    lda.w FLAG_PrevText1_CurrText0_PrevChap8000
    bne +
    lda.w #!FlagPrintingChoice
    tsb.w BufferPosOfLastSpaceChar
    bra +

GotLine:
GotClear:
; if got LINE code, we must forget the last position of a space character, but
; keep the flag for if in a choice or not
    jsr.w SimulateLineBreak
  + jmp.w WriteEncodingToBuffer

; GotSkipTextWhenPicked:
    ; lda.w #!FlagDoNotCalculateXPos
    ; tsb.w BufferPosOfLastSpaceChar
    ; bra WriteEncodingToBuffer

; GotEndChoice:
    ; lda.w #!FlagDoNotCalculateXPos
    ; trb.w BufferPosOfLastSpaceChar
    ; bra WriteEncodingToBuffer

; OLD, keeping just in case I need it later
; if a space, we need to record where we are in the buffer
; preserve current flag(s)
;   bne +
;   lda.w BufferPosOfLastSpaceChar
; ; and #!FlagPrintingChoice|!FlagDoNotCalculateXPos
;   and #!FlagPrintingChoice
;   ora.b $1f
;   sta.w BufferPosOfLastSpaceChar
;   lda #$0000
; + jsr.w AddCharWidthToCalculatedXPos
; check if past right text margin
;   cmp.w #!TextRightMargin
;   bmi WriteEncodingToBuffer
; if yes, we need to overwrite the most recent space character (if it exists)
; with a LINE code; the AND is necessary to mask out the "printing choice" flag
;   lda.w BufferPosOfLastSpaceChar
;   and.w #!SentinelNoPositionForSpace
;   cmp.w #!SentinelNoPositionForSpace
;   beq WriteEncodingToBuffer
;   tax
;   lda.w #$100E
;   sta.w HuffmanTextBuffer,x
;   jsr.w SimulateLineBreak

GotCharacter:
; check if printing character would go past right text margin
  + jsr.w AddCharWidthToCalculatedXPos
    cmp.w #!TextRightMargin
    bmi WriteEncodingToBuffer

; - if yes, we need to overwrite the most recent space character (if it exists)
;   with a LINE code; the AND is necessary to mask out "printing choice" flag
; - edge case: if the character that caused the overflow is a space, we can just
;   pretend we decompressed the Huffman code for a LINE instead of a space
    lda.b $0d
    bne +
    lda.w #$100E
    sta.b $0d
    bra GotLine

  + lda.w BufferPosOfLastSpaceChar
    and.w #!SentinelNoPositionForSpace
    cmp.w #!SentinelNoPositionForSpace
    beq WriteEncodingToBuffer
    tax
    lda.w #$100E
    sta.w HuffmanTextBuffer,x
    jsr.w SimulateLineBreak

; now we need to add the width of all the characters up to this point
; due to buffer wrap-around, it's better to determine how many chars have to be
; processed, instead of checking "is buffer offset for getting widths equal to
; (or greater than) current buffer offset to write to?"

; one note is that you want to use the buffer offset in $1F (position to write
; the next two-byte value) instead of the one in $1D (position of control code
; in buffer); this difference is important for writing the bytes of name control
; codes e.g. for Tooru and Mari

; naive version:
; - inx #2
;   cpx $1d

; less naive version:
; - txa
;   inc #2
;   and.w #$03ff
;   tax
;   cmp $1d

; advance past the LINE we just wrote; this may increase X from 3FE to 400,
; should go to 0 instead; I'm choosing to handle this below
    inx #2
    txa
; use reverse subtraction to calculate byte difference:
; (curr buffer offset) - (offset past LINE) = ~line_offset + 1 + curr_offset
    eor.w #$ffff
    sec
  ; adc.b $1d
    adc.b $1f

; if result is negative, then current buffer offset near the start, LINE is near
; end of the buffer (e.g. 8F8 -> 502); solution is to add 0x400, so (902 - 8F8)
    bpl GotNumCharsToProcess
    clc
    adc.w #!TextBufferSize
    bra GotNumCharsToProcess
    eor.w #$ffff
    inc

GotNumCharsToProcess:
; take care of case mentioned above where X can currently be 0400
    cpx.w #!TextBufferSize
    bne +
    ldx.w #$0000
; Y <- loop counter = # characters = # bytes / 2
  + lsr
    tay

LoopRecalculateX:
    beq DoneRecalculatingX
    lda.w HuffmanTextBuffer,x

; skip control codes and their arguments if you find them; in the testing I've
; done, this only seems to fire for delay codes after commas; still good to
; cover your bases
    cmp.w #$1000
    bpl GotCtrlCodeWhenRecalculatingX
GotCharWhenRecalculatingX:
    jsr.w AddCharWidthToCalculatedXPos
    jsr.w AdvancePastTextValueWithBufferWraparound
  - dey
    bra LoopRecalculateX

GotCtrlCodeWhenRecalculatingX:
; use ctrl code ID to read from 4-byte ctrl code data struct in table at $01a901
; byte 01 in a struct encodes # arguments for the ctrl code in bits 0-1
; assumption: jumps and choices will NOT be encountered!
    phx
    and.w #$00ff
    asl #2
    tax
    lda.l $01a902,x ; is the full 24-bit ptr necessary?
    and.w #$0003
    plx
; advance past ctrl code encoding
; notice that we do not decrement Y (# chars left) here; see notes in below loop
    jsr.w AdvancePastTextValueWithBufferWraparound

LoopSkipCtrlCodeArgs:
; subtle detail: overall loop for recalculating text X pos uses Y as loop ctr,
; so this BEQ here cannot simply go to [LoopRecalculateX]; may as well leech off
; the DEY in the "got character" case
    beq -
    jsr.w AdvancePastTextValueWithBufferWraparound
    dey
    dec a
    bra LoopSkipCtrlCodeArgs

; now we also have to re-add the width of the current character, because adding
; it was what caused the auto line break to occur in the first place
DoneRecalculatingX:
    lda.b $0d
    jsr.w AddCharWidthToCalculatedXPos

WriteEncodingToBuffer:
; if a space, we need to record where we are in the buffer
; preserve current flag(s)
    lda.b $0d
    bne +
    lda.w BufferPosOfLastSpaceChar
  ; and #!FlagPrintingChoice|!FlagDoNotCalculateXPos
    and.w #!FlagPrintingChoice
    ora.b $1f
    sta.w BufferPosOfLastSpaceChar
    lda.b $0d

  + plx
    jmp.w !WriteCharToTextBuffer0500

SimulateLineBreak:
; set that there is no space character to look back at for linebreaking
; preserve the "is choice being printed?" flag
    lda.w BufferPosOfLastSpaceChar
    and.w #!FlagPrintingChoice
    ora.w #!SentinelNoPositionForSpace
    sta.w BufferPosOfLastSpaceChar
; we must reset the text position to the correct left margin based on the flag
    bmi +
    lda.w #!StartXPosForNormalText
    bra ++
  + lda.w #!StartXPosForChoiceText
 ++ sta.w CalculatedXPos
    rts

--------------------------------------------------------------------------------

AdvancePastTextValueWithBufferWraparound:
    pha
    inx #2
    txa
    and.w #$03ff
    tax
    pla
    rts

--------------------------------------------------------------------------------

; reuse code at $00a313
; note that this will not preserve what is in A i.e. the char value
GetWidthOfCharEncodingInA:
    dec a   ; check if space character
    bpl +
    lda #!SpaceCharWidth
    rts
  + phx
    ldx #$0000
LoopGetWidth:
    sec
    sbc.w NewFontGroupSizesTable,x
    bmi +
    inx #2
    bra LoopGetWidth
  + lda.w NewFontDimensionsTable,x
    and #$000f
    plx
    rts

AddCharWidthToCalculatedXPos:
; assume 1 pixel of spacing between each character
; if you want to add text kerning, put it here
    jsr.w GetWidthOfCharEncodingInA
    sec
    adc.w CalculatedXPos
    sta.w CalculatedXPos
    rts

--------------------------------------------------------------------------------

; handle hard-coded input of [SET X POS]*0x20* after printing a choice letter
pushpc
org $009806
  ; jsr.w !WriteCharToTextBuffer0500
    jsr.w AssignValueAsCalculatedXPosAndWriteToBuffer

; special case for SET X POS in the script: since the input value still has to
; be decompressed after you find the code, you have to hijack the code for
; decompressing the input values for control codes
org $009af3
; $009AF0: jsr.w ReadHuffmanCode009B06
    jsr.w CheckForGettingInputOfSetXPosCtrlCode

pullpc
CheckForGettingInputOfSetXPosCtrlCode:
; push the control code input that just got decompressed; get buffer offset to
; write to next, and look back two bytes (do loop around from $0500 to $08FE)
    pha
    lda.b $1f
    dec #2
    and.w #$03ff
; get the two bytes in the buffer and see if they are for SET X POS
    tax
    lda.w HuffmanTextBuffer,x
    cmp.w #$1019
    bne +
    lda.b $0d
  - sta.w CalculatedXPos
  + pla
    jmp.w !WriteCharToTextBuffer0500

AssignValueAsCalculatedXPosAndWriteToBuffer:
; basic implementation
  ; sta.w CalculatedXPos
  ; jmp.w !WriteCharToTextBuffer0500
; reuse the code from above to save 3 bytes
    pha
    bra -

; ------------------------------------------------------------------------------

; the edit at $0099A9 has a flaw in that when you get a comma, the delay code's
; input value is interpreted as a printable character; what's even worse, the
; input value is 0000 by default, and messes up the space character detection!
; consequence: we have to recreate the original code here, oh well
pushpc
org $0099f9
    jsr.w StoreCharEncodingForPunctuationCode

pullpc
StoreCharEncodingForPunctuationCode:
    sta.b $0d
    jsr.w $9996
    jsr.w !WriteCharToTextBuffer0500    ; this JSR had been overwritten
    jsr.w $999d
    rts

; ------------------------------------------------------------------------------

; when transitioning from printing current text to previous text, you should
; back up the calculated X position and the buffer position of the last space

; good place to do this would be with BRK #$1c input 05 (back up script buffer)
; similarly have to restore the variables along with BRK #$16 input 06

; I am opting to alter the code of BRK #$1C inputs 05 and 06 rather than inject
; JSRs over every instance of the three code bytes [00 1C 05] or [00 1C 06]
; see the ASM file for updating BRK #$1C code

; this being said, still documenting instances of [BRK #$1c ; db $05 / db $06]:
; $00eb32: input 05, setting up to show chapter list after pressing Select or R
; $00eb67: input 05, setting up to show previous text after pressing X
; $01cd02: input 06, received input of B, Select, A, L, R when viewing prev text
; $01de52: input 05, reading and displaying the bookmark text in BG3
; $01de62: input 06, reading and displaying the bookmark text in BG3

; ------------------------------------------------------------------------------

; when showing previous text, the fast text printing rate can cause inconsistent
; behavior with the new linebreaking code; by the time it detects that a space
; has to be replaced with a line code, the game may have already printed it!

; one simple, if unsatisfactory, solution is to change the call to FAST TEXT to
; a call to NORMAL TEXT SPEED; instances of calling FAST TEXT SPEED at $00AEC6:
; $00a724: this is what you want
; $00A822: reprinting current page of text, after exiting "view prev text" mode
; org $00a724
  ; JSR.W $AEC6 ; fast
  ; jsr.w $aed0 ; normal

; better solution that I thought would be more complicated than what's below:
; change the printing system to first decompress ALL text for a page of previous
; text before printing any of it, vs how the JP game basically does, "decompress
; one 'chunk' of the page's text, print text until the end of the chunk; repeat
; until end of page"

pushpc
org $00a938
    lda.w #$0400
    ldy.w FLAG_PrevText1_CurrText0_PrevChap8000
    beq +
  ; lda.w #$1235
    jsr.w DecompressWholePageOfPreviousText
  + tcd
assert pc() == $00a944

pullpc
DecompressWholePageOfPreviousText:
    lda.w #$1235
    tcd
; code at $009f03 writes 1018 "END GAME" after end of text for previous page, so
; we can check "is page fully decompressed?" by seeing if last character is 1018
  - ldx.b $1d
    lda.w HuffmanTextBuffer,x
    cmp.w #$1018
    beq +
; since this hack is for printing previous text, we can forgo this JSR and just
; do the direct BRK call
  ; JSR.W call_either_BRK_01_4A_curr_text_or_BRK_01_4B_else_00A967
    brk #$01
    db $4b
; this BRK does the actual text decompression
    BRK #$00
    dw $0080
    BRA -

  + tdc
    rts

; ------------------------------------------------------------------------------

InitTextXForChapterTitleAndInitHuffmanBuffer:
    lda.w #!StartXPosForNormalText
    sta.w CalculatedXPos
    jmp.w !InitHuffmanBuffer
