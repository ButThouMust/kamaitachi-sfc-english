includefrom "MAIN recompress and repoint data.asm"
; asar 1.90
; check title "KAMAITACHI NO YORU    "
; lorom

; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------

; simple struct for readability
struct JapaneseGfxPtrTable $258000
    .PalettePtr skip 3
    .TilemapPtr skip 3
    .TilesetPtr skip 3
endstruct

; !OriginalGfxPtrTable = $258000
!NumGfxIds = $82
!LabyrinthPathwaysIdStart = 4D
!LabyrinthPathwaysIdEnd = 51
!BookmarkGfxId = 66
!OpeningCreditsGfxId = 7D

function GfxPalettePtrN(n) = readfile3("!JPROM",snestopc(JapaneseGfxPtrTable[n].PalettePtr))
function GfxTilemapPtrN(n) = readfile3("!JPROM",snestopc(JapaneseGfxPtrTable[n].TilemapPtr))
function GfxTilesetPtrN(n) = readfile3("!JPROM",snestopc(JapaneseGfxPtrTable[n].TilesetPtr))

; --------------------

print "Repointing BG GFX palette data..."

!EndCreditsGfxData = $5EC49C

; insert file, make sure end credits data block(s) after it didn't get clobbered
org $5E8000
    incbin "recompressed LZSS blocks/recompressed kamaitachi font - name entry char grid data.bin"
  ; assert pc()+$375A < !EndCreditsGfxData

; use freed up space from using smaller data block to move palette data here;
; many groups of IDs have identical palettes, which allows us to reuse them and
; save, no joke, over a kilobyte
NewSpaceForGfxPaletteData:
  ; for n = $00..!NumGfxIds
  ;     NewGfxPalettePtr!{dec2hexTwoDigits_!{n}}:
  ;         incbin "!JPROM":snestopc(GfxPalettePtrN(!n))..snestopc(GfxTilesetPtrN(!n))
  ; endfor

    for n = $00..$21+1
        NewGfxPalettePtr!{dec2hexTwoDigits_!{n}}:
            incbin "!JPROM":snestopc(GfxPalettePtrN(!n))..snestopc(GfxTilesetPtrN(!n))
    endfor

    ; reuse palette for looking at broom closet, closed or open
    ; you must use palette 0x22 because palette 0x23 is a subset of it
    NewGfxPalettePtr22:
    NewGfxPalettePtr23:
        incbin "!JPROM":snestopc(GfxPalettePtrN($22))..snestopc(GfxTilesetPtrN($22))

    for n = $24..$29+1
        NewGfxPalettePtr!{dec2hexTwoDigits_!{n}}:
            incbin "!JPROM":snestopc(GfxPalettePtrN(!n))..snestopc(GfxTilesetPtrN(!n))
    endfor

    ; reuse palettes for guest room with curtains open or closed
    NewGfxPalettePtr2A:
    NewGfxPalettePtr2B:
        incbin "!JPROM":snestopc(GfxPalettePtrN($2A))..snestopc(GfxTilesetPtrN($2A))

    for n = $2c..$4C+1
        NewGfxPalettePtr!{dec2hexTwoDigits_!{n}}:
            incbin "!JPROM":snestopc(GfxPalettePtrN(!n))..snestopc(GfxTilesetPtrN(!n))
    endfor

    ; all the labyrinth pathways' graphics use the same palette; IDs 4D-57
    for n = $!LabyrinthPathwaysIdStart..$57+1
        NewGfxPalettePtr!{dec2hexTwoDigits_!{n}}:
    endfor
        incbin "!JPROM":snestopc(GfxPalettePtrN($!LabyrinthPathwaysIdStart))..snestopc(GfxTilesetPtrN($!LabyrinthPathwaysIdStart+1))

    NewGfxPalettePtr58:
        incbin "!JPROM":snestopc(GfxPalettePtrN($58))..snestopc(GfxTilesetPtrN($58))

    ; reuse palette for the two images for labyrinth door 6
    NewGfxPalettePtr59:
    NewGfxPalettePtr5A:
        incbin "!JPROM":snestopc(GfxPalettePtrN($59))..snestopc(GfxTilesetPtrN($59))

    for n = $5b..$67+1
        NewGfxPalettePtr!{dec2hexTwoDigits_!{n}}:
            incbin "!JPROM":snestopc(GfxPalettePtrN(!n))..snestopc(GfxTilesetPtrN(!n))
    endfor

    ; reuse palettes for dismemberment analogy with banana (68-6D), and "BOMB" (6E)
    for n = $68..$6e+1
        NewGfxPalettePtr!{dec2hexTwoDigits_!{n}}:
    endfor
        incbin "!JPROM":snestopc(GfxPalettePtrN($68))..snestopc(GfxTilesetPtrN($68))

    ; reuse palettes for buzzsaw animation
    NewGfxPalettePtr6F:
    NewGfxPalettePtr70:
        incbin "!JPROM":snestopc(GfxPalettePtrN($6F))..snestopc(GfxTilesetPtrN($6F))

    ; reuse palettes for frames of animation for firing laser
    for n = $71..$78+1
        NewGfxPalettePtr!{dec2hexTwoDigits_!{n}}:
    endfor
        incbin "!JPROM":snestopc(GfxPalettePtrN($71))..snestopc(GfxTilesetPtrN($71))

    ; pictures explaining how the window shattered
    NewGfxPalettePtr79:
    NewGfxPalettePtr7A:
    NewGfxPalettePtr7B:
        incbin "!JPROM":snestopc(GfxPalettePtrN($79))..snestopc(GfxTilesetPtrN($79))

    for n = $7C..!NumGfxIds
        NewGfxPalettePtr!{dec2hexTwoDigits_!{n}}:
            incbin "!JPROM":snestopc(GfxPalettePtrN(!n))..snestopc(GfxTilesetPtrN(!n))
    endfor

