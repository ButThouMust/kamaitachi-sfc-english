includefrom "MAIN insert text.asm"

handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8 = $00a2b8
see_what_text_X_pos_would_be_after_adding_char_width_00A308 = $00a308
check_if_punctuation_1_if_left_0_if_other_FFFF_if_not_00A33C = $00a33c
; read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A = $00a36a

WAIT_100D_and_nominally_101C_00AD2F = $00ad2f
LINE_100E_00AC02 = $00ac02

!TextRightMargin = $00f8 ; originally F4

; FLAGS_in_dialogue = $0406

; ------------------------------------------------------------------------------

; jump table @ $00a905 is for code that can be optimized down by 0x12 bytes

org $00a905
    dw HandleTextNotInChoiceOrDialogue
    dw JslToHandleCtrlCode
    dw HandleCtrlCodeIfInChoice
    dw HandleCtrlCodeIfInChoice

HandleTextNotInChoiceOrDialogue:
    lda $00
    cmp #$1015
    beq RTS_00A918
; reused code in question
JslToHandleCtrlCode:
    jsl $00a0b5
RTS_00A918:
    rts

HandleCtrlCodeIfInChoice:
    cmp #$100d
    beq RTS_00A918
    bra JslToHandleCtrlCode

; fill in unused space with FF bytes
EmptySpaceBefore00A932:
assert pc() < $00a932
    fillbyte $ff
    fill $00a932-pc()

; ------------------------------------------------------------------------------

!do_00A0E7_typical_case = $00
!do_00A11F_past_E3_before_F4 = $02
!do_00A197_after_WAIT_past_E3_before_F4 = $04
!do_00A208_char_after_left_punctuation = $06
!do_00A272_after_WAIT_before_E3 = $08

org $00a0dd
JUMP_TABLE_00A0DD:
     dw do_typical_printing_logic_00A0E7
     dw check_value_before_hard_right_margin_of_F4_00A11F
     dw got_WAIT_when_text_X_pos_greater_than_0xE3_00A197
     dw check_linebreak_with_char_after_left_punctuation_00A208
     dw handle_encoding_value_after_WAIT_00A272

; ------------------------------------------------------------------------------

; for X=0

do_typical_printing_logic_00A0E7:
     CMP.W #$100D                                                       ;00A0E7|C90D10  |      ; check WAIT
     BEQ case_100D_return_08_00A0F7                                     ;00A0EA|F00B    |00A0F7;
     CMP.W #$1000                                                       ;00A0EC|C90010  |      ; check if character
     BCC case_got_char_check_linebreaking_00A0FA                        ;00A0EF|9009    |00A0FA;
case_handle_ctrl_code_00A0F1:
     JSR.W handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8               ;00A0F1|20B8A2  |00A2B8; if ctrl code, handle it and return to call $00A0E7 next time
     LDX.B #!do_00A0E7_typical_case                                     ;00A0F4|A200    |      ;
     RTS                                                                ;00A0F6|60      |      ;

case_100D_return_08_00A0F7:
     LDX.B #!do_00A272_after_WAIT_before_E3                             ;00A0F7|A208    |      ; if WAIT, return to call $00A272 next time
     RTS                                                                ;00A0F9|60      |      ;

case_got_char_check_linebreaking_00A0FA:
     LDX.B #!do_00A0E7_typical_case                                     ;00A0FA|A200    |      ; check for passing text right margin of 0xE3
     LDA.B $00                                                          ;00A0FC|A500    |00102D; if not passed, return 0x00 (call $00A0E7 next time)
     JSR.W see_what_text_X_pos_would_be_after_adding_char_width_00A308  ;00A0FE|2008A3  |00A308;
     CPY.B #$E3                                                         ;00A101|C0E3    |      ;
     BCC +                                                              ;00A103|9002    |00A107;
     LDX.B #!do_00A11F_past_E3_before_F4                                ;00A105|A202    |      ; if passed margin, prepare for more linebreaking logic
   + LDA.B $00                                                          ;00A107|A500    |00102D; call $00A36A with character value
     JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A109|206AA3  |00A36A;
     RTS                                                                ;00A10C|60      |      ;

