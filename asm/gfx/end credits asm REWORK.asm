asar 1.91
lorom

incsrc "asm/! snes hw registers.asm"

SUB_01CD09 = $01cd09

LIST_values_for_DMAPx_for_end_credits_tilesets_018132 = $018132
LIST_values_for_VMAIN_for_end_credits_tileset_018134 = $018134
LIST_base_tilemap_entry_data_for_credits_tile_rows_018136 = $018136
LIST_0x300_byte_block_to_write_to_for_credits_018148 = $018148
LIST_offset_for_bot_mid_top_row_in_credits_char_018158 = $018158
LIST_offset_for_bot_mid_top_tile_row_01815E = $01815E

LIST_id_nums_for_credit_lines_5EC49C = $5EC49C
LIST_relative_offsets_for_credit_lines_5EC4E1 = $5EC4E1
LISTS_credits_letter_values_5EC547 = $5EC547
PTR_TABLE_credits_letter_gfx_5EC82B = $5EC82B

CreditsTilesetLocation = $7F0000
CreditsTilemapLocation = $7F3000

CreditsTilesetInVRAM = $6000
CreditsTilemapInVRAM = $7800

!FLAG_need_to_DMA_gfx_data_to_VRAM = $0001
!FLAG_done_with_one_line = $0002
!FLAG_skip_down_kanji_row = $0004
!FLAG_done_with_all_lines = $0080

CreditsStatusFlags = $3E
NumCharsLeftForLine = $42
CreditLineInVRAM = $44
NumLinesShown = $46
RelOffsetForCharIdInLine = $48
OffsetForGfxDataInBank7F = $4C
PtrToGfxDataInROM = $4E

; original game used 24x24 pixel blocks; planning to use 16x24 pixel blocks
; for the translation
!CreditsCharWidth = $2
; !CreditsCharWidth = $3
!CreditsCharHeight = $3

!OneCreditsTile = $08
!OneCreditsCharRow = $0300
; !OneCreditsCharRow = !OneCreditsTile*$20*!CreditsCharHeight

org $01cd82
    dw display_end_credits_at_high_level_01D96D

org $01d96d
display_end_credits_at_high_level_01D96D:
    LDA.B $14                                                          ;01D96D|A514    |0013F8;
    STA.B $3C                                                          ;01D96F|853C    |001420;
    STZ.B CreditsStatusFlags                                           ;01D971|643E    |001422;
    STZ.B NumLinesShown                                                ;01D973|6446    |00142A;

    JSR.W set_BG3_ctrl_regs_for_credits_01D9D0                         ;01D975|20D0D9  |01D9D0;
    JSR.W initialize_credits_tileset_in_VRAM_01D9FD                    ;01D978|20FDD9  |01D9FD;
    JSR.W generate_tilemap_for_rows_in_credits_01DA51                  ;01D97B|2051DA  |01DA51;
    JSR.W set_up_credits_tilemap_in_VRAM_01DA2B                        ;01D97E|202BDA  |01DA2B;

    LDA.W #$0004                                                       ;01D981|A90400  |      ; run $01CD09 a total of 4 times
    STA.B $40                                                          ;01D984|8540    |001424;
  - CLC                                                                ;01D986|18      |      ;
    JSR.W SUB_01CD09                                                   ;01D987|2009CD  |01CD09;
    DEC.B $40                                                          ;01D98A|C640    |001424;
    BNE -                                                              ;01D98C|D0F8    |01D986;

    JSR.W enable_BG3_for_credits_01D9EE                                ;01D98E|20EED9  |01D9EE;
    STZ.B CreditLineInVRAM                                             ;01D991|6444    |001428;
LOOP_01D993:
    LDA.W #$0020                                                       ;01D993|A92000  |      ;
    STA.B NumCharsLeftForLine                                          ;01D996|8542    |001426;
