includefrom "MAIN insert text.asm"

; ------------------------------------------------------------------------------

!ScriptStartRAMOriginal = $05FCE1

; fill original JP script with all FF bytes
; pushpc
org !ScriptStartRAMOriginal
    check bankcross off
    fillbyte $FF
    fill $7FF8D-snestopc(!ScriptStartRAMOriginal)+1
    check bankcross full
; pullpc

; print hex(pc()),", saved 0x",hex($04a2f8-pc())," bytes of code in bank 04"
; assert pc() >= $048000 && pc() <= $04a618
    ; fillbyte $ff
    ; fill $04a618-pc()

; insert JP script at new position, make sure it doesn't clobber start of sound
; data (see "insert new char grid, repoint sfx and bg gfx.asm")
org $04A618
ScriptStartROM:
    check bankcross off
    incbin "script/huffman script.bin"
    check bankcross full
print "Huffman script end offset: ",hex(snestopc(pc()))
assert pc() < $10cd24, "Huffman script is too large: Ends at $",hex(pc())," > $",hex($10cd24)

; ------------------------------------------------------------------------------

; insert updated start points for the game's demo mode
org $018359
    for i = 0..5
        Start!i = readfile3("!DemoStartPointsFile",3*!i)
        dl calcHuffPtr(Start!i)
    endfor

; ------------------------------------------------------------------------------

; update the 7 special pointers to specific bits of control flow in the script
; however, move updating the last one to the code for updating bank 04
for i = 0..!NumSpecialPtrs-1
    !{SpecLoc!i} = getSpecialPtrLocation(!i)
    !{SpecPtr!i} = getSpecialPtrValue(!i)
    org !{SpecLoc!i}
        ; write the low and middle bytes of the pointer
        dw !{SpecPtr!i}

        ; next write the high byte of the pointer
        skip !SkipAmount
        db !{SpecPtr!i}>>16
endfor

; found out later that have to duplicate "start of the script" pointer to
; another set of locations ($009C2E, $009C38); note that skip amount doesn't
; match the rest of the special pointers (8 vs 4)
; TODO I'm too lazy right now to do this "properly" without hard-coding, but
; seriously, fix this later
org $009C2F
	dw getSpecialPtrValue(1)
org $009C38
	db getSpecialPtrValue(1)>>16

; ------------------------------------------------------------------------------

; insert updated Huffman tree data and update the Huffman routine

!NewHuffTreeContents = "script/huffman tree - game data format.bin"

!SizeOfTreeBlock #= filesize("!NewHuffTreeContents")>>1
!HuffLeftTrees = HuffRightTrees+!SizeOfTreeBlock

; update root position for the trees = where to start feeding in bits
org $009b0f
    dw !SizeOfTreeBlock-2

; update pointers
org $009b28
    dw !HuffLeftTrees
org $009b30
    dw HuffRightTrees

; clear data from Huffman trees up through end of the font pointer table
org $018b6e
HuffRightTrees:
    fillbyte $FF
    fill $01a8a8-pc()
org HuffRightTrees
    incbin "!NewHuffTreeContents"

; insert the spy route's fake choice text and the font after new Huffman trees