; UNREACHED_CODE_to_handle_space_char_00A10D:
   ; CLC                                                                ;00A10D|18      |      ; Y <- 8 + text X pos
   ; LDA.W #$0008                                                       ;00A10E|A90800  |      ; perhaps note that the space character is considered to be 8 pixels wide
   ; ADC.W TextXPos                                                     ;00A111|6DE615  |0115E6; however, this is already handled in the existing case for text
   ; TAY                                                                ;00A114|A8      |      ; consider overwriting this space with English linebreaking logic?
   ; CPY.B #$E3                                                         ;00A115|C0E3    |      ; if this is 0xE3 or greater, set X to 0x2 (call $00A11F next time)
   ; BCC +                                                              ;00A117|9002    |00A11B; if not, keep whatever value was in it when this code was called
   ; LDX.B #!do_00A11F_past_E3_before_F4                                ;00A119|A202    |      ;
 ; + STY.W TextXPos                                                     ;00A11B|8CE615  |0115E6; set Y as new text X position
   ; RTS                                                                ;00A11E|60      |      ;

; ------------------------------------------------------------------------------

; for X=2

check_value_before_hard_right_margin_of_F4_00A11F:
     STA.B $00                                                          ;00A11F|8500    |00102D;
     CMP.W #$100D                                                       ;00A126|C90D10  |      ; check WAIT
     BEQ case_wait_100D_00A147                                          ;00A129|F01C    |00A147;

     CMP.W #$100E                                                       ;00A121|C90E10  |      ; check LINE; got moved down tog group together
     BEQ case_LINE_or_SET_X_or_SET_Y_00A141                             ;00A124|F01B    |00A141;
     CMP.W #$1019                                                       ;00A12B|C91910  |      ; check SET X POS
     BEQ case_LINE_or_SET_X_or_SET_Y_00A141                             ;00A12E|F011    |00A141;
     CMP.W #$101A                                                       ;00A130|C91A10  |      ; check SET Y POS
     BEQ case_LINE_or_SET_X_or_SET_Y_00A141                             ;00A133|F00C    |00A141;

     CMP.W #$1025                                                       ;00A135|C92510  |      ; check CLEAR
     BEQ case_clear_1025_00A185                                         ;00A138|F04B    |00A185;

     CMP.W #$1000                                                       ;00A13A|C90010  |      ; check if character
     BCC case_got_char_00A14A                                           ;00A13D|900B    |00A14A;
     BRA +                                                              ;00A13F|8002    |00A143; any other control code; handle it, use #$02 for next iteration
case_LINE_or_SET_X_or_SET_Y_00A141:
     LDX.B #!do_00A0E7_typical_case                                     ;00A141|A200    |      ; got LINE, or SET X/Y POS codes
   + JSR.W handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8               ;00A143|20B8A2  |00A2B8;
     RTS                                                                ;00A146|60      |      ;

case_wait_100D_00A147:
     LDX.B #!do_00A197_after_WAIT_past_E3_before_F4                     ;00A147|A204    |      ;
     RTS                                                                ;00A149|60      |      ;

case_got_char_00A14A:
     LDA.B $00                                                          ;00A14A|A500    |00102D;
     JSR.W check_if_punctuation_1_if_left_0_if_other_FFFF_if_not_00A33C ;00A14C|203CA3  |00A33C;
     LDA.B $04                                                          ;00A14F|A504    |001031;
     BEQ case_got_period_comma_right_punct_00A16F                       ;00A151|F01C    |00A16F; 0 = got period, comma, right quotes
     BPL case_got_left_punctuation_00A17E                               ;00A153|1029    |00A17E; 1 = got left punctuation, left quotes
     ; BRA case_got_general_character_00A15D                            ;00A155|8006    |00A15D; FFFF = anything else

; cut out unused code
; UNREACHED_CODE_call_LINE_and_return_00_00A157:
     ; JSR.W LINE_100E_00AC02                                           ;00A157|2002AC  |00AC02;
     ; LDX.B #!do_00A0E7_typical_case                                   ;00A15A|A200    |      ;
     ; RTS                                                              ;00A15C|60      |      ;

