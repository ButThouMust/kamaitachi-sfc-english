includefrom "high-level recompress and repoint data.asm"

; hard-coded list of all files for the prompts that need to be inserted

!Prompt00Welcome    = "file prompts data/00 Welcome to the ski lodge Spur.bin"
!Prompt01Guest      = "file prompts data/01 Our guests are.bin"
!Prompt02Partner    = "file prompts data/02 and his partner.bin"
!Prompt03Comma      = "file prompts data/03 comma.bin"
!Prompt04Period     = "file prompts data/04 period.bin"
!Prompt05Start      = "file prompts data/05 Start game.bin"
!Prompt06Change     = "file prompts data/06 Change names.bin"
!Prompt07DeleteFile = "file prompts data/07 Delete file.bin"
!Prompt08Where      = "file prompts data/08 Read from where.bin"
!Prompt09AutoSave   = "file prompts data/09 Auto save.bin"
!Prompt10Beginning  = "file prompts data/10 Beginning.bin"
!Prompt11Chapter    = "file prompts data/11 Chapter.bin"
!Prompt12WillDelete = "file prompts data/12 File will be deleted.bin"
!Prompt13AreYouSure = "file prompts data/13 Are you sure.bin"
!Prompt14Yes        = "file prompts data/14 Yes.bin"
!Prompt15No         = "file prompts data/15 No.bin"

; also need to get the size of the graphics for each prompt
; Notice that we need the file size, divided by 2, for the purposes of metadata.
Prompt00Size = filesize("!Prompt00Welcome")>>1
Prompt01Size = filesize("!Prompt01Guest")>>1
Prompt02Size = filesize("!Prompt02Partner")>>1
Prompt03Size = filesize("!Prompt03Comma")>>1
Prompt04Size = filesize("!Prompt04Period")>>1
Prompt05Size = filesize("!Prompt05Start")>>1
Prompt06Size = filesize("!Prompt06Change")>>1
Prompt07Size = filesize("!Prompt07DeleteFile")>>1
Prompt08Size = filesize("!Prompt08Where")>>1
Prompt09Size = filesize("!Prompt09AutoSave")>>1
Prompt10Size = filesize("!Prompt10Beginning")>>1
Prompt11Size = filesize("!Prompt11Chapter")>>1
Prompt12Size = filesize("!Prompt12WillDelete")>>1
Prompt13Size = filesize("!Prompt13AreYouSure")>>1
Prompt14Size = filesize("!Prompt14Yes")>>1
Prompt15Size = filesize("!Prompt15No")>>1

;; -----------------------------------------------------------------------------
;; -----------------------------------------------------------------------------

!FileManagementPromptsGFXPtr = $04A618 ; originally $04A824
!BadEndGFXPtr = $04BF04

; clear out all of the original Japanese prompts
org !FileManagementPromptsGFXPtr
    fillbyte $FF
    fill !BadEndGFXPtr-!FileManagementPromptsGFXPtr

; insert each prompt's graphics data, and collect the pointers along the way
org $03edf0
Prompt00GfxPtrWelcome:
    incbin "!Prompt00Welcome"
Prompt01GfxPtrGuest:
    incbin "!Prompt01Guest"
Prompt02GfxPtrPartner:
    incbin "!Prompt02Partner"
Prompt03GfxPtrComma:
    incbin "!Prompt03Comma"
Prompt04GfxPtrPeriod:
    incbin "!Prompt04Period"
Prompt05GfxPtrStart:
    incbin "!Prompt05Start"
Prompt06GfxPtrChange:
    incbin "!Prompt06Change"
Prompt07GfxPtrDeleteFile:
    incbin "!Prompt07DeleteFile"
Prompt08GfxPtrWhere:
    incbin "!Prompt08Where"
Prompt09GfxPtrAutoSave:
    incbin "!Prompt09AutoSave"
Prompt10GfxPtrBeginning:
    incbin "!Prompt10Beginning"
Prompt11GfxPtrChapter:
    incbin "!Prompt11Chapter"
Prompt12GfxPtrWillDelete:
    incbin "!Prompt12WillDelete"
Prompt13GfxPtrAreYouSure:
    incbin "!Prompt13AreYouSure"
Prompt14GfxPtrYes:
    incbin "!Prompt14Yes"
Prompt15GfxPtrNo:
    incbin "!Prompt15No"

; reuse graphics for the cursor arrow for selecting a choice
; normally starts at 23D84, but reposition the arrow up a pixel for centering
NewCursorArrowGfxPtr:
    incbin "!JPROM":snestopc($04bd86)..snestopc($04bd94)
    incbin "!JPROM":snestopc($04bda4)..snestopc($04bda6)
    fillbyte $00
    fill $C
    incbin "!JPROM":snestopc($04bdb4)..snestopc($04bdb8)
    incbin "!JPROM":snestopc($04bda6)..snestopc($04bdb0)
    fill $16

assert pc() < $03ffff

