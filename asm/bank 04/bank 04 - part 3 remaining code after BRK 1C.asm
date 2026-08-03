includefrom "MAIN rewrite bank 04.asm"

set_up_DMA_from_0974_to_OAM_04A1AF:
    PHD                 ;04A1AF|0B      |      ;
    LDA.W #$1676        ;04A1B0|A97616  |      ;
    TCD                 ;04A1B3|5B      |      ;
    LDA.W #$000D        ;04A1B4|A90D00  |      ; BRK flags 0D
    STA.B $00           ;04A1B7|8500    |001676; write to OAM address 000
    STZ.B $01           ;04A1B9|6401    |001677;
    LDA.W #$0220        ;04A1BB|A92002  |      ; DMA transfers 0x220 bytes = fill all of OAM
    STA.B $03           ;04A1BE|8503    |001679;
    LDA.W #$0000        ;04A1C0|A90000  |      ; DMA parameters 00 - bit 5 clear = src address is $0974
    STA.B $05           ;04A1C3|8505    |00167B;
    BRK #$12            ;04A1C5|0012    |      ;
    PLD                 ;04A1C7|2B      |      ;
    RTL                 ;04A1C8|6B      |      ;

pushpc
org $03d0a9
    jsl set_up_DMA_from_0974_to_OAM_04A1AF
org $03d3ac
    jsl set_up_DMA_from_0974_to_OAM_04A1AF
org $03da5f
    jsl set_up_DMA_from_0974_to_OAM_04A1AF
org $03e0d7
    jsl set_up_DMA_from_0974_to_OAM_04A1AF
org $03e11b
    jsl set_up_DMA_from_0974_to_OAM_04A1AF
pullpc

; ------------------------------------------------------------------------------

set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9:
    PHD                 ;04A1C9|0B      |      ;
    LDA.W #$1676        ;04A1CA|A97616  |      ;
    TCD                 ;04A1CD|5B      |      ;
    STX.B $01           ;04A1CE|8601    |001677; X has VRAM address
    STY.B $03           ;04A1D0|8403    |001679; Y has DMA transfer size
    SEP #$20            ;04A1D2|E220    |      ;
    LDA.B #$9B          ;04A1D4|A99B    |      ; flags
    STA.B $00           ;04A1D6|8500    |001676;
    LDA.B #$01          ;04A1D8|A901    |      ; DMA parameters = transfer one word [xx, xx + 1] at a time
    STA.B $05           ;04A1DA|8505    |00167B;
    LDA.B #$80          ;04A1DC|A980    |      ; VRAM address increment after high byte
    STA.B $09           ;04A1DE|8509    |00167F;
    REP #$20            ;04A1E0|C220    |      ;
    BRK #$0C            ;04A1E2|000C    |      ; set up, but do not perform, the DMA
    PLD                 ;04A1E4|2B      |      ;
    RTL                 ;04A1E5|6B      |      ;

pushpc
org $038393
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $0383b0
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $0383f1
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03841f
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $038435
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03846e
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03848a
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $0384d3
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $0384ee
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $0385f3
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $038655
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $038964
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $0394c3
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03951d
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $0396d5
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $039714
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03985d
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03991c
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $039e62
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $039e7d
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $039e9b
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $039eb6
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03a08a
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03a0a1
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03a0b8
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03a167
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03a212
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03a273
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03a2ee
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03aa9d
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03d24c
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03d31b
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03d352
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03d558
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03d945
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
org $03e085
    jsl set_up_VRAM_DMA_to_send_Y_bytes_to_VRAM_addr_X_04A1C9
pullpc

; ------------------------------------------------------------------------------

