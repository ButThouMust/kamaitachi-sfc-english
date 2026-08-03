includefrom "MAIN insert text.asm"

; ------------------------------------------------------------------------------
; write new graphics data to ROM

org $01bddb
    incbin "gfx/name entry graphics English new.bin"
assert pc() <= $01bddb+$0f10
    fillbyte $ff
    fill $01bddb+$0f10-pc()

; ------------------------------------------------------------------------------
; new table of possible inputs for drawing two tile columns

; note: grouping like this allows trimming down the ASM code by doing a sequence
; of two sets of two column writes: [00 01], [01 02], [02 03]
; [gray accents][black ABCD][black accents][gray ABCD]

; left column
!TwoColumnAccentsGrayBox = $00
!TwoColumnABCD_BlackBox = $01
!TwoColumnAccentsBlackBox = $02
!TwoColumnABCD_GrayBox = $03

; right column
!TwoColumnSpaceBlackBox = $04
!TwoColumnDeleteBlackBox = $05
!TwoColumnClearBlackBox = $06
!TwoColumnFinishBlackBox = $07
!TwoColumnFinishGrayBox = $08

; black boxes OLD
; !TwoColumnABCD_BlackBox = $00
; !TwoColumnAccentsBlackBox = $01
; !TwoColumnSpaceBlackBox = $02
; !TwoColumnDeleteBlackBox = $03
; !TwoColumnClearBlackBox = $04
; !TwoColumnFinishBlackBox = $05

; gray boxes OLD
; !TwoColumnABCD_GrayBox = $06
; !TwoColumnAccentsGrayBox = $07
; !TwoColumnFinishGrayBox = $08

; "protag." in top left
!TwoColumnProtag1 = $09
!TwoColumnProtag2 = $0a
!TwoColumnProtag3 = $0b

; "Protagonist" in "please name the ___" notice
!TwoColumnProtagonist1 = $0c
!TwoColumnProtagonist2 = $0d
!TwoColumnProtagonist3 = $0e
!TwoColumnProtagonist4 = $0f

; "girlfriend" in top left (crunched version)
!TwoColumnGirlfriendTopLeft1 = $10
!TwoColumnGirlfriendTopLeft2 = $11
!TwoColumnGirlfriendTopLeft3 = $12

; "girlfriend" in "please name the ___" notice (noncrunched version)
!TwoColumnGirlfriendNotice1 = $13
!TwoColumnGirlfriendNotice2 = $14
!TwoColumnGirlfriendNotice3 = $15
!TwoColumnGirlfriendNotice4 = $16

!TwoColumnKiller1 = $17
!TwoColumnKiller2 = $18

!TwoColumnPleaseNameThe1 = $19
!TwoColumnPleaseNameThe2 = $1a
!TwoColumnPleaseNameThe3 = $1b
!TwoColumnPleaseNameThe4 = $1c
!TwoColumnPleaseNameThe5 = $1d
!TwoColumnPleaseNameThe6 = $1e

!NumberOfTwoColumnInputValues = $1+!TwoColumnPleaseNameThe6

; ------------------------------------------------------------------------------
; new set of tile IDs for the graphics

!TileIdClearBlackBox = $00
!TileIdClearGrayBox = $02

!TileIdSpaceBlackBox = $04
!TileIdSpaceGrayBox = $06

!TileIdABCD_BlackBox = $08
!TileIdABCD_GrayBox = $0a

!TileIdAccentsBlackBox = $0c
!TileIdAccentsGrayBox = $0e

!TileIdDeleteBlackBox = $60
!TileIdDeleteGrayBox = $62

!TileIdFinishBlackBox = $64
!TileIdFinishGrayBox = $66

; "protag." in top left
!TileIdProtag1 = $68
!TileIdProtag2 = $6a
!TileIdProtag3 = $6c

; "girlfriend" in top left (crunched version)
!TileIdGirlfriendTopLeft1 = $88
!TileIdGirlfriendTopLeft2 = $8a
!TileIdGirlfriendTopLeft3 = $8c

!TileIdGrayBoxHighlight = $6e
!TileIdGrayBoxKanaInKanjiGrid = $8e

!TileIdEmpty = $a0

