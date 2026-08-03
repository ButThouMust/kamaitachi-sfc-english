; This is Chunsoft's ASM code for tileset decompression with my own labels and
; comments for making it easier to read. It gets assembled to the same machine
; code. Use this if you want the code to be faster, at the expense of needing
; more space to store it.

includefrom "MAIN recompress repoint gfx.asm"

; Overview of data on direct page ($1F00)
; $00-$02 starts with start ptr for compressed data
; - they get overwritten with scratch data
; $03     starts with which "block number" to decompress tileset data into
; - it also gets overwritten with scratch data
CompressedTilesetPtr = $04       ; 3 bytes: $04-$06
TilesetBufferCurrentOffset = $07 ; 2 bytes: $07-$08
TilesetBufferStartOffset = $09   ; 2 bytes: $09-$0A
; $0B-$0E are four bytes of scratch space

TilesetBuffer = $7E8000

LIST_bitmask_group_0 = $7EF69A
LIST_bitmask_group_1 = $7EF6A2
LIST_bitmask_group_2 = $7EF6AA

LIST_bitmask_group_0_INVERT = $7EF6B2
LIST_bitmask_group_1_INVERT = $7EF6BA
LIST_bitmask_group_2_INVERT = $7EF6C2

LIST_tile_bitmasks_F6CA_bank_7E = $7EF6CA

LIST_bit_positions_of_1_bits_bank_7E = $7EF6D2
BUFFER_bitmask_contruction_data_F6DB = $7EF6DB

PTR_subroutine_for_reading_bitmask_data = $7EF6E3

tile_metadata_list_bank_7E = $7EF6E5
tile_metadata_common_bitplane_combinations = $7EF6E5
tile_metadata_common_bitmask_combinations = $7EF6F1

!NumRowsInTile = $0008
!OneTileSize = $20
!BP0 = $00
!BP1 = $01
!BP2 = $10
!BP3 = $11

; org $028DAA
decompress_tiles_028DAA:
    PHP                                                                 ;028DAA|08      |      ;
    SEP #$30                                                            ;028DAB|E230    |      ;

    LDA.B $03                                                           ;028DAD|A503    |001F03; use the value in $03 to determine where to copy graphics to
    ASL A                                                               ;028DAF|0A      |      ;
    TAX                                                                 ;028DB0|AA      |      ;

    LDA.L LIST_bank_7E_or_7F_at_029A7F,X                                ;028DB1|BF7F9A02|029A7F; either get 7E0000, 7E4000, 7F0000, or 7F4000
    PHA                                                                 ;028DB5|48      |      ; set the data bank accordingly
    PLB                                                                 ;028DB6|AB      |      ;

    LDA.L LIST_0000_or_4000_at_029A77,X                                 ;028DB7|BF779A02|029A77; write the bank offset to $09-$0A
    STA.B TilesetBufferStartOffset                                      ;028DBB|8509    |001F09; ultimately, the starting pointer is one of: 7E8000, 7EC000, 7F8000, 7FC000
    LDA.L LIST_0000_or_4000_at_029A77+1,X                               ;028DBD|BF789A02|029A78;
    STA.B TilesetBufferStartOffset+1                                    ;028DC1|850A    |001F0A;

    REP #$10                                                            ;028DC3|C210    |      ;
    LDA.B $02                                                           ;028DC5|A502    |001F02; copy 24-bit pointer from $00-$02 (pointer 2) into $04-$06
    STA.B CompressedTilesetPtr+2                                        ;028DC7|8506    |001F06;
    LDX.B $00                                                           ;028DC9|A600    |001F00;
    STX.B CompressedTilesetPtr                                          ;028DCB|8604    |001F04;

    LDX.B TilesetBufferStartOffset                                      ;028DCD|A609    |001F09; get offset from $7?8000 for where to write data
    LDY.W #$001F                                                        ;028DCF|A01F00  |      ; construct an empty tile of 0x20 bytes
LOOP_create_empty_4bpp_tile_028DD2:
    STZ.W TilesetBuffer,X                                               ;028DD2|9E0080  |7E8000;
    INX                                                                 ;028DD5|E8      |      ;
    DEY                                                                 ;028DD6|88      |      ;
    BPL LOOP_create_empty_4bpp_tile_028DD2                              ;028DD7|10F9    |028DD2;

    STX.B TilesetBufferCurrentOffset                                    ;028DD9|8607    |001F07; copy current offset to $07-$08
    LDX.W #$0000                                                        ;028DDB|A20000  |      ;
LOOP_read_1B_bytes_from_ptr_in_04_028DDE:
    LDA.B [CompressedTilesetPtr]                                        ;028DDE|A704    |001F04; read 1B bytes from pointer in $04-$06 into space at $7?F6E5
    INC.B CompressedTilesetPtr                                          ;028DE0|E604    |001F04;
    BNE +                                                               ;028DE2|D003    |028DE7;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028DE4|20699A  |029A69;
  + STA.W tile_metadata_list_bank_7E,X                                  ;028DE7|9DE5F6  |7EF6E5;
    INX                                                                 ;028DEA|E8      |      ;
    CPX.W #$001B                                                        ;028DEB|E01B00  |      ;
    BNE LOOP_read_1B_bytes_from_ptr_in_04_028DDE                        ;028DEE|D0EE    |028DDE;
    BRA MAIN_LOOP_read_tile_data_type_byte_from_ptr_028DFD              ;028DF0|800B    |028DFD;

advance_offset_in_07_to_next_tile_028DF2:
    LDA.B TilesetBufferCurrentOffset                                    ;028DF2|A507    |001F07;
    CLC                                                                 ;028DF4|18      |      ;
    ADC.B #!OneTileSize                                                 ;028DF5|6920    |      ;
    STA.B TilesetBufferCurrentOffset                                    ;028DF7|8507    |001F07;
    BCC MAIN_LOOP_read_tile_data_type_byte_from_ptr_028DFD              ;028DF9|9002    |028DFD; do carry for 16-bit sum with 8-bit arithmetic
    INC.B TilesetBufferCurrentOffset+1                                  ;028DFB|E608    |001F08;
MAIN_LOOP_read_tile_data_type_byte_from_ptr_028DFD:
    LDA.B [CompressedTilesetPtr]                                        ;028DFD|A704    |001F04; read a byte from pointer
    INC.B CompressedTilesetPtr                                          ;028DFF|E604    |001F04;
    BNE check_tile_data_MSB_028E06                                      ;028E01|D003    |028E06;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028E03|20699A  |029A69;
check_tile_data_MSB_028E06:
    CMP.B #$00                                                          ;028E06|C900    |      ; if MSB (bit 7) is set, branch to $028E77
    BMI case_MSB_0b1_go_to_029396_028E77                                ;028E08|306D    |028E77;
case_MSB_0b0_028E0A:
    BIT.B #$40                                                          ;028E0A|8940    |      ; if MSB clear and 2nd MSB (bit 6) set, branch to $028E7A
    BNE case_MSBs_0b01_go_to_028EFD_028E7A                              ;028E0C|D06C    |028E7A;
case_MSBs_0b00_028E0E:
    XBA                                                                 ;028E0E|EB      |      ; clear top half of accumulator
    LDA.B #$00                                                          ;028E0F|A900    |      ;
    XBA                                                                 ;028E11|EB      |      ;
    TAY                                                                 ;028E12|A8      |      ; Y <- whole 16-bit accumulator
    AND.B #$07                                                          ;028E13|2907    |      ; the 3 LSBs indicate where to jump to with the JMP below
    ASL A                                                               ;028E15|0A      |      ;
    TAX                                                                 ;028E16|AA      |      ;
    TYA                                                                 ;028E17|98      |      ; restore 16-bit accumulator
    JMP.W (JUMP_TABLE_MSBs_00_code_locations_028E1B,X)                  ;028E18|7C1B8E  |028E1B;

JUMP_TABLE_MSBs_00_code_locations_028E1B:
    dw case_byte_00xx_x000_028E2B                                       ;028E1B|        |028E2B; 028E2B = 00xx x000
    dw CODE_byte_00xx_x001_028E42                                       ;028E1D|        |028E42; 028E42 = 00xx x001
    dw CODE_byte_00xx_x010_029114                                       ;028E1F|        |029114; 029114 = 00xx x010
    dw CODE_byte_00xx_x011_0290D8                                       ;028E21|        |0290D8; 0290D8 = 00xx x011
    dw CODE_byte_00xx_x100_029119                                       ;028E23|        |029119; 029119 = 00xx x100
    dw CODE_byte_00xx_x101_0290DD                                       ;028E25|        |0290DD; 0290DD = 00xx x101
    dw CODE_byte_00xx_x110_02911E                                       ;028E27|        |02911E; 02911E = 00xx x110
    dw CODE_byte_00xx_x111_0290E2                                       ;028E29|        |0290E2; 0290E2 = 00xx x111

case_byte_00xx_x000_028E2B:
    LSR A                                                               ;028E2B|4A      |      ; use bits 3-4 of byte to get next value
    LSR A                                                               ;028E2C|4A      |      ;
    AND.B #$06                                                          ;028E2D|2906    |      ; ASM takes care of the "shift left for byte index"
    TAX                                                                 ;028E2F|AA      |      ;
    TYA                                                                 ;028E30|98      |      ;
    JMP.W (JUMP_TABLE_00xx_x000_code_locations_028E34,X)                ;028E31|7C348E  |028E34;
JUMP_TABLE_00xx_x000_code_locations_028E34:
    dw CODE_byte_00x0_0000_028E3C                                       ;028E34|        |028E3C; 028E3C = 00x0 0000
    dw case_00x0_1000_029021                                            ;028E36|        |029021; 029021 = 00x0 1000
    dw case_00x1_0000_02903B                                            ;028E38|        |02903B; 02903B = 00x1 0000
    dw case_00x1_1000_029055                                            ;028E3A|        |029055; 029055 = 00x1 1000

CODE_byte_00x0_0000_028E3C:
    CMP.B #$20                                                          ;028E3C|C920    |      ; check bit 5 of the byte
    BEQ case_0010_0000_get_0x20_bytes_raw_tile_028E5D                   ;028E3E|F01D    |028E5D; if bit 5 is 1, branch to $028E5D below
PLP_RTL_byte_0000_0000_028E40:
    PLP                                                                 ;028E40|28      |      ; if bit 5 is 0, end of data
    RTL                                                                 ;028E41|6B      |      ;

CODE_byte_00xx_x001_028E42:
    BIT.B #$08                                                          ;028E42|8908    |      ; if got LSBs 001, check bit 3
    BNE case_00xx_1001_reuse_prev_tile_and_fill_in_new_rows_028E7D      ;028E44|D037    |028E7D; if bit 3 is 1, branch down to $028E7D
case_byte_00xx_0001_028E46:
    LSR A                                                               ;028E46|4A      |      ; if bit 3 is 0, take bits 4-5 (6-7 assumed to be 0 here)
    LSR A                                                               ;028E47|4A      |      ;
    LSR A                                                               ;028E48|4A      |      ;
    LSR A                                                               ;028E49|4A      |      ;
    TAX                                                                 ;028E4A|AA      |      ;
    LDA.W tile_metadata_common_bitplane_combinations,X                  ;028E4B|BDE5F6  |7EF6E5; construct a 3 byte value in $0B-$0D from data in $7?F6E5, E9, ED
    STA.B $0B                                                           ;028E4E|850B    |001F0B;
    LDA.W tile_metadata_common_bitplane_combinations+4,X                ;028E50|BDE9F6  |7EF6E9;
    STA.B $0C                                                           ;028E53|850C    |001F0C;
    LDA.W tile_metadata_common_bitplane_combinations+8,X                ;028E55|BDEDF6  |7EF6ED;
    STA.B $0D                                                           ;028E58|850D    |001F0D;
    JMP.W CODE_get_1st_029422_sub_index_0293D4                          ;028E5A|4CD493  |0293D4; interpret the value here

case_0010_0000_get_0x20_bytes_raw_tile_028E5D:
    LDY.B TilesetBufferCurrentOffset                                    ;028E5D|A407    |001F07; Y <- current offset to buffer at $7?8000
    LDX.W #$001F                                                        ;028E5F|A21F00  |      ;
LOOP_copy_raw_tile_028E62:
    LDA.B [CompressedTilesetPtr]                                        ;028E62|A704    |001F04; read 0x20 bytes from pointer directly into buffer at $7?8000
    INC.B CompressedTilesetPtr                                          ;028E64|E604    |001F04;
    BNE +                                                               ;028E66|D003    |028E6B;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028E68|20699A  |029A69;
  + STA.W TilesetBuffer,Y                                               ;028E6B|990080  |7E8000;
    INY                                                                 ;028E6E|C8      |      ;
    DEX                                                                 ;028E6F|CA      |      ;
    BPL LOOP_copy_raw_tile_028E62                                       ;028E70|10F0    |028E62;
    STY.B TilesetBufferCurrentOffset                                    ;028E72|8407    |001F07;
    JMP.W MAIN_LOOP_read_tile_data_type_byte_from_ptr_028DFD            ;028E74|4CFD8D  |028DFD;

case_MSB_0b1_go_to_029396_028E77:
    JMP.W case_MSBs_0b1_029396                                          ;028E77|4C9693  |029396;

case_MSBs_0b01_go_to_028EFD_028E7A:
    JMP.W case_MSBs_0b01_028EFD                                         ;028E7A|4CFD8E  |028EFD;

case_00xx_1001_reuse_prev_tile_and_fill_in_new_rows_028E7D:
    AND.B #$30                                                          ;028E7D|2930    |      ; isolate bits 4-5 of the byte; can be either 00, 10, 20, 30
    ASL A                                                               ;028E7F|0A      |      ;
    STA.B $01                                                           ;028E80|8501    |001F01; construct either 0000, 2000, 4000, 6000 in $00-$01
    STZ.B $00                                                           ;028E82|6400    |001F00;
    LDA.B [CompressedTilesetPtr]                                        ;028E84|A704    |001F04; read a byte, call it B0, from pointer
    INC.B CompressedTilesetPtr                                          ;028E86|E604    |001F04;
    BNE +                                                               ;028E88|D003    |028E8D;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028E8A|20699A  |029A69;
  + XBA                                                                 ;028E8D|EB      |      ; put B0 in top half of A
    REP #$20                                                            ;028E8E|C220    |      ; NOTE: be careful with the M flag here!
    LSR A                                                               ;028E90|4A      |      ; X <- [(B0 << 5) | (0000 - 6000 from above)] + (offset from $7x8000, either 0000 or 4000)
    LSR A                                                               ;028E91|4A      |      ; this points to previous tile data to be read
    LSR A                                                               ;028E92|4A      |      ;
    ORA.B $00                                                           ;028E93|0500    |001F00;
    CLC                                                                 ;028E95|18      |      ;
    ADC.B TilesetBufferStartOffset                                      ;028E96|6509    |001F09;
    TAX                                                                 ;028E98|AA      |      ;
    SEP #$20                                                            ;028E99|E220    |      ;
    LDA.B [CompressedTilesetPtr]                                        ;028E9B|A704    |001F04; $00 <- next byte containing bit flags
    INC.B CompressedTilesetPtr                                          ;028E9D|E604    |001F04;
    BNE +                                                               ;028E9F|D003    |028EA4;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028EA1|20699A  |029A69;
  + STA.B $00                                                           ;028EA4|8500    |001F00;
    LDA.B #$07                                                          ;028EA6|A907    |      ; loop counter of 8
    STA.B $01                                                           ;028EA8|8501    |001F01;
    LDY.B TilesetBufferCurrentOffset                                    ;028EAA|A407    |001F07; Y <- where to write next byte in $7?8000 buffer
LOOP_check_next_bit_028EAC:
    ASL.B $00                                                           ;028EAC|0600    |001F00; check bit flag (current MSB of $00)
    BCS case_read_four_new_bytes_028EC2                                 ;028EAE|B012    |028EC2;
case_copy_4_bytes_from_prev_tile_028EB0:
    REP #$20                                                            ;028EB0|C220    |      ; if 0, copy FOUR bytes from a previous tile in the buffer
    LDA.W TilesetBuffer,X                                               ;028EB2|BD0080  |7F8000;
    STA.W TilesetBuffer,Y                                               ;028EB5|990080  |7F8000;
    LDA.W TilesetBuffer+!BP2,X                                          ;028EB8|BD1080  |7F8010;
    STA.W TilesetBuffer+!BP2,Y                                          ;028EBB|991080  |7F8010;
    SEP #$20                                                            ;028EBE|E220    |      ;
    BRA CODE_adv_ptrs_check_if_tile_done_028EF2                         ;028EC0|8030    |028EF2;
case_read_four_new_bytes_028EC2:
    LDA.B [CompressedTilesetPtr]                                        ;028EC2|A704    |001F04; if 1, read a total of 4 bytes and store to buffer at $8000, $8001, $8010, $8011
    INC.B CompressedTilesetPtr                                          ;028EC4|E604    |001F04;
    BNE +                                                               ;028EC6|D003    |028ECB;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028EC8|20699A  |029A69;
  + STA.W TilesetBuffer,Y                                               ;028ECB|990080  |7F8000;
    LDA.B [CompressedTilesetPtr]                                        ;028ECE|A704    |001F04; read 2nd byte
    INC.B CompressedTilesetPtr                                          ;028ED0|E604    |001F04;
    BNE +                                                               ;028ED2|D003    |028ED7;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028ED4|20699A  |029A69;
  + STA.W TilesetBuffer+!BP1,Y                                          ;028ED7|990180  |7F8001;
    LDA.B [CompressedTilesetPtr]                                        ;028EDA|A704    |001F04; read 3rd byte
    INC.B CompressedTilesetPtr                                          ;028EDC|E604    |001F04;
    BNE +                                                               ;028EDE|D003    |028EE3;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028EE0|20699A  |029A69;
  + STA.W TilesetBuffer+!BP2,Y                                          ;028EE3|991080  |7F8010;
    LDA.B [CompressedTilesetPtr]                                        ;028EE6|A704    |001F04; read 4th byte
    INC.B CompressedTilesetPtr                                          ;028EE8|E604    |001F04;
    BNE +                                                               ;028EEA|D003    |028EEF;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028EEC|20699A  |029A69;
  + STA.W TilesetBuffer+!BP3,Y                                          ;028EEF|991180  |7F8011;
CODE_adv_ptrs_check_if_tile_done_028EF2:
    INX                                                                 ;028EF2|E8      |      ;
    INX                                                                 ;028EF3|E8      |      ;
    INY                                                                 ;028EF4|C8      |      ;
    INY                                                                 ;028EF5|C8      |      ;
    DEC.B $01                                                           ;028EF6|C601    |001F01;
    BPL LOOP_check_next_bit_028EAC                                      ;028EF8|10B2    |028EAC;
    JMP.W advance_offset_in_07_to_next_tile_028DF2                      ;028EFA|4CF28D  |028DF2;