case_got_general_character_00A15D:
     JSR.W see_what_text_X_pos_would_be_after_adding_char_width_00A308  ;00A15D|2008A3  |00A308; check if new text X position is 0xF4 or greater (12 pixel margin)
   ; CPY.B #$F4                                                         ;00A160|C0F4    |      ;
   ; BCC case_char_before_F4_right_margin_00A189                        ;00A162|9025    |00A189;
     cpy.b #!TextRightMargin
     BCS case_char_after_F4_right_margin_00A164

; moved up to reuse code
case_char_before_F4_right_margin_00A189:
     LDX.B #!do_00A11F_past_E3_before_F4                                ;00A18E|A202    |      ;
     bra +

case_char_after_F4_right_margin_00A164:
     LDX.B #!do_00A0E7_typical_case                                     ;00A164|A200    |      ; note: suggested that if you want new linebreaking logic, insert it here
     JSR.W LINE_100E_00AC02                                             ;00A166|2002AC  |00AC02; do a line break, and then print the character on the new line
   + LDA.B $00                                                          ;00A169|A500    |00102D;
     JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A16B|206AA3  |00A36A;
     RTS                                                                ;00A16E|60      |      ;

; move this label down to reuse code
; case_got_period_comma_right_punct_00A16F:
   ; LDA.B $00                                                          ;00A16F|A500    |00102D;
   ; JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A171|206AA3  |00A36A;
   ; SEP #$20                                                           ;00A174|E220    |      ;
   ; LDA.B #$F6                                                         ;00A176|A9F6    |      ; set the new X position to 0xF6 if got period, comma, right punctuation
   ; STA.W TextXPos                                                     ;00A178|8DE615  |0115E6;
   ; REP #$20                                                           ;00A17B|C220    |      ;
 ; + RTS                                                                ;00A17D|60      |      ;

case_got_left_punctuation_00A17E:
     LDX.B #!do_00A208_char_after_left_punctuation                      ;00A17E|A206    |      ; signal to run $00A208 next
     LDA.B $00                                                          ;00A180|A500    |00102D;
     STA.B $06                                                          ;00A182|8506    |001033;
     RTS                                                                ;00A184|60      |      ;

; case_clear_1025_00A185:
   ; JSR.W handle_ctrl_code_and_return_0_in_X_reg_00A191                ;00A185|2091A1  |00A191;
   ; RTS                                                                ;00A188|60      |      ;

; case_char_before_F4_right_margin_00A189:
   ; LDA.B $00                                                          ;00A189|A500    |00102D; if character is not past right margin, just print it at current X pos
   ; JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A18B|206AA3  |00A36A;
   ; LDX.B #!do_00A11F_past_E3_before_F4                                ;00A18E|A202    |      ;
   ; RTS                                                                ;00A190|60      |      ;

case_clear_1025_00A185: ; see above
case_1025_1026_00A1C3: ; see below
handle_ctrl_code_and_return_0_in_X_reg_00A191:
     JSR.W handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8               ;00A191|20B8A2  |00A2B8;
     LDX.B #!do_00A0E7_typical_case                                     ;00A194|A200    |      ;
     RTS                                                                ;00A196|60      |      ;

; ------------------------------------------------------------------------------

; for X=4

got_WAIT_when_text_X_pos_greater_than_0xE3_00A197:
     CMP.W #$100D                                                       ;00A197|C90D10  |      ; check WAIT
     BEQ case_100D_RTS_00A1C2                                           ;00A19A|F026    |00A1C2;

     CMP.W #$100E                                                       ;00A19C|C90E10  |      ; check LINE, SET X POS, SET Y POS
     BEQ case_100E_1019_101A_00A1C7                                     ;00A19F|F026    |00A1C7;
     CMP.W #$1019                                                       ;00A1A1|C91910  |      ;
     BEQ case_100E_1019_101A_00A1C7                                     ;00A1A4|F021    |00A1C7;
     CMP.W #$101A                                                       ;00A1A6|C91A10  |      ;
     BEQ case_100E_1019_101A_00A1C7                                     ;00A1A9|F01C    |00A1C7;

     CMP.W #$1025                                                       ;00A1AB|C92510  |      ; check CLEAR
     BEQ case_1025_1026_00A1C3                                          ;00A1AE|F013    |00A1C3;
     CMP.W #$1026                                                       ;00A1B0|C92610  |      ; check whatever this code is
     BEQ case_1025_1026_00A1C3                                          ;00A1B3|F00E    |00A1C3;

     CMP.W #$1000                                                       ;00A1B5|C90010  |      ; check if character
     BCC case_got_char_00A1D0                                           ;00A1B8|9016    |00A1D0;