!TileIdPleaseNameThe1 = $b0
!TileIdPleaseNameThe2 = $b2
!TileIdPleaseNameThe3 = $b4
!TileIdPleaseNameThe4 = $b6
!TileIdPleaseNameThe5 = $b8
!TileIdPleaseNameThe6 = $ba

!TileIdKiller1 = $bc
!TileIdKiller2 = $be

; "Protagonist" in "please name the ___" notice
!TileIdProtagonist1 = $d0
!TileIdProtagonist2 = $d2
!TileIdProtagonist3 = $d4
!TileIdProtagonist4 = $d6

; "girlfriend" in "please name the ___" notice (noncrunched version)
!TileIdGirlfriendNotice1 = $d8
!TileIdGirlfriendNotice2 = $da
!TileIdGirlfriendNotice3 = $dc
!TileIdGirlfriendNotice4 = $de

; ------------------------------------------------------------------------------
; new heights of buttons on screen

!TileHeightClear = 6
!TileHeightSpace = 6

; these two only take up 5 tile rows, but must round up to multiple of 2
!TileHeightABCD = 6
!TileHeightAccents = 6

!TileHeightDelete = 4
!TileHeightFinish = 4

!TileHeightOtherText = 2

; ------------------------------------------------------------------------------
; "new"/updated X/Y positions (in units of TILES) for buttons on screen

!OneRowInTilemap = $40
function TilemapOffsetFromXY(x, y) = y*!OneRowInTilemap+x*2

!LeftColumnOfButtons = $2
!RightColumnOfButtons = $1c
!ColumnTopY = $6

!ABCD_TilemapY = !ColumnTopY+4
!AccentsTilemapY = !ABCD_TilemapY+1+!TileHeightABCD
!SpaceTilemapY = !ColumnTopY
!DeleteTilemapY = !SpaceTilemapY+!TileHeightSpace
!ClearTilemapY = !DeleteTilemapY+!TileHeightDelete
!FinishTilemapY = !ClearTilemapY+1+!TileHeightClear

!CharToBeNamedInTopLeftX = 1 ; originally 2, move left 1 to widen name box
!KillerInTopLeftX = 2
!CharToBeNamedInTopLeftY = 2
!CharToBeNamedInNoticeX = $c
!CharToBeNamedInNoticeY = $f
!PleaseNameTheBlankX = $a
!PleaseNameTheBlankY = $c

; ------------------------------------------------------------------------------

; change how to clear out the "protag." in top left corner or the notice box
!NoticeBoxWidth = $10
!TopLeftBoxWidth = $6
org $01871f
; tile width * 2 = how many bytes to "clear out"
    dw (!NoticeBoxWidth+1)*2,!TopLeftBoxWidth*2
; skip size to start of row
    dw !OneRowInTilemap-(!NoticeBoxWidth+1)*2
    dw !OneRowInTilemap-!TopLeftBoxWidth*2
; ending offset in tilemap, in bytes
    dw TilemapOffsetFromXY(!CharToBeNamedInTopLeftX+!TopLeftBoxWidth,$12)
    dw TilemapOffsetFromXY(!CharToBeNamedInTopLeftX,2+!TileHeightOtherText)
; starting offset in tilemap, in bytes
    dw TilemapOffsetFromXY(!CharToBeNamedInTopLeftX+!TopLeftBoxWidth,$b)
    dw TilemapOffsetFromXY(!CharToBeNamedInTopLeftX,2)

; ------------------------------------------------------------------------------

; change behavior for the initial character grid for naming Tooru or Mari
; remove access to the kanji table, and set top/bottom borders as non-scrollable
org LIST_value_to_write_for_button_type_018738+$10
  ; db $04,$04,$06
    db $00,$00,$07

; ------------------------------------------------------------------------------

; change what positions on the right edge of the grid go to the Delete and Clear
; buttons

; edit the start positions in the grid
org LIST_start_offset_in_button_type_buffer_018753+$c
  ; db $4c,$7c
    db $4c,$6c

; edit the repeat count for the grid
org LIST_num_times_to_repeat_button_type_value_018789+$c
  ; db $03,$02
    db $02,$03

; ------------------------------------------------------------------------------