; UNUSED_set_up_and_do_VRAM_DMA_with_words_04A1E6:
    ; PHD                 ;04A1E6|0B      |      ;
    ; LDA.W #$1676        ;04A1E7|A97616  |      ;
    ; TCD                 ;04A1EA|5B      |      ;
    ; STX.B $01           ;04A1EB|8601    |001677; X has VRAM address
    ; STY.B $03           ;04A1ED|8403    |001679; Y has DMA transfer size
    ; SEP #$20            ;04A1EF|E220    |      ;
    ; LDA.B #$DB          ;04A1F1|A9DB    |      ; flags
    ; STA.B $00           ;04A1F3|8500    |001676;
    ; LDA.B #$01          ;04A1F5|A901    |      ; DMA parameters = send 1 word [xx, xx + 1]
    ; STA.B $05           ;04A1F7|8505    |00167B;
    ; LDA.B #$80          ;04A1F9|A980    |      ; VRAM address increment after high byte
    ; STA.B $09           ;04A1FB|8509    |00167F;
    ; REP #$20            ;04A1FD|C220    |      ;
    ; BRK #$0C            ;04A1FF|000C    |      ; set up DMA
    ; BRK #$00            ;04A201|0000    |      ; execute it?
    ; dw $0008            ;04A203|        |      ;
    ; PLD                 ;04A205|2B      |      ;
    ; RTL                 ;04A206|6B      |      ;

; UNUSED_set_up_VRAM_DMA_transfer_block_to_low_bytes_04A207:
    ; PHD                 ;04A207|0B      |      ;
    ; LDA.W #$1676        ;04A208|A97616  |      ;
    ; TCD                 ;04A20B|5B      |      ;
    ; STX.B $01           ;04A20C|8601    |001677; X has VRAM address
    ; STY.B $03           ;04A20E|8403    |001679; Y has DMA transfer size
    ; SEP #$20            ;04A210|E220    |      ;
    ; LDA.B #$9B          ;04A212|A99B    |      ; flags = 0x9B
    ; STA.B $00           ;04A214|8500    |001676;
    ; STZ.B $05           ;04A216|6405    |00167B; DMA parameters 0x00 = transfer block of bytes, one byte at a time
    ; STZ.B $09           ;04A218|6409    |00167F; VRAM address increment after low byte
    ; REP #$20            ;04A21A|C220    |      ;
    ; BRK #$0C            ;04A21C|000C    |      ;
    ; PLD                 ;04A21E|2B      |      ;
    ; RTL                 ;04A21F|6B      |      ;

; UNUSED_set_up_VRAM_DMA_write_block_to_high_bytes_04A220:
    ; PHD                 ;04A220|0B      |      ;
    ; LDA.W #$1676        ;04A221|A97616  |      ;
    ; TCD                 ;04A224|5B      |      ;
    ; STX.B $01           ;04A225|8601    |001677; X has VRAM address
    ; STY.B $03           ;04A227|8403    |001679; Y has DMA transfer size
    ; SEP #$20            ;04A229|E220    |      ;
    ; LDA.B #$9B          ;04A22B|A99B    |      ; flags = 0x9B
    ; STA.B $00           ;04A22D|8500    |001676;
    ; LDA.B #$20          ;04A22F|A920    |      ; DMA parameters (high byte)
    ; STA.B $05           ;04A231|8505    |00167B;
    ; LDA.B #$80          ;04A233|A980    |      ; VRAM address increment after high byte
    ; STA.B $09           ;04A235|8509    |00167F;
    ; REP #$20            ;04A237|C220    |      ;
    ; BRK #$0C            ;04A239|000C    |      ;
    ; PLD                 ;04A23B|2B      |      ;
    ; RTL                 ;04A23C|6B      |      ;

; ------------------------------------------------------------------------------