LOOP_read_char_data_for_line_01D998:
    CLC                                                                ;01D998|18      |      ;
    JSR.W SUB_01CD09                                                   ;01D999|2009CD  |01CD09;
    CLC                                                                ;01D99C|18      |      ;
    JSR.W SUB_01CD09                                                   ;01D99D|2009CD  |01CD09;
    JSR.W get_ptr_to_list_for_credit_line_01DAB6                       ;01D9A0|20B6DA  |01DAB6;
    CLC                                                                ;01D9A3|18      |      ;
    JSR.W SUB_01CD09                                                   ;01D9A4|2009CD  |01CD09;
    JSR.W read_gfx_data_for_one_credits_character_01DB10               ;01D9A7|2010DB  |01DB10;
    INC.W BG3VOFS_lo_copy_0367                                         ;01D9AA|EE6703  |010367;
    LDA.W #$0004                                                       ;01D9AD|A90400  |      ;
    TSB.W $1670                                                        ;01D9B0|0C7016  |011670;
    DEC.B NumCharsLeftForLine                                          ;01D9B3|C642    |001426;
    BNE LOOP_read_char_data_for_line_01D998                            ;01D9B5|D0E1    |01D998;

    JSR.W write_next_char_row_of_credits_gfx_to_VRAM_01DA81            ;01D9B7|2081DA  |01DA81;
    INC.B CreditLineInVRAM                                             ;01D9BA|E644    |001428;
    LDA.W #!FLAG_done_with_all_lines                                   ;01D9BC|A98000  |      ;
    AND.B CreditsStatusFlags                                           ;01D9BF|253E    |001422;
    BEQ LOOP_01D993                                                    ;01D9C1|F0D0    |01D993;
    DEC.B $40                                                          ;01D9C3|C640    |001424;
    BPL LOOP_01D993                                                    ;01D9C5|10CC    |01D993;

    LDA.W #$0080                                                       ;01D9C7|A98000  |      ;
    TRB.W $0912                                                        ;01D9CA|1C1209  |010912;
    JSR.W SUB_01CD09                                                   ;01D9CD|2009CD  |01CD09;

; ------------------------------------------------------------------------------

set_BG3_ctrl_regs_for_credits_01D9D0:
    PHP                                                                ;01D9D0|08      |      ;
    SEP #$30                                                           ;01D9D1|E230    |      ;
    LDA.B #$00                                                         ;01D9D3|A900    |      ; Mode 0, 8x8 tile sizes on all layers
    TRB.W BGMODE_copy_0355                                             ;01D9D5|1C5503  |010355;
    LDA.B #CreditsTilemapInVRAM>>8                                     ;01D9D8|A978    |      ; BG3 tilemap base is at 0x1E * 1K words -> $7800.w in VRAM; one screen
    STA.W BG3SC_copy_0359                                              ;01D9DA|8D5903  |010359;
    LDA.B #CreditsTilesetInVRAM>>12                                    ;01D9DD|A906    |      ; BG3 tile base addr is at 6000.w in VRAM
    STA.W BG34NBA_copy_035C                                            ;01D9DF|8D5C03  |01035C;
    LDA.B #$04                                                         ;01D9E2|A904    |      ; disable BG3 on main screen
    TRB.W TM_copy_0377                                                 ;01D9E4|1C7703  |010377;
  ; LDA.B #$13                                                         ;01D9E7|A913    |      ;
  ; TSB.W $1670                                                        ;01D9E9|0C7016  |011670;
  ; PLP                                                                ;01D9EC|28      |      ;
  ; RTS                                                                ;01D9ED|60      |      ;
    bra +

enable_BG3_for_credits_01D9EE:
    PHP                                                                ;01D9EE|08      |      ;
    SEP #$30                                                           ;01D9EF|E230    |      ;
    LDA.B #$04                                                         ;01D9F1|A904    |      ;
    TSB.W TM_copy_0377                                                 ;01D9F3|0C7703  |010377;
  + LDA.B #$13                                                         ;01D9F6|A913    |      ;
    TSB.W $1670                                                        ;01D9F8|0C7016  |011670;
    PLP                                                                ;01D9FB|28      |      ;
    RTS                                                                ;01D9FC|60      |      ;

; ------------------------------------------------------------------------------

initialize_credits_tileset_in_VRAM_01D9FD:
    PHP                                                                ;01D9FD|08      |      ;
    SEP #$10                                                           ;01D9FE|E210    |      ;
    LDY.B #$01                                                         ;01DA00|A001    |      ; Y = 1 does VRAM high bytes, Y = 0 does VRAM low bytes