; need to edit $018809-$018835 (sprite X/Y positions)
org $018809
ListButtonHighlightSpritePositions:
    ; I'm planning to cut out the kanji block, but keeping these placeholder IDs
    ; to indicate the button still exists in control flow
    db !LeftColumnOfButtons*8,(!ColumnTopY)*8
    db !LeftColumnOfButtons*8,(!ColumnTopY+2)*8

    db !RightColumnOfButtons*8,(!DeleteTilemapY)*8
    db !RightColumnOfButtons*8,(!DeleteTilemapY+2)*8

    db !RightColumnOfButtons*8,(!FinishTilemapY)*8
    db !RightColumnOfButtons*8,(!FinishTilemapY+2)*8

    db !LeftColumnOfButtons*8,(!AccentsTilemapY)*8
    db !LeftColumnOfButtons*8,(!AccentsTilemapY+2)*8
    db !LeftColumnOfButtons*8,(!AccentsTilemapY+4)*8
    db !LeftColumnOfButtons*8,(!AccentsTilemapY+6)*8

    db !LeftColumnOfButtons*8,(!ABCD_TilemapY)*8
    db !LeftColumnOfButtons*8,(!ABCD_TilemapY+2)*8
    db !LeftColumnOfButtons*8,(!ABCD_TilemapY+4)*8
    db !LeftColumnOfButtons*8,(!ABCD_TilemapY+6)*8

    db !RightColumnOfButtons*8,(!SpaceTilemapY)*8
    db !RightColumnOfButtons*8,(!SpaceTilemapY+2)*8
    db !RightColumnOfButtons*8,(!SpaceTilemapY+4)*8

    db !RightColumnOfButtons*8,(!ClearTilemapY)*8
    db !RightColumnOfButtons*8,(!ClearTilemapY+2)*8
    db !RightColumnOfButtons*8,(!ClearTilemapY+4)*8

    db $00,$e0
    db $2f,$37

    dw $FFFF

assert pc() == $018837

; ------------------------------------------------------------------------------

; need to edit $018837-$01884D (tile numbers for sprites)

!TwoTileRows = $20

ListButtonHighlightTileNums:
; original list:
    ; $7f1892
    ; db $02,$22         ; kanji, gray
    ; --
    ; $7f1893
    ; db $04,$24         ; clear, gray
    ; db $06,$26         ; finish, gray
    ; --
    ; $7f1894
    ; db $0E,$2E,$4E,$6E ; katakana, gray
    ; $7f1895
    ; db $0C,$2C,$4C,$6C ; hiragana, gray
    ; --
    ; $7f1896-$7f1897
    ; db $0A,$2A,$4A     ; space, gray
    ; db $08,$28,$48     ; delete, gray
    ; db $8C,$8E         ; gray highlight boxes
    ; --
    ; db $ff             ; list terminator

    ; ----------

    ; bits 50 in $7F1892
    db !TileIdGrayBoxHighlight
    db !TileIdGrayBoxHighlight

    ; ----------

    ; bits 05 in $7F1893
    db !TileIdDeleteGrayBox
    db !TileIdDeleteGrayBox+!TwoTileRows

    ; bits 50 in $7F1893
    db !TileIdFinishGrayBox
    db !TileIdFinishGrayBox+!TwoTileRows

    ; ----------

    ; bits 55 in $7F1894 (only need bits 15?)
    db !TileIdAccentsGrayBox
    db !TileIdAccentsGrayBox+!TwoTileRows
    db !TileIdAccentsGrayBox+!TwoTileRows*2
    db !TileIdEmpty

    ; bits 55 in $7F1895 (only need bits 15?)
    db !TileIdABCD_GrayBox
    db !TileIdABCD_GrayBox+!TwoTileRows
    db !TileIdABCD_GrayBox+!TwoTileRows*2
    db !TileIdEmpty

    ; ----------

    ; bits 15 in $7F1896
    db !TileIdSpaceGrayBox
    db !TileIdSpaceGrayBox+!TwoTileRows
    db !TileIdSpaceGrayBox+!TwoTileRows*2

    ; bit  40 in $7F1896, bits 05 in $7F1897
    db !TileIdClearGrayBox
    db !TileIdClearGrayBox+!TwoTileRows
    db !TileIdClearGrayBox+!TwoTileRows*2

    ; reuse original sprite slots to reduce ASM edits; one subroutine assumes
    ; that these gray boxes are the last two sprite slots for OAM DMAs
    ; TODO unfortunately might need to get rid of the name box highlight
    ; bits 50 in $7F1897
    db !TileIdGrayBoxHighlight
    db !TileIdGrayBoxKanaInKanjiGrid

    db $ff

