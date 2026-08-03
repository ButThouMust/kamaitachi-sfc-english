asar 1.91
check title "KAMAITACHI NO YORU   "
lorom

; ------------------------------------------------------------------------------

LzssCodeSpace7E24F4 = $7E24F4
LzssCodeSpace7E2574 = $7E2574

; ------------------------------------------------------------------------------

org $01d965
    jsl call_LZ_decomp_with_src_ptr_1C48_dest_ptr_1C4C_03A942
org $03a8d4
    jsl call_LZ_decomp_with_src_ptr_1C48_dest_ptr_1C4C_03A942

org $039507
    jsl call_LZ_decomp_with_data_ptrs_in_A_X_Y_03A992
org $0396a9
    jsl call_LZ_decomp_with_data_ptrs_in_A_X_Y_03A992
org $0396f4
    jsl call_LZ_decomp_with_data_ptrs_in_A_X_Y_03A992
org $03d33c
    jsl call_LZ_decomp_with_data_ptrs_in_A_X_Y_03A992
org $03d92f
    jsl call_LZ_decomp_with_data_ptrs_in_A_X_Y_03A992

; ------------------------------------------------------------------------------

org $03a942
call_LZ_decomp_with_src_ptr_1C48_dest_ptr_1C4C_03A942:
    PHB                                                ;03A942|8B      |      ;
    PEA.W $7E7E                                        ;03A943|F47E7E  |7E7E7E;
    PLB                                                ;03A946|AB      |      ;
    PLB                                                ;03A947|AB      |      ;

  ; LDX.W #LzssDecompress                              ;03A948|A2D8A9  |      ; copy 0x63 bytes of code from $03A9D8 into $7E24F4
    LDY.W #LzssCodeSpace7E24F4                         ;03A94B|A0F424  |      ;
  ; LDA.W #(LzssEndOfCode-LzssDecompress-1)            ;03A94E|A96200  |      ;
  ; MVN bank(LzssCodeSpace7E24F4),bank(LzssDecompress) ;03A951|547E03  |      ;
    jsr CopyLzssCodeToBank7EOffsetInY

; once the MVN is completed, the data bank is the destination of the MVN i.e.
; bank 7E; using just bank offsets (not the whole CPU address) will suffice
; - furthermore, you can take advantage of [STA $addr,X] to reuse the two groups
;   of five STAs; just use a different X offset for start of code in WRAM

    SEP #$20                                           ;03A954|E220    |      ;
    LDA.W $1C4A                                        ;03A956|AD4A1C  |7E1C4A; set the bank to READ from in ASM
  ; STA.L $7E24FF                                      ;03A959|8FFF247E|7E24FF;
  ; STA.L $7E2513                                      ;03A95D|8F13257E|7E2513;
  ; STA.L $7E252B                                      ;03A961|8F2B257E|7E252B;
  ; STA.L $7E253A                                      ;03A965|8F3A257E|7E253A;
  ; STA.L $7E2552                                      ;03A969|8F52257E|7E2552;
  ; sta.w LzssCodeSpace7E24F4+SrcBank1-LzssDecompress
  ; sta.w LzssCodeSpace7E24F4+SrcBank2-LzssDecompress
  ; sta.w LzssCodeSpace7E24F4+SrcBank3-LzssDecompress
  ; sta.w LzssCodeSpace7E24F4+SrcBank4-LzssDecompress
  ; sta.w LzssCodeSpace7E24F4+SrcBank5-LzssDecompress
    ldx.w #LzssCodeSpace7E24F4
    jsr UseXOffsetToSetSrcBanksInWRAM

    LDA.W $1C4E                                        ;03A96D|AD4E1C  |7E1C4E; set the bank to WRITE to in ASM
  ; STA.L $7E2551                                      ;03A970|8F51257E|7E2551;
  ; STA.L $7E2516                                      ;03A974|8F16257E|7E2516;
  ; STA.L $7E2517                                      ;03A978|8F17257E|7E2517;
  ; STA.L $7E2531                                      ;03A97C|8F31257E|7E2531;
  ; STA.L $7E2532                                      ;03A980|8F32257E|7E2532;
  ; sta.w LzssCodeSpace7E24F4+DestBank5-LzssDecompress
  ; sta.w LzssCodeSpace7E24F4+DestBank1-LzssDecompress
  ; sta.w LzssCodeSpace7E24F4+DestBank2-LzssDecompress
  ; sta.w LzssCodeSpace7E24F4+DestBank3-LzssDecompress
  ; sta.w LzssCodeSpace7E24F4+DestBank4-LzssDecompress
    jsr UseXOffsetToSetDestBanksInWRAM

    LDX.W $1C48                                        ;03A984|AE481C  |7E1C48; X <- starting bank offset for data to be READ
    LDY.W $1C4C                                        ;03A987|AC4C1C  |7E1C4C; Y <- starting bank offset for where to WRITE data
    JSL.L LzssCodeSpace7E24F4                          ;03A98A|22F4247E|7E24F4; run the code in bank 7E

  ; REP #$20                                           ;03A98E|C220    |      ;
  ; PLB                                                ;03A990|AB      |      ;
  ; RTL                                                ;03A991|6B      |      ;
    bra +