set_up_VRAM_DMA_to_fill_range_with_single_word_in_A_04A23D:
    STA.W $1686         ;04A23D|8D8616  |7E1686; expect inputs in all of A, X, Y
    PHD                 ;04A240|0B      |      ;
    LDA.W #$1676        ;04A241|A97616  |      ; prepare to call BRK #$0C (set up structure for VRAM DMA)
    TCD                 ;04A244|5B      |      ;
    STX.B $01           ;04A245|8601    |001677; in BRK, $05 <- X = a word offset in VRAM
    STY.B $03           ;04A247|8403    |001679; in BRK, $07 <- Y = transfer size
    SEP #$20            ;04A249|E220    |      ;
    LDA.B #$9B          ;04A24B|A99B    |      ; in BRK, $04 <- 0x9B = flags
    STA.B $00           ;04A24D|8500    |001676;
    LDA.B #$09          ;04A24F|A909    |      ; in BRK, $09 <- 0x09 = DMA parameters = fixed address, unit [xx, xx + 1]
    STA.B $05           ;04A251|8505    |00167B;
    LDA.B #$80          ;04A253|A980    |      ; in BRK, $0D <- 0x80 = VRAM address increment after high byte
    STA.B $09           ;04A255|8509    |00167F;
    LDA.B #$00          ;04A257|A900    |      ; in BRK, $0C <- 0x00 = source data in bank 00
    STA.B $08           ;04A259|8508    |00167E;
    REP #$20            ;04A25B|C220    |      ;
    LDA.W #$1686        ;04A25D|A98616  |      ; in BRK, $0A <- 0x1686 = pointer to data value in A
    STA.B $06           ;04A260|8506    |00167C;
    BRK #$0C            ;04A262|000C    |      ;
    PLD                 ;04A264|2B      |      ;
    RTL                 ;04A265|6B      |      ;

pushpc
org $0383ca
    jsl set_up_VRAM_DMA_to_fill_range_with_single_word_in_A_04A23D
org $038722
    jsl set_up_VRAM_DMA_to_fill_range_with_single_word_in_A_04A23D
org $038983
    jsl set_up_VRAM_DMA_to_fill_range_with_single_word_in_A_04A23D
org $03a18c
    jsl set_up_VRAM_DMA_to_fill_range_with_single_word_in_A_04A23D
org $03a6d2
    jsl set_up_VRAM_DMA_to_fill_range_with_single_word_in_A_04A23D
org $03a6df
    jsl set_up_VRAM_DMA_to_fill_range_with_single_word_in_A_04A23D
org $03bc6e
    jsl set_up_VRAM_DMA_to_fill_range_with_single_word_in_A_04A23D
pullpc

; ------------------------------------------------------------------------------

set_up_VRAM_DMA_to_fill_high_bytes_with_input_in_A_04A266:
    STA.W $1686         ;04A266|8D8616  |7E1686; expect inputs in A, X, Y
    PHD                 ;04A269|0B      |      ;
    LDA.W #$1676        ;04A26A|A97616  |      ;
    TCD                 ;04A26D|5B      |      ;
    STX.B $01           ;04A26E|8601    |001677; in BRK, $05 <- X = a word offset in VRAM
    STY.B $03           ;04A270|8403    |001679; in BRK, $07 <- Y = transfer size
    SEP #$20            ;04A272|E220    |      ;
    LDA.B #$9B          ;04A274|A99B    |      ; in BRK, $04 <- 0x9B = flags
    STA.B $00           ;04A276|8500    |001676;
    LDA.B #$28          ;04A278|A928    |      ; in BRK, $09 <- 0x28 = DMA parameters (high byte, fixed address)
    STA.B $05           ;04A27A|8505    |00167B;
    LDA.B #$00          ;04A27C|A900    |      ; in BRK, $0D <- 0x00 = VRAM address increment after low byte
    STA.B $09           ;04A27E|8509    |00167F;
    LDA.B #$00          ;04A280|A900    |      ; in BRK, $0C <- 0x00 = src data in bank 00
    STA.B $08           ;04A282|8508    |00167E;
    REP #$20            ;04A284|C220    |      ;
    LDA.W #$1686        ;04A286|A98616  |      ; in BRK, $0A <- 0x1686 = pointer to data input in A
    STA.B $06           ;04A289|8506    |00167C;
    BRK #$0C            ;04A28B|000C    |      ;
    PLD                 ;04A28D|2B      |      ;
    RTL                 ;04A28E|6B      |      ;