LOOP_01DA02:
    LDX.B #$9B                                                         ;01DA02|A29B    |      ; $00 <- 0x9B = BRK flags
    STX.B $00                                                          ;01DA04|8600    |0013E4;

    LDA.W #CreditsTilesetInVRAM                                        ;01DA06|A90060  |      ; $01 <- $6000.w is VRAM address for credits graphics
    STA.B $01                                                          ;01DA09|8501    |0013E5;

    LDA.W #$1800                                                       ;01DA0B|A90018  |      ; $03 <- 0x1800 = size of graphics
    STA.B $03                                                          ;01DA0E|8503    |0013E7;

    LDX.W LIST_values_for_DMAPx_for_end_credits_tilesets_018132,Y      ;01DA10|BE3281  |018132; $05 <- DMA parameters = either 0x28 (Y=1) or 0x08 (Y=0)
    STX.B $05                                                          ;01DA13|8605    |0013E9; 0x28 is for VRAM high byte, 0x08 is for VRAM low byte

    LDA.W #DATA_00_01DA2A                                              ;01DA15|A92ADA  |      ; construct pointer $01DA2A in $06-$08
    STA.B $06                                                          ;01DA18|8506    |0013EA;
    LDX.B #bank(DATA_00_01DA2A)                                        ;01DA1A|A201    |      ;
    STX.B $08                                                          ;01DA1C|8608    |0013EC;

    LDX.W LIST_values_for_VMAIN_for_end_credits_tileset_018134,Y       ;01DA1E|BE3481  |018134; $09 <- VRAM increment mode, either 0x80 (Y=1) or 0x00 (Y=0)
    STX.B $09                                                          ;01DA21|8609    |0013ED; increment after high byte (0x80) or low byte (0x00)

    BRK #$0C                                                           ;01DA23|000C    |      ;
    DEY                                                                ;01DA25|88      |      ;
    BPL LOOP_01DA02                                                    ;01DA26|10DA    |01DA02;
    PLP                                                                ;01DA28|28      |      ;
    RTS                                                                ;01DA29|60      |      ;
DATA_00_01DA2A:
    db $00                                                             ;01DA2A|        |      ;

; ------------------------------------------------------------------------------

set_up_credits_tilemap_in_VRAM_01DA2B:
    PHP                                                                ;01DA2B|08      |      ;
    SEP #$10                                                           ;01DA2C|E210    |      ;

    LDX.B #$1B                                                         ;01DA2E|A21B    |      ; 0x1B has flags for the BRK below
    STX.B $00                                                          ;01DA30|8600    |0013E4;

    LDA.W #CreditsTilemapInVRAM                                        ;01DA32|A90078  |      ; $7800.w is VRAM address for credits tilemap
    STA.B $01                                                          ;01DA35|8501    |0013E5;

    LDA.W #$0800                                                       ;01DA37|A90008  |      ; write 0x800 bytes = 0x400 tilemap entries
    STA.B $03                                                          ;01DA3A|8503    |0013E7;

    LDX.B #$01                                                         ;01DA3C|A201    |      ; DMA parameters (DMAPx) 0x01 = two bytes at a time
    STX.B $05                                                          ;01DA3E|8605    |0013E9;

    LDA.W #CreditsTilemapLocation                                      ;01DA40|A90030  |      ; construct pointer $7F3000 in $06-$08
    STA.B $06                                                          ;01DA43|8506    |0013EA;
  ; LDX.B #bank(CreditsTilemapLocation)                                ;01DA45|A27F    |      ;
  ; STX.B $08                                                          ;01DA47|8608    |0013EC;
  ; LDX.B #$80                                                         ;01DA49|A280    |      ; VRAM increment mode 0x80 = after high byte
  ; STX.B $09                                                          ;01DA4B|8609    |0013ED;
    lda.w #bank(CreditsTilesetLocation)|($80<<8)
    sta.b $08

    BRK #$0C                                                           ;01DA4D|000C    |      ;
    PLP                                                                ;01DA4F|28      |      ;
    RTS                                                                ;01DA50|60      |      ;

; ------------------------------------------------------------------------------

