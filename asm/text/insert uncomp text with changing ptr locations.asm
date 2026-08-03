; this address comes after placing this text at $01AC11 (see Atlas file):
; [left quote][left inner quote][right quote][right inner quote].,?!
; 0123456789[spc]
; [A_bold][B_bold][C_bold][D_bold]
; [CURSOR][CLEAR PG]
; &[Ch.]
; so a total of 8 + 10 + 1 + 4 + 2 + 2 = 27 characters = 0x36 bytes
org $018179
    dw PtrToTooruDefaultName
org $01817b
    dw PtrToMariDefaultName

org $01ac47
PlaythruCtrPoundSign:
    ; repointed in text printing hacks ASM file
    dw readfile2("script/bank 04 punctuation.bin", $0)
UnderscoreForKillerGuesses:
    ; repointed in new ASM for checking killer guesses
    dw readfile2("script/bank 04 punctuation.bin", $2)
    dw $ffff
MagicNumberForSaveFiles:
    ; repointed in new BRK #$1C code
    dw $06cd
PtrToTooruDefaultName:
    incbin "script/tooru default name.bin"
    dw $ffff
PtrToMariDefaultName:
    incbin "script/mari default name.bin"
    dw $ffff

; insert and repoint the text for the fake-out choice in the spy route
; in the process, overwrite Tooru and Mari's Japanese names, the original fake
; choice text, the JP asterisk, and the honorifics
NewFakeChoiceText:
!FakeOutChoiceBinaryFile = "script/fake out choice text.bin"
!FakeChoiceTextStartInFile = readfile2("!FakeOutChoiceBinaryFile", 0)
!FakeChoiceTextBlock3Start = readfile2("!FakeOutChoiceBinaryFile", 2)
    incbin "!FakeOutChoiceBinaryFile":!FakeChoiceTextStartInFile..0

; insert text data for the list of killer name options here
; the Japanese game's data for it ends at $01B0AC
NewAcceptedAnswersForKillerGuess:
    incbin "script/culprit names text data.bin"
assert pc() <= $01b0ac,"Killer guesses exceeded $01B0AC by 0x",hex(pc()-$01b0ac)

; assert pc() <= $01acff
    ; fillbyte $ff
    ; fill $01acff-pc()