pushpc
org $0389a3
    jsl set_up_VRAM_DMA_to_fill_high_bytes_with_input_in_A_04A266
org $03bc80
    jsl set_up_VRAM_DMA_to_fill_high_bytes_with_input_in_A_04A266
org $03bc9a
    jsl set_up_VRAM_DMA_to_fill_high_bytes_with_input_in_A_04A266

org $0389ab
  ; jsl identical_copy_of_04A266_code_04A28F
    jsl set_up_VRAM_DMA_to_fill_high_bytes_with_input_in_A_04A266
org $03bc88
  ; jsl identical_copy_of_04A266_code_04A28F
    jsl set_up_VRAM_DMA_to_fill_high_bytes_with_input_in_A_04A266
org $03bca2
  ; jsl identical_copy_of_04A266_code_04A28F
    jsl set_up_VRAM_DMA_to_fill_high_bytes_with_input_in_A_04A266
pullpc

; identical_copy_of_04A266_code_04A28F:
  ; STA.W $1686           ;04A28F|8D8616  |7E1686; expect inputs in A, X, Y (identical code as directly above in $04A266?)
  ; PHD                   ;04A292|0B      |      ;
  ; LDA.W #$1676          ;04A293|A97616  |      ;
  ; TCD                   ;04A296|5B      |      ;
  ; STX.B $01             ;04A297|8601    |001677; in BRK, $05 <- X = a word offset in VRAM
  ; STY.B $03             ;04A299|8403    |001679; in BRK, $07 <- Y = transfer size
  ; SEP #$20              ;04A29B|E220    |      ;
  ; LDA.B #$9B            ;04A29D|A99B    |      ; in BRK, $04 <- 0x9B
  ; STA.B $00             ;04A29F|8500    |001676;
  ; LDA.B #$28            ;04A2A1|A928    |      ; in BRK, $09 <- 0x28
  ; STA.B $05             ;04A2A3|8505    |00167B;
  ; LDA.B #$00            ;04A2A5|A900    |      ; in BRK, $0D <- 0x00
  ; STA.B $09             ;04A2A7|8509    |00167F;
  ; LDA.B #$00            ;04A2A9|A900    |      ; in BRK, $0C <- 0x00
  ; STA.B $08             ;04A2AB|8508    |00167E;
  ; REP #$20              ;04A2AD|C220    |      ;
  ; LDA.W #$1686          ;04A2AF|A98616  |      ; in BRK, $0A <- 0x1686 = pointer to input in A
  ; STA.B $06             ;04A2B2|8506    |00167C;
  ; BRK #$0C              ;04A2B4|000C    |      ;
  ; PLD                   ;04A2B6|2B      |      ;
  ; RTL                   ;04A2B7|6B      |      ;

; ------------------------------------------------------------------------------

; there's only one JSL to here; both the JSL bytes and the code itself (minus
; the RTL) are 4 bytes, so just inject the code there

; call_BRK_00_0001_04A2B8:
    ; BRK #$00            ;04A2B8|0000    |      ;
    ; db $0001            ;04A2BA|        |      ;
    ; RTL                 ;04A2BC|6B      |      ;

pushpc
org $03bb2b
    ; jsl call_BRK_00_0001_04A2B8
    BRK #$00
    dw $0001
    assert pc() == $03bb2f
pullpc

; ------------------------------------------------------------------------------

SUB_04A2BD:
    BRK #$00            ;04A2BD|0000    |      ;
    dw $0010            ;04A2BF|        |      ;
    BRK #$00            ;04A2C1|0000    |      ;
    dw $0001            ;04A2C3|        |      ;
    BRK #$00            ;04A2C5|0000    |      ;
    dw $0001            ;04A2C7|        |      ;
    RTL                 ;04A2C9|6B      |      ;

pushpc
org $3bafe
    jsl SUB_04A2BD
pullpc

; ------------------------------------------------------------------------------