assert pc() == $01884E

; or as a table of addresses and OAM sprite IDs:
; 7f1892  6A: PLACEHOLDER top     7f1896  78: space top
;         6B: PLACEHOLDER bottom          79: space middle
; 7f1893  6C: delete top                  7a: space bottom
;         6D: delete bottom               7b: clear top
;         6E: finish top          7f1897  7c: clear middle
;         6F: finish bottom               7d: clear bottom
; 7f1894  70-73: accented letters         7e: box in name window
; 7f1895  74-77: alphabet+punct.          7f: box in char grid

; places in bank 04 ASM to edit for enabling/disabling sprites:
; $048326: turn off kanji/clear/finish, turn on both highlight boxes
; $048558: turn off ALL sprites, but turn on both highlight boxes
; $048CFC: turn off all button sprites, turn on both highlight boxes
; $048E96: turn on kanji box + name highlight, turn everything else off
; $048ef7: turn on hiragana box + name highlight, turn everything else off
; $048f3e: turn on katagana box + name highlight, turn everything else off
; $048fb0: turn on space + name highlight, turn everything else off
; $048fde: turn on delete + name highlight, turn everything else off
; $04904b: turn on finish + name highlight, turn everything else off

; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------

; need to edit $01884E-$018875 (two tile col writes table: top left tile ID)
; print hex(pc(),6)
ListTileIdsForTwoColumnWrites:
; black boxes OLD
    ; db !TileIdABCD_BlackBox,!TileIdAccentsBlackBox
    ; db !TileIdSpaceBlackBox,!TileIdDeleteBlackBox
    ; db !TileIdClearBlackBox,!TileIdFinishBlackBox

; gray boxes OLD
    ; db !TileIdABCD_GrayBox
    ; db !TileIdAccentsGrayBox
    ; db !TileIdFinishGrayBox

; left column
    db !TileIdAccentsGrayBox,!TileIdABCD_BlackBox
    db !TileIdAccentsBlackBox,!TileIdABCD_GrayBox

; right column
    db !TileIdSpaceBlackBox,!TileIdDeleteBlackBox
    db !TileIdClearBlackBox,!TileIdFinishBlackBox
    db !TileIdFinishGrayBox

; protag in top left
    db !TileIdProtag1,!TileIdProtag2,!TileIdProtag3

; protagonist in notice
    db !TileIdProtagonist1,!TileIdProtagonist2
    db !TileIdProtagonist3,!TileIdProtagonist4

; girlfriend in top left
    db !TileIdGirlfriendTopLeft1
    db !TileIdGirlfriendTopLeft2
    db !TileIdGirlfriendTopLeft3

; girlfriend in notice
    db !TileIdGirlfriendNotice1,!TileIdGirlfriendNotice2
    db !TileIdGirlfriendNotice3,!TileIdGirlfriendNotice4

; killer in top left
    db !TileIdKiller1,!TileIdKiller2

; "please name the" in notice
    db !TileIdPleaseNameThe1,!TileIdPleaseNameThe2
    db !TileIdPleaseNameThe3,!TileIdPleaseNameThe4
    db !TileIdPleaseNameThe5,!TileIdPleaseNameThe6

; ------------------