NewEndCreditsLineIDs = pc()
assert pc() < !EndCreditsGfxData
fillbyte $ff
fill !EndCreditsGfxData-pc()

; --------------------

print "Repointing the two big sound data blocks..."

!OldSoundDataBlock1Start = $108000
!OldSoundDataBlock2Start = $2382ec
!OldSoundDataBlock2End = $24f2c8

; I used a spreadsheet to determine this position; calculate how much space the
; sound data, tilesets, and tilemaps take up, and how much space you save from
; recompressing things or moving stuff around
!NewSoundDataBlock1Start = $10cd24

org $00e83b
    dw !NewSoundDataBlock1Start
org $00e840
    dw bank(!NewSoundDataBlock1Start)
org $00e848
    dw NewSoundDataBlock2Start
org $00e84d
    dw bank(NewSoundDataBlock2Start)

org !OldSoundDataBlock1Start
    fillbyte $FF
    fill !NewSoundDataBlock1Start-pc()

org !NewSoundDataBlock1Start
    check bankcross off
    incbin "!JPROM":snestopc(!OldSoundDataBlock1Start)..snestopc(!OldSoundDataBlock2Start)
NewSoundDataBlock2Start:
    incbin "!JPROM":snestopc(!OldSoundDataBlock2Start)..snestopc(!OldSoundDataBlock2End)
    check bankcross full

; --------------------