; update the bank number of the graphics
org $038446
    db bank(Prompt00GfxPtrWelcome)

;; -----------------------------------------------------------------------------
;; -----------------------------------------------------------------------------

; Start updating the metadata tables for each screen of prompts.
; The metadata for each line of text is in the format:
;  00   01   02   03   04   05   06   07
; [XX] [YY] [Top ptr] [Low ptr] [Row size]

; XX = X pixel position for line
; YY = Y tile position for line
; Top ptr = pointer to start of graphics for the top row of a line
; Low ptr = pointer to start of graphics for the bottom row of a line
; Row size = # bytes for a row of tiles for a line

; Keeping the X/Y positions mostly worked fine for me, but I included comments
; for the original values in case you do want to reposition them on screen.

; The row size is half the size of an individual file for a prompt line.
; Each screen is terminated with the value $8000.

PromptListEnder = $8000
CursorSize = $20

; original location of the list of structures is $04A718
; you can repoint this to any free block of 0x10C bytes, confined to ONE BANK
; !PromptsMetadataTables = $04A718
; org !PromptsMetadataTables

; see the LZSS reinsertion ASM file for where this address label comes from
org FreedSpaceAfterLzssVfx0E

; Main screen on either a new or existing file
StructExistingFile:
    db $40,$14
    dw Prompt07GfxPtrDeleteFile
    dw Prompt07GfxPtrDeleteFile+Prompt07Size
    dw Prompt07Size

StructNewFile:
    db $10,$03
    dw Prompt00GfxPtrWelcome
    dw Prompt00GfxPtrWelcome+Prompt00Size
    dw Prompt00Size

    db $10,$06
    dw Prompt01GfxPtrGuest
    dw Prompt01GfxPtrGuest+Prompt01Size
    dw Prompt01Size

    db $10,$09
    dw Prompt02GfxPtrPartner
    dw Prompt02GfxPtrPartner+Prompt02Size
    dw Prompt02Size

    db $40,$0E
    dw Prompt05GfxPtrStart
    dw Prompt05GfxPtrStart+Prompt05Size
    dw Prompt05Size

    db $40,$11
    dw Prompt06GfxPtrChange
    dw Prompt06GfxPtrChange+Prompt06Size
    dw Prompt06Size

    dw PromptListEnder

; Main screen on existing file after the pink bookmark has been obtained.
; Notice the lack of a "change names" option here, and the "delete" moved up.
StructPinkBookmarkFile:
    db $10,$03
    dw Prompt00GfxPtrWelcome
    dw Prompt00GfxPtrWelcome+Prompt00Size
    dw Prompt00Size

    db $10,$06
    dw Prompt01GfxPtrGuest
    dw Prompt01GfxPtrGuest+Prompt01Size
    dw Prompt01Size

    db $10,$09
    dw Prompt02GfxPtrPartner
    dw Prompt02GfxPtrPartner+Prompt02Size
    dw Prompt02Size

    db $40,$0E
    dw Prompt05GfxPtrStart
    dw Prompt05GfxPtrStart+Prompt05Size
    dw Prompt05Size

    db $40,$11
    dw Prompt07GfxPtrDeleteFile
    dw Prompt07GfxPtrDeleteFile+Prompt07Size
    dw Prompt07Size

    dw PromptListEnder

; Comma after Touru's name (must update X pos, see next section)
StructComma:
    ; db $80,$06
    db $70,$06
    dw Prompt03GfxPtrComma
    dw Prompt03GfxPtrComma+Prompt03Size
    dw Prompt03Size

    dw PromptListEnder

; Period after Mari's name (similar)
StructPeriod:
    ; db $58,$09
    db $70,$09
    dw Prompt04GfxPtrPeriod
    dw Prompt04GfxPtrPeriod+Prompt04Size
    dw Prompt04Size

    dw PromptListEnder

; Cursor on top of three choices
StructCursorHigh:
    db $30,$0E
    dw NewCursorArrowGfxPtr
    dw NewCursorArrowGfxPtr+CursorSize
    dw CursorSize

    dw PromptListEnder

; Cursor on middle of three choices
StructCursorMiddle:
    db $30,$11
    dw NewCursorArrowGfxPtr
    dw NewCursorArrowGfxPtr+CursorSize
    dw CursorSize

    dw PromptListEnder

; Cursor on bottom of three choices
StructCursorLow:
    db $30,$14
    dw NewCursorArrowGfxPtr
    dw NewCursorArrowGfxPtr+CursorSize
    dw CursorSize

    dw PromptListEnder

; Start existing file -- player did not last see an ending; continue from save
StructResumeRestartScreen:
    db $30,$06
    dw Prompt08GfxPtrWhere
    dw Prompt08GfxPtrWhere+Prompt08Size
    dw Prompt08Size

    db $50,$0C
    dw Prompt09GfxPtrAutoSave
    dw Prompt09GfxPtrAutoSave+Prompt09Size
    dw Prompt09Size

    db $50,$0F
    dw Prompt10GfxPtrBeginning
    dw Prompt10GfxPtrBeginning+Prompt10Size
    dw Prompt10Size
