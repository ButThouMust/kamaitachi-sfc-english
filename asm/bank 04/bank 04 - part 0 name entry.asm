includefrom "MAIN rewrite bank 04.asm"

org $008eb8
code_3B_print_input_03_008EB8:
    brk #$00
    dw $0001
    jsl $1d829
    bcs code_3B_print_input_03_008EB8

    ldx #$0000
; the code happens to let me reuse three JSLs by JSRing to them
  ; jsl set_up_VRAM_for_name_entry_screen_player_00_killer_02_048122
  ; jsl $01d946
  ; jsl handle_whole_sequence_to_enter_names_or_a_name_048000
    jsr.w +
    jsl $01d853
    rts

code_3B_print_input_04_008ED6:
    ldx #$0002
  + jsl set_up_VRAM_for_name_entry_screen_player_00_killer_02_048122
    jsl $01d946
    jsl handle_whole_sequence_to_enter_names_or_a_name_048000
    rts

assert pc() <= $008ee6
    fillbyte $ff
    fill $008ee6-pc()

org $008dd3+2*$03
    dw code_3B_print_input_03_008EB8
    dw code_3B_print_input_04_008ED6

; ------------------------------------------------------------------------------

; this requires some new definitions to accommodate the one-byte text encoding
; for names as well as the longer character limits

!DecompressedNameFontTextX = $00
!DecompressedNameFontTextY = $A0
!WramOffsetForDecompressingNameFont = $40*!DecompressedNameFontTextY+2*!DecompressedNameFontTextX
!WramLocationForDecompressingNameFont = $7f0000+!WramOffsetForDecompressingNameFont
!WidthOfDecompressedNameFontIn16x16Tiles = $08

; I want to be able to enforce a different character limit for names depending
; on whether entering one for Tooru/Mari (7) or the killer guess (10)
; - the 7 is because you have to print "Tooru & Mari" in one line on the file
;   select, and also because there are situations where it's important to be
;   able to print two names on a single line when reading text in the story
; - the 10 is because this is the most characters I could get on screen for
;   entering a name while repeating the widest possible character and having
;   the player's input still fit in the name box on screen, as well as still
;   being usable for entering any one character's first/last name in the story
; - nice thing about this new system: you can just modify the values here
!CharLimitForNonKillerNameEntry = $07
!CharLimitForKillerNameEntry = $0A

; old: use a single unified character limit of 10
; !CharLimitForNameEntry = $0A

; the buffer size in bytes stays consistent regardless of the character limit(s)
!NameBufferSize = $0C

; another consequence of changing the character limit is that I unfortunately
; have to disable the sprite of a box that highlights the position in the name
; where a character will be inserted; easiest to just set it off screen
!OffScreenForSprite = $e000

; ------------------------------------------------------------------------------

org $048000
handle_whole_sequence_to_enter_names_or_a_name_048000:
    PHD                                                                ;048000|0B      |      ; X contains input value splitting off between Tooru/Mari or the killer
    COP #$00                                                           ;048001|0200    |      ;
    db $01                                                             ;048003|        |      ;
    PHP                                                                ;048004|08      |      ;
    REP #$30                                                           ;048005|C230    |      ;
    PHA : PHX : PHY
    STX.B menu_type_00_tooru_mari_02_killer-$102b                      ;04800A|8600    |00102B;
  ; JSL.L set_up_OAM_and_code_grid_for_name_entry_buttons_0482DC       ;04800C|22DC8204|0482DC;
    JSR.W set_up_OAM_and_code_grid_for_name_entry_buttons_0482DC
    LDA.B menu_type_00_tooru_mari_02_killer-$102b                      ;048010|A500    |00102B; check if entering name(s) for Tooru/Mari ($00 == 0x00), or the killer ($00 != 0x00)
    BNE CODE_prepare_to_let_player_input_name_048029                   ;048012|D015    |048029;
case_not_entering_name_of_killer_048014:
    LDA.W current_save_file_num_0421                                   ;048014|AD2104  |010421; copy current save file into scratchpad save
    BRK #$1C                                                           ;048017|001C    |      ;
    db $01                                                             ;048019|        |      ;
    LDY.W #$0000                                                       ;04801A|A00000  |      ; read name for Tooru from save file into RAM
  ; BRK #$1C                                                           ;04801D|001C    |      ;
  ; db $14                                                             ;04801F|        |      ;
  ; LDA.W buffer_for_name_1656                                         ;048020|AD5616  |011656; if buffer for name is empty, fill it with the default name for him
  ; BNE CODE_prepare_to_let_player_input_name_048029                   ;048023|D004    |048029;
  ; JSL.L jsl_here_to_read_default_protag_name_01DD2A                  ;048025|222ADD01|01DD2A;
    jsr.w ReadNameYFromSaveFileOrFillWithDefaultIfEmpty
CODE_prepare_to_let_player_input_name_048029:
    LDA.B menu_type_00_tooru_mari_02_killer-$102b                      ;048029|A500    |00102B; bit 0 of $00 indicates whether to input name for Tooru or the killer
    LSR A                                                              ;04802B|4A      |      ;
  ; JSL.L allow_player_to_enter_name_for_character_based_on_A_Y_04893D ;04802C|223D8904|04893D;
    jsr.w allow_player_to_enter_name_for_character_based_on_A_Y_04893D
    LDA.B menu_type_00_tooru_mari_02_killer-$102b                      ;048030|A500    |00102B; name has been entered; if it was for the killer, skip down
    BNE skip_down_if_entered_killer_name_048061                        ;048032|D02D    |048061;
case_just_got_name_for_Tooru_048034:
    LDY.W #$0000                                                       ;048034|A00000  |      ; copy player's name for Tooru into scratchpad save file
    BRK #$1C                                                           ;048037|001C    |      ;
    db $93                                                             ;048039|        |      ;
    LDY.W #$0002                                                       ;04803A|A00200  |      ; read Mari's name from the save file into RAM
  ; BRK #$1C                                                           ;04803D|001C    |      ;
  ; db $14                                                             ;04803F|        |      ;
  ; LDA.W buffer_for_name_1656                                         ;048040|AD5616  |011656; if the first character is 0000, then read her default name into buffer
  ; BNE +                                                              ;048043|D004    |048049;
  ; JSL.L jsl_here_to_read_default_protag_name_01DD2A                  ;048045|222ADD01|01DD2A;
; +
    jsr.w ReadNameYFromSaveFileOrFillWithDefaultIfEmpty
    JSR.W draw_tiles_to_prepare_to_name_Mari_048077                    ;048049|207780  |048077;
    LDY.W #$0002                                                       ;04804C|A00200  |      ; copy her name into scratchpad save file
    BRK #$1C                                                           ;04804F|001C    |      ;
    db $93                                                             ;048051|        |      ;
    LDA.W current_save_file_num_0421                                   ;048052|AD2104  |010421; set the source save file's number into scratchpad save file
    AND.W #$0003                                                       ;048055|290300  |      ;
    BRK #$1C                                                           ;048058|001C    |      ;
    db $96                                                             ;04805A|        |      ;
    BRK #$1C                                                           ;04805B|001C    |      ; update source save file's checksums
    db $AD                                                             ;04805D|        |      ;
    BRK #$1C                                                           ;04805E|001C    |      ;
    db $03                                                             ;048060|        |      ;
skip_down_if_entered_killer_name_048061:
    JSL.L $028259                                                      ;048061|22598202|028259;
    STZ.W $091C                                                        ;048065|9C1C09  |01091C;
    JSR.W restore_PPU_regs_from_backup_048284                          ;048068|208482  |048284;
    JSL.L init_BG3_for_text_and_copy_text_colors_to_CGRAM_04A2D8       ;04806B|22D8A204|04A2D8;
restore_YXAPD_rtl:
    REP #$30                                                           ;04806F|C230    |      ;
    PLY : PLX : PLA : PLP : PLD
    RTL                                                                ;048076|6B      |      ;

ReadNameYFromSaveFileOrFillWithDefaultIfEmpty:
    brk #$1C
    db $14
    lda.w buffer_for_name_1656
    bne +
    jsl.l jsl_here_to_read_default_protag_name_01DD2A
  + rts

draw_tiles_to_prepare_to_name_Mari_048077:
    PHP                                                                ;048077|08      |      ;
    REP #$30                                                           ;048078|C230    |      ;
    PHA : PHX : PHY
    JSR.W set_initial_state_of_enabled_sprites_on_name_entry_048312    ;04807D|201283  |048312;
    LDX.W #$0002                                                       ;048080|A20200  |      ; clear the box at top left that says "protagonist", "girlfriend" or "culprit"
  ; JSL.L clear_tiles_for_please_input_name_box_or_subject_box_0480E5  ;048083|22E58004|0480E5;
    jsr.w clear_tiles_for_please_input_name_box_or_subject_box_0480E5

    ; cut out, don't need
;   JSL.L clear_gray_boxes_below_kana_markers_for_kanji_grid_049161    ;048087|22619104|049161;

; write "girlfriend" in notice box
  ; LDX.W #$001C                                                       ;04808B|A21C00  |      ; write left half of "girlfriend" in notice box for "enter her name"
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;04808E|22608604|048660;
  ; LDX.W #$001D                                                       ;048092|A21D00  |      ; write the right half
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048095|22608604|048660;
    ldx.w #!TwoColumnGirlfriendNotice1
    jsr.w WriteFourConsecutiveSetsOfTwoTileColumns

    JSR.W write_text_please_name_the_BLANK_0481D8                      ;048099|20D881  |0481D8; write the rest of the notice

  ; LDX.W #$0008                                                       ;04809C|A20800  |      ; write "kanji" with gray box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;04809F|22608604|048660;
  ; LDX.W #$0001                                                       ;0480A3|A20100  |      ; write "hiragana" with black box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0480A6|22608604|048660;
  ; LDX.W #$0002                                                       ;0480AA|A20200  |      ; write "katakana" with black box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0480AD|22608604|048660;
    ldx.w #!TwoColumnAccentsBlackBox
    jsr.w WriteTwoConsecutiveSetsOfTwoTileColumns

; JP game would draw up/down arrows at top/bottom of grid window; don't need this
;   JSL.L use_list_X_at_018931_to_write_tile_IDs_048766                ;0480B1|22668704|048766;
  ; ldx.w #$0002
  ; jsr.w use_list_X_at_018931_to_write_tile_IDs_048766

  ; LDX.W #$0006                                                       ;0480B5|A20600  |      ; write "finish" with black box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0480B8|22608604|048660;
    ldx.w #!TwoColumnFinishBlackBox
    jsr.w write_two_tile_ID_columns_for_list_X_at_01884E_048660

    LDX.W #$0007                                                       ;0480BC|A20700  |      ;
    JSR.W draw_box_edges_for_name_entry_screen_0486B3                  ;0480BF|20B386  |0486B3;
    LDX.W #$0008                                                       ;0480C2|A20800  |      ; draw corners of the "please enter name" box
  ; JSL.L use_list_X_at_018931_to_write_tile_IDs_048766                ;0480C5|22668704|048766;
    jsr.w use_list_X_at_018931_to_write_tile_IDs_048766
    LDX.W #$0002                                                       ;0480C9|A20200  |      ; interactive left border with buttons
  ; JSL.L fill_in_char_grid_state_buffer_from_list_X_048427            ;0480CC|22278404|048427;
    JSR.W fill_in_char_grid_state_buffer_from_list_X_048427            ;048EBA|22278404|048427;
; JP game would go back to kanji grid; we want to go to hiragana grid instead
  ; LDA.W #$0000                                                       ;0480D0|A90000  |      ; go back to the kanji grid
    lda.w #$0002
    STA.L char_grid_type_0_kanji_2_hira_4_kata                         ;0480D3|8F21147F|7F1421;
    LDA.B menu_type_00_tooru_mari_02_killer-$102b                      ;0480D7|A500    |00102B;
    LSR A                                                              ;0480D9|4A      |      ;
  ; JSL.L allow_player_to_enter_name_for_character_based_on_A_Y_04893D ;0480DA|223D8904|04893D;
    jsr.w allow_player_to_enter_name_for_character_based_on_A_Y_04893D
    jmp.w pull_YXAP_rts
  ; REP #$30                                                           ;0480DE|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;0480E4|60      |      ;

clear_tiles_for_please_input_name_box_or_subject_box_0480E5:
    PHD                                                                ;0480E5|0B      |      ; input: X can be either 0000 ($0489BE) or 0002 ($048084)
    COP #$00                                                           ;0480E6|0200    |      ; free up 0x6 bytes on stack
    db $05                                                             ;0480E8|        |      ;
    PHP                                                                ;0480E9|08      |      ;
    REP #$30                                                           ;0480EA|C230    |      ;
    PHA : PHX : PHY
    LDA.W DATA_num_bytes_to_fill_0x22_or_0xC_01871F,X                  ;0480EF|BD1F87  |01871F;
    STA.B $00                                                          ;0480F2|8500    |001017;
    LDA.W DATA_skip_size_0x1E_or_0x34_018723,X                         ;0480F4|BD2387  |018723;
    STA.B $02                                                          ;0480F7|8502    |001019;
    LDA.W DATA_end_offset_0490_or_0102_018727,X                        ;0480F9|BD2787  |018727;
    STA.B $04                                                          ;0480FC|8504    |00101B;
    LDA.W DATA_start_offset_02D0_or_0082_01872B,X                      ;0480FE|BD2B87  |01872B; X <- start offset in $7F18A0 to modify
    TAX                                                                ;048101|AA      |      ;
LOOP_048102:
    LDY.B $00                                                          ;048102|A400    |001017; loop counter = # bytes to fill
  ; LDA.W #$207C                                                       ;048104|A97C20  |      ; this represents a tilemap entry for tile $07C (empty) with high priority
    lda.w #$2000|!TileIdEmpty
INNER_LOOP_048107:
    STA.L BUFFER_tilemaps_for_name_entry,X                             ;048107|9FA0187F|7F18A0; fill in the bytes with [7C 20]
    INX #2
    DEY #2
    BNE INNER_LOOP_048107                                              ;04810F|D0F6    |048107;
    TXA                                                                ;048111|8A      |      ; skip appropriate # of bytes
    CLC                                                                ;048112|18      |      ;
    ADC.B $02                                                          ;048113|6502    |001019;
    TAX                                                                ;048115|AA      |      ;
    CMP.B $04                                                          ;048116|C504    |00101B; check against end of data to modify
    BNE LOOP_048102                                                    ;048118|D0E8    |048102;
pull_YXAPD_rts:
    REP #$30                                                           ;04811A|C230    |      ;
    PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048121|6B      |      ;
    RTS

; pushpc
; org $008ec5
    ; jsl set_up_VRAM_for_name_entry_screen_player_00_killer_02_048122
; org $008eda
    ; jsl set_up_VRAM_for_name_entry_screen_player_00_killer_02_048122
