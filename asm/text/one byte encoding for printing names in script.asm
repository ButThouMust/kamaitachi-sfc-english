includefrom "MAIN insert text.asm"
; assume that this code comes after the code for "improving linebreaking.asm"

; ------------------

GetCharacterValueInNameBufferAndCheckIfFF:
    lda.w buffer_for_name_1656,x
CheckIfCharacterValueIsFF:
    and.w #$00ff
    cmp.w #$00ff
    rts

; change the code for printing a name to the buffer when reading normal text;
; since I don't want to have to repoint any of the five control codes, this ASM
; hack must fit (and does fit) exactly in the original space
org $0098cf
TOORU_101A_0098CF:
    LDY.W #$0000
copy_name_into_script_buffer_0098D2:
; $009996 does not alter the value of Y (it sets current buffer position as
; the next buffer position to write character data to)
  ; PHY
    JSR.W $9996
  ; PLY

; read the 0xC bytes of a name into buffer at $1656
    BRK #$1C
    db $14

    LDX.W #$0000
  - LDA.W buffer_for_name_1656,X
  ; BMI got_to_end_of_name_0098EE
    jsr.w CheckIfCharacterValueIsFF
    beq +

    STA.B $0D   ; set as decompressed character
  ; JSR.W write_char_to_text_buffer_at_0500_009B46
    jsr.w UseEncodingToCalculateXPosAndWriteToBuffer
  ; INX #2
    inx
    CPX.W #$000C
    BNE -
  + JSR.W $999D
    RTS

assert pc() <= $0098f2

; MARI_101C_0098F2:
    ; LDY.W #$0002
    ; BRA copy_name_into_script_buffer_0098D2
; CULPRIT_GUESS_101D_0098F7:
    ; LDY.W #$0004
    ; BRA copy_name_into_script_buffer_0098D2
; CULPRIT_GUESS_101E_0098FC:
    ; LDY.W #$0006
    ; BRA copy_name_into_script_buffer_0098D2
; CULPRIT_GUESS_101F_009901:
    ; LDY.W #$0008
    ; BRA copy_name_into_script_buffer_0098D2
; assert pc() == $009906

; --------------------

; change the code for printing a name to the buffer when reading previous text
; and when printing names (only Mari's in JP game, but still) on chapter list
org $009f86
    LDX.W #$0000
; - LDA.W buffer_for_name_1656,X
;   BMI +
  - jsr.w GetCharacterValueInNameBufferAndCheckIfFF
    BEQ +
  ; JSR.W $9B44
    jsr SetValueAsDecompressedEncodingBeforeCalculatingXPosAndWritingToBuffer
  ; INX #2
    inx
    CPX #$000C
    BNE -
  + CLC
    RTS

; --------------------

; update code for printing names for the file management prompts
FLAG_for_doing_text_DMA_15E2 = $15E2
text_x_pos_for_drawing_names_on_file_prompts_01871B = $01871B

org $02a812
draw_font_data_for_names_in_VRAM_for_file_prompts_02A812:
    PHP : PHD : PHB
    PEA.W $0101
    PLB : PLB

; the original code doesn't use how the direct page gets set to the name buffer
    LDA.W #buffer_for_name_1656
    TCD

    LDA.W #$0001
    STA.W FLAG_for_doing_text_DMA_15E2
    STZ.W TextXPos
    LDY.W #$0000
    JSR.W draw_font_data_for_name_Y_and_return_width_02A843
    STA.W $1618

    LDY.W #$0002
    JSR.W draw_font_data_for_name_Y_and_return_width_02A843
    ORA.W $1619
    STA.W $1619

    STZ.W FLAG_for_doing_text_DMA_15E2
    PLB : PLD : PLP
    RTL

draw_font_data_for_name_Y_and_return_width_02A843:
    PHP : PHX
; copy name from scratchpad save file into RAM
    BRK #$1C
    db $14

; in VRAM, draw Tooru's name at X pos 00, Mari's at X pos 0x80
    SEP #$20
    LDA.W text_x_pos_for_drawing_names_on_file_prompts_01871B,Y
    STA.W TextXPos

; use M=1 (8-bit A) and the new direct page
  ; REP #$20
    LDX.W #$0000
    lda.b #$00
    xba

; - LDA.W buffer_for_name_1656,X
;   CMP.W #$FFFF
  - lda.b $00,x
    cmp.b #$ff
    BEQ +
  ; JSL.L read_font_data_and_do_DMA_to_VRAM_make_room_on_DP_00A381
    jsl.l ReadFontDataDoTextDma
    INX
  ; INX
    CPX.W #$000C
    BNE -

  + REP #$20
    LDA.W TextXPos
    AND.W #$007F
    PLX : PLP
    RTS

assert pc() <= $02a871
