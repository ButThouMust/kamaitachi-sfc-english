includefrom "MAIN rewrite bank 04.asm"

!BytesPerChar = 1 ; originally 2
; !NameBufferSize = $000C

pushpc
org $008ef3
    jsl.l check_entered_guess_for_killer_049629
pullpc

!ListHeader = $FE

check_entered_guess_for_killer_049629:
; input value is in A = which "culprit guess" name slot to use
    phd
    cop #$00
    db $03
    php
    rep #$30
  ; pha
    phx : phy

; push input value
    pha

; this address contains the value 0x0039 = start of new list of options
; opting to convert this to just a plain immediate for the comparisons
  ; lda.w accepted_guesses_list
  ; sta $00

    jsr.w copy_entered_name_to_killer_guess_buffer_04975C
    jsr.w check_for_asterisks_in_killer_guess_04965B
  ; jsr.w check_for_trailing_honorific_in_guess_049691
    jsr.w determine_whose_name_was_entered_0496DF
    jsr.w get_name_to_print_for_killer_guess_ctrl_code_049726

; call this with input value in A
    lda.b $01,s
    jsr.w copy_culprit_guess_name_from_ram_to_scratchpad_save_049752

; call this with input value in A
    pla
    jsr.w get_which_branch_to_take_based_on_player_input_049778

    rep #$30
    ply : plx 
  ; pla
    plp
    lda $02
    pld
    rtl

; ------------------------------------------------------------------------------

; moved this up here for clarity
; one note, the limit is 0xA characters, but the buffer is 0xC bytes, so have to
; manually fill in the last two bytes with the FF terminator
copy_entered_name_to_killer_guess_buffer_04975C:
    lda.w #$ffff
  ; sta.w buffer_for_killer_guess_1662+!BytesPerChar*$A
    sta.w buffer_for_killer_guess_1662+!CharLimitForKillerNameEntry
    ldx.w #(!NameBufferSize-!BytesPerChar*4)
  - lda.w buffer_for_name_1656,X
    sta.w buffer_for_killer_guess_1662,X
    dex #!BytesPerChar*2
    bpl -
    rts

; ------------------------------------------------------------------------------

check_for_asterisks_in_killer_guess_04965B:
    ldy.w #$0000
    sep #$20
    bra entry_point_04966E

LOOP_049660:
    cmp.w buffer_for_name_1656,X      ; start at the end of the buffer and run $049677 if you get an asterisk
    bne +
    jsr.w got_asterisk_in_killer_guess_049677
  + dex #!BytesPerChar
    bpl LOOP_049660
    iny #!BytesPerChar*2                 ; advance pointer past the asterisk char and to an FFFF terminator
entry_point_04966E:
    ldx.w #(!NameBufferSize-!BytesPerChar)
  ; lda.w TEXT_asterisk_01ACCD,Y         ; this will either read an asterisk (start of loop) or FFFF (end of loop)
    lda.w UnderscoreForKillerGuesses,Y
    bpl LOOP_049660

    rep #$20
    rts

; --------------------

got_asterisk_in_killer_guess_049677:
    pha : phx
    bra entry_point_049681

LOOP_04967B:
    lda.w buffer_for_name_1656,X         ; copy one character back
    sta.w buffer_for_name_1656-$!BytesPerChar,X
entry_point_049681:
    inx #!BytesPerChar                   ; advance one character
    cpx.w #!NameBufferSize
    bne LOOP_04967B
  ; lda.w TEXT_asterisk_01ACCD           ; if at end of buffer, write an asterisk as last character
    lda.w UnderscoreForKillerGuesses
    sta.w buffer_for_name_1656+!NameBufferSize-!BytesPerChar
    plx : pla
    rts

; ------------------------------------------------------------------------------

; we do not need this for English, so we can save quite a lot of space for code
; check_for_trailing_honorific_in_guess_049691:
    ; ldy.w #$0000
    ; bra entry_point_get_1st_honorific_char_0496B2
; LOOP_check_next_honorific_049696:
    ; phy
    ; ldx.w #!BytesPerChar                 ; start looking for an honorific at the second letter in the entered name
; LOOP_check_next_position_in_entered_name_04969A:
    ; jsr.w check_if_entered_name_matches_honorific_0496BA
    ; lda.b $02; check how many characters match the honorific
    ; bmi PLA_RTS_0496B8
    ; inx #!BytesPerChar
    ; cpx.w #!NameBufferSize
    ; bne LOOP_check_next_position_in_entered_name_04969A
    ; ply
  ; - iny #!BytesPerChar                   ; advance to the FFFF after the honorific
    ; lda.w san_honorific,Y
    ; bpl -
    ; iny #!BytesPerChar                    ; advance past the FFFF
; entry_point_get_1st_honorific_char_0496B2:
    ; lda.w san_honorific,Y                ; read character for san honorific
    ; bpl LOOP_check_next_honorific_049696
    ; rts
; PLA_RTS_0496B8:
    ; pla
    ; rts

; --------------------

; check_if_entered_name_matches_honorific_0496BA:
    ; phx
    ; phy
    ; stz.b $02
; LOOP_0496BE:
    ; lda.w san_honorific,Y                ; compare a string from the list against the player's inputted guess
    ; bmi case_found_honorific_TRIM_0496D5 ; go one character at a time
    ; cpx.w #!NameBufferSize                     ; exit if at end of either list's string or of the inputted guess
    ; beq restore_regs_RTS_0496DC
    ; cmp.w buffer_for_name_1656,X      ; exit if corresponding characters do not match
    ; bne restore_regs_RTS_0496DC

    ; inc.b $02; this contains # matching characters, or FFFF if first so many characters match honorific
    ; inx #!BytesPerChar
    ; iny #!BytesPerChar
    ; bra LOOP_0496BE