call_LZ_decomp_with_data_ptrs_in_A_X_Y_03A992:
    PHB                                                ;03A992|8B      |      ;
    PHX                                                ;03A993|DA      |      ;
    PHY                                                ;03A994|5A      |      ;
    PHA                                                ;03A995|48      |      ;

  ; LDX.W #LzssDecompress                              ;03A996|A2D8A9  |      ; copy 0x63 bytes of code from $03A9D8 into $7E2574
    LDY.W #LzssCodeSpace7E2574                         ;03A999|A07425  |      ;
  ; LDA.W #(LzssEndOfCode-LzssDecompress-1)            ;03A99C|A96200  |      ;
  ; MVN bank(LzssCodeSpace7E2574),bank(LzssDecompress) ;03A99F|547E03  |      ;
    jsr CopyLzssCodeToBank7EOffsetInY

    PLA                                                ;03A9A2|68      |      ;
    SEP #$20                                           ;03A9A3|E220    |      ;
  ; STA.L $7E257F                                      ;03A9A5|8F7F257E|7E257F; low byte of input value in A = bank to READ from in ASM
  ; STA.L $7E2593                                      ;03A9A9|8F93257E|7E2593;
  ; STA.L $7E25AB                                      ;03A9AD|8FAB257E|7E25AB;
  ; STA.L $7E25BA                                      ;03A9B1|8FBA257E|7E25BA;
  ; STA.L $7E25D2                                      ;03A9B5|8FD2257E|7E25D2;
  ; sta.w LzssCodeSpace7E2574+SrcBank1-LzssDecompress
  ; sta.w LzssCodeSpace7E2574+SrcBank2-LzssDecompress
  ; sta.w LzssCodeSpace7E2574+SrcBank3-LzssDecompress
  ; sta.w LzssCodeSpace7E2574+SrcBank4-LzssDecompress
  ; sta.w LzssCodeSpace7E2574+SrcBank5-LzssDecompress
    ldx.w #LzssCodeSpace7E2574
    jsr UseXOffsetToSetSrcBanksInWRAM

    XBA                                                ;03A9B9|EB      |      ; high byte of input value in A = bank to WRITE to in ASM
  ; STA.L $7E25D1                                      ;03A9BA|8FD1257E|7E25D1;
  ; STA.L $7E2596                                      ;03A9BE|8F96257E|7E2596;
  ; STA.L $7E2597                                      ;03A9C2|8F97257E|7E2597;
  ; STA.L $7E25B1                                      ;03A9C6|8FB1257E|7E25B1;
  ; STA.L $7E25B2                                      ;03A9CA|8FB2257E|7E25B2;
  ; sta.w LzssCodeSpace7E2574+DestBank5-LzssDecompress
  ; sta.w LzssCodeSpace7E2574+DestBank1-LzssDecompress
  ; sta.w LzssCodeSpace7E2574+DestBank2-LzssDecompress
  ; sta.w LzssCodeSpace7E2574+DestBank3-LzssDecompress
  ; sta.w LzssCodeSpace7E2574+DestBank4-LzssDecompress
    jsr UseXOffsetToSetDestBanksInWRAM

    PLY                                                ;03A9CE|7A      |      ; input value in Y = bank offset to WRITE to
    PLX                                                ;03A9CF|FA      |      ; input value in X = bank offset to READ from
    JSL.L LzssCodeSpace7E2574                          ;03A9D0|2274257E|7E2574;