; I found a fairly easy script modification that lets you replace the "restart"
; option here with going to the chapter list, so that you don't have to reach an
; ending to be able to jump to a previous chapter; should you do this, you'll
; want to update the text graphics as well (comment out previous 3 "dw" lines)
  ; dw Prompt11GfxPtrChapter
  ; dw Prompt11GfxPtrChapter+Prompt11Size
  ; dw Prompt11Size

    dw PromptListEnder

; Start existing file -- player last saw an ending; continue from chapter list
StructChapterRestartScreen:
    db $30,$06
    dw Prompt08GfxPtrWhere
    dw Prompt08GfxPtrWhere+Prompt08Size
    dw Prompt08Size

    db $50,$0C
    dw Prompt11GfxPtrChapter
    dw Prompt11GfxPtrChapter+Prompt11Size
    dw Prompt11Size

    db $50,$0F
    dw Prompt10GfxPtrBeginning
    dw Prompt10GfxPtrBeginning+Prompt10Size
    dw Prompt10Size

    dw PromptListEnder

; Cursor on "Auto save" or "From chapter"
StructResumeCursor:
    db $40,$0C
    dw NewCursorArrowGfxPtr
    dw NewCursorArrowGfxPtr+CursorSize
    dw CursorSize

    dw PromptListEnder

; Cursor on "Beginning"
StructRestartCursor:
    db $40,$0F
    dw NewCursorArrowGfxPtr
    dw NewCursorArrowGfxPtr+CursorSize
    dw CursorSize

    dw PromptListEnder

; Delete file screen
StructDeleteScreen:
    db $40,$06
    dw Prompt12GfxPtrWillDelete
    dw Prompt12GfxPtrWillDelete+Prompt12Size
    dw Prompt12Size

    db $40,$09
    dw Prompt13GfxPtrAreYouSure
    dw Prompt13GfxPtrAreYouSure+Prompt13Size
    dw Prompt13Size

    db $60,$0F
    dw Prompt14GfxPtrYes
    dw Prompt14GfxPtrYes+Prompt14Size
    dw Prompt14Size

    db $60,$12
    dw Prompt15GfxPtrNo
    dw Prompt15GfxPtrNo+Prompt15Size
    dw Prompt15Size

    dw PromptListEnder

; Cursor on "Yes"
StructYesCursor:
    db $50,$0F
    dw NewCursorArrowGfxPtr
    dw NewCursorArrowGfxPtr+CursorSize
    dw CursorSize

    dw PromptListEnder

; Cursor on "No"
StructNoCursor:
    db $50,$12
    dw NewCursorArrowGfxPtr
    dw NewCursorArrowGfxPtr+CursorSize
    dw CursorSize

    dw PromptListEnder

assert pc() < $5faf6b
    fillbyte $FF
    fill $5faf6b-pc()

;; -----------------------------------------------------------------------------

; reposition the names on screen
; You can move them at a granularity of one tile (8 bytes) left or right.
org $038136
    ; dw $0680
    dw $0670

org $038140
    ; dw $0958
    dw $0970

;; -----------------------------------------------------------------------------

; update bank numbers, more than I was initially expecting :P
org $03831b
    db bank(StructExistingFile) ; draw cursor arrow
org $038337
    db bank(StructExistingFile) ; clear cursor arrow

org $038451
    db bank(StructExistingFile) ; read X pixel column and Y tile row
org $038460
    db bank(StructExistingFile) ; read ptr to top row of gfx data
org $038469
    db bank(StructExistingFile) ; read size of one tile row of gfx data
org $038476
    db bank(StructExistingFile) ; read ptr to bottom row of gfx data
org $03847f
    db bank(StructExistingFile) ; read size again
org $0384a1
    db bank(StructExistingFile) ; check for FFFF terminator

org $0384ae
    db bank(StructExistingFile) ; clearing gfx - read X/Y position
org $0384c2
    db bank(StructExistingFile) ; clearing gfx - read size, top row
org $0384e3
    db bank(StructExistingFile) ; clearing gfx - read size again, bottom row
org $0384f6
    db bank(StructExistingFile) ; clearing gfx - check for FFFF terminator

; update bank offsets for the pointers
org $038046
    dw StructExistingFile
org $038067
    dw StructNewFile
org $038082
    dw StructPinkBookmarkFile
org $0380ef
    dw StructComma
org $038102
    dw StructPeriod
org $03808b
    dw StructCursorHigh
org $038091
    dw StructCursorMiddle
org $03804c
    dw StructCursorLow

org $03816b
    dw StructResumeRestartScreen
org $038183
    dw StructChapterRestartScreen
org $038189
    dw StructResumeCursor
org $03818f
    dw StructRestartCursor

org $0381bf
    dw StructDeleteScreen
org $0381c5
    dw StructYesCursor
org $0381cb
    dw StructNoCursor