generate_tilemap_for_rows_in_credits_01DA51:
    LDX.W #$07FE                                                       ;01DA51|A2FE07  |      ;
    LDA.W #$03FF                                                       ;01DA54|A9FF03  |      ;

LOOP_auto_fill_credits_tilemap_with_03FF_01DA57:
    STA.L CreditsTilemapLocation,X                                     ;01DA57|9F00307F|7F3000; fill 0x400 tilemap entries with 03FF = use very last tile in tilemap
    DEX #2                                                             ;01DA5B|CA      |      ;
    BPL LOOP_auto_fill_credits_tilemap_with_03FF_01DA57                ;01DA5D|10F8    |01DA57;

    LDY.W #$0010                                                       ;01DA5F|A01000  |      ; work on 0x12 (eighteen) rows = 6 rows of characters
    LDX.W #$0000                                                       ;01DA62|A20000  |      ;
LOOP_fill_in_one_char_row_for_credits_01DA65:
    LDA.W LIST_base_tilemap_entry_data_for_credits_tile_rows_018136,Y  ;01DA65|B93681  |018136; each character row gets 0x60 increasing entries with high priority
    DEY                                                                ;01DA68|88      |      ; e.g.: 2000, 2001, 2002, ..., 205E, 205F
    DEY                                                                ;01DA69|88      |      ; three rows of 0x20 tiles per row, i.e. one row of characters on screen
    BMI RTS_01DA80                                                     ;01DA6A|3014    |01DA80;
LOOP_fill_in_one_tile_row_for_credits_01DA6C:
    STA.L CreditsTilemapLocation,X                                     ;01DA6C|9F00307F|7F3000;
    INX #2                                                             ;01DA70|E8      |      ;
    INC A                                                              ;01DA72|1A      |      ;
    CMP.W LIST_base_tilemap_entry_data_for_credits_tile_rows_018136,Y  ;01DA73|D93681  |018136;
    BNE LOOP_fill_in_one_tile_row_for_credits_01DA6C                   ;01DA76|D0F4    |01DA6C;

skip_down_one_tile_row_in_tilemap_01DA78:
    TXA                                                                ;01DA78|8A      |      ; when it gets to 2060, bump address to write to, down by a tile row
    CLC                                                                ;01DA79|18      |      ; but still write the next sequence 2060, 2061, 2062, ..., 20BE, 20BF
    ADC.W #$0040                                                       ;01DA7A|694000  |      ;
    TAX                                                                ;01DA7D|AA      |      ;
    BRA LOOP_fill_in_one_char_row_for_credits_01DA65                   ;01DA7E|80E5    |01DA65;

RTS_01DA80:
    RTS                                                                ;01DA80|60      |      ;

; ------------------------------------------------------------------------------

write_next_char_row_of_credits_gfx_to_VRAM_01DA81:
    PHP                                                                ;01DA81|08      |      ;
    SEP #$10                                                           ;01DA82|E210    |      ;
    LDX.B #$1B                                                         ;01DA84|A21B    |      ; 0x1B = flags for BRK below
    STX.B $00                                                          ;01DA86|8600    |0013E4;

    LDA.B CreditLineInVRAM                                             ;01DA88|A544    |001428; get VRAM address to write to (0x300 byte blocks)
    AND.W #$0007                                                       ;01DA8A|290700  |      ;
    ASL A                                                              ;01DA8D|0A      |      ;
    TAX                                                                ;01DA8E|AA      |      ;
    LDA.W LIST_0x300_byte_block_to_write_to_for_credits_018148,X       ;01DA8F|BD4881  |018148;
    STA.B $01                                                          ;01DA92|8501    |0013E5;

    LDA.W #!OneCreditsCharRow                                          ;01DA94|A90003  |      ; DMA transfer size = 0x300 bytes
    STA.B $03                                                          ;01DA97|8503    |0013E7;

    LDX.B #$00                                                         ;01DA99|A200    |      ; DMA parameters 0x00
    STX.B $05                                                          ;01DA9B|8605    |0013E9;

    LDA.W #CreditsTilesetLocation                                      ;01DA9D|A90000  |      ; construct address $7F0000
    STA.B $06                                                          ;01DAA0|8506    |0013EA;
  ; LDX.B #bank(CreditsTilesetLocation)                                ;01DAA2|A27F    |      ;
  ; STX.B $08                                                          ;01DAA4|8608    |0013EC;
  ; LDX.B #$00                                                         ;01DAA6|A200    |      ; VRAM address increment mode
  ; STX.B $09                                                          ;01DAA8|8609    |0013ED;
    lda.w #bank(CreditsTilesetLocation)|($00<<8)
    sta.b $08

    BRK #$0C                                                           ;01DAAA|000C    |      ;

    LDA.W #!FLAG_need_to_DMA_gfx_data_to_VRAM                          ;01DAAC|A90100  |      ;
    TRB.B CreditsStatusFlags                                           ;01DAAF|143E    |001422;

    JSR.W handle_skipping_down_three_tile_rows_if_needed_01DBC4        ;01DAB1|20C4DB  |01DBC4;
    PLP                                                                ;01DAB4|28      |      ;
    RTS                                                                ;01DAB5|60      |      ;