+   REP #$20                                           ;03A9D4|C220    |      ;
    PLB                                                ;03A9D6|AB      |      ;
    RTL                                                ;03A9D7|6B      |      ;

CopyLzssCodeToBank7EOffsetInY:
    ldx.w #LzssDecompress                              ;03A996|A2D8A9  |      ; copy 0x63 bytes of code from $03A9D8 into $7E2574
    lda.w #(LzssEndOfCode-LzssDecompress-1)            ;03A99C|A96200  |      ;
    mvn bank(LzssCodeSpace7E2574),bank(LzssDecompress) ;03A99F|547E03  |      ;
    rts

UseXOffsetToSetSrcBanksInWRAM:
    sta.w SrcBank1-LzssDecompress,x
    sta.w SrcBank2-LzssDecompress,x
    sta.w SrcBank3-LzssDecompress,x
    sta.w SrcBank4-LzssDecompress,x
    sta.w SrcBank5-LzssDecompress,x
    rts

UseXOffsetToSetDestBanksInWRAM:
    sta.w DestBank5-LzssDecompress,x
    sta.w DestBank1-LzssDecompress,x
    sta.w DestBank2-LzssDecompress,x
    sta.w DestBank3-LzssDecompress,x
    sta.w DestBank4-LzssDecompress,x
    rts

; ------------------------------------------------------------------------------

!SrcPtrPlaceholder = $000000

LzssDecompress:
    BRA read_byte_N1_03AA1B                            ;03A9D8|8041    |03AA1B;
case_end_of_data_03A9DA:
    SEP #$20                                           ;03A9DA|E220    |      ;
    RTL                                                ;03A9DC|6B      |      ;

case_N1_is_zero_03A9DD:
    INX                                                ;03A9DD|E8      |      ; if first got a 00 byte, read a two byte value N2
    REP #$20                                           ;03A9DE|C220    |      ;
    LDA.L !SrcPtrPlaceholder,X                         ;03A9E0|BF000000|000000;
; SrcBank1 = pc()-LzssDecompress-1
; above line is not allowed because LzssDecompress is a non-static label, and
; Asar doesn't allow you to use non-static labels to calculate new labels, yay
SrcBank1 = pc()-1
    BEQ case_end_of_data_03A9DA                        ;03A9E4|F0F4    |03A9DA; if got [00 00 00], end of data
    BMI case_N1_zero_N2_neg_03AA03                     ;03A9E6|301B    |03AA03;

case_N1_zero_N2_pos_03A9E8:
    INX                                                ;03A9E8|E8      |      ; advance src ptr two bytes past the value for N2
    INX                                                ;03A9E9|E8      |      ;
    PHX                                                ;03A9EA|DA      |      ; push src ptr and dest ptr
    PHY                                                ;03A9EB|5A      |      ;
    EOR.W #$FFFF                                       ;03A9EC|49FFFF  |      ; src_addr <- dest_addr + ~N2 + 1 = dest_addr - N2
    SEC                                                ;03A9EF|38      |      ; "reverse subtraction", -B + A = ~B + 1 + A
    ADC.B $01,S                                        ;03A9F0|6301    |000001;
    STA.B $01,S                                        ;03A9F2|8301    |000001;
    LDA.L !SrcPtrPlaceholder,X                         ;03A9F4|BF000000|000000; get TWO bytes for size of data to copy, minus 1 (due to MVN quirk)
SrcBank2 = pc()-1
    PLX                                                ;03A9F8|FA      |      ;
    MVN $7E,$7E                                        ;03A9F9|547E7E  |      ; copy data from decompression buffer to dest ptr