; case_found_honorific_TRIM_0496D5:
    ; ply
    ; plx
    ; sta.w buffer_for_name_1656,X      ; set an FFFF terminator at the position where the honorific started
    ; sta.b $02
; restore_regs_RTS_0496DC:
    ; ply
    ; plx
    ; rts

; ------------------------------------------------------------------------------

determine_whose_name_was_entered_0496DF:
    ldy.w #$0000
; clear out # matching characters from checking honorifics
    stz.b $02
    sep #$20
    BRA loop_entry_point_0496ED

skip_to_next_name_after_no_match_0496E6:
    iny #!BytesPerChar
    lda.w NewAcceptedAnswersForKillerGuess,Y
; skip past name terminator
    cmp.b #$ff
    bne skip_to_next_name_after_no_match_0496E6

loop_entry_point_0496ED:
; lists of strings for matching input to a character name are prefixed with [39 00]
; skip past the list header and read a character
    iny #!BytesPerChar
    lda.w NewAcceptedAnswersForKillerGuess,Y
; $00 should have the value 0x0039 (see $049634) from $01ACFF
; check if at the start of a list -- consider changing the list header to some other value
  ; cmp.b $00
    cmp.b #!ListHeader
    beq case_got_to_next_list_0496F8  ; FE = go to next list
    bcs no_match_for_input_049702     ; FF = end of data, zero matches
case_check_input_against_name_0496FC: ; 00-FD = check if match
    jsr.w compare_input_against_one_option_SEC_if_match_049708
    bcc skip_to_next_name_after_no_match_0496E6
    rep #$20
    rts

case_got_to_next_list_0496F8:
; if at list start, increment which person's name we are looking at
    inc.b $02
    bra loop_entry_point_0496ED

no_match_for_input_049702:
; if entered name matches nothing at all, set this address as "false"
    rep #$20
    lda.w #$FFFF
    sta.b $02
    rts

; --------------------

compare_input_against_one_option_SEC_if_match_049708:
    phy
    ldx.w #$0000
LOOP_compare_entered_and_listed_names_04970C:
    lda.w NewAcceptedAnswersForKillerGuess,Y
    cmp.w buffer_for_name_1656,X
    bne case_no_match_for_this_entry_CLC_RTS_049723
    inx #!BytesPerChar
    iny #!BytesPerChar
; check if at end of list (A would be FFFF, inc to 0)
    inc
    beq case_got_match_for_name_SEC_RTS_049720
; another pass would be if all six chars in entered name match a name in the list
    cpx.w #!NameBufferSize
    bne LOOP_compare_entered_and_listed_names_04970C
case_got_match_for_name_SEC_RTS_049720:
    ply
    sec
    rts
case_no_match_for_this_entry_CLC_RTS_049723:
    ply
    clc
    rts

; ------------------------------------------------------------------------------

get_name_to_print_for_killer_guess_ctrl_code_049726:
; get # of lists to skip so we can get the right name to print
    ldx.b $02
  ; bmi case_entered_name_matches_nothing_04974F
    bmi entered_name_matches_no_person_04976A

    ldy.w #-!BytesPerChar
    sep #$20
LOOP_skip_to_list_we_want_04972D:
    iny #!BytesPerChar
; check if at the start of a list
; keep skipping characters until you get to the start of a list
    lda.w NewAcceptedAnswersForKillerGuess,Y
  ; cmp.w accepted_guesses_list     ; change to an immediate
    cmp.b #!ListHeader
    bne LOOP_skip_to_list_we_want_04972D
; at the start of a list, decrement # lists to skip
    dex
    bpl LOOP_skip_to_list_we_want_04972D

; now we are at the start of the list we want
    ldx.w #-!BytesPerChar
copy_canonical_name_for_guess_to_buffer_04973D:
    iny #!BytesPerChar
    inx #!BytesPerChar
; copy up to 6 characters or until an FFFF terminator, whichever comes first
    cpx.w #!NameBufferSize
    beq +
    lda.w NewAcceptedAnswersForKillerGuess,Y
    sta.w buffer_for_name_1656,X
    cmp.b #$ff
    bne copy_canonical_name_for_guess_to_buffer_04973D
  + rep #$20
    rts

; case_entered_name_matches_nothing_04974F:
    ; jmp entered_name_matches_no_person_04976A

entered_name_matches_no_person_04976A:
; simply copy the player's guess verbatim into buffer if it matches nothing
    ldx.w #(!NameBufferSize-!BytesPerChar*2)
  - lda.w buffer_for_killer_guess_1662,X
    sta.w buffer_for_name_1656,X
    dex #!BytesPerChar*2
    bpl -
    rts

; ------------------------------------------------------------------------------

copy_culprit_guess_name_from_ram_to_scratchpad_save_049752:
; input value is in A = "culprit guess" name slot
; add 4 to skip past slots for Tooru and Mari's names
    asl
    clc
    adc.w #$0004
    tay
    brk #$1C
    db $93
    rts

; ------------------------------------------------------------------------------

get_which_branch_to_take_based_on_player_input_049778:
; input value in A = which "culprit guess" name slot to use
    asl : tax

; get which table to use for "which story branch should we take with this name?"
; "no match" (FFFF) is reserved for first entry in table
    lda.w PTR_TABLE_to_what_branch_to_take_for_culprit_guess_018A88,X
    sec
    adc.b $02
    tax

; select the appropriate story branch value
; if you want to playtest paths, set a breakpoint after the LDA here
    lda.w $0000,X
print "Breakpoint for playtesting killer guesses: $",hex(pc())
    and #$00FF
    sta.b $02
    rts
