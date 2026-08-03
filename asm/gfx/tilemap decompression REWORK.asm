includefrom "insert new char grid, repoint sfx and bg gfx.asm"
; see the above ASM file for where you must repoint this decompression routine

; Overview of data on direct page:
; $00-$02 starts with start pointer for compressed data
; - they get overwritten with scratch data in decompression algorithms
; $03 starts with which "block number" to decompress the tilemap into
; - it also gets overwritten with scratch data
CompressedTilemapPtr = $04       ; 3 bytes: $04-$06
StartOffsetOfDecompTilemap = $07 ; 2 bytes: $07-$08
; $09-$0A are not used here?
CompressedBlockFlags = $0B       ; 1 byte:  $0B
EndOffsetOfDecompTilemap = $0C   ; 2 bytes: $0C-$0D
; $0E is reused between the four phases:
; - low bytes: current tile ID value
; - high bits: # 2-bit values left
; - palettes:  # 3-bit values left
; - X/Y flips: # 2-bit values left
CurrentLowByte = $0E
NumBufferValsLeft = $0E
; $0F contains the 1-byte buffer for high bit and X/Y flip values
BufferForTwoBitVals = $0F
; $0F-$11 contains the 3-byte buffer for palette values
BufferForPaletteBit0Sets = $0F
BufferForPaletteBit1Sets = $10
BufferForPaletteBit2Sets = $11

DecompHighBytesBuffer = $7E6000
DecompLowBytesBuffer = $7E6E00

!OneTileRow = $20
!TilemapSize = $380

!HighBitValueBitmask = $03
!PaletteValueBitmask = $1C
!XYFlipValueBitmask = $C0

; bank_wrap_ptr_in_04_to_06_029A69 = $029a69

; ------------------------------------------------------------------------------

; org $029a87
decompress_tilemap_029A87:
    PHP                                                       ;029A87|08      |      ;
    REP #$30                                                  ;029A88|C230    |      ;
    LDA.B $03                                                 ;029A8A|A503    |001F03; $07 <- [$03] * 0x380 = offset for where to start writing data
    AND.W #$00FF                                              ;029A8C|29FF00  |      ;
    TAX                                                       ;029A8F|AA      |      ;
    LDA.W #$0000                                              ;029A90|A90000  |      ;
LOOP_029A93:
    STA.B StartOffsetOfDecompTilemap                          ;029A93|8507    |001F07;
    CLC                                                       ;029A95|18      |      ;
    ADC.W #!TilemapSize                                       ;029A96|698003  |      ;
    DEX                                                       ;029A99|CA      |      ;
    BPL LOOP_029A93                                           ;029A9A|10F7    |029A93;
    STA.B EndOffsetOfDecompTilemap                            ;029A9C|850C    |001F0C; $0C <- ([$03] + 1) * 0x380 = limit for where to write data

    SEP #$20                                                  ;029A9E|E220    |      ;
    LDA.B $02                                                 ;029AA0|A502    |001F02; $06 <- copy of bank number for gfx ptr 1
    STA.B CompressedTilemapPtr+$2                             ;029AA2|8506    |001F06;
    LDA.B #bank(DecompLowBytesBuffer)                         ;029AA4|A97E    |      ; set data bank to 7E
    PHA                                                       ;029AA6|48      |      ;
    PLB                                                       ;029AA7|AB      |      ;
    LDX.B $00                                                 ;029AA8|A600    |001F00; copy gfx ptr from $00-$02 into $04-$06
    STX.B CompressedTilemapPtr                                ;029AAA|8604    |001F04;

  ; LDA.B [CompressedTilemapPtr]                              ;029AAC|A704    |001F04; byte 0 @ ptr = flags for what blocks are compressed
  ; INC.B CompressedTilemapPtr                                ;029AAE|E604    |001F04;
  ; BNE +                                                     ;029AB0|D003    |029AB5;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029AB2|20699A  |029A69;
; + STA.B CompressedBlockFlags                                ;029AB5|850B    |001F0B;
    jsr GetByteFromPtrAndBankWrap
    sta.b CompressedBlockFlags

; ------------------------------------------------------------------------------

  ; LDY.B StartOffsetOfDecompTilemap                          ;029AB7|A407    |001F07;
  ; LSR.B CompressedBlockFlags                                ;029AB9|460B    |001F0B; check flag for uncompressed data
    jsr GoToTilemapStartAndGetCompressionFlag
    BCS decompress_tilemap_ID_low_bytes_029AD3                ;029ABB|B016    |029AD3;
case_uncompressed_tilemap_ID_low_bytes_029ABD:
    LDX.W #!TilemapSize-1                                     ;029ABD|A27F03  |      ; if 0, copy 0x380 bytes from ptr to space at $7E6E00
; - LDA.B [CompressedTilemapPtr]                              ;029AC0|A704    |001F04;
  ; INC.B CompressedTilemapPtr                                ;029AC2|E604    |001F04;
  ; BNE +                                                     ;029AC4|D003    |029AC9;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029AC6|20699A  |029A69;
; + STA.W DecompLowBytesBuffer,Y                              ;029AC9|99006E  |7E6E00;
  - jsr GetByteFromPtrAndBankWrap
    STA.W DecompLowBytesBuffer,Y
    INY                                                       ;029ACC|C8      |      ;
    DEX                                                       ;029ACD|CA      |      ;
    BPL -                                                     ;029ACE|10F0    |029AC0;
    JMP.W get_high_two_bits_for_tilemap_entry_tile_IDs_029BA3 ;029AD0|4CA39B  |029BA3;

decompress_tilemap_ID_low_bytes_029AD3:
; GoToTilemapStartAndGetCompressionFlag sets CurrentLowByte to 0x00, so replace:
  ; LDA.B #$01                                                ;029AD3|A901    |      ; otherwise, $0E <- 0x01 (start with tile ID 0x001)
  ; STA.B CurrentLowByte                                      ;029AD5|850E    |001F0E;
    inc.b CurrentLowByte
    BRA LOOP_get_tilemap_low_bytes_metadata_byte_029AE0       ;029AD7|8007    |029AE0;
check_if_wrote_enough_bytes_029AD9:
    CPY.B EndOffsetOfDecompTilemap                            ;029AD9|C40C    |001F0C; check Y offset against limit for where to write data
    BCC LOOP_get_tilemap_low_bytes_metadata_byte_029AE0       ;029ADB|9003    |029AE0;
    JMP.W get_high_two_bits_for_tilemap_entry_tile_IDs_029BA3 ;029ADD|4CA39B  |029BA3;

LOOP_get_tilemap_low_bytes_metadata_byte_029AE0:
  ; LDA.B [CompressedTilemapPtr]                              ;029AE0|A704    |001F04; read another byte, and check the MSB
  ; INC.B CompressedTilemapPtr                                ;029AE2|E604    |001F04;
  ; BNE check_MSB_029AE9                                      ;029AE4|D003    |029AE9;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029AE6|20699A  |029A69;
; check_MSB_029AE9:
    jsr GetByteFromPtrAndBankWrap
    BIT.B #$80                                                ;029AE9|8980    |      ;
    BEQ case_MSBs_are_0b0_029AFE                              ;029AEB|F011    |029AFE;
case_MSBs_are_0b1_029AED:
    BIT.B #$40                                                ;029AED|8940    |      ; if MSB is set, check bit 6
    BNE case_MSBs_are_0b11_029AF7                             ;029AEF|D006    |029AF7;
case_MSBs_are_0b10_029AF1:
    BIT.B #$20                                                ;029AF1|8920    |      ; if also that bit 6 is clear, check bit 5
    BEQ case_MSBs_are_0b100_029B33                            ;029AF3|F03E    |029B33;
case_MSBs_are_0b101_029AF5:
    BRA case_MSBs_are_0b101_029B4F                            ;029AF5|8058    |029B4F;
case_MSBs_are_0b11_029AF7:
    BIT.B #$20                                                ;029AF7|8920    |      ;
    BEQ case_MSBs_are_0b110_029B63                            ;029AF9|F068    |029B63;
case_MSBs_are_0b111_029AFB:
; possible to convert this JMP to a BRA?
    JMP.W CODE_MSBs_are_0b111_029B8B                          ;029AFB|4C8B9B  |029B8B;
  ; bra CODE_MSBs_are_0b111_029B8B
case_MSBs_are_0b0_029AFE:
    BIT.B #$40                                                ;029AFE|8940    |      ;
    BNE case_MSBs_are_0b01_029B13                             ;029B00|D011    |029B13;

case_MSBs_are_0b00_029B02:
    INC A                                                     ;029B02|1A      |      ; $00 <- (byte from $029AE0) + 1
    STA.B $00                                                 ;029B03|8500    |001F00;
    LDA.B CurrentLowByte                                      ;029B05|A50E    |001F0E; fill a total of (byte + 2) bytes with current tile #