; need to edit $018876-$01889D (two tile col writes table: height = # tile rows)
; print hex(pc(),6)
ListNumTileRowsForButton:
; black boxes OLD
    ; db !TileHeightABCD,!TileHeightAccents
    ; db !TileHeightSpace,!TileHeightDelete
    ; db !TileHeightClear,!TileHeightFinish

; gray boxes OLD
    ; db !TileHeightABCD
    ; db !TileHeightAccents
    ; db !TileHeightFinish

; left column
    db !TileHeightAccents,!TileHeightABCD
    db !TileHeightAccents,!TileHeightABCD

; right column
    db !TileHeightSpace,!TileHeightDelete
    db !TileHeightClear,!TileHeightFinish
    db !TileHeightFinish

; protag in top left
    db !TileHeightOtherText,!TileHeightOtherText,!TileHeightOtherText

; protagonist in notice
    db !TileHeightOtherText,!TileHeightOtherText
    db !TileHeightOtherText,!TileHeightOtherText

; girlfriend in top left
    db !TileHeightOtherText,!TileHeightOtherText,!TileHeightOtherText

; girlfriend in notice
    db !TileHeightOtherText,!TileHeightOtherText
    db !TileHeightOtherText,!TileHeightOtherText

; killer in top left
    db !TileHeightOtherText,!TileHeightOtherText

; "please name the" in notice
    db !TileHeightOtherText,!TileHeightOtherText,!TileHeightOtherText
    db !TileHeightOtherText,!TileHeightOtherText,!TileHeightOtherText

; ------------------

; need to edit $01889E-$0188ED (two tile col writes table: tilemap offset BYTES)

; print hex(pc(),6)
ListStartingTilemapOffsetsForButtons:
; black boxes OLD
    ; dw TilemapOffsetFromXY(!LeftColumnOfButtons,!ABCD_TilemapY)
    ; dw TilemapOffsetFromXY(!LeftColumnOfButtons,!AccentsTilemapY)
    ; dw TilemapOffsetFromXY(!RightColumnOfButtons,!SpaceTilemapY)
    ; dw TilemapOffsetFromXY(!RightColumnOfButtons,!DeleteTilemapY)
    ; dw TilemapOffsetFromXY(!RightColumnOfButtons,!ClearTilemapY)
    ; dw TilemapOffsetFromXY(!RightColumnOfButtons,!FinishTilemapY)

; gray boxes OLD
    ; dw TilemapOffsetFromXY(!LeftColumnOfButtons,!ABCD_TilemapY)
    ; dw TilemapOffsetFromXY(!LeftColumnOfButtons,!AccentsTilemapY)
    ; dw TilemapOffsetFromXY(!RightColumnOfButtons,!FinishTilemapY)

; left column
    dw TilemapOffsetFromXY(!LeftColumnOfButtons,!AccentsTilemapY)
    dw TilemapOffsetFromXY(!LeftColumnOfButtons,!ABCD_TilemapY)
    dw TilemapOffsetFromXY(!LeftColumnOfButtons,!AccentsTilemapY)
    dw TilemapOffsetFromXY(!LeftColumnOfButtons,!ABCD_TilemapY)

; right column
    dw TilemapOffsetFromXY(!RightColumnOfButtons,!SpaceTilemapY)
    dw TilemapOffsetFromXY(!RightColumnOfButtons,!DeleteTilemapY)
    dw TilemapOffsetFromXY(!RightColumnOfButtons,!ClearTilemapY)
    dw TilemapOffsetFromXY(!RightColumnOfButtons,!FinishTilemapY)
    dw TilemapOffsetFromXY(!RightColumnOfButtons,!FinishTilemapY)

; protag in top left
    dw TilemapOffsetFromXY(!CharToBeNamedInTopLeftX,!CharToBeNamedInTopLeftY)
    dw TilemapOffsetFromXY(!CharToBeNamedInTopLeftX+$2,!CharToBeNamedInTopLeftY)
    dw TilemapOffsetFromXY(!CharToBeNamedInTopLeftX+$4,!CharToBeNamedInTopLeftY)

; protagonist in notice
    dw TilemapOffsetFromXY(!CharToBeNamedInNoticeX,!CharToBeNamedInNoticeY)
    dw TilemapOffsetFromXY(!CharToBeNamedInNoticeX+$2,!CharToBeNamedInNoticeY)
    dw TilemapOffsetFromXY(!CharToBeNamedInNoticeX+$4,!CharToBeNamedInNoticeY)
    dw TilemapOffsetFromXY(!CharToBeNamedInNoticeX+$6,!CharToBeNamedInNoticeY)

; girlfriend in top left
    dw TilemapOffsetFromXY(!CharToBeNamedInTopLeftX,!CharToBeNamedInTopLeftY)
    dw TilemapOffsetFromXY(!CharToBeNamedInTopLeftX+$2,!CharToBeNamedInTopLeftY)
    dw TilemapOffsetFromXY(!CharToBeNamedInTopLeftX+$4,!CharToBeNamedInTopLeftY)

; girlfriend in notice
    dw TilemapOffsetFromXY(!CharToBeNamedInNoticeX,!CharToBeNamedInNoticeY)
    dw TilemapOffsetFromXY(!CharToBeNamedInNoticeX+$2,!CharToBeNamedInNoticeY)
    dw TilemapOffsetFromXY(!CharToBeNamedInNoticeX+$4,!CharToBeNamedInNoticeY)
    dw TilemapOffsetFromXY(!CharToBeNamedInNoticeX+$6,!CharToBeNamedInNoticeY)

; killer in top left
    dw TilemapOffsetFromXY(!KillerInTopLeftX,!CharToBeNamedInTopLeftY)
    dw TilemapOffsetFromXY(!KillerInTopLeftX+$2,!CharToBeNamedInTopLeftY)

; "please name the" in notice
    dw TilemapOffsetFromXY(!PleaseNameTheBlankX,!PleaseNameTheBlankY)
    dw TilemapOffsetFromXY(!PleaseNameTheBlankX+$2,!PleaseNameTheBlankY)
    dw TilemapOffsetFromXY(!PleaseNameTheBlankX+$4,!PleaseNameTheBlankY)
    dw TilemapOffsetFromXY(!PleaseNameTheBlankX+$6,!PleaseNameTheBlankY)
    dw TilemapOffsetFromXY(!PleaseNameTheBlankX+$8,!PleaseNameTheBlankY)
    dw TilemapOffsetFromXY(!PleaseNameTheBlankX+$a,!PleaseNameTheBlankY)

; sanity check: make sure that the table sizes are all consistent
assert ListStartingTilemapOffsetsForButtons-ListNumTileRowsForButton == !NumberOfTwoColumnInputValues
assert ListNumTileRowsForButton-ListTileIdsForTwoColumnWrites == !NumberOfTwoColumnInputValues
assert pc()-ListStartingTilemapOffsetsForButtons == (!NumberOfTwoColumnInputValues)*2

; make sure that data didn't overflow
assert pc() <= $0188ee
    fillbyte $ff
    fill $0188ee-pc()

; ------------------------------------------------------------------------------

; change name box to be a tile wider on the left, and a tile wider on the right
; specifically, change the tilemap offsets for the tile IDs present at $01893B

!NameBoxWidth = $12 ; originally $10
!NameBoxLeftX = !CharToBeNamedInTopLeftX+!TopLeftBoxWidth
!NameBoxRightX = !NameBoxLeftX+!NameBoxWidth-1
!NameBoxTopY = $2
!NameBoxBottomY = !NameBoxTopY+3

; first, adjust the positions of the corner tiles and left/right edges
org LIST_offsets_for_name_entry_screen_tilemap_buffer_01895B
    dw TilemapOffsetFromXY(!NameBoxLeftX,!NameBoxTopY)     ; TL corner
    dw TilemapOffsetFromXY(!NameBoxRightX,!NameBoxTopY)    ; TR corner
    dw TilemapOffsetFromXY(!NameBoxLeftX,!NameBoxTopY+1)   ; left edge 1
    dw TilemapOffsetFromXY(!NameBoxLeftX,!NameBoxTopY+2)   ; left edge 2
    dw TilemapOffsetFromXY(!NameBoxRightX,!NameBoxTopY+1)  ; left edge 1
    dw TilemapOffsetFromXY(!NameBoxRightX,!NameBoxTopY+2)  ; left edge 2
    dw TilemapOffsetFromXY(!NameBoxLeftX,!NameBoxBottomY)  ; BL corner
    dw TilemapOffsetFromXY(!NameBoxRightX,!NameBoxBottomY) ; BR corner

; next, adjust the runs for the tiles on the box's top and bottom edges
org LIST_offsets_in_tilemap_buffer_for_name_entry_boxes_0188FA
    dw TilemapOffsetFromXY(!NameBoxLeftX+1,!NameBoxTopY)    ; top edge start
    skip 1*$2
    dw TilemapOffsetFromXY(!NameBoxLeftX+1,!NameBoxBottomY) ; bottom edge start
org LIST_repeat_count_for_tile_ID_018926
    db !NameBoxWidth-$2     ; top edge width
    skip 1*$1
    db !NameBoxWidth-$2     ; bottom edge width