; ------------------------------------------------------------------------------

get_ptr_to_list_for_credit_line_01DAB6:
    PHP                                                                ;01DAB6|08      |      ;
  ; LDA.W #$0080                                                       ;01DAB7|A98000  |      ;
  ; ORA.W #$0001                                                       ;01DABA|090100  |      ; check if previously got value for next credit line
  ; ORA.W #$0004                                                       ;01DABD|090400  |      ; check if previously got value to skip down a character row
    LDA.W #!FLAG_done_with_all_lines|!FLAG_need_to_DMA_gfx_data_to_VRAM|!FLAG_skip_down_kanji_row
    AND.B CreditsStatusFlags                                           ;01DAC0|253E    |001422;
    BNE PLP_RTS_01DB0E                                                 ;01DAC2|D04A    |01DB0E;

    STZ.B OffsetForGfxDataInBank7F                                     ;01DAC4|644C    |001430;
    JSR.W fill_one_credits_char_row_with_00_01DBB5                     ;01DAC6|20B5DB  |01DBB5;

    SEP #$20                                                           ;01DAC9|E220    |      ;
    LDX.B NumLinesShown                                                ;01DACB|A646    |00142A;
  ; LDA.L LIST_id_nums_for_credit_lines_5EC49C,X                       ;01DACD|BF9CC45E|5EC49C;
    lda.l NewEndCreditsLineIDs,x
    BMI check_if_80_or_FF_01DAEC                                       ;01DAD1|3019    |01DAEC;
case_get_offset_for_next_credit_line_01DAD3:
    REP #$20                                                           ;01DAD3|C220    |      ;
    AND.W #$007F                                                       ;01DAD5|297F00  |      ;
    ASL A                                                              ;01DAD8|0A      |      ;
    TAX                                                                ;01DAD9|AA      |      ;
  ; LDA.L LIST_relative_offsets_for_credit_lines_5EC4E1,X              ;01DADA|BFE1C45E|5EC4E1;
    lda.l NewListOfOffsetsToBlockIds,x
    STA.B RelOffsetForCharIdInLine                                     ;01DADE|8548    |00142C;

    LDA.W #!FLAG_need_to_DMA_gfx_data_to_VRAM                          ;01DAE0|A90100  |      ;
    TSB.B CreditsStatusFlags                                           ;01DAE3|043E    |001422;
    LDA.W #!FLAG_done_with_one_line                                    ;01DAE5|A90200  |      ;
    TRB.B CreditsStatusFlags                                           ;01DAE8|143E    |001422;
    BRA inc_num_lines_shown_PLP_RTS_01DB0C                             ;01DAEA|8020    |01DB0C;

check_if_80_or_FF_01DAEC:
    CMP.B #$FF                                                         ;01DAEC|C9FF    |      ;
    BEQ case_got_FF_end_of_credits_lines_01DAFD                        ;01DAEE|F00D    |01DAFD;
case_got_80_skip_down_3_char_rows_01DAF0:
    REP #$20                                                           ;01DAF0|C220    |      ;
    LDA.W #!FLAG_skip_down_kanji_row                                   ;01DAF2|A90400  |      ;
    TSB.B CreditsStatusFlags                                           ;01DAF5|043E    |001422;
    LDA.B $3C                                                          ;01DAF7|A53C    |001420;
    STA.B $4A                                                          ;01DAF9|854A    |00142E;
    BRA inc_num_lines_shown_PLP_RTS_01DB0C                             ;01DAFB|800F    |01DB0C;