; pullpc
set_up_VRAM_for_name_entry_screen_player_00_killer_02_048122:
    PHD                                                                ;048122|0B      |      ; input in X: either 0000 (naming Tooru & Mari) or 0002 (entering killer's name)
    COP #$00                                                           ;048123|0200    |      ; see $008EB8 and $008ED6
    db $01                                                             ;048125|        |      ;
    PHP                                                                ;048126|08      |      ;
    REP #$30                                                           ;048127|C230    |      ;
    PHA : PHX : PHY
    STX.B menu_type_00_tooru_mari_02_killer-$102b                      ;04812C|8600    |00102B;

    LDA.W #$7D00                                                       ;04812E|A9007D  |      ; clear $7F0000-$7F7CFF
  ; JSL.L clear_first_Acc_bytes_in_bank_7F_0482B9                      ;048131|22B98204|0482B9;
  ; JSL.L copy_current_PPU_regs_to_7F20E0_048224                       ;048135|22248204|048224;
  ; JSL.L set_PPU_regs_for_name_entry_screen_04823F                    ;048139|223F8204|04823F;
    JSR.W clear_first_Acc_bytes_in_bank_7F_0482B9
    JSR.W copy_current_PPU_regs_to_7F20E0_048224
    JSR.W set_PPU_regs_for_name_entry_screen_04823F

    JSR.W fill_odd_bytes_in_VRAM_from_6000_to_6FFF_with_00_048387      ;04813D|208783  |048387;
    JSR.W copy_white_and_light_and_dark_gray_into_CGRAM_0487C1         ;048140|20C187  |0487C1;
    JSR.W copy_gfx_data_for_name_entry_buttons_048721                  ;048143|202187  |048721;
    JSR.W DMA_char_grid_menu_gfx_from_7F0000_to_VRAM_BG3_04879F        ;048146|209F87  |04879F;

    LDA.W #$20E0                                                       ;048149|A9E020  |      ;
  ; JSL.L clear_first_Acc_bytes_in_bank_7F_0482B9                      ;04814C|22B98204|0482B9;
    JSR.W clear_first_Acc_bytes_in_bank_7F_0482B9                      ;04814C|22B98204|0482B9;

    LDA.W #$2180                                                       ;048150|A98021  |      ; fill BG3 tilemap (char grid) with empty tiles
    JSR.W fill_name_entry_tilemap_with_value_048596                    ;048153|209685  |048596;
    JSR.W generate_tilemap_for_char_grid_0485B1                        ;048156|20B185  |0485B1;
    JSR.W write_tilemap_entries_for_chars_in_entered_name_048611       ;048159|201186  |048611;
    JSR.W DMA_char_grid_tilemap_to_VRAM_04863E                         ;04815C|203E86  |04863E;

  ; LDA.W #$207C                                                       ;04815F|A97C20  |      ; fill BG2 tilemap with empty tiles (high priority)
    lda.w #$2000|!TileIdEmpty
    JSR.W fill_name_entry_tilemap_with_value_048596                    ;048162|209685  |048596;
    LDX.W #$0000                                                       ;048165|A20000  |      ; draw edges for boxes for the entered name and the char grid
    JSR.W draw_box_edges_for_name_entry_screen_0486B3                  ;048168|20B386  |0486B3;
    LDA.B menu_type_00_tooru_mari_02_killer-$102b                      ;04816B|A500    |00102B; check if entering names for Tooru and Mari, or the killer (skip down)
    BNE CODE_skip_down_if_entering_killer_name_0481AD                  ;04816D|D03E    |0481AD;
CODE_draw_buttons_for_naming_Tooru_or_Mari_04816F:
  ; LDX.W #$0008                                                       ;04816F|A20800  |      ; write "kanji" with gray box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048172|22608604|048660;
  ; LDX.W #$0001                                                       ;048176|A20100  |      ; write "hiragana" with black box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048179|22608604|048660;
  ; LDX.W #$0002                                                       ;04817D|A20200  |      ; write "katakana" with black box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048180|22608604|048660;
    ldx.w #!TwoColumnAccentsBlackBox
    jsr.w WriteTwoConsecutiveSetsOfTwoTileColumns

; JP game would draw up/down arrows at top/bottom of grid window; don't need this
  ; ldx.w #$0002
;   JSL.L use_list_X_at_018931_to_write_tile_IDs_048766                ;048184|22668704|048766; write the up/down arrows at the top/bottom box borders
  ; jsr.w use_list_X_at_018931_to_write_tile_IDs_048766

  ; LDX.W #$0017                                                       ;048188|A21700  |      ; write left third of "protagonist" for notice
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;04818B|22608604|048660;
  ; LDX.W #$0018                                                       ;04818F|A21800  |      ; write middle third of "protagonist" for notice
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048192|22608604|048660;
  ; LDX.W #$0019                                                       ;048196|A21900  |      ; write the right third of "protagonist" for notice
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048199|22608604|048660;
    ldx.w #!TwoColumnProtagonist1
    jsr.w WriteFourConsecutiveSetsOfTwoTileColumns

    JSR.W write_text_please_name_the_BLANK_0481D8                      ;04819D|20D881  |0481D8; write the rest of the notice in the center
    LDX.W #$0007                                                       ;0481A0|A20700  |      ; draw box edges for the "please enter []'s name" notice in the center
    JSR.W draw_box_edges_for_name_entry_screen_0486B3                  ;0481A3|20B386  |0486B3;
    LDX.W #$0008                                                       ;0481A6|A20800  |      ; draw corners of the "please enter []'s name" box
  ; JSL.L use_list_X_at_018931_to_write_tile_IDs_048766                ;0481A9|22668704|048766;
    JSR.W use_list_X_at_018931_to_write_tile_IDs_048766
CODE_skip_down_if_entering_killer_name_0481AD:
    LDX.W #$0000                                                       ;0481AD|A20000  |      ; draw left/right edges of box around entered name, and corners of char grid
  ; JSL.L use_list_X_at_018931_to_write_tile_IDs_048766                ;0481B0|22668704|048766;
    JSR.W use_list_X_at_018931_to_write_tile_IDs_048766

  ; LDX.W #$0003                                                       ;0481B4|A20300  |      ; write "space" with black box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0481B7|22608604|048660;
  ; LDX.W #$0004                                                       ;0481BB|A20400  |      ; write "delete" with black box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0481BE|22608604|048660;
  ; LDX.W #$0005                                                       ;0481C2|A20500  |      ; write "clear" with black box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0481C5|22608604|048660;
  ; LDX.W #$0006                                                       ;0481C9|A20600  |      ; write "finish" with black box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0481CC|22608604|048660;
    ldx.w #!TwoColumnSpaceBlackBox
    jsr.w WriteFourConsecutiveSetsOfTwoTileColumns

  ; REP #$30                                                           ;0481D0|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTL                                                                ;0481D7|6B      |      ;
    jmp restore_YXAPD_rtl

write_text_please_name_the_BLANK_0481D8:
    PHP                                                                ;0481D8|08      |      ;
    REP #$30                                                           ;0481D9|C230    |      ;
    PHA : PHX : PHY
    LDX.W #$0006                                                       ;0481DE|A20600  |      ; write the right half of the を
  ; JSL.L use_list_X_at_018931_to_write_tile_IDs_048766                ;0481E1|22668704|048766;
    JSR.W use_list_X_at_018931_to_write_tile_IDs_048766
  ; LDX.W #$0020                                                       ;0481E5|A22000  |      ; write "の" in message
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0481E8|22608604|048660;
  ; LDX.W #$0021                                                       ;0481EC|A22100  |      ; 0x21 and 0x22 write the 名前 and left half of the を
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0481EF|22608604|048660;
  ; LDX.W #$0022                                                       ;0481F3|A22200  |      ;
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0481F6|22608604|048660;
  ; LDX.W #$0023                                                       ;0481FA|A22300  |      ; write the 決
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0481FD|22608604|048660;
  ; LDX.W #$0024                                                       ;048201|A22400  |      ; 0x24, 0x25, 0x26 combined write めて下さ
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048204|22608604|048660;
  ; LDX.W #$0025                                                       ;048208|A22500  |      ;
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;04820B|22608604|048660;
  ; LDX.W #$0026                                                       ;04820F|A22600  |      ;
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048212|22608604|048660;
  ; LDX.W #$0027                                                       ;048216|A22700  |      ; write the い
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048219|22608604|048660;
    ldx.w #!TwoColumnPleaseNameThe1
    jsr.w WriteSixConsecutiveSetsOfTwoTileColumns

    jmp.w pull_YXAP_rts
  ; REP #$30                                                           ;04821D|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048223|60      |      ;

WriteSixConsecutiveSetsOfTwoTileColumns:
; initial input value in X: write X, X+1, X+2, ..., X+(N-1)
    jsr.w write_two_tile_ID_columns_for_list_X_at_01884E_048660
    inx
WriteFiveConsecutiveSetsOfTwoTileColumns:
 ; I ended up not needing this label for 5 sets, but leaving in
    jsr.w write_two_tile_ID_columns_for_list_X_at_01884E_048660
    inx
WriteFourConsecutiveSetsOfTwoTileColumns:
    jsr.w write_two_tile_ID_columns_for_list_X_at_01884E_048660
    inx
WriteThreeConsecutiveSetsOfTwoTileColumns:
    jsr.w write_two_tile_ID_columns_for_list_X_at_01884E_048660
    inx
WriteTwoConsecutiveSetsOfTwoTileColumns:
    jsr.w write_two_tile_ID_columns_for_list_X_at_01884E_048660
    inx
    jmp.w write_two_tile_ID_columns_for_list_X_at_01884E_048660

copy_current_PPU_regs_to_7F20E0_048224:
    PHP                                                                ;048224|08      |      ;
    REP #$30                                                           ;048225|C230    |      ;
    PHA : PHX : PHY
    LDX.W #$0030                                                       ;04822A|A23000  |      ;
  - LDA.W INIDISP_copy_0353,X                                          ;04822D|BD5303  |010353;
    STA.L buffer_for_backup_of_PPU_regs_7F20E0,X                       ;048230|9FE0207F|7F20E0;
    DEX #2
    BNE -                                                              ;048236|D0F5    |04822D;
    jmp.w pull_YXAP_rts
  ; REP #$30                                                           ;048238|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;04823E|6B      |      ;
  ; RTS

set_PPU_regs_for_name_entry_screen_04823F:
    PHP                                                                ;04823F|08      |      ;
    REP #$30                                                           ;048240|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048245|E220    |      ;
    LDA.B #$16                                                         ;048247|A916    |      ;
    TRB.W TM_copy_0377                                                 ;048249|1C7703  |010377;
    LDA.B #$49                                                         ;04824C|A949    |      ;
    STA.W BGMODE_copy_0355                                             ;04824E|8D5503  |010355;
    LDA.B #$62                                                         ;048251|A962    |      ;
    STA.W OBSEL_copy_0354                                              ;048253|8D5403  |010354;
    LDA.B #$09                                                         ;048256|A909    |      ;
    STA.W BG3VOFS_lo_copy_0367                                         ;048258|8D6703  |010367;
    LDA.B #$50                                                         ;04825B|A950    |      ;
    STA.W BG2SC_copy_0358                                              ;04825D|8D5803  |010358;
    LDA.B #$40                                                         ;048260|A940    |      ;
    STA.W BG12NBA_copy_035B                                            ;048262|8D5B03  |01035B;
    LDA.B #$70                                                         ;048265|A970    |      ;
    STA.W BG3SC_copy_0359                                              ;048267|8D5903  |010359;
    LDA.B #$06                                                         ;04826A|A906    |      ;
    STA.W BG34NBA_copy_035C                                            ;04826C|8D5C03  |01035C;
    LDA.B #$30                                                         ;04826F|A930    |      ;
    STA.W CGWSEL_copy_037B                                             ;048271|8D7B03  |01037B;
    LDA.B #$1F                                                         ;048274|A91F    |      ;
    bra +
  ; TSB.W $1670                                                        ;048276|0C7016  |011670;
  ; BRK #$00                                                           ;048279|0000    |      ;
  ; dw $0001                                                           ;04827B|        |      ;
  ; jmp.w pull_YXAP_rts
  ; REP #$30                                                           ;04827D|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048283|6B      |      ;
  ; RTS

restore_PPU_regs_from_backup_048284:
    PHP                                                                ;048284|08      |      ;
    REP #$30                                                           ;048285|C230    |      ;
    PHA : PHX : PHY
    LDX.W #$0030                                                       ;04828A|A23000  |      ;
  - LDA.L buffer_for_backup_of_PPU_regs_7F20E0,X                       ;04828D|BFE0207F|7F20E0;
    STA.W INIDISP_copy_0353,X                                          ;048291|9D5303  |010353;
    DEX #2
    BNE -                                                              ;048296|D0F5    |04828D;
    SEP #$20                                                           ;048298|E220    |      ;
    LDA.B #$FF                                                         ;04829A|A9FF    |      ; set vertical offset for text layer
    STA.W BG3VOFS_lo_copy_0367                                         ;04829C|8D6703  |010367;
    LDA.B #$10                                                         ;04829F|A910    |      ; disable sprites on sub screen
    TRB.W TS_copy_0378                                                 ;0482A1|1C7803  |010378;
    LDA.B #$16                                                         ;0482A4|A916    |      ; disable sprites, BG2, BG3 on main screen
    TRB.W TM_copy_0377                                                 ;0482A6|1C7703  |010377;
    LDA.B #$3F                                                         ;0482A9|A93F    |      ;
  + TSB.W $1670                                                        ;0482AB|0C7016  |011670;
    BRK #$00                                                           ;0482AE|0000    |      ;
    dw $0001                                                           ;0482B0|        |      ;
    jmp.w pull_YXAP_rts
  ; REP #$30                                                           ;0482B2|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;0482B8|60      |      ;

clear_first_Acc_bytes_in_bank_7F_0482B9:
    PHD                                                                ;0482B9|0B      |      ;
    COP #$00                                                           ;0482BA|0200    |      ;
    db $01                                                             ;0482BC|        |      ;
    PHP                                                                ;0482BD|08      |      ;
    REP #$30                                                           ;0482BE|C230    |      ;
    PHA : PHX : PHY
    STA.B $00                                                          ;0482C3|8500    |001029; store subroutine input value that is in A
    LDA.W #$0000                                                       ;0482C5|A90000  |      ;
    TAX                                                                ;0482C8|AA      |      ;
    SEP #$20                                                           ;0482C9|E220    |      ;
  - STA.L $7F0000,X                                                    ;0482CB|9F00007F|7F0000;
    INX                                                                ;0482CF|E8      |      ;
    CPX.B $00                                                          ;0482D0|E400    |001029;
    BNE -                                                              ;0482D2|D0F7    |0482CB;
    REP #$30                                                           ;0482D4|C230    |      ;
    jmp.w pull_YXAPD_rts
  ; PLY : PLX : PLA : PLP : PLD                                                                ;0482DA|2B      |      ;
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;0482DB|6B      |      ;
  ; RTS

set_up_OAM_and_code_grid_for_name_entry_buttons_0482DC:
    PHP                                                                ;0482DC|08      |      ;
    REP #$30                                                           ;0482DD|C230    |      ;
    PHA : PHX : PHY
    JSR.W generate_sprite_positions_for_char_grid_highlight_box_0484AB ;0482E2|20AB84  |0484AB;
    JSR.W set_initial_positions_for_button_highlight_sprites_048502    ;0482E5|200285  |048502;
    JSR.W set_tile_nums_OAM_extra_bytes_for_button_highlights_048527   ;0482E8|202785  |048527;
  ; JSL.L set_up_and_run_DMA_to_OAM_048575                             ;0482EB|22758504|048575;
    JSR.W set_up_and_run_DMA_to_OAM_048575                             ;0482EB|22758504|048575;
    LDA.B menu_type_00_tooru_mari_02_killer-$102b                      ;0482EF|A500    |00102B;
    BNE case_killer_name_entry_0482F9                                  ;0482F1|D006    |0482F9;
case_regular_name_entry_0482F3:
  ; JSL.L set_up_char_grid_and_buttons_for_regular_name_entry_0483C4   ;0482F3|22C48304|0483C4;
    JSR.W set_up_char_grid_and_buttons_for_regular_name_entry_0483C4
    BRA restore_regs_RTL_04830B                                        ;0482F7|8012    |04830B;
case_killer_name_entry_0482F9:
  ; JSL.L set_up_char_grid_and_buttons_for_killer_name_entry_0483F4    ;0482F9|22F48304|0483F4;
    JSR.W set_up_char_grid_and_buttons_for_killer_name_entry_0483F4
  ; LDX.W #$001E                                                       ;0482FD|A21E00  |      ; draw left half of the "killer" box in the top left
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048300|22608604|048660;
  ; LDX.W #$001F                                                       ;048304|A21F00  |      ; draw right half
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048307|22608604|048660;
    ldx.w #!TwoColumnKiller1
    jsr.w WriteTwoConsecutiveSetsOfTwoTileColumns
restore_regs_RTL_04830B:
  ; REP #$30                                                           ;04830B|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048311|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

set_initial_state_of_enabled_sprites_on_name_entry_048312:
; this is only for resetting the screen for naming Mari after naming Tooru
    PHP                                                                ;048312|08      |      ;
    REP #$30                                                           ;048313|C230    |      ;
    PHA : PHX : PHY
  ; LDA.W #$174F                                                       ;048318|A94F17  |      ;
    lda.w #!OffScreenForSprite
    STA.L sprite_pos_for_flashing_square_in_name                       ;04831B|8F70187F|7F1870;
    LDA.W #$372F                                                       ;04831F|A92F37  |      ;
    STA.L char_grid_highlight_box_xy_pos                               ;048322|8F74187F|7F1874;

; in JP game, this turns off highlights for kanji/clear/finish buttons
; in patch, this turns off highlights for kanji/delete/finish buttons
  ; LDA.W #$5555                                                       ;048326|A95555  |      ;
  ; STA.L $7F1892                                                      ;048329|8F92187F|7F1892;
    jsr.w TurnOffHighlightsForPlaceholderClearFinishButtons
; turn on highlight boxes in name window and char grid (turn off space/delete)
  ; LDA.W #$0555                                                       ;04832D|A95505  |      ;
  ; STA.L $7F1896                                                      ;048330|8F96187F|7F1896;
    jsr.w TurnOnBothNameHighlightBoxAndCharGridHighlightBox

  ; JSL.L DMA_OAM_data_for_highlight_boxes_and_all_extra_bytes_049270  ;048334|22709204|049270;
    JSR.W DMA_OAM_data_for_highlight_boxes_and_all_extra_bytes_049270
  ; REP #$30                                                           ;048338|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;04833E|60      |      ;
    jmp.w pull_YXAP_rts

TurnOffHighlightsForPlaceholderClearFinishButtons:
    lda.w #$5555
    sta.l $7F1892
    rts

TurnOffHighlightsForABCD_AccentButtons:
    lda.w #$5555
    sta.l $7F1894
    rts

TurnOnBothNameHighlightBoxAndCharGridHighlightBox:
    lda.w #$0555
    bra +
TurnOnNameHighlightBox:
    lda.w #$4555
  + sta.l $7F1896
    rts

transfer_char_grid_font_data_on_screen_to_VRAM_6000_04833F:
    PHD                                                                ;04833F|0B      |      ;
    COP #$0A                                                           ;048340|020A    |      ;
    db $5B                                                             ;048342|        |      ; flags
    dw $6000,$0c00                                                     ;048343|        |      ; VRAM address, DMA size in bytes
    db $00                                                             ;048347|        |      ; DMA parameters
    dl BUFFER_1bpp_char_grid_gfx_on_screen                             ;048348|        |7F0220; source data pointer $7F0220
    db $00,$09                                                         ;04834B|        |      ; VRAM address increment mode
DoBRK0C_BRK_00_0008_WithParamsFilledInOnDirectPage:
    PHP                                                                ;04834D|08      |      ;
    REP #$30                                                           ;04834E|C230    |      ;
    PHA : PHX : PHY
    BRK #$0C                                                           ;048353|000C    |      ;
DoBRK_00_0008_pull_YXAPD_rts:
    BRK #$00                                                           ;048355|0000    |      ;
    dw $0008                                                           ;048357|        |      ;
  ; REP #$30                                                           ;048359|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048360|6B      |      ;
  ; RTS
    jmp.w pull_YXAPD_rts

wrapper_to_read_gfx_data_for_N_chars_in_grid_048361:
    PHD                                                                ;048361|0B      |      ;
    COP #$00                                                           ;048362|0200    |      ;
    db $03                                                             ;048364|        |      ; open up four bytes on direct page
    PHP                                                                ;048365|08      |      ;
    REP #$30                                                           ;048366|C230    |      ;
    PHA : PHX : PHY
    LDA.B $06                                                          ;04836B|A506    |00100F; make copy of starting index in lookup table from $5E8000 decompressed output
    STA.B $00                                                          ;04836D|8500    |001009;
; this copies $08-$09 one byte at a time because the data is two one-byte values
; (e.g. see $0494FA): $08 = tile # to copy to, $09 = # tiles to copy
; cut out the SEP, the second set of LDA/STA, and the REP
  ; SEP #$20                                                           ;04836F|E220    |      ;
    LDA.B $08                                                          ;048371|A508    |001011; make copy of # chars copied (indicates where to write data)
    STA.B $02                                                          ;048373|8502    |00100B;
  ; LDA.B $09                                                          ;048375|A509    |001012; make copy of # chars to copy
  ; STA.B $03                                                          ;048377|8503    |00100C;
  ; REP #$20                                                           ;048379|C220    |      ;
  ; JSL.L read_gfx_data_for_N_chars_in_grid_0497A1                     ;04837B|22A19704|0497A1;
    jsr.w read_gfx_data_for_N_chars_in_grid_0497A1
  ; REP #$30                                                           ;04837F|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048386|6B      |      ;
  ; RTS
    jmp.w pull_YXAPD_rts

fill_odd_bytes_in_VRAM_from_6000_to_6FFF_with_00_048387:
    PHD                                                                ;048387|0B      |      ;
    COP #$0A                                                           ;048388|020A    |      ; fill in data for upcoming BRK
    db $DB                                                             ;04838A|        |      ; flags
    dw $6000,$2000                                                     ;04838B|        |      ; target VRAM address $6000.w
    db $28                                                             ;04838F|        |      ; DMA params - bit 5 is for VRAM entry high byte bus; bit 3 is for fixed CPU addr step
    dl $01872F                                                         ;048390|        |01872F; pointer $01872F is to 0x00
    db $80,$09                                                         ;048393|        |      ; VRAM increment mode
  ; PHP                                                                ;048395|08      |      ;
  ; REP #$30                                                           ;048396|C230    |      ;
  ; PHA : PHX : PHY
  ; BRK #$0C                                                           ;04839B|000C    |      ;
  ; BRK #$00                                                           ;04839D|0000    |      ;
  ; dw $0008                                                           ;04839F|        |      ;
  ; REP #$30                                                           ;0483A1|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;0483A8|60      |      ;
    jmp.w DoBRK0C_BRK_00_0008_WithParamsFilledInOnDirectPage

clear_decompressed_font_data_0483A9:
    PHP                                                                ;0483A9|08      |      ;
    REP #$30                                                           ;0483AA|C230    |      ;
    PHA : PHX : PHY
    LDA.W #$0000                                                       ;0483AF|A90000  |      ; fill the range $7F0000 - $7F021F with all 00 bytes
  ; LDX.W #$021E                                                       ;0483B2|A21E02  |      ; this corresponds to the most recently decompressed character's 2bpp font data
; - STA.L $7F0000,X                                                    ;0483B5|9F00007F|7F0000;
    ldx.w #!WidthOfDecompressedNameFontIn16x16Tiles*$20
  - sta.l !WramLocationForDecompressingNameFont,x
    sta.l !WramLocationForDecompressingNameFont+$0200-$2,x
    DEX #2
    BPL -                                                              ;0483BB|10F8    |0483B5;
  ; REP #$30                                                           ;0483BD|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;0483C3|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

set_up_char_grid_and_buttons_for_regular_name_entry_0483C4:
    PHP                                                                ;0483C4|08      |      ;
    REP #$30                                                           ;0483C5|C230    |      ;
    PHA : PHX : PHY
    LDX.W #$0000                                                       ;0483CA|A20000  |      ; fill in main character grid buttons
  ; JSL.L fill_in_char_grid_state_buffer_from_list_X_048427            ;0483CD|22278404|048427;
    jsr.w fill_in_char_grid_state_buffer_from_list_X_048427            ;048EBA|22278404|048427;
    JSR.W read_data_for_button_states_on_the_name_entry_screens_048478 ;0483D1|207884  |048478; execute with X = 0 (for regular name entry)
    LDX.W #$0002                                                       ;0483D4|A20200  |      ; set the left border as being interactive (change kanji/kana pages)
  ; JSL.L fill_in_char_grid_state_buffer_from_list_X_048427            ;0483D7|22278404|048427;
    jsr.w fill_in_char_grid_state_buffer_from_list_X_048427            ;048EBA|22278404|048427;
  ; LDA.W #$BBB3                                                       ;0483DB|A9B3BB  |      ;
    lda.w #read2($01B129)
    STA.L ptr_to_end_of_name_entry_char_data_BBB3                      ;0483DE|8FA0207F|7F20A0;
  ; LDA.W #$B129                                                       ;0483E2|A929B1  |      ; 0xB129 - 0xB0D3 = 0x56 = 2 * (# rows of kanji chars) = # bytes in ptr table
    lda.w #!EndOfKanjiPtrTable
    SEC                                                                ;0483E5|38      |      ;
  ; SBC.W #$B0D3                                                       ;0483E6|E9D3B0  |      ;
    sbc.w #!StartOfKanjiPtrTable
    STA.L size_of_kanji_row_ptr_table                                  ;0483E9|8FA2207F|7F20A2;
  ; REP #$30                                                           ;0483ED|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;0483F3|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

set_up_char_grid_and_buttons_for_killer_name_entry_0483F4:
    PHP                                                                ;0483F4|08      |      ;
    REP #$30                                                           ;0483F5|C230    |      ;
    PHA : PHX : PHY
    LDX.W #$0006                                                       ;0483FA|A20600  |      ; set left border as non-interactive (no kanji/kana page switching)
  ; JSL.L fill_in_char_grid_state_buffer_from_list_X_048427            ;0483FD|22278404|048427;
    jsr.w fill_in_char_grid_state_buffer_from_list_X_048427            ;048EBA|22278404|048427;
    LDX.W #$0000                                                       ;048401|A20000  |      ; fill in the main character grid
  ; JSL.L fill_in_char_grid_state_buffer_from_list_X_048427            ;048404|22278404|048427;
    jsr.w fill_in_char_grid_state_buffer_from_list_X_048427            ;048EBA|22278404|048427;
    LDX.W #$0002                                                       ;048408|A20200  |      ;
    JSR.W read_data_for_button_states_on_the_name_entry_screens_048478 ;04840B|207884  |048478; execute with X = 2 (for killer name entry)
  ; LDA.W #$B1EF                                                       ;04840E|A9EFB1  |      ;
    lda.w #Page1NameEntryCharData+!BytesPerCharScreen
    STA.L ptr_to_end_of_name_entry_char_data_BBB3                      ;048411|8FA0207F|7F20A0;
    LDA.W #$B0C1                                                       ;048415|A9C1B0  |      ; 0xB0C1 - 0xB0AD = 0x14 (20) = ten pointers to rows = for hiragana table
    SEC                                                                ;048418|38      |      ;
    SBC.W #$B0AD                                                       ;048419|E9ADB0  |      ;
    STA.L size_of_kanji_row_ptr_table                                  ;04841C|8FA2207F|7F20A2;
  ; REP #$30                                                           ;048420|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048426|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

fill_in_char_grid_state_buffer_from_list_X_048427:
    PHD                                                                ;048427|0B      |      ; input in X is what list to read from (there are 4); X can be 0, 2, 4, or 6
    COP #$01                                                           ;048428|0201    |      ;
    db $00,$04                                                         ;04842A|        |      ; $00 <- 0x00 = loop counter for below
    PHP                                                                ;04842C|08      |      ;
    REP #$30                                                           ;04842D|C230    |      ;
    PHA : PHX : PHY
    LDA.W LIST_offsets_for_018738_lists_018730,X                       ;048432|BD3087  |018730; get offset to start of the list of data we want
    TAX                                                                ;048435|AA      |      ;
    TAY                                                                ;048436|A8      |      ;
    SEP #$30                                                           ;048437|E230    |      ;
LOOP_get_button_type_value_and_metadata_048439:
    LDA.W LIST_value_to_write_for_button_type_018738,X                 ;048439|BD3887  |018738; read byte from list; FF is end of list
    CMP.B #$FF                                                         ;04843C|C9FF    |      ;
    BEQ restore_regs_RTL_04846E                                        ;04843E|F02E    |04846E;
    STA.B $01                                                          ;048440|8501    |001027; $01 <- button type value to write
    LDA.W LIST_start_offset_in_button_type_buffer_018753,X             ;048442|BD5387  |018753; $02 <- start offset in buffer for button to fill in
    STA.B $02                                                          ;048445|8502    |001028;
    LDA.W LIST_skip_size_for_button_type_01876E,X                      ;048447|BD6E87  |01876E; $03 <- how far to advance after writing the byte
    STA.B $03                                                          ;04844A|8503    |001029;
    LDA.W LIST_num_times_to_repeat_button_type_value_018789,X          ;04844C|BD8987  |018789; $04 <- # times to repeat writing the value
    STA.B $04                                                          ;04844F|8504    |00102A;
    LDX.B $02                                                          ;048451|A602    |001028; X <- start offset
LOOP_repeat_button_type_value_048453:
    LDA.B $01                                                          ;048453|A501    |001027; write the button type value itself
    STA.L state_values_for_pos_in_name_entry_grid,X                    ;048455|9F20127F|7F1220;
    TXA                                                                ;048459|8A      |      ; advance by skip size
    CLC                                                                ;04845A|18      |      ;
    ADC.B $03                                                          ;04845B|6503    |001029;
    TAX                                                                ;04845D|AA      |      ;
    INC.B $00                                                          ;04845E|E600    |001026; check repeat count
    LDA.B $00                                                          ;048460|A500    |001026;
    CMP.B $04                                                          ;048462|C504    |00102A;
    BNE LOOP_repeat_button_type_value_048453                           ;048464|D0ED    |048453;
  ; LDA.B #$00                                                         ;048466|A900    |      ; move on to the next button type value from its list
  ; STA.B $00                                                          ;048468|8500    |001026;
    stz.b $00                                                          ;048468|8500    |001026;
    INY                                                                ;04846A|C8      |      ;
    TYX                                                                ;04846B|BB      |      ;
    BRA LOOP_get_button_type_value_and_metadata_048439                 ;04846C|80CB    |048439;
restore_regs_RTL_04846E:
  ; REP #$30                                                           ;04846E|C230    |      ; why is there a second one of this here?
  ; REP #$30                                                           ;048470|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048477|6B      |      ;
  ; RTS
    jmp.w pull_YXAPD_rts

read_data_for_button_states_on_the_name_entry_screens_048478:
    PHD                                                                ;048478|0B      |      ; input value in X: 0 reads from 87A8, 2 reads from 87D5
    COP #$00                                                           ;048479|0200    |      ;
    db $02                                                             ;04847B|        |      ;
    PHP                                                                ;04847C|08      |      ;
    REP #$30                                                           ;04847D|C230    |      ;
    PHA : PHX : PHY
    LDA.W PTR_TABLE_data_0187A4,X                                      ;048482|BDA487  |0187A4; get either 87A8 or 87D5
    STA.B $00                                                          ;048485|8500    |001028;
    LDY.W #$0000                                                       ;048487|A00000  |      ;
    SEP #$30                                                           ;04848A|E230    |      ;
  - LDA.B ($00),Y                                                      ;04848C|B100    |001028; get a byte from pointer
    CMP.B #$FF                                                         ;04848E|C9FF    |      ; list is FF terminated
    BEQ restore_regs_0484A1                                            ;048490|F00F    |0484A1;
    STA.B $02                                                          ;048492|8502    |00102A; two byte structures: data value, and its offset to write to
    INY                                                                ;048494|C8      |      ;
    LDA.B ($00),Y                                                      ;048495|B100    |001028;
    TAX                                                                ;048497|AA      |      ;
    LDA.B $02                                                          ;048498|A502    |00102A;
    STA.L state_values_for_pos_in_name_entry_grid,X                    ;04849A|9F20127F|7F1220;
    INY                                                                ;04849E|C8      |      ;
    BRA -                                                              ;04849F|80EB    |04848C;
restore_regs_0484A1:
  ; REP #$30                                                           ;0484A1|C230    |      ; why is there a second one of this here?
  ; REP #$30                                                           ;0484A3|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;0484AA|60      |      ;
    jmp.w pull_YXAPD_rts

generate_sprite_positions_for_char_grid_highlight_box_0484AB:
    PHD                                                                ;0484AB|0B      |      ;
    COP #$04                                                           ;0484AC|0204    |      ;
    db $24,$00,$00,$00,$05                                             ;0484AE|        |      ; $00 <- 0x24, $02 <- 0x00; makes space for 6 bytes of data
    PHP                                                                ;0484B3|08      |      ;
    REP #$30                                                           ;0484B4|C230    |      ;
    PHA : PHX : PHY
    LDX.W #$0000                                                       ;0484B9|A20000  |      ;
    SEP #$20                                                           ;0484BC|E220    |      ;
    LDA.W LIST_sprite_Y_positions_for_char_grid_highlight_0187FF,X     ;0484BE|BDFF87  |0187FF;
LOOP_0484C1:
    STA.B $05                                                          ;0484C1|8505    |00102A;
    LDY.W #$0000                                                       ;0484C3|A00000  |      ;
LOOP_0484C6:
    TYX                                                                ;0484C6|BB      |      ;
    LDA.W LIST_sprite_X_positions_for_char_grid_highlight_0187F4,X     ;0484C7|BDF487  |0187F4;
    CMP.B #$FF                                                         ;0484CA|C9FF    |      ;
    BEQ advance_ptr_for_sprite_position_by_0xC_0484E3                  ;0484CC|F015    |0484E3;
    STA.B $04                                                          ;0484CE|8504    |001029;
    REP #$20                                                           ;0484D0|C220    |      ;
    LDX.B $00                                                          ;0484D2|A600    |001025;
    LDA.B $04                                                          ;0484D4|A504    |001029;
    STA.L MEM_LIST_char_grid_highlight_positions,X                     ;0484D6|9F20147F|7F1420;
    INC.B $00                                                          ;0484DA|E600    |001025;
    INC.B $00                                                          ;0484DC|E600    |001025;
    INY                                                                ;0484DE|C8      |      ;
    SEP #$20                                                           ;0484DF|E220    |      ;
    BRA LOOP_0484C6                                                    ;0484E1|80E3    |0484C6;
advance_ptr_for_sprite_position_by_0xC_0484E3:
    REP #$20                                                           ;0484E3|C220    |      ;
    LDA.B $00                                                          ;0484E5|A500    |001025;
    CLC                                                                ;0484E7|18      |      ;
    ADC.W #$000C                                                       ;0484E8|690C00  |      ;
    STA.B $00                                                          ;0484EB|8500    |001025;
    INC.B $02                                                          ;0484ED|E602    |001027;
    LDX.B $02                                                          ;0484EF|A602    |001027;
    SEP #$20                                                           ;0484F1|E220    |      ;
    LDA.W LIST_sprite_Y_positions_for_char_grid_highlight_0187FF,X     ;0484F3|BDFF87  |0187FF;
    CMP.B #$FF                                                         ;0484F6|C9FF    |      ;
    BNE LOOP_0484C1                                                    ;0484F8|D0C7    |0484C1;
  ; REP #$30                                                           ;0484FA|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;048501|60      |      ;
    jmp.w pull_YXAPD_rts

set_initial_positions_for_button_highlight_sprites_048502:
    PHP                                                                ;048502|08      |      ;
    REP #$30                                                           ;048503|C230    |      ;
    PHA : PHX : PHY
    LDX.W #$0000                                                       ;048508|A20000  |      ;
    TXY                                                                ;04850B|9B      |      ;
    BRA loop_entry_point_048518                                        ;04850C|800A    |048518;
LOOP_04850E:
    STA.L MEM_LIST_OAM_data_for_button_highlights,X                    ;04850E|9F20187F|7F1820;
    INX #4
    INY #2
loop_entry_point_048518:
  ; LDA.W LIST_sprite_positions_for_highlighted_buttons_018809,Y       ;048518|B90988  |018809;
    LDA.W ListButtonHighlightSpritePositions,Y                         ;048518|B90988  |018809;
    CMP.W #$FFFF                                                       ;04851B|C9FFFF  |      ;
    BNE LOOP_04850E                                                    ;04851E|D0EE    |04850E;
  ; REP #$30                                                           ;048520|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048526|60      |      ;
    jmp.w pull_YXAP_rts

set_tile_nums_OAM_extra_bytes_for_button_highlights_048527:
    PHD                                                                ;048527|0B      |      ;
    COP #$02                                                           ;048528|0202    |      ;
    dw $3000                                                           ;04852A|        |      ; 0x3000 = use priority 3 for sprites
    db $01                                                             ;04852C|        |      ;
    PHP                                                                ;04852D|08      |      ;
    REP #$30                                                           ;04852E|C230    |      ;
    PHA : PHX : PHY
    LDX.W #$0002                                                       ;048533|A20200  |      ;
    LDY.W #$0000                                                       ;048536|A00000  |      ;
LOOP_do_tile_nums_048539:
    SEP #$20                                                           ;048539|E220    |      ;
  ; LDA.W LIST_button_highlight_tile_nums_018837,Y                     ;04853B|B93788  |018837;
    LDA.W ListButtonHighlightTileNums,Y                                ;04853B|B93788  |018837;
    CMP.B #$FF                                                         ;04853E|C9FF    |      ;
    BEQ +                                                              ;048540|F011    |048553;
    STA.B $00                                                          ;048542|8500    |001029;
    INY                                                                ;048544|C8      |      ;
    REP #$20                                                           ;048545|C220    |      ;
    LDA.B $00                                                          ;048547|A500    |001029;
    STA.L MEM_LIST_OAM_data_for_button_highlights,X                    ;048549|9F20187F|7F1820;
    INX #4
    BRA LOOP_do_tile_nums_048539                                       ;048551|80E6    |048539;

  + REP #$20                                                           ;048553|C220    |      ;
    LDX.W #$0000                                                       ;048555|A20000  |      ;
LOOP_set_all_sprite_X_pos_high_bits_048558:
    LDA.W #$5555                                                       ;048558|A95555  |      ; set all the highlight sprites to off screen
    STA.L MEM_LIST_button_highlights_OAM_extra_bytes,X                 ;04855B|9F78187F|7F1878;
    INX #2
    CPX.W #$0020                                                       ;048561|E02000  |      ;
    BNE LOOP_set_all_sprite_X_pos_high_bits_048558                     ;048564|D0F2    |048558;
  ; LDA.W #$0555                                                       ;048566|A95505  |      ; set two sprites to on-screen (boxes in char grid, name window)
  ; STA.L $7F1896                                                      ;048569|8F96187F|7F1896;
    jsr.w TurnOnBothNameHighlightBoxAndCharGridHighlightBox
  ; REP #$30                                                           ;04856D|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;048574|60      |      ;
    jmp.w pull_YXAPD_rts

set_up_and_run_DMA_to_OAM_048575:
    PHD                                                                ;048575|0B      |      ;
    COP #$09                                                           ;048576|0209    |      ;
    db $5D                                                             ;048578|        |      ; flags
    db $D4                                                             ;048579|        |      ; OAM address $0D4
    db $00                                                             ;04857A|        |      ; no priority rotation
    dw $0078                                                           ;04857B|        |      ; DMA transfer 0x78 bytes
    db $00                                                             ;04857D|        |      ; DMA params
    dl $7F1820                                                         ;04857E|        |7F1820; source data pointer $7F1820
    db $08                                                             ;048581|        |      ; COP size
    PHP                                                                ;048582|08      |      ;
    REP #$30                                                           ;048583|C230    |      ;
    PHA : PHX : PHY
    BRK #$12                                                           ;048588|0012    |      ;
  ; BRK #$00                                                           ;04858A|0000    |      ;
  ; dw $0008                                                           ;04858C|        |      ;
  ; REP #$30                                                           ;04858E|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048595|6B      |      ;
  ; RTS
    jmp DoBRK_00_0008_pull_YXAPD_rts

fill_name_entry_tilemap_with_value_048596:
    PHP                                                                ;048596|08      |      ;
    REP #$30                                                           ;048597|C230    |      ;
    PHA : PHX : PHY
    LDX.W #$0000                                                       ;04859C|A20000  |      ; fill 0x800 bytes from $7F18A0 - $7F209F with the input value in A
  - STA.L BUFFER_tilemaps_for_name_entry,X                             ;04859F|9FA0187F|7F18A0;
    INX #2
    CPX.W #$0800                                                       ;0485A5|E00008  |      ;
    BNE -                                                              ;0485A8|D0F5    |04859F;
  ; REP #$30                                                           ;0485AA|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;0485B0|60      |      ;
    jmp.w pull_YXAP_rts

!CharGridTilemapStartOffset = $0106 ; word offset $083 = top left of grid
!CharGridTilemapEndOffset = $0330   ; word offset $198
!CharGridTilemapStartTileID = $0000
!NumCharsPerRowInScreenGrid = $A
!NumCharsPerRowInVramGrid = $8
CharGridTileID = $00
CharGridTilemapOffset = $02
NumScreenGridRowsLeft = $04
NumVramGridRowsLeft = $06
generate_tilemap_for_char_grid_0485B1:
    PHD                                                                ;0485B1|0B      |      ;
    COP #$08                                                           ;0485B2|0208    |      ;
    dw !CharGridTilemapStartTileID                                     ;0485B4|        |      ; $00 = tile ID to use
    dw !CharGridTilemapStartOffset                                     ;0485B6|        |      ; $02 = tilemap offset
    dw !NumCharsPerRowInScreenGrid                                     ;0485B8|        |      ; $04 = # chars per row on screen
    dw !NumCharsPerRowInVramGrid                                       ;0485BA|        |      ; $06 = # chars per row in VRAM
    db $07                                                             ;0485BC|        |      ;
    PHP                                                                ;0485BD|08      |      ;
    REP #$30                                                           ;0485BE|C230    |      ;
    PHA : PHX : PHY                                                    ;0485C2|5A      |      ;

LOOP_0485C3:
    LDX.B CharGridTilemapOffset                                        ;0485C3|A602    |001025; get offset in tilemap
    LDA.B CharGridTileID                                               ;0485C5|A500    |001023; get tile ID for tilemap entry
    ORA.W #$2000                                                       ;0485C7|090020  |      ; set high priority
    STA.L BUFFER_tilemaps_for_name_entry,X                             ;0485CA|9FA0187F|7F18A0;

    DEC.B NumVramGridRowsLeft                                          ;0485CE|C606    |001029; characters in VRAM are arranged in rows of 8 chars
; DEC already affects Z flag for us, and value of $06 is not immediately used
  ; LDA.B NumVramGridRowsLeft                                          ;0485D0|A506    |001029;
    BEQ case_skip_tile_ID_to_next_row_in_VRAM_0485EB                   ;0485D2|F017    |0485EB;
    INC.B CharGridTileID                                               ;0485D4|E600    |001023; advance tile ID by 2 (tiles are 16x16)
    INC.B CharGridTileID                                               ;0485D6|E600    |001023;
check_if_0xA_chars_written_in_row_0485D8:
    DEC.B NumScreenGridRowsLeft                                        ;0485D8|C604    |001027;
  ; LDA.B NumScreenGridRowsLeft                                        ;0485DA|A504    |001027;
    BEQ case_skip_in_tilemap_to_next_char_row_0485FA                   ;0485DC|F01C    |0485FA;
    INC.B CharGridTilemapOffset                                        ;0485DE|E602    |001025;
    INC.B CharGridTilemapOffset                                        ;0485E0|E602    |001025;
    LDA.B CharGridTilemapOffset                                        ;0485E2|A502    |001025;
check_index_in_02_0485E2:
    CMP.W #!CharGridTilemapEndOffset                                   ;0485E4|C93003  |      ;
    BPL restore_regs_RTS_048609                                        ;0485E7|1020    |048609;
    BRA LOOP_0485C3                                                    ;0485E9|80D8    |0485C3;

case_skip_tile_ID_to_next_row_in_VRAM_0485EB:
; go from tile ID of top left tile of rightmost in row, to top left tile of
; leftmost in row, so skip bottom tile row of characters to next char row
; 0x12 = (num chars per VRAM row) * 2 + 2
    LDA.B CharGridTileID                                               ;0485EB|A500    |001023;
    CLC                                                                ;0485ED|18      |      ;
    ADC.W #2+2*!NumCharsPerRowInVramGrid                               ;0485EE|691200  |      ;
    STA.B CharGridTileID                                               ;0485F1|8500    |001023;
    LDA.W #!NumCharsPerRowInVramGrid                                   ;0485F3|A90800  |      ;
    STA.B NumVramGridRowsLeft                                          ;0485F6|8506    |001029;
    BRA check_if_0xA_chars_written_in_row_0485D8                       ;0485F8|80DE    |0485D8;
case_skip_in_tilemap_to_next_char_row_0485FA:
; move this [LDA #$000A ; STA.B $04] up
    lda.w #!NumCharsPerRowInScreenGrid
    sta.b NumScreenGridRowsLeft
    LDA.B CharGridTilemapOffset                                        ;0485FA|A502    |001025; skip 0x17 positions = to start of next row
    CLC                                                                ;0485FC|18      |      ;
    ADC.W #$002E                                                       ;0485FD|692E00  |      ;
    STA.B CharGridTilemapOffset                                        ;048600|8502    |001025;
  ; LDA.W #!NumCharsPerRowInScreenGrid                                 ;048602|A90A00  |      ;
  ; STA.B NumScreenGridRowsLeft                                        ;048605|8504    |001027;
    BRA check_index_in_02_0485E2                                       ;048607|80D9    |0485E2;
restore_regs_RTS_048609:
  ; REP #$30                                                           ;048609|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;048610|60      |      ;
    jmp.w pull_YXAPD_rts

write_tilemap_entries_for_chars_in_entered_name_048611:
; also see $0494FA for writing the tiles of name font data
!TileIdOf1stCharInName = $01a0 ; $0184
!TileIdOfEndOfName = !TileIdOf1stCharInName+2*!WidthOfDecompressedNameFontIn16x16Tiles
!StartTilemapOffsetForName = $0044*2
    PHD                                                                ;048611|0B      |      ;
    COP #$02                                                           ;048612|0202    |      ;
    dw !TileIdOf1stCharInName                                          ;048614|        |      ; $00 <- 0x0184 = tile ID # of first character in name
    db $01                                                             ;048616|        |      ;
    PHP                                                                ;048617|08      |      ;
    REP #$30                                                           ;048618|C230    |      ;
    PHA : PHX : PHY
  ; LDX.W #$008A                                                       ;04861D|A28A00  |      ; starting address in BG3 tilemap for name
    ldx.w #!StartTilemapOffsetForName
    LDA.B $00                                                          ;048620|A500    |001029;
LOOP_048622:
    ORA.W #$2000                                                       ;048622|090020  |      ; set high priority
    STA.L BUFFER_tilemaps_for_name_entry,X                             ;048625|9FA0187F|7F18A0;
    INX #2                                                             ;048629|E8      |      ; advance to next tilemap entry
    INC.B $00                                                          ;04862B|E600    |001029; tile ID advances by 2
    INC.B $00                                                          ;04862D|E600    |001029;
    LDA.B $00                                                          ;04862F|A500    |001029;
  ; CMP.W #$0190                                                       ;048631|C99001  |      ; implicit: 0x190 - 0x184 = 0xC = 0x6 * 2 => limit for # characters to draw
    cmp.w #!TileIdOfEndOfName
    BNE LOOP_048622                                                    ;048634|D0EC    |048622;
  ; REP #$30                                                           ;048636|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;04863D|60      |      ;
    jmp.w pull_YXAPD_rts

DMA_char_grid_tilemap_to_VRAM_04863E:
    PHD                                                                ;04863E|0B      |      ;
    COP #$0A                                                           ;04863F|020A    |      ;
    db $5B                                                             ;048641|        |      ; flags
    dw $7000,$0400                                                     ;048641|        |      ; VRAM address $7000.w, DMA transfer of 0x400 bytes
    db $01                                                             ;048707|        |      ; DMA params
    dl BUFFER_tilemaps_for_name_entry                                  ;048647|        |      ; source data pointer $7F18A0
    db $80,$09                                                         ;04864A|        |      ; VRAM address increment mode
  ; PHP                                                                ;04864C|08      |      ;
  ; REP #$30                                                           ;04864D|C230    |      ;
  ; PHA : PHX : PHY
  ; BRK #$0C                                                           ;048652|000C    |      ;
  ; BRK #$00                                                           ;048654|0000    |      ;
  ; dw $0008                                                           ;048656|        |      ;
  ; REP #$30                                                           ;048658|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;04865F|60      |      ;
    jmp.w DoBRK0C_BRK_00_0008_WithParamsFilledInOnDirectPage

write_two_tile_ID_columns_for_list_X_at_01884E_048660:
    PHD                                                                ;048660|0B      |      ;
    COP #$00                                                           ;048661|0200    |      ;
    db $02                                                             ;048663|        |      ;
    PHP                                                                ;048664|08      |      ;
    REP #$30                                                           ;048665|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;04866A|E220    |      ; subroutine input is a list index (00-27)
  ; LDA.W LIST_tile_ID_for_name_entry_tilemap_01884E,X                 ;04866C|BD4E88  |01884E; $00 <- a tile ID from list
    lda.w ListTileIdsForTwoColumnWrites,x
    STA.B $00                                                          ;04866F|8500    |001028;
    INC A                                                              ;048671|1A      |      ; $01 <- the tile ID directly to its right
    STA.B $01                                                          ;048672|8501    |001029;
  ; LDA.W LIST_num_tile_rows_of_object_018876,X                        ;048674|BD7688  |018876; $02 <- loop ctr size = height of columns
    lda.w ListNumTileRowsForButton,x
    STA.B $02                                                          ;048677|8502    |00102A;
    REP #$20                                                           ;048679|C220    |      ;
    TXA                                                                ;04867B|8A      |      ;
    ASL A                                                              ;04867C|0A      |      ;
    TAY                                                                ;04867D|A8      |      ;
  ; LDX.W LIST_starting_offsets_in_tilemap_buffer_01889E,Y             ;04867E|BE9E88  |01889E;
    ldx.w ListStartingTilemapOffsetsForButtons,y
LOOP_048681:
    SEP #$20                                                           ;048681|E220    |      ;
    LDA.B $00                                                          ;048683|A500    |001028; store tile ID for left half
    STA.L BUFFER_tilemaps_for_name_entry,X                             ;048685|9FA0187F|7F18A0;
    CLC                                                                ;048689|18      |      ; prepare to write the left tile ID for next row down
    ADC.B #$10                                                         ;04868A|6910    |      ;
    STA.B $00                                                          ;04868C|8500    |001028;
    INX                                                                ;04868E|E8      |      ; store tile ID for right half
    INX                                                                ;04868F|E8      |      ;
    LDA.B $01                                                          ;048690|A501    |001029;
    STA.L BUFFER_tilemaps_for_name_entry,X                             ;048692|9FA0187F|7F18A0;
    CLC                                                                ;048696|18      |      ; prepare to write the right tile ID for next row down
    ADC.B #$10                                                         ;048697|6910    |      ;
    STA.B $01                                                          ;048699|8501    |001029;
    DEC.B $02                                                          ;04869B|C602    |00102A; check if more tile rows to fill in
; DEC already sets/clears Z flag, and value from loading $02 is discarded
  ; LDA.B $02                                                          ;04869D|A502    |00102A;
    BEQ restore_regs_RTL_0486AB                                        ;04869F|F00A    |0486AB;
    REP #$20                                                           ;0486A1|C220    |      ; otherwise, move offset down by one tile row
    TXA                                                                ;0486A3|8A      |      ;
    CLC                                                                ;0486A4|18      |      ;
    ADC.W #$003E                                                       ;0486A5|693E00  |      ;
    TAX                                                                ;0486A8|AA      |      ;
    BRA LOOP_048681                                                    ;0486A9|80D6    |048681;
restore_regs_RTL_0486AB:
  ; REP #$30                                                           ;0486AB|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;0486B2|6B      |      ;
  ; RTS
    jmp.w pull_YXAPD_rts

draw_box_edges_for_name_entry_screen_0486B3:
    PHD                                                                ;0486B3|0B      |      ; input: offset in X, either 0 or 0x7, to access one of two lists
    COP #$00                                                           ;0486B4|0200    |      ; 0x0 is for Tooru/Mari name entry, 0x7 is for killer name entry
    db $06                                                             ;0486B6|        |      ; free up 7 bytes on DP
    PHP                                                                ;0486B7|08      |      ;
    REP #$30                                                           ;0486B8|C230    |      ;
    PHA : PHX : PHY
    TXY                                                                ;0486BD|9B      |      ; Y <- offset for which window element to use
LOOP_do_one_window_element_0486BE:
    SEP #$20                                                           ;0486BE|E220    |      ;
    LDA.W LIST_tile_ID_for_box_elements_on_name_entry_0188EE,X         ;0486C0|BDEE88  |0188EE; $01 <- value from $0188EE list
    CMP.B #$FF                                                         ;0486C3|C9FF    |      ; FF is end of list
    BEQ restore_regs_RTS_0486F7                                        ;0486C5|F030    |0486F7;
    STA.B $01                                                          ;0486C7|8501    |001025;
    LDA.W LIST_repeat_count_for_tile_ID_018926,X                       ;0486C9|BD2689  |018926;
    STA.B $06                                                          ;0486CC|8506    |00102A; is there a reason this gets stored to $06?
    STA.B $00                                                          ;0486CE|8500    |001024;
    REP #$20                                                           ;0486D0|C220    |      ;
    TXA : ASL : TAX
    LDA.W LIST_skip_sizes_between_entries_018910,X                     ;0486D5|BD1089  |018910;
    STA.B $04                                                          ;0486D8|8504    |001028;
    LDA.W LIST_offsets_in_tilemap_buffer_for_name_entry_boxes_0188FA,X ;0486DA|BDFA88  |0188FA;
    TAX                                                                ;0486DD|AA      |      ;
    SEP #$20                                                           ;0486DE|E220    |      ;
LOOP_fill_tiles_for_window_element_0486E0:
    LDA.B $01                                                          ;0486E0|A501    |001025; write the tile ID value to the tilemap buffer
    STA.L BUFFER_tilemaps_for_name_entry,X                             ;0486E2|9FA0187F|7F18A0;
    REP #$20                                                           ;0486E6|C220    |      ;
    TXA                                                                ;0486E8|8A      |      ; skip by appropriate amount (one tile, or one tile row)
    CLC                                                                ;0486E9|18      |      ;
    ADC.B $04                                                          ;0486EA|6504    |001028;
    TAX                                                                ;0486EC|AA      |      ;
    SEP #$20                                                           ;0486ED|E220    |      ;
    DEC.B $00                                                          ;0486EF|C600    |001024;
    BNE LOOP_fill_tiles_for_window_element_0486E0                      ;0486F1|D0ED    |0486E0;
    INY                                                                ;0486F3|C8      |      ;
    TYX                                                                ;0486F4|BB      |      ;
    BRA LOOP_do_one_window_element_0486BE                              ;0486F5|80C7    |0486BE;
restore_regs_RTS_0486F7:
  ; REP #$30                                                           ;0486F7|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;0486FE|60      |      ;
    jmp.w pull_YXAPD_rts

DMA_tilemap_for_name_entry_buttons_windows_to_VRAM_0486FF:
    PHD                                                                ;0486FF|0B      |      ;
    COP #$0A                                                           ;048700|020A    |      ;
    db $5B                                                             ;048702|        |      ; flags
    dw $5000,$0800                                                     ;048703|        |      ; VRAM address $5000.w, DMA transfer of 0x800 bytes
    db $01                                                             ;048707|        |      ; DMA params
    dl BUFFER_tilemaps_for_name_entry                                  ;048708|        |      ; source data pointer $7F18A0
    db $80,$09                                                         ;04870B|        |      ; VRAM address increment mode
  ; PHP                                                                ;04870D|08      |      ;
  ; REP #$30                                                           ;04870E|C230    |      ;
  ; PHA : PHX : PHY
  ; BRK #$0C                                                           ;048713|000C    |      ;
  ; BRK #$00                                                           ;048715|0000    |      ;
  ; dw $0008                                                           ;048717|        |      ;
  ; REP #$30                                                           ;048719|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048720|6B      |      ;
  ; RTS
    jmp.w DoBRK0C_BRK_00_0008_WithParamsFilledInOnDirectPage

copy_gfx_data_for_name_entry_buttons_048721:
!NameEntryButtonGfxSize = $0F10
    PHD                                                                ;048721|0B      |      ;
    COP #$02                                                           ;048722|0202    |      ;
    dw $0080                                                           ;048724|        |      ; $00 <- 0x0080
    db $01                                                             ;048726|        |      ;
    PHP                                                                ;048727|08      |      ;
    REP #$30                                                           ;048728|C230    |      ;
    PHA : PHX : PHY
    LDX.W #$0000                                                       ;04872D|A20000  |      ;
    TXY                                                                ;048730|9B      |      ;
LOOP_write_sixteen_00_bytes_048731:
    LDA.W #$0000                                                       ;048731|A90000  |      ;
    STA.L $7F0000,X                                                    ;048734|9F00007F|7F0000;
    INX #2                                                             ;048738|E8      |      ;
    LSR.B $00                                                          ;04873A|4600    |001029; this gets initialized with 0x0080 as above in COP
    BCC LOOP_write_sixteen_00_bytes_048731                             ;04873C|90F3    |048731;

    LDA.W #$0080                                                       ;04873E|A98000  |      ; reinit with 0x0080
    STA.B $00                                                          ;048741|8500    |001029;
LOOP_048743:
    LDA.W GFX_DATA_name_entry_menu_button_01BDDB,Y                     ;048743|B9DBBD  |01BDDB; read data for the "enter name" menu's text
    CPY.W #!NameEntryButtonGfxSize                                     ;048746|C0100F  |      ;
    BEQ restore_regs_RTS_04875E                                        ;048749|F013    |04875E;
    STA.L $7F0000,X                                                    ;04874B|9F00007F|7F0000;
    INX #2
    INY #2
    LSR.B $00                                                          ;048753|4600    |001029;
    BCC LOOP_048743                                                    ;048755|90EC    |048743;
    LDA.W #$0080                                                       ;048757|A98000  |      ;
    STA.B $00                                                          ;04875A|8500    |001029;
    BRA LOOP_write_sixteen_00_bytes_048731                             ;04875C|80D3    |048731;
restore_regs_RTS_04875E:
  ; REP #$30                                                           ;04875E|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;048765|60      |      ;
    jmp.w pull_YXAPD_rts

use_list_X_at_018931_to_write_tile_IDs_048766:
    PHD                                                                ;048766|0B      |      ;
    COP #$00                                                           ;048767|0200    |      ;
    db $00                                                             ;048769|        |      ;
    PHP                                                                ;04876A|08      |      ;
    REP #$30                                                           ;04876B|C230    |      ;
    PHA : PHX : PHY
    LDA.W LIST_offsets_for_01893B_at_018931,X                          ;048770|BD3189  |018931;
    TAX                                                                ;048773|AA      |      ;
LOOP_048774:
    SEP #$20                                                           ;048774|E220    |      ;
    LDA.W LISTs_tile_IDs_for_name_entry_screen_01893B,X                ;048776|BD3B89  |01893B; get tile ID number for name entry screen (usually box borders)
    CMP.B #$FF                                                         ;048779|C9FF    |      ;
    BEQ restore_regs_RTL_048797                                        ;04877B|F01A    |048797;
    STA.B $00                                                          ;04877D|8500    |00102A; store byte from list, copy it into memory below at $7F18A0
    TXY                                                                ;04877F|9B      |      ;
    REP #$20                                                           ;048780|C220    |      ;
    TXA : ASL : TAX                                                    ;048782|8A      |      ; use X offset from $018931 to address 16-bit values
    LDA.W LIST_offsets_for_name_entry_screen_tilemap_buffer_01895B,X   ;048785|BD5B89  |01895B;
    TAX                                                                ;048788|AA      |      ;
    SEP #$20                                                           ;048789|E220    |      ;
    LDA.B $00                                                          ;04878B|A500    |00102A;
    STA.L BUFFER_tilemaps_for_name_entry,X                             ;04878D|9FA0187F|7F18A0;
    REP #$20                                                           ;048791|C220    |      ;
    INY                                                                ;048793|C8      |      ; advance pointer index at $01893B
    TYX                                                                ;048794|BB      |      ;
    BRA LOOP_048774                                                    ;048795|80DD    |048774;
restore_regs_RTL_048797:
  ; REP #$30                                                           ;048797|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;04879E|6B      |      ;
  ; RTS
    jmp.w pull_YXAPD_rts

DMA_char_grid_menu_gfx_from_7F0000_to_VRAM_BG3_04879F:
    PHD                                                                ;04879F|0B      |      ;
    COP #$0A                                                           ;0487A0|020A    |      ;
    db $DB                                                             ;0487A2|        |      ; flags
    dw $4000,$1E00                                                     ;0487A3|        |      ; VRAM address $4000.w, DMA 0x1E00 bytes
    db $01                                                             ;0487A7|        |      ; DMA params
    dl $7F0000                                                         ;0487A8|        |7F0000; source data $7F0000
    db $80,$09                                                         ;0487AB|        |      ; VRAM address increment mode, COP size
  ; PHP                                                                ;0487AD|08      |      ;
  ; REP #$30                                                           ;0487AE|C230    |      ;
  ; PHA : PHX : PHY
  ; BRK #$0C                                                           ;0487B3|000C    |      ;
  ; BRK #$00                                                           ;0487B5|0000    |      ;
  ; dw $0008                                                           ;0487B7|        |      ;
  ; REP #$30                                                           ;0487B9|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;0487C0|60      |      ;
    jmp.w DoBRK0C_BRK_00_0008_WithParamsFilledInOnDirectPage

copy_white_and_light_and_dark_gray_into_CGRAM_0487C1:
    PHP                                                                ;0487C1|08      |      ;
    REP #$30                                                           ;0487C2|C230    |      ;
    PHA : PHX : PHY
    LDA.W color_dark_gray_0x2108_01BDC3                                ;0487C7|ADC3BD  |01BDC3; 0x2108 = BGR 8,8,8; dark gray
    STA.W $0108                                                        ;0487CA|8D0801  |010108;
    LDA.W color_light_gray_0x3DEF_01BDCB                               ;0487CD|ADCBBD  |01BDCB; 0x3DEF = BGR F,F,F; light gray
    STA.W $0110                                                        ;0487D0|8D1001  |010110;
    LDA.W color_white_0x7FFF_01BDD3                                    ;0487D3|ADD3BD  |01BDD3; 0x7FFF = BGR 1F,1F,1F; white
    STA.W $0118                                                        ;0487D6|8D1801  |010118;
    LDA.W color_dark_gray_0x2108_01BDC3                                ;0487D9|ADC3BD  |01BDC3;
    STA.W $0208                                                        ;0487DC|8D0802  |010208;
    LDA.W color_light_gray_0x3DEF_01BDCB                               ;0487DF|ADCBBD  |01BDCB;
    STA.W $0210                                                        ;0487E2|8D1002  |010210;
    LDA.W color_white_0x7FFF_01BDD3                                    ;0487E5|ADD3BD  |01BDD3;
    STA.W $0218                                                        ;0487E8|8D1802  |010218;
    LDA.W #$8080                                                       ;0487EB|A98080  |      ;
    TSB.W $166E                                                        ;0487EE|0C6E16  |01166E;
  ; REP #$30                                                           ;0487F1|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;0487F7|60      |      ;
    jmp.w pull_YXAP_rts

; ------------------------------------------------------------------------------

check_which_char_grid_and_read_char_data_0487F8:
    PHD                                                                ;0487F8|0B      |      ;
    COP #$00                                                           ;0487F9|0200    |      ;
    db $09                                                             ;0487FB|        |      ;
    PHP : PHY : PHX
    STA.B $00                                                          ;0487FF|8500    |001013;
  ; CMP.W #$B13B                                                       ;048801|C93BB1  |      ; check if hiragana
    CMP.W #Page1NameEntryCharData
    BEQ case_get_contiguous_char_data_block_048825                     ;048804|F01F    |048825;
  ; CMP.W #$B1EF                                                       ;048806|C9EFB1  |      ; check if katakana
    CMP.W #Page1NameEntryCharData+!BytesPerCharScreen
    BEQ case_get_contiguous_char_data_block_048825                     ;048809|F01A    |048825;
  ; CMP.W #$B2A3                                                       ;04880B|C9A3B2  |      ; check if scrolling up from あ row to わ row in kanji grid
    CMP.W #Page1NameEntryCharData+2*!BytesPerCharScreen
    BMI case_scrolling_up_to_wa_kanji_row_04883E                       ;04880E|302E    |04883E;
case_in_kanji_grid_048810:
    LDA.L ptr_to_end_of_name_entry_char_data_BBB3                      ;048810|AFA0207F|7F20A0; otherwise, any other row in kanji grid
    SEC                                                                ;048814|38      |      ; get (end of data) - (current position)
    SBC.B $00                                                          ;048815|E500    |001013;
    BEQ use_start_of_kanji_data_if_at_end_048820                       ;048817|F007    |048820;
    CMP.W #!BytesPerCharScreen                                         ;048819|C9B400  |      ; 0xB4 = 180 = 90 chars (1 screen) worth of data
    BMI case_show_both_end_and_start_of_grid_048843                    ;04881C|3025    |048843; if result < 0xB4, need to show data @ both end AND start of the table
    BRA case_get_contiguous_char_data_block_048825                     ;04881E|8005    |048825; otherwise, just grab a contiguous block of 0xB4 bytes

use_start_of_kanji_data_if_at_end_048820:
  ; LDA.W #$B2A3                                                       ;048820|A9A3B2  |      ; set to start of kanji char data if at end
    LDA.W #Page1NameEntryCharData+2*!BytesPerCharScreen
    STA.B $00                                                          ;048823|8500    |001013;
case_get_contiguous_char_data_block_048825:
    LDA.B $00                                                          ;048825|A500    |001013; set starting ROM position to read char encodings from
    STA.B $04                                                          ;048827|8504    |001017;
    STA.B $08                                                          ;048829|8508    |00101B;
    LDA.W #!BytesPerCharScreen                                         ;04882B|A9B400  |      ; read 180 bytes of data = 90 chars = 1 screen
    STA.B $02                                                          ;04882E|8502    |001015;
    LDA.W #$0024                                                       ;048830|A92400  |      ; starting position to write to
    STA.B offset_for_char_font_data_in_name_entry-$1013                ;048833|8506    |001019;
    LDX.W #$0000                                                       ;048835|A20000  |      ;
  ; JSL.L read_encoding_and_font_data_for_N_chars_in_grid_0488EC       ;048838|22EC8804|0488EC;
    JSR.W read_encoding_and_font_data_for_N_chars_in_grid_0488EC
    BRA exit_after_transferring_char_grid_font_data_to_VRAM_048846     ;04883C|8008    |048846;

case_scrolling_up_to_wa_kanji_row_04883E:
    JSR.W handle_scrolling_up_to_wa_row_in_kanji_grid_048851           ;04883E|205188  |048851;
    BRA exit_after_transferring_char_grid_font_data_to_VRAM_048846     ;048841|8003    |048846;
case_show_both_end_and_start_of_grid_048843:
    JSR.W handle_showing_kanji_at_both_end_and_start_of_block_0488A4   ;048843|20A488  |0488A4;
exit_after_transferring_char_grid_font_data_to_VRAM_048846:
  ; JSL.L transfer_char_grid_font_data_on_screen_to_VRAM_6000_04833F   ;048846|223F8304|04833F;
    JSR.W transfer_char_grid_font_data_on_screen_to_VRAM_6000_04833F
    LDA.B $08                                                          ;04884A|A508    |00101B;
    PLX : PLY : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048850|6B      |      ;
    RTS

handle_scrolling_up_to_wa_row_in_kanji_grid_048851:
    PHP                                                                ;048851|08      |      ;
    REP #$30                                                           ;048852|C230    |      ;
    PHA : PHX : PHY
  ; LDA.W #$B2A3                                                       ;048857|A9A3B2  |      ; $00 should be $B28F here, so should be that $02 <- 0x14
    LDA.W #Page1NameEntryCharData+2*!BytesPerCharScreen
    SEC                                                                ;04885A|38      |      ;
    SBC.B $00                                                          ;04885B|E500    |001013;
    STA.B $02                                                          ;04885D|8502    |001015;
    TAY                                                                ;04885F|A8      |      ;
    LDA.W #$0024                                                       ;048860|A92400  |      ; starting offset to write char encoding data to
    STA.B offset_for_char_font_data_in_name_entry-$1013                ;048863|8506    |001019;
    LDA.L ptr_to_end_of_name_entry_char_data_BBB3                      ;048865|AFA0207F|7F20A0; $04 = starting ROM position to read from <- BBB3 - 0x14 = BB9F
    SEC                                                                ;048869|38      |      ; i.e. start reading the row with わ kanji
    SBC.B $02                                                          ;04886A|E502    |001015;
    STA.B $04                                                          ;04886C|8504    |001017;
    STA.B $08                                                          ;04886E|8508    |00101B;
    LDX.W #$0000                                                       ;048870|A20000  |      ;
  ; JSL.L read_encoding_and_font_data_for_N_chars_in_grid_0488EC       ;048873|22EC8804|0488EC;
    JSR.W read_encoding_and_font_data_for_N_chars_in_grid_0488EC
    TYA                                                                ;048877|98      |      ; 0x14 >> 3 = 0x2 (see $048857)
    LSR #3
    TAX                                                                ;04887B|AA      |      ;
    LDA.W LIST_offsets_to_start_writing_char_encoding_data_01899B,X    ;04887C|BD9B89  |01899B; read value 0x0044 = offset to start writing data to after first row
    STA.B offset_for_char_font_data_in_name_entry-$1013                ;04887F|8506    |001019;
    STY.B $02                                                          ;048881|8402    |001015; already wrote 0x14 bytes (one row) of characters
    TYX                                                                ;048883|BB      |      ;
    LDA.W #!BytesPerCharScreen                                         ;048884|A9B400  |      ; now need to write 0xA0 bytes of characters (ten rows)
    SEC                                                                ;048887|38      |      ;
    SBC.B $02                                                          ;048888|E502    |001015;
    STA.B $02                                                          ;04888A|8502    |001015;
  ; LDA.W #$B2A3                                                       ;04888C|A9A3B2  |      ; set pointer to start reading kanji data from あ row
    LDA.W #Page1NameEntryCharData+2*!BytesPerCharScreen
    STA.B $04                                                          ;04888F|8504    |001017;
    LDA.W #!BytesPerCharScreen                                          ;048891|A9B400  |      ; X <- 0xA0 >> 1 = 0x50
    SEC                                                                ;048894|38      |      ;
    SBC.B $02                                                          ;048895|E502    |001015;
    LSR A                                                              ;048897|4A      |      ;
    TAX                                                                ;048898|AA      |      ;
  ; JSL.L read_encoding_and_font_data_for_N_chars_in_grid_0488EC       ;048899|22EC8804|0488EC;
    JSR.W read_encoding_and_font_data_for_N_chars_in_grid_0488EC
  ; REP #$30                                                           ;04889D|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;0488A3|60      |      ;
    jmp.w pull_YXAP_rts

handle_showing_kanji_at_both_end_and_start_of_block_0488A4:
    PHP                                                                ;0488A4|08      |      ;
    REP #$30                                                           ;0488A5|C230    |      ;
    PHA : PHX : PHY
    TAY                                                                ;0488AA|A8      |      ; assume here that A < 0xB4 from control flow @ $04881C
    STA.B $02                                                          ;0488AB|8502    |001015;
    LDA.B $00                                                          ;0488AD|A500    |001013; set pointer for where to start reading char encoding data
    STA.B $04                                                          ;0488AF|8504    |001017;
    STA.B $08                                                          ;0488B1|8508    |00101B;
    LDA.W #$0024                                                       ;0488B3|A92400  |      ; set starting offset for where to write chars
    STA.B offset_for_char_font_data_in_name_entry-$1013                ;0488B6|8506    |001019;
    LDX.W #$0000                                                       ;0488B8|A20000  |      ;
  ; JSL.L read_encoding_and_font_data_for_N_chars_in_grid_0488EC       ;0488BB|22EC8804|0488EC;
    JSR.W read_encoding_and_font_data_for_N_chars_in_grid_0488EC
    TYA                                                                ;0488BF|98      |      ; take # bytes written just now, and get table entry
    LSR #3
    TAX                                                                ;0488C3|AA      |      ;
    LDA.W LIST_offsets_to_start_writing_char_encoding_data_01899B,X    ;0488C4|BD9B89  |01899B; set starting offset for where to write chars
    STA.B offset_for_char_font_data_in_name_entry-$1013                ;0488C7|8506    |001019;
  ; LDA.W #$B2A3                                                       ;0488C9|A9A3B2  |      ; set pointer to start reading from あ row of kanji data
    LDA.W #Page1NameEntryCharData+2*!BytesPerCharScreen
    STA.B $04                                                          ;0488CC|8504    |001017;
    STY.B $02                                                          ;0488CE|8402    |001015;
  ; TYX                                                                ;0488D0|BB      |      ; (useless TYX gets overwritten by TAX below)
    LDA.W #!BytesPerCharScreen                                          ;0488D1|A9B400  |      ; $02 <- 0xB4 - $02 = remaining # bytes that need to be read
    SEC                                                                ;0488D4|38      |      ;
    SBC.B $02                                                          ;0488D5|E502    |001015;
    STA.B $02                                                          ;0488D7|8502    |001015;
    LDA.W #!BytesPerCharScreen                                          ;0488D9|A9B400  |      ;
    SEC                                                                ;0488DC|38      |      ;
    SBC.B $02                                                          ;0488DD|E502    |001015;
    LSR A                                                              ;0488DF|4A      |      ;
    TAX                                                                ;0488E0|AA      |      ;
  ; JSL.L read_encoding_and_font_data_for_N_chars_in_grid_0488EC       ;0488E1|22EC8804|0488EC;
    JSR.W read_encoding_and_font_data_for_N_chars_in_grid_0488EC
  ; REP #$30                                                           ;0488E5|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;0488EB|60      |      ;
    jmp.w pull_YXAP_rts

read_encoding_and_font_data_for_N_chars_in_grid_0488EC:
    PHD                                                                ;0488EC|0B      |      ;
    COP #$02                                                           ;0488ED|0202    |      ;
    db !CharsPerRow,$00,$05                                            ;0488EF|        |      ; $00 <- 0xA = # loop iterations below
    PHP                                                                ;0488F2|08      |      ;
    REP #$30                                                           ;0488F3|C230    |      ;
    PHA : PHX : PHY
    SEP #$30                                                           ;0488F8|E230    |      ;
    STX.B $04                                                          ;0488FA|8604    |001011;
    LDA.B $08                                                          ;0488FC|A508    |001015;
    LSR A                                                              ;0488FE|4A      |      ;
    STA.B $05                                                          ;0488FF|8505    |001012;
    REP #$30                                                           ;048901|C230    |      ;
    LDA.B $0A                                                          ;048903|A50A    |001017; $02 <- relative offset from start of name entry data ($01B12B)
    SEC                                                                ;048905|38      |      ;
  ; SBC.W #$B12B                                                       ;048906|E92BB1  |      ;
    SBC.W #StartOfNameEntryCharData
    STA.B $02                                                          ;048909|8502    |00100F;
    LDY.W #$0000                                                       ;04890B|A00000  |      ;
    LDX.B offset_for_char_font_data_in_name_entry-$100D                ;04890E|A60C    |001019; $0C has starting offset for where to write char encoding values
LOOP_fill_in_buffer_of_chars_on_screen_048910:
    LDA.B ($0A),Y                                                      ;048910|B10A    |001017; read char data from ROM into memory buffer of chars ON SCREEN
    STA.L name_entry_chars_on_screen,X                                 ;048912|9F20167F|7F1620;
    DEC.B $08                                                          ;048916|C608    |001015;
    DEC.B $08                                                          ;048918|C608    |001015;
    INY #2
    INX #2
    DEC.B $00                                                          ;04891E|C600    |00100D;
    BNE LOOP_fill_in_buffer_of_chars_on_screen_048910                  ;048920|D0EE    |048910;
    TXA                                                                ;048922|8A      |      ; move down to start of next char row
    CLC                                                                ;048923|18      |      ;
    ADC.W #$000C                                                       ;048924|690C00  |      ;
    TAX                                                                ;048927|AA      |      ;
    LDA.W #!CharsPerRow                                                ;048928|A90A00  |      ; do another ten characters if needed
    STA.B $00                                                          ;04892B|8500    |00100D;
    LDA.B $08                                                          ;04892D|A508    |001015;
    BNE LOOP_fill_in_buffer_of_chars_on_screen_048910                  ;04892F|D0DF    |048910;
  ; JSL.L wrapper_to_read_gfx_data_for_N_chars_in_grid_048361          ;048931|22618304|048361;
    JSR.W wrapper_to_read_gfx_data_for_N_chars_in_grid_048361
  ; REP #$30                                                           ;048935|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;04893C|6B      |      ;
  ; RTS
    jmp.w pull_YXAPD_rts

; ------------------------------------------------------------------------------

; COP input with words, if perhaps this makes DP layout easier to understand
  ; dw $0000,$1200,$0000,$0000,$0000,$0000,$0001

allow_player_to_enter_name_for_character_based_on_A_Y_04893D:
    PHD                                                                ;04893D|0B      |      ; inputs: A=0 and Y=0 is for Tooru, A=0 and Y != 0 is for Mari
    COP #$0E                                                           ;04893E|020E    |      ; A != 0 is for entering killer's name
    db $00,$00,$00,$12,$00,$00,$00,$00                                 ;048940|        |      ; $00
    db $00,$00,$00,$00,$01,$00,$0D                                     ;048948|        |      ; $08
    PHP                                                                ;04894F|08      |      ;
    REP #$30                                                           ;048950|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048955|E220    |      ;

; change behavior: if A == 0 (Tooru/Mari), set to start on kana grid
    pha
    bne +
    lda #$02
  + STA.B $0B                                                          ;048957|850B    |001028; input in A differentiates between entering name for Tooru/Mari (0) or killer (not 0)
    pla

    REP #$20                                                           ;048959|C220    |      ;
    BEQ case_enter_name_for_Tooru_or_Mari_048978                       ;04895B|F01B    |048978;
case_enter_name_of_killer_04895D:
  ; LDA.W #$B13B                                                       ;04895D|A93BB1  |      ; $01B13B is for hiragana char data
    lda.w #Page1NameEntryCharData
  ; JSL.L check_which_char_grid_and_read_char_data_0487F8              ;048960|22F88704|0487F8;
    jsr.w check_which_char_grid_and_read_char_data_0487F8
    STA.B $09                                                          ;048964|8509    |001026;
  ; JSL.L DMA_tilemap_for_name_entry_buttons_windows_to_VRAM_0486FF    ;048966|22FF8604|0486FF;
    jsr.w DMA_tilemap_for_name_entry_buttons_windows_to_VRAM_0486FF
  ; JSL.L get_font_data_for_current_name_state_049111                  ;04896A|22119104|049111;
    jsr.w get_font_data_for_current_name_state_049111
    JSR.W enable_BG2_BG3_sprites_049233                                ;04896E|203392  |049233;
    BRK #$00                                                           ;048971|0000    |      ;
    dw $0001                                                           ;048973|        |      ;
    JMP.W CODE_allow_player_to_enter_name_0489FB                       ;048975|4CFB89  |0489FB;

case_enter_name_for_Tooru_or_Mari_048978:
    CPY.W #$0000                                                       ;048978|C00000  |      ; Y contains input for differentiating entering name for Tooru/Mari
    BEQ +                                                              ;04897B|F002    |04897F;
    STY.B $05                                                          ;04897D|8405    |001022;
; set to start on kanji grid
; + LDA.W #$B2A3                                                       ;04897F|A9A3B2  |      ; $01B2A3 is for kanji char data
; + lda.w #Page1NameEntryCharData+2*!BytesPerCharScreen
; or set to start on originally hiragana grid
  + lda.w #Page1NameEntryCharData
  ; JSL.L check_which_char_grid_and_read_char_data_0487F8              ;048982|22F88704|0487F8;
    jsr.w check_which_char_grid_and_read_char_data_0487F8
    STA.B $09                                                          ;048986|8509    |001026;
  ; JSL.L get_font_data_for_current_name_state_049111                  ;048988|22119104|049111;
    jsr.w get_font_data_for_current_name_state_049111

    ; cut out, don't need
  ; JSL.L draw_gray_boxes_behind_hiragana_on_kanji_screen_049189       ;04898C|22899104|049189;
  ; JSR.W draw_gray_boxes_behind_hiragana_on_kanji_screen_049189

  ; JSL.L DMA_tilemap_for_name_entry_buttons_windows_to_VRAM_0486FF    ;048990|22FF8604|0486FF;
    jsr.w DMA_tilemap_for_name_entry_buttons_windows_to_VRAM_0486FF
  ; JSL.L set_up_PPU_window_regs_0491D1                                ;048994|22D19104|0491D1;
    jsr.w set_up_PPU_window_regs_0491D1
    BRK #$00                                                           ;048998|0000    |      ;
    dw $0001                                                           ;04899A|        |      ;
    JSR.W enable_BG2_BG3_sprites_049233                                ;04899C|203392  |049233;
    BRK #$00                                                           ;04899F|0000    |      ;
    dw $0001                                                           ;0489A1|        |      ;
    BRK #$03                                                           ;0489A3|0003    |      ; check for any input at all on controller 1
    dw $FFF0                                                           ;0489A5|        |      ;
    LDX.W #$00B4                                                       ;0489A7|A2B400  |      ; 0xB4 = 180 = 3 seconds at 60 fps?
LOOP_0489AA:
    BRK #$00                                                           ;0489AA|0000    |      ;
    dw $0003                                                           ;0489AC|        |      ;
    BRK #$1B                                                           ;0489AE|001B    |      ;
    BCC case_no_input_0489B4                                           ;0489B0|9002    |0489B4;
    BRA case_input_detected_0489BB                                     ;0489B2|8007    |0489BB;
case_no_input_0489B4:
  ; JSL.L handle_color_cycles_for_flashing_squares_0490D2              ;0489B4|22D29004|0490D2;
    jsr.w handle_color_cycles_for_flashing_squares_0490D2
    DEX                                                                ;0489B8|CA      |      ;
    BNE LOOP_0489AA                                                    ;0489B9|D0EF    |0489AA;
case_input_detected_0489BB:
    LDX.W #$0000                                                       ;0489BB|A20000  |      ; clear the "please input a name for [whoever]" box
  ; JSL.L clear_tiles_for_please_input_name_box_or_subject_box_0480E5  ;0489BE|22E58004|0480E5;
    jsr.w clear_tiles_for_please_input_name_box_or_subject_box_0480E5
    LDA.B $05                                                          ;0489C2|A505    |001022; check if box at top left is for "protagonist" or "girlfriend"
    BNE print_girlfriend_box_at_top_left_0489DD                        ;0489C4|D017    |0489DD;
print_protagonist_box_at_top_left_0489C6:
  ; LDX.W #$0014                                                       ;0489C6|A21400  |      ; left third of protagonist box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0489C9|22608604|048660;
  ; LDX.W #$0015                                                       ;0489CD|A21500  |      ; middle third of protagonist box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0489D0|22608604|048660;
  ; LDX.W #$0016                                                       ;0489D4|A21600  |      ; right third of protagonist box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0489D7|22608604|048660;
  ; BRA done_writing_box_0489EB                                        ;0489DB|800E    |0489EB;
    ldx.w #!TwoColumnProtag1
    bra +
print_girlfriend_box_at_top_left_0489DD:
  ; LDX.W #$001A                                                       ;0489DD|A21A00  |      ; left half of girlfriend box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0489E0|22608604|048660;
  ; LDX.W #$001B                                                       ;0489E4|A21B00  |      ; right half of girlfriend box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0489E7|22608604|048660;
    ldx.w #!TwoColumnGirlfriendTopLeft1
  + jsr.w WriteThreeConsecutiveSetsOfTwoTileColumns
done_writing_box_0489EB:
    BRK #$00                                                           ;0489EB|0000    |      ;
    dw $0001                                                           ;0489ED|        |      ;
  ; JSL.L disable_HDMA_channel_6_04921A                                ;0489EF|221A9204|04921A;
    jsr.w disable_HDMA_channel_6_04921A
    BRK #$00                                                           ;0489F3|0000    |      ;
    dw $0001                                                           ;0489F5|        |      ;
  ; JSL.L DMA_tilemap_for_name_entry_buttons_windows_to_VRAM_0486FF    ;0489F7|22FF8604|0486FF;
    jsr.w DMA_tilemap_for_name_entry_buttons_windows_to_VRAM_0486FF

CODE_allow_player_to_enter_name_0489FB:
    BRK #$03                                                           ;0489FB|0003    |      ; check for all buttons except Select on controller 1
    dw $DFF2                                                           ;0489FD|        |      ;
LOOP_check_for_inputs_on_name_entry_grid_0489FF:
    BRK #$00                                                           ;0489FF|0000    |      ;
    dw $0003                                                           ;048A01|        |      ;
  ; JSL.L handle_color_cycles_for_flashing_squares_0490D2              ;048A03|22D29004|0490D2;
    jsr.w handle_color_cycles_for_flashing_squares_0490D2
    BRK #$1B                                                           ;048A07|001B    |      ; check for any input at all
    BCC LOOP_check_for_inputs_on_name_entry_grid_0489FF                ;048A09|90F4    |0489FF; if none, skip back
    LDA.W contr1_control_flow_state                                    ;048A0B|AD9903  |010399; $05 <- P1 controller state
    STA.B char_grid_contr_input_val-$101D                              ;048A0E|8505    |001022;
    JSR.W char_grid_check_START_048C1C                                 ;048A10|201C8C  |048C1C;
    JSR.W char_grid_check_A_L_048BFC                                   ;048A13|20FC8B  |048BFC;
    JSR.W char_grid_check_B_048C49                                     ;048A16|20498C  |048C49;
    JSR.W char_grid_check_X_048C66                                     ;048A19|20668C  |048C66;
    JSR.W char_grid_check_Y_048C93                                     ;048A1C|20938C  |048C93;
    JSR.W char_grid_check_UP_048A58                                    ;048A1F|20588A  |048A58;
    JSR.W char_grid_check_DOWN_048A8D                                  ;048A22|208D8A  |048A8D;
    JSR.W char_grid_check_RIGHT_048AF5                                 ;048A25|20F58A  |048AF5;
    JSR.W char_grid_check_LEFT_048AC2                                  ;048A28|20C28A  |048AC2;
    JSR.W char_grid_check_UP_LEFT_048B28                               ;048A2B|20288B  |048B28;
    JSR.W char_grid_check_DOWN_LEFT_048B5D                             ;048A2E|205D8B  |048B5D;
    JSR.W char_grid_check_UP_RIGHT_048B92                              ;048A31|20928B  |048B92;
    JSR.W char_grid_check_DOWN_RIGHT_048BC7                            ;048A34|20C78B  |048BC7;
    SEP #$20                                                           ;048A37|E220    |      ;
    ASL.B $0B                                                          ;048A39|060B    |001028; check if we need to update OAM and VRAM after player's input
    BCC +                                                              ;048A3B|9008    |048A45;
  ; JSL.L DMA_OAM_data_for_highlight_boxes_and_all_extra_bytes_049270  ;048A3D|22709204|049270;
  ; JSL.L DMA_tilemap_for_name_entry_buttons_windows_to_VRAM_0486FF    ;048A41|22FF8604|0486FF;
    jsr.w DMA_OAM_data_for_highlight_boxes_and_all_extra_bytes_049270
    jsr.w DMA_tilemap_for_name_entry_buttons_windows_to_VRAM_0486FF
  + LSR.B $0B                                                          ;048A45|460B    |001028;
    REP #$20                                                           ;048A47|C220    |      ;
    LDA.B char_grid_contr_input_val-$101D                              ;048A49|A505    |001022; if a valid name has been submitted to the game, we are done
    AND.W #$2000                                                       ;048A4B|290020  |      ;
    BEQ LOOP_check_for_inputs_on_name_entry_grid_0489FF                ;048A4E|F0AF    |0489FF;
  ; REP #$30                                                           ;048A50|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048A57|6B      |      ;
  ; rts
    jmp.w pull_YXAPD_rts

; ------------------------------------------------------------------------------

; for specifically the d-pad checks, the basic structure in Chunsoft's code is:
; [16-bit mode]
; - set up registers and get input value
; - check particular d-pad bits in input value, tear down if no match
; [8-bit mode]
; - get target grid position from current grid position
; - get what type of thing in the grid we're moving to
; [16-bit mode]
; - get unique index value based on type of input
; - use index value and target position to get jump table index for what to do

; rearrange this as:
; [16-bit mode]
; - set up registers and get input value
; - check particular d-pad bits in input value, tear down if no match
; - get unique index value based on type of input
; [8-bit mode]
; - get target grid position from current grid position
; - get what type of thing in the grid we're moving to
; [16-bit mode]
; - use index value and target position to get jump table index for what to do

; and there's a lot of code that you can reuse between the d-pad subroutines

!CharGridOneRow = $10
!CharGridOneCol = $01
TABLE_char_grid_row_col_deltas:
    db -!CharGridOneRow                 ; Up
    db  !CharGridOneRow                 ; Down
    db -!CharGridOneCol                 ; Left
    db  !CharGridOneCol                 ; Right
    db -!CharGridOneRow-!CharGridOneCol ; Up+Left
    db  !CharGridOneRow-!CharGridOneCol ; Down+Left
    db -!CharGridOneRow+!CharGridOneCol ; Up+Right
    db  !CharGridOneRow+!CharGridOneCol ; Down+Right

char_grid_check_UP_048A58:
    PHP                                                                ;048A58|08      |      ;
    REP #$30                                                           ;048A59|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048A5E|A505    |001022;
    AND.W #$0F00                                                       ;048A60|29000F  |      ; notice that you cannot just do AND #$0800
    CMP.W #$0800                                                       ;048A63|C90008  |      ; this prevents e.g. Up+Down at the same time
  ; BNE restore_regs_RTS_048A86                                        ;048A66|D01E    |048A86;
    BNE IntermediateBranchForTeardown
    LDA.W #$0000                                                       ;048A7A|A90000  |      ; <- moved up
  ; STA.B $01                                                          ;048A7D|8501    |00101E; <- moved up
  ; SEP #$30                                                           ;048A68|E230    |      ;
  ; LDA.B name_entry_grid_curr_position-$101D                          ;048A6A|A503    |001020;
  ; SEC                                                                ;048A6C|38      |      ; subtract 1 from row pos
  ; SBC.B #$10                                                         ;048A6D|E910    |      ;
    bra AcknowledgeDpadInput
  ; STA.B name_entry_grid_target_position-$101D                        ;048A6F|8504    |001021;
  ; TAX                                                                ;048A71|AA      |      ;
  ; LDA.L state_values_for_pos_in_name_entry_grid,X                    ;048A72|BF20127F|7F1220;
  ; STA.B button_type_for_char_grid_curr_pos-$101D                     ;048A76|8500    |00101D;
  ; REP #$30                                                           ;048A78|C230    |      ;
;   JSL.L get_index_for_dpad_input_sub_in_char_grid_048CC0             ;048A7F|22C08C04|048CC0;
  ; JSR.W get_index_for_dpad_input_sub_in_char_grid_048CC0
  ; JSR.W (JUMP_TABLE_handle_button_for_input_048CD8,X)                ;048A83|FCD88C  |048CD8;
; restore_regs_RTS_048A86:
  ; REP #$30                                                           ;048A86|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048A8C|60      |      ;

char_grid_check_DOWN_048A8D:
    PHP                                                                ;048A8D|08      |      ;
    REP #$30                                                           ;048A8E|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048A93|A505    |001022;
    AND.W #$0F00                                                       ;048A95|29000F  |      ;
    CMP.W #$0400                                                       ;048A98|C90004  |      ;
  ; BNE restore_regs_RTS_048ABB                                        ;048A9B|D01E    |048ABB;
    BNE IntermediateBranchForTeardown
    LDA.W #$0002                                                       ;048AAF|A90200  |      ; <- moved up
  ; STA.B $01                                                          ;048AB2|8501    |00101E; <- moved up
  ; SEP #$30                                                           ;048A9D|E230    |      ;
  ; LDA.B name_entry_grid_curr_position-$101D                          ;048A9F|A503    |001020;
  ; CLC                                                                ;048AA1|18      |      ; add 1 to row pos
  ; ADC.B #$10                                                         ;048AA2|6910    |      ;
    bra AcknowledgeDpadInput
  ; STA.B name_entry_grid_target_position-$101D                        ;048AA4|8504    |001021;
  ; TAX                                                                ;048AA6|AA      |      ;
  ; LDA.L state_values_for_pos_in_name_entry_grid,X                    ;048AA7|BF20127F|7F1220;
  ; STA.B button_type_for_char_grid_curr_pos-$101D                     ;048AAB|8500    |00101D;
  ; REP #$30                                                           ;048AAD|C230    |      ;
;   JSL.L get_index_for_dpad_input_sub_in_char_grid_048CC0             ;048AB4|22C08C04|048CC0;
  ; JSR.W get_index_for_dpad_input_sub_in_char_grid_048CC0
  ; JSR.W (JUMP_TABLE_handle_button_for_input_048CD8,X)                ;048AB8|FCD88C  |048CD8;
; restore_regs_RTS_048ABB:
  ; REP #$30                                                           ;048ABB|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048AC1|60      |      ;

char_grid_check_LEFT_048AC2:
    PHP                                                                ;048AC2|08      |      ;
    REP #$30                                                           ;048AC3|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048AC8|A505    |001022;
    AND.W #$0F00                                                       ;048ACA|29000F  |      ;
    CMP.W #$0200                                                       ;048ACD|C90002  |      ;
  ; BNE restore_regs_RTS_048AEE                                        ;048AD0|D01C    |048AEE;
    BNE IntermediateBranchForTeardown
    LDA.W #$0004                                                       ;048AE2|A90400  |      ; <- moved up
  ; STA.B $01                                                          ;048AE5|8501    |00101E; <- moved up
  ; SEP #$30                                                           ;048AD2|E230    |      ;
  ; LDA.B name_entry_grid_curr_position-$101D                          ;048AD4|A503    |001020;
  ; DEC A                                                              ;048AD6|3A      |      ; subtract 1 from col pos
    bra AcknowledgeDpadInput
  ; STA.B name_entry_grid_target_position-$101D                        ;048AD7|8504    |001021;
  ; TAX                                                                ;048AD9|AA      |      ;
  ; LDA.L state_values_for_pos_in_name_entry_grid,X                    ;048ADA|BF20127F|7F1220;
  ; STA.B button_type_for_char_grid_curr_pos-$101D                     ;048ADE|8500    |00101D;
  ; REP #$30                                                           ;048AE0|C230    |      ;
;   JSL.L get_index_for_dpad_input_sub_in_char_grid_048CC0             ;048AE7|22C08C04|048CC0;
  ; JSR.W get_index_for_dpad_input_sub_in_char_grid_048CC0
  ; JSR.W (JUMP_TABLE_handle_button_for_input_048CD8,X)                ;048AEB|FCD88C  |048CD8;
; restore_regs_RTS_048AEE:
  ; REP #$30                                                           ;048AEE|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048AF4|60      |      ;

char_grid_check_RIGHT_048AF5:
    PHP                                                                ;048AF5|08      |      ;
    REP #$30                                                           ;048AF6|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048AFB|A505    |001022;
    AND.W #$0F00                                                       ;048AFD|29000F  |      ;
    CMP.W #$0100                                                       ;048B00|C90001  |      ;
  ; BNE restore_regs_RTS_048B21                                        ;048B03|D01C    |048B21;
    BNE InputCheckTeardown
    LDA.W #$0006                                                       ;048B15|A90600  |      ; <- moved up
  ; STA.B $01                                                          ;048B18|8501    |00101E; <- moved up
  ; SEP #$30                                                           ;048B05|E230    |      ;
  ; LDA.B name_entry_grid_curr_position-$101D                          ;048B07|A503    |001020;
  ; INC A                                                              ;048B09|1A      |      ; add 1 to col pos
    bra AcknowledgeDpadInput
  ; STA.B name_entry_grid_target_position-$101D                        ;048B0A|8504    |001021;
  ; TAX                                                                ;048B0C|AA      |      ;
  ; LDA.L state_values_for_pos_in_name_entry_grid,X                    ;048B0D|BF20127F|7F1220;
  ; STA.B button_type_for_char_grid_curr_pos-$101D                     ;048B11|8500    |00101D;
  ; REP #$30                                                           ;048B13|C230    |      ;
;   JSL.L get_index_for_dpad_input_sub_in_char_grid_048CC0             ;048B1A|22C08C04|048CC0;
  ; JSR.W get_index_for_dpad_input_sub_in_char_grid_048CC0
  ; JSR.W (JUMP_TABLE_handle_button_for_input_048CD8,X)                ;048B1E|FCD88C  |048CD8;
; restore_regs_RTS_048B21:
  ; REP #$30                                                           ;048B21|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048B27|60      |      ;

char_grid_check_UP_LEFT_048B28:
    PHP                                                                ;048B28|08      |      ;
    REP #$30                                                           ;048B29|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048B2E|A505    |001022;
    AND.W #$0F00                                                       ;048B30|29000F  |      ;
    CMP.W #$0A00                                                       ;048B33|C9000A  |      ;
  ; BNE restore_regs_RTS_048B56                                        ;048B36|D01E    |048B56;
    BNE InputCheckTeardown
    LDA.W #$0008                                                       ;048B4A|A90800  |      ; <- moved up
; common branching point for when correct D-PAD input is detected
AcknowledgeDpadInput:
    STA.B $01                                                          ;048B4D|8501    |00101E; <- moved up
    lsr : tax
    SEP #$30                                                           ;048B38|E230    |      ;
; to reuse code, use a table of how to get to the target grid position
; need the 24-bit ptr since data bank here is 01
    lda.l TABLE_char_grid_row_col_deltas,x
    clc
    adc.b name_entry_grid_curr_position-$101D
  ; LDA.B name_entry_grid_curr_position-$101D                          ;048B3A|A503    |001020;
  ; SEC                                                                ;048B3C|38      |      ; subtract 1 from row pos, subtract 1 from col pos
  ; SBC.B #$11                                                         ;048B3D|E911    |      ;
    STA.B name_entry_grid_target_position-$101D                        ;048B3F|8504    |001021;
    TAX                                                                ;048B41|AA      |      ;
    LDA.L state_values_for_pos_in_name_entry_grid,X                    ;048B42|BF20127F|7F1220;
    STA.B button_type_for_char_grid_curr_pos-$101D                     ;048B46|8500    |00101D;
    REP #$30                                                           ;048B48|C230    |      ;
  ; JSL.L get_index_for_dpad_input_sub_in_char_grid_048CC0             ;048B4F|22C08C04|048CC0;
    JSR.W get_index_for_dpad_input_sub_in_char_grid_048CC0
    JSR.W (JUMP_TABLE_handle_button_for_input_048CD8,X)                ;048B53|FCD88C  |048CD8;
; restore_regs_RTS_048B56:
IntermediateBranchForTeardown:
    bra InputCheckTeardown
  ; REP #$30                                                           ;048B56|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048B5C|60      |      ;

char_grid_check_DOWN_LEFT_048B5D:
    PHP                                                                ;048B5D|08      |      ;
    REP #$30                                                           ;048B5E|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048B63|A505    |001022;
    AND.W #$0F00                                                       ;048B65|29000F  |      ;
    CMP.W #$0600                                                       ;048B68|C90006  |      ;
  ; BNE restore_regs_RTS_048B8B                                        ;048B6B|D01E    |048B8B;
    BNE InputCheckTeardown
    LDA.W #$000A                                                       ;048B7F|A90A00  |      ; <- moved up
  ; STA.B $01                                                          ;048B82|8501    |00101E; <- moved up
  ; SEP #$30                                                           ;048B6D|E230    |      ;
  ; LDA.B name_entry_grid_curr_position-$101D                          ;048B6F|A503    |001020;
  ; CLC                                                                ;048B71|18      |      ; add 1 to row pos, subtract 1 from col pos
  ; ADC.B #$0F                                                         ;048B72|690F    |      ;
    bra AcknowledgeDpadInput
  ; STA.B name_entry_grid_target_position-$101D                        ;048B74|8504    |001021;
  ; TAX                                                                ;048B76|AA      |      ;
  ; LDA.L state_values_for_pos_in_name_entry_grid,X                    ;048B77|BF20127F|7F1220;
  ; STA.B button_type_for_char_grid_curr_pos-$101D                     ;048B7B|8500    |00101D;
  ; REP #$30                                                           ;048B7D|C230    |      ;
;   JSL.L get_index_for_dpad_input_sub_in_char_grid_048CC0             ;048B84|22C08C04|048CC0;
  ; JSR.W get_index_for_dpad_input_sub_in_char_grid_048CC0
  ; JSR.W (JUMP_TABLE_handle_button_for_input_048CD8,X)                ;048B88|FCD88C  |048CD8;
; restore_regs_RTS_048B8B:
  ; REP #$30                                                           ;048B8B|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048B91|60      |      ;

char_grid_check_UP_RIGHT_048B92:
    PHP                                                                ;048B92|08      |      ;
    REP #$30                                                           ;048B93|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048B98|A505    |001022;
    AND.W #$0F00                                                       ;048B9A|29000F  |      ;
    CMP.W #$0900                                                       ;048B9D|C90009  |      ;
  ; BNE restore_regs_RTS_048BC0                                        ;048BA0|D01E    |048BC0;
    BNE InputCheckTeardown
    LDA.W #$000C                                                       ;048BB4|A90C00  |      ; <- moved up
  ; STA.B $01                                                          ;048BB7|8501    |00101E; <- moved up
  ; SEP #$30                                                           ;048BA2|E230    |      ;
  ; LDA.B name_entry_grid_curr_position-$101D                          ;048BA4|A503    |001020;
  ; SEC                                                                ;048BA6|38      |      ; subtract 1 from row pos, add 1 to col pos
  ; SBC.B #$0F                                                         ;048BA7|E90F    |      ;
    bra AcknowledgeDpadInput
  ; STA.B name_entry_grid_target_position-$101D                        ;048BA9|8504    |001021;
  ; TAX                                                                ;048BAB|AA      |      ;
  ; LDA.L state_values_for_pos_in_name_entry_grid,X                    ;048BAC|BF20127F|7F1220;
  ; STA.B button_type_for_char_grid_curr_pos-$101D                     ;048BB0|8500    |00101D;
  ; REP #$30                                                           ;048BB2|C230    |      ;
;   JSL.L get_index_for_dpad_input_sub_in_char_grid_048CC0             ;048BB9|22C08C04|048CC0;
  ; JSR.W get_index_for_dpad_input_sub_in_char_grid_048CC0
  ; JSR.W (JUMP_TABLE_handle_button_for_input_048CD8,X)                ;048BBD|FCD88C  |048CD8;
; restore_regs_RTS_048BC0:
  ; REP #$30                                                           ;048BC0|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048BC6|60      |      ;

char_grid_check_DOWN_RIGHT_048BC7:
    PHP                                                                ;048BC7|08      |      ;
    REP #$30                                                           ;048BC8|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048BCD|A505    |001022;
    AND.W #$0F00                                                       ;048BCF|29000F  |      ;
    CMP.W #$0500                                                       ;048BD2|C90005  |      ;
  ; BNE restore_regs_RTS_048BF5                                        ;048BD5|D01E    |048BF5;
    BNE InputCheckTeardown
    LDA.W #$000E                                                       ;048BE9|A90E00  |      ; <- moved up
  ; STA.B $01                                                          ;048BEC|8501    |00101E; <- moved up
  ; SEP #$30                                                           ;048BD7|E230    |      ;
  ; LDA.B name_entry_grid_curr_position-$101D                          ;048BD9|A503    |001020;
  ; CLC                                                                ;048BDB|18      |      ; add 1 to row pos, add 1 to col pos
  ; ADC.B #$11                                                         ;048BDC|6911    |      ;
    bra AcknowledgeDpadInput
  ; STA.B name_entry_grid_target_position-$101D                        ;048BDE|8504    |001021;
  ; TAX                                                                ;048BE0|AA      |      ;
  ; LDA.L state_values_for_pos_in_name_entry_grid,X                    ;048BE1|BF20127F|7F1220;
  ; STA.B button_type_for_char_grid_curr_pos-$101D                     ;048BE5|8500    |00101D;
  ; REP #$30                                                           ;048BE7|C230    |      ;
;   JSL.L get_index_for_dpad_input_sub_in_char_grid_048CC0             ;048BEE|22C08C04|048CC0;
  ; jsr.w get_index_for_dpad_input_sub_in_char_grid_048CC0
  ; JSR.W (JUMP_TABLE_handle_button_for_input_048CD8,X)                ;048BF2|FCD88C  |048CD8;
; restore_regs_RTS_048BF5:
  ; REP #$30                                                           ;048BF5|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048BFB|60      |      ;

pull_YXAP_rts:
InputCheckTeardown:
    REP #$30
    PLY : PLX : PLA : PLP
    RTS

char_grid_check_A_L_048BFC:
    PHP                                                                ;048BFC|08      |      ;
    REP #$30                                                           ;048BFD|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048C02|A505    |001022;
    LSR #4
    BCS restore_regs_RTS_048C15                                        ;048C08|B00B    |048C15;
    LDA.B char_grid_contr_input_val-$101D                              ;048C0A|A505    |001022;
    AND.W #$00A0                                                       ;048C0C|29A000  |      ;
    BEQ restore_regs_RTS_048C15                                        ;048C0F|F004    |048C15;
  ; JSL.L handle_pressing_A_L_in_char_grid_04928D                      ;048C11|228D9204|04928D;
    jsr.w handle_pressing_A_L_in_char_grid_04928D
restore_regs_RTS_048C15:
    bra InputCheckTeardown
  ; REP #$30                                                           ;048C15|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048C1B|60      |      ;

char_grid_check_START_048C1C:
    PHP                                                                ;048C1C|08      |      ;
    REP #$30                                                           ;048C1D|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048C22|A505    |001022;
    AND.W #$1008                                                       ;048C24|290810  |      ;
    CMP.W #$1000                                                       ;048C27|C90010  |      ;
    BNE restore_regs_RTS_048C42                                        ;048C2A|D016    |048C42;
    SEP #$30                                                           ;048C2C|E230    |      ;
    LDX.B name_entry_grid_curr_position-$101D                          ;048C2E|A603    |001020; check if on the 終り "finish" button
    CPX.B #$9C                                                         ;048C30|E09C    |      ;
    BEQ +                                                              ;048C32|F00A    |048C3E; if yes, then go ahead and do it like normal
    LDA.L state_values_for_pos_in_name_entry_grid,X                    ;048C34|BF20127F|7F1220; otherwise, only do the check if in the main grid, not on a button
    AND.B #$FC                                                         ;048C38|29FC    |      ; value should be either 00, 01, 02, or 03
    BNE restore_regs_RTS_048C42                                        ;048C3A|D006    |048C42;
; this REP is unnecessary; while the JSR does save the P register, it gets
; overwritten right after it returns
  ; REP #$30                                                           ;048C3C|C230    |      ;
; + JSL.L check_if_entered_name_is_valid_0493FF                        ;048C3E|22FF9304|0493FF;
  + jsr.w check_if_entered_name_is_valid_0493FF
restore_regs_RTS_048C42:
    bra InputCheckTeardown
  ; REP #$30                                                           ;048C42|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048C48|60      |      ;

char_grid_check_B_048C49:
    PHP                                                                ;048C49|08      |      ;
    REP #$30                                                           ;048C4A|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048C4F|A505    |001022; why does this get loaded twice?
  ; LDA.B char_grid_contr_input_val-$101D                              ;048C51|A505    |001022;
    AND.W #$8008                                                       ;048C53|290880  |      ;
    CMP.W #$8000                                                       ;048C56|C90080  |      ;
    BNE restore_regs_RTS_048C5F                                        ;048C59|D004    |048C5F;
  ; JSL.L handle_pressing_B_in_char_grid_0495C0                        ;048C5B|22C09504|0495C0;
    jsr.w handle_pressing_B_in_char_grid_0495C0
restore_regs_RTS_048C5F:
    bra InputCheckTeardown
  ; REP #$30                                                           ;048C5F|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048C65|60      |      ;

; in kanji grid, pressing X will scroll the grid UP to the next kana character,
; and pressing Y will scroll the grid DOWN to the next kana character
; I'm not sure if I need either of these for the English patch or not

char_grid_check_X_048C66:
    PHP                                                                ;048C66|08      |      ;
    REP #$30                                                           ;048C67|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048C6C|A505    |001022;
    AND.W #$0040                                                       ;048C6E|294000  |      ;
    BEQ restore_regs_RTS_048C8C                                        ;048C71|F019    |048C8C;
  ; SEP #$30                                                           ;048C73|E230    |      ;
  ; LDA.B $0B                                                          ;048C75|A50B    |001028; ensure that we are in the kanji grid before we do anything
  ; LSR A                                                              ;048C77|4A      |      ; 01 -> hiragana grid specifically for entering the killer's name
  ; BCS restore_regs_RTS_048C8C                                        ;048C78|B012    |048C8C;
  ; LSR A                                                              ;048C7A|4A      |      ; 02 -> either kana grid for entering Tooru/Mari's names
  ; BCS restore_regs_RTS_048C8C                                        ;048C7B|B00F    |048C8C;
  ; LDX.B name_entry_grid_curr_position-$101D                          ;048C7D|A603    |001020; ensure that we are also hovering on part of the character grid
  ; LDA.L state_values_for_pos_in_name_entry_grid,X                    ;048C7F|BF20127F|7F1220;
  ; AND.B #$FC                                                         ;048C83|29FC    |      ;
  ; BNE restore_regs_RTS_048C8C                                        ;048C85|D005    |048C8C;
  ; REP #$30                                                           ;048C87|C230    |      ;
    jsr.w CheckIfGridScrollShouldHappenFor_X_or_Y
    bcs restore_regs_RTS_048C8C
    JSR.W handle_pressing_X_in_char_grid_049067                        ;048C89|206790  |049067;
restore_regs_RTS_048C8C:
    bra InputCheckTeardown
  ; REP #$30                                                           ;048C8C|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048C92|60      |      ;

char_grid_check_Y_048C93:
    PHP                                                                ;048C93|08      |      ;
    REP #$30                                                           ;048C94|C230    |      ;
    PHA : PHX : PHY
    LDA.B char_grid_contr_input_val-$101D                              ;048C99|A505    |001022;
    AND.W #$4000                                                       ;048C9B|290040  |      ;
    BEQ restore_regs_RTS_048CB9                                        ;048C9E|F019    |048CB9;
  ; SEP #$30                                                           ;048CA0|E230    |      ;
  ; LDA.B $0B                                                          ;048CA2|A50B    |001028; reuse the same "should we do this?" logic as for pressing X
  ; LSR A                                                              ;048CA4|4A      |      ;
  ; BCS restore_regs_RTS_048CBC                                        ;048CA5|B0E5    |048C8C;
  ; LSR A                                                              ;048CA7|4A      |      ;
  ; BCS restore_regs_RTS_048CBC                                        ;048CA8|B0E2    |048C8C;
  ; LDX.B name_entry_grid_curr_position-$101D                          ;048CAA|A603    |001020;
  ; LDA.L state_values_for_pos_in_name_entry_grid,X                    ;048CAC|BF20127F|7F1220;
  ; AND.B #$FC                                                         ;048CB0|29FC    |      ;
  ; BNE restore_regs_RTS_048CB9                                        ;048CB2|D005    |048CB9;
  ; REP #$30                                                           ;048CB4|C230    |      ;
    jsr.w CheckIfGridScrollShouldHappenFor_X_or_Y
    bcs restore_regs_RTS_048C8C
    JSR.W handle_pressing_Y_in_char_grid_049094                        ;048CB6|209490  |049094;
restore_regs_RTS_048CB9:
    bra restore_regs_RTS_048C8C
  ; REP #$30                                                           ;048CB9|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048CBF|60      |      ;

; the "should we scroll the grid?" logic is the same for both X and Y, minus the
; "handle pressing __ in char grid" subroutines at the end
CheckIfGridScrollShouldHappenFor_X_or_Y:
    SEP #$30
    LDA.B $0B                                  
    LSR A
    BCS no_grid_scroll_SEC_RTS
    LSR A
    BCS no_grid_scroll_SEC_RTS
    LDX.B name_entry_grid_curr_position-$101D
    LDA.L state_values_for_pos_in_name_entry_grid,X
    AND.B #$FC
    BNE no_grid_scroll_SEC_RTS
    clc
    rts
no_grid_scroll_SEC_RTS:
    sec
    rts

get_index_for_dpad_input_sub_in_char_grid_048CC0:
    PHP : PHY : PHA
    LDX.B $01                                                          ;048CC3|A601    |00101E; $01 encodes which direction
    LDA.W PTR_TABLE_for_indices_to_use_in_char_grid_0189B3,X           ;048CC5|BDB389  |0189B3;
    STA.B $01                                                          ;048CC8|8501    |00101E;
    SEP #$30                                                           ;048CCA|E230    |      ;
    LDY.B button_type_for_char_grid_curr_pos-$101D                     ;048CCC|A400    |00101D; $00 encodes what state we are in
    LDA.B ($01),Y                                                      ;048CCE|B101    |00101E; get index for how to handle combination of direction and state
    ASL A                                                              ;048CD0|0A      |      ;
    TAX                                                                ;048CD1|AA      |      ;
    REP #$30                                                           ;048CD2|C230    |      ;
    PLA : PLY : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048CD7|6B      |      ;
    RTS

JUMP_TABLE_handle_button_for_input_048CD8:
    dw char_grid_dpad_sub_00_048D1E, char_grid_dpad_sub_01_048D1F
    dw char_grid_dpad_sub_02_048D84, char_grid_dpad_sub_03_048DA9
    dw char_grid_dpad_sub_04_048E0C, char_grid_dpad_sub_05_048E30
    dw char_grid_dpad_sub_06_048DCE, char_grid_dpad_sub_07_048DED
    dw char_grid_dpad_sub_08_048D40, char_grid_dpad_sub_09_048E54
    dw char_grid_dpad_sub_0a_048F9E, char_grid_dpad_sub_0b_048FCC
    dw char_grid_dpad_sub_0c_048FFA, char_grid_dpad_sub_0d_049028
; bypass going to the kanji box with going to the hiragana box
  ; dw char_grid_dpad_sub_0e_048E79, char_grid_dpad_sub_0f_048EDE
    dw char_grid_dpad_sub_0f_048EDE, char_grid_dpad_sub_0f_048EDE
    dw char_grid_dpad_sub_10_048F3E, char_grid_dpad_sub_11_048D61

set_button_sprites_off_screen_flash_squares_on_screen_048CFC:
    PHP                                                                ;048CFC|08      |      ;
    REP #$30                                                           ;048CFD|C230    |      ;
    PHA : PHX : PHY
  ; LDA.W #$5555                                                       ;048D02|A95555  |      ; sprites 0x68-0x6F
  ; STA.L $7F1892                                                      ;048D05|8F92187F|7F1892;
    jsr.w TurnOffHighlightsForPlaceholderClearFinishButtons
  ; LDA.W #$5555                                                       ;048D09|A95555  |      ; sprites 0x70-0x77
  ; STA.L $7F1894                                                      ;048D0C|8F94187F|7F1894;
    jsr.w TurnOffHighlightsForABCD_AccentButtons
  ; LDA.W #$0555                                                       ;048D10|A95505  |      ; sprites 0x78-0x7D, and 0x7E-0x7F on
  ; STA.L $7F1896                                                      ;048D13|8F96187F|7F1896;
    jsr.w TurnOnBothNameHighlightBoxAndCharGridHighlightBox
    REP #$30                                                           ;048D17|C230    |      ;
    PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;048D1D|6B      |      ;

char_grid_dpad_sub_00_048D1E:
    RTS                                                                ;048D1E|60      |      ; RTS if attempted to move off top/bottom of kana grid

char_grid_dpad_sub_01_048D1F:
    PHP                                                                ;048D1F|08      |      ; moved into any of the middle 8 columns of character grid
    REP #$30                                                           ;048D20|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048D25|E220    |      ;
    LDA.B name_entry_grid_target_position-$101D                        ;048D27|A504    |001021;
    STA.B name_entry_grid_curr_position-$101D                          ;048D29|8503    |001020;
  ; JSL.L get_sprite_pos_for_char_grid_pos_highlight_box_049250        ;048D2B|22509204|049250;
    JSR.W get_sprite_pos_for_char_grid_pos_highlight_box_049250
    LDA.B #$80                                                         ;048D2F|A980    |      ; indicate to do DMA subs at $048A3D
    TSB.B $0B                                                          ;048D31|040B    |001028;
    REP #$20                                                           ;048D33|C220    |      ;
    bra ++
;   JSL.L set_button_sprites_off_screen_flash_squares_on_screen_048CFC ;048D35|22FC8C04|048CFC;
  ; JSR.W set_button_sprites_off_screen_flash_squares_on_screen_048CFC
  ; REP #$30                                                           ;048D39|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048D3F|60      |      ;

char_grid_dpad_sub_08_048D40:
    PHP                                                                ;048D40|08      |      ; moved left (plus possibly up/down) into rightmost char column
    REP #$30                                                           ;048D41|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048D46|E220    |      ;
    LDA.B name_entry_grid_target_position-$101D                        ;048D48|A504    |001021;
    bra +
  ; STA.B name_entry_grid_curr_position-$101D                          ;048D4A|8503    |001020;
  ; LDA.B #$80                                                         ;048D4C|A980    |      ; indicate to do DMA subs at $048A3D
  ; TSB.B $0B                                                          ;048D4E|040B    |001028;
  ; REP #$20                                                           ;048D50|C220    |      ;
;   JSL.L get_sprite_pos_for_char_grid_pos_highlight_box_049250        ;048D52|22509204|049250;
  ; JSR.W get_sprite_pos_for_char_grid_pos_highlight_box_049250
;   JSL.L set_button_sprites_off_screen_flash_squares_on_screen_048CFC ;048D56|22FC8C04|048CFC;
  ; JSR.W set_button_sprites_off_screen_flash_squares_on_screen_048CFC
  ; REP #$30                                                           ;048D5A|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048D60|60      |      ;

char_grid_dpad_sub_11_048D61:
    PHP                                                                ;048D61|08      |      ; move right (plus possibly up/down) into leftmost char column
    REP #$30                                                           ;048D62|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048D67|E220    |      ;
    LDA.L MEM_LIST_char_grid_highlight_positions                       ;048D69|AF20147F|7F1420;
  + STA.B name_entry_grid_curr_position-$101D                          ;048D6D|8503    |001020;
    LDA.B #$80                                                         ;048D6F|A980    |      ; indicate to do DMA subs at $048A3D
    TSB.B $0B                                                          ;048D71|040B    |001028;
    REP #$20                                                           ;048D73|C220    |      ;
  ; JSL.L get_sprite_pos_for_char_grid_pos_highlight_box_049250        ;048D75|22509204|049250;
    JSR.W get_sprite_pos_for_char_grid_pos_highlight_box_049250
  ; JSL.L set_button_sprites_off_screen_flash_squares_on_screen_048CFC ;048D79|22FC8C04|048CFC;
 ++ JSR.W set_button_sprites_off_screen_flash_squares_on_screen_048CFC
  ; REP #$30                                                           ;048D7D|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048D83|60      |      ;
    jmp.w pull_YXAP_rts

char_grid_dpad_sub_02_048D84:
    PHP                                                                ;048D84|08      |      ; pressed up at top of on-screen kanji grid
    REP #$30                                                           ;048D85|C230    |      ;
    PHA : PHX : PHY
  ; LDA.B $09                                                          ;048D8A|A509    |001026; take a pointer and subtract 20 bytes = shift up a row of 10 characters
  ; SEC                                                                ;048D8C|38      |      ;
  ; SBC.W #$0014                                                       ;048D8D|E91400  |      ;
    lda.w #-$0014
    bra +
;   JSL.L check_which_char_grid_and_read_char_data_0487F8              ;048D90|22F88704|0487F8; check if need to wrap around?
  ; JSR.W check_which_char_grid_and_read_char_data_0487F8
  ; STA.B $09                                                          ;048D94|8509    |001026;
  ; SEP #$20                                                           ;048D96|E220    |      ;
  ; LDA.B #$80                                                         ;048D98|A980    |      ; indicate to do DMA subs at $048A3D
  ; TSB.B $0B                                                          ;048D9A|040B    |001028;
  ; REP #$20                                                           ;048D9C|C220    |      ;
  ; JSL.L draw_gray_boxes_behind_hiragana_on_kanji_screen_049189       ;048D9E|22899104|049189;
  ; JSR.W draw_gray_boxes_behind_hiragana_on_kanji_screen_049189
  ; REP #$30                                                           ;048DA2|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048DA8|60      |      ;

char_grid_dpad_sub_03_048DA9:
    PHP                                                                ;048DA9|08      |      ; pressed down at bottom of on-screen kanji grid
    REP #$30                                                           ;048DAA|C230    |      ;
    PHA : PHX : PHY
  ; LDA.B $09                                                          ;048DAF|A509    |001026; similar, take pointer and ADD 20 bytes = go down one row
  ; CLC                                                                ;048DB1|18      |      ;
  ; ADC.W #$0014                                                       ;048DB2|691400  |      ;
    lda #$0014
  + clc
    adc $09
  ; JSL.L check_which_char_grid_and_read_char_data_0487F8              ;048DB5|22F88704|0487F8;
    JSR.W check_which_char_grid_and_read_char_data_0487F8
    STA.B $09                                                          ;048DB9|8509    |001026;
    SEP #$20                                                           ;048DBB|E220    |      ;
    LDA.B #$80                                                         ;048DBD|A980    |      ; indicate to do DMA subs at $048A3D
    TSB.B $0B                                                          ;048DBF|040B    |001028;

    ; cut out, don't need
  ; REP #$20                                                           ;048DC1|C220    |      ;
;   JSL.L draw_gray_boxes_behind_hiragana_on_kanji_screen_049189       ;048DC3|22899104|049189;
  ; JSR.W draw_gray_boxes_behind_hiragana_on_kanji_screen_049189

  ; REP #$30                                                           ;048DC7|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048DCD|60      |      ;
    jmp.w pull_YXAP_rts

char_grid_dpad_sub_06_048DCE:
    PHP                                                                ;048DCE|08      |      ; pressed left + (up/down) at top of grid (either kana or kanji)
    REP #$30                                                           ;048DCF|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048DD4|E220    |      ;
    DEC.B name_entry_grid_curr_position-$101D                          ;048DD6|C603    |001020; go left one character
    bra +
;   JSL.L get_sprite_pos_for_char_grid_pos_highlight_box_049250        ;048DD8|22509204|049250;
  ; JSR.W get_sprite_pos_for_char_grid_pos_highlight_box_049250
  ; LDA.B #$80                                                         ;048DDC|A980    |      ; indicate to do DMA subs at $048A3D
  ; TSB.B $0B                                                          ;048DDE|040B    |001028;
  ; REP #$20                                                           ;048DE0|C220    |      ;
;   JSL.L set_button_sprites_off_screen_flash_squares_on_screen_048CFC ;048DE2|22FC8C04|048CFC;
  ; JSR.W set_button_sprites_off_screen_flash_squares_on_screen_048CFC
  ; REP #$30                                                           ;048DE6|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048DEC|60      |      ;

char_grid_dpad_sub_07_048DED:
    PHP                                                                ;048DED|08      |      ; pressed right + (up/down) at top of grid (either kana or kanji)
    REP #$30                                                           ;048DEE|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048DF3|E220    |      ;
    INC.B name_entry_grid_curr_position-$101D                          ;048DF5|E603    |001020; go right one character
  ; JSL.L get_sprite_pos_for_char_grid_pos_highlight_box_049250        ;048DF7|22509204|049250;
- + JSR.W get_sprite_pos_for_char_grid_pos_highlight_box_049250
    LDA.B #$80                                                         ;048DFB|A980    |      ; indicate to do DMA subs at $048A3D
    TSB.B $0B                                                          ;048DFD|040B    |001028;
    REP #$20                                                           ;048DFF|C220    |      ;
  ; JSL.L set_button_sprites_off_screen_flash_squares_on_screen_048CFC ;048E01|22FC8C04|048CFC;
    JSR.W set_button_sprites_off_screen_flash_squares_on_screen_048CFC
  ; REP #$30                                                           ;048E05|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048E0B|60      |      ;
    jmp.w pull_YXAP_rts

char_grid_dpad_sub_04_048E0C:
    PHP                                                                ;048E0C|08      |      ; only appears in killer grid when pressing up + (left/right)
    REP #$30                                                           ;048E0D|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048E12|E220    |      ;
  ; LDA.B name_entry_grid_curr_position-$101D                          ;048E14|A503    |001020; go up one row in grid
  ; SEC                                                                ;048E16|38      |      ;
  ; SBC.B #$10                                                         ;048E17|E910    |      ;
    lda.b #-$10
    bra +
  ; STA.B name_entry_grid_curr_position-$101D                          ;048E19|8503    |001020;
;   JSL.L get_sprite_pos_for_char_grid_pos_highlight_box_049250        ;048E1B|22509204|049250;
  ; JSR.W get_sprite_pos_for_char_grid_pos_highlight_box_049250
  ; LDA.B #$80                                                         ;048E1F|A980    |      ; indicate to do DMA subs at $048A3D
  ; TSB.B $0B                                                          ;048E21|040B    |001028;
  ; REP #$20                                                           ;048E23|C220    |      ;
  ; JSL.L set_button_sprites_off_screen_flash_squares_on_screen_048CFC ;048E25|22FC8C04|048CFC;
  ; JSR.W set_button_sprites_off_screen_flash_squares_on_screen_048CFC
  ; REP #$30                                                           ;048E29|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048E2F|60      |      ;

char_grid_dpad_sub_05_048E30:
    PHP                                                                ;048E30|08      |      ; only appears in killer grid when pressing down + (left/right)
    REP #$30                                                           ;048E31|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048E36|E220    |      ;
  ; LDA.B name_entry_grid_curr_position-$101D                          ;048E38|A503    |001020; go down one row in grid
  ; CLC                                                                ;048E3A|18      |      ;
  ; ADC.B #$10                                                         ;048E3B|6910    |      ;
    lda.b #$10
  + clc
    adc.b name_entry_grid_curr_position-$101D
    STA.B name_entry_grid_curr_position-$101D                          ;048E3D|8503    |001020;
    bra -
  ; JSL.L get_sprite_pos_for_char_grid_pos_highlight_box_049250        ;048E3F|22509204|049250;
  ; JSR.W get_sprite_pos_for_char_grid_pos_highlight_box_049250
  ; LDA.B #$80                                                         ;048E43|A980    |      ; indicate to do DMA subs at $048A3D
  ; TSB.B $0B                                                          ;048E45|040B    |001028;
  ; REP #$20                                                           ;048E47|C220    |      ;
  ; JSL.L set_button_sprites_off_screen_flash_squares_on_screen_048CFC ;048E49|22FC8C04|048CFC;
  ; JSR.W set_button_sprites_off_screen_flash_squares_on_screen_048CFC
  ; REP #$30                                                           ;048E4D|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048E53|60      |      ;
  ; jmp.w pull_YXAP_rts

char_grid_dpad_sub_09_048E54:
    PHP                                                                ;048E54|08      |      ; press left (plus up/down) to go to box column on left of screen
    REP #$30                                                           ;048E55|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048E5A|E220    |      ;
    LDA.B name_entry_grid_curr_position-$101D                          ;048E5C|A503    |001020;
    STA.L MEM_LIST_char_grid_highlight_positions                       ;048E5E|8F20147F|7F1420;
    REP #$20                                                           ;048E62|C220    |      ;
    LDA.L char_grid_type_0_kanji_2_hira_4_kata                         ;048E64|AF21147F|7F1421; this gets set depending on which page you are currently on
    TAX                                                                ;048E68|AA      |      ;
    JSR.W (JUMP_TABLE_go_to_box_for_current_page_048E73,X)             ;048E69|FC738E  |048E73; go to the button for the appropriate page
  ; REP #$30                                                           ;048E6C|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048E72|60      |      ;
    jmp.w pull_YXAP_rts

JUMP_TABLE_go_to_box_for_current_page_048E73:
; if going to the kanji box (still happens upon entering screen to name Tooru),
; bypass the code for going to the kanji box with going to the hiragana box
  ; dw char_grid_dpad_sub_0e_048E79                                    ;048E73|        |048E79; go to kanji box
    dw char_grid_dpad_sub_0f_048EDE                                    ;048E75|        |048EDE; go to hiragana box
    dw char_grid_dpad_sub_0f_048EDE                                    ;048E75|        |048EDE; go to hiragana box
    dw char_grid_dpad_sub_10_048F3E                                    ;048E77|        |048F3E; go to katakana box

char_grid_dpad_sub_0e_048E79:
    PHP                                                                ;048E79|08      |      ; move to the kanji box
    REP #$30                                                           ;048E7A|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048E7F|E220    |      ;
    LDA.B #$11                                                         ;048E81|A911    |      ;
    STA.B name_entry_grid_curr_position-$101D                          ;048E83|8503    |001020;
    LDA.B #$80                                                         ;048E85|A980    |      ; indicate to do DMA subs at $048A3D
    TSB.B $0B                                                          ;048E87|040B    |001028;
    LDA.B #$02                                                         ;048E89|A902    |      ; set flag that grid is scrollable
    TRB.B $0B                                                          ;048E8B|140B    |001028;
    REP #$20                                                           ;048E8D|C220    |      ;
    LDA.W #$0000                                                       ;048E8F|A90000  |      ; 0 for kanji
    STA.L char_grid_type_0_kanji_2_hira_4_kata                         ;048E92|8F21147F|7F1421;
    LDA.W #$5505                                                       ;048E96|A90555  |      ; turn on sprites 6A and 6B = kanji box highlight
    STA.L $7F1892                                                      ;048E99|8F92187F|7F1892;
  ; LDA.W #$5555                                                       ;048E9D|A95555  |      ;
  ; STA.L $7F1894                                                      ;048EA0|8F94187F|7F1894;
    jsr.w TurnOffHighlightsForABCD_AccentButtons
  ; LDA.W #$4555                                                       ;048EA4|A95545  |      ; turn on sprite 7E = highlight box for entered name
  ; STA.L $7F1896                                                      ;048EA7|8F96187F|7F1896;
    jsr.w TurnOnNameHighlightBox
    LDA.B $09                                                          ;048EAB|A509    |001026; read appropriate block of kanji chars
  ; JSL.L check_which_char_grid_and_read_char_data_0487F8              ;048EAD|22F88704|0487F8;
    JSR.W check_which_char_grid_and_read_char_data_0487F8
    STA.B $09                                                          ;048EB1|8509    |001026;

    ; cut out, don't need
  ; JSL.L draw_gray_boxes_behind_hiragana_on_kanji_screen_049189       ;048EB3|22899104|049189;
  ; JSR.W draw_gray_boxes_behind_hiragana_on_kanji_screen_049189

    LDX.W #$0002                                                       ;048EB7|A20200  |      ; left border with buttons
  ; JSL.L fill_in_char_grid_state_buffer_from_list_X_048427            ;048EBA|22278404|048427;
    JSR.W fill_in_char_grid_state_buffer_from_list_X_048427            ;048EBA|22278404|048427;

; JP game would draw up/down arrows at top/bottom of grid window; don't need this
;   JSL.L use_list_X_at_018931_to_write_tile_IDs_048766                ;048EBE|22668704|048766; draw up/down arrows at top/bottom of char grid window
  ; jsr.w use_list_X_at_018931_to_write_tile_IDs_048766

  ; LDX.W #$0008                                                       ;048EC2|A20800  |      ; kanji box (gray)
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048EC5|22608604|048660;
  ; LDX.W #$0001                                                       ;048EC9|A20100  |      ; hiragana box (black)
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048ECC|22608604|048660;
  ; LDX.W #$0002                                                       ;048ED0|A20200  |      ; katakana box (black)
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048ED3|22608604|048660;
    ldx.w #!TwoColumnABCD_BlackBox
    jsr.w WriteTwoConsecutiveSetsOfTwoTileColumns
  ; REP #$30                                                           ;048ED7|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048EDD|60      |      ;
    jmp.w pull_YXAP_rts

char_grid_dpad_sub_0f_048EDE:
    PHP                                                                ;048EDE|08      |      ; go to hiragana box
    REP #$30                                                           ;048EDF|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048EE4|E220    |      ;
    LDA.B #$31                                                         ;048EE6|A931    |      ;
    STA.B name_entry_grid_curr_position-$101D                          ;048EE8|8503    |001020;
    LDA.B #$82                                                         ;048EEA|A982    |      ; indicate to do DMA subs at $048A3D, grid is NOT scrollable
    TSB.B $0B                                                          ;048EEC|040B    |001028;
    REP #$20                                                           ;048EEE|C220    |      ;
    LDA.W #$0002                                                       ;048EF0|A90200  |      ; 2 for hiragana
    STA.L char_grid_type_0_kanji_2_hira_4_kata                         ;048EF3|8F21147F|7F1421;
  ; LDA.W #$4555                                                       ;048EF7|A95545  |      ; turn on sprite 7E = entered name highlight box
  ; STA.L $7F1896                                                      ;048EFA|8F96187F|7F1896;
    jsr.w TurnOnNameHighlightBox
  ; LDA.W #$0055                                                       ;048EFE|A95500  |      ; turn on sprites 74-77 = hiragana box
; turn on sprites 74-76 = alphabet box
    lda.w #$4055
    STA.L $7F1894                                                      ;048F01|8F94187F|7F1894;
  ; LDA.W #$5555                                                       ;048F05|A95555  |      ; turn off kanji box, katakana box
  ; STA.L $7F1892                                                      ;048F08|8F92187F|7F1892;
    jsr.w TurnOffHighlightsForPlaceholderClearFinishButtons
  ; LDA.W #$B13B                                                       ;048F0C|A93BB1  |      ; hiragana table
    LDA.W #Page1NameEntryCharData
  ; JSL.L check_which_char_grid_and_read_char_data_0487F8              ;048F0F|22F88704|0487F8;
    JSR.W check_which_char_grid_and_read_char_data_0487F8
    LDX.W #$0004                                                       ;048F13|A20400  |      ;
  ; JSL.L fill_in_char_grid_state_buffer_from_list_X_048427            ;048F16|22278404|048427; top/bottom borders for kana grid (interactive portion)
    JSR.W fill_in_char_grid_state_buffer_from_list_X_048427            ;048EBA|22278404|048427;
  ; JSL.L use_list_X_at_018931_to_write_tile_IDs_048766                ;048F1A|22668704|048766; replace up/down arrows with regular border if needed
    JSR.W use_list_X_at_018931_to_write_tile_IDs_048766
  ; LDX.W #$0000                                                       ;048F1E|A20000  |      ; kanji box (black)
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048F21|22608604|048660;
  ; LDX.W #$0002                                                       ;048F25|A20200  |      ; katakana box (black)
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048F28|22608604|048660;
  ; LDX.W #$0009                                                       ;048F2C|A20900  |      ; hiragana box (gray)
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048F2F|22608604|048660;
    ldx.w #!TwoColumnAccentsBlackBox
    jsr.w WriteTwoConsecutiveSetsOfTwoTileColumns

    ; cut out, don't need
  ; JSL.L clear_gray_boxes_below_kana_markers_for_kanji_grid_049161    ;048F33|22619104|049161;
  ; jsr.w clear_gray_boxes_below_kana_markers_for_kanji_grid_049161

  ; REP #$30                                                           ;048F37|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048F3D|60      |      ;
    jmp.w pull_YXAP_rts

char_grid_dpad_sub_10_048F3E:
    PHP                                                                ;048F3E|08      |      ; go to katakana box
    REP #$30                                                           ;048F3F|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048F44|E220    |      ;
    LDA.B #$61                                                         ;048F46|A961    |      ;
    STA.B name_entry_grid_curr_position-$101D                          ;048F48|8503    |001020;
    LDA.B #$82                                                         ;048F4A|A982    |      ; indicate to do DMA subs at $048A3D, grid is NOT scrollable
    TSB.B $0B                                                          ;048F4C|040B    |001028;
    REP #$20                                                           ;048F4E|C220    |      ;
    LDA.W #$0004                                                       ;048F50|A90400  |      ; 4 for katakana
    STA.L char_grid_type_0_kanji_2_hira_4_kata                         ;048F53|8F21147F|7F1421;
  ; LDA.W #$4555                                                       ;048F57|A95545  |      ; turn on sprite 7E = box in name window
  ; STA.L $7F1896                                                      ;048F5A|8F96187F|7F1896;
    jsr.w TurnOnNameHighlightBox
  ; LDA.W #$5500                                                       ;048F5E|A90055  |      ; turn on sprites 70-73 = katakana
; turn on sprites 70-72 = accent box
    LDA.W #$5540
    STA.L $7F1894                                                      ;048F61|8F94187F|7F1894;
  ; LDA.W #$5555                                                       ;048F65|A95555  |      ; turn off sprites 74-77 = hiragana
  ; STA.L $7F1892                                                      ;048F68|8F92187F|7F1892;
    jsr.w TurnOffHighlightsForPlaceholderClearFinishButtons
  ; LDA.W #$B1EF                                                       ;048F6C|A9EFB1  |      ; katakana grid
    LDA.W #Page1NameEntryCharData+!BytesPerCharScreen
  ; JSL.L check_which_char_grid_and_read_char_data_0487F8              ;048F6F|22F88704|0487F8;
    JSR.W check_which_char_grid_and_read_char_data_0487F8
    LDX.W #$0004                                                       ;048F73|A20400  |      ;
  ; JSL.L fill_in_char_grid_state_buffer_from_list_X_048427            ;048F76|22278404|048427; top/bottom borders for kana grid (interactive portion)
    JSR.W fill_in_char_grid_state_buffer_from_list_X_048427            ;048EBA|22278404|048427;
  ; JSL.L use_list_X_at_018931_to_write_tile_IDs_048766                ;048F7A|22668704|048766; replace up/down arrows with regular border if needed
    JSR.W use_list_X_at_018931_to_write_tile_IDs_048766
  ; LDX.W #$0000                                                       ;048F7E|A20000  |      ; kanji box (black)
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048F81|22608604|048660;
  ; LDX.W #$0001                                                       ;048F85|A20100  |      ; hiragana box (black)
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048F88|22608604|048660;
  ; LDX.W #$000A                                                       ;048F8C|A20A00  |      ; katakana box (gray)
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;048F8F|22608604|048660;
    ldx.w #!TwoColumnAccentsGrayBox
    jsr.w WriteTwoConsecutiveSetsOfTwoTileColumns

    ; cut out, don't need
  ; JSL.L clear_gray_boxes_below_kana_markers_for_kanji_grid_049161    ;048F93|22619104|049161;
  ; jsr.w clear_gray_boxes_below_kana_markers_for_kanji_grid_049161

  ; REP #$30                                                           ;048F97|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048F9D|60      |      ;
    jmp.w pull_YXAP_rts

char_grid_dpad_sub_0a_048F9E:
    PHP                                                                ;048F9E|08      |      ; go onto space box
    REP #$30                                                           ;048F9F|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048FA4|E220    |      ;
    LDA.B #$1C                                                         ;048FA6|A91C    |      ;
    STA.B name_entry_grid_curr_position-$101D                          ;048FA8|8503    |001020;
    LDA.B #$80                                                         ;048FAA|A980    |      ; indicate to do DMA subs at $048A3D
    TSB.B $0B                                                          ;048FAC|040B    |001028;
    REP #$20                                                           ;048FAE|C220    |      ;

; in JP game, turn on sprites 78-7B (space) and 7E (box in name window)
; turn off hiragana/katakana, turn off kanji/clear/finish
  ; LDA.W #$4540                                                       ;048FB0|A94045  |      ;
  ; STA.L $7F1896                                                      ;048FB3|8F96187F|7F1896;
  ; LDA.W #$5555                                                       ;048FB7|A95555  |      ;
  ; STA.L $7F1894                                                      ;048FBA|8F94187F|7F1894;
  ; LDA.W #$5555                                                       ;048FBE|A95555  |      ;
  ; STA.L $7F1892                                                      ;048FC1|8F92187F|7F1892;

; in patch, turn on name box (7E) and space (78-7A)
    lda.w #$5555&(~$1000)&(~$0015)
    sta.l $7F1896
; turn off accents+alphabet (70-73, 74-77)
  ; lda.w #$5555
  ; sta.l $7F1894
    jsr.w TurnOffHighlightsForABCD_AccentButtons
; turn off delete/finish (6C-6D, 6E-6F), turn off placeholder sprites (6A-6B)
  ; lda.w #$5555
  ; sta.l $7F1892
    jsr.w TurnOffHighlightsForPlaceholderClearFinishButtons

    bra +
  ; REP #$30                                                           ;048FC5|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048FCB|60      |      ;

char_grid_dpad_sub_0b_048FCC:
    PHP                                                                ;048FCC|08      |      ; go onto delete box
    REP #$30                                                           ;048FCD|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;048FD2|E220    |      ;
    LDA.B #$4C                                                         ;048FD4|A94C    |      ;
    STA.B name_entry_grid_curr_position-$101D                          ;048FD6|8503    |001020;
    LDA.B #$80                                                         ;048FD8|A980    |      ; indicate to do DMA subs at $048A3D
    TSB.B $0B                                                          ;048FDA|040B    |001028;
    REP #$20                                                           ;048FDC|C220    |      ;

; in JP game, turn on sprites 7B-7D (delete) and 7E (box in name window)
; turn off hiragana/katakana, turn off kanji/clear/finish
  ; LDA.W #$4015                                                       ;048FDE|A91540  |      ;
  ; STA.L $7F1896                                                      ;048FE1|8F96187F|7F1896;
  ; LDA.W #$5555                                                       ;048FE5|A95555  |      ;
  ; STA.L $7F1894                                                      ;048FE8|8F94187F|7F1894;
  ; LDA.W #$5555                                                       ;048FEC|A95555  |      ;
  ; STA.L $7F1892                                                      ;048FEF|8F92187F|7F1892;

; in patch, turn off space (78-7A) and clear (7B-7D), turn on name highlight box (7E)
  ; lda.w #$5555&(~$1000)
  ; sta.l $7f1896
    jsr.w TurnOnNameHighlightBox
; turn off accents (70-73) and alphabet (74-77)
  ; lda.w #$5555
  ; sta.l $7f1894
    jsr.w TurnOffHighlightsForABCD_AccentButtons
; turn on sprites 6C-6D (delete), turn off finish (6E-6F) and placeholder (6A-6B)
    lda.w #$5555&(~$0500)
    sta.l $7f1892

  ; REP #$30                                                           ;048FF3|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;048FF9|60      |      ;
  + jmp.w pull_YXAP_rts

char_grid_dpad_sub_0c_048FFA:
    PHP                                                                ;048FFA|08      |      ; go onto clear box
    REP #$30                                                           ;048FFB|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;049000|E220    |      ;
; change grid position to set to if needed; I have to because I made
; Delete shorter and Clear taller
  ; LDA.B #$7C                                                         ;049002|A97C    |      ;
    lda.b #$6C                                                         ;049002|A97C    |      ;
    STA.B name_entry_grid_curr_position-$101D                          ;049004|8503    |001020;
    LDA.B #$80                                                         ;049006|A980    |      ; indicate to do DMA subs at $048A3D
    TSB.B $0B                                                          ;049008|040B    |001028;
    REP #$20                                                           ;04900A|C220    |      ;

; in JP game, turn on name highlight box, turn on clear box
  ; LDA.W #$4555                                                       ;04900C|A95545  |      ; turn on sprite 7E = box in name window
  ; STA.L $7F1896                                                      ;04900F|8F96187F|7F1896;
  ; LDA.W #$5555                                                       ;049013|A95555  |      ;
  ; STA.L $7F1894                                                      ;049016|8F94187F|7F1894;
  ; LDA.W #$5055                                                       ;04901A|A95550  |      ; turn on sprites 6C-6D = clear
  ; STA.L $7F1892                                                      ;04901D|8F92187F|7F1892;

; in patch, turn on clear box (7B-7D) and name highlight box (7E)
    lda.w #$5555&(~$0540)&(~$1000)
    sta.l $7f1896
; turn off accents (70-73) and alphabet (74-77)
  ; lda.w #$5555
  ; sta.l $7f1894
    jsr.w TurnOffHighlightsForABCD_AccentButtons
; turn off placeholders (6A-6B), delete (6C-6D), finish (6E-6F)
  ; lda.w #$5555
  ; sta.l $7f1892
    jsr.w TurnOffHighlightsForPlaceholderClearFinishButtons

  ; REP #$30                                                           ;049021|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;049027|60      |      ;
    jmp.w pull_YXAP_rts

char_grid_dpad_sub_0d_049028:
; this jump table entry is just a JSR wrapper to code that's accessed with a JSL
; but the underlying code is only ever accessed in the current bank, so we can
; just have the pointer in the jump table go directly to the main code itself,
; since the "save processor state on stack" setup code is the same
  ; PHP                                                                ;049028|08      |      ; go onto finish box - underlying code accessed with JSL, so must wrap in JSR
  ; REP #$30                                                           ;049029|C230    |      ;
  ; PHA                                                                ;04902B|48      |      ;
  ; PHX                                                                ;04902C|DA      |      ;
  ; PHY                                                                ;04902D|5A      |      ;
  ; JSL.L handle_moving_to_finish_box_049039                           ;04902E|22399004|049039;
  ; REP #$30                                                           ;049032|C230    |      ;
  ; PLY                                                                ;049034|7A      |      ;
  ; PLX                                                                ;049035|FA      |      ;
  ; PLA                                                                ;049036|68      |      ;
  ; PLP                                                                ;049037|28      |      ;
  ; RTS                                                                ;049038|60      |      ;

handle_moving_to_finish_box_049039:
    PHP                                                                ;049039|08      |      ;
    REP #$30                                                           ;04903A|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;04903F|E220    |      ;
    LDA.B #$9C                                                         ;049041|A99C    |      ;
    STA.B name_entry_grid_curr_position-$101D                          ;049043|8503    |001020;
    LDA.B #$80                                                         ;049045|A980    |      ; indicate to do DMA subs at $048A3D
    TSB.B $0B                                                          ;049047|040B    |001028;
    REP #$20                                                           ;049049|C220    |      ;
; in JP game, turn on the name box (7E) and finish (6E-6F)
  ; LDA.W #$4555                                                       ;04904B|A95545  |      ; turn on sprite 7E = box in name window
  ; STA.L $7F1896                                                      ;04904E|8F96187F|7F1896;
  ; LDA.W #$5555                                                       ;049052|A95555  |      ;
  ; STA.L $7F1894                                                      ;049055|8F94187F|7F1894;
  ; LDA.W #$0555                                                       ;049059|A95505  |      ; turn on sprites 6E-6F = finish
  ; STA.L $7F1892                                                      ;04905C|8F92187F|7F1892;

; in patch, turn on name box (7E), turn off space (78-7A) and clear (7B-7D)
  ; lda.w #$5555&(~$1000)
  ; sta.l $7F1896
    jsr.w TurnOnNameHighlightBox
; turn off accents (70-73) and alphabet (74-77)
  ; lda.w #$5555
  ; sta.l $7F1894
    jsr.w TurnOffHighlightsForABCD_AccentButtons
; turn on finish (6E-6F), turn off placeholder (6A-6B) and delete (6C-6D)
    lda.w #$5555&(~$5000)
    sta.l $7F1892

  ; REP #$30                                                           ;049060|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;049066|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

handle_pressing_X_in_char_grid_049067:
    PHP                                                                ;049067|08      |      ;
    REP #$30                                                           ;049068|C230    |      ;
    PHA : PHX : PHY
    LDA.L size_of_kanji_row_ptr_table                                  ;04906D|AFA2207F|7F20A2; start at the end and keep going up until you reach the current row
    TAX                                                                ;049071|AA      |      ;
  - DEX #2                                                             ;049072|CA      |      ;
    LDA.W ptr_to_kanji_row_data_due_to_loop_counter_01B0D1,X           ;049074|BDD1B0  |01B0D1; get pointer to row of kanji character data
    CMP.B $09                                                          ;049077|C509    |001026;
    BPL -                                                              ;049079|10F7    |049072;
    bra got_next_target_0490B9
;   JSL.L check_which_char_grid_and_read_char_data_0487F8              ;04907B|22F88704|0487F8;
  ; JSR.W check_which_char_grid_and_read_char_data_0487F8
  ; STA.B $09                                                          ;04907F|8509    |001026;
  ; SEP #$20                                                           ;049081|E220    |      ;
  ; LDA.B #$80                                                         ;049083|A980    |      ;
  ; TSB.B $0B                                                          ;049085|040B    |001028;
  ; REP #$20                                                           ;049087|C220    |      ;

    ; cut out, don't need
;   JSL.L draw_gray_boxes_behind_hiragana_on_kanji_screen_049189       ;049089|22899104|049189;
  ; JSR.W draw_gray_boxes_behind_hiragana_on_kanji_screen_049189

  ; REP #$30                                                           ;04908D|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;049093|60      |      ;

handle_pressing_Y_in_char_grid_049094:
    PHP                                                                ;049094|08      |      ;
    REP #$30                                                           ;049095|C230    |      ;
    PHA : PHX : PHY
    LDX.W #$0000                                                       ;04909A|A20000  |      ; start at the beginning and keep going down
LOOP_check_next_kanji_row_04909D:
    INX #2                                                             ;04909D|E8      |      ;
    LDA.W ptr_to_kanji_row_data_due_to_loop_counter_01B0D1,X           ;04909F|BDD1B0  |01B0D1; get pointer to a row of kanji character data
  ; CMP.W #$BB9F                                                       ;0490A2|C99FBB  |      ; check if on very last row
    CMP.W #read2($01B127)
    BEQ case_loop_around_to_top_kanji_row_0490B6                       ;0490A5|F00F    |0490B6;
    CMP.B $09                                                          ;0490A7|C509    |001026;
    BEQ got_match_0490AF                                               ;0490A9|F004    |0490AF;
    BMI LOOP_check_next_kanji_row_04909D                               ;0490AB|30F0    |04909D;
    BRA got_next_target_0490B9                                         ;0490AD|800A    |0490B9; if somehow made it past without a match, do nothing
got_match_0490AF:
    INX #2                                                             ;0490AF|E8      |      ;
    LDA.W ptr_to_kanji_row_data_due_to_loop_counter_01B0D1,X           ;0490B1|BDD1B0  |01B0D1;
    BRA got_next_target_0490B9                                         ;0490B4|8003    |0490B9;
case_loop_around_to_top_kanji_row_0490B6:
  ; LDA.W #$B2A3                                                       ;0490B6|A9A3B2  |      ;
    LDA.W #Page1NameEntryCharData+2*!BytesPerCharScreen
got_next_target_0490B9:
  ; JSL.L check_which_char_grid_and_read_char_data_0487F8              ;0490B9|22F88704|0487F8;
    JSR.W check_which_char_grid_and_read_char_data_0487F8
    STA.B $09                                                          ;0490BD|8509    |001026;
    SEP #$20                                                           ;0490BF|E220    |      ;
    LDA.B #$80                                                         ;0490C1|A980    |      ;
    TSB.B $0B                                                          ;0490C3|040B    |001028;
  ; REP #$20                                                           ;0490C5|C220    |      ;

    ; cut out, don't need
;   JSL.L draw_gray_boxes_behind_hiragana_on_kanji_screen_049189       ;0490C7|22899104|049189;
  ; JSR.W draw_gray_boxes_behind_hiragana_on_kanji_screen_049189

  ; REP #$30                                                           ;0490CB|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;0490D1|60      |      ;
    jmp.w pull_YXAP_rts

handle_color_cycles_for_flashing_squares_0490D2:
    PHP                                                                ;0490D2|08      |      ;
    REP #$30                                                           ;0490D3|C230    |      ;
    PHA : PHX : PHY
    SEP #$30                                                           ;0490D8|E230    |      ;
    DEC.B temp_copy_of_text_xy_tile_pos-$101D                          ;0490DA|C60C    |001029; decrement frame counter
    BNE restore_regs_RTL_04910A                                        ;0490DC|D02C    |04910A;
  - LDX.B $0D                                                          ;0490DE|A60D    |00102A;
    LDA.W LIST_color_sequence_for_flashing_square_018A2B,X             ;0490E0|BD2B8A  |018A2B;
    CMP.B #$FF                                                         ;0490E3|C9FF    |      ;
    BNE got_next_palette_option_0490ED                                 ;0490E5|D006    |0490ED;
reset_palette_cycle_0490E7:
  ; LDA.B #$00                                                         ;0490E7|A900    |      ; FF is end of list, so reset back to start of list
  ; STA.B $0D                                                          ;0490E9|850D    |00102A;
    stz.b $0D                                                          ;0490E9|850D    |00102A;
    BRA -                                                              ;0490EB|80F1    |0490DE;
got_next_palette_option_0490ED:
    ASL A                                                              ;0490ED|0A      |      ;
    TAX                                                                ;0490EE|AA      |      ;
    REP #$30                                                           ;0490EF|C230    |      ;
    LDA.W COLOR_DATA_flashing_square_018A41,X                          ;0490F1|BD418A  |018A41;
    STA.W $0210                                                        ;0490F4|8D1002  |010210;
    LDA.W #$0080                                                       ;0490F7|A98000  |      ;
    TSB.W $166E                                                        ;0490FA|0C6E16  |01166E;
    SEP #$30                                                           ;0490FD|E230    |      ;
    INC.B $0D                                                          ;0490FF|E60D    |00102A; set to use next color in list
    LDX.B $0D                                                          ;049101|A60D    |00102A;
    LDA.W LIST_color_sequence_for_flashing_square_018A2B,X             ;049103|BD2B8A  |018A2B;
    STA.B temp_copy_of_text_xy_tile_pos-$101D                          ;049106|850C    |001029;
    INC.B $0D                                                          ;049108|E60D    |00102A;
restore_regs_RTL_04910A:
  ; REP #$30                                                           ;04910A|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;049110|6B      |      ;
  ; RTS                                                                ;049110|6B      |      ;
    jmp.w pull_YXAP_rts

get_font_data_for_current_name_state_049111:
; print "Breakpoint for getting font for entered name: $",hex(pc())
    PHP                                                                ;049111|08      |      ;
    REP #$30                                                           ;049112|C230    |      ;
    PHA : PHX : PHY

    LDX.W #$0000                                                       ;049117|A20000  |      ;
    sep #$20
; LOOP_prefill_name_buffer_with_asterisks_04911A:
  ; LDA.W asterisk_01B12D                                              ;04911A|AD2DB1  |01B12D;
    lda.w UnderscoreInNameEntryCharData
LOOP_prefill_name_buffer_with_asterisks_04911A:
    STA.L name_in_name_entry_screen,X                                  ;04911D|9FD0207F|7F20D0;
  ; INX #2                                                             ;049121|E8      |      ;
    inx
    CPX.W #!NameBufferSize                                             ;049123|E00C00  |      ;
    BNE LOOP_prefill_name_buffer_with_asterisks_04911A                 ;049126|D0F2    |04911A;

    LDX.W #$0000                                                       ;049128|A20000  |      ;
  ; SEP #$20                                                           ;04912B|E220    |      ;
    LDA.B $0B                                                          ;04912D|A50B    |001028;
    LSR A                                                              ;04912F|4A      |      ;
    BCS done_copying_name_049147                                       ;049130|B015    |049147;

  ; REP #$20                                                           ;049132|C220    |      ;
LOOP_copy_FFFF_terminated_name_to_buffer_049134:
    LDA.W buffer_for_name_1656,X                                       ;049134|BD5616  |011656;
  ; CMP.W #$FFFF                                                       ;049137|C9FFFF  |      ;
    cmp.b #$FF
    BEQ done_copying_name_049147                                       ;04913A|F00B    |049147;
    STA.L name_in_name_entry_screen,X                                  ;04913C|9FD0207F|7F20D0;
  ; INX #2                                                             ;049140|E8      |      ;
    inx
    CPX.W #!NameBufferSize                                             ;049142|E00C00  |      ;
    BNE LOOP_copy_FFFF_terminated_name_to_buffer_049134                ;049145|D0ED    |049134;

done_copying_name_049147:
    REP #$20                                                           ;049147|C220    |      ;
    STZ.B name_entry_name_length-$101D                                 ;049149|6407    |001024;
  ; JSL.L read_font_data_for_chars_in_entered_name_04948B              ;04914B|228B9404|04948B;
    jsr.w read_font_data_for_chars_in_entered_name_04948B
  ; LDA.W #$174F                                                       ;04914F|A94F17  |      ;
    lda.w #!OffScreenForSprite
    STA.L sprite_pos_for_flashing_square_in_name                       ;049152|8F70187F|7F1870;
  ; JSL.L DMA_OAM_data_for_highlight_boxes_and_all_extra_bytes_049270  ;049156|22709204|049270;
    jsr.w DMA_OAM_data_for_highlight_boxes_and_all_extra_bytes_049270
  ; REP #$30                                                           ;04915A|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;049160|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

; cut out, don't need
; clear_gray_boxes_below_kana_markers_for_kanji_grid_049161:
    ; PHP                                                                ;049161|08      |      ;
    ; REP #$30                                                           ;049162|C230    |      ;
    ; PHA : PHX : PHY
    ; LDX.W #$01CC                                                       ;049167|A2CC01  |      ;
; LOOP_04916A:
    ; LDA.W #$207C                                                       ;04916A|A97C20  |      ; write [7C 20 7C 20] at every 0x40 bytes from $7F1A6C - $7F1EEB
    ; STA.L BUFFER_tilemaps_for_name_entry,X                             ;04916D|9FA0187F|7F18A0; 207C = tile 07C (empty) with high priority
    ; INX #2                                                             ;049171|E8      |      ;
    ; STA.L BUFFER_tilemaps_for_name_entry,X                             ;049173|9FA0187F|7F18A0;
    ; TXA                                                                ;049177|8A      |      ;
    ; CLC                                                                ;049178|18      |      ;
    ; ADC.W #$003E                                                       ;049179|693E00  |      ;
    ; TAX                                                                ;04917C|AA      |      ;
    ; CMP.W #$064C                                                       ;04917D|C94C06  |      ; (0x64C - 0x1CC) / 0x40 = 0x12 = tile height between top and bottom of char grid box
    ; BNE LOOP_04916A                                                    ;049180|D0E8    |04916A;
  ; REP #$30                                                           ;049182|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;049188|6B      |      ;
  ; RTS
    ; jmp.w pull_YXAP_rts

; cut out, don't need
; draw_gray_boxes_behind_hiragana_on_kanji_screen_049189:
    ; PHD                                                                ;049189|0B      |      ;
    ; COP #$02                                                           ;04918A|0202    |      ;
    ; dw $0007                                                           ;04918C|        |      ; $00 <- 0x0007 = input value for $048660 to draw gray box
    ; db $01                                                             ;04918E|        |      ;
    ; PHP                                                                ;04918F|08      |      ; when player is in kanji grid, this subroutine takes all the chars present on screen,
    ; REP #$30                                                           ;049190|C230    |      ; checks if any of them are hiragana markers, and draws a gray box behind any kana
    ; PHA : PHX : PHY
  ; JSL.L clear_gray_boxes_below_kana_markers_for_kanji_grid_049161    ;049195|22619104|049161;
    ; JSR.W clear_gray_boxes_below_kana_markers_for_kanji_grid_049161
    ; LDY.W #$0000                                                       ;049199|A00000  |      ;
; LOOP_check_one_char_on_screen_04919C:
    ; TYX                                                                ;04919C|BB      |      ; get one character in the grid
    ; LDA.L MEM_LIST_char_data_for_chars_on_screen,X                     ;04919D|BF44167F|7F1644;
    ; LDX.W #$00AC                                                       ;0491A1|A2AC00  |      ; compare it against all 86 (0xAC >> 1 = 0x56 = 86) hiragana chars
; LOOP_check_against_one_hiragana_0491A4:
    ; DEX #2                                                             ;0491A4|CA      |      ;
    ; BMI +                                                              ;0491A6|300B    |0491B3;
    ; CMP.W hiragana_name_entry_data,X                                   ;0491A8|DD3BB1  |01B13B;
    ; BNE LOOP_check_against_one_hiragana_0491A4                         ;0491AB|D0F7    |0491A4;
; case_got_hiragana_marker_0491AD:
    ; LDX.B index_for_end_of_entered_name-$101B                          ;0491AD|A600    |00101B; insert tile IDs for gray box at position "behind" the hiragana char
    ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0491AF|22608604|048660;
    ; jsr.w write_two_tile_ID_columns_for_list_X_at_01884E_048660
  ; + TYA                                                                ;0491B3|98      |      ; X <- Y >> 4
    ; LSR #4                                                             ;0491B4|4A      |      ;
    ; TAX                                                                ;0491B8|AA      |      ;
    ; LDA.W DATA_018A4D,X                                                ;0491B9|BD4D8A  |018A4D; A <- 0xC + X/2 i.e. start with 0xC and increment up to 0x13
    ; STA.B index_for_end_of_entered_name-$101B                          ;0491BC|8500    |00101B;
    ; TYA                                                                ;0491BE|98      |      ; Y += 0x20 (go down a row)
    ; CLC                                                                ;0491BF|18      |      ;
    ; ADC.W #$0020                                                       ;0491C0|692000  |      ;
    ; TAY                                                                ;0491C3|A8      |      ;
    ; CMP.W #$0120                                                       ;0491C4|C92001  |      ; do up to 9 rows (0x20 * 9 = 0x120)
    ; BNE LOOP_check_one_char_on_screen_04919C                           ;0491C7|D0D3    |04919C;
  ; REP #$30                                                           ;0491C9|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;0491D0|6B      |      ;
  ; RTS
    ; jmp.w pull_YXAPD_rts

set_up_PPU_window_regs_0491D1:
    PHP                                                                ;0491D1|08      |      ;
    REP #$30                                                           ;0491D2|C230    |      ;
    PHA                                                                ;0491D4|48      |      ;
  ; PHX                                                                ;0491D5|DA      |      ;
  ; PHY                                                                ;0491D6|5A      |      ;
    LDA.W #$0200                                                       ;0491D7|A90002  |      ;
    STA.W W12SEL_copy_036E                                             ;0491DA|8D6E03  |01036E;
    LDA.W #$4344                                                       ;0491DD|A94443  |      ;
    STA.W WH0_copy_0371                                                ;0491E0|8D7103  |010371;
  ; LDA.W #$0000                                                       ;0491E3|A90000  |      ;
  ; STA.W WBGLOG_copy_0375                                             ;0491E6|8D7503  |010375;
    stz.w WBGLOG_copy_0375                                             ;0491E6|8D7503  |010375;
    LDA.W #$0004                                                       ;0491E9|A90400  |      ;
    STA.W TMW_copy_0379                                                ;0491EC|8D7903  |010379;
  ; LDA.W #$0000                                                       ;0491EF|A90000  |      ;
  ; STA.W DMAP6                                                        ;0491F2|8D6043  |014360;
    stz.w DMAP6                                                        ;0491F2|8D6043  |014360;
    LDA.W #WH1&$00FF                                                   ;0491F5|A92700  |      ;
    STA.W BBAD6                                                        ;0491F8|8D6143  |014361;
    LDA.W #HDMA_table_018a5d                                           ;0491FB|A95D8A  |      ;
    STA.W A1T6L                                                        ;0491FE|8D6243  |014362;
    LDA.W #bank(HDMA_table_018a5d)                                     ;049201|A90100  |      ;
    STA.W A1B6                                                         ;049204|8D6443  |014364;
    LDA.W #$0040                                                       ;049207|A94000  |      ;
    TSB.W HDMAEN_copy_0384                                             ;04920A|0C8403  |010384;
    LDA.W #$0058                                                       ;04920D|A95800  |      ;
    bra +
  ; TSB.W $1670                                                        ;049210|0C7016  |011670;
  ; REP #$30                                                           ;049213|C230    |      ;
  ; PLY                                                                ;049215|7A      |      ;
  ; PLX                                                                ;049216|FA      |      ;
  ; PLA                                                                ;049217|68      |      ;
  ; PLP                                                                ;049218|28      |      ;
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;049219|6B      |      ;
  ; RTS

disable_HDMA_channel_6_04921A:
    PHP                                                                ;04921A|08      |      ;
    REP #$30                                                           ;04921B|C230    |      ;
    PHA                                                                ;04921D|48      |      ;
  ; PHX                                                                ;04921E|DA      |      ;
  ; PHY                                                                ;04921F|5A      |      ;
    LDA.W #$0040                                                       ;049220|A94000  |      ;
    TRB.W HDMAEN_copy_0384                                             ;049223|1C8403  |010384;
    LDA.W #$0040                                                       ;049226|A94000  |      ;
  + TSB.W $1670                                                        ;049229|0C7016  |011670;
  - REP #$30                                                           ;04922C|C230    |      ;
  ; PLY                                                                ;04922E|7A      |      ;
  ; PLX                                                                ;04922F|FA      |      ;
    PLA                                                                ;049230|68      |      ;
    PLP                                                                ;049231|28      |      ;
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;049232|6B      |      ;
    RTS

enable_BG2_BG3_sprites_049233:
    PHP                                                                ;049233|08      |      ;
    REP #$30                                                           ;049234|C230    |      ;
    PHA                                                                ;049236|48      |      ;
  ; PHX                                                                ;049237|DA      |      ;
  ; PHY                                                                ;049238|5A      |      ;
    SEP #$20                                                           ;049239|E220    |      ;
    LDA.B #$16                                                         ;04923B|A916    |      ; enable BG2, BG3, sprites
    TSB.W TM_copy_0377                                                 ;04923D|0C7703  |010377;
    LDA.B #$10                                                         ;049240|A910    |      ;
    TSB.W $1670                                                        ;049242|0C7016  |011670;
    BRK #$00                                                           ;049245|0000    |      ;
    dw $0001                                                           ;049247|        |      ;
    bra -
  ; REP #$30                                                           ;049249|C230    |      ;
  ; PLY                                                                ;04924B|7A      |      ;
  ; PLX                                                                ;04924C|FA      |      ;
  ; PLA                                                                ;04924D|68      |      ;
  ; PLP                                                                ;04924E|28      |      ;
  ; RTS                                                                ;04924F|60      |      ;

get_sprite_pos_for_char_grid_pos_highlight_box_049250:
    PHP                                                                ;049250|08      |      ;
    REP #$30                                                           ;049251|C230    |      ;
    PHA : PHX : PHY
    LDA.W #$0000                                                       ;049256|A90000  |      ;
    SEP #$20                                                           ;049259|E220    |      ;
    LDA.B name_entry_grid_curr_position-$101D                          ;04925B|A503    |001020;
    REP #$20                                                           ;04925D|C220    |      ;
    ASL A                                                              ;04925F|0A      |      ;
    TAX                                                                ;049260|AA      |      ;
    LDA.L MEM_LIST_char_grid_highlight_positions,X                     ;049261|BF20147F|7F1420;
    STA.L char_grid_highlight_box_xy_pos                               ;049265|8F74187F|7F1874;
; this subroutine doesn't affect Y, but I'm fine with a few extra instructions to save space
  ; REP #$30                                                           ;049269|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;04926F|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

DMA_OAM_data_for_highlight_boxes_and_all_extra_bytes_049270:
    PHD                                                                ;049270|0B      |      ;
    COP #$09                                                           ;049271|0209    |      ;
    db $1D                                                             ;049273|        |      ; flags
    db $FC                                                             ;049274|        |      ; OAM address 0xFC = start with OBJ 0x7E
    db $00                                                             ;049275|        |      ;
    dw $0020+4*2                                                       ;049276|        |      ; # bytes to transfer; 2 OBJs, all extra bytes
    db $02                                                             ;049278|        |      ; parameters
    dl MEM_LIST_button_highlights_OAM_extra_bytes-4*2                  ;049279|        |7F1870; src data @ $7F1870
    db $08                                                             ;04927C|        |      ;
    PHP                                                                ;04927D|08      |      ;
    REP #$30                                                           ;04927E|C230    |      ;
    PHA : PHX : PHY
    BRK #$12                                                           ;049283|0012    |      ;
  ; REP #$30                                                           ;049285|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;04928C|6B      |      ;
  ; RTS
    jmp.w pull_YXAPD_rts

handle_pressing_A_L_in_char_grid_04928D:
    PHP                                                                ;04928D|08      |      ;
    REP #$30                                                           ;04928E|C230    |      ;
    PHA : PHX : PHY
    LDA.W #$0000                                                       ;049293|A90000  |      ;
    SEP #$30                                                           ;049296|E230    |      ;
    LDA.B name_entry_grid_curr_position-$101D                          ;049298|A503    |001020; get value for position in grid (roughly, byte is RC)
    TAX                                                                ;04929A|AA      |      ;
    LDA.L state_values_for_pos_in_name_entry_grid,X                    ;04929B|BF20127F|7F1220; get value for "state" for position
    REP #$30                                                           ;04929F|C230    |      ;
    ASL A                                                              ;0492A1|0A      |      ;
    TAX                                                                ;0492A2|AA      |      ;
    JSR.W (JUMP_TABLE_for_A_press_in_name_entry_0492AD,X)              ;0492A3|FCAD92  |0492AD;
  ; REP #$30                                                           ;0492A6|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;0492AC|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

JUMP_TABLE_for_A_press_in_name_entry_0492AD:
    dw $0000                                                           ;0492AD|        |      ; (00 is off grid)
    dw press_A_on_char_in_grid_0492C7                                  ;0492AF|        |0492C7; 01 = any of the "middle" char columns
    dw press_A_on_char_in_grid_0492C7                                  ;0492B1|        |0492C7; 02 = leftmost char column
    dw press_A_on_char_in_grid_0492C7                                  ;0492B3|        |0492C7; 03 = rightmost char column
    dw $0000,$0000                                                     ;0492B5|        |      ; (04 and 05 are off grid)
    dw RTS_04933B                                                      ;0492B9|        |04933B; 06 = kanji selector (do nothing)
    dw RTS_04933B                                                      ;0492BB|        |04933B; 07 = hiragana selector (do nothing)
    dw RTS_04933B                                                      ;0492BD|        |04933B; 08 = katakana selector (do nothing)
    dw press_A_on_space_button_04933C                                  ;0492BF|        |04933C; 09 = space
    dw press_A_on_delete_button_0493DD                                 ;0492C1|        |0493DD; 0A = delete
    dw press_A_on_clear_button_04938E                                  ;0492C3|        |04938E; 0B = clear
    dw press_A_on_finish_button_0493EE                                 ;0492C5|        |0493EE; 0C = finish

; input  in A: the length of the currently entered name
; output in P: comparison result
; possible consideration(s): should M flag be preserved?
CompareAgainstNameCharLimitForNameType:
    rep #$20
    pha
    lda.w menu_type_00_tooru_mari_02_killer
    and.w #$00ff
    bne CaseKillerCharLimit
CaseNonKillerCharLimit:
    pla
    cmp.w #!CharLimitForNonKillerNameEntry
    rts
CaseKillerCharLimit:
    pla
    cmp.w #!CharLimitForKillerNameEntry
    rts

press_A_on_char_in_grid_0492C7:
    PHP                                                                ;0492C7|08      |      ;
    REP #$30                                                           ;0492C8|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;0492CD|E220    |      ;
    LDA.B #$80                                                         ;0492CF|A980    |      ; indicate to do DMA subs at $048A3D
    TSB.B $0B                                                          ;0492D1|040B    |001028;

    REP #$20                                                           ;0492D3|C220    |      ;
    LDA.B name_entry_name_length-$101D                                 ;0492D5|A507    |001024;
; move "is name empty" case up here
    beq CaseNameIsEmptyWhenPressingA
  ; CMP.W #!NameBufferSize                                             ;0492D7|C90C00  |      ; check length; do nothing if 6 characters in name
;   cmp.w #!CharLimitForNameEntry
    jsr.w CompareAgainstNameCharLimitForNameType
    BEQ draw_gray_finish_box_and_move_cursor_to_it_04931F              ;0492DA|F043    |04931F;
  ; CMP.W #$0000                                                       ;0492DC|C90000  |      ; if the name is empty, skip down
  ; BNE name_is_initialized_for_entry_0492F2                           ;0492DF|D011    |0492F2;
    bra name_is_initialized_for_entry_0492F2

CaseNameIsEmptyWhenPressingA:
  ; LDX.W #$0000                                                       ;0492E1|A20000  |      ; pre-fill the name with all asterisks
  ; LDA.W asterisk_01B12D                                              ;0492E4|AD2DB1  |01B12D;
  + tax
    sep #$20
    lda.w UnderscoreInNameEntryCharData
LOOP_pre_fill_name_with_asterisks_0492E7:
    STA.L name_in_name_entry_screen,X                                  ;0492E7|9FD0207F|7F20D0;
  ; INX #2                                                             ;0492EB|E8      |      ;
    inx
    CPX.W #!NameBufferSize                                             ;0492ED|E00C00  |      ;
    BNE LOOP_pre_fill_name_with_asterisks_0492E7                       ;0492F0|D0F5    |0492E7;
    bra +

name_is_initialized_for_entry_0492F2:
    LDA.W #$0000                                                       ;0492F2|A90000  |      ;
    SEP #$20                                                           ;0492F5|E220    |      ;
  + LDA.B name_entry_grid_curr_position-$101D                          ;0492F7|A503    |001020; use the grid position to read a character encoding value
    REP #$20                                                           ;0492F9|C220    |      ;
    ASL A                                                              ;0492FB|0A      |      ;
    TAX                                                                ;0492FC|AA      |      ;
    LDA.L name_entry_chars_on_screen,X                                 ;0492FD|BF20167F|7F1620;
GotCharValueToWriteToName:
    and.w #$00ff
    sep #$20
    LDX.B name_entry_name_length-$101D                                 ;049301|A607    |001024; store the value to the correct position in the player's name
    STA.L name_in_name_entry_screen,X                                  ;049303|9FD0207F|7F20D0;
; turn off the name highlight box altogether
  ; LDA.W name_entry_char_flashing_sprite_position,X                   ;049307|BD648A  |018A64; update position for flashing sprite
    rep #$20
    lda.w #!OffScreenForSprite
    STA.L sprite_pos_for_flashing_square_in_name                       ;04930A|8F70187F|7F1870;
  ; JSL.L read_font_data_for_chars_in_entered_name_04948B              ;04930E|228B9404|04948B;
    JSR.W read_font_data_for_chars_in_entered_name_04948B
    INC.B name_entry_name_length-$101D                                 ;049312|E607    |001024;
  ; INC.B name_entry_name_length-$101D                                 ;049314|E607    |001024;
    BRK #$17                                                           ;049316|0017    |      ;
    LDA.B name_entry_name_length-$101D                                 ;049318|A507    |001024;
  ; CMP.W #!NameBufferSize                                             ;04931A|C90C00  |      ;
;   cmp.w #!CharLimitForNameEntry
    jsr.w CompareAgainstNameCharLimitForNameType
    BNE restore_regs_RTS_049334                                        ;04931D|D015    |049334;

draw_gray_finish_box_and_move_cursor_to_it_04931F:
  ; LDX.W #$000B                                                       ;04931F|A20B00  |      ; draw gray box for "finish"
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;049322|22608604|048660;
    ldx.w #!TwoColumnFinishGrayBox
    jsr.w write_two_tile_ID_columns_for_list_X_at_01884E_048660
    LDX.W #$000F                                                       ;049326|A20F00  |      ; wait about 15 frames = 1/4 of a second?
  - BRK #$00                                                           ;049329|0000    |      ;
    dw $0001                                                           ;04932B|        |      ;
    DEX                                                                ;04932D|CA      |      ;
    BNE -                                                              ;04932E|D0F9    |049329;
  ; JSL.L handle_moving_to_finish_box_049039                           ;049330|22399004|049039;
    JSR.W handle_moving_to_finish_box_049039
restore_regs_RTS_049334:
  ; REP #$30                                                           ;049334|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;04933A|60      |      ;
    jmp.w pull_YXAP_rts

RTS_04933B:
    RTS                                                                ;04933B|60      |      ;

press_A_on_space_button_04933C:
    PHP                                                                ;04933C|08      |      ;
    REP #$30                                                           ;04933D|C230    |      ;
    PHA : PHX : PHY
    SEP #$20                                                           ;049342|E220    |      ;
    LDA.B #$80                                                         ;049344|A980    |      ; indicate to do DMA subs at $048A3D
    TSB.B $0B                                                          ;049346|040B    |001028;
    REP #$20                                                           ;049348|C220    |      ;
    LDA.B name_entry_name_length-$101D                                 ;04934A|A507    |001024;
  ; CMP.W #!NameBufferSize                                             ;04934C|C90C00  |      ;
  ; BEQ restore_regs_RTS_049387                                        ;04934F|F036    |049387;
;   cmp.w #!CharLimitForNameEntry
    jsr.w CompareAgainstNameCharLimitForNameType
    beq restore_regs_RTS_049334
    LDA.W #$0000                                                       ;049351|A90000  |      ; insert a space character at correct position
    bra GotCharValueToWriteToName
  ; LDX.B name_entry_name_length-$101D                                 ;049354|A607    |001024;
  ; STA.L name_in_name_entry_screen,X                                  ;049356|9FD0207F|7F20D0;
  ; LDA.W name_entry_char_flashing_sprite_position,X                   ;04935A|BD648A  |018A64;
  ; STA.L sprite_pos_for_flashing_square_in_name                       ;04935D|8F70187F|7F1870;
;   JSL.L read_font_data_for_chars_in_entered_name_04948B              ;049361|228B9404|04948B;
  ; JSR.W read_font_data_for_chars_in_entered_name_04948B
  ; INC.B name_entry_name_length-$101D                                 ;049365|E607    |001024;
  ; INC.B name_entry_name_length-$101D                                 ;049367|E607    |001024;
  ; BRK #$17                                                           ;049369|0017    |      ;
  ; LDA.B name_entry_name_length-$101D                                 ;04936B|A507    |001024; check for character limit of 6
  ; CMP.W #!NameBufferSize                                             ;04936D|C90C00  |      ;
  ; BNE restore_regs_RTS_049387                                        ;049370|D015    |049387;
  ; LDX.W #$000B                                                       ;049372|A20B00  |      ; draw gray "finish" box
;   JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;049375|22608604|048660;
  ; ldx.w #!TwoColumnFinishGrayBox
  ; jsr.w write_two_tile_ID_columns_for_list_X_at_01884E_048660
  ; LDX.W #$000F                                                       ;049379|A20F00  |      ; move cursor to it after 0x10 frames
; - BRK #$00                                                           ;04937C|0000    |      ;
  ; dw $0001                                                           ;04937E|        |      ;
  ; DEX                                                                ;049380|CA      |      ;
  ; BNE -                                                              ;049381|D0F9    |04937C;
  ; JSL.L handle_moving_to_finish_box_049039                           ;049383|22399004|049039;
  ; JSR.W handle_moving_to_finish_box_049039
; restore_regs_RTS_049387:
  ; REP #$30                                                           ;049387|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;04938D|60      |      ;

press_A_on_clear_button_04938E:
    PHP                                                                ;04938E|08      |      ;
    REP #$30                                                           ;04938F|C230    |      ;
    PHA : PHX : PHY
  ; LDA.W #$0000                                                       ;049394|A90000  |      ; you can just use STZ here?
  ; STA.B name_entry_name_length-$101D                                 ;049397|8507    |001024;
    stz.b name_entry_name_length-$101D
    LDX.W #$0000                                                       ;049399|A20000  |      ; overwrite buffer contents with all asterisks
; have to read and write underscores as bytes, not words
  ; LDA.W asterisk_01B12D                                              ;04939C|AD2DB1  |01B12D;
    sep #$20
    lda.w UnderscoreInNameEntryCharData
  - STA.L name_in_name_entry_screen,X                                  ;04939F|9FD0207F|7F20D0;
  ; INX #2                                                             ;0493A3|E8      |      ;
    inx
    CPX.W #!NameBufferSize                                             ;0493A5|E00C00  |      ;
    BNE -                                                              ;0493A8|D0F5    |04939F;
; replace JSL with JSR; since already have M=1, don't need to set it again
  ; JSL.L read_font_data_for_chars_in_entered_name_04948B              ;0493AA|228B9404|04948B;
  ; SEP #$20                                                           ;0493AE|E220    |      ;
    jsr.w read_font_data_for_chars_in_entered_name_04948B

    LDA.B #$80                                                         ;0493B0|A980    |      ;
    TSB.B $0B                                                          ;0493B2|040B    |001028;

; set name highlight box to off screen; don't need it
    REP #$20                                                           ;0493B4|C220    |      ;
  ; LDA.W #$174F                                                       ;0493B6|A94F17  |      ; reset sprite position for flashing square over entered name to the first character
    lda.w #!OffScreenForSprite
    STA.L sprite_pos_for_flashing_square_in_name                       ;0493B9|8F70187F|7F1870;

    SEP #$20                                                           ;0493BD|E220    |      ;
    LDA.B #$12                                                         ;0493BF|A912    |      ; reset grid position to top left of the grid
    STA.B name_entry_grid_curr_position-$101D                          ;0493C1|8503    |001020;
  ; JSL.L get_sprite_pos_for_char_grid_pos_highlight_box_049250        ;0493C3|22509204|049250;
    JSR.W get_sprite_pos_for_char_grid_pos_highlight_box_049250

    REP #$20                                                           ;0493C7|C220    |      ;
  ; JSL.L set_button_sprites_off_screen_flash_squares_on_screen_048CFC ;0493C9|22FC8C04|048CFC;
    JSR.W set_button_sprites_off_screen_flash_squares_on_screen_048CFC
  ; LDX.W #$0006                                                       ;0493CD|A20600  |      ; draw black "finish" box
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;0493D0|22608604|048660;
    ldx.w #!TwoColumnFinishBlackBox
    jsr.w write_two_tile_ID_columns_for_list_X_at_01884E_048660
    BRK #$18                                                           ;0493D4|0018    |      ; play the "delete character" sound effect
  ; REP #$30                                                           ;0493D6|C230    |      ;
  ; PLY : PLX : PLA : PLP
  ; RTS                                                                ;0493DC|60      |      ;
    jmp.w pull_YXAP_rts

; press_A_on_delete_button_0493DD:
; this jump table entry is just a JSR wrapper to code that's accessed with a JSL
; but the underlying code is only ever accessed in the current bank, so we can
; just have the pointer in the jump table go directly to the main code itself,
; since the "save processor state on stack" setup code is the same
  ; PHP                                                                ;0493DD|08      |      ;
  ; REP #$30                                                           ;0493DE|C230    |      ;
  ; PHA                                                                ;0493E0|48      |      ;
  ; PHX                                                                ;0493E1|DA      |      ;
  ; PHY                                                                ;0493E2|5A      |      ;
  ; JSL.L ctrl_flow_del_char_0495EE                                    ;0493E3|22EE9504|0495EE;
  ; REP #$30                                                           ;0493E7|C230    |      ;
  ; PLY                                                                ;0493E9|7A      |      ;
  ; PLX                                                                ;0493EA|FA      |      ;
  ; PLA                                                                ;0493EB|68      |      ;
  ; PLP                                                                ;0493EC|28      |      ;
  ; RTS                                                                ;0493ED|60      |      ;

press_A_on_finish_button_0493EE:
; this jump table entry is just a JSR wrapper to code that's accessed with a JSL
; but the underlying code is only ever accessed in the current bank, so we can
; just have the pointer in the jump table go directly to the main code itself,
; since the "save processor state on stack" setup code is the same
  ; PHP                                                                ;0493EE|08      |      ;
  ; REP #$30                                                           ;0493EF|C230    |      ;
  ; PHA                                                                ;0493F1|48      |      ;
  ; PHX                                                                ;0493F2|DA      |      ;
  ; PHY                                                                ;0493F3|5A      |      ;
  ; JSL.L check_if_entered_name_is_valid_0493FF                        ;0493F4|22FF9304|0493FF;
  ; REP #$30                                                           ;0493F8|C230    |      ;
  ; PLY                                                                ;0493FA|7A      |      ;
  ; PLX                                                                ;0493FB|FA      |      ;
  ; PLA                                                                ;0493FC|68      |      ;
  ; PLP                                                                ;0493FD|28      |      ;
  ; RTS                                                                ;0493FE|60      |      ;

check_if_entered_name_is_valid_0493FF:
; print "Breakpoint for checking if entered name is valid: $",hex(pc())
    PHP                                                                ;0493FF|08      |      ;
    REP #$30                                                           ;049400|C230    |      ;
    PHA : PHX : PHY

; check data in name as bytes, not words
  ; LDX.W #$FFFE                                                       ;049405|A2FEFF  |      ;
    ldx.w #$ffff
LOOP_skip_leading_spaces_asterisks_049408:
  ; INX #2                                                             ;049408|E8      |      ;
  ; CPX.W #!NameBufferSize                                             ;04940A|E00C00  |      ;
    inx
;   cpx.w #!CharLimitForNameEntry
    txa
    jsr.w CompareAgainstNameCharLimitForNameType
    BEQ restore_regs_RTL_049427                                        ;04940D|F018    |049427;
    LDA.L name_in_name_entry_screen,X                                  ;04940F|BFD0207F|7F20D0; load character value
    and.w #$00ff
; move up "check for space" here
    beq LOOP_skip_leading_spaces_asterisks_049408
  ; CMP.W asterisk_01B12D                                              ;049413|CD2DB1  |01B12D; if got an asterisk, skip to the next character
    cmp.w UnderscoreInNameEntryCharData
    BEQ LOOP_skip_leading_spaces_asterisks_049408                      ;049416|F0F0    |049408;
  ; CMP.W #$0000                                                       ;049418|C90000  |      ; if got a space, skip to the next character
  ; BEQ LOOP_skip_leading_spaces_asterisks_049408                      ;04941B|F0EB    |049408;

    JSR.W copy_trimmed_version_of_entered_name_04942E                  ;04941D|202E94  |04942E;
    BRK #$17                                                           ;049420|0017    |      ;

    LDA.W #$2000                                                       ;049422|A90020  |      ; indicate that valid name has been entered
    STA.B char_grid_contr_input_val-$101D                              ;049425|8505    |001022;
restore_regs_RTL_049427:
  ; REP #$30                                                           ;049427|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;04942D|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

; I'm not sure if this qualifies as a "bug" or not, but it's possible to prefix
; a name with asterisks and have it be recognized as valid; e.g. start w/ Mari's
; default Japanese name 真理, then select Space and Delete to get "＊理" in the
; text box, which can be set as her name; I'm choosing to fix this by trimming
; out leading asterisks from the entered name
copy_trimmed_version_of_entered_name_04942E:
    PHD                                                                ;04942E|0B      |      ;
    COP #$00                                                           ;04942F|0200    |      ;
    db $01                                                             ;049431|        |      ;
    PHP                                                                ;049432|08      |      ;
    REP #$30                                                           ;049433|C230    |      ;
    PHA : PHX : PHY

; in the JP game, the loop fills the $1656 buffer with 00 bytes, then copies in
; the entered name, then writes an FFFF terminator if it does not occupy the
; whole buffer
; beyond having to do a one-byte encoding hack, I think it would be better to
; pre-fill the buffer with all FF at first instead
    LDX.W #!NameBufferSize                                             ;049438|A20C00  |      ;
    lda.w #$ffff
LOOP_clear_name_buffer_04943B:
    DEX #2                                                             ;04943B|CA      |      ; clear out $1656 thru $1661
  ; STZ.W buffer_for_name_1656,X                                       ;04943D|9E5616  |011656;
    sta.w buffer_for_name_1656,x
    BNE LOOP_clear_name_buffer_04943B                                  ;049440|D0F9    |04943B;

  ; LDX.W #$FFFE                                                       ;049442|A2FEFF  |      ;
    tax ; X <- FFFF
    sep #$20
LOOP_skip_leading_spaces_049445:
  ; INX #2                                                             ;049445|E8      |      ; in this loop, X <- index of first non-space character
    inx
    LDA.L name_in_name_entry_screen,X                                  ;049447|BFD0207F|7F20D0;
    BEQ LOOP_skip_leading_spaces_049445                                ;04944B|F0F8    |049445;
; add: also skip leading asterisks
    cmp.w UnderscoreInNameEntryCharData
    beq LOOP_skip_leading_spaces_049445

    PHX                                                                ;04944D|DA      |      ; keep calculated index on stack for later
  ; LDX.W #!NameBufferSize                                             ;04944E|A20C00  |      ; check characters starting at the end of the entered name
;   ldx.w #!CharLimitForNameEntry
    lda.w menu_type_00_tooru_mari_02_killer
    beq +
    ldx.w #!CharLimitForKillerNameEntry
    bra LOOP_skip_trailing_spaces_asterisks_049451
  + ldx.w #!CharLimitForNonKillerNameEntry
LOOP_skip_trailing_spaces_asterisks_049451:
  ; DEX #2                                                             ;049451|CA      |      ; ignore any trailing asterisks or spaces
    dex
    LDA.L name_in_name_entry_screen,X                                  ;049453|BFD0207F|7F20D0;
    BEQ LOOP_skip_trailing_spaces_asterisks_049451                     ;049457|F0F8    |049451;
  ; CMP.W asterisk_01B12D                                              ;049459|CD2DB1  |01B12D;
    cmp.w UnderscoreInNameEntryCharData
    BEQ LOOP_skip_trailing_spaces_asterisks_049451                     ;04945C|F0F3    |049451;

  ; INX #2                                                             ;04945E|E8      |      ; store index for the end of the name
    inx
    STX.B index_for_end_of_entered_name-$101B                          ;049460|8600    |00101B;

    PLX                                                                ;049462|FA      |      ; take only the letters we care about for the final result
    LDY.W #$0000                                                       ;049463|A00000  |      ;
  - LDA.L name_in_name_entry_screen,X                                  ;049466|BFD0207F|7F20D0;
    PHX                                                                ;04946A|DA      |      ;
    TYX                                                                ;04946B|BB      |      ;
    STA.W buffer_for_name_1656,Y                                       ;04946C|995616  |011656;
    PLX                                                                ;04946F|FA      |      ;
  ; INY #2                                                             ;049470|C8      |      ;
  ; INX #2                                                             ;049472|E8      |      ;
    iny : inx
    CPX.B index_for_end_of_entered_name-$101B                          ;049474|E400    |00101B;
    BNE -                                                              ;049476|D0EE    |049466;

; this next section writes FFFF after the name if it is 0-5 characters long
; already took care of this above
  ; CPY.W #!NameBufferSize                                             ;049478|C00C00  |      ; check if entered name is 6 characters long
  ; BEQ restore_regs_RTS_049483                                        ;04947B|F006    |049483;
  ; LDA.W #$FFFF                                                       ;04947D|A9FFFF  |      ; insert FFFF terminator if needed
  ; STA.W buffer_for_name_1656,Y                                       ;049480|995616  |011656; so entered name is either FFFF terminated, or exactly fits the buffer
restore_regs_RTS_049483:
  ; REP #$30                                                           ;049483|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;04948A|60      |      ;
    jmp.w pull_YXAPD_rts

read_font_data_for_chars_in_entered_name_04948B:
    PHD                                                                ;04948B|0B      |      ; control flow comes here after selecting a character or the space button
    COP #$00                                                           ;04948C|0200    |      ;
    db $0C                                                             ;04948E|        |      ;
    PHP                                                                ;04948F|08      |      ;
    REP #$30                                                           ;049490|C230    |      ;
    PHA : PHX : PHY

    LDA.W #$0000                                                       ;049495|A90000  |      ; for now, set end of entered name to 0
    STA.B index_for_end_of_entered_name-$1010                          ;049498|850B    |00101B;
    TAX                                                                ;04949A|AA      |      ;
  - STA.L font_data_buffer_for_entered_name,X                          ;04949B|9F402D7F|7F2D40; initialize the space $7F2D40 - $7F2DFF with all 00 bytes
    INX #2                                                             ;04949F|E8      |      ; this is used for storing the uncompressed font data for the 6 characters
    CPX.W #$00C0                                                       ;0494A1|E0C000  |      ;
    BNE -                                                              ;0494A4|D0F5    |04949B;

; new: initialize X/Y position for printing whole name
; instead of drawing to original buffer at $7F0000 (space for 1 character),
; draw to part of the buffer with enough space for all the characters
    lda.w #(!DecompressedNameFontTextY<<8)|(!DecompressedNameFontTextX+1)
    sta.b x_pos_to_center_char_in_entered_name-$1010
    sta.w TextXPos

; set the top byte of the two-byte character to print as 00
    stz.b name_entry_1_indexed_encoding_val-$1010
LOOP_write_font_data_for_1_char_in_entered_name_0494A6:
    LDX.B index_for_end_of_entered_name-$1010                          ;0494A6|A60B    |00101B; get index for current position in entered name
    LDA.L name_in_name_entry_screen,X                                  ;0494A8|BFD0207F|7F20D0;
; JP game: each character is printed individually to buffer, and in monospace
; starting X position is (0xF - width) / 2 -> center char in 0xF pixel block;
; in patch, better to either left-align or center the whole name in box?
  ; CMP.W #$0000                                                       ;0494AC|C90000  |      ; if character is a space, skip down
  ; BEQ SkipWritingFontDataForSpace                                    ;0494AF|F02C    |0494DD;
  ; DEC A                                                              ;0494B1|3A      |      ; otherwise, prepare to read the font data for it
  ; STA.B name_entry_1_indexed_encoding_val-$1010                      ;0494B2|8500    |001010; store 1-indexed character encoding value to $1010
  ; JSL.L get_X_pos_for_centering_char_in_16x16_block_049558           ;0494B4|22589504|049558; get the value (0xF - char_width) / 2
  ; STA.B x_pos_to_center_char_in_entered_name-$1010                   ;0494B8|8505    |001015;
  ; STA.W TextXPos                                                     ;0494BA|8DE615  |0115E6;

    and.w #$00ff
    beq SkipWritingFontDataForSpace
    dec a
    and.w #$00ff
    sta.b name_entry_1_indexed_encoding_val-$1010

  ; LDA.B x_pos_to_center_char_in_entered_name-$1010                   ;0494BD|A505    |001015; calculate the Y and X tile positions for text
    lda.w TextXPos
    AND.W #$F8F8                                                       ;0494BF|29F8F8  |      ;
    SEP #$20                                                           ;0494C2|E220    |      ;
    XBA                                                                ;0494C4|EB      |      ; manipulate YYYY Y--- XXXX X--- into ---Y YYYY XXXX X---
    LSR #3
    XBA                                                                ;0494C8|EB      |      ;
    REP #$20                                                           ;0494C9|C220    |      ;
    ASL A                                                              ;0494CB|0A      |      ; store result --YY YYYX XXXX ----
    STA.B $03                                                          ;0494CC|8503    |001013; this sets a value that gets used later for font shadowing, see $02A003
    JSL.L write_font_data_for_char_to_7F0000_buffer_029F66             ;0494CE|22669F02|029F66;

; in JP game, the font shadow that came as part of the font decompression is
; removed one character at a time; with VWF, may be better to remove all of it
; at once after printing all the characters
  ; LDX.B index_for_end_of_entered_name-$1010                          ;0494D2|A60B    |00101B; given an index N from 0 to 5, read [0x40 + N*0x20], so 40 60 80 A0 C0 or E0
  ; LDA.W LIST_offsets_for_entered_chars_font_data_018A70,X            ;0494D4|BD708A  |018A70;
  ; STA.B $09                                                          ;0494D7|8509    |001019;
  ; JSL.L remove_shadowing_for_entered_char_049583                     ;0494D9|22839504|049583;

SkipWritingFontDataForSpace:
  ; JSR.W clear_extra_byte_from_removing_shadowing_04951A              ;0494DD|201A95  |04951A;
  ; JSL.L clear_decompressed_font_data_0483A9                          ;0494E0|22A98304|0483A9;
    jsr.w AddWidthPlusOneToTextX
    INC.B index_for_end_of_entered_name-$1010                          ;0494E4|E60B    |00101B; advance by one character in name buffer
  ; INC.B index_for_end_of_entered_name-$1010                          ;0494E6|E60B    |00101B;
    LDA.B index_for_end_of_entered_name-$1010                          ;0494E8|A50B    |00101B; if at limit, we are done
  ; CMP.W #!NameBufferSize                                             ;0494EA|C90C00  |      ;
;   cmp.w #!CharLimitForNameEntry
    jsr.w CompareAgainstNameCharLimitForNameType
    BNE LOOP_write_font_data_for_1_char_in_entered_name_0494A6         ;0494ED|D0B7    |0494A6;

; remove shadowing all at once after loop is finished
  ; lda.w LIST_offsets_for_entered_chars_font_data_018A70
    stz.b $09
    jsr.w RemoveShadowingForNameAndConvertToSetsOfFour8x8Tiles
  ; jsr.w clear_extra_byte_from_removing_shadowing_04951A

    JSR.W write_font_data_for_name_to_WRAM_and_then_VRAM_0494FA        ;0494EF|20FA94  |0494FA; when name is finished, run the subroutine below

; we need to clear out the decompressed font for future updates
    jsr.w clear_decompressed_font_data_0483A9

  ; REP #$30                                                           ;0494F2|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;0494F9|6B      |      ;
  ; RTS
    jmp.w pull_YXAPD_rts

write_font_data_for_name_to_WRAM_and_then_VRAM_0494FA:
; also see $048611 for writing the tilemap
!NumRowsDownForName = $D
!IndexForLzssOffsetLookupTable = $0000 ; $0004
!TargetVramTileIDForName = !NumRowsDownForName*$8       ; $62 = 0xC * 8, + 2
!Num16x16TilesForName = $08            ; $06
    PHD                                                                ;0494FA|0B      |      ;
    COP #$06                                                           ;0494FB|0206    |      ;
    dw $0000                                                           ;0494FD|        |      ; $00 <- 0x0000; what's the purpose?
    dw !IndexForLzssOffsetLookupTable                                  ;0494FF|        |      ; $02 <- 0x4 = starting index in lookup table
    db !TargetVramTileIDForName                                        ;049501|        |      ; $04 <- 0x62 = tile # to copy to
    db !Num16x16TilesForName                                           ;049502|        |      ; $06 <- 0x6 = # chars (16x16 tiles?) to copy
    db $05                                                             ;049503|        |      ;
    PHP                                                                ;049504|08      |      ;
    REP #$30                                                           ;049505|C230    |      ;
    PHA : PHX : PHY
  ; JSL.L wrapper_to_read_gfx_data_for_N_chars_in_grid_048361          ;04950A|22618304|048361; write font data for the name's six characters to $7F0E40
    jsr.w wrapper_to_read_gfx_data_for_N_chars_in_grid_048361   ; see $0497a1
  ; JSL.L do_DMA_transfer_of_currently_entered_name_to_VRAM_049536     ;04950E|22369504|049536;
    jsr.w do_DMA_transfer_of_currently_entered_name_to_VRAM_049536     ;04950E|22369504|049536;
  ; REP #$30                                                           ;049512|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
  ; RTS                                                                ;049519|60      |      ;
    jmp.w pull_YXAPD_rts

; may not need this? I tried to incorporate it into the "remove shadow" routine
; clear_extra_byte_from_removing_shadowing_04951A:
;   PHP                                                                ;04951A|08      |      ;
;   REP #$30                                                           ;04951B|C230    |      ;
;   PHA : PHX : PHY
;   LDA.W LIST_offsets_for_entered_chars_font_data_018A70,X            ;049520|BD708A  |018A70; removing the shadowing copies in an extraneous byte, so clear it out
;   CLC                                                                ;049523|18      |      ;
;   ADC.W #$0020                                                       ;049524|692000  |      ;
;   TAX                                                                ;049527|AA      |      ;
;   LDA.W #$0000                                                       ;049528|A90000  |      ;
;   STA.L BUFFER_decompressed_name_entry_font_1bpp_data,X              ;04952B|9F002D7F|7F2D00;
; ; REP #$30                                                           ;04952F|C230    |      ;
; ; PLY : PLX : PLA : PLP
; ; RTS                                                                ;049535|60      |      ;
;   jmp.w pull_YXAP_rts

do_DMA_transfer_of_currently_entered_name_to_VRAM_049536:
    PHD                                                                ;049536|0B      |      ;
    COP #$0A                                                           ;049537|020A    |      ;
    db $5B                                                             ;049539|        |      ; BRK flags
; need to update src CPU address and dest VRAM address
  ; dw $6C00,$0100                                                     ;04953A|        |      ; VRAM address $6C00.w, transfer 0x100 bytes
    dw $6000+!NumRowsDownForName*$100
    dw $0100
    db $00                                                             ;04953E|        |      ; DMA params
; need to update src address based on above
  ; dl $7F0E20                                                         ;04953F|        |7F0E20; src data ptr 7F0E20
    dl BUFFER_1bpp_char_grid_gfx_on_screen+!NumRowsDownForName*$100
    db $00,$09                                                         ;049542|        |      ; DMA bus $2100
  ; PHP                                                                ;049544|08      |      ;
  ; REP #$30                                                           ;049545|C230    |      ;
  ; PHA : PHX : PHY
  ; BRK #$0C                                                           ;04954A|000C    |      ;
  ; BRK #$00                                                           ;04954C|0000    |      ;
  ; db $0008                                                           ;04954E|        |      ;
  ; REP #$30                                                           ;049550|C230    |      ;
  ; PLY : PLX : PLA : PLP : PLD
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;049557|6B      |      ;
  ; RTS
    jmp.w DoBRK0C_BRK_00_0008_WithParamsFilledInOnDirectPage

; this subroutine is only used once in the code (and in current bank)
; however, I don't think I'll reuse it in the patch because I've integrated the
; VWF proper for displaying the entered name
; get_X_pos_for_centering_char_in_16x16_block_049558:
;   PHP : PHX : PHY
;   LDX.W #$0000                                                       ;04955B|A20000  |      ;
;   INC.B name_entry_1_indexed_encoding_val-$1010                      ;04955E|E600    |001010;
; ; LDA.W FONT_TABLE_size_of_char_groups_01A736,X                      ;049560|BD36A7  |01A736; check which font character group to read from
;   lda.w NewFontGroupSizesTable,X
; - CMP.B name_entry_1_indexed_encoding_val-$1010                      ;049563|C500    |001010;
;   BPL +                                                              ;049565|1007    |04956E;
;   INX #2                                                             ;049567|E8      |      ;
; ; ADC.W FONT_TABLE_size_of_char_groups_01A736,X                      ;049569|7D36A7  |01A736;
;   adc.w NewFontGroupSizesTable,X
;   BRA -                                                              ;04956C|80F5    |049563;

; + LDA.W #$0000                                                       ;04956E|A90000  |      ; clear out top byte of A
;   SEP #$20                                                           ;049571|E220    |      ;
; ; LDA.W FONT_TABLE_dimensions_for_char_groups_01A7A0,X               ;049573|BDA0A7  |01A7A0; get the width of the character
;   lda.w NewFontDimensionsTable,X
;   AND.B #$0F                                                         ;049576|290F    |      ;
;   EOR.B #$0F                                                         ;049578|490F    |      ; return the value (W ^ 0xF) >> 1
;   LSR A                                                              ;04957A|4A      |      ; because 1 <= W <= 0xF, can simplify as (0xF - W) >> 1
;   REP #$20                                                           ;04957B|C220    |      ;
;   DEC.B name_entry_1_indexed_encoding_val-$1010                      ;04957D|C600    |001010;
;   PLY : PLX : PLP
; this subroutine is only accessed in current bank, so replace with RTS
; ; RTL                                                                ;049582|6B      |      ;
;   rts

AddWidthPlusOneToTextX:
    php
    rep #$20
    phx
; get character encoding; if 0000 = space, use width of 2
    ldx.b index_for_end_of_entered_name-$1010
    lda.l name_in_name_entry_screen,x
    and.w #$00ff
    bne +
    lda.w #$0002
    bra ++

; otherwise, determine correct font metadata range
  + sta.b name_entry_1_indexed_encoding_val-$1010
    ldx.w #$0000
    lda.w NewFontGroupSizesTable,x
  - cmp.b name_entry_1_indexed_encoding_val-$1010
    bpl +
    inx #2
    adc.w NewFontGroupSizesTable,X
    bra -

; extract out the width value, add it to text X, and add 1 for spacing
  + lda.w NewFontDimensionsTable,X
    and.w #$000f
 ++ sec
    adc.w TextXPos
    sta.w TextXPos
    sta.b x_pos_to_center_char_in_entered_name-$1010
    plx : plp
    rts

; this accomplishes two things: remove the font shadowing, and copy the 16x16
; pixel block of font data as four tiles [TL TR BL BR]
; you can condense the two loops into one
; remove_shadowing_for_entered_char_049583:
RemoveShadowingForNameAndConvertToSetsOfFour8x8Tiles:
    PHP                                                                ;049583|08      |      ;
    REP #$30                                                           ;049584|C230    |      ;
    PHA : PHX : PHY

  ; LDX.W #$0000                                                       ;049589|A20000  |      ;
; LOOP_top_row_04958C:
  ; LDA.L $7F0000,X                                                    ;04958C|BF00007F|7F0000; contains the font gfx for the most recently decompressed character
  ; TXY                                                                ;049590|9B      |      ;
  ; LDX.B $09                                                          ;049591|A609    |001019; copy the top tile row of the character's gfx into the space for the entered name
  ; STA.L BUFFER_decompressed_name_entry_font_1bpp_data,X              ;049593|9F002D7F|7F2D00;
  ; INC.B $09                                                          ;049597|E609    |001019; note that for displaying the name, you take the main text bitplane
  ; INY #2                                                             ;049599|C8      |      ; but also overwrite the text's shadowing bitplane (2bpp -> 1bpp) on
  ; TYX                                                                ;04959B|BB      |      ; subsequent writes (the final write copies an extraneous shadow byte)
  ; CPY.W #$0020                                                       ;04959C|C02000  |      ;
  ; BMI LOOP_top_row_04958C                                            ;04959F|30EB    |04958C;
  ; LDX.W #$0200                                                       ;0495A1|A20002  |      ; now copy the bottom two tile rows of the character's data into the space
; LOOP_bottom_row_0495A4:
  ; LDA.L $7F0000,X                                                    ;0495A4|BF00007F|7F0000;
  ; TXY                                                                ;0495A8|9B      |      ;
  ; LDX.B $09                                                          ;0495A9|A609    |001019;
  ; STA.L BUFFER_decompressed_name_entry_font_1bpp_data,X              ;0495AB|9F002D7F|7F2D00;
  ; INC.B $09                                                          ;0495AF|E609    |001019;
  ; INY #2                                                             ;0495B1|C8      |      ;
  ; TYX                                                                ;0495B3|BB      |      ;
  ; CPY.W #$0220                                                       ;0495B4|C02002  |      ;
  ; BNE LOOP_bottom_row_0495A4                                         ;0495B7|D0EB    |0495A4;

; set loop counter for # 16x16 tiles to process
    lda #$0000
    tax
    ldy.w #!WidthOfDecompressedNameFontIn16x16Tiles
; start with processing the TL TR tiles
  - txa
    jsr.w RemoveShadowingForOneTileRowInEnteredName
; advance a tile row down and 2 tile columns left (currently 2 tile cols right)
    clc : adc.w #$0200-$20
    jsr.w RemoveShadowingForOneTileRowInEnteredName
; advance a tile row up (currently 2 tile cols right and 1 tile row down)
    sec : sbc.w #$0200
    tax
    dey
    bne -
restore_regs_RTL_0495B9:
  ; REP #$30                                                           ;0495B9|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;0495BF|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

RemoveShadowingForOneTileRowInEnteredName:
; to reuse the loop, we can input the start offset, push end offset, and use a
; stack-relative CMP
    phy
    tax
    clc
    adc #$0020
    pha

  - lda.l !WramLocationForDecompressingNameFont,X
    txy
    ldx.b $09
    sta.l BUFFER_decompressed_name_entry_font_1bpp_data,X
    inc.b $09
    iny #2
    tyx
    tya
    cmp $01,s
    bmi -

; move the "clear extra shadow byte" here
; notice: subroutine exits two tiles to the right from position at routine start
    lda #$0000
    sta.l BUFFER_decompressed_name_entry_font_1bpp_data,X
    pla : ply
    rts

handle_pressing_B_in_char_grid_0495C0:
; print "Breakpoint for handling pressing B in char grid: $",hex(pc())
    PHP                                                                ;0495C0|08      |      ;
    REP #$30                                                           ;0495C1|C230    |      ;
    PHA : PHX : PHY
  ; JSL.L ctrl_flow_del_char_0495EE                                    ;0495C6|22EE9504|0495EE;
    JSR.W ctrl_flow_del_char_0495EE                                    ;0495C6|22EE9504|0495EE;

  ; LDA.B name_entry_name_length-$101D                                 ;0495CA|A507    |001024; check if length is 5 chars after deleting i.e. name was full
  ; CMP.W #$000A                                                       ;0495CC|C90A00  |      ;
;   cmp.w #!CharLimitForNameEntry-1

;   jsr.w CompareAgainstNameCharLimitForNameType
    lda.w menu_type_00_tooru_mari_02_killer
    and.w #$00ff
    bne +
    lda.b name_entry_name_length-$101d
    cmp.w #!CharLimitForNonKillerNameEntry-1
    bra ++
  + lda.b name_entry_name_length-$101d
    cmp.w #!CharLimitForKillerNameEntry-1
 ++ BNE restore_regs_RTL_0495E5                                        ;0495CF|D014    |0495E5; if no, skip down

    SEP #$30                                                           ;0495D1|E230    |      ;
    LDA.B name_entry_grid_curr_position-$101D                          ;0495D3|A503    |001020; if name was full before delete, check if on the 終り "finish" button
    CMP.B #$9C                                                         ;0495D5|C99C    |      ;
    BNE restore_regs_RTL_0495E5                                        ;0495D7|D00C    |0495E5;
    LDA.B #$12                                                         ;0495D9|A912    |      ; if yes, set the grid position to to the top left of the grid
    STA.B name_entry_grid_curr_position-$101D                          ;0495DB|8503    |001020;
  ; JSL.L get_sprite_pos_for_char_grid_pos_highlight_box_049250        ;0495DD|22509204|049250;
    JSR.W get_sprite_pos_for_char_grid_pos_highlight_box_049250
  ; JSL.L set_button_sprites_off_screen_flash_squares_on_screen_048CFC ;0495E1|22FC8C04|048CFC;
    JSR.W set_button_sprites_off_screen_flash_squares_on_screen_048CFC
restore_regs_RTL_0495E5:
  ; REP #$30                                                           ;0495E5|C230    |      ; why are there two of these REP #$30s?
  ; REP #$30                                                           ;0495E7|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;0495ED|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

press_A_on_delete_button_0493DD: ; see note
ctrl_flow_del_char_0495EE:
    PHP                                                                ;0495EE|08      |      ;
    REP #$30                                                           ;0495EF|C230    |      ;
    PHA : PHX : PHY

    LDX.B name_entry_name_length-$101D                                 ;0495F4|A607    |001024; go back one character if available
  ; DEX #2                                                             ;0495F6|CA      |      ;
  ; CPX.W #$FFFE                                                       ;0495F8|E0FEFF  |      ;
    dex
    cpx.w #$ffff
    BEQ restore_regs_RTL_049622                                        ;0495FB|F025    |049622; if entered name is empty, do nothing

    STX.B name_entry_name_length-$101D                                 ;0495FD|8607    |001024; otherwise, update current length of the entered name
  ; LDA.W LIST_text_XY_pos_for_name_entry_018A7C,X                     ;0495FF|BD7C8A  |018A7C; read a text X/Y position? X = 0x4F + L*0x10 ; Y = 0x17
    lda.w #!OffScreenForSprite
    STA.L sprite_pos_for_flashing_square_in_name                       ;049602|8F70187F|7F1870;

  ; LDA.W asterisk_01B12D                                              ;049606|AD2DB1  |01B12D; replace the deleted character with an asterisk
    SEP #$20                                                           ;049611|E220    |      ;
    LDA.W UnderscoreInNameEntryCharData
    STA.L name_in_name_entry_screen,X                                  ;049609|9FD0207F|7F20D0;

  ; JSL.L read_font_data_for_chars_in_entered_name_04948B              ;04960D|228B9404|04948B;
    JSR.W read_font_data_for_chars_in_entered_name_04948B
  ; SEP #$20                                                           ;049611|E220    |      ;
    LDA.B #$80                                                         ;049613|A980    |      ;
    TSB.B $0B                                                          ;049615|040B    |001028;
  ; REP #$20                                                           ;049617|C220    |      ;
  ; LDX.W #$0006                                                       ;049619|A20600  |      ; draw black box for "finish"
  ; JSL.L write_two_tile_ID_columns_for_list_X_at_01884E_048660        ;04961C|22608604|048660;
    ldx.w #!TwoColumnFinishBlackBox
    jsr.w write_two_tile_ID_columns_for_list_X_at_01884E_048660
    BRK #$18                                                           ;049620|0018    |      ; play the "delete character" sound effect
restore_regs_RTL_049622:
  ; REP #$30                                                           ;049622|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;049628|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

; ------------------------------------------------------------------------------

; this next block of code comes after the "check killer guess" code and before the
; code for BRK #$1C; moving here to keep # ASM files down

; not used, so cut out
; UNREACHED_clear_1bpp_char_grid_gfx_data_04978A:
    ; PHP                                                                ;04978A|08      |      ;
    ; REP #$30                                                           ;04978B|C230    |      ;
    ; PHA                                                                ;04978D|48      |      ;
    ; PHX                                                                ;04978E|DA      |      ;
    ; LDX.W #$0FFE                                                       ;04978F|A2FE0F  |      ;
    ; LDA.W #$0000                                                       ;049792|A90000  |      ;
  ; - STA.L BUFFER_1bpp_char_grid_gfx_on_screen,X                        ;049795|9F20027F|7F0220;
    ; DEX                                                                ;049799|CA      |      ;
    ; DEX                                                                ;04979A|CA      |      ;
    ; BPL -                                                              ;04979B|10F8    |049795;
    ; PLX                                                                ;04979D|FA      |      ;
    ; PLA                                                                ;04979E|68      |      ;
    ; PLP                                                                ;04979F|28      |      ;
    ; RTL                                                                ;0497A0|6B      |      ;

read_gfx_data_for_N_chars_in_grid_0497A1:
    PHP                                                                ;0497A1|08      |      ; input: two bytes in $00-$01, one byte in $02, one byte in $03
    REP #$30                                                           ;0497A2|C230    |      ;
    PHA : PHX : PHY : PHB
    PEA.W $7F00                                                        ;0497A8|F4007F  |017F00;
    PLB                                                                ;0497AB|AB      |      ;
    PLB                                                                ;0497AC|AB      |      ;
    LDX.B $00                                                          ;0497AD|A600    |001009; $00 = 2-byte offset in lookup table in data from $5E8000 decompressed output
    LDA.B $02                                                          ;0497AF|A502    |00100B; $02 = target tile # to write to, $03 = # characters that must be printed
    BRL loop_entry_point_0497F6                                        ;0497B1|824200  |0497F6;

LOOP_copy_font_data_for_chars_that_must_be_on_screen_0497B4:
    PHA                                                                ;0497B4|48      |      ; contents: [$02 $03 $00 $01]
    PHX                                                                ;0497B5|DA      |      ;
    AND.W #$00FF                                                       ;0497B6|29FF00  |      ; push (# chars printed so far) << 1
    ASL A                                                              ;0497B9|0A      |      ;
    PHA                                                                ;0497BA|48      |      ;
    AND.W #$00F0                                                       ;0497BB|29F000  |      ; skip down as many tile rows as needed (chars are 2x2 tiles)
    CLC                                                                ;0497BE|18      |      ;
    ADC.B $01,S                                                        ;0497BF|6301    |000001;
    PLY                                                                ;0497C1|7A      |      ; (discard pushed value)
    ASL #3                                                             ;0497C2|0A      |      ; Y <- # tiles to skip, in units of bytes
  ; ASL A                                                              ;0497C3|0A      |      ; in other words, use # tiles to skip to calculate where in WRAM to write font data
  ; ASL A                                                              ;0497C4|0A      |      ;
    TAY                                                                ;0497C5|A8      |      ;
    LDA.W BUFFER_decompressed_name_entry_font_offset_lookup_table,X    ;0497C6|BD0022  |7F2200;
    TAX                                                                ;0497C9|AA      |      ;
    LDA.W #$0003                                                       ;0497CA|A90300  |      ; run loop a total of 4 times
LOOP_convert_font_data_for_one_char_0497CD:
    PHA                                                                ;0497CD|48      |      ;
    LDA.W BUFFER_decompressed_name_entry_font_1bpp_data,X              ;0497CE|BD002D  |7F2D00; read two rows for top left tile
    STA.W BUFFER_1bpp_char_grid_gfx_on_screen,Y                        ;0497D1|992002  |7F0220;
    LDA.W BUFFER_decompressed_name_entry_font_1bpp_data+$08,X          ;0497D4|BD082D  |7F2D08; two rows of top right tile
    STA.W BUFFER_1bpp_char_grid_gfx_on_screen+$08,Y                    ;0497D7|992802  |7F0228;
    LDA.W BUFFER_decompressed_name_entry_font_1bpp_data+$10,X          ;0497DA|BD102D  |7F2D10; two rows of bottom left tile
    STA.W BUFFER_1bpp_char_grid_gfx_on_screen+$80,Y                    ;0497DD|99A002  |7F02A0;
    LDA.W BUFFER_decompressed_name_entry_font_1bpp_data+$18,X          ;0497E0|BD182D  |7F2D18; two rows of bottom right tile
    STA.W BUFFER_1bpp_char_grid_gfx_on_screen+$88,Y                    ;0497E3|99A802  |7F02A8;
    INX #2                                                             ;0497E6|E8      |      ; advance down two rows in src and dest ptrs
    INY #2                                                             ;0497E8|C8      |      ;
    PLA                                                                ;0497EA|68      |      ; check loop counter
    DEC A                                                              ;0497EB|3A      |      ;
    BPL LOOP_convert_font_data_for_one_char_0497CD                     ;0497EC|10DF    |0497CD;
    PLX                                                                ;0497EE|FA      |      ;
    INX #2                                                             ;0497EF|E8      |      ;
    PLA                                                                ;0497F1|68      |      ;
    CLC                                                                ;0497F2|18      |      ; take value in $02 and essentially do INC $02 DEC $03
    ADC.W #$FF01                                                       ;0497F3|6901FF  |      ; purpose: "$02" = # chars printed, "$03" = # chars left to print
loop_entry_point_0497F6:
    BIT.W #$FF00                                                       ;0497F6|8900FF  |      ; check "$03" = # chars left to print
    BNE LOOP_copy_font_data_for_chars_that_must_be_on_screen_0497B4    ;0497F9|D0B9    |0497B4;
    PLB                                                                ;0497FB|AB      |      ;
  ; REP #$30                                                           ;0497FC|C230    |      ;
  ; PLY : PLX : PLA : PLP
; this subroutine is only accessed in current bank, so replace with RTS
  ; RTL                                                                ;049802|6B      |      ;
  ; RTS
    jmp.w pull_YXAP_rts

; not used, so cut out
; UNUSED_SUB_049803:
    ; PHP                                                                ;049803|08      |      ;
    ; SEP #$20                                                           ;049804|E220    |      ;
    ; LDA.B #$81                                                         ;049806|A981    |      ; enable V-Blank NMI and auto joypad read
    ; STA.W NMITIMEN                                                     ;049808|8D0042  |014200;
    ; REP #$30                                                           ;04980B|C230    |      ;
    ; BRK #$03                                                           ;04980D|0003    |      ; check for A being pressed
    ; dw $0080                                                           ;04980F|        |      ;
    ; BRK #$00                                                           ;049811|0000    |      ;
    ; dw $0001                                                           ;049813|        |      ;
    ; LDA.W prev_contr1_input_state_0391                                 ;049815|AD9103  |000391;
    ; AND.W #$0080                                                       ;049818|298000  |      ;
    ; BNE UNUSED_check_killer_guess_for_opportunity_3_04981F             ;04981B|D002    |04981F; if A is not pressed, do nothing
    ; PLP                                                                ;04981D|28      |      ;
    ; RTL                                                                ;04981E|6B      |      ;
; UNUSED_check_killer_guess_for_opportunity_3_04981F:
    ; LDA.W #$0004                                                       ;04981F|A90400  |      ; if A is pressed, check entered name for killer in context of third opportunity
    ; JSL.L check_entered_guess_for_killer_049629                        ;049822|22299604|049629;
    ; PLP                                                                ;049826|28      |      ;
    ; RTL                                                                ;049827|6B      |      ;
