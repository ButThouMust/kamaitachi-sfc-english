includefrom "MAIN insert text.asm"

; ------------------------------------------------------------------------------

text_xy_tile_pos = $15E0
text_y_pos = $15E7

generate_BG3_tilemap_for_game_text_008C11 = $008C11
copy_BG3_text_tilemap_from_7F3800_into_VRAM_7C00_009FF5 = $009FF5
clear_font_data_for_WAIT_icon_00A033 = $00A033
read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A = $00A36A
store_x_y_tile_pos_to_15E0_00A3FE = $00A3FE

LIST_frame_counter_to_switch_fake_choice_palettes_0183D0 = $0183D0
VALUE_000C_0183F4 = $0183F4

; text locations for these change, so have to read from other points in ROM
; where the control flow isn't modified
; A_choice = $01AC41
; C_choice = $01AC45
; cursor_icon_char_value = $01AC53

!A_choice = read2($0097f2)
!C_choice = read2($0097f2)+4
!cursor_icon_char_value = read2($00a48b)

!LineBreakHeight = $14
!ChoiceTextXPos = $20

; fake_choice_text_1_01AC77 = $01AC77

text_BG3_tilemap_buffer = $7F3800

; ------------------------------------------------------------------------------

org $00a540
highlight_fake_choice_text_00A540:
     PHD                                                                ;00A540|0B      |      ;
     COP #$00                                                           ;00A541|0200    |      ;
     db $01                                                             ;00A543|        |      ;
     PHP                                                                ;00A544|08      |      ;
     REP #$30                                                           ;00A545|C230    |      ;
     PHA                                                                ;00A547|48      |      ;
     PHX                                                                ;00A548|DA      |      ;
     PHY                                                                ;00A549|5A      |      ;
     AND.W #$00FF                                                       ;00A54A|29FF00  |      ; $00 <- Y tile position of first option
     LSR A                                                              ;00A54D|4A      |      ;
     LSR A                                                              ;00A54E|4A      |      ;
     LSR A                                                              ;00A54F|4A      |      ;
     STA.B $00                                                          ;00A550|8500    |001021;
     LDA.B $05,S                                                        ;00A552|A305    |000005; A <- Y tile position of line below curr. option
     CLC                                                                ;00A554|18      |      ;
   ; ADC.W #$0017                                                       ;00A555|691700  |      ;
     ADC.W #!LineBreakHeight*2
     AND.W #$00FF                                                       ;00A558|29FF00  |      ;
   ; LSR A                                                              ;00A55B|4A      |      ;
   ; LSR A                                                              ;00A55C|4A      |      ;
   ; LSR A                                                              ;00A55D|4A      |      ;
     BRA got_Y_tile_pos_of_curr_option_00A589                           ;00A55E|8029    |00A589;

; UNUSED_PLD_00A560:
     ; db $2B                                                             ;00A560|        |      ;
pushpc
org $00a467
    jsr highlight_text_for_current_choice_option_00A561
pullpc

highlight_text_for_current_choice_option_00A561:
     PHD                                                                ;00A561|0B      |      ;
     COP #$00                                                           ;00A562|0200    |      ;
     db $01                                                             ;00A564|        |      ;
     PHP                                                                ;00A565|08      |      ;
     REP #$30                                                           ;00A566|C230    |      ;
     PHA                                                                ;00A568|48      |      ;
     PHX                                                                ;00A569|DA      |      ;
     PHY                                                                ;00A56A|5A      |      ;
     SEP #$10                                                           ;00A56B|E210    |      ;
     LDA.W $0426,X                                                      ;00A56D|BD2604  |010426; $00 <- Y tile pos of first option
     LSR A                                                              ;00A570|4A      |      ;
     LSR A                                                              ;00A571|4A      |      ;
     LSR A                                                              ;00A572|4A      |      ;
     STA.B $00                                                          ;00A573|8500    |00102B;
   - INX                                                                ;00A575|E8      |      ;
     INX                                                                ;00A576|E8      |      ;
     CPX.W $0423                                                        ;00A577|EC2304  |010423;
     BCS failsafe_write_to_bottom_of_screen_00A586                      ;00A57A|B00A    |00A586;
     LDA.W $0426,X                                                      ;00A57C|BD2604  |010426;
     BMI -                                                              ;00A57F|30F4    |00A575;
   ; LSR A                                                              ;00A581|4A      |      ;
   ; LSR A                                                              ;00A582|4A      |      ;
   ; LSR A                                                              ;00A583|4A      |      ;
     BRA got_Y_tile_pos_of_curr_option_00A589                           ;00A584|8003    |00A589;
