includefrom "MAIN insert text.asm"

; ------------------------------------------------------------------------------

; The game's feature for reading previous text constructs a data table at $0700
; in RAM, which is in the middle of the text decompression ring buffer. Move it
; further back to $0860 (text buffer ends at $08FF), since too much decompressed
; English text on a page can clobber the table's contents, importantly the text
; pointers. Might be able to move to $0866, since it's a "0xA * 0xA" byte block.

PrevTextPtrTable = $0860

; for marking the first page in a chapter - without updating this, game will
; crash if you try to move between chapters!
org $009de0
    stz.w PrevTextPtrTable+1,x

; for creating the table
org $009e8d
    sta.w PrevTextPtrTable+0,x
org $009e92
    sta.w PrevTextPtrTable+2,x
org $009e97
    sta.w PrevTextPtrTable+4,x
org $009e9d
    sta.w PrevTextPtrTable+6,x
org $009ea3
    sta.w PrevTextPtrTable+8,x

; for reading from the table - documenting list of locations, but actual edits
; are incorporated into rewriting bank 04
; org $04a11a
    ; lda.w PrevTextPtrTable+1,x
; org $04a121
    ; lda.w PrevTextPtrTable+0,x
; org $04a126
    ; lda.w PrevTextPtrTable+4,x
; org $04a12b
    ; lda.w PrevTextPtrTable+6,x
; org $04a131
    ; lda.w PrevTextPtrTable+8,x

; ------------------------------------------------------------------------------

; Change the game's on-the-fly text shadowing routine to make it easier to read
; against bright backgrounds. The basic idea is that given a font pixel, the
; original routine uses it to generate two shadow pixels: one "east", and one
; "southeast". This modification also makes the routine generate one "south".

org $02A121
; Overwrite instructions in original shadowing routine with JSR to new code.
  ; tya
  ; ror a       ; ROR shifts out a bit that MUST be preserved in the carry flag
  ; tay
    jsr ModifiedShadowing

; Place new shadowing code in small empty block near the end of bank 02.
org $02FFE9
ModifiedShadowing:
; This implementation takes 0x8 bytes.
    phy         ; Y contains a row of pixel data

    tya         ; A <- (row >> 1) | row
    ror a
    ora $01,s

    ply         ; undo stack push that was needed for calculation
    tay         ; both A and Y must contain row of shadowed font data
    rts

; ------------------------------------------------------------------------------

; If you want, you can change the default text speed. Although I find 00 to be
; too fast and 01 to be slower than I'd like for English text, it's faster than
; than what Otogirisou had.

TextSpeed = $15EF

; demo mode
org $00aed8
  ; lda.b #$02
    lda.b #$01

; main gameplay
org $00aedc
    lda.b #$01
  ; lda.b #$00

; ------------------------------------------------------------------------------

; change the width of the space character from 8 pixels to 2 pixels
!SpaceCharWidth = $0002

org $00a319
    db !SpaceCharWidth
org $01e21c
    dw !SpaceCharWidth
; this one gets changed in an ASM hack below
; org $00a3bf
    ; dw !SpaceCharWidth

; ----------

; Change parameters for printing text:
; - height of a line break (how far to go down)
; - where to reset the text X position to after a line break
; - the starting text X/Y position after clearing the screen

; Experiment with these; try to get 10 lines on screen at once while also always
; coloring in text for choices correctly.

ChoiceLineXPos = $00AC17
NewLineXPos = $00AC1E
LineBreakHeight = $00AC24
NewScreenXPos = $00AD1B
NewScreenYPos = $00AD20
BottomLimitForYPos = $00AC29

org ChoiceLineXPos
  ; db $20
    db $20
org NewLineXPos
  ; db $0d
    db $0d
org LineBreakHeight
  ; db $17
    db $14

org NewScreenXPos
  ; db $0d
    db $0d
org NewScreenYPos
  ; db $0d
    db $0c

org BottomLimitForYPos
; if (line height + text Y pos) exceeds this bound, text Y pos will not change
; purpose is to prevent clobbering the BG3 tilemap in VRAM with tile data
  ; db $d0
    db $d0

; ------------------------------------------------------------------------------

; $00A36A is the subroutine that reads the font data for a character and elapses
; frames after it based on the text speed control; there is a vestigial BEQ $00
; at the start that says Chunsoft may have planned to specially handle spaces,
; but ultimately handled them like any other character; remove it
org $00a36a
  ; beq $00
    jsl ReadFontDataDoTextDma
    php
    sep #$20

; TextSpeed = # frames to elapse per character; 0 = print as many characters as
; possible per frame
    lda.w TextSpeed
    beq +
-   brk #$00
    dw $0001
    dec a
    bne -

+   plp
    rts

; OLD: basic hack to reduce the inter-character spacing from 2 pixels to 1 pixel
; org $00a3cb
    ; clc

; the subroutine at $00A3D4 advances the text X position right if the current
; character is either an ellipsis dot or an exclamation mark; I don't need this,
; and there is only one JSR to it in the code, so we can repurpose the space

; OLD: simpler version is to just NOP out the JSR
; org $00a398
    ; jsr $a3d4
    ; nop #3

!StoreXYTilePosTo15E0 = $00A3FE