case_got_FF_end_of_credits_lines_01DAFD:
    REP #$20                                                           ;01DAFD|C220    |      ;
  ; LDA.W #$0080                                                       ;01DAFF|A98000  |      ;
  ; ORA.W #$0002                                                       ;01DB02|090200  |      ;
    LDA.W #!FLAG_done_with_all_lines|!FLAG_done_with_one_line
    TSB.B CreditsStatusFlags                                           ;01DB05|043E    |001422;
    LDA.W #$0003                                                       ;01DB07|A90300  |      ;
    STA.B $40                                                          ;01DB0A|8540    |001424;
inc_num_lines_shown_PLP_RTS_01DB0C:
    INC.B NumLinesShown                                                ;01DB0C|E646    |00142A;
PLP_RTS_01DB0E:
    PLP                                                                ;01DB0E|28      |      ;
    RTS                                                                ;01DB0F|60      |      ;

; ------------------------------------------------------------------------------

read_gfx_data_for_one_credits_character_01DB10:
    PHP                                                                ;01DB10|08      |      ;
  ; LDA.W #$0002                                                       ;01DB11|A90200  |      ; check if got FF above
  ; ORA.W #$0004                                                       ;01DB14|090400  |      ; check if got 80 above
    LDA.W #!FLAG_done_with_one_line|!FLAG_skip_down_kanji_row
    AND.B CreditsStatusFlags                                           ;01DB17|253E    |001422;
    BNE PLP_RTS_01DB42                                                 ;01DB19|D027    |01DB42; if either is true, do nothing for this subroutine call

    SEP #$20                                                           ;01DB1B|E220    |      ;
    LDX.B RelOffsetForCharIdInLine                                     ;01DB1D|A648    |00142C; get pointer to 0x48 bytes of 1bpp graphics data (3x3 tile block)
  ; LDA.L LISTS_credits_letter_values_5EC547,X                         ;01DB1F|BF47C55E|5EC547;
    lda.l NewListsOfBlockIds,x

; add case for FE to signify "go left one tile column"
  ; CMP.B #$FF                                                         ;01DB23|C9FF    |      ; [FF] is end of data
  ; BEQ case_FF_end_of_data_for_one_line_01DB3B                        ;01DB25|F014    |01DB3B;
    cmp.b #$fe
    beq case_FE_go_back_one_tile_col
    bcs case_FF_end_of_data_for_one_line_01DB3B

    REP #$20                                                           ;01DB27|C220    |      ;
    INC.B RelOffsetForCharIdInLine                                     ;01DB29|E648    |00142C; advance pointer to next letter value in list
    AND.W #$00FF                                                       ;01DB2B|29FF00  |      ;
    BEQ case_00_advance_1_tile_col_01DB36                              ;01DB2E|F006    |01DB36; if got [00], fill in three sets of eight [00] bytes = advance 1 tile col
    DEC A                                                              ;01DB30|3A      |      ; otherwise, read credits data
case_general_read_credits_gfx_data_01DB31:
    JSR.W read_gfx_data_for_credits_char_01DB44                        ;01DB31|2044DB  |01DB44;
    BRA PLP_RTS_01DB42                                                 ;01DB34|800C    |01DB42;
case_00_advance_1_tile_col_01DB36:
    JSR.W insert_1_empty_tile_col_for_credits_char_01DB8A              ;01DB36|208ADB  |01DB8A;
    BRA PLP_RTS_01DB42                                                 ;01DB39|8007    |01DB42;
case_FF_end_of_data_for_one_line_01DB3B:
    REP #$20                                                           ;01DB3B|C220    |      ;
    LDA.W #!FLAG_done_with_one_line                                    ;01DB3D|A90200  |      ;
    TSB.B CreditsStatusFlags                                           ;01DB40|043E    |001422;
PLP_RTS_01DB42:
    PLP                                                                ;01DB42|28      |      ;
    RTS                                                                ;01DB43|60      |      ;