; insert recompressed tilesets and tilemaps
print "Inserting recompressed BG GFX tilesets and tilemaps..."

    check bankcross off
    ; insert tilesets/tilemaps for 00 through 4C
    for n = $00..$!LabyrinthPathwaysIdStart
        NewGfxTilemapPtr!{dec2hexTwoDigits_!{n}}:
            incbin "recompressed tilemaps/RECOMPRESSED tilemap !{dec2hexTwoDigits_!{n}}.bin"
        NewGfxTilesetPtr!{dec2hexTwoDigits_!{n}}:
          ; incbin "!JPROM":snestopc(GfxTilesetPtrN(!n))..snestopc(GfxTilemapPtrN(!n))
            incbin "recompressed tilesets/RECOMPRESSED decompressed tileset !{dec2hexTwoDigits_!{n}}.bin"
    endfor

    ; you can reuse tileset 50 for IDs 4D-51 
    for n = $!LabyrinthPathwaysIdStart..$!LabyrinthPathwaysIdEnd+1
        NewGfxTilesetPtr!{dec2hexTwoDigits_!{n}}:
    endfor
        incbin "recompressed tilesets/RECOMPRESSED decompressed tileset 50.bin"
    ; insert tilemaps for IDs 4D-51
    for n = $!LabyrinthPathwaysIdStart..$!LabyrinthPathwaysIdEnd+1
        NewGfxTilemapPtr!{dec2hexTwoDigits_!{n}}:
            incbin "recompressed tilemaps/RECOMPRESSED tilemap !{dec2hexTwoDigits_!{n}}.bin"
    endfor

    ; insert tilesets/tilemaps for 52 through 65
    for n = $!LabyrinthPathwaysIdEnd+1..$!BookmarkGfxId
        NewGfxTilemapPtr!{dec2hexTwoDigits_!{n}}:
            incbin "recompressed tilemaps/RECOMPRESSED tilemap !{dec2hexTwoDigits_!{n}}.bin"
        NewGfxTilesetPtr!{dec2hexTwoDigits_!{n}}:
          ; incbin "!JPROM":snestopc(GfxTilesetPtrN(!n))..snestopc(GfxTilemapPtrN(!n))
            incbin "recompressed tilesets/RECOMPRESSED decompressed tileset !{dec2hexTwoDigits_!{n}}.bin"
    endfor

    ; gfx ID 0x66 for bookmark uses two tilemaps; only 1st one needs a pointer
    NewGfxTilemapPtr!BookmarkGfxId:
        incbin "recompressed tilemaps/RECOMPRESSED tilemap 66.bin"
        incbin "recompressed tilemaps/RECOMPRESSED $46C1B8 combined tilemap.bin"
    NewGfxTilesetPtr!BookmarkGfxId:
          ; incbin "!JPROM":snestopc(GfxTilesetPtrN(!n))..snestopc(GfxTilemapPtrN(!n))
            incbin "recompressed tilesets/RECOMPRESSED decompressed tileset 66.bin"

    ; insert tilesets/tilemaps for 67 through 7C
    for n = $!BookmarkGfxId+1..$!OpeningCreditsGfxId
        NewGfxTilemapPtr!{dec2hexTwoDigits_!{n}}:
            incbin "recompressed tilemaps/RECOMPRESSED tilemap !{dec2hexTwoDigits_!{n}}.bin"
        NewGfxTilesetPtr!{dec2hexTwoDigits_!{n}}:
          ; incbin "!JPROM":snestopc(GfxTilesetPtrN(!n))..snestopc(GfxTilemapPtrN(!n))
            incbin "recompressed tilesets/RECOMPRESSED decompressed tileset !{dec2hexTwoDigits_!{n}}.bin"
    endfor

    ; new data for the opening credits, ID 7D
    NewGfxTilemapPtr!OpeningCreditsGfxId:
        incbin "recompressed tilemaps/RECOMPRESSED credits map.bin"
    NewGfxTilesetPtr!OpeningCreditsGfxId:
        incbin "gfx/new opening credits/RECOMPRESSED credits tiles.bin"

    ; insert tilesets/tilemaps for 7E through 81, end of data
    for n = $!OpeningCreditsGfxId+1..!NumGfxIds
        NewGfxTilemapPtr!{dec2hexTwoDigits_!{n}}:
            incbin "recompressed tilemaps/RECOMPRESSED tilemap !{dec2hexTwoDigits_!{n}}.bin"
        NewGfxTilesetPtr!{dec2hexTwoDigits_!{n}}:
          ; incbin "!JPROM":snestopc(GfxTilesetPtrN(!n))..snestopc(GfxTilemapPtrN(!n))
            incbin "recompressed tilesets/RECOMPRESSED decompressed tileset !{dec2hexTwoDigits_!{n}}.bin"
    endfor
    check bankcross full

; !NewStartOfSilhDataInBank48 = $48d082 ; see ASM file for repointing silhouettes
print "End offset after gfx tilesets/maps: $",hex(pc())
assert pc() <= !NewStartOfSilhDataInBank48, "",hex(pc()),", move back ",hex(pc()-!NewStartOfSilhDataInBank48)," bytes"
    fillbyte $ff
    fill snestopc(!NewStartOfSilhDataInBank48)-snestopc(pc())

; --------------------

print "Moving pointer table for background graphics..."

; fill in graphics pointer table at new location at end of ROM
; org $5ffa1c
; recompressing VFX 0B/37/3B LZSS blocks freed up enough space for this table
org FreedSpaceInBank5F
NewLocationForGfxPtrTable:
    for n = $00..!NumGfxIds
    ; improvement: all palette ptrs' bank bytes are $5E, so hard-code into ASM
    ; and just store the bank offset (so use dw, not dl)
        dw NewGfxPalettePtr!{dec2hexTwoDigits_!{n}}
        dl NewGfxTilemapPtr!{dec2hexTwoDigits_!{n}}
        dl NewGfxTilesetPtr!{dec2hexTwoDigits_!{n}}
    endfor
assert pc() <= $5fec1c

; put silhouette OAM block 305 (0xDA bytes) here and update its pointer
; org $5ffa1c
; NewLocationForOamBlock305:
    ; %moveDataBlockAndUpdatePtrTable(!SilhOamPtrTable, 305, 305, $5dc690, NewLocationForOamBlock305, EmptyBlockAfterOamPtr305, "OAM")

struct GfxPtrTable NewLocationForGfxPtrTable
    .PalettePtr skip 2
    .TilemapPtr skip 3
    .TilesetPtr skip 3
endstruct

; tilemap ptr for ID 0x66 is for two blocks, and needs to have bit 15 cleared to
; indicate this; prefer using one loop & handling this separately
; org JapaneseGfxPtrTable[$!BookmarkGfxId].TilemapPtr
org GfxPtrTable[$!BookmarkGfxId].TilemapPtr
    dl (~$008000)&NewGfxTilemapPtr66
