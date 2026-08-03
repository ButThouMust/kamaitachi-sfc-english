asar 1.90
check title "KAMAITACHI NO YORU    "
lorom

; Asar's table file functionality (single ASCII only, no UTF-8) sadly isn't as
; robust as Atlas's; it otherwise could help with some 1-byte text hacks
; table "tables/inserted font one byte.tbl",rtl

!JPROM = "rom/Kamaitachi no Yoru (Japan).sfc"

incsrc "asm/! defines for script start points.asm"

incsrc "asm/text/insert new name entry char data.asm"

incsrc "asm/text/insert uncomp text with changing ptr locations.asm"
incsrc "asm/text/fake choice text REWORK.asm"

incsrc "asm/! snes hw registers.asm"
incsrc "asm/bank 04/! bank 04 defines.asm"
incsrc "asm/text/insert new gfx for name entry buttons.asm"
incsrc "asm/MAIN rewrite bank 04.asm"

print hex(pc()),", saved 0x",hex($04a2f8-pc())," bytes of code in bank 04"
assert pc() >= $048000 && pc() <= $04a618
    fillbyte $ff
    fill $04a618-pc()

incsrc "asm/text/insert new huffman script.asm"
incsrc "asm/text/insert new english font.asm"

incsrc "asm/text/kamaitachi text printing hacks.asm"
incsrc "asm/text/bookmark text hacks.asm"
incsrc "asm/text/process char with 00A0DD jump table.asm"
incsrc "asm/text/improve linebreaking.asm"
incsrc "asm/text/one byte encoding for printing names in script.asm"