failsafe_write_to_bottom_of_screen_00A586:
   ; LDA.W #$001B                                                       ;00A586|A91B00  |      ;
     LDA.W #($001C-1)<<3

got_Y_tile_pos_of_curr_option_00A589:
; reuse the three LSRs between all branches to here; save 3 bytes
     LSR #3

     REP #$10                                                           ;00A589|C210    |      ;
     TAY                                                                ;00A58B|A8      |      ; Y reg <- Y tile pos of line below current option
     XBA                                                                ;00A58C|EB      |      ; X <- Y tile pos * 0x40 = a tilemap pos
     LSR A                                                              ;00A58D|4A      |      ;
     LSR A                                                              ;00A58E|4A      |      ;
     TAX                                                                ;00A58F|AA      |      ;
LOOP_highlight_tile_rows_for_choice_text_00A590:
     DEX                                                                ;00A590|CA      |      ;
     DEX                                                                ;00A591|CA      |      ;
     TXA                                                                ;00A592|8A      |      ;
     AND.W #$003F                                                       ;00A593|293F00  |      ; isolate out relative position in tile row
     CMP.W #$0002                                                       ;00A596|C90200  |      ; do not change palette for the cursor; it should stay white
     BNE +                                                              ;00A599|D004    |00A59F;
     DEX                                                                ;00A59B|CA      |      ;
     DEX                                                                ;00A59C|CA      |      ;
     BRA LOOP_highlight_tile_rows_for_choice_text_00A590                ;00A59D|80F1    |00A590;
   + CMP.W #$003E                                                       ;00A59F|C93E00  |      ; check if done with highlighting one tile row
     BNE set_palette_1_for_tilemap_entry_00A5A9                         ;00A5A2|D005    |00A5A9;
     DEY                                                                ;00A5A4|88      |      ; if yes, check if done with highlighting all tile rows we need to
     CPY.B $00                                                          ;00A5A5|C400    |00102B;
     BCC restore_regs_RTS_00A5B6                                        ;00A5A7|900D    |00A5B6;
set_palette_1_for_tilemap_entry_00A5A9:
     LDA.L text_BG3_tilemap_buffer,X                                    ;00A5A9|BF00387F|7F3800;
     ORA.W #$0400                                                       ;00A5AD|090004  |      ; value 0400 corresponds to palette 1 in a tilemap entry
     STA.L text_BG3_tilemap_buffer,X                                    ;00A5B0|9F00387F|7F3800;
     BRA LOOP_highlight_tile_rows_for_choice_text_00A590                ;00A5B4|80DA    |00A590;
restore_regs_RTS_00A5B6:
     REP #$30                                                           ;00A5B6|C230    |      ;
     PLY : PLX : PLA : PLP : PLD
     RTS                                                                ;00A5BD|60      |      ;

pushpc
org $0090ea
    jsl do_fake_choice_code_in_spy_route_00A5BE
pullpc
do_fake_choice_code_in_spy_route_00A5BE:
     PHD                                                                ;00A5BE|0B      |      ;
     COP #$00                                                           ;00A5BF|0200    |      ;
     db $09                                                             ;00A5C1|        |      ;
     PHP                                                                ;00A5C2|08      |      ;
     REP #$30                                                           ;00A5C3|C230    |      ;
     LDX.W #$0000                                                       ;00A5C5|A20000  |      ;
   ; LDY.W #$0000                                                       ;00A5C8|A00000  |      ;
     TXY