case_MSBs_0b01_028EFD:
    STA.B $00                                                           ;028EFD|8500    |001F00; store type byte to $00
    ASL A                                                               ;028EFF|0A      |      ; store byte<<2 to $01 (shift out the top 0b01)
    ASL A                                                               ;028F00|0A      |      ;
    STA.B $01                                                           ;028F01|8501    |001F01;
    LDA.B $00                                                           ;028F03|A500    |001F00; keep (byte & 0x3) in top half of A
    AND.B #$03                                                          ;028F05|2903    |      ;
    XBA                                                                 ;028F07|EB      |      ;
    LDA.B [CompressedTilesetPtr]                                        ;028F08|A704    |001F04; read byte from pointer
    INC.B CompressedTilesetPtr                                          ;028F0A|E604    |001F04;
    BNE +                                                               ;028F0C|D003    |028F11;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028F0E|20699A  |029A69;
  + REP #$20                                                            ;028F11|C220    |      ;
    ASL A                                                               ;028F13|0A      |      ; X <- (16-bit value) << 5 + (offset from $7x8000, either 0000 or 4000)
    ASL A                                                               ;028F14|0A      |      ;
    ASL A                                                               ;028F15|0A      |      ;
    ASL A                                                               ;028F16|0A      |      ;
    ASL A                                                               ;028F17|0A      |      ;
    CLC                                                                 ;028F18|18      |      ;
    ADC.B TilesetBufferStartOffset                                      ;028F19|6509    |001F09;
    TAX                                                                 ;028F1B|AA      |      ;
    LDY.B TilesetBufferCurrentOffset                                    ;028F1C|A407    |001F07;
    LDA.W TilesetBuffer+$00,X                                           ;028F1E|BD0080  |7E8000; copy an entire 4bpp tile from one place to another
    STA.W TilesetBuffer+$00,Y                                           ;028F21|990080  |7E8000;
    LDA.W TilesetBuffer+$02,X                                           ;028F24|BD0280  |7E8002;
    STA.W TilesetBuffer+$02,Y                                           ;028F27|990280  |7E8002;
    LDA.W TilesetBuffer+$04,X                                           ;028F2A|BD0480  |7E8004;
    STA.W TilesetBuffer+$04,Y                                           ;028F2D|990480  |7E8004;
    LDA.W TilesetBuffer+$06,X                                           ;028F30|BD0680  |7E8006;
    STA.W TilesetBuffer+$06,Y                                           ;028F33|990680  |7E8006;
    LDA.W TilesetBuffer+$08,X                                           ;028F36|BD0880  |7E8008;
    STA.W TilesetBuffer+$08,Y                                           ;028F39|990880  |7E8008;
    LDA.W TilesetBuffer+$0A,X                                           ;028F3C|BD0A80  |7E800A;
    STA.W TilesetBuffer+$0A,Y                                           ;028F3F|990A80  |7E800A;
    LDA.W TilesetBuffer+$0C,X                                           ;028F42|BD0C80  |7E800C;
    STA.W TilesetBuffer+$0C,Y                                           ;028F45|990C80  |7E800C;
    LDA.W TilesetBuffer+$0E,X                                           ;028F48|BD0E80  |7E800E;
    STA.W TilesetBuffer+$0E,Y                                           ;028F4B|990E80  |7E800E;
    LDA.W TilesetBuffer+$10,X                                           ;028F4E|BD1080  |7E8010;
    STA.W TilesetBuffer+$10,Y                                           ;028F51|991080  |7E8010;
    LDA.W TilesetBuffer+$12,X                                           ;028F54|BD1280  |7E8012;
    STA.W TilesetBuffer+$12,Y                                           ;028F57|991280  |7E8012;
    LDA.W TilesetBuffer+$14,X                                           ;028F5A|BD1480  |7E8014;
    STA.W TilesetBuffer+$14,Y                                           ;028F5D|991480  |7E8014;
    LDA.W TilesetBuffer+$16,X                                           ;028F60|BD1680  |7E8016;
    STA.W TilesetBuffer+$16,Y                                           ;028F63|991680  |7E8016;
    LDA.W TilesetBuffer+$18,X                                           ;028F66|BD1880  |7E8018;
    STA.W TilesetBuffer+$18,Y                                           ;028F69|991880  |7E8018;
    LDA.W TilesetBuffer+$1A,X                                           ;028F6C|BD1A80  |7E801A;
    STA.W TilesetBuffer+$1A,Y                                           ;028F6F|991A80  |7E801A;
    LDA.W TilesetBuffer+$1C,X                                           ;028F72|BD1C80  |7E801C;
    STA.W TilesetBuffer+$1C,Y                                           ;028F75|991C80  |7E801C;
    LDA.W TilesetBuffer+$1E,X                                           ;028F78|BD1E80  |7E801E;
    STA.W TilesetBuffer+$1E,Y                                           ;028F7B|991E80  |7E801E;
    STZ.B $0B                                                           ;028F7E|640B    |001F0B; zero out $0B-$0E
    STZ.B $0D                                                           ;028F80|640D    |001F0D;
    SEP #$20                                                            ;028F82|E220    |      ;
check_for_0B_028F84:
    ASL.B $01                                                           ;028F84|0601    |001F01;
    BCC check_for_0C_028F93                                             ;028F86|900B    |028F93;
case_read_byte_into_0B_028F88:
    LDA.B [CompressedTilesetPtr]                                        ;028F88|A704    |001F04;
    INC.B CompressedTilesetPtr                                          ;028F8A|E604    |001F04;
    BNE +                                                               ;028F8C|D003    |028F91;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028F8E|20699A  |029A69;
  + STA.B $0B                                                           ;028F91|850B    |001F0B;
check_for_0C_028F93:
    ASL.B $01                                                           ;028F93|0601    |001F01;
    BCC check_for_0D_028FA2                                             ;028F95|900B    |028FA2;
case_read_byte_into_0C_028F97:
    LDA.B [CompressedTilesetPtr]                                        ;028F97|A704    |001F04;
    INC.B CompressedTilesetPtr                                          ;028F99|E604    |001F04;
    BNE +                                                               ;028F9B|D003    |028FA0;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028F9D|20699A  |029A69;
  + STA.B $0C                                                           ;028FA0|850C    |001F0C;
check_for_0D_028FA2:
    ASL.B $01                                                           ;028FA2|0601    |001F01;
    BCC check_for_0E_028FB1                                             ;028FA4|900B    |028FB1;
case_read_byte_into_0D_028FA6:
    LDA.B [CompressedTilesetPtr]                                        ;028FA6|A704    |001F04;
    INC.B CompressedTilesetPtr                                          ;028FA8|E604    |001F04;
    BNE +                                                               ;028FAA|D003    |028FAF;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028FAC|20699A  |029A69;
  + STA.B $0D                                                           ;028FAF|850D    |001F0D;
check_for_0E_028FB1:
    ASL.B $01                                                           ;028FB1|0601    |001F01;
    BCC +                                                               ;028FB3|900B    |028FC0;
case_read_byte_into_0E_028FB5:
    LDA.B [CompressedTilesetPtr]                                        ;028FB5|A704    |001F04;
    INC.B CompressedTilesetPtr                                          ;028FB7|E604    |001F04;
    BNE ++                                                              ;028FB9|D003    |028FBE;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028FBB|20699A  |029A69;
 ++ STA.B $0E                                                           ;028FBE|850E    |001F0E;
  + DEY                                                                 ;028FC0|88      |      ; X <- Y <- Y - 2
    DEY                                                                 ;028FC1|88      |      ;
    TYX                                                                 ;028FC2|BB      |      ;
LOOP_read_bytes_using_0B_028FC3:
    INY                                                                 ;028FC3|C8      |      ; go forward two bytes at a time
    INY                                                                 ;028FC4|C8      |      ;
    ASL.B $0B                                                           ;028FC5|060B    |001F0B; use the bits of $0B to read in bytes from pointer into bitplane 0
    BCC +                                                               ;028FC7|900E    |028FD7;
    LDA.B [CompressedTilesetPtr]                                        ;028FC9|A704    |001F04;
    INC.B CompressedTilesetPtr                                          ;028FCB|E604    |001F04;
    BNE ++                                                              ;028FCD|D003    |028FD2;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028FCF|20699A  |029A69;
 ++ STA.W TilesetBuffer,Y                                               ;028FD2|990080  |7E8000;
    BRA LOOP_read_bytes_using_0B_028FC3                                 ;028FD5|80EC    |028FC3;
  + BNE LOOP_read_bytes_using_0B_028FC3                                 ;028FD7|D0EA    |028FC3; here, shifted out a 0; check if rest of buffer is 0
    TXY                                                                 ;028FD9|9B      |      ; get back old offset from before start of loop
LOOP_read_bytes_using_0C_028FDA:
    INY                                                                 ;028FDA|C8      |      ; repeat the process but using $0C for bitplane 1
    INY                                                                 ;028FDB|C8      |      ;
    ASL.B $0C                                                           ;028FDC|060C    |001F0C;
    BCC +                                                               ;028FDE|900E    |028FEE;
    LDA.B [CompressedTilesetPtr]                                        ;028FE0|A704    |001F04;
    INC.B CompressedTilesetPtr                                          ;028FE2|E604    |001F04;
    BNE ++                                                              ;028FE4|D003    |028FE9;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028FE6|20699A  |029A69;
 ++ STA.W TilesetBuffer+!BP1,Y                                          ;028FE9|990180  |7E8001;
    BRA LOOP_read_bytes_using_0C_028FDA                                 ;028FEC|80EC    |028FDA;
  + BNE LOOP_read_bytes_using_0C_028FDA                                 ;028FEE|D0EA    |028FDA;
    TXY                                                                 ;028FF0|9B      |      ;
LOOP_read_bytes_using_0D_028FF1:
    INY                                                                 ;028FF1|C8      |      ; repeat process but using bits of $0D for bitplane 2
    INY                                                                 ;028FF2|C8      |      ;
    ASL.B $0D                                                           ;028FF3|060D    |001F0D;
    BCC +                                                               ;028FF5|900E    |029005;
    LDA.B [CompressedTilesetPtr]                                        ;028FF7|A704    |001F04;
    INC.B CompressedTilesetPtr                                          ;028FF9|E604    |001F04;
    BNE ++                                                              ;028FFB|D003    |029000;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;028FFD|20699A  |029A69;
 ++ STA.W TilesetBuffer+!BP2,Y                                          ;029000|991080  |7E8010;
    BRA LOOP_read_bytes_using_0D_028FF1                                 ;029003|80EC    |028FF1;
  + BNE LOOP_read_bytes_using_0D_028FF1                                 ;029005|D0EA    |028FF1;
    TXY                                                                 ;029007|9B      |      ;
LOOP_read_bytes_using_0E_029008:
    INY                                                                 ;029008|C8      |      ; repeat process but using bits of $0E for bitplane 3
    INY                                                                 ;029009|C8      |      ;
    ASL.B $0E                                                           ;02900A|060E    |001F0E;
    BCC +                                                               ;02900C|900E    |02901C;
    LDA.B [CompressedTilesetPtr]                                        ;02900E|A704    |001F04;
    INC.B CompressedTilesetPtr                                          ;029010|E604    |001F04;
    BNE ++                                                              ;029012|D003    |029017;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029014|20699A  |029A69;
 ++ STA.W TilesetBuffer+!BP3,Y                                          ;029017|991180  |7E8011;
    BRA LOOP_read_bytes_using_0E_029008                                 ;02901A|80EC    |029008;
  + BNE LOOP_read_bytes_using_0E_029008                                 ;02901C|D0EA    |029008;
    JMP.W advance_offset_in_07_to_next_tile_028DF2                      ;02901E|4CF28D  |028DF2;

case_00x0_1000_029021:
    STA.B $00                                                           ;029021|8500    |001F00; store "type byte" to $00
    LDA.B [CompressedTilesetPtr]                                        ;029023|A704    |001F04; push next byte from pointer - bit flags for loop below at $02907D
    INC.B CompressedTilesetPtr                                          ;029025|E604    |001F04;
    BNE +                                                               ;029027|D003    |02902C;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029029|20699A  |029A69;
  + PHA                                                                 ;02902C|48      |      ;
    LDA.B $00                                                           ;02902D|A500    |001F00; check bit 5 of type byte
    BIT.B #$20                                                          ;02902F|8920    |      ;
    BEQ call_02925E_with_X_0000_and_run_029075                          ;029031|F03C    |02906F;
case_0010_1000_029033:
    LDX.W #$0000                                                        ;029033|A20000  |      ;
    JSR.W get_8_bitmask_bytes_with_pseudo_RLE_format_029277             ;029036|207792  |029277; call $029277 with X=0000
    BRA CODE_029075                                                     ;029039|803A    |029075;

case_00x1_0000_02903B:
    STA.B $00                                                           ;02903B|8500    |001F00;
    LDA.B [CompressedTilesetPtr]                                        ;02903D|A704    |001F04; push next byte from pointer - bit flags for loop below at $02907D
    INC.B CompressedTilesetPtr                                          ;02903F|E604    |001F04;
    BNE ++                                                              ;029041|D003    |029046;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029043|20699A  |029A69;
 ++ PHA                                                                 ;029046|48      |      ;
    LDA.B $00                                                           ;029047|A500    |001F00; check bit 5 of type byte
    BIT.B #$20                                                          ;029049|8920    |      ;
    BEQ call_02925E_with_X_0000_and_run_029075                          ;02904B|F022    |02906F;
case_0011_0000_02904D:
    LDX.W #$0000                                                        ;02904D|A20000  |      ;
    JSR.W get_8_bitmask_bytes_from_seq_of_3_or_4_unique_bytes_0292A8    ;029050|20A892  |0292A8; call $0292A8 with X = 0000
    BRA CODE_029075                                                     ;029053|8020    |029075;

case_00x1_1000_029055:
    STA.B $00                                                           ;029055|8500    |001F00; store type byte to $00
    LDA.B [CompressedTilesetPtr]                                        ;029057|A704    |001F04; push next byte from pointer - bit flags for loop below at $02907D
    INC.B CompressedTilesetPtr                                          ;029059|E604    |001F04;
    BNE ++                                                              ;02905B|D003    |029060;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;02905D|20699A  |029A69;
 ++ PHA                                                                 ;029060|48      |      ;
    LDA.B $00                                                           ;029061|A500    |001F00;
    BIT.B #$20                                                          ;029063|8920    |      ; check bit 5 of type byte
    BEQ call_02925E_with_X_0000_and_run_029075                          ;029065|F008    |02906F;
case_0011_1000_029067:
    LDX.W #$0000                                                        ;029067|A20000  |      ;
    JSR.W get_8_bitmask_bytes_from_seq_of_8_unique_nibbles_029305       ;02906A|200593  |029305; call $029305 with X=0000
    BRA CODE_029075                                                     ;02906D|8006    |029075;

call_02925E_with_X_0000_and_run_029075:
    LDX.W #$0000                                                        ;02906F|A20000  |      ; fill up buffers at $7?F69A and $7?F6B2
    JSR.W read_8_bytes_store_to_7xF69A_negs_to_7xF6B2                   ;029072|205E92  |02925E;
CODE_029075:
    PLA                                                                 ;029075|68      |      ; get back byte read at either $029023, $02903D, or $029057
    STA.B $00                                                           ;029076|8500    |001F00;
    LDX.B TilesetBufferCurrentOffset                                    ;029078|A607    |001F07; X <- offset for start of tile
    LDY.W #$0000                                                        ;02907A|A00000  |      ;
LOOP_02907D:
    LDA.B $00                                                           ;02907D|A500    |001F00; copy pulled byte
    STA.B $01                                                           ;02907F|8501    |001F01;

    LDA.B #$00                                                          ;029081|A900    |      ; start with 0x00
    LSR.B $01                                                           ;029083|4601    |001F01; check bit flags of the copy of the pulled byte
    BCC +                                                               ;029085|9003    |02908A; if 1, use data byte
    LDA.W LIST_bitmask_group_0,Y                                        ;029087|B99AF6  |7EF69A; if 0, keep the 0x00 byte
  + LSR.B $01                                                           ;02908A|4601    |001F01; check next bit flag
    BCC +                                                               ;02908C|9003    |029091; if 1, OR in the bitwise NOT version of the byte
    ORA.W LIST_bitmask_group_0_INVERT,Y                                 ;02908E|19B2F6  |7EF6B2; if 0, keep the byte as-is from whatever it is at $02908A
  + STA.W TilesetBuffer+$00,X                                           ;029091|9D0080  |7E8000; store result to tile buffer

    LDA.B #$00                                                          ;029094|A900    |      ; repeat the process four times for each tile
    LSR.B $01                                                           ;029096|4601    |001F01; to summarize cases for bit flags:
    BCC +                                                               ;029098|9003    |02909D; 0b00 -> write [00]
    LDA.W LIST_bitmask_group_0,Y                                        ;02909A|B99AF6  |7EF69A; 0b01 -> write [byte]
  + LSR.B $01                                                           ;02909D|4601    |001F01; 0b10 -> write [~byte]
    BCC +                                                               ;02909F|9003    |0290A4; 0b11 -> write [FF]
    ORA.W LIST_bitmask_group_0_INVERT,Y                                 ;0290A1|19B2F6  |7EF6B2;
  + STA.W TilesetBuffer+$01,X                                           ;0290A4|9D0180  |7E8001;

    LDA.B #$00                                                          ;0290A7|A900    |      ;
    LSR.B $01                                                           ;0290A9|4601    |001F01;
    BCC +                                                               ;0290AB|9003    |0290B0;
    LDA.W LIST_bitmask_group_0,Y                                        ;0290AD|B99AF6  |7EF69A;
  + LSR.B $01                                                           ;0290B0|4601    |001F01;
    BCC +                                                               ;0290B2|9003    |0290B7;
    ORA.W LIST_bitmask_group_0_INVERT,Y                                 ;0290B4|19B2F6  |7EF6B2;
  + STA.W TilesetBuffer+$10,X                                           ;0290B7|9D1080  |7E8010;

    LDA.B #$00                                                          ;0290BA|A900    |      ;
    LSR.B $01                                                           ;0290BC|4601    |001F01;
    BCC +                                                               ;0290BE|9003    |0290C3;
    LDA.W LIST_bitmask_group_0,Y                                        ;0290C0|B99AF6  |7EF69A;
  + LSR.B $01                                                           ;0290C3|4601    |001F01;
    BCC +                                                               ;0290C5|9003    |0290CA;
    ORA.W LIST_bitmask_group_0_INVERT,Y                                 ;0290C7|19B2F6  |7EF6B2;
  + STA.W TilesetBuffer+$11,X                                           ;0290CA|9D1180  |7E8011;

    INX                                                                 ;0290CD|E8      |      ; go to next row in tile
    INX                                                                 ;0290CE|E8      |      ;
    INY                                                                 ;0290CF|C8      |      ; use next byte in list at F69A/F6B2
    CPY.W #$0008                                                        ;0290D0|C00800  |      ;
    BNE LOOP_02907D                                                     ;0290D3|D0A8    |02907D;
    JMP.W advance_offset_in_07_to_next_tile_028DF2                      ;0290D5|4CF28D  |028DF2;

