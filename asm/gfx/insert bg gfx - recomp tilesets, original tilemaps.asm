includefrom "asm/gfx/insert new char grid, repoint sfx and bg gfx.asm"

check bankcross off
; insert tilesets/tilemaps for 00 through 4C
for n = $00..$!LabyrinthPathwaysIdStart
    NewGfxTilemapPtr!{dec2hexTwoDigits_!{n}}:
        incbin "!JPROM":snestopc(GfxTilemapPtrN(!n))..snestopc(GfxPalettePtrN(!n+1))
      ; incbin "recompressed tilemaps/RECOMPRESSED tilemap !{dec2hexTwoDigits_!{n}}.bin"
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
        incbin "!JPROM":snestopc(GfxTilemapPtrN(!n))..snestopc(GfxPalettePtrN(!n+1))
endfor

; insert tilesets/tilemaps for 52 through 7C
; gfx ID 0x66 for bookmark uses two tilemaps; only 1st one needs a pointer
; if copying from the JP game, both are covered by the same pointer
for n = $!LabyrinthPathwaysIdEnd+1..$!OpeningCreditsGfxId
    NewGfxTilemapPtr!{dec2hexTwoDigits_!{n}}:
        incbin "!JPROM":snestopc(GfxTilemapPtrN(!n))..snestopc(GfxPalettePtrN(!n+1))
    NewGfxTilesetPtr!{dec2hexTwoDigits_!{n}}:
      ; incbin "!JPROM":snestopc(GfxTilesetPtrN(!n))..snestopc(GfxTilemapPtrN(!n))
        incbin "recompressed tilesets/RECOMPRESSED decompressed tileset !{dec2hexTwoDigits_!{n}}.bin"
endfor

; new data for the opening credits, ID 7D
; NOTICE: you must recompress the tilemap in the original format
NewGfxTilemapPtr!OpeningCreditsGfxId:
    incbin "recompressed tilemaps orig format/RECOMPRESSED credits map.bin"
NewGfxTilesetPtr!OpeningCreditsGfxId:
  ; incbin "gfx/new opening credits/RECOMPRESSED credits tiles.bin"
    incbin "recompressed tilesets/RECOMPRESSED credits tiles.bin"

; insert tilesets/tilemaps for 7E through 80, end of data
for n = $!OpeningCreditsGfxId+1..!NumGfxIds-1
    NewGfxTilemapPtr!{dec2hexTwoDigits_!{n}}:
        incbin "!JPROM":snestopc(GfxTilemapPtrN(!n))..snestopc(GfxPalettePtrN(!n+1))
    NewGfxTilesetPtr!{dec2hexTwoDigits_!{n}}:
      ; incbin "!JPROM":snestopc(GfxTilesetPtrN(!n))..snestopc(GfxTilemapPtrN(!n))
        incbin "recompressed tilesets/RECOMPRESSED decompressed tileset !{dec2hexTwoDigits_!{n}}.bin"
endfor

; insert tilemap and tileset for gfx ID 0x81
; there is not a palette pointer to mark the end of the tilemap data here,
; so have to hard-code in the end pointer
NewGfxTilemapPtr81:
    incbin "!JPROM":snestopc(GfxTilemapPtrN($81))..snestopc($48d081+1)
NewGfxTilesetPtr81:
    incbin "recompressed tilesets/RECOMPRESSED decompressed tileset 81.bin"
check bankcross full