case_general_ctrl_code_00A1BA:
     JSR.W WAIT_100D_and_nominally_101C_00AD2F                          ;00A1BA|202FAD  |00AD2F;
     JSR.W handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8               ;00A1BD|20B8A2  |00A2B8;
     LDX.B #!do_00A11F_past_E3_before_F4                                ;00A1C0|A202    |      ;
case_100D_RTS_00A1C2:
     RTS                                                                ;00A1C2|60      |      ;

; case_1025_1026_00A1C3:
     ; JSR.W handle_ctrl_code_and_return_0_in_X_reg_00A191                ;00A1C3|2091A1  |00A191;
     ; RTS                                                                ;00A1C6|60      |      ;

case_100E_1019_101A_00A1C7:
     JSR.W handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8               ;00A1C7|20B8A2  |00A2B8;
     JSR.W WAIT_100D_and_nominally_101C_00AD2F                          ;00A1CA|202FAD  |00AD2F;
     LDX.B #!do_00A0E7_typical_case                                     ;00A1CD|A200    |      ;
     RTS                                                                ;00A1CF|60      |      ;

case_got_char_00A1D0:
     LDA.B $00                                                          ;00A1D0|A500    |00102D;
     JSR.W check_if_punctuation_1_if_left_0_if_other_FFFF_if_not_00A33C ;00A1D2|203CA3  |00A33C;
     LDA.B $04                                                          ;00A1D5|A504    |001031;
     BEQ case_comma_period_right_punc_00A1E4                            ;00A1D7|F00B    |00A1E4;
     BPL case_left_punctuation_do_line_break_before_printing_00A201     ;00A1D9|1026    |00A201;
case_general_character_00A1DB:
     LDA.B $00                                                          ;00A1DB|A500    |00102D;
     JSR.W see_what_text_X_pos_would_be_after_adding_char_width_00A308  ;00A1DD|2008A3  |00A308;
   ; CPY.B #$F4                                                         ;00A1E0|C0F4    |      ;
     cpy.b #!TextRightMargin
     BCS case_left_punctuation_do_line_break_before_printing_00A201     ;00A1E2|B01D    |00A201;
case_comma_period_right_punc_00A1E4:
     LDX.B #!do_00A11F_past_E3_before_F4                                ;00A1E4|A202    |      ;
     JSR.W WAIT_100D_and_nominally_101C_00AD2F                          ;00A1E6|202FAD  |00AD2F;

; moved label down; see note from above
case_got_period_comma_right_punct_00A16F:
     LDA.B $00                                                          ;00A1E9|A500    |00102D;
     JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A1EB|206AA3  |00A36A;

; the three punctuation pairs ?" !" ." (all right punctuation) are common enough
; that this "X pos <- 0xF6 after right punctuation" can just inexplicably put
; the right quote on the far right of the screen away from the ? ! or .
; this prominently appears with line "Tonight, at midnight, someone will die."

; I initially considered doing a check to only do this if currently in dialogue,
; but you'd need to look at $03C1 to know whether to check $0406 (current text)
; or $123B (previous text); I then found that cutting out the code altogether
; seems to be a valid option
   ; SEP #$20                                                           ;00A1EE|E220    |      ;
   ; LDA.B #$F6                                                         ;00A1F0|A9F6    |      ;
   ; STA.W TextXPos                                                     ;00A1F2|8DE615  |0115E6;
   ; REP #$20                                                           ;00A1F5|C220    |      ;
     RTS                                                                ;00A1F7|60      |      ;

case_left_punctuation_do_line_break_before_printing_00A201:
     LDX.B #!do_00A0E7_typical_case                                     ;00A201|A200    |      ;
     JSR.W LINE_100E_00AC02                                             ;00A203|2002AC  |00AC02;
   ; BRA CODE_00A1F8                                                    ;00A206|80F0    |00A1F8;