CODE_byte_00xx_x011_0290D8:
    LDY.W #get_8_bitmask_bytes_with_pseudo_RLE_format_029277-1          ;0290D8|A07692  |      ;
    BRA store_Y_to_F6E3_0290E5                                          ;0290DB|8008    |0290E5;
CODE_byte_00xx_x101_0290DD:
    LDY.W #get_8_bitmask_bytes_from_seq_of_3_or_4_unique_bytes_0292A8-1 ;0290DD|A0A792  |      ;
    BRA store_Y_to_F6E3_0290E5                                          ;0290E0|8003    |0290E5;
CODE_byte_00xx_x111_0290E2:
    LDY.W #get_8_bitmask_bytes_from_seq_of_8_unique_nibbles_029305-1    ;0290E2|A00493  |      ;
store_Y_to_F6E3_0290E5:
    STY.W PTR_subroutine_for_reading_bitmask_data                       ;0290E5|8CE3F6  |7EF6E3;
    ASL A                                                               ;0290E8|0A      |      ; $0B <- type byte << 2
    ASL A                                                               ;0290E9|0A      |      ;
    STA.B $0B                                                           ;0290EA|850B    |001F0B;
    LDA.B #$00                                                          ;0290EC|A900    |      ; clear out top byte of accumulator
    XBA                                                                 ;0290EE|EB      |      ;
    LDA.B [CompressedTilesetPtr]                                        ;0290EF|A704    |001F04; $01 <- next byte from pointer
    INC.B CompressedTilesetPtr                                          ;0290F1|E604    |001F04;
    BNE +                                                               ;0290F3|D003    |0290F8;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0290F5|20699A  |029A69;
  + STA.B $01                                                           ;0290F8|8501    |001F01;
    LSR A                                                               ;0290FA|4A      |      ; if top 4 bits of pointer byte are not 0, use it as index to data from $7?F6F0-F6FF
    LSR A                                                               ;0290FB|4A      |      ;
    LSR A                                                               ;0290FC|4A      |      ;
    LSR A                                                               ;0290FD|4A      |      ;
    BEQ +                                                               ;0290FE|F004    |029104; otherwise, just keep the 0
    TAX                                                                 ;029100|AA      |      ;
    LDA.W tile_metadata_common_bitmask_combinations-1,X                 ;029101|BDF0F6  |7EF6F0;
  + STA.B $00                                                           ;029104|8500    |001F00; store the result of two above comments to $00
    LDA.B $01                                                           ;029106|A501    |001F01; get the low 4 bits of pointer byte
    AND.B #$0F                                                          ;029108|290F    |      ; also use them to either get a byte from $F6F0-$F6FF, or just 0
    BEQ +                                                               ;02910A|F004    |029110;
    TAX                                                                 ;02910C|AA      |      ;
    LDA.W tile_metadata_common_bitmask_combinations-1,X                 ;02910D|BDF0F6  |7EF6F0;
  + STA.B $01                                                           ;029110|8501    |001F01;
    BRA CODE_fill_0x20_bytes_with_00_02913E                             ;029112|802A    |02913E;

CODE_byte_00xx_x010_029114:
    LDY.W #get_8_bitmask_bytes_with_pseudo_RLE_format_029277-1          ;029114|A07692  |      ; these three options are very close to above, but without the "read from $F6F0 range"
    BRA store_Y_to_F6E3_029121                                          ;029117|8008    |029121;
CODE_byte_00xx_x100_029119:
    LDY.W #get_8_bitmask_bytes_from_seq_of_3_or_4_unique_bytes_0292A8-1 ;029119|A0A792  |      ;
    BRA store_Y_to_F6E3_029121                                          ;02911C|8003    |029121;
CODE_byte_00xx_x110_02911E:
    LDY.W #get_8_bitmask_bytes_from_seq_of_8_unique_nibbles_029305-1    ;02911E|A00493  |      ;
store_Y_to_F6E3_029121:
    STY.W PTR_subroutine_for_reading_bitmask_data                       ;029121|8CE3F6  |7EF6E3;
    ASL A                                                               ;029124|0A      |      ; $0B <- type byte << 2
    ASL A                                                               ;029125|0A      |      ;
    STA.B $0B                                                           ;029126|850B    |001F0B;
    LDA.B [CompressedTilesetPtr]                                        ;029128|A704    |001F04; $00 <- next byte from pointer
    INC.B CompressedTilesetPtr                                          ;02912A|E604    |001F04;
    BNE ++                                                              ;02912C|D003    |029131;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;02912E|20699A  |029A69;
 ++ STA.B $00                                                           ;029131|8500    |001F00;
    LDA.B [CompressedTilesetPtr]                                        ;029133|A704    |001F04; $01 <- next byte from pointer
    INC.B CompressedTilesetPtr                                          ;029135|E604    |001F04;
    BNE ++                                                              ;029137|D003    |02913C;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029139|20699A  |029A69;
 ++ STA.B $01                                                           ;02913C|8501    |001F01;
CODE_fill_0x20_bytes_with_00_02913E:
    REP #$20                                                            ;02913E|C220    |      ;
    LDY.W #$000F                                                        ;029140|A00F00  |      ; fill 0x20 bytes in $7?8000 buffer with 00 at start of current tile
    LDX.B TilesetBufferCurrentOffset                                    ;029143|A607    |001F07;
LOOP_029145:
    STZ.W TilesetBuffer,X                                               ;029145|9E0080  |7E8000;
    INX                                                                 ;029148|E8      |      ;
    INX                                                                 ;029149|E8      |      ;
    DEY                                                                 ;02914A|88      |      ;
    BPL LOOP_029145                                                     ;02914B|10F8    |029145;
    LDX.W #$0000                                                        ;02914D|A20000  |      ; write a list of bytes with the positions of all the 1 bits in the $00-$01 buffer
    TXA                                                                 ;029150|8A      |      ; count up from MSB to LSB (e.g. 1A40 -> [03 04 06 08 FF])
LOOP_write_list_of_bits_with_1_029151:
    ASL.B $00                                                           ;029151|0600    |001F00; left shift buffer in $00-$01
    BEQ case_last_write_to_list_02915E                                  ;029153|F009    |02915E; if state of buffer is now 0x0000, this will be the last store to space in $F6D2
    BCC case_inc_bit_counter_02915B                                     ;029155|9004    |02915B; write bit position if shifted out a 1
case_store_bit_position_029157:
    STA.W LIST_bit_positions_of_1_bits_bank_7E,X                        ;029157|9DD2F6  |7EF6D2;
    INX                                                                 ;02915A|E8      |      ;
case_inc_bit_counter_02915B:
    INC A                                                               ;02915B|1A      |      ;
    BRA LOOP_write_list_of_bits_with_1_029151                           ;02915C|80F3    |029151;
case_last_write_to_list_02915E:
    BCC write_FF_terminator_029164                                      ;02915E|9004    |029164; write last bit position to space if needed (initial state may be 0x0000 -> empty list)
    STA.W LIST_bit_positions_of_1_bits_bank_7E,X                        ;029160|9DD2F6  |7EF6D2;
    INX                                                                 ;029163|E8      |      ;
write_FF_terminator_029164:
    SEP #$20                                                            ;029164|E220    |      ; next, write an FF terminator byte
    LDA.B #$FF                                                          ;029166|A9FF    |      ;
    STA.W LIST_bit_positions_of_1_bits_bank_7E,X                        ;029168|9DD2F6  |7EF6D2;
    LDA.B #$02                                                          ;02916B|A902    |      ; $0C <- 0x02
    STA.B $0C                                                           ;02916D|850C    |001F0C;
    STX.B $0D                                                           ;02916F|860D    |001F0D; $0D <- size of the list
    LDX.W #$0000                                                        ;029171|A20000  |      ; zero out both X and low byte of A
    TXA                                                                 ;029174|8A      |      ; $0B starts with (type byte << 2)
LOOP_029175:
    ASL.B $0B                                                           ;029175|060B    |001F0B; left shift out a bit in $0B
    BCC case_shifted_out_0_029181                                       ;029177|9008    |029181;
case_shifted_out_1_029179:
    PEA.W CODE_029184-1                                                 ;029179|F48391  |7E9183; if shifted out a 1, we are done; push [83 91]
    LDY.W PTR_subroutine_for_reading_bitmask_data                       ;02917C|ACE3F6  |7EF6E3; this is saying, "run the subroutine pointed to in $7?F6E3...
    PHY                                                                 ;02917F|5A      |      ; ...then return to $029184 when subroutine finishes"
    RTS                                                                 ;029180|60      |      ;
case_shifted_out_0_029181:
    JSR.W read_8_bytes_store_to_7xF69A_negs_to_7xF6B2                   ;029181|205E92  |02925E;
CODE_029184:
    DEC.B $0C                                                           ;029184|C60C    |001F0C; decrement $0C from $02916B
    BNE run_loop_again_if_more_bytes_029190                             ;029186|D008    |029190; if still more to go, check if positive
case_no_bytes_left_029188:
    LDA.B $0D                                                           ;029188|A50D    |001F0D; if none left, check size of list in $0D
    CMP.B #$05                                                          ;02918A|C905    |      ; if 5+ bytes, run the loop again
    BCS LOOP_029175                                                     ;02918C|B0E7    |029175;
    BRA case_done_with_under_5_bytes_029194                             ;02918E|8004    |029194;
run_loop_again_if_more_bytes_029190:
    BPL LOOP_029175                                                     ;029190|10E3    |029175; since possible to run loop when $0C is 0, need to check if $0C underflowed to FF
    BRA case_done_with_5_or_more_bytes_0291D1                           ;029192|803D    |0291D1; if yes, branch down; if no, do loop again
case_done_with_under_5_bytes_029194:
    STZ.B $00                                                           ;029194|6400    |001F00;
LOOP_check_list_of_byte_offsets_029196:
    LDA.B #$00                                                          ;029196|A900    |      ; clear out top byte of accumulator
    XBA                                                                 ;029198|EB      |      ;
    LDA.B $00                                                           ;029199|A500    |001F00; get list index
    TAX                                                                 ;02919B|AA      |      ;
    LDA.W LIST_bit_positions_of_1_bits_bank_7E,X                        ;02919C|BDD2F6  |7EF6D2; read a byte from the list of bytes generated at $029151
    BMI done_jmp_to_read_next_type_byte_0291CE                          ;02919F|302D    |0291CE; if got FF terminator, we are done
    STA.B $01                                                           ;0291A1|8501    |001F01; store byte position from list into $01
    LDX.W #$0007                                                        ;0291A3|A20700  |      ;
LOOP_0291C5:
    LDA.B $00                                                           ;0291A6|A500    |001F00; $02 <- (list position) >> 1
    LSR A                                                               ;0291A8|4A      |      ;
    STA.B $02                                                           ;0291A9|8502    |001F02;
    BCC case_0_use_F6B2_0291B2                                          ;0291AB|9005    |0291B2;
case_1_use_F69A_0291AD:
    LDA.W LIST_bitmask_group_0,X                                        ;0291AD|BD9AF6  |7EF69A; on odd iterations (equiv. to 1 or 3 mod 4), read from $7?F69A
    BRA +                                                               ;0291B0|8003    |0291B5;
case_0_use_F6B2_0291B2:
    LDA.W LIST_bitmask_group_0_INVERT,X                                 ;0291B2|BDB2F6  |7EF6B2; on even iterations (equiv. to 0 or 2 mod 4), read from $7?F6B2
  + LSR.B $02                                                           ;0291B5|4602    |001F02; shift out the next LSB from the list position
    BCC case_0x_use_F6BA_0291BE                                         ;0291B7|9005    |0291BE;
case_1x_use_F6A2_0291B9:
    AND.W LIST_bitmask_group_1,X                                        ;0291B9|3DA2F6  |7EF6A2; on "even pair iterations" (equiv. to 0 or 1 mod 4), use $F6A2
    BRA +                                                               ;0291BC|8003    |0291C1;
case_0x_use_F6BA_0291BE:
    AND.W LIST_bitmask_group_1_INVERT,X                                 ;0291BE|3DBAF6  |7EF6BA; on "odd pair iterations" (equiv. to 2 or 3 mod 4), use $F6BA
  + STA.W LIST_tile_bitmasks_F6CA_bank_7E,X                             ;0291C1|9DCAF6  |7EF6CA; store the result to $F6CA
    DEX                                                                 ;0291C4|CA      |      ; repeat for all 8 bytes
    BPL LOOP_0291C5                                                     ;0291C5|10DF    |0291A6;
    JSR.W SUB_modify_tile_with_data_at_F6CA                             ;0291C7|201892  |029218; once done, run this subroutine
    INC.B $00                                                           ;0291CA|E600    |001F00; look at the next byte in the list from $029151
    BRA LOOP_check_list_of_byte_offsets_029196                          ;0291CC|80C8    |029196;
done_jmp_to_read_next_type_byte_0291CE:
    JMP.W advance_offset_in_07_to_next_tile_028DF2                      ;0291CE|4CF28D  |028DF2;
case_done_with_5_or_more_bytes_0291D1:
    STZ.B $00                                                           ;0291D1|6400    |001F00;
CODE_0291D3:
    LDA.B #$00                                                          ;0291D3|A900    |      ; clear high byte of accumulator
    XBA                                                                 ;0291D5|EB      |      ;
    LDA.B $00                                                           ;0291D6|A500    |001F00; get list index, and read a bit position
    TAX                                                                 ;0291D8|AA      |      ;
    LDA.W LIST_bit_positions_of_1_bits_bank_7E,X                        ;0291D9|BDD2F6  |7EF6D2;
    BMI done_jmp_to_read_next_type_byte_0291CE                          ;0291DC|30F0    |0291CE; if got FF terminator, we are done
    STA.B $01                                                           ;0291DE|8501    |001F01; $01 <- bit position
    LDX.W #$0007                                                        ;0291E0|A20700  |      ; loop counter, 8 times
LOOP_0291E3:
    LDA.B $00                                                           ;0291E3|A500    |001F00; $02 <- list index >> 1
    LSR A                                                               ;0291E5|4A      |      ;
    STA.B $02                                                           ;0291E6|8502    |001F02;
    BCC case_0_use_F6B2_0291EF                                          ;0291E8|9005    |0291EF; check LSB that got shifted out
case_1_use_F69A_0291EA:
    LDA.W LIST_bitmask_group_0,X                                        ;0291EA|BD9AF6  |7EF69A; if 1 (1, 3, 5, 7 mod 8), read from $7xF69A
    BRA +                                                               ;0291ED|8003    |0291F2;
case_0_use_F6B2_0291EF:
    LDA.W LIST_bitmask_group_0_INVERT,X                                 ;0291EF|BDB2F6  |7EF6B2; if 0 (0. 2, 4, 6 mod 8), read from $7xF6B2
  + LSR.B $02                                                           ;0291F2|4602    |001F02; shift out another LSB and check it
    BCC case_0x_use_F6BA_0291FB                                         ;0291F4|9005    |0291FB;
case_1x_use_F6A2_0291F6:
    AND.W LIST_bitmask_group_1,X                                        ;0291F6|3DA2F6  |7EF6A2; if 1 (2, 3, 6, 7 mod 8), bitwise AND from $7xF6A2
    BRA +                                                               ;0291F9|8003    |0291FE;
case_0x_use_F6BA_0291FB:
    AND.W LIST_bitmask_group_1_INVERT,X                                 ;0291FB|3DBAF6  |7EF6BA; if 0 (0, 1, 4, 5 mod 8), bitwise AND from $7xF6BA
  + LSR.B $02                                                           ;0291FE|4602    |001F02; shift out yet another LSB and check it
    BCC case_0xx_use_F6C2_029207                                        ;029200|9005    |029207;
case_1xx_use_F6AA_029202:
    AND.W LIST_bitmask_group_2,X                                        ;029202|3DAAF6  |7EF6AA; if 1 (4, 5, 6, 7 mod 8), bitwise AND from $7xF6AA
    BRA +                                                               ;029205|8003    |02920A;
case_0xx_use_F6C2_029207:
    AND.W LIST_bitmask_group_2_INVERT,X                                 ;029207|3DC2F6  |7EF6C2; if 0 (0, 1, 2, 3 mod 8), bitwise AND from $7x6FC2
  + STA.W LIST_tile_bitmasks_F6CA_bank_7E,X                             ;02920A|9DCAF6  |7EF6CA; store the result to $7xF6CA
    DEX                                                                 ;02920D|CA      |      ; go to next element in 8 byte list if available
    BPL LOOP_0291E3                                                     ;02920E|10D3    |0291E3;
    JSR.W SUB_modify_tile_with_data_at_F6CA                             ;029210|201892  |029218; with whole 8 byte list done, modify tile
    INC.B $00                                                           ;029213|E600    |001F00; go to next "1" bit position if available
    JMP.W CODE_0291D3                                                   ;029215|4CD391  |0291D3;

SUB_modify_tile_with_data_at_F6CA:
    LDX.W #$0000                                                        ;029218|A20000  |      ;
    TXA                                                                 ;02921B|8A      |      ;
    LDY.B TilesetBufferCurrentOffset                                    ;02921C|A407    |001F07; get offset to start of tile
LOOP_02921E:
    LDA.B $01                                                           ;02921E|A501    |001F01; $02 <- (offset in list of offsets) >> 1
    LSR A                                                               ;029220|4A      |      ; note that here, $01 is essentially a series of bit flags for what parts of the tile to modify
    STA.B $02                                                           ;029221|8502    |001F02;
    BCC check_for_8001_02922E                                           ;029223|9009    |02922E; if shifted out 0, skip for $7?8000
case_modify_8000_029225:
    LDA.W LIST_tile_bitmasks_F6CA_bank_7E,X                             ;029225|BDCAF6  |7EF6CA; if shifted out 1, modify the tile using $F6CA as an OR bitmask
    ORA.W TilesetBuffer+!BP0,Y                                          ;029228|190080  |7E8000;
    STA.W TilesetBuffer+!BP0,Y                                          ;02922B|990080  |7E8000;
check_for_8001_02922E:
    LSR.B $02                                                           ;02922E|4602    |001F02;
    BCC check_for_8010_02923B                                           ;029230|9009    |02923B;
case_modify_8001_029232:
    LDA.W LIST_tile_bitmasks_F6CA_bank_7E,X                             ;029232|BDCAF6  |7EF6CA;
    ORA.W TilesetBuffer+!BP1,Y                                          ;029235|190180  |7E8001;
    STA.W TilesetBuffer+!BP1,Y                                          ;029238|990180  |7E8001;
