includefrom "MAIN recompress and repoint data.asm"

;; -----------------------------------------------------------------------------
;; -----------------------------------------------------------------------------

; original and modified formats for the silhouette graphics compression:
; 00:    end of data                    | 00:    SAME
; 01-3F: run of 00 bytes (size 01-3F)   | 01-0E: literal data    (size 01-0E)
; 40:    LoROM bank advance             | N/A, bank wrap as you go along
; 41-7F: run of FF bytes (size 01-3F)   | 0F-17: run of NN bytes (size 02-0A)
; 80-BF: literal data    (size 01-40)   | 18-4F: run of FF bytes (size 01-38)
; C0-FF: run of NN bytes (size 01-40)   | 50-FF: run of 00 bytes (size 01-B0)

; !JPROM = "Kamaitachi no Yoru (Japan).sfc"

; need to update pointers to subroutines for each case
; CodePtrTable = $02867C
GfxBuffer = $7F6000
!BufferSize = $2000
!Case00Run = $50
!CaseFFRun = $18
!CaseNNRun = $0F

; start editing code in the main loop at $02864A

org $02864A
MainLoopGetNextBlock:
    lda.b [$03]
    beq DoneDecompressing

    ; determine encoding type for block; going to the right place was originally
    ; accomplished with a jump table because Chunsoft's format let them just
    ; mask out the "how is this block encoded?" bits

    ; this new code is small enough that we can just use direct branches to and
    ; from the decompression code blocks
    sta.b $00
    cmp.b #!Case00Run
    bcs Do00Run

    cmp.b #!CaseFFRun
    bcs DoFFRun

    cmp.b #!CaseNNRun
    bcs DoNNRun
    bra DoLiteralData

DoneWithOneBlock:
    jsr.w AdvPtrAndBankWrap ; advance ptr to next type byte
    ldx.b $01               ; stop decompression if 0x2000+ bytes written
    cpx.w #!BufferSize
    bcc MainLoopGetNextBlock

DoneDecompressing:
    ldx.w $849a             ; read ptr to $7F6000 = decompressed data
    stx.b $03               ; original ASM did it with three LDAs/STAs, one byte
    lda.w $849c             ; at a time; can save five bytes here
    sta.b $05

; I overwrote the buffer's data size in X to trim down the ASM code but am not
; certain if it is necessary to preserve it in X when exiting? the one outright
; JSR to this decompression code soon overwrites the value of X, so probably not
; necessary to restore, but leaving in as a comment
  ; ldx $01

    plp
    pld
    rts

; ----------

; copy the code for runs of 00
Do00Run:
    phd
    cop #$01                ; shift direct page back by 1, and write 0x00 to it
    db $00,$00

    ; we have to extract out the run's size with a subtraction instead of just
    ; ANDing out the bits for the case like in Chunsoft's code
    ; we want ($01 - L), where L = #$50 (00 run), #$18 (FF run), #$0F (NN run),
    ; and a reverse subtraction allows us to reuse code
    lda #!Case00Run
RevSubtractSizeBase:
    eor.b #$ff              ; A <- ~RangeStart + 1 + TypeByte = TypeByte - Start
    sec
    adc.b $01

    inc a                   ; size of run = encoded value + 1
    sta.b $01

    ldx.b $02
    lda.b $00               ; get the value to repeat
LoopRepeatValue:
    sta.l GfxBuffer,x       ; write value to buffer

    inx                     ; terminate if 0x2000 bytes written
    cpx.w #!BufferSize
    beq +

    dec.b $01
    bne LoopRepeatValue

  + stx.b $02
    pld
    bra DoneWithOneBlock
  ; rts

; ----------

; run of FF eliminates checking for bank advance from original code
DoFFRun:
    phd
    cop #$01                ; shift direct page back by 1, and write 0xFF to it
    db $FF, $00

    lda.b #!CaseFFRun
    bra RevSubtractSizeBase
    ; had we not done the reverse subtraction, we'd have had to repeat the code:
    ; [lda $01 ; sec ; sbc #$20] before branching to a [sta $01]

; ----------

DoNNRun:
; the new code for doing runs of 00 and FF is just about identical to what we
; need for runs of NN; set up the run in the same format, but notice that we
; must advance the ROM pointer BEFORE changing the direct page offset
    jsr AdvPtrAndBankWrap

    phd
    cop #$00                ; shift direct page back by 1 byte
    db $00

    lda.b [$04]             ; and fill in the free byte with value from ROM
    sta.b $00

    lda.b #!CaseNNRun-1     ; runs of NN are assumed to be 2+ bytes long
    bra RevSubtractSizeBase

; ----------

; literal data case is mostly the same; I rearranged the format so that the type
; byte now IS the size of the group; see $0286D9 in original Japanese game
DoLiteralData:
    ldx.b $01               ; get offset

; the PHX/PLX surrounding the call for bank wrapping were to preserve the buffer
; offset should the literal bytes cross a bank boundary; however, can just use Y
; reg instead of X, since Y otherwise not used in code here
LoopLiteralData:
  ; phx
    jsr.w AdvPtrAndBankWrap ; read next byte from the ROM, write to buffer
  ; plx
    lda.b [$03]
    sta.l GfxBuffer,x

    inx                     ; terminate if 0x2000 bytes written
    cpx.w #!BufferSize
    beq ExitLiteralLoop

    dec.b $00               ; check if more literals to read
    bne LoopLiteralData     ; change BPL to BNE to use four bits as-is for size

ExitLiteralLoop:
    stx.b $01               ; update offset to write to
    bra DoneWithOneBlock

;; ----------

AdvPtrAndBankWrap:
    php
    rep #$30

; instead of keeping original pointer and incrementing Y all the time, increment
; the pointer itself and use `lda [ptr]` intead of `lda [ptr],y`
    inc.b $03
    bmi PtrGoesToROM        ; if result in range 0000-7FFF, we need to bank wrap

    inc.b $05                 ; see $02869D; set ROM ptr to start of next bank
    ldy #$8000              ; (increment bank num, set bank offset to 0x8000)
    sty.b $03
  ; ldy #$0000

PtrGoesToROM:
    plp                     ; change A back to 8-bit
    rts

;; ----------

; above implementation saved quite a bit of space; one thing we can do with the
; space now is to add bank wrapping for the "advance OAM data pointer" code

AdvanceOamPtr:
    pha
    lda.b $0a               ; ptr_offset += 2
    inc #2
    sta.b $0a

    clc                     ; calculate base_ptr + ptr_offset
    adc.b $1c
    bmi OamPtrAdvanced      ; see if rolled over from FFFE->0000 or FFFF->0001

    lsr a                   ; set base ptr offset to 8000 or 8001 as appropriate
    lda.w #$8000>>1
    rol a
    sta.b $1c

    inc.b $1e               ; increment bank number of pointer
    stz.b $0a               ; reset offset from base pointer

OamPtrAdvanced:
    pla
    rts

; ensure that code block after original NN run case was not clobbered, and fill
; in remaining bytes with FF to make it more obvious the bytes are freed up
assert pc() < $028719
fillbyte $FF
fill $028719-pc()

; overwrite these 4 bytes of code
org $0287dc
    ; inc $0a
    ; inc $0a
    jsr AdvanceOamPtr
    nop