; why did Chunsoft use 4-byte JSLs to reuse the same block of 3 bytes minus the
; RTL? all JSLs to here are in bank 03, so they could've put this code into bank
; 03 (they had the space) and save 72 bytes from using 3-byte JSRs instead

call_BRK_01_24_04A2CA:
    BRK #$01            ;04A2CA|0001    |      ;
    db $24              ;04A2CC|        |      ;
    RTL                 ;04A2CD|6B      |      ;

pushpc
org $0381fa
    jsl call_BRK_01_24_04A2CA
org $0385f8
    jsl call_BRK_01_24_04A2CA
org $038669
    jsl call_BRK_01_24_04A2CA
org $038687
    jsl call_BRK_01_24_04A2CA
org $0386c7
    jsl call_BRK_01_24_04A2CA
org $038784
    jsl call_BRK_01_24_04A2CA
org $0388a2
    jsl call_BRK_01_24_04A2CA
org $038a05
    jsl call_BRK_01_24_04A2CA
org $038a17
    jsl call_BRK_01_24_04A2CA
org $038a8f
    jsl call_BRK_01_24_04A2CA
org $038b05
    jsl call_BRK_01_24_04A2CA
org $038ba3
    jsl call_BRK_01_24_04A2CA
org $038bfb
    jsl call_BRK_01_24_04A2CA
org $038f0c
    jsl call_BRK_01_24_04A2CA
org $038fa8
    jsl call_BRK_01_24_04A2CA
org $038ffd
    jsl call_BRK_01_24_04A2CA
org $03905e
    jsl call_BRK_01_24_04A2CA
org $039178
    jsl call_BRK_01_24_04A2CA
org $039247
    jsl call_BRK_01_24_04A2CA
org $0395f8
    jsl call_BRK_01_24_04A2CA
org $03965e
    jsl call_BRK_01_24_04A2CA
org $03980a
    jsl call_BRK_01_24_04A2CA
org $039838
    jsl call_BRK_01_24_04A2CA
org $0399aa
    jsl call_BRK_01_24_04A2CA
org $039a09
    jsl call_BRK_01_24_04A2CA
org $039a52
    jsl call_BRK_01_24_04A2CA
org $039f87
    jsl call_BRK_01_24_04A2CA
org $039f9d
    jsl call_BRK_01_24_04A2CA
org $03a142
    jsl call_BRK_01_24_04A2CA
org $03a25a
    jsl call_BRK_01_24_04A2CA
org $03a37f
    jsl call_BRK_01_24_04A2CA
org $03a464
    jsl call_BRK_01_24_04A2CA
org $03a5dd
    jsl call_BRK_01_24_04A2CA
org $03a654
    jsl call_BRK_01_24_04A2CA
org $03a752
    jsl call_BRK_01_24_04A2CA
org $03af7b
    jsl call_BRK_01_24_04A2CA
org $03af96
    jsl call_BRK_01_24_04A2CA
org $03b133
    jsl call_BRK_01_24_04A2CA
org $03b1b1
    jsl call_BRK_01_24_04A2CA
org $03b25c
    jsl call_BRK_01_24_04A2CA
org $03b27c
    jsl call_BRK_01_24_04A2CA
org $03b2fa
    jsl call_BRK_01_24_04A2CA
org $03b4e9
    jsl call_BRK_01_24_04A2CA
org $03b509
    jsl call_BRK_01_24_04A2CA
org $03b7b9
    jsl call_BRK_01_24_04A2CA
org $03b83b
    jsl call_BRK_01_24_04A2CA
org $03bc4c
    jsl call_BRK_01_24_04A2CA
org $03bc55
    jsl call_BRK_01_24_04A2CA
org $03c1a7
    jsl call_BRK_01_24_04A2CA
org $03c2d4
    jsl call_BRK_01_24_04A2CA
org $03c2d9
    jsl call_BRK_01_24_04A2CA
org $03c2f1
    jsl call_BRK_01_24_04A2CA