check_for_8010_02923B:
    LSR.B $02                                                           ;02923B|4602    |001F02;
    BCC check_for_8011_029248                                           ;02923D|9009    |029248;
case_modify_8010_02923F:
    LDA.W LIST_tile_bitmasks_F6CA_bank_7E,X                             ;02923F|BDCAF6  |7EF6CA;
    ORA.W TilesetBuffer+!BP2,Y                                          ;029242|191080  |7E8010;
    STA.W TilesetBuffer+!BP2,Y                                          ;029245|991080  |7E8010;
check_for_8011_029248:
    LSR.B $02                                                           ;029248|4602    |001F02;
    BCC +                                                               ;02924A|9009    |029255;
case_modify_8011_02924C:
    LDA.W LIST_tile_bitmasks_F6CA_bank_7E,X                             ;02924C|BDCAF6  |7EF6CA;
    ORA.W TilesetBuffer+!BP3,Y                                          ;02924F|191180  |7E8011;
    STA.W TilesetBuffer+!BP3,Y                                          ;029252|991180  |7E8011;
  + INY                                                                 ;029255|C8      |      ; move to next tile, get next bitmask modifier
    INY                                                                 ;029256|C8      |      ;
    INX                                                                 ;029257|E8      |      ;
    CPX.W #$0008                                                        ;029258|E00800  |      ;
    BNE LOOP_02921E                                                     ;02925B|D0C1    |02921E;
    RTS                                                                 ;02925D|60      |      ;

read_8_bytes_store_to_7xF69A_negs_to_7xF6B2:
    LDY.W #$0007                                                        ;02925E|A00700  |      ; read 8 bytes
LOOP_029261:
    LDA.B [CompressedTilesetPtr]                                        ;029261|A704    |001F04; read a byte
    INC.B CompressedTilesetPtr                                          ;029263|E604    |001F04;
    BNE +                                                               ;029265|D003    |02926A;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029267|20699A  |029A69;
  + STA.W LIST_bitmask_group_0,X                                        ;02926A|9D9AF6  |7EF69A; store the bytes to buffer at $7?F69A
    EOR.B #$FF                                                          ;02926D|49FF    |      ; also store their inverses to corresponding buffer at $7?F6B2
    STA.W LIST_bitmask_group_0_INVERT,X                                 ;02926F|9DB2F6  |7EF6B2;
    INX                                                                 ;029272|E8      |      ;
    DEY                                                                 ;029273|88      |      ;
    BPL LOOP_029261                                                     ;029274|10EB    |029261;
    RTS                                                                 ;029276|60      |      ;

get_8_bitmask_bytes_with_pseudo_RLE_format_029277:
    LDY.W #$0007                                                        ;029277|A00700  |      ; execution also came here once after $029179 (loop counter of 8)
    LDA.B [CompressedTilesetPtr]                                        ;02927A|A704    |001F04; read byte from pointer
    INC.B CompressedTilesetPtr                                          ;02927C|E604    |001F04;
    BNE +                                                               ;02927E|D003    |029283;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029280|20699A  |029A69;
  + ASL A                                                               ;029283|0A      |      ; $00 <- byte << 1 = rest of bit flags
    STA.B $00                                                           ;029284|8500    |001F00;
    LDA.B #$00                                                          ;029286|A900    |      ; data byte <- 0
    BCC LOOP_store_byte_and_complement_029293                           ;029288|9009    |029293; if the ASL shifted out a 1, read another byte
read_byte_02928A:
    LDA.B [CompressedTilesetPtr]                                        ;02928A|A704    |001F04;
    INC.B CompressedTilesetPtr                                          ;02928C|E604    |001F04;
    BNE LOOP_store_byte_and_complement_029293                           ;02928E|D003    |029293;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029290|20699A  |029A69;
LOOP_store_byte_and_complement_029293:
    STA.W LIST_bitmask_group_0,X                                        ;029293|9D9AF6  |7EF69A; store data byte to $7?F69A
    EOR.B #$FF                                                          ;029296|49FF    |      ; store ~data byte to $7?F6B2
    STA.W LIST_bitmask_group_0_INVERT,X                                 ;029298|9DB2F6  |7EF6B2;
    EOR.B #$FF                                                          ;02929B|49FF    |      ;
    INX                                                                 ;02929D|E8      |      ;
    DEY                                                                 ;02929E|88      |      ;
    BMI RTS_0292A7                                                      ;02929F|3006    |0292A7;
    ASL.B $00                                                           ;0292A1|0600    |001F00; shift the byte left again
    BCS read_byte_02928A                                                ;0292A3|B0E5    |02928A; if shifted out a 1, read a byte
    BRA LOOP_store_byte_and_complement_029293                           ;0292A5|80EC    |029293; otherwise, store the same byte from this completed iteration again
RTS_0292A7:
    RTS                                                                 ;0292A7|60      |      ;

get_8_bitmask_bytes_from_seq_of_3_or_4_unique_bytes_0292A8:
    LDA.B [CompressedTilesetPtr]                                        ;0292A8|A704    |001F04; $01 <- read byte
    INC.B CompressedTilesetPtr                                          ;0292AA|E604    |001F04;
    BNE +                                                               ;0292AC|D003    |0292B1;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0292AE|20699A  |029A69;
  + STA.B $01                                                           ;0292B1|8501    |001F01;
    LDA.B [CompressedTilesetPtr]                                        ;0292B3|A704    |001F04; $00 <- read next byte
    INC.B CompressedTilesetPtr                                          ;0292B5|E604    |001F04;
    BNE +                                                               ;0292B7|D003    |0292BC;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0292B9|20699A  |029A69;
  + STA.B $00                                                           ;0292BC|8500    |001F00;
    LDY.W #$0004                                                        ;0292BE|A00400  |      ; check $00 & 0x3
    AND.B #$03                                                          ;0292C1|2903    |      ; if 0b00, Y <- 4
    BEQ +                                                               ;0292C3|F004    |0292C9;
case_clear_low_bits_of_00_0292C5:
    DEY                                                                 ;0292C5|88      |      ; otherwise, clear them anyway, and Y <- 3
    TYA                                                                 ;0292C6|98      |      ;
    TRB.B $00                                                           ;0292C7|1400    |001F00;
  + STY.B $02                                                           ;0292C9|8402    |001F02; $02 <- Y = loop counter
    LDY.W #$0000                                                        ;0292CB|A00000  |      ;
    TYA                                                                 ;0292CE|98      |      ;
LOOP_read_bytes_into_7xF6DB_0292CF:
    LDA.B [CompressedTilesetPtr]                                        ;0292CF|A704    |001F04; read byte from pointer and store to buffer at $7xF6DB
    INC.B CompressedTilesetPtr                                          ;0292D1|E604    |001F04;
    BNE +                                                               ;0292D3|D003    |0292D8;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0292D5|20699A  |029A69;
  + STA.W BUFFER_bitmask_contruction_data_F6DB,Y                        ;0292D8|99DBF6  |7EF6DB;
    INY                                                                 ;0292DB|C8      |      ;
    DEC.B $02                                                           ;0292DC|C602    |001F02;
    BNE LOOP_read_bytes_into_7xF6DB_0292CF                              ;0292DE|D0EF    |0292CF;
    LDA.B #$07                                                          ;0292E0|A907    |      ; $02 <- 0x7 = loop counter (8 times)
    STA.B $02                                                           ;0292E2|8502    |001F02;
LOOP_0292E4:
    LDA.B #$00                                                          ;0292E4|A900    |      ; clear top byte of accumulator
    XBA                                                                 ;0292E6|EB      |      ;
    LDA.B $00                                                           ;0292E7|A500    |001F00; Y <- two LSBs of $00
    AND.B #$03                                                          ;0292E9|2903    |      ;
    TAY                                                                 ;0292EB|A8      |      ;
    LDA.W BUFFER_bitmask_contruction_data_F6DB,Y                        ;0292EC|B9DBF6  |7EF6DB; directly store byte from here to buffer
    STA.W LIST_bitmask_group_0,X                                        ;0292EF|9D9AF6  |7EF69A;
    EOR.B #$FF                                                          ;0292F2|49FF    |      ; as well as the 1's complement of the byte = bitwise NOT
    STA.W LIST_bitmask_group_0_INVERT,X                                 ;0292F4|9DB2F6  |7EF6B2;
    LSR.B $01                                                           ;0292F7|4601    |001F01; right shift the 16-bit buffer in $00-$01 twice
    ROR.B $00                                                           ;0292F9|6600    |001F00;
    LSR.B $01                                                           ;0292FB|4601    |001F01;
    ROR.B $00                                                           ;0292FD|6600    |001F00;
    INX                                                                 ;0292FF|E8      |      ;
    DEC.B $02                                                           ;029300|C602    |001F02;
    BPL LOOP_0292E4                                                     ;029302|10E0    |0292E4;
    RTS                                                                 ;029304|60      |      ;

get_8_bitmask_bytes_from_seq_of_8_unique_nibbles_029305:
    LDY.W #$0003                                                        ;029305|A00300  |      ;
LOOP_read_four_bytes_into_7xF6DB_029308:
    LDA.B [CompressedTilesetPtr]                                        ;029308|A704    |001F04; read four bytes (16 2-bit indices) into $7xF6DB
    INC.B CompressedTilesetPtr                                          ;02930A|E604    |001F04;
    BNE +                                                               ;02930C|D003    |029311;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;02930E|20699A  |029A69;
  + STA.W BUFFER_bitmask_contruction_data_F6DB,Y                        ;029311|99DBF6  |7EF6DB;
    DEY                                                                 ;029314|88      |      ;
    BPL LOOP_read_four_bytes_into_7xF6DB_029308                         ;029315|10F1    |029308;
    LDA.B [CompressedTilesetPtr]                                        ;029317|A704    |001F04; read a byte
    INC.B CompressedTilesetPtr                                          ;029319|E604    |001F04;
    BNE +                                                               ;02931B|D003    |029320;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;02931D|20699A  |029A69;
  + PHA                                                                 ;029320|48      |      ;
    AND.B #$0F                                                          ;029321|290F    |      ; store its four low bits to $7xF6E0
    STA.W $F6E0                                                         ;029323|8DE0F6  |7EF6E0;
    PLA                                                                 ;029326|68      |      ; store its four high bits to $7xF6DF
    LSR A                                                               ;029327|4A      |      ;
    LSR A                                                               ;029328|4A      |      ;
    LSR A                                                               ;029329|4A      |      ;
    LSR A                                                               ;02932A|4A      |      ;
    STA.W $F6DF                                                         ;02932B|8DDFF6  |7EF6DF;
    LDA.B [CompressedTilesetPtr]                                        ;02932E|A704    |001F04; read another byte
    INC.B CompressedTilesetPtr                                          ;029330|E604    |001F04;
    BNE +                                                               ;029332|D003    |029337;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029334|20699A  |029A69;
  + PHA                                                                 ;029337|48      |      ;
    AND.B #$0F                                                          ;029338|290F    |      ; store the four low bits to $7xF6E2
    STA.W $F6E2                                                         ;02933A|8DE2F6  |7EF6E2;
    PLA                                                                 ;02933D|68      |      ; store the four high bits to $7xF6E1
    LSR A                                                               ;02933E|4A      |      ;
    LSR A                                                               ;02933F|4A      |      ;
    LSR A                                                               ;029340|4A      |      ;
    LSR A                                                               ;029341|4A      |      ;
    STA.W $F6E1                                                         ;029342|8DE1F6  |7EF6E1;
    LDA.B #$07                                                          ;029345|A907    |      ; $00 <- 7 = loop counter (8 times)
    STA.B $00                                                           ;029347|8500    |001F00;
    STZ.B $01                                                           ;029349|6401    |001F01; $01 <- 0, $02 <- 0 = "false"
    STZ.B $02                                                           ;02934B|6402    |001F02;
LOOP_02934D:
    LDA.B #$00                                                          ;02934D|A900    |      ; clear top byte of accumulator
    XBA                                                                 ;02934F|EB      |      ;
    LDA.B $01                                                           ;029350|A501    |001F01; Y <- $01
    TAY                                                                 ;029352|A8      |      ;
    LDA.W BUFFER_bitmask_contruction_data_F6DB,Y                        ;029353|B9DBF6  |7EF6DB; use Y to get a bitmask from $7xF6DB, and store it to $03
    STA.B $03                                                           ;029356|8503    |001F03;
    LSR A                                                               ;029358|4A      |      ; push ($03 >> 2)
    LSR A                                                               ;029359|4A      |      ;
    PHA                                                                 ;02935A|48      |      ;
    LSR A                                                               ;02935B|4A      |      ; $7xF6DB <- $03 >> 4
    LSR A                                                               ;02935C|4A      |      ;
    STA.W BUFFER_bitmask_contruction_data_F6DB,Y                        ;02935D|99DBF6  |7EF6DB;
    LDA.B $03                                                           ;029360|A503    |001F03; use two MSBs of $03 as index to $7xF6DF
    AND.B #$03                                                          ;029362|2903    |      ;
    TAY                                                                 ;029364|A8      |      ;
    LDA.W $F6DF,Y                                                       ;029365|B9DFF6  |7EF6DF;
    ASL A                                                               ;029368|0A      |      ; $03 <- (value from $7xF6DF) << 4
    ASL A                                                               ;029369|0A      |      ;
    ASL A                                                               ;02936A|0A      |      ;
    ASL A                                                               ;02936B|0A      |      ;
    STA.B $03                                                           ;02936C|8503    |001F03;
    LDA.B #$00                                                          ;02936E|A900    |      ; clear top byte of accumulator
    XBA                                                                 ;029370|EB      |      ;
    PLA                                                                 ;029371|68      |      ; get back the next two low MSBs (bits 2-3) of bitmask from above at $029353
    AND.B #$03                                                          ;029372|2903    |      ;
    TAY                                                                 ;029374|A8      |      ;
    LDA.W $F6DF,Y                                                       ;029375|B9DFF6  |7EF6DF; use as index to $7xF6DF
    ORA.B $03                                                           ;029378|0503    |001F03; bitwise OR this byte with the value in $03 from above at $029368
    STA.W LIST_bitmask_group_0,X                                        ;02937A|9D9AF6  |7EF69A; store result and its complement to here
    EOR.B #$FF                                                          ;02937D|49FF    |      ;
    STA.W LIST_bitmask_group_0_INVERT,X                                 ;02937F|9DB2F6  |7EF6B2;
    INX                                                                 ;029382|E8      |      ; advance pointer; RTS if no more bytes left
    DEC.B $00                                                           ;029383|C600    |001F00;
    BMI RTS_029395                                                      ;029385|300E    |029395;
    LDA.B $02                                                           ;029387|A502    |001F02; $02 is flag for whether or not to increment $01
    BNE +                                                               ;029389|D004    |02938F;
    INC.B $02                                                           ;02938B|E602    |001F02; if "no," turn it on for next iteration
    BRA LOOP_02934D                                                     ;02938D|80BE    |02934D;
  + STZ.B $02                                                           ;02938F|6402    |001F02; if "yes," turn it off and increment $01
    INC.B $01                                                           ;029391|E601    |001F01; so effectively every other iteration, $01 increments
    BRA LOOP_02934D                                                     ;029393|80B8    |02934D;
RTS_029395:
    RTS                                                                 ;029395|60      |      ;

case_MSBs_0b1_029396:
    BIT.B #$40                                                          ;029396|8940    |      ; check bit 6
    BEQ case_tile_MSBs_0b10_0293BC                                      ;029398|F022    |0293BC;
case_tile_MSBs_0b11_02939A:
    STA.B $0B                                                           ;02939A|850B    |001F0B; if 0b11 MSBs, $0B <- type byte
    LDA.B [CompressedTilesetPtr]                                        ;02939C|A704    |001F04; $0C <- read another byte
    INC.B CompressedTilesetPtr                                          ;02939E|E604    |001F04;
    BNE +                                                               ;0293A0|D003    |0293A5;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0293A2|20699A  |029A69;
  + STA.B $0C                                                           ;0293A5|850C    |001F0C;
    BIT.B #$04                                                          ;0293A7|8904    |      ; put byte in $0C into top half of A
    BNE +                                                               ;0293A9|D005    |0293B0; check bit 2; if 0, $0D <- 0x08
    XBA                                                                 ;0293AB|EB      |      ;
    LDA.B #$08                                                          ;0293AC|A908    |      ;
    BRA ++                                                              ;0293AE|8003    |0293B3;
  + XBA                                                                 ;0293B0|EB      |      ; if 1, $0D <- 0x0A
    LDA.B #$0A                                                          ;0293B1|A90A    |      ;
 ++ STA.B $0D                                                           ;0293B3|850D    |001F0D; note that based on below code, this is not a pointer value
    LDA.B #$00                                                          ;0293B5|A900    |      ; top byte of A <- 0x00; low byte of A <- $0C & 0x3
    XBA                                                                 ;0293B7|EB      |      ;
    AND.B #$03                                                          ;0293B8|2903    |      ;
    BRA CODE_run_4_subs_from_029422_list_0293DE                         ;0293BA|8022    |0293DE;

case_tile_MSBs_0b10_0293BC:
    STA.B $0B                                                           ;0293BC|850B    |001F0B; $0B <- type byte
    LDA.B [CompressedTilesetPtr]                                        ;0293BE|A704    |001F04; $0C <- another byte
    INC.B CompressedTilesetPtr                                          ;0293C0|E604    |001F04;
    BNE ++                                                              ;0293C2|D003    |0293C7;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0293C4|20699A  |029A69;
 ++ STA.B $0C                                                           ;0293C7|850C    |001F0C;
    LDA.B [CompressedTilesetPtr]                                        ;0293C9|A704    |001F04; $0D <- another byte
    INC.B CompressedTilesetPtr                                          ;0293CB|E604    |001F04; so just read three bytes from ptr into $0B-$0D
    BNE ++                                                              ;0293CD|D003    |0293D2;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0293CF|20699A  |029A69;
 ++ STA.B $0D                                                           ;0293D2|850D    |001F0D;
CODE_get_1st_029422_sub_index_0293D4:
    LDA.B #$00                                                          ;0293D4|A900    |      ; clear top byte of accumulator
    XBA                                                                 ;0293D6|EB      |      ;
    LDA.B $0C                                                           ;0293D7|A50C    |001F0C; A <- middle byte
    ASL.B $0D                                                           ;0293D9|060D    |001F0D; use 3 LSBs of middle byte and MSB of top byte to construct an index
    ROL A                                                               ;0293DB|2A      |      ;
    AND.B #$0F                                                          ;0293DC|290F    |      ;