; ASM hack based on $01DBAC below
; optimization to save a byte: got here via a CMP where the tested value equaled
; the value to test against (0xFE), so carry got set; don't need explicit SEC
case_FE_go_back_one_tile_col:
    rep #$20
    lda.b OffsetForGfxDataInBank7F
  ; sec
	sbc.w #!OneCreditsTile
    sta.b OffsetForGfxDataInBank7F
; you need to explicitly increment past the FE here
    inc.b RelOffsetForCharIdInLine
    bra PLP_RTS_01DB42

; ------------------------------------------------------------------------------

; possible improvement: put all credits gfx into one bank and hard-code it here
; to allow using a pointer table with 16-bit entries instead of 24-bit entries
read_gfx_data_for_credits_char_01DB44:
; print hex(pc()),": calculate pointer to end credits graphics data block to read"
  ; PHA                                                                ;01DB44|48      |      ; use A as index to ptr list at $5EC82B
  ; ASL A                                                              ;01DB45|0A      |      ;
  ; CLC                                                                ;01DB46|18      |      ;
  ; ADC.B $01,S                                                        ;01DB47|6301    |000001;
  ; TAX                                                                ;01DB49|AA      |      ;

  ; LDA.L PTR_TABLE_credits_letter_gfx_5EC82B,X                        ;01DB4A|BF2BC85E|5EC82B; store 24-bit pointer to $4E-$50
  ; STA.B PtrToGfxDataInROM                                            ;01DB4E|854E    |001432;
  ; SEP #$20                                                           ;01DB50|E220    |      ;
  ; LDA.L PTR_TABLE_credits_letter_gfx_5EC82B+$2,X                     ;01DB52|BF2DC85E|5EC82D;
  ; STA.B PtrToGfxDataInROM+$2                                         ;01DB56|8550    |001434;

  ; REP #$20                                                           ;01DB58|C220    |      ;
  ; PLA                                                                ;01DB5A|68      |      ;

; to be used when new English credits (16x24 blocks) are added
; 0x10 * 0x18 / 8 = 0x30, which is easy to compute with ASLs and such
    pha         ; N*0x30 = (N*2 + N) * 0x10
    asl a
    clc
    adc.b $01,s
    asl #4

    clc
    adc.w #NewCreditsGraphicsData
    sta.b PtrToGfxDataInROM
    pla
    sep #$20
    lda.b #bank(NewCreditsGraphicsData)
    sta.b PtrToGfxDataInROM+2
    rep #$20

    LDX.W #(!CreditsCharHeight-1)*2                                    ;01DB5B|A20400  |      ; run the inner loop a total of 3 times (read a total of 0x48 bytes)
    LDY.W #$0000                                                       ;01DB5E|A00000  |      ;
OUTER_LOOP_read_3_rows_of_3_tiles_01DB61:
    LDA.B OffsetForGfxDataInBank7F                                     ;01DB61|A54C    |001430; a row of credits is 3 tiles high; pick if doing top, middle, or bottom tile row
    CLC                                                                ;01DB63|18      |      ;
    ADC.W LIST_offset_for_bot_mid_top_row_in_credits_char_018158,X     ;01DB64|7D5881  |018158;
    PHX                                                                ;01DB67|DA      |      ;
    TAX                                                                ;01DB68|AA      |      ;

    LDA.W #!OneCreditsTile*!CreditsCharWidth/2-1                       ;01DB69|A90B00  |      ;
    STA.B $4A                                                          ;01DB6C|854A    |00142E;
INNER_LOOP_read_row_of_3_tiles_01DB6E:
    LDA.B [PtrToGfxDataInROM],Y                                        ;01DB6E|B74E    |001432; read 0x18 bytes of data (row of 3 tiles) from pointer into bank 7F
    STA.L CreditsTilesetLocation,X                                     ;01DB70|9F00007F|7F0000;
    INY #2                                                             ;01DB74|C8      |      ;
    INX #2                                                             ;01DB76|E8      |      ;
    DEC.B $4A                                                          ;01DB78|C64A    |00142E;
    BPL INNER_LOOP_read_row_of_3_tiles_01DB6E                          ;01DB7A|10F2    |01DB6E;

    PLX                                                                ;01DB7C|FA      |      ;
    DEX #2                                                             ;01DB7D|CA      |      ;
    BPL OUTER_LOOP_read_3_rows_of_3_tiles_01DB61                       ;01DB7F|10E0    |01DB61;

    LDA.B OffsetForGfxDataInBank7F                                     ;01DB81|A54C    |001430; advance offset in bank 7F past these 0x18 bytes
    CLC                                                                ;01DB83|18      |      ;
    ADC.W #!OneCreditsTile*!CreditsCharWidth                           ;01DB84|691800  |      ;
    STA.B OffsetForGfxDataInBank7F                                     ;01DB87|854C    |001430;
    RTS                                                                ;01DB89|60      |      ;

