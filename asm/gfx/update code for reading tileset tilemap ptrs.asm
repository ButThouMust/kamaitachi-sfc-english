includefrom "MAIN recompress and repoint data.asm"

; ------------------------------------------------------------------------------

; need to change pointer table offset calculations from N*9 to N*8

; OLD: NOP out the "+ N" from N*9 = N*8 + N
; org $028d4f
  ; CLC : ADC $00
  ; nop #3

; OLD: update pointer for high/bank bytes of tileSET pointer
; org $028d54
    ; dl GfxPtrTable.TilesetPtr+1

; OLD: update pointer for low/high bytes of tileMAP pointer
; org $028d59
    ; dl GfxPtrTable.TilemapPtr

; OLD: update pointer for bank byte of tileMAP pointer, low byte of tileSET pointer
; org $028d5f
    ; dl GfxPtrTable.TilemapPtr+2

org $028d47
get_tiles_and_tilemap_for_GFX_ID_028D47:
    PHP                                     ;028D47|08      |      ;
    REP #$30                                ;028D48|C230    |      ;

    LDA.B $00                               ;028D4A|A500    |001F00; X <- value in $00, multiplied by 9
    ASL A                                   ;028D4C|0A      |      ;
    ASL A                                   ;028D4D|0A      |      ;
    ASL A                                   ;028D4E|0A      |      ;
; get rid of the "+ N" from N*9 = N*8 + N
  ; CLC                                     ;028D4F|18      |      ;
  ; ADC.B $00                               ;028D50|6500    |001F00;
    TAX                                     ;028D52|AA      |      ;

  ; LDA.L PTR24_258007,X                    ;028D53|BF078025|258007; push high and bank bytes of tileset pointer
    lda.l GfxPtrTable.TilesetPtr+1,x
    PHA                                     ;028D57|48      |      ;

  ; LDA.L LIST_tilemap_data_bank_offsets,X  ;028D58|BF038025|258003; $00 <- low and high bytes of tilemap pointer
    lda.l GfxPtrTable.TilemapPtr,x
    STA.B $00                               ;028D5C|8500    |001F00;

  ; LDA.L PTR24_258005,X                    ;028D5E|BF058025|258005; get bank byte of tilemap pointer, and low byte of tileset pointer
    lda.l GfxPtrTable.TilemapPtr+2,x
    SEP #$20                                ;028D62|E220    |      ;
    XBA                                     ;028D64|EB      |      ; push the low byte of tileset pointer (now fully on the stack)
    PHA                                     ;028D65|48      |      ;

    LDA.B $02                               ;028D66|A502    |001F02; push current value of $02 onto stack
    PHA                                     ;028D68|48      |      ;
    XBA                                     ;028D69|EB      |      ; $02 <- bank byte of "ptr 1" i.e. copy "ptr 1" to $00-$02
    STA.B $02                               ;028D6A|8502    |001F02;

    LDA.B $01                               ;028D6C|A501    |001F01; check if tilemap ptr is to ROM or not
    BPL special_case_tilemap_0x66_028D79    ;028D6E|1009    |028D79; the only one like this is 0x66 = file select bookmark
case_gfx_ptr_1_is_to_ROM_028D70:
  ; JSL.L decompress_tilemap_029A87         ;028D70|22879A02|029A87;
    jsr decompress_tilemap_029A87
    LDY.W #$0001                            ;028D74|A00100  |      ;
    BRA set_up_to_decompress_tileset_028D97 ;028D77|801E    |028D97;

special_case_tilemap_0x66_028D79:
    ORA.B #$80                              ;028D79|0980    |      ; force pointer to go to ROM
    STA.B $01                               ;028D7B|8501    |001F01;
    LDA.B $03                               ;028D7D|A503    |001F03; keep track of which "block" of 0x380 bytes to decompress into
    PHA                                     ;028D7F|48      |      ;
  ; JSL.L decompress_tilemap_029A87         ;028D80|22879A02|029A87; decompress the tilemap
    jsr decompress_tilemap_029A87

    PLA                                     ;028D84|68      |      ; $03 <- 1 + (old value of $03 before tilemap decompression)
    INC A                                   ;028D85|1A      |      ; i.e. prepare to write into next "block"
    STA.B $03                               ;028D86|8503    |001F03;

    LDX.B CompressedTilemapPtr              ;028D88|A604    |001F04; decompress the SECOND tilemap for this gfx ID
    STX.B $00                               ;028D8A|8600    |001F00;
    LDA.B CompressedTilemapPtr+2            ;028D8C|A506    |001F06;
    STA.B $02                               ;028D8E|8502    |001F02;
  ; JSL.L decompress_tilemap_029A87         ;028D90|22879A02|029A87;
    jsr decompress_tilemap_029A87

    LDY.W #$0002                            ;028D94|A00200  |      ;
set_up_to_decompress_tileset_028D97:
    PLA                                     ;028D97|68      |      ; $03 <- old value of $02 from $028D66
    STA.B $03                               ;028D98|8503    |001F03;
    PLX                                     ;028D9A|FA      |      ; $00-$02 <- pointer to graphics
    STX.B $00                               ;028D9B|8600    |001F00;
    PLA                                     ;028D9D|68      |      ;
    STA.B $02                               ;028D9E|8502    |001F02;
    PHY                                     ;028DA0|5A      |      ; push current offset after the tilemap(s)
    JSL.L decompress_tiles_028DAA           ;028DA1|22AA8D02|028DAA;

    PLY                                     ;028DA5|7A      |      ;
    STY.B $00                               ;028DA6|8400    |001F00;
    PLP                                     ;028DA8|28      |      ;
    RTL                                     ;028DA9|6B      |      ;

; after this comes the code for tileset decompression