LOOP_repeat_current_low_byte_029B07:
  ; STA.W DecompLowBytesBuffer,Y                              ;029B07|99006E  |7E6E00;
  ; INY                                                       ;029B0A|C8      |      ;
  ; DEC.B $00                                                 ;029B0B|C600    |001F00;
    jsr StoreLowByteAndDec00
    BPL LOOP_repeat_current_low_byte_029B07                   ;029B0D|10F8    |029B07;
    INC.B CurrentLowByte                                      ;029B0F|E60E    |001F0E; go to next tile ID
    BRA check_if_wrote_enough_bytes_029AD9                    ;029B11|80C6    |029AD9;

case_MSBs_are_0b01_029B13:
    AND.B #$3F                                                ;029B13|293F    |      ; MSBs 0b01 -> use low 6 bits of type byte as # bytes to fill in with consecutive values
    CMP.B #$3F                                                ;029B15|C93F    |      ; however, check for special case of 0x7F = 01 11 1111
    BNE got_num_consec_ints_to_write_029B22                   ;029B17|D009    |029B22;
case_byte_is_7F_029B19:
  ; LDA.B [CompressedTilemapPtr]                              ;029B19|A704    |001F04; if got 7F, then read the next byte from pointer to use as counter
  ; INC.B CompressedTilemapPtr                                ;029B1B|E604    |001F04; otherwise (0x40-0x7E), use low 6 bits of type byte
  ; BNE got_num_consec_ints_to_write_029B22                   ;029B1D|D003    |029B22;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029B1F|20699A  |029A69;
    jsr GetByteFromPtrAndBankWrap
; new: as-is, this is not taking full advantage of the extra byte you must read,
; because the size of the compressed block has the range 0x40-0x100 but could be
; 0x40-0x13F; need to dip into using M=0 for a bit
    rep #$21    ; clear carry, M=0
    and #$00ff
    adc #$0040
    sta $00
    bra LOOP_write_consec_ints_to_7E6E00
got_num_consec_ints_to_write_029B22:
    INC A                                                     ;029B22|1A      |      ; take result, increment it, store as loop counter
    STA.B $00                                                 ;029B23|8500    |001F00;
    stz.b $01
LOOP_write_consec_ints_to_7E6E00:
; need to write the value as a byte
    sep #$20
    LDA.B CurrentLowByte                                      ;029B25|A50E    |001F0E;
    STA.W DecompLowBytesBuffer,Y                              ;029B27|99006E  |7E6E00;
    INY                                                       ;029B2A|C8      |      ;
    INC.B CurrentLowByte                                      ;029B2B|E60E    |001F0E;
; need to decrement loop counter as a word
    rep #$20
    DEC.B $00                                                 ;029B2D|C600    |001F00;
    BNE LOOP_write_consec_ints_to_7E6E00                      ;029B2F|D0F4    |029B25;
; once done with loop, need to go back to M=1 for rest of code
    sep #$20
    BRA check_if_wrote_enough_bytes_029AD9                    ;029B31|80A6    |029AD9;

case_MSBs_are_0b100_029B33:
    AND.B #$1F                                                ;029B33|291F    |      ; $00 <- byte & 0x1F
    STA.B $00                                                 ;029B35|8500    |001F00;
  ; REP #$20                                                  ;029B37|C220    |      ;
  ; TYA                                                       ;029B39|98      |      ; X <- Y - 20 = look one tile row up
  ; SEC                                                       ;029B3A|38      |      ;
  ; SBC.W #!OneTileRow                                        ;029B3B|E92000  |      ;
  ; TAX                                                       ;029B3E|AA      |      ;
  ; SEP #$20                                                  ;029B3F|E220    |      ;
    jsr GetOffsetToOneRowUpInXReg
LOOP_repeat_IDs_from_0x20_bytes_back_029B41:
    LDA.W DecompLowBytesBuffer,X                              ;029B41|BD006E  |7E6E00; repeat a total of [$00] tile IDs from tile row up
  ; STA.W DecompLowBytesBuffer,Y                              ;029B44|99006E  |7E6E00;
  ; INX                                                       ;029B47|E8      |      ;
  ; INY                                                       ;029B48|C8      |      ;
  ; DEC.B $00                                                 ;029B49|C600    |001F00;
    inx
    jsr StoreLowByteAndDec00
    BPL LOOP_repeat_IDs_from_0x20_bytes_back_029B41           ;029B4B|10F4    |029B41;
IntermediateBranchForLowBytes:
    BRA check_if_wrote_enough_bytes_029AD9                    ;029B4D|808A    |029AD9;

case_MSBs_are_0b101_029B4F:
    AND.B #$1F                                                ;029B4F|291F    |      ; $00 <- byte & 0x1F
    STA.B $00                                                 ;029B51|8500    |001F00;
    DEY                                                       ;029B53|88      |      ; take the previous tilemap low byte and repeat it [$00] times
    LDA.W DecompLowBytesBuffer,Y                              ;029B54|B9006E  |7E6E00;
    INY                                                       ;029B57|C8      |      ;
LOOP_repeat_tilemap_low_byte_029B58:
  ; STA.W DecompLowBytesBuffer,Y                              ;029B58|99006E  |7E6E00;
  ; INY                                                       ;029B5B|C8      |      ;
  ; DEC.B $00                                                 ;029B5C|C600    |001F00;
    jsr StoreLowByteAndDec00
    BPL LOOP_repeat_tilemap_low_byte_029B58                   ;029B5E|10F8    |029B58;
; possible to convert this JMP to a BRA?
  ; JMP.W check_if_wrote_enough_bytes_029AD9                  ;029B60|4CD99A  |029AD9;
    bra IntermediateBranchForLowBytes

case_MSBs_are_0b110_029B63:
    AND.B #$1F                                                ;029B63|291F    |      ; check for special case of byte DF
    CMP.B #$1F                                                ;029B65|C91F    |      ;
    BNE got_repeat_count_for_next_byte_029B73                 ;029B67|D00A    |029B73;
case_byte_is_DF_029B69:
  ; LDA.B [CompressedTilemapPtr]                              ;029B69|A704    |001F04; if DF, read another byte and (in total) increment it to use as count
  ; INC.B CompressedTilemapPtr                                ;029B6B|E604    |001F04;
  ; BNE +                                                     ;029B6D|D003    |029B72;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029B6F|20699A  |029A69;
; + DEC A                                                     ;029B72|3A      |      ;
; same as for 7F case with low bytes; fully use extra byte to extend size range
; from 0x21-0x100 to 0x21-0x120
    jsr GetByteFromPtrAndBankWrap
    rep #$21    ; clear carry, M=0
    and #$00ff
    adc #$0021
    ; sta $00
    bra +
got_repeat_count_for_next_byte_029B73:
    stz $01
    INC A                                                     ;029B73|1A      |      ;
    INC A                                                     ;029B74|1A      |      ;
  + STA.B $00                                                 ;029B75|8500    |001F00;
  ; LDA.B [CompressedTilemapPtr]                              ;029B77|A704    |001F04; read the next byte and repeat it [count] times
  ; INC.B CompressedTilemapPtr                                ;029B79|E604    |001F04;
  ; BNE LOOP_repeat_byte_using_count_029B80                   ;029B7B|D003    |029B80;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029B7D|20699A  |029A69;
    jsr GetByteFromPtrAndBankWrap
LOOP_repeat_byte_using_count_029B80:
; write value as a byte
    sep #$20
    STA.W DecompLowBytesBuffer,Y                              ;029B80|99006E  |7E6E00;
    INY                                                       ;029B83|C8      |      ;
; decrement loop counter as a word
    rep #$20
    DEC.B $00                                                 ;029B84|C600    |001F00;
    BNE LOOP_repeat_byte_using_count_029B80                   ;029B86|D0F8    |029B80;
  ; JMP.W check_if_wrote_enough_bytes_029AD9                  ;029B88|4CD99A  |029AD9;
    sep #$20
    bra IntermediateBranchForLowBytes

CODE_MSBs_are_0b111_029B8B:
; add new case: type byte FF = set the next byte as the current tile ID
    cmp #$ff
    beq NewCaseSetCurrentTileID
; add new case: type bytes range F0-FE = write decreasing sequence
    bit #$10
    bne NewCaseWriteDecreasingSequence

; originally range E0-FF; restrict to E0-EB
  ; AND.B #$1F                                                ;029B8B|291F    |      ; $00 <- byte & 0x1F = isolate # bytes to read
    and.b #$0f
; add new case: type bytes range EC-EF = write small self-contained increasing sequence
    cmp #$0c
    bcs NewCaseSmallIsolatedIncreasingSequence
    STA.B $00                                                 ;029B8D|8500    |001F00;
