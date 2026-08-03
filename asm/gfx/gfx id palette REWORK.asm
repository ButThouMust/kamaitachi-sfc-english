includefrom "asm/insert new char grid, repoint sfx and bg gfx.asm"

pushpc
org $00b3ba
    jsl read_palette_data_for_gfx_ID_029EFC
org $01d751
    jsl read_palette_data_for_gfx_ID_029EFC
pullpc

; -----

; OLD: update pointer for low/high bytes of palette pointer
; org $029f09
    ; dl NewLocationForGfxPtrTable+0
    ; dl GfxPtrTable.PalettePtr

; OLD: update pointer for bank byte of palette pointer
; org $029f14
    ; dl NewLocationForGfxPtrTable+2
    ; dl GfxPtrTable.PalettePtr+2

; -----

; org $029efc
read_palette_data_for_gfx_ID_029EFC:
    PHP                                       ;029EFC|08      |      ;
    REP #$30                                  ;029EFD|C230    |      ;
    LDA.B $00                                 ;029EFF|A500    |001F00; calculate value in $00, multiplied by 9
    ASL A                                     ;029F01|0A      |      ;
    ASL A                                     ;029F02|0A      |      ;
    ASL A                                     ;029F03|0A      |      ;
; pointer table entries are now 8 bytes instead of 9
  ; CLC                                       ;029F04|18      |      ;
  ; ADC.B $00                                 ;029F05|6500    |001F00;
    TAX                                       ;029F07|AA      |      ;

; ASM hack allows hard-coding the bank number for palette data
  ; LDA.L LIST_palette_data_bank_offsets,X    ;029F08|BF008025|258000; read a 24-bit pointer indexed from $258000
    lda.l GfxPtrTable.PalettePtr,x
    STA.B $04                                 ;029F0C|8504    |001F04;
  ; LDA.W #$0000                              ;029F0E|A90000  |      ;
    lda.w #bank(NewSpaceForGfxPaletteData)
    SEP #$20                                  ;029F11|E220    |      ;
  ; LDA.L LIST_palette_data_bank_offsets+2,X  ;029F13|BF028025|258002;
    STA.B $06                                 ;029F17|8506    |001F06;

;   LDA.B [$04]                               ;029F19|A704    |001F04; read a byte from 24-bit pointer, advance
;   INC.B $04                                 ;029F1B|E604    |001F04;
;   BNE +                                     ;029F1D|D003    |029F22;
;   JSR.W bank_wrap_ptr_in_04_to_06_029A69    ;029F1F|20699A  |029A69; bank wrap if necessary
; + STA.B $00                                 ;029F22|8500    |001F00; keep data byte in both $00 (original) and $01 (gets modified)
    jsr GetByteFromPtrAndBankWrap
    sta.b $00
    STA.B $01                                 ;029F24|8501    |001F01;

    LDX.W #$0000                              ;029F26|A20000  |      ; set initial loop conditions
    TXA                                       ;029F29|8A      |      ;
LOOP_test_MSB_of_addr_01_029F2A:
    ASL.B $01                                 ;029F2A|0601    |001F01; test the MSB of $01
    BCC case_shifted_out_0_029F52             ;029F2C|9024    |029F52;
case_shifted_out_1_029F2E:
    INX                                       ;029F2E|E8      |      ; if shifted out a 1, advance X position by 2 and do this loop 0xF times
    INX                                       ;029F2F|E8      |      ;
    LDY.W #$000E                              ;029F30|A00E00  |      ; effectively, read 0xF two-byte palette values
INNER_LOOP_029F33:
;   LDA.B [$04]                               ;029F33|A704    |001F04; read low byte of palette, store to buffer at $7FF70x
;   INC.B $04                                 ;029F35|E604    |001F04;
;   BNE +                                     ;029F37|D003    |029F3C;
;   JSR.W bank_wrap_ptr_in_04_to_06_029A69    ;029F39|20699A  |029A69;
; + STA.W $F700,X                             ;029F3C|9D00F7  |7EF700;
    jsr GetByteFromPtrAndBankWrap
    sta.w $f700,x
    INX                                       ;029F3F|E8      |      ;

;   LDA.B [$04]                               ;029F40|A704    |001F04; read high byte of palette, store to buffer at $7FF70x + 1
;   INC.B $04                                 ;029F42|E604    |001F04;
;   BNE +                                     ;029F44|D003    |029F49;
;   JSR.W bank_wrap_ptr_in_04_to_06_029A69    ;029F46|20699A  |029A69;
; + STA.W $F700,X                             ;029F49|9D00F7  |7EF700;
    jsr GetByteFromPtrAndBankWrap
    sta.w $f700,x
    INX                                       ;029F4C|E8      |      ;

    DEY                                       ;029F4D|88      |      ; decrement loop counter; repeat if needed
    BPL INNER_LOOP_029F33                     ;029F4E|10E3    |029F33;
    BRA check_for_more_bits_in_addr_01_029F5C ;029F50|800A    |029F5C;

case_shifted_out_0_029F52:
    REP #$20                                  ;029F52|C220    |      ; if shifted out a 0, advance X value by 0x20
    TXA                                       ;029F54|8A      |      ; i.e. move to next row in CGRAM
    CLC                                       ;029F55|18      |      ;
    ADC.W #$0020                              ;029F56|692000  |      ;
    TAX                                       ;029F59|AA      |      ;
    SEP #$20                                  ;029F5A|E220    |      ;
check_for_more_bits_in_addr_01_029F5C:
    LDA.B $01                                 ;029F5C|A501    |001F01;
    BNE LOOP_test_MSB_of_addr_01_029F2A       ;029F5E|D0CA    |029F2A;
; why is this LDA/STA here?
  ; LDA.B $00                                 ;029F60|A500    |001F00;
  ; STA.B $00                                 ;029F62|8500    |001F00;
    PLP                                       ;029F64|28      |      ;
    RTL                                       ;029F65|6B      |      ;

assert pc() <= $029f66,hex(pc())
print "pc() = $",hex(pc()),", saved 0x",hex($029f66-pc())," bytes with new tileset/tilemap/palette decomp code"
    fillbyte $ff
    fill $029f66-pc()