CODE_run_4_subs_from_029422_list_0293DE:
    ASL A                                                               ;0293DE|0A      |      ; convert word index to byte index
    TAX                                                                 ;0293DF|AA      |      ; note that this uses the current state of A, not necessarily one specific manip of $0C
    LDY.B TilesetBufferCurrentOffset                                    ;0293E0|A407    |001F07; Y <- $07
    PEA.W CODE_run_2nd_sub_0293E8-1                                     ;0293E2|F4E793  |7E93E7; run a subroutine and then come back to $0293E8 below
    JMP.W (JUMP_TABLE_gfx_decompression_029422,X)                       ;0293E5|7C2294  |029422;
CODE_run_2nd_sub_0293E8:
    LDY.B TilesetBufferCurrentOffset                                    ;0293E8|A407    |001F07; Y <- $07 + 1
    INY                                                                 ;0293EA|C8      |      ;
    LDA.B #$00                                                          ;0293EB|A900    |      ; clear top byte of accumulator
    XBA                                                                 ;0293ED|EB      |      ;
    LDA.B $0C                                                           ;0293EE|A50C    |001F0C; next, take the top 5 bits (bits 7-3) of middle byte to use as an index
    LSR A                                                               ;0293F0|4A      |      ;
    LSR A                                                               ;0293F1|4A      |      ;
    AND.B #$3E                                                          ;0293F2|293E    |      ;
    TAX                                                                 ;0293F4|AA      |      ;
    PEA.W CODE_run_3rd_sub_0293FB-1                                     ;0293F5|F4FA93  |7E93FA; run a subroutine and come back to $0293FB below
    JMP.W (JUMP_TABLE_gfx_decompression_029422,X)                       ;0293F8|7C2294  |029422;
CODE_run_3rd_sub_0293FB:
    REP #$20                                                            ;0293FB|C220    |      ;
    LDA.B TilesetBufferCurrentOffset                                    ;0293FD|A507    |001F07; Y <- $07 + 0x10
    CLC                                                                 ;0293FF|18      |      ;
    ADC.W #!BP2                                                         ;029400|691000  |      ;
    TAY                                                                 ;029403|A8      |      ;
    PHA                                                                 ;029404|48      |      ; push this Y value for later
    LDA.B $0B                                                           ;029405|A50B    |001F0B; now use all of the low byte (except its MSB) as an index to the list
    ASL A                                                               ;029407|0A      |      ;
    AND.W #$007E                                                        ;029408|297E00  |      ;
    SEP #$20                                                            ;02940B|E220    |      ;
    TAX                                                                 ;02940D|AA      |      ;
    PEA.W CODE_run_4th_sub_029414-1                                     ;02940E|F41394  |7E9413; run the subroutine, and come back to $029414
    JMP.W (JUMP_TABLE_gfx_decompression_029422,X)                       ;029411|7C2294  |029422;