LOOP_read_literal_bytes_029B8F:
  ; LDA.B [CompressedTilemapPtr]                              ;029B8F|A704    |001F04; read a total of [$00]+1 literal bytes from pointer
  ; INC.B CompressedTilemapPtr                                ;029B91|E604    |001F04;
  ; BNE +                                                     ;029B93|D003    |029B98;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029B95|20699A  |029A69;
; + STA.W DecompLowBytesBuffer,Y                              ;029B98|99006E  |7E6E00;
    jsr GetByteFromPtrAndBankWrap
  ; STA.W DecompLowBytesBuffer,Y
  ; INY                                                       ;029B9B|C8      |      ;
  ; DEC.B $00                                                 ;029B9C|C600    |001F00;
    jsr StoreLowByteAndDec00
    BPL LOOP_read_literal_bytes_029B8F                        ;029B9E|10EF    |029B8F;
  ; JMP.W check_if_wrote_enough_bytes_029AD9                  ;029BA0|4CD99A  |029AD9;
    bra IntermediateBranchForLowBytes

NewCaseSmallIsolatedIncreasingSequence:
; isolate sequence length from type byte
; encode size from 0x2-0x5 in two bits as (size-2)
    and #$03
    inc
    sta $00
    jsr GetByteFromPtrAndBankWrap
    sta $01
  - lda $01
    inc $01
    jsr StoreLowByteAndDec00
    bpl -
    bra IntermediateBranchForLowBytes

NewCaseSetCurrentTileID:
    jsr GetByteFromPtrAndBankWrap
    sta.b CurrentLowByte
    bra IntermediateBranchForLowBytes

NewCaseWriteDecreasingSequence:
; isolate sequence length from type byte
; encode size from 0x2-0x10 in four bits as (size-2)
    and #$0f
    inc
    sta $01
; read byte from ROM for starting tile ID
    jsr GetByteFromPtrAndBankWrap
    sta $00
; loop to write tile ID value to buffer, decrement tile ID
LoopWriteDecreasingSeq:
    lda $00
  ; sta.w DecompLowBytesBuffer,y
  ; iny
  ; dec $00
    jsr StoreLowByteAndDec00
    dec $01
    bpl LoopWriteDecreasingSeq
    
    jmp.w check_if_wrote_enough_bytes_029AD9

; ------------------------------------------------------------------------------

get_high_two_bits_for_tilemap_entry_tile_IDs_029BA3:
  ; LDY.B StartOffsetOfDecompTilemap                          ;029BA3|A407    |001F07;
  ; STZ.B NumBufferValsLeft                                   ;029BA5|640E    |001F0E;
  ; LSR.B CompressedBlockFlags                                ;029BA7|460B    |001F0B; check flag for compressed data
    jsr GoToTilemapStartAndGetCompressionFlag
    BCS get_metadata_byte_for_high_bits_029BC7                ;029BA9|B01C    |029BC7;
case_uncompressed_high_two_bits_for_tilemap_IDs_029BAB:
    LDX.W #!TilemapSize-1                                     ;029BAB|A27F03  |      ; if clear, then the next 0x380 / 8 * 2 = 0xE0 bytes contain all the tile ID high bits
  - JSR.W get_two_bit_val_from_buffer_in_bits_76_029EAA       ;029BAE|20AA9E  |029EAA;
    ROL #3                                                    ;029BB1|2A2A2A  |      ;
  ; AND.B #!HighBitValueBitmask                               ;029BB4|2903    |      ;
  ; STA.W DecompHighBytesBuffer,Y                             ;029BB6|990060  |7E6000;
  ; INY                                                       ;029BB9|C8      |      ;
    jsr StoreToHighBytesBuffer
    DEX                                                       ;029BBA|CA      |      ;
    BPL -                                                     ;029BBB|10F1    |029BAE;
    JMP.W get_palette_numbers_for_tilemap_029C73              ;029BBD|4C739C  |029C73;

check_if_all_high_bits_filled_in_029BC0:
    CPY.B EndOffsetOfDecompTilemap                            ;029BC0|C40C    |001F0C;
    BCC get_metadata_byte_for_high_bits_029BC7                ;029BC2|9003    |029BC7;
    JMP.W get_palette_numbers_for_tilemap_029C73              ;029BC4|4C739C  |029C73;

get_metadata_byte_for_high_bits_029BC7:
  ; LDA.B [CompressedTilemapPtr]                              ;029BC7|A704    |001F04; $00 <- next byte from the pointer
  ; INC.B CompressedTilemapPtr                                ;029BC9|E604    |001F04;
  ; jsr GetByteFromPtr
  ; BNE +                                                     ;029BCB|D003    |029BD0;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029BCD|20699A  |029A69;
; + STA.B $00                                                 ;029BD0|8500    |001F00;
    jsr GetByteFromPtrAndBankWrap
    STA.B $00
    BIT.B #$C0                                                ;029BD2|89C0    |      ; check bits 7 and 6 - both clear?
    BEQ case_MSBs_are_0b00_029BEA                             ;029BD4|F014    |029BEA;
    CMP.B #$C0                                                ;029BD6|C9C0    |      ; are they both set?
  ; BCS case_MSBs_are_0b11_029C56                             ;029BD8|B07C    |029C56;
    BCS IntermediateBranchForHighBitsMSBsOf11
    BIT.B #$80                                                ;029BDA|8980    |      ; is only bit 7 set?
    BNE case_MSBs_are_0b10_029BE4                             ;029BDC|D006    |029BE4;
case_MSBs_are_0b01_029BDE:
    BIT.B #$20                                                ;029BDE|8920    |      ; if here, then only bit 6 is currently set
    BEQ case_MSBs_are_0b010_029C06                            ;029BE0|F024    |029C06;
    BRA case_MSBs_are_0b011_029C11                            ;029BE2|802D    |029C11;
case_MSBs_are_0b10_029BE4:
    BIT.B #$20                                                ;029BE4|8920    |      ;
    BEQ case_MSBs_are_0b100_029C30                            ;029BE6|F048    |029C30;
    BRA case_MSBs_are_0b101_029C3C                            ;029BE8|8052    |029C3C;

IntermediateBranchForHighBitsMSBsOf11:
    BRA case_MSBs_are_0b11_029C56

case_MSBs_are_0b00_029BEA:
; worth noting that [STZ addr,Y] is not a valid instruction
; however, [STZ addr,X] IS valid; put Y into X for now
    tyx
    CMP.B #$3F                                                ;029BEA|C93F    |      ; check for special case of 3F
    BNE got_num_bytes_to_fill_with_00_029BF7                  ;029BEC|D009    |029BF7; if no, use the byte as is
case_byte_is_3F_029BEE:
  ; LDA.B [CompressedTilemapPtr]                              ;029BEE|A704    |001F04; if yes, read another byte
  ; INC.B CompressedTilemapPtr                                ;029BF0|E604    |001F04;
  ; BNE got_num_bytes_to_fill_with_00_029BF7                  ;029BF2|D003    |029BF7;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029BF4|20699A  |029A69;
    jsr GetByteFromPtrAndBankWrap
; same as for 7F case with low bytes; fully use extra byte to extend size range
; from 0x40-0x100 to 0x41-0x140
    rep #$21    ; clear carry, M=0
    and #$00ff
    adc #$0041
    sta $00
    bra LOOP_fill_with_00_bytes_029BFC
got_num_bytes_to_fill_with_00_029BF7:
    INC A                                                     ;029BF7|1A      |      ; use the result as # bytes to fill in with 0x00
    inc
    STA.B $00                                                 ;029BF8|8500    |001F00;
    stz.b $01
  ; LDA.B #$00                                                ;029BFA|A900    |      ;
LOOP_fill_with_00_bytes_029BFC:
  ; STA.W DecompHighBytesBuffer,Y                             ;029BFC|990060  |7E6000;
  ; INY                                                       ;029BFF|C8      |      ;
    sep #$20
    stz.w DecompHighBytesBuffer,X
    inx
    rep #$20
    DEC.B $00                                                 ;029C00|C600    |001F00;
    BNE LOOP_fill_with_00_bytes_029BFC                        ;029C02|D0F8    |029BFC;
; put current buffer position into Y
    txy
    sep #$20
    BRA check_if_all_high_bits_filled_in_029BC0               ;029C04|80BA    |029BC0;

case_MSBs_are_0b010_029C06:
    AND.B #$07                                                ;029C06|2907    |      ; $01 <- (byte & 0x7)
    STA.B $01                                                 ;029C08|8501    |001F01;
    LDA.B $00                                                 ;029C0A|A500    |001F00; shift the two tile ID high bits into position
    LSR A                                                     ;029C0C|4A      |      ;
    LSR A                                                     ;029C0D|4A      |      ;
    LSR A                                                     ;029C0E|4A      |      ;
    BRA store_single_tile_ID_high_bits_skip_bytes_029C1E      ;029C0F|800D    |029C1E;