; this code block originally came before the case, which is the only way to
; access it; move down to cut out the BRA
; CODE_00A1F8:
     JSR.W WAIT_100D_and_nominally_101C_00AD2F                          ;00A1F8|202FAD  |00AD2F;
     LDA.B $00                                                          ;00A1FB|A500    |00102D;
     JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A1FD|206AA3  |00A36A;
     RTS                                                                ;00A200|60      |      ;

; ------------------------------------------------------------------------------

; for X=6

check_linebreak_with_char_after_left_punctuation_00A208:
     CMP.W #$1025                                                       ;00A208|C92510  |      ; check CLEAR and WAIT -- wait for player input
     BEQ case_1025_100D_00A264                                          ;00A20B|F057    |00A264;
     CMP.W #$100D                                                       ;00A20D|C90D10  |      ;
     BEQ case_1025_100D_00A264                                          ;00A210|F052    |00A264;

     CMP.W #$100E                                                       ;00A212|C90E10  |      ; check LINE and SET X/Y POS
     BEQ case_100E_1019_101A_00A251                                     ;00A215|F03A    |00A251;
     CMP.W #$1019                                                       ;00A217|C91910  |      ;
     BEQ case_100E_1019_101A_00A251                                     ;00A21A|F035    |00A251;
     CMP.W #$101A                                                       ;00A21C|C91A10  |      ;
     BEQ case_100E_1019_101A_00A251                                     ;00A21F|F030    |00A251;

     CMP.W #$1000                                                       ;00A221|C90010  |      ; check for any other control codes
     BCS case_general_ctrl_code_00A25E                                  ;00A224|B038    |00A25E;
case_got_char_00A226:
     LDY.W TextXPos                                                     ;00A226|ACE615  |0115E6; keep current X pos on stack
     PHY                                                                ;00A229|5A      |      ;
     LDA.B $00                                                          ;00A22A|A500    |00102D; get X pos after writing the two characters
     JSR.W see_what_text_X_pos_would_be_after_adding_char_width_00A308  ;00A22C|2008A3  |00A308;
     STY.W TextXPos                                                     ;00A22F|8CE615  |0115E6;
     LDA.B $06                                                          ;00A232|A506    |001033;
     JSR.W see_what_text_X_pos_would_be_after_adding_char_width_00A308  ;00A234|2008A3  |00A308;
   ; CPY.B #$F4                                                         ;00A237|C0F4    |      ; check if past right margin of 0xF4 pixels
     cpy.b #!TextRightMargin
     PLY                                                                ;00A239|7A      |      ;
     STY.W TextXPos                                                     ;00A23A|8CE615  |0115E6;
     LDX.B #!do_00A11F_past_E3_before_F4                                ;00A23D|A202    |      ;
     BCC +                                                              ;00A23F|9005    |00A246;
     LDX.B #!do_00A0E7_typical_case                                     ;00A241|A200    |      ; if yes, do a line break and resume normal printing
     JSR.W LINE_100E_00AC02                                             ;00A243|2002AC  |00AC02;
   + LDA.B $06                                                          ;00A246|A506    |001033; draw the two characters to the screen
     JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A248|206AA3  |00A36A;
     LDA.B $00                                                          ;00A24B|A500    |00102D;
     JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A24D|206AA3  |00A36A;
     RTS                                                                ;00A250|60      |      ;

case_100E_1019_101A_00A251:
     PHA                                                                ;00A251|48      |      ; got LINE or SET X/Y POS after left punctuation
     LDA.B $06                                                          ;00A252|A506    |001033; draw the character now
     JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A254|206AA3  |00A36A;
     PLA                                                                ;00A257|68      |      ;
     JSR.W handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8               ;00A258|20B8A2  |00A2B8; print the left punctuation char
     LDX.B #!do_00A0E7_typical_case                                     ;00A25B|A200    |      ; resume normal printing
     RTS                                                                ;00A25D|60      |      ;

case_general_ctrl_code_00A25E:
     JSR.W handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8               ;00A25E|20B8A2  |00A2B8;
     LDX.B #!do_00A208_char_after_left_punctuation                      ;00A261|A206    |      ;
     RTS                                                                ;00A263|60      |      ;