DestBank1 = pc()-2
DestBank2 = pc()-1
    PLX                                                ;03A9FC|FA      |      ;
    INX                                                ;03A9FD|E8      |      ; advance past data block size
    INX                                                ;03A9FE|E8      |      ;
  ; SEP #$20                                           ;03A9FF|E220    |      ;
    BRA read_byte_N1_03AA1B                            ;03AA01|8018    |03AA1B;

case_N1_zero_N2_neg_03AA03:
    INX                                                ;03AA03|E8      |      ; advance src pointer two bytes past value for N2
Continue_N1_neg:
    INX                                                ;03AA04|E8      |      ;
    PHX                                                ;03AA05|DA      |      ;
    PHY                                                ;03AA06|5A      |      ;
; read_N_bytes_back_from_dest_ptr_03AA07:
    CLC                                                ;03AA07|18      |      ; use a src addr of (dest - N1) or (dest - N2) accordingly, from the decomp buffer
    ADC.B $01,S                                        ;03AA08|6301    |000001;
    STA.B $01,S                                        ;03AA0A|8301    |000001;
    LDA.L !SrcPtrPlaceholder,X                         ;03AA0C|BF000000|000000; read one byte for size of data block to copy
SrcBank3 = pc()-1
    AND.W #$00FF                                       ;03AA10|29FF00  |      ;
    PLX                                                ;03AA13|FA      |      ;
    MVN $7E,$7E                                        ;03AA14|547E7E  |      ;
DestBank3 = pc()-2
DestBank4 = pc()-1
    PLX                                                ;03AA17|FA      |      ;
    INX                                                ;03AA18|E8      |      ;
; move this down to save space
  ; SEP #$20                                           ;03AA19|E220    |      ;

read_byte_N1_03AA1B:
    sep #$20
    LDA.L !SrcPtrPlaceholder,X                         ;03AA1B|BF000000|000000; read a byte from ROM
SrcBank4 = pc()-1
    BEQ case_N1_is_zero_03A9DD                         ;03AA1F|F0BC    |03A9DD;
  ; BPL case_read_N1_bytes_03AA2D                      ;03AA21|100A    |03AA2D;
!MaxLits = $1F
    cmp #!MaxLits+1
    bcc case_read_N1_bytes_03AA2D

case_N1_is_negative_03AA23:
; rearrange to save space for the [INX : PHX : PHY]
  ; INX                                                ;03AA23|E8      |      ; advance past byte for value N1
  ; PHX                                                ;03AA24|DA      |      ; save src ptr X for PLX at $03AA17
  ; PHY                                                ;03AA25|5A      |      ; save dest ptr Y for PLX at $03AA13 (use dest to get src)
    REP #$20                                           ;03AA26|C220    |      ;
    ORA.W #$FF00                                       ;03AA28|0900FF  |      ; sign extend N1 to the 16-bit value FF[N1]
  ; BRA read_N_bytes_back_from_dest_ptr_03AA07         ;03AA2B|80DA    |03AA07; reuse code for 16-bit negative case
    bra Continue_N1_neg

case_read_N1_bytes_03AA2D:
    INX                                                ;03AA2D|E8      |      ; advance past byte for value N1
    REP #$20                                           ;03AA2E|C220    |      ;
    AND.W #$00FF                                       ;03AA30|29FF00  |      ; use 8-bit value in 16-bit mode
    DEC A                                              ;03AA33|3A      |      ; (decrement accounts for MVN quirk of transferring A+1 bytes)
    MVN $7E,bank(!SrcPtrPlaceholder)                   ;03AA34|547E00  |      ; copy N1 bytes from source (ROM) into destination
DestBank5 = pc()-2
SrcBank5 = pc()-1
  ; SEP #$20                                           ;03AA37|E220    |      ;
    BRA read_byte_N1_03AA1B                            ;03AA39|80E0    |03AA1B;

LzssEndOfCode = pc()

; ensure that the size of the decompression code is smaller than 0x80 bytes
assert LzssEndOfCode-LzssDecompress <= LzssCodeSpace7E2574-LzssCodeSpace7E24F4

assert LzssEndOfCode <= $03aa3b
    fillbyte $ff
    fill $03aa3b-LzssEndOfCode