LOOP_print_fake_choices_A_and_B_00A5CB:
; only need to get 1 byte at $15E7
; we can save a byte by replacing the AND #$00FF with STZ $07,X
   ; LDA.W text_y_pos                                                   ;00A5CB|ADE715  |0115E7;
   ; AND.W #$00FF                                                       ;00A5CE|29FF00  |      ;
   ; STA.B $06,X                                                        ;00A5D1|9506    |001029;
   ; SEP #$20                                                           ;00A5D3|E220    |      ;
     SEP #$20
     LDA.W text_y_pos        
     STA.B $06,X
     STZ.B $07,X

     LDA.B #$10                                                         ;00A5D5|A910    |      ; text X pos <- 0x10
     STA.W TextXPos                                                     ;00A5D7|8DE615  |0115E6;
     REP #$20                                                           ;00A5DA|C220    |      ;
   ; LDA.W A_choice,X                                                   ;00A5DC|BD41AC  |01AC41; print choice letter A on first loop, then choice letter B
     LDA.W !A_choice,X
     JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A5DF|206AA3  |00A36A;
     LDA.B $06,X                                                        ;00A5E2|B506    |001029; print appropriate text for choice option
     JSR.W print_text_for_fake_choice_option_00A6DD                     ;00A5E4|20DDA6  |00A6DD;
     INX                                                                ;00A5E7|E8      |      ;
     INX                                                                ;00A5E8|E8      |      ;
     CPX.W #$0004                                                       ;00A5E9|E00400  |      ;
     BNE LOOP_print_fake_choices_A_and_B_00A5CB                         ;00A5EC|D0DD    |00A5CB;
     LDY.W #$00E3                                                       ;00A5EE|A0E300  |      ;
; push the distance to go down after choices A/B
     PEA.W !LineBreakHeight*2
   ; LDA.W #!LineBreakHeight*2
   ; PHA
start_countdown_timer_for_fake_choice_flipping_00A5F1:
     LDX.W #$0000                                                       ;00A5F1|A20000  |      ;
     LDA.B $06                                                          ;00A5F4|A506    |001029; $06 has Y pos of first choice option
LOOP_00A5F6:
     STA.B $04                                                          ;00A5F6|8504    |001027; $04 <- Y pos of a choice option, one or the other
     JSR.W highlight_fake_choice_text_00A540                            ;00A5F8|2040A5  |00A540;
     JSL.L copy_BG3_text_tilemap_from_7F3800_into_VRAM_7C00_009FF5      ;00A5FB|22F59F00|009FF5;
     JSR.W generate_BG3_tilemap_for_game_text_008C11                    ;00A5FF|20118C  |008C11;
     JSR.W draw_cursor_and_keep_it_there_until_palette_switch_00A60F    ;00A602|200FA6  |00A60F;
     LDA.B $06                                                          ;00A605|A506    |001029;
     CMP.B $04                                                          ;00A607|C504    |001027;
     BNE +                                                              ;00A609|D002    |00A60D;
     LDA.B $08                                                          ;00A60B|A508    |00102B; $08 has Y pos of second choice option
   + BRA LOOP_00A5F6                                                    ;00A60D|80E7    |00A5F6;

draw_cursor_and_keep_it_there_until_palette_switch_00A60F:
     JSR.W draw_cursor_at_X_pos_7_and_Y_pos_in_DP_04_00A66E             ;00A60F|206EA6  |00A66E;
     JSR.W elapse_frames_until_need_to_switch_choice_palette_00A6A8     ;00A612|20A8A6  |00A6A8; get frame # of when to switch palettes
     BEQ case_end_of_gag_00A628                                         ;00A615|F011    |00A628;
     BCS case_0xF_frames_left_in_gag_00A61D                             ;00A617|B004    |00A61D;
     JSR.W clear_cursor_icon_to_left_of_highlighted_fake_choice_00A67E  ;00A619|207EA6  |00A67E;
     RTS                                                                ;00A61C|60      |      ;
case_0xF_frames_left_in_gag_00A61D:
     JSR.W clear_cursor_icon_to_left_of_highlighted_fake_choice_00A67E  ;00A61D|207EA6  |00A67E;
     JSR.W elapse_frames_until_need_to_switch_choice_palette_00A6A8     ;00A620|20A8A6  |00A6A8;
     BEQ case_end_of_gag_00A628                                         ;00A623|F003    |00A628;
     BCS draw_cursor_and_keep_it_there_until_palette_switch_00A60F      ;00A625|B0E8    |00A60F;
     RTS                                                                ;00A627|60      |      ;