case_MSBs_are_0b011_029C11:
    AND.B #$1F                                                ;029C11|291F    |      ; $01 <- (byte & 0x1F) + 8
    CLC                                                       ;029C13|18      |      ;
    ADC.B #$08                                                ;029C14|6908    |      ;
    STA.B $01                                                 ;029C16|8501    |001F01;
    JSR.W get_two_bit_val_from_buffer_in_bits_76_029EAA       ;029C18|20AA9E  |029EAA; get value in bits 6-7, and rotate around to bits 0-1
    ROL #3                                                    ;029C1B|2A2A2A  |      ;
store_single_tile_ID_high_bits_skip_bytes_029C1E:
    AND.B #!HighBitValueBitmask                               ;029C1E|2903    |      ; store the single set of two high bits
  ; STA.W DecompHighBytesBuffer,Y                             ;029C20|990060  |7E6000;
  ; INY                                                       ;029C23|C8      |      ;
    jsr StoreToHighBytesBuffer
    LDA.B #$00                                                ;029C24|A900    |      ; use 0b00 for the next [$01] bytes
LOOP_skip_01_bytes_for_tile_ID_high_bits_029C2C:
  ; STA.W DecompHighBytesBuffer,Y                             ;029C26|990060  |7E6000;
  ; INY                                                       ;029C29|C8      |      ;
  ; DEC.B $01                                                 ;029C2A|C601    |001F01;
    jsr StoreToHighBytesBufferAndDec01
    BPL LOOP_skip_01_bytes_for_tile_ID_high_bits_029C2C       ;029C2C|10F8    |029C26;
    BRA check_if_all_high_bits_filled_in_029BC0               ;029C2E|8090    |029BC0;

case_MSBs_are_0b100_029C30:
    AND.B #$07                                                ;029C30|2907    |      ; $01 <- (byte & 0x7) + 1
    INC A                                                     ;029C32|1A      |      ;
    STA.B $01                                                 ;029C33|8501    |001F01;
    LDA.B $00                                                 ;029C35|A500    |001F00; shift the tile ID high bits into position
    LSR A                                                     ;029C37|4A      |      ;
    LSR A                                                     ;029C38|4A      |      ;
    LSR A                                                     ;029C39|4A      |      ;
    BRA fill_nonzero_tilemap_entry_high_bytes_029C49          ;029C3A|800D    |029C49;
case_MSBs_are_0b101_029C3C:
    AND.B #$1F                                                ;029C3C|291F    |      ; $01 <- (byte & 0x1F) + 9
    CLC                                                       ;029C3E|18      |      ; this is # bytes to fill with next buffer value
    ADC.B #$09                                                ;029C3F|6909    |      ;
    STA.B $01                                                 ;029C41|8501    |001F01;
    JSR.W get_two_bit_val_from_buffer_in_bits_76_029EAA       ;029C43|20AA9E  |029EAA; get the tile ID high bits from buffer and shift into position
    ROL #3                                                    ;029C46|2A2A2A  |      ;
fill_nonzero_tilemap_entry_high_bytes_029C49:
    AND.B #!HighBitValueBitmask                               ;029C49|2903    |      ;
; - STA.W DecompHighBytesBuffer,Y                             ;029C4B|990060  |7E6000; store tilemap entry high byte to buffer
  ; INY                                                       ;029C4E|C8      |      ;
  ; DEC.B $01                                                 ;029C4F|C601    |001F01; the number of times to copy it is [$01] + 1
  - jsr StoreToHighBytesBufferAndDec01
    BPL -                                                     ;029C51|10F8    |029C4B;
    JMP.W check_if_all_high_bits_filled_in_029BC0             ;029C53|4CC09B  |029BC0;

case_MSBs_are_0b11_029C56:
    AND.B #$0F                                                ;029C56|290F    |      ; $01 <- byte & 0xF
    STA.B $01                                                 ;029C58|8501    |001F01;
    LDA.B $00                                                 ;029C5A|A500    |001F00; to keep high bits in same format as output from $029EAA...
    ROL A                                                     ;029C5C|2A      |      ; ...rotate the value from 11xx yyyy to xxyy yy11 (result: yyyy 11xx)
    ROL A                                                     ;029C5D|2A      |      ; i.e. you pack the case; the first set of two high bits; repeat count
    BRA +                                                     ;029C5E|8003    |029C63;
LOOP_write_series_of_tile_ID_high_bits_029C60:
    JSR.W get_two_bit_val_from_buffer_in_bits_76_029EAA       ;029C60|20AA9E  |029EAA; on subsequent iterations, get high bits from buffer
  + ROL #3                                                    ;029C63|2A2A2A  |      ; rotate them into position for tilemap entry standard format
    AND.B #!HighBitValueBitmask                               ;029C66|2903    |      ;
  ; STA.W DecompHighBytesBuffer,Y                             ;029C68|990060  |7E6000; write to tilemap buffer
  ; INY                                                       ;029C6B|C8      |      ;
  ; DEC.B $01                                                 ;029C6C|C601    |001F01;
    jsr StoreToHighBytesBufferAndDec01
    BPL LOOP_write_series_of_tile_ID_high_bits_029C60         ;029C6E|10F0    |029C60;
    JMP.W check_if_all_high_bits_filled_in_029BC0             ;029C70|4CC09B  |029BC0;

; ------------------------------------------------------------------------------

; the compression formats for palettes and X/Y flips are identical minus size
; ranges for some of the cases; there is potential to reuse code between them

get_palette_numbers_for_tilemap_029C73:
  ; LDY.B StartOffsetOfDecompTilemap                          ;029C73|A407    |001F07;
  ; STZ.B NumBufferValsLeft                                   ;029C75|640E    |001F0E;
  ; LSR.B CompressedBlockFlags                                ;029C77|460B    |001F0B; check flag for compressed palettes
    jsr GoToTilemapStartAndGetCompressionFlag
    BCS get_metadata_byte_for_tilemap_palette_nums_029C95     ;029C79|B01A    |029C95;
case_uncompressed_tilemap_palette_numbers_029C7B:
    LDX.W #!TilemapSize-1                                     ;029C7B|A27F03  |      ; if clear, then the next 0x380 * 8 / 3 = 0x150 bytes contain all the palette numbers
  - JSR.W get_palette_num_from_buffer_in_0F_11_029EC5         ;029C7E|20C59E  |029EC5;
  ; ORA.W DecompHighBytesBuffer,Y                             ;029C81|190060  |7E6000;
  ; STA.W DecompHighBytesBuffer,Y                             ;029C84|990060  |7E6000;
  ; INY                                                       ;029C87|C8      |      ;
    jsr StoreOnePaletteXY
    DEX                                                       ;029C88|CA      |      ;
    BPL -                                                     ;029C89|10F3    |029C7E;
    JMP.W propagate_XOR_down_tilemap_columns_029D81           ;029C8B|4C819D  |029D81;

check_if_all_palettes_filled_in_029C8E:
    CPY.B EndOffsetOfDecompTilemap                            ;029C8E|C40C    |001F0C;
    BCC get_metadata_byte_for_tilemap_palette_nums_029C95     ;029C90|9003    |029C95;
    JMP.W propagate_XOR_down_tilemap_columns_029D81           ;029C92|4C819D  |029D81;

get_metadata_byte_for_tilemap_palette_nums_029C95:
  ; LDA.B [CompressedTilemapPtr]                              ;029C95|A704    |001F04; $00 <- metadata byte for palette numbers
  ; INC.B CompressedTilemapPtr                                ;029C97|E604    |001F04;
  ; BNE +                                                     ;029C99|D003    |029C9E;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029C9B|20699A  |029A69;
; + STA.B $00                                                 ;029C9E|8500    |001F00;
    jsr GetByteFromPtrAndBankWrap
    STA.B $00

    BIT.B #$C0                                                ;029CA0|89C0    |      ; check two MSBs
    BEQ case_MSBs_are_0b00_029CC7                             ;029CA2|F023    |029CC7; are they both 0?
    CMP.B #$C0                                                ;029CA4|C9C0    |      ;
    BCS case_MSBs_are_0b11_go_to_029D65                       ;029CA6|B01C    |029CC4; are they both 1?
    BIT.B #$80                                                ;029CA8|8980    |      ;
    BNE case_MSBs_are_0b10_029CB6                             ;029CAA|D00A    |029CB6; is only bit 7 set?
case_MSBs_are_0b01_029CAC:
    BIT.B #$20                                                ;029CAC|8920    |      ; if here, then only bit 6 is set
    BNE case_MSBs_are_0b011_029CFC                            ;029CAE|D04C    |029CFC; check bit 5
