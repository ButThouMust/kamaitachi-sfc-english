includefrom "asm/MAIN insert text.asm"

; Asar was being fussy about these definitions coming BEFORE any places in the
; ASM where they get used, so putting in dedicated ASM file, yay

!DemoStartPointsFile = "script/start points' script offsets.bin"
!SpecialPointersFile = "script/special pointers' script offsets.bin"

!NumSpecialPtrs = 7
!StructSize = 6
!SkipAmount = 4

function numBytes(startVal) = startVal>>3
function numBits(startVal) = startVal&$7
function calcHuffPtr(startVal) = numBits(startVal)|(pctosnes(snestopc(ScriptStartROM)+numBytes(startVal))<<3)

function getSpecialPtrLocation(ptrNum) = readfile3("!SpecialPointersFile",!StructSize*ptrNum+0)
function getSpecialPtrValue(ptrNum) = calcHuffPtr(readfile3("!SpecialPointersFile",!StructSize*ptrNum+3))