CODE_run_4th_sub_029414:
    PLY                                                                 ;029414|7A      |      ; Y <- $07 + 0x11 (see $0293FB above)
    INY                                                                 ;029415|C8      |      ;
    LDA.B #$00                                                          ;029416|A900    |      ; clear top byte of accumulator
    XBA                                                                 ;029418|EB      |      ;
    LDA.B $0D                                                           ;029419|A50D    |001F0D; use current state of high byte (it may have been ASL'd earlier) as an index to the list
    TAX                                                                 ;02941B|AA      |      ;
    PEA.W advance_offset_in_07_to_next_tile_028DF2-1                    ;02941C|F4F18D  |7E8DF1; run the subroutine, and return to $028DF2
    JMP.W (JUMP_TABLE_gfx_decompression_029422,X)                       ;02941F|7C2294  |029422; that adds 0x20 to $07, and gets the next type byte for the tile data

JUMP_TABLE_gfx_decompression_029422:
    dw bitplane_sub_00_read_8_raw_bytes_0294B0                          ;029422|        |0294B0;
    dw bitplane_sub_01_spot_change_04_02992F                            ;029424|        |02992F;
    dw bitplane_sub_02_spot_change_05_029937                            ;029426|        |029937;
    dw bitplane_sub_03_pseudo_RLE_starting_with_00_02951A               ;029428|        |02951A;
    dw bitplane_sub_04_fill_bitplane_with_00_0294C5                     ;02942A|        |0294C5;
    dw bitplane_sub_05_fill_bitplane_with_FF_0294C9                     ;02942C|        |0294C9;
    dw bitplane_sub_06_fill_bitplane_with_ROM_byte_0294CD               ;02942E|        |0294CD;
    dw bitplane_sub_07_repeat_2_byte_seq_4_times_0294EF                 ;029430|        |0294EF;
    dw bitplane_sub_08_repeat_4_byte_seq_twice_02962B                   ;029432|        |02962B;
    dw bitplane_sub_09_spot_change_06_02993F                            ;029434|        |02993F;
    dw bitplane_sub_0A_spot_change_07_029947                            ;029436|        |029947;
    dw bitplane_sub_0B_use_3_or_4_unique_bytes_for_bitplane_029545      ;029438|        |029545;
    dw bitplane_sub_0C_use_4_unique_nibbles_to_fill_bitplane_02959E     ;02943A|        |02959E;
    dw bitplane_sub_0D_reuse_bp_from_tile_possibly_reverse_029643       ;02943C|        |029643;
    dw bitplane_sub_0E_spot_change_0D_02994F                            ;02943E|        |02994F;
    dw bitplane_sub_0F_copy_bp0_to_current_bp_02968F                    ;029440|        |02968F;
    dw bitplane_sub_10_spot_change_0F_029957                            ;029442|        |029957;
    dw bitplane_sub_11_copy_inverted_bp0_0296D4                         ;029444|        |0296D4;
    dw bitplane_sub_12_spot_change_11_02996F                            ;029446|        |02996F;
    dw bitplane_sub_13_copy_bp1_to_current_bp_029693                    ;029448|        |029693;
    dw bitplane_sub_14_spot_change_13_02995F                            ;02944A|        |02995F;
    dw bitplane_sub_15_copy_inverted_bp1_0296D8                         ;02944C|        |0296D8;
    dw bitplane_sub_16_spot_change_15_029977                            ;02944E|        |029977;
    dw bitplane_sub_17_or_bp0_bp1_0296FD                                ;029450|        |0296FD;
    dw bitplane_sub_18_spot_change_17_029987                            ;029452|        |029987;
    dw bitplane_sub_19_and_bp0_bp1_029760                               ;029454|        |029760;
    dw bitplane_sub_1A_spot_change_19_0299A7                            ;029456|        |0299A7;
    dw bitplane_sub_1B_xor_bp0_bp1_0297C3                               ;029458|        |0297C3;
    dw bitplane_sub_1C_spot_change_1B_0299C7                            ;02945A|        |0299C7;
    dw bitplane_sub_1D_not_or_bp0_bp1_02980B                            ;02945C|        |02980B;
    dw bitplane_sub_1E_spot_change_1D_0299DF                            ;02945E|        |0299DF;
    dw bitplane_sub_1F_not_and_bp0_bp1_029876                           ;029460|        |029876;
    dw bitplane_sub_20_spot_change_1F_0299FF                            ;029462|        |0299FF;
    dw bitplane_sub_21_not_xor_bp0_bp1_0298E1                           ;029464|        |0298E1;
    dw bitplane_sub_22_spot_change_21_029A1F                            ;029466|        |029A1F;
    dw bitplane_sub_23_copy_bp2_to_current_bp_029698                    ;029468|        |029698;
    dw bitplane_sub_24_spot_change_23_029967                            ;02946A|        |029967;
    dw bitplane_sub_25_copy_inverted_bp2_0296DD                         ;02946C|        |0296DD;
    dw bitplane_sub_26_spot_change_25_02997F                            ;02946E|        |02997F;
    dw bitplane_sub_27_or_bp0_bp2_029715                                ;029470|        |029715;
    dw bitplane_sub_28_spot_change_27_02998F                            ;029472|        |02998F;
    dw bitplane_sub_29_and_bp0_bp2_029778                               ;029474|        |029778;
    dw bitplane_sub_2A_spot_change_29_0299AF                            ;029476|        |0299AF;
    dw bitplane_sub_2B_xor_bp0_bp2_0297DB                               ;029478|        |0297DB;
    dw bitplane_sub_2C_spot_change_2B_0299CF                            ;02947A|        |0299CF;
    dw bitplane_sub_2D_not_or_bp0_bp2_029825                            ;02947C|        |029825;
    dw bitplane_sub_2E_spot_change_2D_0299E7                            ;02947E|        |0299E7;
    dw bitplane_sub_2F_not_and_bp0_bp2_029890                           ;029480|        |029890;
    dw bitplane_sub_30_spot_change_2F_029A07                            ;029482|        |029A07;
    dw bitplane_sub_31_not_xor_bp0_bp2_0298FB                           ;029484|        |0298FB;
    dw bitplane_sub_32_spot_change_31_029A27                            ;029486|        |029A27;
    dw bitplane_sub_33_or_bp1_bp2_02972D                                ;029488|        |02972D;
    dw bitplane_sub_34_spot_change_33_029997                            ;02948A|        |029997;
    dw bitplane_sub_35_and_bp1_bp2_029790                               ;02948C|        |029790;
    dw bitplane_sub_36_spot_change_35_0299B7                            ;02948E|        |0299B7;
    dw bitplane_sub_37_xor_bp1_bp2_0297F3                               ;029490|        |0297F3;
    dw bitplane_sub_38_spot_change_37_0299D7                            ;029492|        |0299D7;
    dw bitplane_sub_39_not_or_bp1_bp2_02983F                            ;029494|        |02983F;
    dw bitplane_sub_3A_spot_change_39_0299EF                            ;029496|        |0299EF;
    dw bitplane_sub_3B_not_and_bp1_bp2_0298AA                           ;029498|        |0298AA;
    dw bitplane_sub_3C_spot_change_3B_029A0F                            ;02949A|        |029A0F;
    dw bitplane_sub_3D_not_xor_bp1_bp2_029915                           ;02949C|        |029915;
    dw bitplane_sub_3E_spot_change_3D_029A2F                            ;02949E|        |029A2F;
    dw bitplane_sub_3F_or_bp0_bp1_bp2_029745                            ;0294A0|        |029745;
    dw bitplane_sub_40_spot_change_3F_02999F                            ;0294A2|        |02999F;
    dw bitplane_sub_41_and_bp0_bp1_bp2_0297A8                           ;0294A4|        |0297A8;
    dw bitplane_sub_42_spot_change_41_0299BF                            ;0294A6|        |0299BF;
    dw bitplane_sub_43_not_or_bp0_bp1_bp2_029859                        ;0294A8|        |029859;
    dw bitplane_sub_44_spot_change_33_0299F7                            ;0294AA|        |0299F7;
    dw bitplane_sub_45_not_and_bp0_bp1_bp2_0298C4                       ;0294AC|        |0298C4;
    dw bitplane_sub_46_spot_change_45_029A17                            ;0294AE|        |029A17;

bitplane_sub_00_read_8_raw_bytes_0294B0:
    LDX.W #$0007                                                        ;0294B0|A20700  |      ; read 8 bytes from pointer, and copy them to every other byte position
LOOP_read_byte_of_tile_data_0294B3:
    LDA.B [CompressedTilesetPtr]                                        ;0294B3|A704    |001F04;
    INC.B CompressedTilesetPtr                                          ;0294B5|E604    |001F04;
    BNE +                                                               ;0294B7|D003    |0294BC;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0294B9|20699A  |029A69;
  + STA.W TilesetBuffer,Y                                               ;0294BC|990080  |7E8000;
    INY                                                                 ;0294BF|C8      |      ;
    INY                                                                 ;0294C0|C8      |      ;
    DEX                                                                 ;0294C1|CA      |      ;
    BPL LOOP_read_byte_of_tile_data_0294B3                              ;0294C2|10EF    |0294B3;
    RTS                                                                 ;0294C4|60      |      ;

bitplane_sub_04_fill_bitplane_with_00_0294C5:
    LDA.B #$00                                                          ;0294C5|A900    |      ; copy [00] 8 times
    BRA CODE_fill_bitplane_with_byte_0294D6                             ;0294C7|800D    |0294D6;
bitplane_sub_05_fill_bitplane_with_FF_0294C9:
    LDA.B #$FF                                                          ;0294C9|A9FF    |      ; copy [FF] 8 times
    BRA CODE_fill_bitplane_with_byte_0294D6                             ;0294CB|8009    |0294D6;
bitplane_sub_06_fill_bitplane_with_ROM_byte_0294CD:
    LDA.B [CompressedTilesetPtr]                                        ;0294CD|A704    |001F04; read a byte from pointer, and copy it 8 times
    INC.B CompressedTilesetPtr                                          ;0294CF|E604    |001F04;
    BNE CODE_fill_bitplane_with_byte_0294D6                             ;0294D1|D003    |0294D6;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0294D3|20699A  |029A69;
CODE_fill_bitplane_with_byte_0294D6:
    STA.W TilesetBuffer+$00,Y                                           ;0294D6|990080  |7E8000;
    STA.W TilesetBuffer+$02,Y                                           ;0294D9|990280  |7E8002;
    STA.W TilesetBuffer+$04,Y                                           ;0294DC|990480  |7E8004;
    STA.W TilesetBuffer+$06,Y                                           ;0294DF|990680  |7E8006;
    STA.W TilesetBuffer+$08,Y                                           ;0294E2|990880  |7E8008;
    STA.W TilesetBuffer+$0A,Y                                           ;0294E5|990A80  |7E800A;
    STA.W TilesetBuffer+$0C,Y                                           ;0294E8|990C80  |7E800C;
    STA.W TilesetBuffer+$0E,Y                                           ;0294EB|990E80  |7E800E;
    RTS                                                                 ;0294EE|60      |      ;

bitplane_sub_07_repeat_2_byte_seq_4_times_0294EF:
    LDA.B [CompressedTilesetPtr]                                        ;0294EF|A704    |001F04; read two bytes B0 and B1, and copy them in order [B0 x B1 x B0 x B1 x B0 x B1 x B0 x B1 x]
    INC.B CompressedTilesetPtr                                          ;0294F1|E604    |001F04;
    BNE +                                                               ;0294F3|D003    |0294F8;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0294F5|20699A  |029A69;
  + STA.W TilesetBuffer+$00,Y                                           ;0294F8|990080  |7F8000;
    STA.W TilesetBuffer+$04,Y                                           ;0294FB|990480  |7F8004;
    STA.W TilesetBuffer+$08,Y                                           ;0294FE|990880  |7F8008;
    STA.W TilesetBuffer+$0C,Y                                           ;029501|990C80  |7F800C;
    LDA.B [CompressedTilesetPtr]                                        ;029504|A704    |001F04;
    INC.B CompressedTilesetPtr                                          ;029506|E604    |001F04;
    BNE +                                                               ;029508|D003    |02950D;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;02950A|20699A  |029A69;
  + STA.W TilesetBuffer+$02,Y                                           ;02950D|990280  |7F8002;
    STA.W TilesetBuffer+$06,Y                                           ;029510|990680  |7F8006;
    STA.W TilesetBuffer+$0A,Y                                           ;029513|990A80  |7F800A;
    STA.W TilesetBuffer+$0E,Y                                           ;029516|990E80  |7F800E;
    RTS                                                                 ;029519|60      |      ;

bitplane_sub_03_pseudo_RLE_starting_with_00_02951A:
    LDX.W #$0007                                                        ;02951A|A20700  |      ; run loop below 8 times
    LDA.B [CompressedTilesetPtr]                                        ;02951D|A704    |001F04; read a byte that contains 8 bit flags
    INC.B CompressedTilesetPtr                                          ;02951F|E604    |001F04;
    BNE +                                                               ;029521|D003    |029526;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029523|20699A  |029A69;
  + ASL A                                                               ;029526|0A      |      ; first bit flag is the MSB of the byte
    STA.B $00                                                           ;029527|8500    |001F00;
    LDA.B #$00                                                          ;029529|A900    |      ; if 0, write a [00] byte
    BCC case_write_byte_029536                                          ;02952B|9009    |029536;
LOOP_read_byte_02952D:
    LDA.B [CompressedTilesetPtr]                                        ;02952D|A704    |001F04; if 1, read another byte from pointer, and write it
    INC.B CompressedTilesetPtr                                          ;02952F|E604    |001F04;
    BNE case_write_byte_029536                                          ;029531|D003    |029536;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029533|20699A  |029A69;
case_write_byte_029536:
    STA.W TilesetBuffer,Y                                               ;029536|990080  |7E8000; write byte to space
    INY                                                                 ;029539|C8      |      ;
    INY                                                                 ;02953A|C8      |      ;
    DEX                                                                 ;02953B|CA      |      ; check loop counter, RTS if done
    BMI RTS_029544                                                      ;02953C|3006    |029544;
    ASL.B $00                                                           ;02953E|0600    |001F00; check next bit flag
    BCS LOOP_read_byte_02952D                                           ;029540|B0EB    |02952D; if 1, read another byte from pointer
    BRA case_write_byte_029536                                          ;029542|80F2    |029536; if 0, write the previous byte again
RTS_029544:
    RTS                                                                 ;029544|60      |      ;

bitplane_sub_0B_use_3_or_4_unique_bytes_for_bitplane_029545:
    LDA.B [CompressedTilesetPtr]                                        ;029545|A704    |001F04; read a byte into $01
    INC.B CompressedTilesetPtr                                          ;029547|E604    |001F04;
    BNE +                                                               ;029549|D003    |02954E;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;02954B|20699A  |029A69;
  + STA.B $01                                                           ;02954E|8501    |001F01;
    LDA.B [CompressedTilesetPtr]                                        ;029550|A704    |001F04; read another byte into $00
    INC.B CompressedTilesetPtr                                          ;029552|E604    |001F04;
    BNE +                                                               ;029554|D003    |029559;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029556|20699A  |029A69;
  + STA.B $00                                                           ;029559|8500    |001F00;
    LDX.W #$0004                                                        ;02955B|A20400  |      ; check if LSBs of $00 are 0b00
    AND.B #$03                                                          ;02955E|2903    |      ;
    BEQ +                                                               ;029560|F004    |029566; if yes, skip down
    DEX                                                                 ;029562|CA      |      ; if no, X <- 3, and use 0x3 to reset the bits of $00
    TXA                                                                 ;029563|8A      |      ;
    TRB.B $00                                                           ;029564|1400    |001F00;
  + STX.B $02                                                           ;029566|8602    |001F02; $02 <- 4 if LSBs are 00; 3 if LSBs are not 00; i.e. a loop counter
    LDX.W #$0000                                                        ;029568|A20000  |      ;
    TXA                                                                 ;02956B|8A      |      ;
LOOP_02956C:
    LDA.B [CompressedTilesetPtr]                                        ;02956C|A704    |001F04; read N bytes, where N is initial value in $02
    INC.B CompressedTilesetPtr                                          ;02956E|E604    |001F04;
    BNE +                                                               ;029570|D003    |029575;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029572|20699A  |029A69;
  + STA.W LIST_bitmask_group_0,X                                        ;029575|9D9AF6  |7FF69A;
    INX                                                                 ;029578|E8      |      ;
    DEC.B $02                                                           ;029579|C602    |001F02;
    BNE LOOP_02956C                                                     ;02957B|D0EF    |02956C;
    LDA.B #$07                                                          ;02957D|A907    |      ; run next loop 8 times
    STA.B $02                                                           ;02957F|8502    |001F02;
LOOP_029581:
    LDA.B #$00                                                          ;029581|A900    |      ; clear top byte of accumulator
    XBA                                                                 ;029583|EB      |      ;
    LDA.B $00                                                           ;029584|A500    |001F00; take the two LSBs of $00-$01
    AND.B #$03                                                          ;029586|2903    |      ;
    TAX                                                                 ;029588|AA      |      ;
    LDA.W LIST_bitmask_group_0,X                                        ;029589|BD9AF6  |7FF69A; use as index to data we just read from pointer, store to tile buffer
    STA.W TilesetBuffer,Y                                               ;02958C|990080  |7F8000;
    LSR.B $01                                                           ;02958F|4601    |001F01; shift the 16-bit value right by 2
    ROR.B $00                                                           ;029591|6600    |001F00;
    LSR.B $01                                                           ;029593|4601    |001F01;
    ROR.B $00                                                           ;029595|6600    |001F00;
    INY                                                                 ;029597|C8      |      ; advance pointer, check if need to run loop again
    INY                                                                 ;029598|C8      |      ;
    DEC.B $02                                                           ;029599|C602    |001F02;
    BPL LOOP_029581                                                     ;02959B|10E4    |029581;
    RTS                                                                 ;02959D|60      |      ;

bitplane_sub_0C_use_4_unique_nibbles_to_fill_bitplane_02959E:
    LDX.W #$0003                                                        ;02959E|A20300  |      ;
LOOP_0295A1:
    LDA.B [CompressedTilesetPtr]                                        ;0295A1|A704    |001F04; read 4 bytes from pointer into $F6CA
    INC.B CompressedTilesetPtr                                          ;0295A3|E604    |001F04; note that you write them from "right to left" like [03 02 01 00]
    BNE +                                                               ;0295A5|D003    |0295AA;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0295A7|20699A  |029A69;
  + STA.W LIST_tile_bitmasks_F6CA_bank_7E,X                             ;0295AA|9DCAF6  |7EF6CA;
    DEX                                                                 ;0295AD|CA      |      ;
    BPL LOOP_0295A1                                                     ;0295AE|10F1    |0295A1;
    LDA.B [CompressedTilesetPtr]                                        ;0295B0|A704    |001F04; push next byte
    INC.B CompressedTilesetPtr                                          ;0295B2|E604    |001F04;
    BNE +                                                               ;0295B4|D003    |0295B9;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0295B6|20699A  |029A69;
  + PHA                                                                 ;0295B9|48      |      ;
    AND.B #$0F                                                          ;0295BA|290F    |      ; store 4 low bits of byte to $F69B
    STA.W $F69B                                                         ;0295BC|8D9BF6  |7EF69B;
    PLA                                                                 ;0295BF|68      |      ; store 4 high bits of byte to $F69A
    LSR A                                                               ;0295C0|4A      |      ;
    LSR A                                                               ;0295C1|4A      |      ;
    LSR A                                                               ;0295C2|4A      |      ;
    LSR A                                                               ;0295C3|4A      |      ;
    STA.W LIST_bitmask_group_0                                          ;0295C4|8D9AF6  |7EF69A;
    LDA.B [CompressedTilesetPtr]                                        ;0295C7|A704    |001F04; push next byte
    INC.B CompressedTilesetPtr                                          ;0295C9|E604    |001F04;
    BNE +                                                               ;0295CB|D003    |0295D0;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;0295CD|20699A  |029A69;
  + PHA                                                                 ;0295D0|48      |      ;
    AND.B #$0F                                                          ;0295D1|290F    |      ; store 4 low bits to $F69D
    STA.W $F69D                                                         ;0295D3|8D9DF6  |7EF69D;
    PLA                                                                 ;0295D6|68      |      ; store 4 high bits to $F69C
    LSR A                                                               ;0295D7|4A      |      ;
    LSR A                                                               ;0295D8|4A      |      ;
    LSR A                                                               ;0295D9|4A      |      ;
    LSR A                                                               ;0295DA|4A      |      ;
    STA.W $F69C                                                         ;0295DB|8D9CF6  |7EF69C;
    LDA.B #$07                                                          ;0295DE|A907    |      ; loop counter of 8
    STA.B $00                                                           ;0295E0|8500    |001F00;
    STZ.B $01                                                           ;0295E2|6401    |001F01;
    STZ.B $02                                                           ;0295E4|6402    |001F02;
LOOP_0295E6:
    LDA.B #$00                                                          ;0295E6|A900    |      ;
    XBA                                                                 ;0295E8|EB      |      ;
    LDA.B $01                                                           ;0295E9|A501    |001F01;
    TAX                                                                 ;0295EB|AA      |      ;
    LDA.W LIST_tile_bitmasks_F6CA_bank_7E,X                             ;0295EC|BDCAF6  |7EF6CA; $03 <- value in $F6CA
    STA.B $03                                                           ;0295EF|8503    |001F03;
    LSR A                                                               ;0295F1|4A      |      ; push $03 >> 2
    LSR A                                                               ;0295F2|4A      |      ;
    PHA                                                                 ;0295F3|48      |      ;
    LSR A                                                               ;0295F4|4A      |      ; $F6CA <- $F6CA >> 4
    LSR A                                                               ;0295F5|4A      |      ;
    STA.W LIST_tile_bitmasks_F6CA_bank_7E,X                             ;0295F6|9DCAF6  |7EF6CA;
    LDA.B $03                                                           ;0295F9|A503    |001F03; get original value of $F6CA
    AND.B #$03                                                          ;0295FB|2903    |      ; use its two LSBs to get a value from $F69A
    TAX                                                                 ;0295FD|AA      |      ;
    LDA.W LIST_bitmask_group_0,X                                        ;0295FE|BD9AF6  |7EF69A;
    ASL A                                                               ;029601|0A      |      ;
    ASL A                                                               ;029602|0A      |      ;
    ASL A                                                               ;029603|0A      |      ;
    ASL A                                                               ;029604|0A      |      ;
    STA.B $03                                                           ;029605|8503    |001F03; store it, left shifted 4 times, to $03
    LDA.B #$00                                                          ;029607|A900    |      ; clear top byte of accumulator
    XBA                                                                 ;029609|EB      |      ;
    PLA                                                                 ;02960A|68      |      ; get back pushed value of "$03 >> 2" from $0295F1
    AND.B #$03                                                          ;02960B|2903    |      ;
    TAX                                                                 ;02960D|AA      |      ;
    LDA.W LIST_bitmask_group_0,X                                        ;02960E|BD9AF6  |7EF69A; generate tile bitplane value
    ORA.B $03                                                           ;029611|0503    |001F03;
    STA.W TilesetBuffer,Y                                               ;029613|990080  |7E8000;
    INY                                                                 ;029616|C8      |      ; advance pointers and finish loop if needed
    INY                                                                 ;029617|C8      |      ;
    DEC.B $00                                                           ;029618|C600    |001F00;
    BMI RTS_02962A                                                      ;02961A|300E    |02962A;
    LDA.B $02                                                           ;02961C|A502    |001F02; $02 is flag for "should increment $01"
    BNE case_inc_01_029624                                              ;02961E|D004    |029624;
case_do_not_inc_01_029620:
    INC.B $02                                                           ;029620|E602    |001F02; if 0, set to increment on after next iteration
    BRA LOOP_0295E6                                                     ;029622|80C2    |0295E6;
case_inc_01_029624:
    STZ.B $02                                                           ;029624|6402    |001F02; if 1, increment on this iteration, but not after next
    INC.B $01                                                           ;029626|E601    |001F01;
    BRA LOOP_0295E6                                                     ;029628|80BC    |0295E6;
RTS_02962A:
    RTS                                                                 ;02962A|60      |      ;

bitplane_sub_08_repeat_4_byte_seq_twice_02962B:
    LDX.W #$0003                                                        ;02962B|A20300  |      ; run loop 4 times
LOOP_02962E:
    LDA.B [CompressedTilesetPtr]                                        ;02962E|A704    |001F04; read a byte from pointer
    INC.B CompressedTilesetPtr                                          ;029630|E604    |001F04;
    BNE +                                                               ;029632|D003    |029637;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029634|20699A  |029A69;
  + STA.W TilesetBuffer,Y                                               ;029637|990080  |7F8000; store to row 0 and 4 of particular bitplane
    STA.W TilesetBuffer+$08,Y                                           ;02963A|990880  |7F8008;
    INY                                                                 ;02963D|C8      |      ; continue down the rows
    INY                                                                 ;02963E|C8      |      ; so in total, B0 B1 B2 B3 B0 B1 B2 B3
    DEX                                                                 ;02963F|CA      |      ;
    BPL LOOP_02962E                                                     ;029640|10EC    |02962E;
    RTS                                                                 ;029642|60      |      ;

bitplane_sub_0D_reuse_bp_from_tile_possibly_reverse_029643:
    LDA.B [CompressedTilesetPtr]                                        ;029643|A704    |001F04; read byte B0 from pointer
    INC.B CompressedTilesetPtr                                          ;029645|E604    |001F04;
    BNE +                                                               ;029647|D003    |02964C;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029649|20699A  |029A69;
  + STA.B $00                                                           ;02964C|8500    |001F00; store to $00 to modify; keep a copy of original byte in $02 for later
    STA.B $02                                                           ;02964E|8502    |001F02;
    LDA.B [CompressedTilesetPtr]                                        ;029650|A704    |001F04; read another byte from pointer (B1), and put into top half of accumulator
    INC.B CompressedTilesetPtr                                          ;029652|E604    |001F04;
    BNE +                                                               ;029654|D003    |029659;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029656|20699A  |029A69;
  + XBA                                                                 ;029659|EB      |      ;
    LDA.B #$00                                                          ;02965A|A900    |      ;
    REP #$20                                                            ;02965C|C220    |      ; 16-bit accumulator has (B1 << 8)
    ROR.B $00                                                           ;02965E|6600    |001F00; rotate out bits 0-1 of $00, and rotate them into MSBs of accumulator
    ROR A                                                               ;029660|6A      |      ;
    ROR.B $00                                                           ;029661|6600    |001F00;
    ROR A                                                               ;029663|6A      |      ;
    LSR A                                                               ;029664|4A      |      ; shift out LSB of accumulator (should be a 0?), and rotate into the MSB of $00-$01
    ROR.B $00                                                           ;029665|6600    |001F00;
    BCC +                                                               ;029667|9001    |02966A; if rotate shifted out a 1 (bit pos 2), increment accumulator (look at even or odd bitplane #)
    INC A                                                               ;029669|1A      |      ; perhaps note that if C is set, this INC does not change it, but $00 no longer needed
  + ROR.B $00                                                           ;02966A|6600    |001F00; check LSB of $00 by rotating it out
    BCC +                                                               ;02966C|9004    |029672; if 0, skip down
    CLC                                                                 ;02966E|18      |      ; if 1, add 0x10 to accumulator (look at either bitplane 2 or 3)
    ADC.W #$0010                                                        ;02966F|691000  |      ;
  + CLC                                                                 ;029672|18      |      ; add the offset for the start of the decompression buffer
    ADC.B TilesetBufferStartOffset                                      ;029673|6509    |001F09;
    TAX                                                                 ;029675|AA      |      ; this is our final offset in bank 7E or 7F for tile data to copy
    SEP #$20                                                            ;029676|E220    |      ;
    LDA.B $02                                                           ;029678|A502    |001F02; look at the MSB of the original copy of the byte B0 in $00
    BPL copy_bitplane_data_from_X_0296A3                                ;02967A|1027    |0296A3; if 0, run $0296A3 (copy in regular order)
    LDA.B #$07                                                          ;02967C|A907    |      ; if 1, do this code here
    STA.B $00                                                           ;02967E|8500    |001F00;
LOOP_copy_bitplane_in_reverse_order_029680:
    LDA.W TilesetBuffer+$00,X                                           ;029680|BD0080  |7E8000; copy the bitplane in reverse order, e.g. 0 -> 7, 1 -> 6, ..., 6 -> 1, 7 -> 0
    STA.W TilesetBuffer+$0E,Y                                           ;029683|990E80  |7E800E;
    INX                                                                 ;029686|E8      |      ;
    INX                                                                 ;029687|E8      |      ;
    DEY                                                                 ;029688|88      |      ;
    DEY                                                                 ;029689|88      |      ;
    DEC.B $00                                                           ;02968A|C600    |001F00;
    BPL LOOP_copy_bitplane_in_reverse_order_029680                      ;02968C|10F2    |029680;
    RTS                                                                 ;02968E|60      |      ;

bitplane_sub_0F_copy_bp0_to_current_bp_02968F:
    LDX.B TilesetBufferCurrentOffset                                    ;02968F|A607    |001F07;
    BRA copy_bitplane_data_from_X_0296A3                                ;029691|8010    |0296A3;
bitplane_sub_13_copy_bp1_to_current_bp_029693:
    LDX.B TilesetBufferCurrentOffset                                    ;029693|A607    |001F07;
    INX                                                                 ;029695|E8      |      ;
    BRA copy_bitplane_data_from_X_0296A3                                ;029696|800B    |0296A3;
bitplane_sub_23_copy_bp2_to_current_bp_029698:
    REP #$20                                                            ;029698|C220    |      ;
    LDA.B TilesetBufferCurrentOffset                                    ;02969A|A507    |001F07;
    CLC                                                                 ;02969C|18      |      ;
    ADC.W #!BP2                                                         ;02969D|691000  |      ;
    TAX                                                                 ;0296A0|AA      |      ;
    SEP #$20                                                            ;0296A1|E220    |      ;
copy_bitplane_data_from_X_0296A3:
    LDA.W TilesetBuffer+$00,X                                           ;0296A3|BD0080  |7E8000;
    STA.W TilesetBuffer+$00,Y                                           ;0296A6|990080  |7E8000;
    LDA.W TilesetBuffer+$02,X                                           ;0296A9|BD0280  |7E8002;
    STA.W TilesetBuffer+$02,Y                                           ;0296AC|990280  |7E8002;
    LDA.W TilesetBuffer+$04,X                                           ;0296AF|BD0480  |7E8004;
    STA.W TilesetBuffer+$04,Y                                           ;0296B2|990480  |7E8004;
    LDA.W TilesetBuffer+$06,X                                           ;0296B5|BD0680  |7E8006;
    STA.W TilesetBuffer+$06,Y                                           ;0296B8|990680  |7E8006;
    LDA.W TilesetBuffer+$08,X                                           ;0296BB|BD0880  |7E8008;
    STA.W TilesetBuffer+$08,Y                                           ;0296BE|990880  |7E8008;
    LDA.W TilesetBuffer+$0A,X                                           ;0296C1|BD0A80  |7E800A;
    STA.W TilesetBuffer+$0A,Y                                           ;0296C4|990A80  |7E800A;
    LDA.W TilesetBuffer+$0C,X                                           ;0296C7|BD0C80  |7E800C;
    STA.W TilesetBuffer+$0C,Y                                           ;0296CA|990C80  |7E800C;
    LDA.W TilesetBuffer+$0E,X                                           ;0296CD|BD0E80  |7E800E;
    STA.W TilesetBuffer+$0E,Y                                           ;0296D0|990E80  |7E800E;
    RTS                                                                 ;0296D3|60      |      ;

bitplane_sub_11_copy_inverted_bp0_0296D4:
    LDX.B TilesetBufferCurrentOffset                                    ;0296D4|A607    |001F07; modify bitplane 0 of current tile
    BRA copy_inverted_bitplane_0296E8                                   ;0296D6|8010    |0296E8;
bitplane_sub_15_copy_inverted_bp1_0296D8:
    LDX.B TilesetBufferCurrentOffset                                    ;0296D8|A607    |001F07; modify bitplane 1 of current tile
    INX                                                                 ;0296DA|E8      |      ;
    BRA copy_inverted_bitplane_0296E8                                   ;0296DB|800B    |0296E8;
bitplane_sub_25_copy_inverted_bp2_0296DD:
    REP #$20                                                            ;0296DD|C220    |      ; modify bitplane 2 of current tile
    LDA.B TilesetBufferCurrentOffset                                    ;0296DF|A507    |001F07;
    CLC                                                                 ;0296E1|18      |      ;
    ADC.W #!BP2                                                         ;0296E2|691000  |      ;
    TAX                                                                 ;0296E5|AA      |      ;
    SEP #$20                                                            ;0296E6|E220    |      ;
copy_inverted_bitplane_0296E8:
    LDA.B #$07                                                          ;0296E8|A907    |      ; initialize loop counter (8 iterations)
    STA.B $00                                                           ;0296EA|8500    |001F00;
LOOP_copy_inverted_bitplane_0296EC:
    LDA.W TilesetBuffer,X                                               ;0296EC|BD0080  |7E8000; take the specified bitplane, invert it, and store to current
    EOR.B #$FF                                                          ;0296EF|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;0296F1|990080  |7E8000;
    INX                                                                 ;0296F4|E8      |      ;
    INX                                                                 ;0296F5|E8      |      ;
    INY                                                                 ;0296F6|C8      |      ;
    INY                                                                 ;0296F7|C8      |      ;
    DEC.B $00                                                           ;0296F8|C600    |001F00;
    BPL LOOP_copy_inverted_bitplane_0296EC                              ;0296FA|10F0    |0296EC;
    RTS                                                                 ;0296FC|60      |      ;

bitplane_sub_17_or_bp0_bp1_0296FD:
    LDX.B TilesetBufferCurrentOffset                                    ;0296FD|A607    |001F07; next several subroutines all combine previous bitplanes together
    LDA.B #$07                                                          ;0296FF|A907    |      ;
    STA.B $00                                                           ;029701|8500    |001F00;
LOOP_or_bp0_bp1_029703:
    LDA.W TilesetBuffer,X                                               ;029703|BD0080  |7E8000; this one does BP0 | BP1
    ORA.W TilesetBuffer+!BP1,X                                          ;029706|1D0180  |7E8001;
    STA.W TilesetBuffer,Y                                               ;029709|990080  |7E8000;
    INX                                                                 ;02970C|E8      |      ;
    INX                                                                 ;02970D|E8      |      ;
    INY                                                                 ;02970E|C8      |      ;
    INY                                                                 ;02970F|C8      |      ;
    DEC.B $00                                                           ;029710|C600    |001F00;
    BPL LOOP_or_bp0_bp1_029703                                          ;029712|10EF    |029703;
    RTS                                                                 ;029714|60      |      ;

bitplane_sub_27_or_bp0_bp2_029715:
    LDX.B TilesetBufferCurrentOffset                                    ;029715|A607    |001F07;
    LDA.B #$07                                                          ;029717|A907    |      ;
    STA.B $00                                                           ;029719|8500    |001F00;
LOOP_or_bp0_bp2_02971B:
    LDA.W TilesetBuffer,X                                               ;02971B|BD0080  |7F8000; BP0 | BP2
    ORA.W TilesetBuffer+!BP2,X                                          ;02971E|1D1080  |7F8010;
    STA.W TilesetBuffer,Y                                               ;029721|990080  |7F8000;
    INX                                                                 ;029724|E8      |      ;
    INX                                                                 ;029725|E8      |      ;
    INY                                                                 ;029726|C8      |      ;
    INY                                                                 ;029727|C8      |      ;
    DEC.B $00                                                           ;029728|C600    |001F00;
    BPL LOOP_or_bp0_bp2_02971B                                          ;02972A|10EF    |02971B;
    RTS                                                                 ;02972C|60      |      ;

bitplane_sub_33_or_bp1_bp2_02972D:
    LDX.B TilesetBufferCurrentOffset                                    ;02972D|A607    |001F07;
    LDA.B #$07                                                          ;02972F|A907    |      ;
    STA.B $00                                                           ;029731|8500    |001F00;
LOOP_or_bp1_bp2_029733:
    LDA.W TilesetBuffer+!BP1,X                                          ;029733|BD0180  |7E8001; BP1 | BP2
    ORA.W TilesetBuffer+!BP2,X                                          ;029736|1D1080  |7E8010;
    STA.W TilesetBuffer,Y                                               ;029739|990080  |7E8000;
    INX                                                                 ;02973C|E8      |      ;
    INX                                                                 ;02973D|E8      |      ;
    INY                                                                 ;02973E|C8      |      ;
    INY                                                                 ;02973F|C8      |      ;
    DEC.B $00                                                           ;029740|C600    |001F00;
    BPL LOOP_or_bp1_bp2_029733                                          ;029742|10EF    |029733;
    RTS                                                                 ;029744|60      |      ;

bitplane_sub_3F_or_bp0_bp1_bp2_029745:
    LDX.B TilesetBufferCurrentOffset                                    ;029745|A607    |001F07;
    LDA.B #$07                                                          ;029747|A907    |      ;
    STA.B $00                                                           ;029749|8500    |001F00;
LOOP_or_bp0_bp1_bp2_02974B:
    LDA.W TilesetBuffer,X                                               ;02974B|BD0080  |7E8000; BP0 | BP1 | BP2
    ORA.W TilesetBuffer+!BP1,X                                          ;02974E|1D0180  |7E8001;
    ORA.W TilesetBuffer+!BP2,X                                          ;029751|1D1080  |7E8010;
    STA.W TilesetBuffer,Y                                               ;029754|990080  |7E8000;
    INX                                                                 ;029757|E8      |      ;
    INX                                                                 ;029758|E8      |      ;
    INY                                                                 ;029759|C8      |      ;
    INY                                                                 ;02975A|C8      |      ;
    DEC.B $00                                                           ;02975B|C600    |001F00;
    BPL LOOP_or_bp0_bp1_bp2_02974B                                      ;02975D|10EC    |02974B;
    RTS                                                                 ;02975F|60      |      ;

bitplane_sub_19_and_bp0_bp1_029760:
    LDX.B TilesetBufferCurrentOffset                                    ;029760|A607    |001F07;
    LDA.B #$07                                                          ;029762|A907    |      ;
    STA.B $00                                                           ;029764|8500    |001F00;
LOOP_and_bp0_bp1_029766:
    LDA.W TilesetBuffer,X                                               ;029766|BD0080  |7E8000; BP0 & BP1
    AND.W TilesetBuffer+!BP1,X                                          ;029769|3D0180  |7E8001;
    STA.W TilesetBuffer,Y                                               ;02976C|990080  |7E8000;
    INX                                                                 ;02976F|E8      |      ;
    INX                                                                 ;029770|E8      |      ;
    INY                                                                 ;029771|C8      |      ;
    INY                                                                 ;029772|C8      |      ;
    DEC.B $00                                                           ;029773|C600    |001F00;
    BPL LOOP_and_bp0_bp1_029766                                         ;029775|10EF    |029766;
    RTS                                                                 ;029777|60      |      ;

bitplane_sub_29_and_bp0_bp2_029778:
    LDX.B TilesetBufferCurrentOffset                                    ;029778|A607    |001F07;
    LDA.B #$07                                                          ;02977A|A907    |      ;
    STA.B $00                                                           ;02977C|8500    |001F00;
LOOP_and_bp0_bp2_02977E:
    LDA.W TilesetBuffer,X                                               ;02977E|BD0080  |7E8000; BP0 & BP2
    AND.W TilesetBuffer+!BP2,X                                          ;029781|3D1080  |7E8010;
    STA.W TilesetBuffer,Y                                               ;029784|990080  |7E8000;
    INX                                                                 ;029787|E8      |      ;
    INX                                                                 ;029788|E8      |      ;
    INY                                                                 ;029789|C8      |      ;
    INY                                                                 ;02978A|C8      |      ;
    DEC.B $00                                                           ;02978B|C600    |001F00;
    BPL LOOP_and_bp0_bp2_02977E                                         ;02978D|10EF    |02977E;
    RTS                                                                 ;02978F|60      |      ;

bitplane_sub_35_and_bp1_bp2_029790:
    LDX.B TilesetBufferCurrentOffset                                    ;029790|A607    |001F07;
    LDA.B #$07                                                          ;029792|A907    |      ;
    STA.B $00                                                           ;029794|8500    |001F00;
LOOP_and_bp1_bp2_029796:
    LDA.W TilesetBuffer+!BP1,X                                          ;029796|BD0180  |7F8001; BP1 & BP2
    AND.W TilesetBuffer+!BP2,X                                          ;029799|3D1080  |7F8010;
    STA.W TilesetBuffer,Y                                               ;02979C|990080  |7F8000;
    INX                                                                 ;02979F|E8      |      ;
    INX                                                                 ;0297A0|E8      |      ;
    INY                                                                 ;0297A1|C8      |      ;
    INY                                                                 ;0297A2|C8      |      ;
    DEC.B $00                                                           ;0297A3|C600    |001F00;
    BPL LOOP_and_bp1_bp2_029796                                         ;0297A5|10EF    |029796;
    RTS                                                                 ;0297A7|60      |      ;

bitplane_sub_41_and_bp0_bp1_bp2_0297A8:
    LDX.B TilesetBufferCurrentOffset                                    ;0297A8|A607    |001F07;
    LDA.B #$07                                                          ;0297AA|A907    |      ;
    STA.B $00                                                           ;0297AC|8500    |001F00;
LOOP_and_bp0_bp1_bp2_0297AE:
    LDA.W TilesetBuffer,X                                               ;0297AE|BD0080  |7F8000; BP0 & BP1 & BP2
    AND.W TilesetBuffer+!BP1,X                                          ;0297B1|3D0180  |7F8001;
    AND.W TilesetBuffer+!BP2,X                                          ;0297B4|3D1080  |7F8010;
    STA.W TilesetBuffer,Y                                               ;0297B7|990080  |7F8000;
    INX                                                                 ;0297BA|E8      |      ;
    INX                                                                 ;0297BB|E8      |      ;
    INY                                                                 ;0297BC|C8      |      ;
    INY                                                                 ;0297BD|C8      |      ;
    DEC.B $00                                                           ;0297BE|C600    |001F00;
    BPL LOOP_and_bp0_bp1_bp2_0297AE                                     ;0297C0|10EC    |0297AE;
    RTS                                                                 ;0297C2|60      |      ;

bitplane_sub_1B_xor_bp0_bp1_0297C3:
    LDX.B TilesetBufferCurrentOffset                                    ;0297C3|A607    |001F07;
    LDA.B #$07                                                          ;0297C5|A907    |      ;
    STA.B $00                                                           ;0297C7|8500    |001F00;
LOOP_xor_bp0_bp1_0297C9:
    LDA.W TilesetBuffer,X                                               ;0297C9|BD0080  |7E8000; BP0 ^ BP1
    EOR.W TilesetBuffer+!BP1,X                                          ;0297CC|5D0180  |7E8001;
    STA.W TilesetBuffer,Y                                               ;0297CF|990080  |7E8000;
    INX                                                                 ;0297D2|E8      |      ;
    INX                                                                 ;0297D3|E8      |      ;
    INY                                                                 ;0297D4|C8      |      ;
    INY                                                                 ;0297D5|C8      |      ;
    DEC.B $00                                                           ;0297D6|C600    |001F00;
    BPL LOOP_xor_bp0_bp1_0297C9                                         ;0297D8|10EF    |0297C9;
    RTS                                                                 ;0297DA|60      |      ;

bitplane_sub_2B_xor_bp0_bp2_0297DB:
    LDX.B TilesetBufferCurrentOffset                                    ;0297DB|A607    |001F07;
    LDA.B #$07                                                          ;0297DD|A907    |      ;
    STA.B $00                                                           ;0297DF|8500    |001F00;
LOOP_xor_bp0_bp2_0297E1:
    LDA.W TilesetBuffer,X                                               ;0297E1|BD0080  |7E8000; BP0 ^ BP2
    EOR.W TilesetBuffer+!BP2,X                                          ;0297E4|5D1080  |7E8010;
    STA.W TilesetBuffer,Y                                               ;0297E7|990080  |7E8000;
    INX                                                                 ;0297EA|E8      |      ;
    INX                                                                 ;0297EB|E8      |      ;
    INY                                                                 ;0297EC|C8      |      ;
    INY                                                                 ;0297ED|C8      |      ;
    DEC.B $00                                                           ;0297EE|C600    |001F00;
    BPL LOOP_xor_bp0_bp2_0297E1                                         ;0297F0|10EF    |0297E1;
    RTS                                                                 ;0297F2|60      |      ;

bitplane_sub_37_xor_bp1_bp2_0297F3:
    LDX.B TilesetBufferCurrentOffset                                    ;0297F3|A607    |001F07;
    LDA.B #$07                                                          ;0297F5|A907    |      ;
    STA.B $00                                                           ;0297F7|8500    |001F00;
LOOP_xor_bp1_bp2_0297F9:
    LDA.W TilesetBuffer+!BP1,X                                          ;0297F9|BD0180  |7E8001; BP1 ^ BP2
    EOR.W TilesetBuffer+!BP2,X                                          ;0297FC|5D1080  |7E8010;
    STA.W TilesetBuffer,Y                                               ;0297FF|990080  |7E8000;
    INX                                                                 ;029802|E8      |      ;
    INX                                                                 ;029803|E8      |      ;
    INY                                                                 ;029804|C8      |      ;
    INY                                                                 ;029805|C8      |      ;
    DEC.B $00                                                           ;029806|C600    |001F00;
    BPL LOOP_xor_bp1_bp2_0297F9                                         ;029808|10EF    |0297F9;
    RTS                                                                 ;02980A|60      |      ;

bitplane_sub_1D_not_or_bp0_bp1_02980B:
    LDX.B TilesetBufferCurrentOffset                                    ;02980B|A607    |001F07; same as 17, but invert resulting bytes
    LDA.B #$07                                                          ;02980D|A907    |      ;
    STA.B $00                                                           ;02980F|8500    |001F00;
LOOP_not_or_bp0_bp1_029811:
    LDA.W TilesetBuffer,X                                               ;029811|BD0080  |7E8000;
    ORA.W TilesetBuffer+!BP1,X                                          ;029814|1D0180  |7E8001;
    EOR.B #$FF                                                          ;029817|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;029819|990080  |7E8000;
    INX                                                                 ;02981C|E8      |      ;
    INX                                                                 ;02981D|E8      |      ;
    INY                                                                 ;02981E|C8      |      ;
    INY                                                                 ;02981F|C8      |      ;
    DEC.B $00                                                           ;029820|C600    |001F00;
    BPL LOOP_not_or_bp0_bp1_029811                                      ;029822|10ED    |029811;
    RTS                                                                 ;029824|60      |      ;

bitplane_sub_2D_not_or_bp0_bp2_029825:
    LDX.B TilesetBufferCurrentOffset                                    ;029825|A607    |001F07; same as 27, but invert resulting bytes
    LDA.B #$07                                                          ;029827|A907    |      ;
    STA.B $00                                                           ;029829|8500    |001F00;
LOOP_not_or_bp0_bp2_02982B:
    LDA.W TilesetBuffer,X                                               ;02982B|BD0080  |7E8000;
    ORA.W TilesetBuffer+!BP2,X                                          ;02982E|1D1080  |7E8010;
    EOR.B #$FF                                                          ;029831|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;029833|990080  |7E8000;
    INX                                                                 ;029836|E8      |      ;
    INX                                                                 ;029837|E8      |      ;
    INY                                                                 ;029838|C8      |      ;
    INY                                                                 ;029839|C8      |      ;
    DEC.B $00                                                           ;02983A|C600    |001F00;
    BPL LOOP_not_or_bp0_bp2_02982B                                      ;02983C|10ED    |02982B;
    RTS                                                                 ;02983E|60      |      ;

bitplane_sub_39_not_or_bp1_bp2_02983F:
    LDX.B TilesetBufferCurrentOffset                                    ;02983F|A607    |001F07; same as 33, but invert resulting bytes
    LDA.B #$07                                                          ;029841|A907    |      ;
    STA.B $00                                                           ;029843|8500    |001F00;
LOOP_not_or_bp1_bp2_029845:
    LDA.W TilesetBuffer+!BP1,X                                          ;029845|BD0180  |7E8001;
    ORA.W TilesetBuffer+!BP2,X                                          ;029848|1D1080  |7E8010;
    EOR.B #$FF                                                          ;02984B|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;02984D|990080  |7E8000;
    INX                                                                 ;029850|E8      |      ;
    INX                                                                 ;029851|E8      |      ;
    INY                                                                 ;029852|C8      |      ;
    INY                                                                 ;029853|C8      |      ;
    DEC.B $00                                                           ;029854|C600    |001F00;
    BPL LOOP_not_or_bp1_bp2_029845                                      ;029856|10ED    |029845;
    RTS                                                                 ;029858|60      |      ;

bitplane_sub_43_not_or_bp0_bp1_bp2_029859:
    LDX.B TilesetBufferCurrentOffset                                    ;029859|A607    |001F07; same as 3F, but invert resulting bytes
    LDA.B #$07                                                          ;02985B|A907    |      ;
    STA.B $00                                                           ;02985D|8500    |001F00;
LOOP_not_or_bp0_bp1_bp2_02985F:
    LDA.W TilesetBuffer,X                                               ;02985F|BD0080  |7E8000;
    ORA.W TilesetBuffer+!BP1,X                                          ;029862|1D0180  |7E8001;
    ORA.W TilesetBuffer+!BP2,X                                          ;029865|1D1080  |7E8010;
    EOR.B #$FF                                                          ;029868|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;02986A|990080  |7E8000;
    INX                                                                 ;02986D|E8      |      ;
    INX                                                                 ;02986E|E8      |      ;
    INY                                                                 ;02986F|C8      |      ;
    INY                                                                 ;029870|C8      |      ;
    DEC.B $00                                                           ;029871|C600    |001F00;
    BPL LOOP_not_or_bp0_bp1_bp2_02985F                                  ;029873|10EA    |02985F;
    RTS                                                                 ;029875|60      |      ;

bitplane_sub_1F_not_and_bp0_bp1_029876:
    LDX.B TilesetBufferCurrentOffset                                    ;029876|A607    |001F07; same as 19, but invert resulting bytes
    LDA.B #$07                                                          ;029878|A907    |      ;
    STA.B $00                                                           ;02987A|8500    |001F00;
LOOP_not_and_bp0_bp1_02987C:
    LDA.W TilesetBuffer,X                                               ;02987C|BD0080  |7E8000;
    AND.W TilesetBuffer+!BP1,X                                          ;02987F|3D0180  |7E8001;
    EOR.B #$FF                                                          ;029882|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;029884|990080  |7E8000;
    INX                                                                 ;029887|E8      |      ;
    INX                                                                 ;029888|E8      |      ;
    INY                                                                 ;029889|C8      |      ;
    INY                                                                 ;02988A|C8      |      ;
    DEC.B $00                                                           ;02988B|C600    |001F00;
    BPL LOOP_not_and_bp0_bp1_02987C                                     ;02988D|10ED    |02987C;
    RTS                                                                 ;02988F|60      |      ;

bitplane_sub_2F_not_and_bp0_bp2_029890:
    LDX.B TilesetBufferCurrentOffset                                    ;029890|A607    |001F07; same as 29, but invert resulting bytes
    LDA.B #$07                                                          ;029892|A907    |      ;
    STA.B $00                                                           ;029894|8500    |001F00;
LOOP_not_and_bp0_bp2_029896:
    LDA.W TilesetBuffer,X                                               ;029896|BD0080  |7E8000;
    AND.W TilesetBuffer+!BP2,X                                          ;029899|3D1080  |7E8010;
    EOR.B #$FF                                                          ;02989C|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;02989E|990080  |7E8000;
    INX                                                                 ;0298A1|E8      |      ;
    INX                                                                 ;0298A2|E8      |      ;
    INY                                                                 ;0298A3|C8      |      ;
    INY                                                                 ;0298A4|C8      |      ;
    DEC.B $00                                                           ;0298A5|C600    |001F00;
    BPL LOOP_not_and_bp0_bp2_029896                                     ;0298A7|10ED    |029896;
    RTS                                                                 ;0298A9|60      |      ;

bitplane_sub_3B_not_and_bp1_bp2_0298AA:
    LDX.B TilesetBufferCurrentOffset                                    ;0298AA|A607    |001F07; same as 35, but invert resulting bytes
    LDA.B #$07                                                          ;0298AC|A907    |      ;
    STA.B $00                                                           ;0298AE|8500    |001F00;
LOOP_not_and_bp1_bp2_0298B0:
    LDA.W TilesetBuffer+!BP1,X                                          ;0298B0|BD0180  |7E8001;
    AND.W TilesetBuffer+!BP2,X                                          ;0298B3|3D1080  |7E8010;
    EOR.B #$FF                                                          ;0298B6|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;0298B8|990080  |7E8000;
    INX                                                                 ;0298BB|E8      |      ;
    INX                                                                 ;0298BC|E8      |      ;
    INY                                                                 ;0298BD|C8      |      ;
    INY                                                                 ;0298BE|C8      |      ;
    DEC.B $00                                                           ;0298BF|C600    |001F00;
    BPL LOOP_not_and_bp1_bp2_0298B0                                     ;0298C1|10ED    |0298B0;
    RTS                                                                 ;0298C3|60      |      ;

bitplane_sub_45_not_and_bp0_bp1_bp2_0298C4:
    LDX.B TilesetBufferCurrentOffset                                    ;0298C4|A607    |001F07; same as 41, but invert resulting bytes
    LDA.B #$07                                                          ;0298C6|A907    |      ;
    STA.B $00                                                           ;0298C8|8500    |001F00;
LOOP_not_and_bp0_bp1_bp2_0298CA:
    LDA.W TilesetBuffer,X                                               ;0298CA|BD0080  |7E8000;
    AND.W TilesetBuffer+!BP1,X                                          ;0298CD|3D0180  |7E8001;
    AND.W TilesetBuffer+!BP2,X                                          ;0298D0|3D1080  |7E8010;
    EOR.B #$FF                                                          ;0298D3|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;0298D5|990080  |7E8000;
    INX                                                                 ;0298D8|E8      |      ;
    INX                                                                 ;0298D9|E8      |      ;
    INY                                                                 ;0298DA|C8      |      ;
    INY                                                                 ;0298DB|C8      |      ;
    DEC.B $00                                                           ;0298DC|C600    |001F00;
    BPL LOOP_not_and_bp0_bp1_bp2_0298CA                                 ;0298DE|10EA    |0298CA;
    RTS                                                                 ;0298E0|60      |      ;

bitplane_sub_21_not_xor_bp0_bp1_0298E1:
    LDX.B TilesetBufferCurrentOffset                                    ;0298E1|A607    |001F07; same as 1B, but invert resulting bytes
    LDA.B #$07                                                          ;0298E3|A907    |      ;
    STA.B $00                                                           ;0298E5|8500    |001F00;
LOOP_not_xor_bp0_bp1_0298E7:
    LDA.W TilesetBuffer,X                                               ;0298E7|BD0080  |7E8000;
    EOR.W TilesetBuffer+!BP1,X                                          ;0298EA|5D0180  |7E8001;
    EOR.B #$FF                                                          ;0298ED|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;0298EF|990080  |7E8000;
    INX                                                                 ;0298F2|E8      |      ;
    INX                                                                 ;0298F3|E8      |      ;
    INY                                                                 ;0298F4|C8      |      ;
    INY                                                                 ;0298F5|C8      |      ;
    DEC.B $00                                                           ;0298F6|C600    |001F00;
    BPL LOOP_not_xor_bp0_bp1_0298E7                                     ;0298F8|10ED    |0298E7;
    RTS                                                                 ;0298FA|60      |      ;

bitplane_sub_31_not_xor_bp0_bp2_0298FB:
    LDX.B TilesetBufferCurrentOffset                                    ;0298FB|A607    |001F07; same as 2B, but invert resulting bytes
    LDA.B #$07                                                          ;0298FD|A907    |      ;
    STA.B $00                                                           ;0298FF|8500    |001F00;
LOOP_not_xor_bp0_bp2_029901:
    LDA.W TilesetBuffer,X                                               ;029901|BD0080  |7F8000;
    EOR.W TilesetBuffer+!BP2,X                                          ;029904|5D1080  |7F8010;
    EOR.B #$FF                                                          ;029907|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;029909|990080  |7F8000;
    INX                                                                 ;02990C|E8      |      ;
    INX                                                                 ;02990D|E8      |      ;
    INY                                                                 ;02990E|C8      |      ;
    INY                                                                 ;02990F|C8      |      ;
    DEC.B $00                                                           ;029910|C600    |001F00;
    BPL LOOP_not_xor_bp0_bp2_029901                                     ;029912|10ED    |029901;
    RTS                                                                 ;029914|60      |      ;

bitplane_sub_3D_not_xor_bp1_bp2_029915:
    LDX.B TilesetBufferCurrentOffset                                    ;029915|A607    |001F07; same as 37, but invert resulting bytes
    LDA.B #$07                                                          ;029917|A907    |      ;
    STA.B $00                                                           ;029919|8500    |001F00;
LOOP_not_xor_bp1_bp2_02991B:
    LDA.W TilesetBuffer+!BP1,X                                          ;02991B|BD0180  |7E8001;
    EOR.W TilesetBuffer+!BP2,X                                          ;02991E|5D1080  |7E8010;
    EOR.B #$FF                                                          ;029921|49FF    |      ;
    STA.W TilesetBuffer,Y                                               ;029923|990080  |7E8000;
    INX                                                                 ;029926|E8      |      ;
    INX                                                                 ;029927|E8      |      ;
    INY                                                                 ;029928|C8      |      ;
    INY                                                                 ;029929|C8      |      ;
    DEC.B $00                                                           ;02992A|C600    |001F00;
    BPL LOOP_not_xor_bp1_bp2_02991B                                     ;02992C|10ED    |02991B;
    RTS                                                                 ;02992E|60      |      ;

bitplane_sub_01_spot_change_04_02992F:
    PHY                                                                 ;02992F|5A      |      ; the next 0x21 (33) codes all have the same format
    JSR.W bitplane_sub_04_fill_bitplane_with_00_0294C5                  ;029930|20C594  |0294C5; call some other subroutine ID
    PLY                                                                 ;029933|7A      |      ; then run the code at $029A37 to spot change bytes in the bitplane
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029934|4C379A  |029A37;
bitplane_sub_02_spot_change_05_029937:
    PHY                                                                 ;029937|5A      |      ;
    JSR.W bitplane_sub_05_fill_bitplane_with_FF_0294C9                  ;029938|20C994  |0294C9;
    PLY                                                                 ;02993B|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;02993C|4C379A  |029A37;
bitplane_sub_09_spot_change_06_02993F:
    PHY                                                                 ;02993F|5A      |      ;
    JSR.W bitplane_sub_06_fill_bitplane_with_ROM_byte_0294CD            ;029940|20CD94  |0294CD;
    PLY                                                                 ;029943|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029944|4C379A  |029A37;
bitplane_sub_0A_spot_change_07_029947:
    PHY                                                                 ;029947|5A      |      ;
    JSR.W bitplane_sub_07_repeat_2_byte_seq_4_times_0294EF              ;029948|20EF94  |0294EF;
    PLY                                                                 ;02994B|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;02994C|4C379A  |029A37;
bitplane_sub_0E_spot_change_0D_02994F:
    PHY                                                                 ;02994F|5A      |      ;
    JSR.W bitplane_sub_0D_reuse_bp_from_tile_possibly_reverse_029643    ;029950|204396  |029643;
    PLY                                                                 ;029953|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029954|4C379A  |029A37;
bitplane_sub_10_spot_change_0F_029957:
    PHY                                                                 ;029957|5A      |      ;
    JSR.W bitplane_sub_0F_copy_bp0_to_current_bp_02968F                 ;029958|208F96  |02968F;
    PLY                                                                 ;02995B|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;02995C|4C379A  |029A37;
bitplane_sub_14_spot_change_13_02995F:
    PHY                                                                 ;02995F|5A      |      ;
    JSR.W bitplane_sub_13_copy_bp1_to_current_bp_029693                 ;029960|209396  |029693;
    PLY                                                                 ;029963|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029964|4C379A  |029A37;
bitplane_sub_24_spot_change_23_029967:
    PHY                                                                 ;029967|5A      |      ;
    JSR.W bitplane_sub_23_copy_bp2_to_current_bp_029698                 ;029968|209896  |029698;
    PLY                                                                 ;02996B|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;02996C|4C379A  |029A37;
bitplane_sub_12_spot_change_11_02996F:
    PHY                                                                 ;02996F|5A      |      ;
    JSR.W bitplane_sub_11_copy_inverted_bp0_0296D4                      ;029970|20D496  |0296D4;
    PLY                                                                 ;029973|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029974|4C379A  |029A37;
bitplane_sub_16_spot_change_15_029977:
    PHY                                                                 ;029977|5A      |      ;
    JSR.W bitplane_sub_15_copy_inverted_bp1_0296D8                      ;029978|20D896  |0296D8;
    PLY                                                                 ;02997B|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;02997C|4C379A  |029A37;
bitplane_sub_26_spot_change_25_02997F:
    PHY                                                                 ;02997F|5A      |      ;
    JSR.W bitplane_sub_25_copy_inverted_bp2_0296DD                      ;029980|20DD96  |0296DD;
    PLY                                                                 ;029983|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029984|4C379A  |029A37;
bitplane_sub_18_spot_change_17_029987:
    PHY                                                                 ;029987|5A      |      ;
    JSR.W bitplane_sub_17_or_bp0_bp1_0296FD                             ;029988|20FD96  |0296FD;
    PLY                                                                 ;02998B|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;02998C|4C379A  |029A37;
bitplane_sub_28_spot_change_27_02998F:
    PHY                                                                 ;02998F|5A      |      ;
    JSR.W bitplane_sub_27_or_bp0_bp2_029715                             ;029990|201597  |029715;
    PLY                                                                 ;029993|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029994|4C379A  |029A37;
bitplane_sub_34_spot_change_33_029997:
    PHY                                                                 ;029997|5A      |      ;
    JSR.W bitplane_sub_33_or_bp1_bp2_02972D                             ;029998|202D97  |02972D;
    PLY                                                                 ;02999B|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;02999C|4C379A  |029A37;
bitplane_sub_40_spot_change_3F_02999F:
    PHY                                                                 ;02999F|5A      |      ;
    JSR.W bitplane_sub_3F_or_bp0_bp1_bp2_029745                         ;0299A0|204597  |029745;
    PLY                                                                 ;0299A3|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299A4|4C379A  |029A37;
bitplane_sub_1A_spot_change_19_0299A7:
    PHY                                                                 ;0299A7|5A      |      ;
    JSR.W bitplane_sub_19_and_bp0_bp1_029760                            ;0299A8|206097  |029760;
    PLY                                                                 ;0299AB|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299AC|4C379A  |029A37;
bitplane_sub_2A_spot_change_29_0299AF:
    PHY                                                                 ;0299AF|5A      |      ;
    JSR.W bitplane_sub_29_and_bp0_bp2_029778                            ;0299B0|207897  |029778;
    PLY                                                                 ;0299B3|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299B4|4C379A  |029A37;
bitplane_sub_36_spot_change_35_0299B7:
    PHY                                                                 ;0299B7|5A      |      ;
    JSR.W bitplane_sub_35_and_bp1_bp2_029790                            ;0299B8|209097  |029790;
    PLY                                                                 ;0299BB|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299BC|4C379A  |029A37;
bitplane_sub_42_spot_change_41_0299BF:
    PHY                                                                 ;0299BF|5A      |      ;
    JSR.W bitplane_sub_41_and_bp0_bp1_bp2_0297A8                        ;0299C0|20A897  |0297A8;
    PLY                                                                 ;0299C3|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299C4|4C379A  |029A37;
bitplane_sub_1C_spot_change_1B_0299C7:
    PHY                                                                 ;0299C7|5A      |      ;
    JSR.W bitplane_sub_1B_xor_bp0_bp1_0297C3                            ;0299C8|20C397  |0297C3;
    PLY                                                                 ;0299CB|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299CC|4C379A  |029A37;
bitplane_sub_2C_spot_change_2B_0299CF:
    PHY                                                                 ;0299CF|5A      |      ;
    JSR.W bitplane_sub_2B_xor_bp0_bp2_0297DB                            ;0299D0|20DB97  |0297DB;
    PLY                                                                 ;0299D3|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299D4|4C379A  |029A37;
bitplane_sub_38_spot_change_37_0299D7:
    PHY                                                                 ;0299D7|5A      |      ;
    JSR.W bitplane_sub_37_xor_bp1_bp2_0297F3                            ;0299D8|20F397  |0297F3;
    PLY                                                                 ;0299DB|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299DC|4C379A  |029A37;
bitplane_sub_1E_spot_change_1D_0299DF:
    PHY                                                                 ;0299DF|5A      |      ;
    JSR.W bitplane_sub_1D_not_or_bp0_bp1_02980B                         ;0299E0|200B98  |02980B;
    PLY                                                                 ;0299E3|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299E4|4C379A  |029A37;
bitplane_sub_2E_spot_change_2D_0299E7:
    PHY                                                                 ;0299E7|5A      |      ;
    JSR.W bitplane_sub_2D_not_or_bp0_bp2_029825                         ;0299E8|202598  |029825;
    PLY                                                                 ;0299EB|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299EC|4C379A  |029A37;
bitplane_sub_3A_spot_change_39_0299EF:
    PHY                                                                 ;0299EF|5A      |      ;
    JSR.W bitplane_sub_39_not_or_bp1_bp2_02983F                         ;0299F0|203F98  |02983F;
    PLY                                                                 ;0299F3|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299F4|4C379A  |029A37;
bitplane_sub_44_spot_change_33_0299F7:
    PHY                                                                 ;0299F7|5A      |      ;
    JSR.W bitplane_sub_43_not_or_bp0_bp1_bp2_029859                     ;0299F8|205998  |029859;
    PLY                                                                 ;0299FB|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;0299FC|4C379A  |029A37;
bitplane_sub_20_spot_change_1F_0299FF:
    PHY                                                                 ;0299FF|5A      |      ;
    JSR.W bitplane_sub_1F_not_and_bp0_bp1_029876                        ;029A00|207698  |029876;
    PLY                                                                 ;029A03|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029A04|4C379A  |029A37;
bitplane_sub_30_spot_change_2F_029A07:
    PHY                                                                 ;029A07|5A      |      ;
    JSR.W bitplane_sub_2F_not_and_bp0_bp2_029890                        ;029A08|209098  |029890;
    PLY                                                                 ;029A0B|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029A0C|4C379A  |029A37;
bitplane_sub_3C_spot_change_3B_029A0F:
    PHY                                                                 ;029A0F|5A      |      ;
    JSR.W bitplane_sub_3B_not_and_bp1_bp2_0298AA                        ;029A10|20AA98  |0298AA;
    PLY                                                                 ;029A13|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029A14|4C379A  |029A37;
bitplane_sub_46_spot_change_45_029A17:
    PHY                                                                 ;029A17|5A      |      ;
    JSR.W bitplane_sub_45_not_and_bp0_bp1_bp2_0298C4                    ;029A18|20C498  |0298C4;
    PLY                                                                 ;029A1B|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029A1C|4C379A  |029A37;
bitplane_sub_22_spot_change_21_029A1F:
    PHY                                                                 ;029A1F|5A      |      ;
    JSR.W bitplane_sub_21_not_xor_bp0_bp1_0298E1                        ;029A20|20E198  |0298E1;
    PLY                                                                 ;029A23|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029A24|4C379A  |029A37;
bitplane_sub_32_spot_change_31_029A27:
    PHY                                                                 ;029A27|5A      |      ;
    JSR.W bitplane_sub_31_not_xor_bp0_bp2_0298FB                        ;029A28|20FB98  |0298FB;
    PLY                                                                 ;029A2B|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029A2C|4C379A  |029A37;
bitplane_sub_3E_spot_change_3D_029A2F:
    PHY                                                                 ;029A2F|5A      |      ;
    JSR.W bitplane_sub_3D_not_xor_bp1_bp2_029915                        ;029A30|201599  |029915;
    PLY                                                                 ;029A33|7A      |      ;
    JMP.W CODE_spot_change_bytes_in_bitplane_029A37                     ;029A34|4C379A  |029A37;

CODE_spot_change_bytes_in_bitplane_029A37:
    LDA.B [CompressedTilesetPtr]                                        ;029A37|A704    |001F04; $00 <- byte from pointer = bit flags
    INC.B CompressedTilesetPtr                                          ;029A39|E604    |001F04;
    BNE +                                                               ;029A3B|D003    |029A40;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029A3D|20699A  |029A69;
  + STA.B $00                                                           ;029A40|8500    |001F00;
check_spot_change_flag_bit_029A42:
    ASL.B $00                                                           ;029A42|0600    |001F00; check the current MSB and shift it out of the bit flags buffer
    BEQ CODE_done_with_loop_do_last_spot_change_029A58                  ;029A44|F012    |029A58; if buffer is 0x00, we are done
    BCC skip_to_next_row_in_bitplane_029A54                             ;029A46|900C    |029A54; if got a 0, keep the existing byte of tile data
case_get_and_write_byte_029A48:
    LDA.B [CompressedTilesetPtr]                                        ;029A48|A704    |001F04; if got a 1, overwriite one tile data byte w/ next byte from pointer
    INC.B CompressedTilesetPtr                                          ;029A4A|E604    |001F04;
    BNE ++                                                              ;029A4C|D003    |029A51;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029A4E|20699A  |029A69;
 ++ STA.W TilesetBuffer,Y                                               ;029A51|990080  |7E8000;
skip_to_next_row_in_bitplane_029A54:
    INY                                                                 ;029A54|C8      |      ;
    INY                                                                 ;029A55|C8      |      ;
    BRA check_spot_change_flag_bit_029A42                               ;029A56|80EA    |029A42;
CODE_done_with_loop_do_last_spot_change_029A58:
    LDA.B [CompressedTilesetPtr]                                        ;029A58|A704    |001F04; take one more byte and write it to the tile buffer
    INC.B CompressedTilesetPtr                                          ;029A5A|E604    |001F04;
    BNE +                                                               ;029A5C|D003    |029A61;
    JSR.W bank_wrap_ptr_in_04_to_06_029A69                              ;029A5E|20699A  |029A69;
  + STA.W TilesetBuffer,Y                                               ;029A61|990080  |7E8000;
    RTS                                                                 ;029A64|60      |      ;

CODE_029A65:
    SEP #$20                                                            ;029A65|E220    |      ;
    REP #$10                                                            ;029A67|C210    |      ;
bank_wrap_ptr_in_04_to_06_029A69:
    INC.B CompressedTilesetPtr+1                                        ;029A69|E605    |001F05; increment high byte of pointer in $05
    BEQ +                                                               ;029A6B|F001    |029A6E; if rolled over, need to bank wrap
    RTS                                                                 ;029A6D|60      |      ;
  + PHA                                                                 ;029A6E|48      |      ; set high byte to 0x80 (xx80xx)
    LDA.B #$80                                                          ;029A6F|A980    |      ;
    STA.B CompressedTilesetPtr+1                                        ;029A71|8505    |001F05;
    INC.B CompressedTilesetPtr+2                                        ;029A73|E606    |001F06; increment bank byte for pointer
    PLA                                                                 ;029A75|68      |      ;
    RTS                                                                 ;029A76|60      |      ;

LIST_0000_or_4000_at_029A77:
    dw $0000,$4000,$0000,$4000                                          ;029A77|        |      ; 7E0000
LIST_bank_7E_or_7F_at_029A7F:
    dw $007E,$007E,$007F,$007F                                          ;029A7F|        |      ;
