includefrom "MAIN recompress and repoint data.asm"

;; -----------------------------------------------------------------------------

; Test the format by inserting the gold bookmark animation's sprites.
org $01F0C0
    incbin "recompressed silh gfx/recompressed gold bookmark sprites $01F0C0.bin"

; Optionally set gold bookmark to appear on the top file, given it is not empty.
; org $018167
  ; ; db $04,$08
  ; db $0C,$0C

;; -----------------------------------------------------------------------------

!NewStartOfSilhDataInBank48 = $48d082

!OriginalSilhConstructionDataPtrTable = $4b8000
!SilhConstructionData = $4b88e2
!SilhXYPtrTable = $4b9cfe
!SilhOamPtrTable = $4ba802

!SilhGfxPtrTable = $4bba5e
!SilhGfxDataSpace = $4bffda ; used to start at $4c8000, can free up 0x26 bytes
!NumSilhGfxPtrs = $2f6
!PtrSize = 3

org $0280c4
    jsr get_ptr_to_silh_construction_data_028107

; the pointer table for silhouette construction data uses 24-bit pointers but
; can easily use 16-bit pointers, since all the pointed data is in one bank
org $028107
    fillbyte $ff
    fill $9
get_ptr_to_silh_construction_data_028107:
    PHP                                       ;028107|08      |      ;
    REP #$30                                  ;028108|C230    |      ;
; use silhouette control code input to get a pointer from list at $4B8000
; change to only need to multiply by 2 instead of by 3
    LDA.B $02                                 ;02810A|A502    |000FC2;
    ASL A                                     ;02810C|0A      |      ;
  ; CLC                                       ;02810D|18      |      ;
  ; ADC.B $02                                 ;02810E|6502    |000FC2;
    TAX                                       ;028110|AA      |      ;
    LDA.L SilhConstructionDataPtrTable,X      ;028111|BF00804B|4B8000;
    STA.B $04                                 ;028115|8504    |000FC4;
; hard-code the bank number as an immediate
  ; LDA.L SilhConstructionDataPtrTable+2,X    ;028117|BF02804B|4B8002;
  ; AND.W #$00FF                              ;02811B|29FF00  |      ;
  ; TSB.B $06                                 ;02811E|0406    |000FC6;
  ; REP #$20                                  ;028120|C220    |      ;
    lda.w #bank(SilhConstructionDataPtrTable)
    sta.b $06
  ; 

assert pc() == $028122,hex(pc())
  ; LDA.B [$04]                               ;028122|A704    |000FC4;
  ; etc.

org !OriginalSilhConstructionDataPtrTable
EmptySpaceBeforeSilhConstructionData:
    fillbyte $ff
    fill !NumSilhGfxPtrs
SilhConstructionDataPtrTable:
    for i = 0..!NumSilhGfxPtrs
        dw readfile2("!JPROM",snestopc(!OriginalSilhConstructionDataPtrTable)+!i*3)
    endfor
assert pc() == !SilhConstructionData,hex(pc())

; ------------------------------------------------------------------------------

; optional: clear out the original compressed graphics data
org !SilhGfxDataSpace
    check bankcross off
    fillbyte $FF
    fill $8c40f
    check bankcross full

; insert all the recompressed graphics and keep track of the pointers
org !SilhGfxDataSpace
    check bankcross off
    for i = 0..!NumSilhGfxPtrs
        SilhGfxPtr!i:
            incbin "recompressed silh gfx/recompressed silh sprites block 0x!{dec2hex_!{i}}.bin"
    endfor
    check bankcross full

; get a pointer to after the graphics data block
NewOam30dThru391Space = pc()

; update pointers for the graphics
org !SilhGfxPtrTable
    for i = 0..!NumSilhGfxPtrs
        dl SilhGfxPtr!i
    endfor

;; -----------------------------------------------------------------------------

; !JPROM = "rom/Kamaitachi no Yoru (Japan).sfc"