case_end_of_gag_00A628:
     JSR.W clear_cursor_icon_to_left_of_highlighted_fake_choice_00A67E  ;00A628|207EA6  |00A67E;
     JSL.L copy_BG3_text_tilemap_from_7F3800_into_VRAM_7C00_009FF5      ;00A62B|22F59F00|009FF5;

; add stack value = the distance to go down after the choice
; pull return address, pull distance down, restore return address
; not a pretty solution, but it exactly fits into the original space
   ; LDA.B $08                                                          ;00A62F|A508    |00102B; go down a line and set text X to 0xD
   ; CLC                                                                ;00A631|18      |      ;
   ; ADC.W #$0017                                                       ;00A632|691700  |      ;
     PLX
     PLA
     PHX
     CLC : ADC $08

     XBA                                                                ;00A635|EB      |      ;
     ORA.W #$000D                                                       ;00A636|090D00  |      ;
     STA.W TextXPos                                                     ;00A639|8DE615  |0115E6;
     PLA                                                                ;00A63C|68      |      ;
     PLP                                                                ;00A63D|28      |      ;
     PLD                                                                ;00A63E|2B      |      ;
     RTL                                                                ;00A63F|6B      |      ;

pushpc
org $0090ef
    jsl do_fake_choice_option_C_in_spy_route_00A640
pullpc
do_fake_choice_option_C_in_spy_route_00A640:
     PHD                                                                ;00A640|0B      |      ;
     COP #$00                                                           ;00A641|0200    |      ;
     db $09                                                             ;00A643|        |      ;
     PHP                                                                ;00A644|08      |      ;
     REP #$30                                                           ;00A645|C230    |      ;
     LDA.W text_y_pos                                                   ;00A647|ADE715  |0115E7; store current text Y pos to both $06 and $08 to reuse code
     AND.W #$00FF                                                       ;00A64A|29FF00  |      ;
     STA.B $06                                                          ;00A64D|8506    |001029;
     STA.B $08                                                          ;00A64F|8508    |00102B;
     SEP #$20                                                           ;00A651|E220    |      ;
     LDA.B #$10                                                         ;00A653|A910    |      ; text X pos <- 0x10
     STA.W TextXPos                                                     ;00A655|8DE615  |0115E6;
     REP #$20                                                           ;00A658|C220    |      ;
   ; LDA.W C_choice                                                     ;00A65A|AD45AC  |01AC45; print the choice letter C
     LDA.W !C_choice
     JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A65D|206AA3  |00A36A;
   ; LDY.W #$0046                                                       ;00A660|A04600  |      ; note: 0x46 is relative offset of 3rd option from ptr to 1st option
     LDY.w #(!FakeChoiceTextBlock3Start-!FakeChoiceTextStartInFile)
     LDA.B $06                                                          ;00A663|A506    |001029;
     JSR.W print_text_for_fake_choice_option_00A6DD                     ;00A665|20DDA6  |00A6DD;
     LDY.W #$0001                                                       ;00A668|A00100  |      ; this flashes the choice pink for a split second, and "selects" it
; push the distance to go down after choice C
     PEA.W !LineBreakHeight
   ; LDA.W #!LineBreakHeight
   ; PHA
     BRA start_countdown_timer_for_fake_choice_flipping_00A5F1
; UNUSED_PLD_00A66D:
     ; db $2B                                                             ;00A66D|        |      ;

draw_cursor_at_X_pos_7_and_Y_pos_in_DP_04_00A66E:
     LDA.B $04                                                          ;00A66E|A504    |001027;
     XBA                                                                ;00A670|EB      |      ;
     ORA.W #$0007                                                       ;00A671|090700  |      ;
     STA.W TextXPos                                                     ;00A674|8DE615  |0115E6;
   ; LDA.W cursor_icon_char_value                                       ;00A677|AD53AC  |01AC53;
     LDA.W !cursor_icon_char_value
     JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A67A|206AA3  |00A36A;
     RTS                                                                ;00A67D|60      |      ;

