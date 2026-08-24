includefrom "asm/gfx/insert new char grid, repoint sfx and bg gfx.asm"

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
  ; incbin "gfx/new opening credits/RECOMPRESSED credits tiles.bin"
    incbin "recompressed tilesets/RECOMPRESSED credits tiles.bin"

; insert tilesets/tilemaps for 7E through 81, end of data
for n = $!OpeningCreditsGfxId+1..!NumGfxIds
    NewGfxTilemapPtr!{dec2hexTwoDigits_!{n}}:
        incbin "recompressed tilemaps/RECOMPRESSED tilemap !{dec2hexTwoDigits_!{n}}.bin"
    NewGfxTilesetPtr!{dec2hexTwoDigits_!{n}}:
      ; incbin "!JPROM":snestopc(GfxTilesetPtrN(!n))..snestopc(GfxTilemapPtrN(!n))
        incbin "recompressed tilesets/RECOMPRESSED decompressed tileset !{dec2hexTwoDigits_!{n}}.bin"
endfor

check bankcross full