macro moveDataBlockAndUpdatePtrTable(PtrTable, StartIndex, EndIndex, OldEndOffset, NewStartOffset, NewEndOffset, Type)
    org <NewStartOffset>
        ; move data blocks for all but the last pointer in the range
        for i = $<StartIndex>..$<EndIndex>
            ?NewPtr<Type>!{dec2hex_!{i}}:
                !start = read3(<PtrTable>+(!i)*!PtrSize)
                !end = read3(<PtrTable>+(!i+1)*!PtrSize)
                incbin "!JPROM":snestopc(!start)..snestopc(!end)
        endfor

        ; data for last ptr index is assumed to not end with the ptr after it
        ; (if available), so must provide the original end offset of the block
        ?NewPtr<Type><EndIndex>:
            !start = read3(<PtrTable>+$<EndIndex>*!PtrSize)
            incbin "!JPROM":snestopc(!start)..snestopc(<OldEndOffset>+1)

        ; make a label for the end of the block's new location
        <NewEndOffset> = pc()

        ; update the pointers
        org <PtrTable>+!PtrSize*$<StartIndex>
            for i = $<StartIndex>..$<EndIndex>
                dl ?NewPtr<Type>!{dec2hex_!{i}}
            endfor
            dl ?NewPtr<Type><EndIndex>
endmacro

; for good measure, fill in the original space with all FF bytes
org $5dc40f
    fillbyte $FF
    fill $5dffa8-pc()+1

; move back block of OAM data for silh sets 2ff-391 to create bigger contiguous
; block of empty bytes (0x1b97 saved + 0x57+0x26 existing empty bytes = 0x1c14)
%moveDataBlockAndUpdatePtrTable(!SilhOamPtrTable, 30d, 391, $5dffa8, NewOam30dThru391Space, NewCurtainTilesetPtr, "OAM")
  ; print "New ptr for curtain tileset: ",hex(NewCurtainTilesetPtr)

; move back 3 blocks of OAM-related data to combine four separate empty blocks:
; - $48D1A3-$48FFF0: silh X/Y data blocks 0dc-32d -\
; - $498000-$49FF89: silh OAM data blocks 000-12c --+-> $48d082, 0x12DD2 bytes
; - $4A8000-$4AFFF9: silh OAM data blocks 12d-26d -/
check bankcross off
    %moveDataBlockAndUpdatePtrTable(!SilhXYPtrTable, 0dc, 32d, $48fff0, !NewStartOfSilhDataInBank48, NewOamXY000to12cBlock, "XY")
    %moveDataBlockAndUpdatePtrTable(!SilhOamPtrTable, 000, 12c, $49ff89, NewOamXY000to12cBlock, NewOamXY12dto26dBlock, "OAM")
    %moveDataBlockAndUpdatePtrTable(!SilhOamPtrTable, 12d, 26d, $4afff9, NewOamXY12dto26dBlock, NewOam2ffto30cBlock, "OAM")

; then also move in this block to take advantage of the 0x1AC bytes of space:
; - $5DC40F-$5DC5B6: silh OAM data blocks 2ff-304 (0x1A8 bytes, 4 leftover FF)
; NEW: shrinking construction data ptr table also lets us put in 305's OAM data
  ; %moveDataBlockAndUpdatePtrTable(!SilhOamPtrTable, 2ff, 304, $5dc5b6, NewOam2ffto304Block, NewEmptyAfterOam2ffTo304Block, "OAM")
    %moveDataBlockAndUpdatePtrTable(!SilhOamPtrTable, 2ff, 30c, $5dc864, NewOam2ffto30cBlock, NewEmptyAfterOam2ffTo30cBlock, "OAM")
  ; print "Before OAM 2FF-30C: ",hex(NewOam2ffto30cBlock)
  ; print "After  OAM 2FF-30C: ",hex(NewEmptyAfterOam2ffTo30cBlock)
check bankcross full

org NewEmptyAfterOam2ffTo30cBlock
    fillbyte $FF
    fill $4affff-pc()+1

; move OAM data blocks 392-3ab from bank 04 to bank 02; blank out original space
%moveDataBlockAndUpdatePtrTable(!SilhOamPtrTable, 392, 3ab, $04eade, $02c31f, EmptySpaceBank02, "OAM")
org $04df87
    fillbyte $FF
    fill $04eade-pc()+1

; change color of silhouette 2DE from green to the normal color
org read3(!OriginalSilhConstructionDataPtrTable+3*$2de)|$8000
    assert pc() == $4b9c4a,hex(pc(),6)
    skip 6
  ; dw $7c1f
    dw $04e7

; ------------------------------------------------------------------------------

; if you need to debug stuff, put it here
print "Ptr for silh gfx data block 0x14B: ",hex(SilhGfxPtr331)