case_MSBs_are_0b010_029CB0:
    BIT.B #$10                                                ;029CB0|8910    |      ;
    BEQ case_MSBs_are_0b0100_029CE7                           ;029CB2|F033    |029CE7;
    BRA case_MSBs_are_0b0101_029D19                           ;029CB4|8063    |029D19;
case_MSBs_are_0b10_029CB6:
    BIT.B #$20                                                ;029CB6|8920    |      ;
    BEQ case_MSBs_are_0b100_go_to_029D3E                      ;029CB8|F007    |029CC1;
case_MSBs_are_0b101_029CBA:
    BIT.B #$10                                                ;029CBA|8910    |      ;
    BEQ case_MSBs_are_0b1010_029D06                           ;029CBC|F048    |029D06;
case_MSBs_are_0b1011_go_to_029D49:
  ; JMP.W case_MSBs_are_0b1011_029D49                         ;029CBE|4C499D  |029D49;
    bra case_MSBs_are_0b1011_029D49
case_MSBs_are_0b100_go_to_029D3E:
  ; JMP.W case_MSBs_are_0b100_029D3E                          ;029CC1|4C3E9D  |029D3E;
    bra case_MSBs_are_0b100_029D3E
case_MSBs_are_0b11_go_to_029D65:
    JMP.W case_MSBs_are_0b11_029D65                           ;029CC4|4C659D  |029D65;

case_MSBs_are_0b00_029CC7:
  ; CMP.B #$3F                                                ;029CC7|C93F    |      ; check for special case of byte 3F
  ; BNE got_num_bytes_to_skip_029CD4                          ;029CC9|D009    |029CD4; if no, keep the byte as is
; case_byte_is_3F_029CCB:
;   LDA.B [CompressedTilemapPtr]                              ;029CCB|A704    |001F04; if yes, read another byte and use that
;   INC.B CompressedTilemapPtr                                ;029CCD|E604    |001F04;
;   BNE got_num_bytes_to_skip_029CD4                          ;029CCF|D003    |029CD4;
;   JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029CD1|20699A  |029A69;
  ; jsr GetByteFromPtrAndBankWrap
; got_num_bytes_to_skip_029CD4:
  ; STA.B $01                                                 ;029CD4|8501    |001F01; $01 <- num bytes to skip
; CODE_skip_bytes_using_01_029CD6:
  ; INY                                                       ;029CD6|C8      |      ; $02 <- Y + 1 + [$01]
  ; STY.B $02                                                 ;029CD7|8402    |001F02;
  ; TYA                                                       ;029CD9|98      |      ;
  ; CLC                                                       ;029CDA|18      |      ;
  ; ADC.B $01                                                 ;029CDB|6501    |001F01;
  ; STA.B $02                                                 ;029CDD|8502    |001F02;
  ; BCC +                                                     ;029CDF|9002    |029CE3; apply carry if necessary
  ; INC.B $03                                                 ;029CE1|E603    |001F03;
; + LDY.B $02                                                 ;029CE3|A402    |001F02;
    jsr UseValue0_ForPaletteXY
    BRA check_if_all_palettes_filled_in_029C8E                ;029CE5|80A7    |029C8E;

case_MSBs_are_0b0100_029CE7:
  ; AND.B #$0F                                                ;029CE7|290F    |      ; $01 <- byte & 0xF (ignore the top "4" nibble)
  ; STA.B $01                                                 ;029CE9|8501    |001F01;
  ; REP #$20                                                  ;029CEB|C220    |      ;
  ; TYA                                                       ;029CED|98      |      ; X <- Y - 0x20 = look up one tile row
  ; SEC                                                       ;029CEE|38      |      ;
  ; SBC.W #!OneTileRow                                        ;029CEF|E92000  |      ;
  ; TAX                                                       ;029CF2|AA      |      ;
  ; SEP #$20                                                  ;029CF3|E220    |      ;
    jsr StoreLowNibbleTo01AndGetOffsetToRowUp
    LDA.W DecompHighBytesBuffer,X                             ;029CF5|BD0060  |7E6000; reuse the palette value from one tile row up
  ; AND.B #!PaletteValueBitmask                               ;029CF8|291C    |      ;
    BRA store_1_palette_num_and_skip_using_01_029D10          ;029CFA|8014    |029D10;