ReadFontDataDoTextDma:  ; originally at $00a381, move back
    phd
    cop #$00
    db $06

    php
    rep #$30
    pha : phx : phy

; the game appears to not use $02 on the direct page here, so assuming your font
; has under 0x100 characters, you can keep a one-byte copy of the encoding value
; there if you want to do text kerning in the font routine itself
;   sta $02

    dec a
    bmi case_got_0000_space_00a3be

    sta $00
    jsr.w !StoreXYTilePosTo15E0

    lda.w TextXPos
    sta $05
  ; JSR $A3D4       ; leave this out!
    lda $15e0
    sta $03

    jsl $029f66     ; write font data for character to buffer at $7F0000
    lda $15e2
    bne adv_text_pos_pull_regs_RTL_00a3b3

    lda $15e0
    sta $03
    ldx #$0002
    brk #$15

adv_text_pos_pull_regs_RTL_00a3b3:
  ; jsr add_text_width_and_spacing_00a3c5
add_text_width_and_spacing_00a3c5:
; only one JSR to this subroutine, so see if moving ASM here harms anything
; but I'm keeping in set-up code (JSR/RTS, PHP/PLP) as comments if needed later
  ; PHP
  ; SEP #$30    ; absorb the below SEC into this SEP to save a byte
    sep #$31    ; carry = 1; 8-bit M, 8-bit X
    lda.w TextXPos
  ; SEC
    adc $00
  ; INC A       ; leave out to reduce char spacing from 2 pixels to 1 pixel
; if you want to try baking text kerning directly into the text printing routine
; versus using control codes in the script for text kerning, do it here!
    sta.w TextXPos
  ; PLP
  ; RTS

    rep #$30
    ply : plx : pla : plp : pld
    rtl

case_got_0000_space_00a3be:
    lda #!SpaceCharWidth
    sta $00
    bra adv_text_pos_pull_regs_RTL_00a3b3

; this frees up a space of 2 + 0xB + 0x2A = 0x37 bytes; not bad!
assert pc() < !StoreXYTilePosTo15E0
    fillbyte $ff
    fill !StoreXYTilePosTo15E0-pc()

; need to repoint all instances of JSL $00A381; those not explicitly updated
; below are updated in the other ASM hacks in this file; ref list for JP game:
; x a36c, x 1def3, x 1df0a, x 1df9f, x 1dfb3, x 1e046, x 1e072

; clear the wait icon, either cursor or next page
org $00ad9c
    jsl ReadFontDataDoTextDma
; flash the wait icon on
org $00adef
    jsl ReadFontDataDoTextDma
; show the wait icon if input detected?
org $00ae09
    jsl ReadFontDataDoTextDma
; next two in subroutine at $00ae27
org $00ae5e
    jsl ReadFontDataDoTextDma
org $00ae8c
    jsl ReadFontDataDoTextDma

; chapter title in chapter list
org $02a363
    jsl ReadFontDataDoTextDma
; [Ch.] in chapter list
org $02a3b2
    jsl ReadFontDataDoTextDma
; chapter number in chapter list
org $02a3fd
    jsl ReadFontDataDoTextDma
; in JP game, print 章 "chapter"; do not need, but documenting anyway
; org $02a411
    ; jsl ReadFontDataDoTextDma
; cursor in chapter list
org $02a478
    jsl ReadFontDataDoTextDma

; font data for name on file management prompts; documenting location
; this should get updated in one-byte encoding name hack
org $02a85d
    jsl ReadFontDataDoTextDma

; ------------------------------------------------------------------------------

; change chapter list printing params; overall ctrl flow is in ASM at $02a1a3

; when printing the chapter list, change X position of start of chapter name
org $02a352
  ; db $48
    db $36

; change the X position of the [Ch.] character on each line of the list
org $02a3a9
  ; db $15
    db $13

; replace reading [Ch.] from a pointer, to loading its value as an immediate
; motivation: no longer using [Ch.] on bookmark screen, so it's only used here
; org $02a3af
  ; lda.w $01ac5f ; originally for "第"
;   lda.w #FILL_IN

; formula for starting X pos of chapter numbers: X <- 0x2C - (width of digits)
org $02a3b9
  ; db $2c
    db $2c

; cursor's font data gets drawn to (X,Y) = (0xA,0xA0) in VRAM; game moves cursor
; on screen by changing tilemap, so feel free to change X pos (but not Y pos)
; org $02a46a
    ; db $a0
org $02a46f
  ; db $0a
    db $09

; JP game also draws the 章 "chapter" character after the digits; we don't need
; it, so we can cut out the code that prints it
org $02a405
  ; SEP #$20
  ; LDA #$34
  ; STA.W TextXPos
  ; REP #$20
  ; LDA.W $01ac61 ; ptr to chapter kanji
  ; JSL ReadFontDataDoTextDma
    ply : plx : pla : plp : pld
    rts

assert pc() < $02a41d
fillbyte $ff
fill $02a41d-pc()

; ------------------------------------------------------------------------------

; not exactly a text hack, but it's in the same general category
; in the name entry character grid, move the box highlight for the 2nd column of
; characters left a pixel from what it normally is
org $0187f5
  ; db $40
  db $3f
