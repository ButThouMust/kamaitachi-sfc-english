asar 1.90
check title "KAMAITACHI NO YORU    "
lorom

;; -----------------------------------------------------------------------------
;; -----------------------------------------------------------------------------

!NumTilemapsForVfx0E = $E
!TilemapPtrTableForVfx0E = $03961C
; !PtrSize = 3

; !JPROM = "Kamaitachi no Yoru (Japan).sfc"

!LzFolder = "recompressed LZSS blocks"

!NewCurtainTileset = "!LzFolder/recompressed $04C004.bin"
!NewCurtainTilemap = "!LzFolder/recompressed $04DD73.bin"

!NewVfx0ETileset = "!LzFolder/recompressed $5F8000.bin"

!NewVfx0ETilemap0 = "!LzFolder/recompressed $5FA34C.bin"
!NewVfx0ETilemap1 = "!LzFolder/recompressed $5FA37A.bin"
!NewVfx0ETilemap2 = "!LzFolder/recompressed $5FA3C4.bin"
!NewVfx0ETilemap3 = "!LzFolder/recompressed $5FA42A.bin"
!NewVfx0ETilemap4 = "!LzFolder/recompressed $5FA4AE.bin"
!NewVfx0ETilemap5 = "!LzFolder/recompressed $5FA548.bin"
!NewVfx0ETilemap6 = "!LzFolder/recompressed $5FA600.bin"
!NewVfx0ETilemap7 = "!LzFolder/recompressed $5FA6D0.bin"
!NewVfx0ETilemap8 = "!LzFolder/recompressed $5FA7BE.bin"
!NewVfx0ETilemap9 = "!LzFolder/recompressed $5FA8C7.bin"
!NewVfx0ETilemap10 = "!LzFolder/recompressed $5FA9EC.bin"
!NewVfx0ETilemap11 = "!LzFolder/recompressed $5FAB2F.bin"
!NewVfx0ETilemap12 = "!LzFolder/recompressed $5FAC8B.bin"
!NewVfx0ETilemap13 = "!LzFolder/recompressed $5FADF6.bin"

!NewVfx0BTileset = "!LzFolder/recompressed $5FC9A2.bin"
!NewVfx0BTilemap = "!LzFolder/recompressed $5FCE57.bin"

!NewVfx37Tileset = "!LzFolder/recompressed $5FD15B.bin"
!NewVfx37Tilemap = "!LzFolder/recompressed $5FD564.bin"

!NewVfx3BTileset = "!LzFolder/recompressed $5FD7E7.bin"

;; -----------------------------------------------------------------------------
;; -----------------------------------------------------------------------------

; see ASM file for modifying the silhouette graphics compression format
org NewCurtainTilesetPtr
    incbin "!NewCurtainTileset"
NewCurtainTilemapPtr:
    incbin "!NewCurtainTilemap"
NewCurtainPalettePtr:
    incbin "!JPROM":snestopc($04df07)..snestopc($04df87)

; update pointer to tileset
org $03a8e6
    dl NewCurtainTilesetPtr

; update bank offset and bank number for pointer to tilemap
org $03d334
    dw NewCurtainTilemapPtr
org $03d33a
    db bank(NewCurtainTilemapPtr)

; update bank offset and bank number for pointer to palette
org $03d36a
    dw NewCurtainPalettePtr
org $03d370
    db bank(NewCurtainPalettePtr)

; clear out original space in the ROM for good measure
org $04c004
    fillbyte $FF
    fill $04df87-pc()

;; -----------------------------------------------------------------------------
;; -----------------------------------------------------------------------------

; insert recompressed tileset, don't need to repoint it
org $5f8000
    incbin "!NewVfx0ETileset"

; next, move the palette table back to here
RepointedPaletteTable:
    incbin "!JPROM":snestopc($5fa33c)..snestopc($5fa34c)

; then, insert recompressed tilemaps
    for i = 0..!NumTilemapsForVfx0E
        NewVfx0ETilemapPtr!i:
            incbin "!{NewVfx0ETilemap!{i}}"
    endfor

; the freed up space allows us to move the data for the "bad end" graphic here
NewLocationForBadEndGraphic:
  ; incbin "!JPROM":snestopc($04bf04)..snestopc($04c004)
    incbin "gfx/bad end english graphic tiles.bin"

; we can also fit in the metadata table for the file management prompts
; off-load that to another ASM file to not clutter stuff up here
FreedSpaceAfterLzssVfx0E = pc()

; clear out the original space for the bad end graphic for good measure
org $04bf04
    fillbyte $FF
    fill $100