case_MSBs_are_0b011_029CFC:
    AND.B #$03                                                ;029CFC|2903    |      ; $01 <- byte & 0x3
    STA.B $01                                                 ;029CFE|8501    |001F01; so byte is [011][palette#][num bytes]
    LDA.B $00                                                 ;029D00|A500    |001F00; get palette number
  ; AND.B #!PaletteValueBitmask                               ;029D02|291C    |      ;
    BRA store_1_palette_num_and_skip_using_01_029D10          ;029D04|800A    |029D10;
case_MSBs_are_0b1010_029D06:
    AND.B #$0F                                                ;029D06|290F    |      ; $01 <- (byte & 0xF) + 4 -- (ignore the top "A" nibble)
    CLC                                                       ;029D08|18      |      ;
    ADC.B #$04                                                ;029D09|6904    |      ;
    STA.B $01                                                 ;029D0B|8501    |001F01;
    JSR.W get_palette_num_from_buffer_in_0F_11_029EC5         ;029D0D|20C59E  |029EC5;
store_1_palette_num_and_skip_using_01_029D10:
    and.b #!PaletteValueBitmask
  ; ORA.W DecompHighBytesBuffer,Y                             ;029D10|190060  |7E6000; store the single palette value
  ; STA.W DecompHighBytesBuffer,Y                             ;029D13|990060  |7E6000;
  ; INY                                                       ;029D16|C8      |      ;
  ; BRA CODE_skip_bytes_using_01_029CD6                       ;029D17|80BD    |029CD6; then skip by [$01] bytes
    jsr StoreOnePaletteXY
    jsr skip_bytes_based_on_01
    bra check_if_all_palettes_filled_in_029C8E                ;029CE5|80A7    |029C8E;

case_MSBs_are_0b0101_029D19:
  ; AND.B #$0F                                                ;029D19|290F    |      ; $01 <- byte & 0xF (ignore the top "5" nibble)
  ; STA.B $01                                                 ;029D1B|8501    |001F01;
  ; REP #$20                                                  ;029D1D|C220    |      ;
  ; TYA                                                       ;029D1F|98      |      ; X <- Y - 0x20 = look one tile row up
  ; SEC                                                       ;029D20|38      |      ;
  ; SBC.W #!OneTileRow                                        ;029D21|E92000  |      ;
  ; TAX                                                       ;029D24|AA      |      ;
  ; SEP #$20                                                  ;029D25|E220    |      ;
    jsr StoreLowNibbleTo01AndGetOffsetToRowUp
  ; LDA.W DecompHighBytesBuffer,X                             ;029D27|BD0060  |7E6000; get the palette number from one tile row up
  ; AND.B #!PaletteValueBitmask                               ;029D2A|291C    |      ;
  ; STA.B $02                                                 ;029D2C|8502    |001F02;
; LOOP_copy_prev_palette_num_029D2E:
  ; LDA.B $02                                                 ;029D2E|A502    |001F02; repeatedly copy palette number into the buffer as needed
  ; ORA.W DecompHighBytesBuffer,Y                             ;029D30|190060  |7E6000;
  ; STA.W DecompHighBytesBuffer,Y                             ;029D33|990060  |7E6000;
  ; INY                                                       ;029D36|C8      |      ;
  ; DEC.B $01                                                 ;029D37|C601    |001F01;
  ; BPL LOOP_copy_prev_palette_num_029D2E                     ;029D39|10F3    |029D2E;
    lda #!PaletteValueBitmask
    jsr RepeatPreviousPaletteXY
    JMP.W check_if_all_palettes_filled_in_029C8E              ;029D3B|4C8E9C  |029C8E;

case_MSBs_are_0b100_029D3E:
    AND.B #$03                                                ;029D3E|2903    |      ; $01 <- (byte & 0x3) + 1 = # bytes to modify with palette number
    INC A                                                     ;029D40|1A      |      ;
    STA.B $01                                                 ;029D41|8501    |001F01;
    LDA.B $00                                                 ;029D43|A500    |001F00; A <- byte & 0x1C (ignore the top 0b100)
    AND.B #!PaletteValueBitmask                               ;029D45|291C    |      ; this contains the palette number itself
    BRA store_palette_num_029D53                              ;029D47|800A    |029D53;

case_MSBs_are_0b1011_029D49:
    AND.B #$0F                                                ;029D49|290F    |      ; take the low 4 bits of the byte (ignore the top B nibble)
    CLC                                                       ;029D4B|18      |      ; $01 <- (byte & 0xF) + 5
    ADC.B #$05                                                ;029D4C|6905    |      ;
    STA.B $01                                                 ;029D4E|8501    |001F01;
    JSR.W get_palette_num_from_buffer_in_0F_11_029EC5         ;029D50|20C59E  |029EC5;
store_palette_num_029D53:
  ; STA.B $02                                                 ;029D53|8502    |001F02; keep copy of palette value
; LOOP_029D55:
  ; LDA.B $02                                                 ;029D55|A502    |001F02; set for as many tilemap entries as necessary
  ; ORA.W DecompHighBytesBuffer,Y                             ;029D57|190060  |7E6000;
  ; STA.W DecompHighBytesBuffer,Y                             ;029D5A|990060  |7E6000;
  ; INY                                                       ;029D5D|C8      |      ;
  ; DEC.B $01                                                 ;029D5E|C601    |001F01;
  ; BPL LOOP_029D55                                           ;029D60|10F3    |029D55;
    jsr RepeatNewPaletteXY
    JMP.W check_if_all_palettes_filled_in_029C8E              ;029D62|4C8E9C  |029C8E;

case_MSBs_are_0b11_029D65:
    AND.B #$07                                                ;029D65|2907    |      ; $01 <- byte & 0x7
    STA.B $01                                                 ;029D67|8501    |001F01;
    LDA.B $00                                                 ;029D69|A500    |001F00; the next three bits after the top 0b11 encode a single palette number from 0-7
    LSR A                                                     ;029D6B|4A      |      ;
    AND.B #!PaletteValueBitmask                               ;029D6C|291C    |      ;
    BRA +                                                     ;029D6E|8003    |029D73;
LOOP_029D70:
    JSR.W get_palette_num_from_buffer_in_0F_11_029EC5         ;029D70|20C59E  |029EC5; on all subsequent entries, get a palette number based on bits in $0F-$11
; + ORA.W DecompHighBytesBuffer,Y                             ;029D73|190060  |7E6000; OR in the palette number to the tilemap entry
  ; STA.W DecompHighBytesBuffer,Y                             ;029D76|990060  |7E6000;
  ; INY                                                       ;029D79|C8      |      ;
  ; DEC.B $01                                                 ;029D7A|C601    |001F01;
  + jsr StoreOnePaletteXYAndDec01
    BPL LOOP_029D70                                           ;029D7C|10F2    |029D70;
    JMP.W check_if_all_palettes_filled_in_029C8E              ;029D7E|4C8E9C  |029C8E;

; ------------------------------------------------------------------------------

propagate_XOR_down_tilemap_columns_029D81:
    LDX.B StartOffsetOfDecompTilemap                          ;029D81|A607    |001F07;
    LDY.W #!TilemapSize-!OneTileRow-1                         ;029D83|A05F03  |      ; loop counter of 0x360
LOOP_propagate_XOR_down_029D86:
    LDA.W DecompHighBytesBuffer,X                             ;029D86|BD0060  |7E6000; for each top byte, XOR the top byte into the byte 0x20 bytes ahead of it
    EOR.W DecompHighBytesBuffer+!OneTileRow,X                 ;029D89|5D2060  |7E6020;
    STA.W DecompHighBytesBuffer+!OneTileRow,X                 ;029D8C|9D2060  |7E6020;
    INX                                                       ;029D8F|E8      |      ;
    DEY                                                       ;029D90|88      |      ;
    BPL LOOP_propagate_XOR_down_029D86                        ;029D91|10F3    |029D86;

; ------------------------------------------------------------------------------

get_X_Y_flip_flags_for_tilemap_029D93:
  ; LDY.B StartOffsetOfDecompTilemap                          ;029D93|A407    |001F07;
  ; STZ.B NumBufferValsLeft                                   ;029D95|640E    |001F0E;
  ; LSR.B CompressedBlockFlags                                ;029D97|460B    |001F0B; check flag for uncompressed data
    jsr GoToTilemapStartAndGetCompressionFlag
    BCS get_X_Y_flip_flags_byte_029DB7                        ;029D99|B01C    |029DB7;
case_uncompressed_X_Y_flip_bits_029D9B:
    LDX.W #!TilemapSize-1                                     ;029D9B|A27F03  |      ; if clear, then the next 0x380 / 8 * 2 = 0xE0 bytes have the X/Y flip bits
  - JSR.W get_two_bit_val_from_buffer_in_bits_76_029EAA       ;029D9E|20AA9E  |029EAA;
  ; AND.B #!XYFlipValueBitmask                                ;029DA1|29C0    |      ;
  ; ORA.W DecompHighBytesBuffer,Y                             ;029DA3|190060  |7E6000;
  ; STA.W DecompHighBytesBuffer,Y                             ;029DA6|990060  |7E6000;
  ; INY                                                       ;029DA9|C8      |      ;
    jsr StoreOnePaletteXY
    DEX                                                       ;029DAA|CA      |      ;
    BPL -                                                     ;029DAB|10F1    |029D9E;
    JMP.W PLP_RTL_done_getting_tilemap_029EA8                 ;029DAD|4CA89E  |029EA8;

check_if_got_all_XY_bytes_029DB0:
    CPY.B EndOffsetOfDecompTilemap                            ;029DB0|C40C    |001F0C;
    BCC get_X_Y_flip_flags_byte_029DB7                        ;029DB2|9003    |029DB7;
    JMP.W PLP_RTL_done_getting_tilemap_029EA8                 ;029DB4|4CA89E  |029EA8;

get_X_Y_flip_flags_byte_029DB7:
  ; LDA.B [CompressedTilemapPtr]                              ;029DB7|A704    |001F04; $00 <- byte from pointer
  ; INC.B CompressedTilemapPtr                                ;029DB9|E604    |001F04;
  ; BNE +                                                     ;029DBB|D003    |029DC0;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029DBD|20699A  |029A69;
; + STA.B $00                                                 ;029DC0|8500    |001F00;
    jsr GetByteFromPtrAndBankWrap
    STA.B $00

    BIT.B #$C0                                                ;029DC2|89C0    |      ; test MSBs for it
    BEQ case_MSBs_are_0b00_029DE9                             ;029DC4|F023    |029DE9; are both bits 7 and 6 clear?
    CMP.B #$C0                                                ;029DC6|C9C0    |      ;
    BCS case_MSBs_are_0b11_go_to_029E8B                       ;029DC8|B01C    |029DE6; are both bits 7 and 6 set?
    BIT.B #$80                                                ;029DCA|8980    |      ;
    BNE case_MSBs_are_0b10_029DD8                             ;029DCC|D00A    |029DD8; is only bit 7 set?
case_MSBs_are_0b01_029DCE:
    BIT.B #$20                                                ;029DCE|8920    |      ; here, only bit 6 should be set
    BNE case_MSBs_are_0b011_029E1C                            ;029DD0|D04A    |029E1C;
case_MSBs_are_0b010_029DD2:
    BIT.B #$10                                                ;029DD2|8910    |      ;
    BEQ case_MSBs_are_0b0100_029E09                           ;029DD4|F033    |029E09;
    BRA case_MSBs_are_0b0101_029E3C                           ;029DD6|8064    |029E3C;
case_MSBs_are_0b10_029DD8:
    BIT.B #$20                                                ;029DD8|8920    |      ;
    BEQ case_MSBs_are_0b100_go_to_029E61                      ;029DDA|F007    |029DE3;
case_MSBs_are_0b101_029DDC:
    BIT.B #$10                                                ;029DDC|8910    |      ;
    BEQ case_MSBs_are_0b1010_029E27                           ;029DDE|F047    |029E27;
case_MSBs_are_0b1011_go_to_029E6D:
    JMP.W case_MSBs_are_0b1011_029E6D                         ;029DE0|4C6D9E  |029E6D;
case_MSBs_are_0b100_go_to_029E61:
    JMP.W case_MSBs_are_0b100_029E61                          ;029DE3|4C619E  |029E61;
case_MSBs_are_0b11_go_to_029E8B:
    JMP.W case_MSBs_are_0b11_029E8B                           ;029DE6|4C8B9E  |029E8B;

case_MSBs_are_0b00_029DE9:
  ; CMP.B #$3F                                                ;029DE9|C93F    |      ; if MSBs are 0b00, skip bytes
  ; BNE got_num_bytes_to_skip_029DF6                          ;029DEB|D009    |029DF6; if 3F, read another byte for how many bytes to skip
; case_byte_is_3F_029DED:
;   LDA.B [CompressedTilemapPtr]                              ;029DED|A704    |001F04; otherwise, use the byte as is for the skip count
;   INC.B CompressedTilemapPtr                                ;029DEF|E604    |001F04;
;   BNE got_num_bytes_to_skip_029DF6                          ;029DF1|D003    |029DF6;
;   JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029DF3|20699A  |029A69;
  ; jsr GetByteFromPtrAndBankWrap
; got_num_bytes_to_skip_029DF6:
  ; STA.B $01                                                 ;029DF6|8501    |001F01; store skip count
; CODE_skip_bytes_based_on_01_029DF8:
  ; INY                                                       ;029DF8|C8      |      ; Y <- Y + 1 + skip count
  ; STY.B $02                                                 ;029DF9|8402    |001F02;
  ; TYA                                                       ;029DFB|98      |      ;
  ; CLC                                                       ;029DFC|18      |      ;
  ; ADC.B $01                                                 ;029DFD|6501    |001F01;
  ; STA.B $02                                                 ;029DFF|8502    |001F02;
  ; BCC +                                                     ;029E01|9002    |029E05;
  ; INC.B $03                                                 ;029E03|E603    |001F03; do 16-bit add with 8 bit arithmetic
; + LDY.B $02                                                 ;029E05|A402    |001F02;
    jsr UseValue0_ForPaletteXY
    BRA check_if_got_all_XY_bytes_029DB0                      ;029E07|80A7    |029DB0;

case_MSBs_are_0b0100_029E09:
  ; AND.B #$0F                                                ;029E09|290F    |      ; $01 <- (byte & 0xF)
  ; STA.B $01                                                 ;029E0B|8501    |001F01;
  ; REP #$20                                                  ;029E0D|C220    |      ;
  ; TYA                                                       ;029E0F|98      |      ; X <- Y - 0x20 = look one tile row up
  ; SEC                                                       ;029E10|38      |      ;
  ; SBC.W #!OneTileRow                                        ;029E11|E92000  |      ;
  ; TAX                                                       ;029E14|AA      |      ;
  ; SEP #$20                                                  ;029E15|E220    |      ;
    jsr StoreLowNibbleTo01AndGetOffsetToRowUp
    LDA.W DecompHighBytesBuffer,X                             ;029E17|BD0060  |7E6000; get the X/Y flip flags from one tile row up
    BRA insert_X_Y_flip_bits_and_skip_bytes_029E31            ;029E1A|8015    |029E31;

case_MSBs_are_0b011_029E1C:
    AND.B #$07                                                ;029E1C|2907    |      ; $01 <- (byte & 0x7)
    STA.B $01                                                 ;029E1E|8501    |001F01;
    LDA.B $00                                                 ;029E20|A500    |001F00; shift out the leading 0b011 and get X/Y flip bits in position
    ASL A                                                     ;029E22|0A      |      ;
    ASL A                                                     ;029E23|0A      |      ;
    ASL A                                                     ;029E24|0A      |      ;
    BRA insert_X_Y_flip_bits_and_skip_bytes_029E31            ;029E25|800A    |029E31;

case_MSBs_are_0b1010_029E27:
    AND.B #$0F                                                ;029E27|290F    |      ; $01 <- (byte & 0xF) + 8 -- ignore the top "A" nibble
    CLC                                                       ;029E29|18      |      ;
    ADC.B #$08                                                ;029E2A|6908    |      ;
    STA.B $01                                                 ;029E2C|8501    |001F01;
    JSR.W get_two_bit_val_from_buffer_in_bits_76_029EAA       ;029E2E|20AA9E  |029EAA; get the X/Y flip bits
insert_X_Y_flip_bits_and_skip_bytes_029E31:
    AND.B #!XYFlipValueBitmask                                ;029E31|29C0    |      ;
  ; ORA.W DecompHighBytesBuffer,Y                             ;029E33|190060  |7E6000;
  ; STA.W DecompHighBytesBuffer,Y                             ;029E36|990060  |7E6000;
  ; INY                                                       ;029E39|C8      |      ;
  ; BRA CODE_skip_bytes_based_on_01_029DF8                    ;029E3A|80BC    |029DF8;
    jsr StoreOnePaletteXY
    jsr skip_bytes_based_on_01
    jmp.w check_if_got_all_XY_bytes_029DB0                    ;029CE5|80A7    |029C8E;

case_MSBs_are_0b0101_029E3C:
  ; AND.B #$0F                                                ;029E3C|290F    |      ; $01 <- byte & 0xF
  ; STA.B $01                                                 ;029E3E|8501    |001F01;
  ; REP #$20                                                  ;029E40|C220    |      ;
  ; TYA                                                       ;029E42|98      |      ; X <- Y - 0x20 = look one tile row up
  ; SEC                                                       ;029E43|38      |      ;
  ; SBC.W #!OneTileRow                                        ;029E44|E92000  |      ;
  ; TAX                                                       ;029E47|AA      |      ;
  ; SEP #$20                                                  ;029E48|E220    |      ;
    jsr StoreLowNibbleTo01AndGetOffsetToRowUp
  ; LDA.W DecompHighBytesBuffer,X                             ;029E4A|BD0060  |7E6000; $02 <- X Y flip bits from one tile row up
  ; AND.B #!XYFlipValueBitmask                                ;029E4D|29C0    |      ;
  ; STA.B $02                                                 ;029E4F|8502    |001F02;
; LOOP_copy_prev_X_Y_flip_029E51:
  ; LDA.B $02                                                 ;029E51|A502    |001F02; copy in the X Y flip bits into next however many bytes as specified
  ; ORA.W DecompHighBytesBuffer,Y                             ;029E53|190060  |7E6000;
  ; STA.W DecompHighBytesBuffer,Y                             ;029E56|990060  |7E6000;
  ; INY                                                       ;029E59|C8      |      ;
  ; DEC.B $01                                                 ;029E5A|C601    |001F01;
  ; BPL LOOP_copy_prev_X_Y_flip_029E51                        ;029E5C|10F3    |029E51;
    lda #!XYFlipValueBitmask
    jsr RepeatPreviousPaletteXY
    JMP.W check_if_got_all_XY_bytes_029DB0                    ;029E5E|4CB09D  |029DB0;

case_MSBs_are_0b100_029E61:
    AND.B #$07                                                ;029E61|2907    |      ; repeat count = (byte & 0x7) + 1
    INC A                                                     ;029E63|1A      |      ;
    STA.B $01                                                 ;029E64|8501    |001F01;
    LDA.B $00                                                 ;029E66|A500    |001F00; X/Y value to repeat = (byte << 3) & 0xC0
    ASL A                                                     ;029E68|0A      |      ;
    ASL A                                                     ;029E69|0A      |      ;
    ASL A                                                     ;029E6A|0A      |      ;
    BRA got_X_Y_flip_bits_029E77                              ;029E6B|800A    |029E77;

case_MSBs_are_0b1011_029E6D:
    AND.B #$0F                                                ;029E6D|290F    |      ; repeat count = (byte & 0xF) + 9
    CLC                                                       ;029E6F|18      |      ;
    ADC.B #$09                                                ;029E70|6909    |      ;
    STA.B $01                                                 ;029E72|8501    |001F01;
    JSR.W get_two_bit_val_from_buffer_in_bits_76_029EAA       ;029E74|20AA9E  |029EAA; X/Y value to repeat = get from buffer
got_X_Y_flip_bits_029E77:
    AND.B #!XYFlipValueBitmask                                ;029E77|29C0    |      ;
  ; STA.B $02                                                 ;029E79|8502    |001F02;
; LOOP_repeat_X_Y_flip_bits_029E7B:
  ; LDA.B $02                                                 ;029E7B|A502    |001F02;
  ; ORA.W DecompHighBytesBuffer,Y                             ;029E7D|190060  |7E6000;
  ; STA.W DecompHighBytesBuffer,Y                             ;029E80|990060  |7E6000;
  ; INY                                                       ;029E83|C8      |      ;
  ; DEC.B $01                                                 ;029E84|C601    |001F01;
  ; BPL LOOP_repeat_X_Y_flip_bits_029E7B                      ;029E86|10F3    |029E7B;
    jsr RepeatNewPaletteXY
    JMP.W check_if_got_all_XY_bytes_029DB0                    ;029E88|4CB09D  |029DB0;

case_MSBs_are_0b11_029E8B:
    AND.B #$0F                                                ;029E8B|290F    |      ; $01 <- byte & 0xF
    STA.B $01                                                 ;029E8D|8501    |001F01;
    LDA.B $00                                                 ;029E8F|A500    |001F00; shift X/Y flip bits into position
    ASL A                                                     ;029E91|0A      |      ;
    ASL A                                                     ;029E92|0A      |      ;
    BRA +                                                     ;029E93|8003    |029E98;
LOOP_insert_X_Y_flip_bits_029E95:
    JSR.W get_two_bit_val_from_buffer_in_bits_76_029EAA       ;029E95|20AA9E  |029EAA; on subsequent iterations, get X/Y flip bits from buffer
  + AND.B #!XYFlipValueBitmask                                ;029E98|29C0    |      ; write the X/Y flip bits for tilemap entry
  ; ORA.W DecompHighBytesBuffer,Y                             ;029E9A|190060  |7E6000;
  ; STA.W DecompHighBytesBuffer,Y                             ;029E9D|990060  |7E6000;
  ; INY                                                       ;029EA0|C8      |      ;
  ; DEC.B $01                                                 ;029EA1|C601    |001F01;
    jsr StoreOnePaletteXYAndDec01
    BPL LOOP_insert_X_Y_flip_bits_029E95                      ;029EA3|10F0    |029E95;
    JMP.W check_if_got_all_XY_bytes_029DB0                    ;029EA5|4CB09D  |029DB0;

PLP_RTL_done_getting_tilemap_029EA8:
; this only gets called within the current bank (02); change RTL to RTS
    PLP                                                       ;029EA8|28      |      ;
  ; RTL                                                       ;029EA9|6B      |      ;
    rts

; ------------------------------------------------------------------------------

get_two_bit_val_from_buffer_in_bits_76_029EAA:
    DEC.B NumBufferValsLeft                                   ;029EAA|C60E    |001F0E; check if still pairs of bits left in buffer
    BPL case_shift_in_bit_pair_029EBE                         ;029EAC|1010    |029EBE;
case_fill_buffer_with_byte_029EAE:
    LDA.B #$03                                                ;029EAE|A903    |      ; if negative, set to 0x03
    STA.B NumBufferValsLeft                                   ;029EB0|850E    |001F0E;
  ; LDA.B [CompressedTilemapPtr]                              ;029EB2|A704    |001F04; $0F <- next byte from pointer
  ; INC.B CompressedTilemapPtr                                ;029EB4|E604    |001F04;
  ; BNE +                                                     ;029EB6|D003    |029EBB;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029EB8|20699A  |029A69;
; + STA.B BufferForTwoBitVals                                 ;029EBB|850F    |001F0F;
  ; RTS                                                       ;029EBD|60      |      ;
    jsr GetByteFromPtrAndBankWrap
    bra +
case_shift_in_bit_pair_029EBE:
    LDA.B BufferForTwoBitVals                                 ;029EBE|A50F    |001F0F; otherwise, left shift $0F by two to get next two bits in position
    ASL A                                                     ;029EC0|0A      |      ;
    ASL A                                                     ;029EC1|0A      |      ;
  + STA.B BufferForTwoBitVals                                 ;029EC2|850F    |001F0F;
    and #!XYFlipValueBitmask
    RTS                                                       ;029EC4|60      |      ;

; ------------------------------------------------------------------------------

get_palette_num_from_buffer_in_0F_11_029EC5:
    DEC.B NumBufferValsLeft                                   ;029EC5|C60E    |001F0E; if no bits left in 3 byte buffer, fill it
    BPL +                                                     ;029EC7|1025    |029EEE;

    LDA.B #$07                                                ;029EC9|A907    |      ; set num bits left to 7
    STA.B NumBufferValsLeft                                   ;029ECB|850E    |001F0E;

  ; LDA.B [CompressedTilemapPtr]                              ;029ECD|A704    |001F04; read the next three bytes from pointer into $0F-$11
  ; INC.B CompressedTilemapPtr                                ;029ECF|E604    |001F04;
  ; BNE ++                                                    ;029ED1|D003    |029ED6;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029ED3|20699A  |029A69;
;++ STA.B BufferForPaletteBit0Sets                            ;029ED6|850F    |001F0F;
    jsr GetByteFromPtrAndBankWrap
    STA.B BufferForPaletteBit0Sets                            ;029ED6|850F    |001F0F;

  ; LDA.B [CompressedTilemapPtr]                              ;029ED8|A704    |001F04;
  ; INC.B CompressedTilemapPtr                                ;029EDA|E604    |001F04;
  ; BNE ++                                                    ;029EDC|D003    |029EE1;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029EDE|20699A  |029A69;
;++ STA.B BufferForPaletteBit1Sets                            ;029EE1|8510    |001F10;
    jsr GetByteFromPtrAndBankWrap
    STA.B BufferForPaletteBit1Sets

  ; LDA.B [CompressedTilemapPtr]                              ;029EE3|A704    |001F04;
  ; INC.B CompressedTilemapPtr                                ;029EE5|E604    |001F04;
  ; BNE ++                                                    ;029EE7|D003    |029EEC;
  ; JSR.W bank_wrap_ptr_in_04_to_06_029A69                    ;029EE9|20699A  |029A69;
;++ STA.B BufferForPaletteBit2Sets                            ;029EEC|8511    |001F11;
    jsr GetByteFromPtrAndBankWrap
    STA.B BufferForPaletteBit2Sets

  + LDA.B #$00                                                ;029EEE|A900    |      ; each of the 3 MSBs come together to create a palette number from 0-7
    ASL.B BufferForPaletteBit2Sets                            ;029EF0|0611    |001F11;
    ROL A                                                     ;029EF2|2A      |      ;
    ASL.B BufferForPaletteBit1Sets                            ;029EF3|0610    |001F10;
    ROL A                                                     ;029EF5|2A      |      ;
    ASL.B BufferForPaletteBit0Sets                            ;029EF6|060F    |001F0F;
    ROL A                                                     ;029EF8|2A      |      ;

    ASL A                                                     ;029EF9|0A      |      ; shift left twice to put into correct bit position for tilemap entry standard
    ASL A                                                     ;029EFA|0A      |      ;
    RTS                                                       ;029EFB|60      |      ;

; ------------------------------------------------------------------------------
; additions here to reuse code

GoToTilemapStartAndGetCompressionFlag:
    LDY.B StartOffsetOfDecompTilemap
  ; same as doing STZ.B CurrentLowByte
    STZ.B NumBufferValsLeft
    LSR.B CompressedBlockFlags
    rts

GetByteFromPtrAndBankWrap:
    php
    sep #$20
    lda.b [CompressedTilemapPtr]
    inc.b CompressedTilemapPtr
    bne +
    jsr.w bank_wrap_ptr_in_04_to_06_029A69
  + plp
    rts

StoreLowByteAndDec00:
    sta.w DecompLowBytesBuffer,y
    iny
    dec $00
    rts

StoreLowNibbleTo01AndGetOffsetToRowUp:
    AND.B #$0F
    STA.B $01
GetOffsetToOneRowUpInXReg:
    REP #$20
    TYA
    SEC
    SBC.W #!OneTileRow
    TAX
    SEP #$20
    rts

UseValue0_ForPaletteXY:
; same as for 7F case with low bytes; fully use extra byte to extend size range
; from 0x41-0x100 to 0x41-0x140; needs to be a little different due to how data
; is laid out in memory; calculate Y <- Y + 1 + [byte] + [0x40 if byte is 0x3F]
; also notice modification to encode (size - 2) if in range 0x2-0x40 or encode
; (size - 0x41) if in range 0x41-0x140
    CMP.B #$3F
    BNE +
case_byte_is_3F:
    rep #$21        ; clear carry, M=0
    tya
    adc #$0041-2    ; see the two INYs below
    tay
    sep #$20
    jsr GetByteFromPtrAndBankWrap
  + STA.B $01
    INY
skip_bytes_based_on_01:
    INY
    STY.B $02
    TYA
    CLC
    ADC.B $01
    STA.B $02
    BCC +
    INC.B $03
  + LDY.B $02
    rts

StoreOnePaletteXY:
    ORA.W DecompHighBytesBuffer,Y
StoreToHighBytesBuffer:
    STA.W DecompHighBytesBuffer,Y
    INY
    rts

StoreOnePaletteXYAndDec01:
    jsr StoreOnePaletteXY
    bra +
StoreToHighBytesBufferAndDec01:
    jsr StoreToHighBytesBuffer
  + dec $01
    rts

RepeatPreviousPaletteXY:
; A contains bitmask for what kind of data to use
    and.w DecompHighBytesBuffer,X
RepeatNewPaletteXY:
    STA.B $02
  - LDA.B $02
  ; ORA.W DecompHighBytesBuffer,Y
  ; STA.W DecompHighBytesBuffer,Y
  ; INY
  ; DEC.B $01
    jsr StoreOnePaletteXYAndDec01
    BPL -
    rts

; I'd brought this over to be reused between just the "repeat new palette or X/Y
; value" code, but this is the same code as after the AND instruction above
; RepeatNewPaletteXY:
    ; STA.B $02
  ; - LDA.B $02
    ; ORA.W DecompHighBytesBuffer,Y
    ; STA.W DecompHighBytesBuffer,Y
    ; INY
    ; DEC.B $01
    ; BPL -
    ; rts