clear_cursor_icon_to_left_of_highlighted_fake_choice_00A67E:
     PHD                                                                ;00A67E|0B      |      ;
     COP #$01                                                           ;00A67F|0201    |      ;
     db $21,$02                                                         ;00A681|        |      ;
     LDA.B $07                                                          ;00A683|A507    |001027; set Y position from (what used to be) $04
     XBA                                                                ;00A685|EB      |      ;
     ORA.W #$0007                                                       ;00A686|090700  |      ; set X position to 7
     STA.W TextXPos                                                     ;00A689|8DE615  |0115E6;
   ; LDA.W cursor_icon_char_value                                       ;00A68C|AD53AC  |01AC53; clear the cursor icon
     LDA.W !cursor_icon_char_value
     JSL.L clear_font_data_for_WAIT_icon_00A033                         ;00A68F|2233A000|00A033;
     JSR.W store_x_y_tile_pos_to_15E0_00A3FE                            ;00A693|20FEA3  |00A3FE;
     LDA.W text_xy_tile_pos                                             ;00A696|ADE015  |0115E0;
     STA.B $01                                                          ;00A699|8501    |001021;
     PHX                                                                ;00A69B|DA      |      ;
     LDX.W #$0000                                                       ;00A69C|A20000  |      ; perform a DMA to VRAM for specifically the text layer
     BRK #$15                                                           ;00A69F|0015    |      ;
     BRK #$00                                                           ;00A6A1|0000    |      ;
     db $01,$00                                                         ;00A6A3|        |      ;
     PLX                                                                ;00A6A5|FA      |      ;
     PLD                                                                ;00A6A6|2B      |      ;
     RTS                                                                ;00A6A7|60      |      ;

elapse_frames_until_need_to_switch_choice_palette_00A6A8:
     PHY                                                                ;00A6A8|5A      |      ; push current value of Y (counting down from 0xE3)
LOOP_skip_to_next_frame_00A6A9:
     BRK #$00                                                           ;00A6A9|0000    |      ;
     db $01,$00                                                         ;00A6AB|        |      ;
     TYA                                                                ;00A6AD|98      |      ; calculate (original frame ctr) - (current frame ctr) - 1
     EOR.W #$FFFF                                                       ;00A6AE|49FFFF  |      ;
     CLC                                                                ;00A6B1|18      |      ;
     ADC.B $01,S                                                        ;00A6B2|6301    |000001;
     CMP.W #$000F                                                       ;00A6B4|C90F00  |      ; if this result is 0xF or if Y is 0, set that as Y
     BEQ put_Y_value_in_A_and_return_00A6D8                             ;00A6B7|F01F    |00A6D8; note that if result is 0xF, carry flag gets set and is used in ctrl flow
     DEY                                                                ;00A6B9|88      |      ; indicate for next iteration that one frame has elapsed
     BEQ put_Y_value_in_A_and_return_00A6D8                             ;00A6BA|F01C    |00A6D8;
     PHY                                                                ;00A6BC|5A      |      ;
     LDA.W VALUE_000C_0183F4                                            ;00A6BD|ADF483  |0183F4; if under 0xC frames left, we are done
     CMP.B $01,S                                                        ;00A6C0|C301    |000001;
     BCC +                                                              ;00A6C2|9002    |00A6C6;
     BRA got_to_frame_to_switch_choice_highlight_00A6D6                 ;00A6C4|8010    |00A6D6;
   + LDX.W #$0026                                                       ;00A6C6|A22600  |      ; why does the code start on the two bytes right after the list?
LOOP_check_if_on_frame_to_switch_palettes_00A6C9:
     LDA.W LIST_frame_counter_to_switch_fake_choice_palettes_0183D0,X   ;00A6C9|BDD083  |0183D0;
     CMP.B $01,S                                                        ;00A6CC|C301    |000001;
     BEQ got_to_frame_to_switch_choice_highlight_00A6D6                 ;00A6CE|F006    |00A6D6;
     DEX                                                                ;00A6D0|CA      |      ; why only decrement list offset by 1 if entries are 2 bytes?
     BPL LOOP_check_if_on_frame_to_switch_palettes_00A6C9               ;00A6D1|10F6    |00A6C9;
     PLY                                                                ;00A6D3|7A      |      ;
     BRA LOOP_skip_to_next_frame_00A6A9                                 ;00A6D4|80D3    |00A6A9;