org $03c34d
    jsl call_BRK_01_24_04A2CA
org $03c365
    jsl call_BRK_01_24_04A2CA
org $03c3de
    jsl call_BRK_01_24_04A2CA
org $03c3f6
    jsl call_BRK_01_24_04A2CA
org $03c461
    jsl call_BRK_01_24_04A2CA
org $03c7ba
    jsl call_BRK_01_24_04A2CA
org $03d194
    jsl call_BRK_01_24_04A2CA
org $03d3a4
    jsl call_BRK_01_24_04A2CA
org $03d8d5
    jsl call_BRK_01_24_04A2CA
org $03dbac
    jsl call_BRK_01_24_04A2CA
org $03dbee
    jsl call_BRK_01_24_04A2CA
org $03dcfd
    jsl call_BRK_01_24_04A2CA
org $03dd55
    jsl call_BRK_01_24_04A2CA
org $03dd97
    jsl call_BRK_01_24_04A2CA
org $03ddb2
    jsl call_BRK_01_24_04A2CA
org $03de3f
    jsl call_BRK_01_24_04A2CA
org $03de4a
    jsl call_BRK_01_24_04A2CA
org $03de55
    jsl call_BRK_01_24_04A2CA
org $03de60
    jsl call_BRK_01_24_04A2CA
org $03e271
    jsl call_BRK_01_24_04A2CA
pullpc

; ------------------------------------------------------------------------------

; same idea as for $04A2B8 above
; call_BRK_03_0CA0_only_allow_Up_Down_A_L_04A2CE:
    ; BRK #$03            ;04A2CE|0003    |      ;
    ; dw $0CA0            ;04A2D0|        |      ;
    ; RTL                 ;04A2D2|6B      |      ;

pushpc
org $03829f
    brk #$03
    dw $0ca0
assert pc() == $0382a3
pullpc

; ------------------------------------------------------------------------------

; yet again the same idea as for $04A2B8 above
; call_BRK_03_0000_prevent_all_input_04A2D3:
    ; BRK #$03            ;04A2D3|0003    |      ;
    ; dw $0000            ;04A2D5|        |      ;
    ; RTL                 ;04A2D7|6B      |      ;

pushpc
org $0382ee
    brk #$03
    dw $0000
assert pc() == $0382f2
pullpc

; ------------------------------------------------------------------------------

init_BG3_for_text_and_copy_text_colors_to_CGRAM_04A2D8:
    PHD                 ;04A2D8|0B      |      ;
    PHB                 ;04A2D9|8B      |      ;
    LDA.W #$1656        ;04A2DA|A95616  |      ;
    TCD                 ;04A2DD|5B      |      ;
    PEA.W $0101         ;04A2DE|F40101  |010101;
    PLB                 ;04A2E1|AB      |      ;
    PLB                 ;04A2E2|AB      |      ;
    JSL.L $00ACE7       ;04A2E3|22E7AC00|00ACE7; init BG3 tilemap for text, run CODE 1026
    JSL.L $008D44       ;04A2E7|22448D00|008D44; 
    PLB                 ;04A2EB|AB      |      ;
    PLD                 ;04A2EC|2B      |      ;
    RTL                 ;04A2ED|6B      |      ;

pushpc
org $008ba8
    jsl init_BG3_for_text_and_copy_text_colors_to_CGRAM_04A2D8
org $00b22a
    jsl init_BG3_for_text_and_copy_text_colors_to_CGRAM_04A2D8
pullpc
; also one JSL here near the beginning of bank 04

; ------------------------------------------------------------------------------

; UNUSED_call_01D8E9_with_input_in_A_04A2EE:
    ; AND.W #$00FF                          ;04A2EE|29FF00  |      ;
    ; STA.B $00                             ;04A2F1|8500    |000000;
    ; JSL.L SUB_takes_gfx_ID_value_01D8E9   ;04A2F3|22E9D801|01D8E9;
    ; RTL                                   ;04A2F7|6B      |      ;