;; -----------------------------------------------------------------------------
;; -----------------------------------------------------------------------------

; update pointer for the palette table
org $0394d2
    dl RepointedPaletteTable

; update pointers for the tilemaps
org $03961c
    for i = 0..!NumTilemapsForVfx0E
        dl NewVfx0ETilemapPtr!i
    endfor

; update pointers for the 4 tile rows of the bad end graphic
org $03851b
    dl NewLocationForBadEndGraphic
org $038526
    dl NewLocationForBadEndGraphic+$40
org $038531
    dl NewLocationForBadEndGraphic+$80
org $03853c
    dl NewLocationForBadEndGraphic+$c0

; optional: test the edit by going to $08a489-6 in the Japanese script
; org $05fe63
;     db $91, $51, $4F, $02

;; -----------------------------------------------------------------------------
;; -----------------------------------------------------------------------------

; reinsert the other LZSS data blocks

org $5fc9a2
; optional: test the edit by going to $099651-2 in the Japanese script
NewVfx0BTilesetPtr:
    incbin "!NewVfx0BTileset"
NewVfx0BTilemapPtr:
    incbin "!NewVfx0BTilemap"

; optional: test the edit by going to $07c079-7 in the Japanese script
NewVfx37TilesetPtr:
    incbin "!NewVfx37Tileset"
NewVfx37TilemapPtr:
    incbin "!NewVfx37Tilemap"

; optional: test the edit by going to $0c80d3-3 in the Japanese script
NewVfx3BTilesetPtr:
    incbin "!NewVfx3BTileset"

; move back a handful of blocks to make a bigger contiguous empty space
NewColorGenerationTable1:
    incbin "!JPROM":snestopc($5fd99a)..snestopc($5fdd9a)
NewColorGenerationTable2:
    incbin "!JPROM":snestopc($5fdd9a)..snestopc($5fe19a)
NewDataTableColorGeneration:
    incbin "!JPROM":snestopc($5fe19a)..snestopc($5fe99a)
NewBGR111Table:
    incbin "!JPROM":snestopc($5fe99a)..snestopc($5fe9dc)
NewBrownscaleLookupTable:
    incbin "!JPROM":snestopc($5fe9dc)..snestopc($5fea1c)

; you might be able to get away with not including this block?
; New5fea1cDataBlock:
;     incbin "!JPROM":snestopc($5fea1c)..snestopc($5fea5c)

FreedSpaceInBank5F:
    assert pc() <= $5fec1c
        fillbyte $FF
        fill $5fec1c-pc()

; update their pointers
org $5fc992
    dl NewVfx0BTilesetPtr, NewVfx0BTilemapPtr
    skip $2
    dl NewVfx37TilesetPtr, NewVfx37TilemapPtr

org $03d927
    dw NewVfx3BTilesetPtr

org $03d92d
    db bank(NewVfx3BTilesetPtr)

org $03c52f
    dl NewColorGenerationTable1
org $03c53b
    dl NewColorGenerationTable1
org $03c56d
    dl NewColorGenerationTable1
org $03c574
    dl NewColorGenerationTable1
org $03c5a1
    dl NewColorGenerationTable1
org $03c5a8
    dl NewColorGenerationTable1
org $03c5dd
    dl NewColorGenerationTable1
org $03c5e7
    dl NewColorGenerationTable1
org $03c617
    dl NewColorGenerationTable1
org $03c61e
    dl NewColorGenerationTable1
org $03c650
    dl NewColorGenerationTable1
org $03c657
    dl NewColorGenerationTable1

org $03c685
    dl NewColorGenerationTable2

org $03c9fa
    dl NewDataTableColorGeneration
org $03ca0d
    dl NewDataTableColorGeneration
org $03ca20
    dl NewDataTableColorGeneration

org $03c391
    dl NewBGR111Table

org $03c311
    dl NewBrownscaleLookupTable

; block @ $5FEA1C doesn't have any true direct pointers to it? ASM @ $03D2C1 has
; the "hidden" value [1C EA], but it's used more for calculating a value as:
; X <- A + 0xEA1C = 0x300 + N*0x10 + 0xEA1C = 0xED1C + N*0x10 (N is a hex digit)
; org $03d2c1
;    dl New5fea1cDataBlock

; eh, I'll just update the (unused) ASM code to use a slightly more accurate
; base pointer value and offsets

org $03d2ba
  ; part of adc #$0030
    dw $0010

org $03d2c1
  ; part of adc #$ea1c
    dw $ec1c