got_to_frame_to_switch_choice_highlight_00A6D6:
     PLY                                                                ;00A6D6|7A      |      ;
     CLC                                                                ;00A6D7|18      |      ;
put_Y_value_in_A_and_return_00A6D8:
     TYA                                                                ;00A6D8|98      |      ;
     STA.B $01,S                                                        ;00A6D9|8301    |000001;
     PLY                                                                ;00A6DB|7A      |      ;
     RTS                                                                ;00A6DC|60      |      ;

; improvement: use 1-byte encoding instead of 2-byte encoding
print_text_for_fake_choice_option_00A6DD:
     XBA                                                                ;00A6DD|EB      |      ; value in A is text Y position
     ORA.W #!ChoiceTextXPos                                             ;00A6DE|092000  |      ; set both the Y position, and an X position of 0x20 in one go
     STA.W TextXPos                                                     ;00A6E1|8DE615  |0115E6;
LOOP_get_font_data_for_fake_choice_text_00A6E4:
; add code for 1-byte encoding, and to allow line breaks in choice options' text
; assume that if subroutine returns with C flag set, got end of string
   ; LDA.W fake_choice_text_1_01AC77,Y                                  ;00A6E4|B977AC  |01AC77; keep reading this text and printing to screen until FFFF terminator
   ; BMI end_of_fake_choice_code_00A6F0                                 ;00A6E7|3007    |00A6F0;
   ; INY #2                                                             ;00A6E9|C8      |      ;
   ; JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A6EB|206AA3  |00A36A;
   ; BRA LOOP_get_font_data_for_fake_choice_text_00A6E4                 ;00A6EE|80F4    |00A6E4;
     LDA.W NewFakeChoiceText,Y
     iny
     and.w #$00ff   ; you can fit the AND/CMP here with one byte to spare
     cmp.w #$00fe
     jsr ProcessTextByteForFakeChoice
     bcc LOOP_get_font_data_for_fake_choice_text_00A6E4
; end_of_fake_choice_code_00A6F0:
     LDA.W #$001E                                                       ;00A6F0|A91E00  |      ; wait about 30 frames?
   - DEC A                                                              ;00A6F3|3A      |      ;
     BRK #$00                                                           ;00A6F4|0000    |      ;
     dw $0001                                                           ;00A6F6|        |      ;
     BNE -                                                              ;00A6F8|D0F9    |00A6F3;
     LDA.W text_y_pos                                                   ;00A6FA|ADE715  |0115E7; do line break after choice text
     CLC                                                                ;00A6FD|18      |      ;
   ; ADC.W #$0017                                                       ;00A6FE|691700  |      ;
     ADC.W #!LineBreakHeight
     STA.W text_y_pos                                                   ;00A701|8DE715  |0115E7;
; don't need to advance past (now) FF terminator since we always advance past
; the most recent byte of text
   ; INY #2                                                             ;00A704|C8      |      ; advance text offset past the FFFF terminator
     RTS                                                                ;00A706|60      |      ;

assert pc() <= $00a707
    fillbyte $ff
    fill $00a707-pc()

; ------------------------------------------------------------------------------

org $00ffb0-$18
ProcessTextByteForFakeChoice:
; check two things in one go: FE = line break, FF = end string
    beq GotLineBreakForFakeChoice
    bcc GotCharForFakeChoice
; FF will set C flag in the CMP, so can use this to indicate end of string;
; neither printing a character or doing a line break seem to set C flag here
    rts
GotCharForFakeChoice:
    jmp read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A
GotLineBreakForFakeChoice:
    lda $15e6           ; A <- Y pos << 8 -- discard X pos
    and #$ff00
    clc                 ; add 0x14 to Y pos, set X pos to 0x20
;   adc #$1420
    adc.w #((!LineBreakHeight<<8)|!ChoiceTextXPos)
    sta $15e6
    rts