; ------------------------------------------------------------------------------

insert_1_empty_tile_col_for_credits_char_01DB8A:
    LDX.W #(!CreditsCharHeight-1)*2                                    ;01DB8A|A20400  |      ;

  - LDA.B OffsetForGfxDataInBank7F                                     ;01DB8D|A54C    |001430; take current offset in bank 7F, and go down 0, 1, or 2 tile rows
    CLC                                                                ;01DB8F|18      |      ;
    ADC.W LIST_offset_for_bot_mid_top_tile_row_01815E,X                ;01DB90|7D5E81  |01815E;
    PHX                                                                ;01DB93|DA      |      ;
    TAX                                                                ;01DB94|AA      |      ;

    LDA.W #!OneCreditsTile/2-1                                         ;01DB95|A90300  |      ; fill 0x8 bytes with [00] = 0x4 words with [00 00]
    STA.B $4A                                                          ;01DB98|854A    |00142E;
    LDA.W #$0000                                                       ;01DB9A|A90000  |      ;
 -- STA.L CreditsTilesetLocation,X                                     ;01DB9D|9F00007F|7F0000;
    INX #2                                                             ;01DBA1|E8      |      ;
    DEC.B $4A                                                          ;01DBA3|C64A    |00142E;
    BPL --                                                             ;01DBA5|10F6    |01DB9D;

    PLX                                                                ;01DBA7|FA      |      ;
    DEX #2                                                             ;01DBA8|CA      |      ; do this for the three tile rows
    BPL -                                                              ;01DBAA|10E1    |01DB8D;

    LDA.B OffsetForGfxDataInBank7F                                     ;01DBAC|A54C    |001430; advance one tile to the right
    CLC                                                                ;01DBAE|18      |      ;
    ADC.W #!OneCreditsTile                                             ;01DBAF|690800  |      ;
    STA.B OffsetForGfxDataInBank7F                                     ;01DBB2|854C    |001430;
    RTS                                                                ;01DBB4|60      |      ;

; ------------------------------------------------------------------------------

fill_one_credits_char_row_with_00_01DBB5:
; $20 tiles across, 3 tiles tall -> $60 tiles, $300 bytes
    LDX.W #!OneCreditsCharRow-2                                         ;01DBB5|A2FE02  |      ;
    LDA.W #$0000                                                       ;01DBB8|A90000  |      ;
  - STA.L CreditsTilesetLocation,X                                     ;01DBBB|9F00007F|7F0000;
    DEX #2                                                             ;01DBBF|CA      |      ;
    BPL -                                                              ;01DBC1|10F8    |01DBBB;
    RTS                                                                ;01DBC3|60      |      ;

; ------------------------------------------------------------------------------

handle_skipping_down_three_tile_rows_if_needed_01DBC4:
    LDA.W #!FLAG_skip_down_kanji_row                                   ;01DBC4|A90400  |      ;
    AND.B CreditsStatusFlags                                           ;01DBC7|253E    |001422;
    BEQ +                                                              ;01DBC9|F009    |01DBD4;
    DEC.B $4A                                                          ;01DBCB|C64A    |00142E;
    BNE +                                                              ;01DBCD|D005    |01DBD4;
    LDA.W #!FLAG_skip_down_kanji_row                                   ;01DBCF|A90400  |      ;
    TRB.B CreditsStatusFlags                                           ;01DBD2|143E    |001422;
  + RTS                                                                ;01DBD4|60      |      ;

; ------------------------------------------------------------------------------

assert pc() <= $01dbd5
    fillbyte $ff
    fill $01dbd5-pc()