case_1025_100D_00A264:
     LDX.B #!do_00A0E7_typical_case                                     ;00A264|A200    |      ;
     JSR.W LINE_100E_00AC02                                             ;00A266|2002AC  |00AC02;
     LDA.B $06                                                          ;00A269|A506    |001033;
     JSR.W read_font_data_and_elapse_frames_with_text_speed_ctrl_00A36A ;00A26B|206AA3  |00A36A;
     JSR.W handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8               ;00A26E|20B8A2  |00A2B8;
     RTS                                                                ;00A271|60      |      ;

; ------------------------------------------------------------------------------

; for X=8

handle_encoding_value_after_WAIT_00A272:
     CMP.W #$100D                                                       ;00A272|C90D10  |      ; if got another WAIT, do nothing
     BEQ RTS_for_WAIT_0D_00A29E                                         ;00A275|F027    |00A29E;

     CMP.W #$100E                                                       ;00A277|C90E10  |      ; check LINE and SET X/Y POS
     BEQ case_LINE_SET_X_SET_Y_00A29F                                   ;00A27A|F023    |00A29F;
     CMP.W #$1019                                                       ;00A27C|C91910  |      ;
     BEQ case_LINE_SET_X_SET_Y_00A29F                                   ;00A27F|F01E    |00A29F;
     CMP.W #$101A                                                       ;00A281|C91A10  |      ;
     BEQ case_LINE_SET_X_SET_Y_00A29F                                   ;00A284|F019    |00A29F;

     CMP.W #$1025                                                       ;00A286|C92510  |      ; check CLEAR
     BEQ case_code_25_26_00A2A8                                         ;00A289|F01D    |00A2A8;
     CMP.W #$1026                                                       ;00A28B|C92610  |      ; check whatever this code is
     BEQ case_code_25_26_00A2A8                                         ;00A28E|F018    |00A2A8;

     CMP.W #$1000                                                       ;00A290|C90010  |      ; check if character
     BCC case_got_character_00A2AE                                      ;00A293|9019    |00A2AE;
case_other_ctrl_code_00A295:
     JSR.W WAIT_100D_and_nominally_101C_00AD2F                          ;00A295|202FAD  |00AD2F; if other ctrl code, do a WAIT, handle ctrl code, and set to do $00A0E7 next
; see note below about moving this label up
case_code_25_26_00A2A8:
     JSR.W handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8               ;00A298|20B8A2  |00A2B8;
     LDX.B #!do_00A0E7_typical_case                                     ;00A29B|A200    |      ;
   ; RTS                                                                ;00A29D|60      |      ;
RTS_for_WAIT_0D_00A29E:
     RTS                                                                ;00A29E|60      |      ;

case_LINE_SET_X_SET_Y_00A29F:
     LDX.B #!do_00A0E7_typical_case                                     ;00A29F|A200    |      ; if line or set x/y pos, set to do $00A0E7 next time
     JSR.W handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8               ;00A2A1|20B8A2  |00A2B8; handle ctrl code, and WAIT
     JSR.W WAIT_100D_and_nominally_101C_00AD2F                          ;00A2A4|202FAD  |00AD2F;
     RTS                                                                ;00A2A7|60      |      ;

; is there a particular difference between doing [LDX #$02 ; JSR $A2B8] and
; [JSR $A2B8; LDX #$02]? if not, you can move this label up to $00A29B
; the JSR does preserve whatever value X has when it is called
; case_code_25_26_00A2A8:
     ; LDX.B #!do_00A0E7_typical_case                                     ;00A2A8|A200    |      ; if clear or code 26, set to do $00A0E7 next time
     ; JSR.W handle_ctrl_code_after_NEW_CHAPTER_code_00A2B8               ;00A2AA|20B8A2  |00A2B8;
     ; RTS                                                                ;00A2AD|60      |      ;

case_got_character_00A2AE:
     JSR.W WAIT_100D_and_nominally_101C_00AD2F                          ;00A2AE|202FAD  |00AD2F; got a character after the WAIT
   ; BRL case_got_char_check_linebreaking_00A0FA
     jmp.w case_got_char_check_linebreaking_00A0FA

assert pc() <= $00a2b4
    fillbyte $ff
    fill $00a2b4-pc()
