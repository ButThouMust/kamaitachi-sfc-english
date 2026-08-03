asar 1.90
check title "KAMAITACHI NO YORU    "
lorom

; --------------------

!JPROM = "rom/Kamaitachi no Yoru (Japan).sfc"

; Asar 1.9 does not have the syntax `!hex_label := hex(!number)`
; got workaround from https://github.com/RPGHacker/asar/issues/347
; - for silh ctrl code IDs, use the text: !{dec2hex_!{i}}
; - for gfx IDs, use the text: !{dec2hex_!{i}}
incsrc "asm/gfx/! gfx id hex defines.asm"
incsrc "asm/gfx/! silh ctrl code id hex defines.asm"

; --------------------

print "Inserting recompressed silhouette graphics..."
incsrc "asm/gfx/silh gfx decompression REWORK.asm"
incsrc "asm/gfx/insert repoint silhouette data.asm"

print "Inserting recompressed LZSS blocks..."
incsrc "asm/gfx/lzss asm REWORK.asm"
incsrc "asm/gfx/insert recompressed LZSS.asm"

print "Inserting new file management prompts..."
incsrc "asm/gfx/insert file management prompts.asm"

incsrc "asm/gfx/insert new char grid, repoint sfx and bg gfx.asm"

; update the code for tileset/tilemap decompression, and reading the palettes
incsrc "asm/gfx/update code for reading tileset tilemap ptrs.asm"
; incsrc "asm/gfx/tileset decompression REWORK.asm"
incsrc "asm/gfx/tileset decompression ORIGINAL.asm"
incsrc "asm/gfx/tilemap decompression REWORK.asm"
incsrc "asm/gfx/gfx id palette REWORK.asm"

incsrc "asm/gfx/insert other graphics.asm"

incsrc "asm/gfx/insert new end credits.asm"
incsrc "asm/gfx/end credits asm REWORK.asm"
