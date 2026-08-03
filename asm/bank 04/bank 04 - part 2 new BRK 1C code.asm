includefrom "MAIN rewrite bank 04.asm"

; update pointers for main BRK #$1C to "JSL" to, and all its helper code
pushpc
org $018333
    dl BRK_1C_at_049828-1
org $018ab5
JUMP_TABLE_for_BRK_1C_018AB5:
    dw BRK_1C_00_at_04985C-1, BRK_1C_01_at_0498CE-1, UNREACHED_BRK_1C_02_at_0498D4-1, BRK_1C_03_at_0498DA-1
    dw BRK_1C_04_at_0498F1-1, BRK_1C_05_at_0498F8-1, BRK_1C_06_at_04992D-1, BRK_1C_07_at_04995F-1
    dw BRK_1C_08_at_04998B-1, BRK_1C_09_at_04997F-1, BRK_1C_0A_at_049992-1, BRK_1C_0B_at_0499C7-1
    dw BRK_1C_0C_at_0499DB-1, BRK_1C_0D_at_049A4A-1, BRK_1C_0E_at_049B6D-1, BRK_1C_0F_at_049BA9-1
    dw BRK_1C_10_at_049BBB-1, BRK_1C_11_at_049BCD-1, BRK_1C_12_at_049BEB-1, BRK_1C_13_at_049C23-1
    dw BRK_1C_14_at_049C45-1, BRK_1C_15_at_049C3A-1, BRK_1C_16_at_049C59-1, BRK_1C_17_at_049C67-1
    dw BRK_1C_18_at_049C78-1, BRK_1C_19_at_049C91-1, BRK_1C_1A_at_049CA6-1, BRK_1C_1B_at_049CB6-1
    dw BRK_1C_1C_at_049CC8-1, BRK_1C_1D_at_049CD8-1, BRK_1C_1E_at_049CFD-1, BRK_1C_1F_at_049D22-1
    dw BRK_1C_20_at_049D64-1, BRK_1C_21_at_049D57-1, BRK_1C_22_at_049D41-1, BRK_1C_23_at_049D6E-1
    dw BRK_1C_24_at_049D7D-1, BRK_1C_25_at_049D8F-1, BRK_1C_26_at_049DA1-1, BRK_1C_27_at_049DAE-1
    dw BRK_1C_28_at_049DBE-1, BRK_1C_29_at_049DDD-1, BRK_1C_2A_at_049E19-1, BRK_1C_2B_at_049E20-1
    dw BRK_1C_2C_at_049E32-1, BRK_1C_2D_at_049E4F-1
pullpc

BRK_1C_at_049828:
    PHP                                                                ;049828|08      |      ;
    REP #$30                                                           ;049829|C230    |      ;
    PHA                                                                ;04982B|48      |      ; state: [D.low D.high Y.low Y.high X.low X.high A.low A.high P ret_addr.low ret_addr_high]
    PHX                                                                ;04982C|DA      |      ;
    PHY                                                                ;04982D|5A      |      ;
    PHD                                                                ;04982E|0B      |      ;
    TSC                                                                ;04982F|3B      |      ; direct page <- stack pointer
    TCD                                                                ;049830|5B      |      ;
    INC.B $0A                                                          ;049831|E60A    |0011F3; increment return address to after #$1C in BRK instruction
    LDA.B [$0A]                                                        ;049833|A70A    |0011F3; load byte after the #$1C
    AND.W #$00FF                                                       ;049835|29FF00  |      ;
    PLD                                                                ;049838|2B      |      ; restore direct page
    BIT.W $03c1                                                        ;049839|2CC103  |0103C1;
    BPL +                                                              ;04983C|1005    |049843;
    BIT.W #$0080                                                       ;04983E|898000  |      ;
    BNE pull_Y_X_A_P_RTL_049855                                        ;049841|D012    |049855;
  + AND.W #$007F                                                       ;049843|297F00  |      ; use byte after #$1C to index list at $018AB5
    ASL A                                                              ;049846|0A      |      ;
    TAX                                                                ;049847|AA      |      ;
    LDA.W JUMP_TABLE_for_BRK_1C_018AB5,X                               ;049848|BDB58A  |018AB5;
    PER pull_Y_X_A_P_RTL_049855-1                                      ;04984B|620600  |049854; push [54 98] and then the specified list value (where to RTS to)
    PHA                                                                ;04984E|48      |      ;
    LDA.B $07,S                                                        ;04984F|A307    |000007; load X and A values from stack
    TAX                                                                ;049851|AA      |      ;
    LDA.B $09,S                                                        ;049852|A309    |000009;
    RTS                                                                ;049854|60      |      ;
pull_Y_X_A_P_RTL_049855:
    REP #$30                                                           ;049855|C230    |      ; come back here after running specific code for BRK 1C [input]
    PLY                                                                ;049857|7A      |      ;
    PLX                                                                ;049858|FA      |      ;
    PLA                                                                ;049859|68      |      ;
    PLP                                                                ;04985A|28      |      ;
    RTL                                                                ;04985B|6B      |      ;

BRK_1C_00_at_04985C:
    STZ.W temp_copy_of_scratchpad_source_save_file                     ;04985C|9CE903  |0103E9; default this to 0 unless not scratchpad
    LDA.L SRAM_which_save_file_1_2_or_3                                ;04985F|AF780070|700078;
    AND.W #$00FF                                                       ;049863|29FF00  |      ;
    BEQ +                                                              ;049866|F008    |049870; if scratchpad save file, skip down
    CMP.W #$0004                                                       ;049868|C90400  |      ;
    BCS +                                                              ;04986B|B003    |049870; store save file # to memory if in range 1-3
    STA.W temp_copy_of_scratchpad_source_save_file                     ;04986D|8DE903  |0103E9;
  + LDA.W #$0003                                                       ;049870|A90300  |      ;
LOOP_check_save_file_checksums_delete_if_bad_049873:
    JSR.W update_save_file_checksums_049EC3                            ;049873|20C39E  |049EC3; check save file checksums; if carry CLEAR, no match
    BCC +                                                              ;049876|9005    |04987D;
    JSR.W check_for_06CD_at_offset_0C4_in_save_file_A_049E64           ;049878|20649E  |049E64; if checksums are good, check for this particular address
    BRA ++                                                             ;04987B|8003    |049880;
  + JSR.W delete_and_reinit_save_file_A_049E85                         ;04987D|20859E  |049E85; if checksums are bad, run this instead
 ++ DEC A                                                              ;049880|3A      |      ; repeat for all four save files
    BPL LOOP_check_save_file_checksums_delete_if_bad_049873            ;049881|10F0    |049873;
    LDA.L SRAM_which_save_file_1_2_or_3                                ;049883|AF780070|700078; get save file # for the scratchpad save file
    AND.W #$00FF                                                       ;049887|29FF00  |      ;
    BEQ +                                                              ;04988A|F00F    |04989B; if it is 0 (scratchpad save file deleted due to bad checksum), skip down
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;04988C|201F9F  |049F1F; otherwise, check if save file the scratchpad was sourced from was deleted
    LDA.L SRAM_which_save_file_1_2_or_3,X                              ;04988F|BF780070|700078;
    AND.W #$00FF                                                       ;049893|29FF00  |      ;
    BNE +                                                              ;049896|D003    |04989B;
    JSR.W copy_scratchpad_save_file_into_sourced_save_file_049F59      ;049898|20599F  |049F59; if save file that the scratchpad was sourced from was deleted, restore it
  + LDA.W $03DF                                                        ;04989B|ADDF03  |0103DF;
    BEQ CODE_delete_scratchpad_save_file_0498C4                        ;04989E|F024    |0498C4;
    LDA.W temp_copy_of_scratchpad_source_save_file                     ;0498A0|ADE903  |0103E9;
    BEQ CODE_delete_scratchpad_save_file_0498C4                        ;0498A3|F01F    |0498C4;
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;0498A5|201F9F  |049F1F;
    LDA.L SRAM_which_save_file_1_2_or_3,X                              ;0498A8|BF780070|700078;
    AND.W #$00FF                                                       ;0498AC|29FF00  |      ;
    BEQ CODE_delete_scratchpad_save_file_0498C4                        ;0498AF|F013    |0498C4;
    TAY                                                                ;0498B1|A8      |      ;
    JSR.W copy_save_file_proper_1st_0x78_bytes_into_scratchpad_049F30  ;0498B2|20309F  |049F30;
    LDA.W #$003E                                                       ;0498B5|A93E00  |      ; check progress flag 0x3E (if set, need to display secret message)
    BRK #$1C                                                           ;0498B8|001C    |      ;
    db $25                                                             ;0498BA|        |      ;
    BCC CODE_delete_scratchpad_save_file_0498C4                        ;0498BB|9007    |0498C4; if clear, delete the scratchpad save file
    TYA                                                                ;0498BD|98      |      ; otherwise, copy source save file into scratchpad
    JSR.W copy_save_file_proper_into_scratchpad_049F28                 ;0498BE|20289F  |049F28;
    JMP.W case_prog_flag_set_049E5C                                    ;0498C1|4C5C9E  |049E5C;
CODE_delete_scratchpad_save_file_0498C4:
    LDA.W #$0000                                                       ;0498C4|A90000  |      ;
    CLC                                                                ;0498C7|18      |      ;
    JSR.W delete_and_reinit_save_file_A_049E85                         ;0498C8|20859E  |049E85;
    JMP.W case_prog_flag_clear_049E54                                  ;0498CB|4C549E  |049E54;

BRK_1C_01_at_0498CE:
    AND.W #$0003                                                       ;0498CE|290300  |      ;
    JMP.W copy_save_file_proper_into_scratchpad_049F28                 ;0498D1|4C289F  |049F28;
UNREACHED_BRK_1C_02_at_0498D4:
    AND.W #$0003                                                       ;0498D4|290300  |      ;
    JMP.W copy_save_file_proper_1st_0x78_bytes_into_scratchpad_049F30  ;0498D7|4C309F  |049F30;

BRK_1C_03_at_0498DA:
    LDA.W #$0000                                                       ;0498DA|A90000  |      ;
    LDX.W $03C3                                                        ;0498DD|AEC303  |0103C3;
    BEQ +                                                              ;0498E0|F009    |0498EB;
    STZ.W $03C3                                                        ;0498E2|9CC303  |0103C3;
    JSR.W update_save_file_checksums_049EC3                            ;0498E5|20C39E  |049EC3; calc checksums for scratchpad save file
    JMP.W copy_scratchpad_save_file_into_sourced_save_file_049F59      ;0498E8|4C599F  |049F59;
  + JSR.W calc_checksum_for_save_file_metadata_049ECD                  ;0498EB|20CD9E  |049ECD; calc checksum for scratchpad save file metadata
    JMP.W copy_scratchpad_save_metadata_into_sourced_save_file_049F61  ;0498EE|4C619F  |049F61;

BRK_1C_04_at_0498F1:
    AND.W #$0003                                                       ;0498F1|290300  |      ;
    CLC                                                                ;0498F4|18      |      ;
    JMP.W delete_and_reinit_save_file_A_049E85                         ;0498F5|4C859E  |049E85;

BRK_1C_05_at_0498F8:
    JSR.W SUB_for_BRK_1C_05_04A197                                     ;0498F8|2097A1  |04A197;

; new: for new linebreaking hack, back up the calculated X position and buffer
; position of the most recently decompressed space
    lda.w CalculatedXPos
    sta.w BackUpOfCalculatedXPos
    lda.w BufferPosOfLastSpaceChar
    sta.w BackUpOfBufferPosOfLastSpaceChar

    LDX.W #$03FE                                                       ;0498FB|A2FE03  |      ; back up script into bank 7F
  - LDA.W script_text_buffer,X                                         ;0498FE|BD0005  |010500;
    STA.L backup_script_buffer_7F6000,X                                ;049901|9F00607F|7F6000;
    DEX #2                                                             ;049905|CA      |      ;
    BPL -                                                              ;049907|10F5    |0498FE;
    LDX.W #$002E                                                       ;049909|A22E00  |      ;
  - LDA.W block_containing_playthru_temp_flags_0B94,X                  ;04990C|BD940B  |010B94;
    STA.L $7F7000,X                                                    ;04990F|9F00707F|7F7000;
    DEX #2                                                             ;049913|CA      |      ;
    BPL -                                                              ;049915|10F5    |04990C;
    LDX.W #$0006                                                       ;049917|A20600  |      ;
  - LDA.L SRAM_file_progress_flags_SCRATCHPAD_ONLY,X                   ;04991A|BF180070|700018;
    STA.L $7F7100,X                                                    ;04991E|9F00717F|7F7100;
    DEX #2                                                             ;049922|CA      |      ;
    BPL -                                                              ;049924|10F4    |04991A;
    LDA.W #$8000                                                       ;049926|A90080  |      ;
    STA.W $03c1                                                        ;049929|8DC103  |0103C1;
    RTS                                                                ;04992C|60      |      ;

BRK_1C_06_at_04992D:
; new: for new linebreaking hack, restore the calculated X position and buffer
; position of the most recently decompressed space
    lda.w BackUpOfCalculatedXPos
    sta.w CalculatedXPos
    lda.w BackUpOfBufferPosOfLastSpaceChar
    sta.w BufferPosOfLastSpaceChar

    LDX.W #$03FE                                                       ;04992D|A2FE03  |      ;
  - LDA.L backup_script_buffer_7F6000,X                                ;049930|BF00607F|7F6000;
    STA.W script_text_buffer,X                                         ;049934|9D0005  |010500;
    DEX #2                                                             ;049937|CA      |      ;
    BPL -                                                              ;049939|10F5    |049930;
    LDX.W #$002E                                                       ;04993B|A22E00  |      ;
  - LDA.L $7F7000,X                                                    ;04993E|BF00707F|7F7000;
    STA.W block_containing_playthru_temp_flags_0B94,X                  ;049942|9D940B  |010B94;
    DEX #2                                                             ;049945|CA      |      ;
    BPL -                                                              ;049947|10F5    |04993E;
    LDX.W #$0006                                                       ;049949|A20600  |      ;
  - LDA.L $7F7100,X                                                    ;04994C|BF00717F|7F7100;
    STA.L SRAM_file_progress_flags_SCRATCHPAD_ONLY,X                   ;049950|9F180070|700018;
    DEX #2                                                             ;049954|CA      |      ;
    BPL -                                                              ;049956|10F4    |04994C;
    STZ.W $03c1                                                        ;049958|9CC103  |0103C1;
    BRK #$01                                                           ;04995B|0001    |      ;
    db $4A                                                             ;04995D|        |      ;
    RTS                                                                ;04995E|60      |      ;

BRK_1C_07_at_04995F:
    INC.W $03C3                                                        ;04995F|EEC303  |0103C3;
    SEP #$20                                                           ;049962|E220    |      ;
    LDA.L SRAM_curr_chapter_index_to_text_block_num_list               ;049964|AF060070|700006; use at most 0x28 entries in list at $700050
    CMP.B #$28                                                         ;049968|C928    |      ;
    BCC +                                                              ;04996A|9001    |04996D;
    DEC A                                                              ;04996C|3A      |      ;
  + STA.L SRAM_curr_chapter_index_to_text_block_num_list               ;04996D|8F060070|700006;
    REP #$20                                                           ;049971|C220    |      ;
    AND.W #$00FF                                                       ;049973|29FF00  |      ;
    JSR.W copy_prog_flags_from_scratchpad_to_src_save_file_04A14C      ;049976|204CA1  |04A14C;
    JSR.W increment_page_block_number_for_chapter_lookup_049FBC        ;049979|20BC9F  |049FBC;
    JMP.W write_curr_text_block_data_to_SRAM_and_init_new_block_049FD4 ;04997C|4CD49F  |049FD4;

BRK_1C_09_at_04997F:
    AND.W #$0003                                                       ;04997F|290300  |      ;
    PHD                                                                ;049982|0B      |      ;
    PEA.W $1235                                                        ;049983|F43512  |011235;
    PLD                                                                ;049986|2B      |      ;
    JSR.W copy_save_file_proper_1st_0x78_bytes_into_scratchpad_049F30  ;049987|20309F  |049F30;
    PLD                                                                ;04998A|2B      |      ;
BRK_1C_08_at_04998B:
    JSR.W get_chapter_number_to_print_on_screen_049F84                 ;04998B|20849F  |049F84;
    TXA                                                                ;04998E|8A      |      ;
    STA.B $07,S                                                        ;04998F|8307    |000007;
    RTS                                                                ;049991|60      |      ;

BRK_1C_0A_at_049992:
    LDX.W #$002E                                                       ;049992|A22E00  |      ;
  - LDA.W block_containing_playthru_temp_flags_0B94,X                  ;049995|BD940B  |010B94; copy 0x30 bytes of playthrough flags to scratchpad
    STA.L $700020,X                                                    ;049998|9F200070|700020;
    DEX #2                                                             ;04999C|CA      |      ;
    BPL -                                                              ;04999E|10F5    |049995;
    LDA.L SRAM_num_pages_in_curr_text_page_block                       ;0499A0|AF0F0070|70000F;
    AND.W #$00FF                                                       ;0499A4|29FF00  |      ; check if # pgs = 0xA or # pgs is in range 0x80-0xFF
    BIT.W #$0080                                                       ;0499A7|898000  |      ;
    BNE +                                                              ;0499AA|D005    |0499B1;
    CMP.W #$000A                                                       ;0499AC|C90A00  |      ;
    BNE ++                                                             ;0499AF|D010    |0499C1;
  + SEP #$20                                                           ;0499B1|E220    |      ;
    AND.B #$7F                                                         ;0499B3|297F    |      ;
    STA.L SRAM_num_pages_in_curr_text_page_block                       ;0499B5|8F0F0070|70000F;
    REP #$20                                                           ;0499B9|C220    |      ;
    JSR.W write_curr_text_block_data_to_SRAM_and_init_new_block_049FD4 ;0499BB|20D49F  |049FD4;
    INC.W $03C3                                                        ;0499BE|EEC303  |0103C3;
 ++ JSR.W copy_curr_pg_block_data_with_inc_pg_ctr_to_scratchpad_04A02E ;0499C1|202EA0  |04A02E;
    JMP.W BRK_1C_03_at_0498DA                                          ;0499C4|4CDA98  |0498DA; recalc checksum for save file and copy save file into scratchpad

BRK_1C_0B_at_0499C7:
    LDX.W #$002E                                                       ;0499C7|A22E00  |      ;
  - LDA.W block_containing_playthru_temp_flags_0B94,X                  ;0499CA|BD940B  |010B94;
    STA.L $700020,X                                                    ;0499CD|9F200070|700020;
    DEX #2                                                             ;0499D1|CA      |      ;
    BPL -                                                              ;0499D3|10F5    |0499CA;
    JSR.W copy_curr_text_page_block_data_from_RAM_to_scratchpad_04A021 ;0499D5|2021A0  |04A021;
    JMP.W BRK_1C_03_at_0498DA                                          ;0499D8|4CDA98  |0498DA;

BRK_1C_0C_at_0499DB:
    TAX                                                                ;0499DB|AA      |      ; input value is in A before the [00 1C 0C] bytes for BRK
    BPL case_set_current_chapter_0499EE                                ;0499DC|1010    |0499EE;
case_need_to_show_secret_message_ending_0499DE:
    LDX.W #$002E                                                       ;0499DE|A22E00  |      ; case if the input is negative (FFFF at $008AFE)
  - LDA.L $700020,X                                                    ;0499E1|BF200070|700020; copy these 0x30 bytes from scratchpad into memory
    STA.W block_containing_playthru_temp_flags_0B94,X                  ;0499E5|9D940B  |010B94;
    DEX #2                                                             ;0499E8|CA      |      ;
    BPL -                                                              ;0499EA|10F5    |0499E1;
    BRA CODE_049A24                                                    ;0499EC|8036    |049A24;
case_set_current_chapter_0499EE:
    STA.L SRAM_curr_chapter_index_to_text_block_num_list               ;0499EE|8F060070|700006;
    TAX                                                                ;0499F2|AA      |      ;
    LDA.L SRAM_LIST_text_page_block_num_for_each_chapter,X             ;0499F3|BF500070|700050;
    AND.W #$00FF                                                       ;0499F7|29FF00  |      ;
    STA.L SRAM_max_page_block_num_reached_overall                      ;0499FA|8F070070|700007;
    JSR.W get_X_index_for_text_page_block_num_in_input_04A05D          ;0499FE|205DA0  |04A05D;
    LDA.L SRAM_data_struct_for_text_page_block_temp_flags,X            ;049A01|BFD00270|7002D0;
    STA.L SRAM_data_for_curr_page_block                                ;049A05|8F080070|700008;
    LDA.L $7002D2,X                                                    ;049A09|BFD20270|7002D2;
    STA.L $70000A                                                      ;049A0D|8F0A0070|70000A;
    LDA.L SRAM_LIST_ptr_to_start_of_text_page_block,X                  ;049A11|BFD40270|7002D4;
    STA.L $70000C                                                      ;049A15|8F0C0070|70000C;
    LDA.L $7002D6,X                                                    ;049A19|BFD60270|7002D6;
    STA.L $70000E                                                      ;049A1D|8F0E0070|70000E;
    JSR.W copy_0x30_bytes_to_SRAM_020_and_update_perm_prog_flag_049A9D ;049A21|209D9A  |049A9D;
CODE_049A24:
    LDA.L SRAM_data_for_curr_page_block                                ;049A24|AF080070|700008;
    STA.W playthru_temp_flags                                          ;049A28|8DB10B  |010BB1;
    LDA.L $70000A                                                      ;049A2B|AF0A0070|70000A;
    STA.W $0BB3                                                        ;049A2F|8DB30B  |010BB3;
    LDA.L $70000C                                                      ;049A32|AF0C0070|70000C;
    STA.W huff_script_position_in_bytes                                ;049A36|8D0804  |010408;
    LDA.L $70000D                                                      ;049A39|AF0D0070|70000D;
    STA.W $0409                                                        ;049A3D|8D0904  |010409;
    STZ.W huff_buffer_contents                                         ;049A40|9C0B04  |01040B;
    LDA.W #$007D                                                       ;049A43|A97D00  |      ; clear progress flag 0x7D
    JSR.W BRK_1C_24_at_049D7D                                          ;049A46|207D9D  |049D7D;
    RTS                                                                ;049A49|60      |      ;

; ------------------------------------------------------------------------------

BRK_1C_0D_at_049A4A:
    LDA.W #$0000                                                       ;049A4A|A90000  |      ; set chapter number to 0
    SEP #$30                                                           ;049A4D|E230    |      ;
    STA.L SRAM_curr_chapter_index_to_text_block_num_list               ;049A4F|8F060070|700006;
    STA.L SRAM_max_page_block_num_reached_overall                      ;049A53|8F070070|700007; reset page block counters
    STA.L SRAM_num_pages_in_curr_text_page_block                       ;049A57|8F0F0070|70000F;
    REP #$30                                                           ;049A5B|C230    |      ;
    STA.L SRAM_data_for_curr_page_block                                ;049A5D|8F080070|700008;
    STA.L $70000A                                                      ;049A61|8F0A0070|70000A;
    STA.W playthru_temp_flags                                          ;049A65|8DB10B  |010BB1;
    STA.W $0BB3                                                        ;049A68|8DB30B  |010BB3;
   
; we need to properly update the script pointer here
  ; LDA.W #$F189                                                       ;049A6B|A989F1  |      ; 2FF189 -> $05FE31-1 = clear temp flags 0-F in script
    LDA.W #(getSpecialPtrValue(6))
    STA.W huff_script_position_in_bytes                                ;049A6E|8D0804  |010408;
  ; LDA.W #$002F                                                       ;049A71|A92F00  |      ;
    LDA.W #((getSpecialPtrValue(6)>>16)&$ff)
    STA.W bank_num_of_huff_script_pos                                  ;049A74|8D0A04  |01040A;

    STZ.W huff_buffer_contents                                         ;049A77|9C0B04  |01040B;
    JSR.W copy_0x30_bytes_to_SRAM_020_and_update_perm_prog_flag_049A9D ;049A7A|209D9A  |049A9D;
    LDA.W #$0000                                                       ;049A7D|A90000  |      ; clear out all SRAM progress flags
    LDX.W #$0006                                                       ;049A80|A20600  |      ;
  - STA.L SRAM_progress_flags_for_playthru,X                           ;049A83|9F100070|700010;
    DEX #2                                                             ;049A87|CA      |      ;
    BPL -                                                              ;049A89|10F8    |049A83;
    LDA.W #$007D                                                       ;049A8B|A97D00  |      ; clear progress flag 0x7D
    JSR.W BRK_1C_24_at_049D7D                                          ;049A8E|207D9D  |049D7D;
    LDA.L $700005                                                      ;049A91|AF050070|700005; clear bit 3 of SRAM byte 005 = allow reading previous text
    AND.W #$FFF7                                                       ;049A95|29F7FF  |      ;
    STA.L $700005                                                      ;049A98|8F050070|700005;
    RTS                                                                ;049A9C|60      |      ;

copy_0x30_bytes_to_SRAM_020_and_update_perm_prog_flag_049A9D:
    LDX.W #$002E                                                       ;049A9D|A22E00  |      ;
    LDA.W #$0000                                                       ;049AA0|A90000  |      ;
  - STA.W block_containing_playthru_temp_flags_0B94,X                  ;049AA3|9D940B  |010B94;
    STA.L $700020,X                                                    ;049AA6|9F200070|700020;
    DEX #2                                                             ;049AAA|CA      |      ;
    BPL -                                                              ;049AAC|10F5    |049AA3;
update_permanent_prog_flags_and_clear_flag_0x7F_049AAE:
    LDX.W #$0006                                                       ;049AAE|A20600  |      ;
  - LDA.L SRAM_progress_flags_for_playthru,X                           ;049AB1|BF100070|700010; update (permanent?) SRAM progress flags based on player progress
    ORA.L SRAM_file_progress_flags_SCRATCHPAD_ONLY,X                   ;049AB5|1F180070|700018;
    STA.L SRAM_file_progress_flags_SCRATCHPAD_ONLY,X                   ;049AB9|9F180070|700018;
    DEX #2                                                             ;049ABD|CA      |      ;
    BPL -                                                              ;049ABF|10F0    |049AB1;
    SEP #$30                                                           ;049AC1|E230    |      ;
    LDA.B #$00                                                         ;049AC3|A900    |      ; what does byte 0B8 in SRAM do?
    STA.L $7000B8                                                      ;049AC5|8FB80070|7000B8;
    REP #$30                                                           ;049AC9|C230    |      ;
    LDA.W #$007F                                                       ;049ACB|A97F00  |      ; clear progress flag 0x7F
    JSR.W BRK_1C_24_at_049D7D                                          ;049ACE|207D9D  |049D7D;
    RTS                                                                ;049AD1|60      |      ;

; ------------------------------------------------------------------------------

check_viewed_endings_and_update_prog_flags_049AD2:
    JSR.W update_permanent_prog_flags_and_clear_flag_0x7F_049AAE       ;049AD2|20AE9A  |049AAE;
    LDA.W #$0001                                                       ;049AD5|A90100  |      ; check if player has reached 1+ good endings in murder mystery route
    BRK #$1C                                                           ;049AD8|001C    |      ; on technical level, check if at least one of progress flags 1-4 is set
    db $25                                                             ;049ADA|        |      ;
    BCS case_player_has_viewed_good_ending_049AF5                      ;049ADB|B018    |049AF5;

    LDA.W #$0002                                                       ;049ADD|A90200  |      ; check progress flag 2
    BRK #$1C                                                           ;049AE0|001C    |      ;
    db $25                                                             ;049AE2|        |      ;
    BCS case_player_has_viewed_good_ending_049AF5                      ;049AE3|B010    |049AF5;

    LDA.W #$0003                                                       ;049AE5|A90300  |      ; check progress flag 3
    BRK #$1C                                                           ;049AE8|001C    |      ;
    db $25                                                             ;049AEA|        |      ;
    BCS case_player_has_viewed_good_ending_049AF5                      ;049AEB|B008    |049AF5;

    LDA.W #$0004                                                       ;049AED|A90400  |      ; check progress flag 4
    BRK #$1C                                                           ;049AF0|001C    |      ;
    db $25                                                             ;049AF2|        |      ;
    BCC check_for_viewing_secret_message_ending_049AFB                 ;049AF3|9006    |049AFB; if progress flags 1-4 are all CLEAR, skip down

case_player_has_viewed_good_ending_049AF5:
    LDA.W #$0073                                                       ;049AF5|A97300  |      ; if any of these are set, set progress flag 0x73
    BRK #$1C                                                           ;049AF8|001C    |      ;
    db $A3                                                             ;049AFA|        |      ;

check_for_viewing_secret_message_ending_049AFB:
    LDA.W #$0018                                                       ;049AFB|A91800  |      ; check progress flag 0x18 (secret message ending)
    BRK #$1C                                                           ;049AFE|001C    |      ;
    db $25                                                             ;049B00|        |      ;
    BCC check_for_pink_bookmark_049B09                                 ;049B01|9006    |049B09;
    LDA.W #$0075                                                       ;049B03|A97500  |      ; if player has viewed that ending, set progress flag 0x75
    BRK #$1C                                                           ;049B06|001C    |      ;
    db $A3                                                             ;049B08|        |      ;

check_for_pink_bookmark_049B09:
    LDA.W #$0014                                                       ;049B09|A91400  |      ; check progress flags for endings 0x01 to 0x14
LOOP_check_progress_flags_0x1_to_0x14_049B0C:
    BRK #$1C                                                           ;049B0C|001C    |      ;
    db $25                                                             ;049B0E|        |      ;
    BCC do_checks_for_prog_flags_0x2D_0x2C_049B28                      ;049B0F|9017    |049B28;
    DEC A                                                              ;049B11|3A      |      ;
    BNE LOOP_check_progress_flags_0x1_to_0x14_049B0C                   ;049B12|D0F8    |049B0C;
    LDA.W #$002B                                                       ;049B14|A92B00  |      ; check progress flag 0x2B (yet another ending)
    BRK #$1C                                                           ;049B17|001C    |      ;
    db $25                                                             ;049B19|        |      ;
    BCC do_checks_for_prog_flags_0x2D_0x2C_049B28                      ;049B1A|900C    |049B28;
    LDA.W #$0074                                                       ;049B1C|A97400  |      ; if got all 0x15 of these endings, grant the pink bookmark
    BRK #$1C                                                           ;049B1F|001C    |      ;
    db $A3                                                             ;049B21|        |      ;
    LDA.W #$0002                                                       ;049B22|A90200  |      ; set bit 1 in $005 in scratchpad
    JSR.W BRK_1C_1A_at_049CA6                                          ;049B25|20A69C  |049CA6;

do_checks_for_prog_flags_0x2D_0x2C_049B28:
    LDA.W #$002D                                                       ;049B28|A92D00  |      ; check progress flag 0x2D (met the girls and the Kayamas or not)
    BRK #$1C                                                           ;049B2B|001C    |      ;
    db $25                                                             ;049B2D|        |      ;
    BCS +                                                              ;049B2E|B009    |049B39;
    LDX.W #$0003                                                       ;049B30|A20300  |      ; if flag 0x2D is clear, set option C (take a nap) as not selected
    LDA.W #$0003                                                       ;049B33|A90300  |      ;
    JSR.W BRK_1C_22_at_049D41                                          ;049B36|20419D  |049D41;
  + LDA.W #$002C                                                       ;049B39|A92C00  |      ; check progress flag 0x2C (surmised about Tanaka being a yakuza)
    BRK #$1C                                                           ;049B3C|001C    |      ;
    db $25                                                             ;049B3E|        |      ;
    BCS +                                                              ;049B3F|B009    |049B4A;
    LDX.W #$0007                                                       ;049B41|A20700  |      ; if flag 0x2C is clear, set option C (ask Tanaka himself) as not selected
    LDA.W #$0003                                                       ;049B44|A90300  |      ;
    JSR.W BRK_1C_22_at_049D41                                          ;049B47|20419D  |049D41;
  + RTS                                                                ;049B4A|60      |      ;

; ------------------------------------------------------------------------------

check_for_gold_bookmark_EDUC_GUESS_049B4B:
    SEP #$30                                                           ;049B4B|E230    |      ;
    LDX.W X_reg_VALUE_A0_018B6D                                        ;049B4D|AE6D8B  |018B6D;
  - LDA.L SRAM_choice_progress_flags_208,X                             ;049B50|BF080270|700208; check that all these bytes are in range 0xF8-0xFF
    ORA.B #$07                                                         ;049B54|0907    |      ;
    INC A                                                              ;049B56|1A      |      ;
    BNE +                                                              ;049B57|D011    |049B6A;
    DEX                                                                ;049B59|CA      |      ;
    BNE -                                                              ;049B5A|D0F4    |049B50;
    REP #$30                                                           ;049B5C|C230    |      ;
    LDA.W #$0076                                                       ;049B5E|A97600  |      ; if yes, set progress flag 0x76
    BRK #$1C                                                           ;049B61|001C    |      ;
    db $A3                                                             ;049B63|        |      ;
    LDA.W #$0004                                                       ;049B64|A90400  |      ; set bit 2 in $005 of scratchpad file
    JSR.W BRK_1C_1A_at_049CA6                                          ;049B67|20A69C  |049CA6;
  + REP #$30                                                           ;049B6A|C230    |      ;
    RTS                                                                ;049B6C|60      |      ;

; ------------------------------------------------------------------------------

BRK_1C_0E_at_049B6D:
    PHD                                                                ;049B6D|0B      |      ;
    PHA                                                                ;049B6E|48      |      ; input value in A
    LDA.W #$1235                                                       ;049B6F|A93512  |      ;
    TCD                                                                ;049B72|5B      |      ;
    JSR.W get_chapter_number_to_print_on_screen_049F84                 ;049B73|20849F  |049F84; chapter # is returned in both Y and A regs
    STY.W $03D5                                                        ;049B76|8CD503  |0103D5;
    PLA                                                                ;049B79|68      |      ; check input in A; if negative, read from before curr pos; else, read from chapter
    BPL case_read_prev_text_from_chapter_BRK_1C_0E_049B8E              ;049B7A|1012    |049B8E;
case_read_prev_text_before_curr_pos_BRK_1C_0E_049B7C:
    STY.W $03CD                                                        ;049B7C|8CCD03  |0103CD;
    JSR.W set_up_to_read_previous_text_04A0D6                          ;049B7F|20D6A0  |04A0D6;
    JSR.W get_num_pages_to_decompress_from_SRAM_04A13B                 ;049B82|203BA1  |04A13B;
    INC A                                                              ;049B85|1A      |      ;
    STA.W $03CF                                                        ;049B86|8DCF03  |0103CF;
    JSR.W read_prev_text_starting_from_curr_pos_04A064                 ;049B89|2064A0  |04A064;
    BRA +                                                              ;049B8C|8017    |049BA5;
case_read_prev_text_from_chapter_BRK_1C_0E_049B8E:
    TAX                                                                ;049B8E|AA      |      ;
    LDA.L SRAM_LIST_text_page_block_num_for_each_chapter,X             ;049B8F|BF500070|700050;
    AND.W #$00FF                                                       ;049B93|29FF00  |      ;
    STA.W $03CD                                                        ;049B96|8DCD03  |0103CD;
    JSR.W set_up_to_read_previous_text_04A0D6                          ;049B99|20D6A0  |04A0D6;
    LDA.W #$0001                                                       ;049B9C|A90100  |      ;
    STA.W $03CF                                                        ;049B9F|8DCF03  |0103CF;
    JSR.W read_prev_text_from_chapter_in_list_04A097                   ;049BA2|2097A0  |04A097;
  + PLD                                                                ;049BA5|2B      |      ;
    JMP.W case_prog_flag_set_or_clear_based_on_C_flag_049E52           ;049BA6|4C529E  |049E52;

BRK_1C_0F_at_049BA9:
    PHD                                                                ;049BA9|0B      |      ;
    LDA.W #$1235                                                       ;049BAA|A93512  |      ;
    TCD                                                                ;049BAD|5B      |      ;
    JSR.W read_prev_text_starting_from_curr_pos_04A064                 ;049BAE|2064A0  |04A064; this sets/clears carry flag based on if it succeeded or not
    LDA.W #$0001                                                       ;049BB1|A90100  |      ;
    TSB.W $03c1                                                        ;049BB4|0CC103  |0103C1;
    PLD                                                                ;049BB7|2B      |      ;
    JMP.W case_prog_flag_set_or_clear_based_on_C_flag_049E52           ;049BB8|4C529E  |049E52;

BRK_1C_10_at_049BBB:
    PHD                                                                ;049BBB|0B      |      ;
    LDA.W #$1235                                                       ;049BBC|A93512  |      ;
    TCD                                                                ;049BBF|5B      |      ;
    JSR.W read_prev_text_from_chapter_in_list_04A097                   ;049BC0|2097A0  |04A097;
    LDA.W #$0001                                                       ;049BC3|A90100  |      ;
    TSB.W $03c1                                                        ;049BC6|0CC103  |0103C1;
    PLD                                                                ;049BC9|2B      |      ;
    JMP.W case_prog_flag_set_or_clear_based_on_C_flag_049E52           ;049BCA|4C529E  |049E52;

BRK_1C_11_at_049BCD:
    AND.W #$0003                                                       ;049BCD|290300  |      ;
    PHD                                                                ;049BD0|0B      |      ;
    PEA.W $1235                                                        ;049BD1|F43512  |011235;
    PLD                                                                ;049BD4|2B      |      ;
    STA.B $43                                                          ;049BD5|8543    |001278;
    JSR.W copy_save_file_proper_into_scratchpad_049F28                 ;049BD7|20289F  |049F28;
    JSR.W get_chapter_number_to_print_on_screen_049F84                 ;049BDA|20849F  |049F84;
    DEX                                                                ;049BDD|CA      |      ; if chapter # is somehow 0, do not try to read its title
    BMI +                                                              ;049BDE|3007    |049BE7;
    JSR.W read_title_for_chapter_X_049BF8                              ;049BE0|20F89B  |049BF8;
    PLD                                                                ;049BE3|2B      |      ;
    JMP.W case_prog_flag_clear_049E54                                  ;049BE4|4C549E  |049E54;
  + PLD                                                                ;049BE7|2B      |      ;
    JMP.W case_prog_flag_set_049E5C                                    ;049BE8|4C5C9E  |049E5C;

BRK_1C_12_at_049BEB:
    PHD                                                                ;049BEB|0B      |      ;
    PEA.W $1235                                                        ;049BEC|F43512  |011235;
    PLD                                                                ;049BEF|2B      |      ;
    STZ.B $43                                                          ;049BF0|6443    |001278;
    TAX                                                                ;049BF2|AA      |      ;
    JSR.W read_title_for_chapter_X_049BF8                              ;049BF3|20F89B  |049BF8;
    PLD                                                                ;049BF6|2B      |      ;
    RTS                                                                ;049BF7|60      |      ;

read_title_for_chapter_X_049BF8:
    LDA.L SRAM_LIST_text_page_block_num_for_each_chapter,X             ;049BF8|BF500070|700050;
    AND.W #$00FF                                                       ;049BFC|29FF00  |      ;
    JSR.W get_X_index_for_text_page_block_num_in_input_04A05D          ;049BFF|205DA0  |04A05D;
    LDA.L SRAM_data_struct_for_text_page_block_temp_flags,X            ;049C02|BFD00270|7002D0; use the temporary flags that the player had as soon as the chapter started
    STA.W playthru_temp_flags                                          ;049C06|8DB10B  |010BB1;
    LDA.L $7002D2,X                                                    ;049C09|BFD20270|7002D2;
    STA.W $0BB3                                                        ;049C0D|8DB30B  |010BB3;
    LDA.L SRAM_LIST_ptr_to_start_of_text_page_block,X                  ;049C10|BFD40270|7002D4; read the 24-bit (20+4) pointer for the start of a chapter
    STA.B $08                                                          ;049C14|8508    |00123D;
    LDA.L $7002D5,X                                                    ;049C16|BFD50270|7002D5;
    STA.B $09                                                          ;049C1A|8509    |00123E;
    STZ.B $0B                                                          ;049C1C|640B    |001240;
    JSL.L read_Huff_script_starting_from_prev_chapter_009C99           ;049C1E|22999C00|009C99;
    RTS                                                                ;049C22|60      |      ;

BRK_1C_13_at_049C23:
    LDX.W offsets_in_save_file_0_for_names_018B11,Y                    ;049C23|BE118B  |018B11;
    LDY.W #$000A                                                       ;049C26|A00A00  |      ;
  - LDA.W buffer_for_name_1656,Y                                       ;049C29|B95616  |011656;
    STA.L SRAM_START_save_file_metadata_checksum,X                     ;049C2C|9F000070|700000;
    DEX #2                                                             ;049C30|CA      |      ;
    DEY #2                                                             ;049C32|88      |      ;
    BPL -                                                              ;049C34|10F3    |049C29;
    INC.W $03C3                                                        ;049C36|EEC303  |0103C3;
    RTS                                                                ;049C39|60      |      ;

BRK_1C_15_at_049C3A:
    AND.W #$0003                                                       ;049C3A|290300  |      ; take a save file number (?) and get appropriate offset in SRAM for names of things
    ASL A                                                              ;049C3D|0A      |      ;
    TAX                                                                ;049C3E|AA      |      ;
    TYA                                                                ;049C3F|98      |      ; input Y is rel. offset into list of ptrs to names in save file
    CLC                                                                ;049C40|18      |      ; add actual offset in SRAM to the base pointer
    ADC.W LIST_offsets_for_table_of_offsets_in_SRAM_018B39,X           ;049C41|7D398B  |018B39;
    TAY                                                                ;049C44|A8      |      ;
BRK_1C_14_at_049C45:
    LDX.W offsets_in_save_file_0_for_names_018B11,Y                    ;049C45|BE118B  |018B11;
    LDY.W #$000A                                                       ;049C48|A00A00  |      ;
  - LDA.L SRAM_START_save_file_metadata_checksum,X                     ;049C4B|BF000070|700000;
    STA.W buffer_for_name_1656,Y                                       ;049C4F|995616  |011656;
    DEX #2                                                             ;049C52|CA      |      ;
    DEY #2                                                             ;049C54|88      |      ;
    BPL -                                                              ;049C56|10F3    |049C4B;
    RTS                                                                ;049C58|60      |      ;

BRK_1C_16_at_049C59:
    SEP #$20                                                           ;049C59|E220    |      ;
    AND.B #$03                                                         ;049C5B|2903    |      ;
    STA.L SRAM_which_save_file_1_2_or_3                                ;049C5D|8F780070|700078;
    REP #$20                                                           ;049C61|C220    |      ;
    INC.W $03C3                                                        ;049C63|EEC303  |0103C3;
    RTS                                                                ;049C66|60      |      ;

BRK_1C_17_at_049C67:
    AND.W #$0003                                                       ;049C67|290300  |      ; given a save file ID #, get the value at position 0x078 for a file
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049C6A|201F9F  |049F1F;
    SEP #$20                                                           ;049C6D|E220    |      ;
    LDA.L SRAM_which_save_file_1_2_or_3,X                              ;049C6F|BF780070|700078;
    STA.B $07,S                                                        ;049C73|8307    |000007;
    REP #$20                                                           ;049C75|C220    |      ;
    RTS                                                                ;049C77|60      |      ;

BRK_1C_18_at_049C78:
    LDA.L SRAM_num_playthrus                                           ;049C78|AF7A0070|70007A; increment # playthroughs
    INC A                                                              ;049C7C|1A      |      ;
    STA.L SRAM_num_playthrus                                           ;049C7D|8F7A0070|70007A;
    LDA.W #$007D                                                       ;049C81|A97D00  |      ; set progress flag 0x7D (player has reached an ending)
    JSR.W BRK_1C_23_at_049D6E                                          ;049C84|206E9D  |049D6E;
    INC.W $03C3                                                        ;049C87|EEC303  |0103C3;
    JSR.W check_viewed_endings_and_update_prog_flags_049AD2            ;049C8A|20D29A  |049AD2; determine if player has pink bookmark, can view more routes, etc.
    JSR.W check_for_gold_bookmark_EDUC_GUESS_049B4B                    ;049C8D|204B9B  |049B4B;
    RTS                                                                ;049C90|60      |      ;

BRK_1C_19_at_049C91:
    AND.W #$0003                                                       ;049C91|290300  |      ;
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049C94|201F9F  |049F1F;
    LDA.L SRAM_num_playthrus,X                                         ;049C97|BF7A0070|70007A;
    CMP.W #$03E8                                                       ;049C9B|C9E803  |      ; 0x3E8 = one thousand; if 1000 or greater, use 999 instead
    BCC +                                                              ;049C9E|9003    |049CA3;
    LDA.W #$03E7                                                       ;049CA0|A9E703  |      ;
  + STA.B $07,S                                                        ;049CA3|8307    |000007;
    RTS                                                                ;049CA5|60      |      ;

BRK_1C_1A_at_049CA6:
    SEP #$20                                                           ;049CA6|E220    |      ; given 1-byte input in A, set appropriate bits in $005 in scratchpad
    ORA.L $700005                                                      ;049CA8|0F050070|700005;
    STA.L $700005                                                      ;049CAC|8F050070|700005;
    REP #$20                                                           ;049CB0|C220    |      ;
    INC.W $03C3                                                        ;049CB2|EEC303  |0103C3;
    RTS                                                                ;049CB5|60      |      ;

BRK_1C_1B_at_049CB6:
    SEP #$20                                                           ;049CB6|E220    |      ; given 1-byte input in A, clear appropriate bits in $005 in scratchpad
    EOR.B #$FF                                                         ;049CB8|49FF    |      ;
    AND.L $700005                                                      ;049CBA|2F050070|700005;
    STA.L $700005                                                      ;049CBE|8F050070|700005;
    REP #$20                                                           ;049CC2|C220    |      ;
    INC.W $03C3                                                        ;049CC4|EEC303  |0103C3;
    RTS                                                                ;049CC7|60      |      ;

BRK_1C_1C_at_049CC8:
    AND.W #$0003                                                       ;049CC8|290300  |      ;
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049CCB|201F9F  |049F1F;
    LDA.L $700005,X                                                    ;049CCE|BF050070|700005;
    AND.W #$00FF                                                       ;049CD2|29FF00  |      ;
    STA.B $07,S                                                        ;049CD5|8307    |000007;
    RTS                                                                ;049CD7|60      |      ;

BRK_1C_1D_at_049CD8:
    LDA.W #$0001                                                       ;049CD8|A90100  |      ;
    JSR.W copy_save_file_proper_1st_0x78_bytes_into_scratchpad_049F30  ;049CDB|20309F  |049F30;
    LDA.L $700005                                                      ;049CDE|AF050070|700005; clear out bit 0 of address $005 in scratchpad
    AND.W #$FFFE                                                       ;049CE2|29FEFF  |      ;
    STA.L $700005                                                      ;049CE5|8F050070|700005;
    LDA.W #$0000                                                       ;049CE9|A90000  |      ; calculate checksum of scratchpad's metadata
    JSR.W calc_checksum_for_save_file_metadata_049ECD                  ;049CEC|20CD9E  |049ECD;
    SEP #$20                                                           ;049CEF|E220    |      ;
    LDA.B #$01                                                         ;049CF1|A901    |      ; default to save file 1
    STA.L SRAM_which_save_file_1_2_or_3                                ;049CF3|8F780070|700078;
    REP #$20                                                           ;049CF7|C220    |      ;
    JSR.W copy_scratchpad_save_metadata_into_sourced_save_file_049F61  ;049CF9|20619F  |049F61; copy updated metadata into save file 1
    RTS                                                                ;049CFC|60      |      ;

BRK_1C_1E_at_049CFD:
    LDA.W #$0001                                                       ;049CFD|A90100  |      ; copy save file 1's metadata into scratchpad
    JSR.W copy_save_file_proper_1st_0x78_bytes_into_scratchpad_049F30  ;049D00|20309F  |049F30;
    LDA.L $700005                                                      ;049D03|AF050070|700005; set bit 0 of scratchpad address $005
    ORA.W #$0001                                                       ;049D07|090100  |      ;
    STA.L $700005                                                      ;049D0A|8F050070|700005;
    LDA.W #$0000                                                       ;049D0E|A90000  |      ; calculate checksums for scratchpad save file
    JSR.W calc_checksum_for_save_file_metadata_049ECD                  ;049D11|20CD9E  |049ECD;
    SEP #$20                                                           ;049D14|E220    |      ;
    LDA.B #$01                                                         ;049D16|A901    |      ; default to save file 1
    STA.L SRAM_which_save_file_1_2_or_3                                ;049D18|8F780070|700078;
    REP #$20                                                           ;049D1C|C220    |      ;
    JSR.W copy_scratchpad_save_metadata_into_sourced_save_file_049F61  ;049D1E|20619F  |049F61; copy scratchpad save file's metadata into save file 1
    RTS                                                                ;049D21|60      |      ;

BRK_1C_1F_at_049D22:
    SEP #$30                                                           ;049D22|E230    |      ;
    PHX                                                                ;049D24|DA      |      ;
    TAX                                                                ;049D25|AA      |      ; A = index for a bitmask
    ORA.W DATA_018B67,X                                                ;049D26|1D678B  |018B67;
    ORA.W DATA_018B3F,Y                                                ;049D29|193F8B  |018B3F; Y = index for a bitmask
    PLX                                                                ;049D2C|FA      |      ; X = which byte of choice progress to modify
    PHA                                                                ;049D2D|48      |      ;
    LDA.L SRAM_choice_progress_flags_208,X                             ;049D2E|BF080270|700208;
    AND.B #$F8                                                         ;049D32|29F8    |      ;
    ORA.B $01,S                                                        ;049D34|0301    |000001;
    STA.L SRAM_choice_progress_flags_208,X                             ;049D36|9F080270|700208;
    PLA                                                                ;049D3A|68      |      ;
    REP #$30                                                           ;049D3B|C230    |      ;
    INC.W $03C3                                                        ;049D3D|EEC303  |0103C3;
    RTS                                                                ;049D40|60      |      ;

BRK_1C_22_at_049D41:
    SEP #$30                                                           ;049D41|E230    |      ; inputs in A and X
    TAY                                                                ;049D43|A8      |      ; A = index for a bitmask
    LDA.W DATA_018B67,Y                                                ;049D44|B9678B  |018B67;
    EOR.B #$FF                                                         ;049D47|49FF    |      ;
    AND.L SRAM_choice_progress_flags_208,X                             ;049D49|3F080270|700208; X = index for what byte of choice progress to modify
    STA.L SRAM_choice_progress_flags_208,X                             ;049D4D|9F080270|700208;
    REP #$30                                                           ;049D51|C230    |      ;
    INC.W $03C3                                                        ;049D53|EEC303  |0103C3;
    RTS                                                                ;049D56|60      |      ;

BRK_1C_21_at_049D57:
    PHX                                                                ;049D57|DA      |      ;
    AND.W #$0003                                                       ;049D58|290300  |      ;
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049D5B|201F9F  |049F1F;
    TXA                                                                ;049D5E|8A      |      ;
    CLC                                                                ;049D5F|18      |      ;
    ADC.B $01,S                                                        ;049D60|6301    |000001;
    TAX                                                                ;049D62|AA      |      ;
    PLA                                                                ;049D63|68      |      ;
BRK_1C_20_at_049D64:
    LDA.L SRAM_choice_progress_flags_208,X                             ;049D64|BF080270|700208;
    AND.W #$0007                                                       ;049D68|290700  |      ;
    STA.B $07,S                                                        ;049D6B|8307    |000007;
    RTS                                                                ;049D6D|60      |      ;

BRK_1C_23_at_049D6E:
    AND.W #$007F                                                       ;049D6E|297F00  |      ; related to setting a progress flag? input in A is the flag ID value
    JSR.W get_bit_to_set_for_prog_flag_049DCC                          ;049D71|20CC9D  |049DCC;
    ORA.L SRAM_progress_flags_for_playthru,X                           ;049D74|1F100070|700010;
    STA.L SRAM_progress_flags_for_playthru,X                           ;049D78|9F100070|700010;
    RTS                                                                ;049D7C|60      |      ;

BRK_1C_24_at_049D7D:
    AND.W #$007F                                                       ;049D7D|297F00  |      ; clears progress flags
    JSR.W get_bit_to_set_for_prog_flag_049DCC                          ;049D80|20CC9D  |049DCC;
    EOR.W #$FFFF                                                       ;049D83|49FFFF  |      ;
    AND.L SRAM_progress_flags_for_playthru,X                           ;049D86|3F100070|700010;
    STA.L SRAM_progress_flags_for_playthru,X                           ;049D8A|9F100070|700010;
    RTS                                                                ;049D8E|60      |      ;

BRK_1C_25_at_049D8F:
    AND.W #$003F                                                       ;049D8F|293F00  |      ; check a particular progress flag
    JSR.W get_bit_to_set_for_prog_flag_049DCC                          ;049D92|20CC9D  |049DCC;
    AND.L SRAM_file_progress_flags_SCRATCHPAD_ONLY,X                   ;049D95|3F180070|700018;
    BEQ +                                                              ;049D99|F003    |049D9E;
    JMP.W case_prog_flag_set_049E5C                                    ;049D9B|4C5C9E  |049E5C; flag is set
  + JMP.W case_prog_flag_clear_049E54                                  ;049D9E|4C549E  |049E54; flag is clear

BRK_1C_26_at_049DA1:
    AND.W #$001F                                                       ;049DA1|291F00  |      ; set one temporary flag
    JSR.W get_bit_to_set_for_prog_flag_049DCC                          ;049DA4|20CC9D  |049DCC;
    ORA.W playthru_temp_flags,X                                        ;049DA7|1DB10B  |010BB1;
    STA.W playthru_temp_flags,X                                        ;049DAA|9DB10B  |010BB1;
    RTS                                                                ;049DAD|60      |      ;

BRK_1C_27_at_049DAE:
    AND.W #$001F                                                       ;049DAE|291F00  |      ; clear one temporary flag
    JSR.W get_bit_to_set_for_prog_flag_049DCC                          ;049DB1|20CC9D  |049DCC;
    EOR.W #$FFFF                                                       ;049DB4|49FFFF  |      ;
    AND.W playthru_temp_flags,X                                        ;049DB7|3DB10B  |010BB1;
    STA.W playthru_temp_flags,X                                        ;049DBA|9DB10B  |010BB1;
    RTS                                                                ;049DBD|60      |      ;

BRK_1C_28_at_049DBE:
    JSR.W get_bit_to_set_for_prog_flag_049DCC                          ;049DBE|20CC9D  |049DCC; check temp flag and return status in carry flag
    AND.W playthru_temp_flags,X                                        ;049DC1|3DB10B  |010BB1;
    BEQ +                                                              ;049DC4|F003    |049DC9;
    JMP.W case_prog_flag_set_049E5C                                    ;049DC6|4C5C9E  |049E5C;
  + JMP.W case_prog_flag_clear_049E54                                  ;049DC9|4C549E  |049E54;

get_bit_to_set_for_prog_flag_049DCC:
    TAY                                                                ;049DCC|A8      |      ; X <- A >> 3, keep old value of A
    LSR #3                                                             ;049DCD|4A      |      ;
    TAX                                                                ;049DD0|AA      |      ;
    TYA                                                                ;049DD1|98      |      ;
    AND.W #$0007                                                       ;049DD2|290700  |      ; Y <- A & 0x7
    TAY                                                                ;049DD5|A8      |      ; so flag ID value packs a 5-bit value and a 3-bit value as XXXXX YYY
    LDA.W bits_to_set_for_SRAM_prog_flags_018B65,Y                     ;049DD6|B9658B  |018B65;
    AND.W #$00FF                                                       ;049DD9|29FF00  |      ;
    RTS                                                                ;049DDC|60      |      ;

BRK_1C_29_at_049DDD:
    LDX.W #$000A                                                       ;049DDD|A20A00  |      ;
    SEP #$20                                                           ;049DE0|E220    |      ;
    STA.L $700004                                                      ;049DE2|8F040070|700004;
    CMP.L $7000B8                                                      ;049DE6|CFB80070|7000B8;
    REP #$20                                                           ;049DEA|C220    |      ;
    BEQ LOOP_copy_from_SRAM_0B8_to_004_copy_temp_flags_to_RAM_049DFE   ;049DEC|F010    |049DFE;
LOOP_copy_from_SRAM_004_to_0B8_and_inc_03C3_049DEE:
    LDA.L $700004,X                                                    ;049DEE|BF040070|700004;
    STA.L $7000B8,X                                                    ;049DF2|9FB80070|7000B8;
    DEX #2                                                             ;049DF6|CA      |      ;
    BPL LOOP_copy_from_SRAM_004_to_0B8_and_inc_03C3_049DEE             ;049DF8|10F4    |049DEE;
    INC.W $03C3                                                        ;049DFA|EEC303  |0103C3;
    RTS                                                                ;049DFD|60      |      ;
LOOP_copy_from_SRAM_0B8_to_004_copy_temp_flags_to_RAM_049DFE:
    LDA.L $7000B8,X                                                    ;049DFE|BFB80070|7000B8;
    STA.L $700004,X                                                    ;049E02|9F040070|700004;
    DEX #2                                                             ;049E06|CA      |      ;
    BPL LOOP_copy_from_SRAM_0B8_to_004_copy_temp_flags_to_RAM_049DFE   ;049E08|10F4    |049DFE;
    LDA.L SRAM_data_for_curr_page_block                                ;049E0A|AF080070|700008;
    STA.W playthru_temp_flags                                          ;049E0E|8DB10B  |010BB1;
    LDA.L $70000A                                                      ;049E11|AF0A0070|70000A;
    STA.W $0BB3                                                        ;049E15|8DB30B  |010BB3;
    RTS                                                                ;049E18|60      |      ;

BRK_1C_2A_at_049E19:
    LDA.W #$0008                                                       ;049E19|A90800  |      ; set the 0x08 bit of $005 in scratchpad
    BRK #$1C                                                           ;049E1C|001C    |      ;
    db $9A                                                             ;049E1E|        |      ;
    RTS                                                                ;049E1F|60      |      ;

BRK_1C_2B_at_049E20:
    LDA.W #$0008                                                       ;049E20|A90800  |      ; clear the 0x08 bit of $005 in scratchpad
    BRK #$1C                                                           ;049E23|001C    |      ;
    db $9B                                                             ;049E25|        |      ;
    LDA.L SRAM_num_pages_in_curr_text_page_block                       ;049E26|AF0F0070|70000F; set the maze's text as unreadable after you escape from it
    ORA.W #$0080                                                       ;049E2A|098000  |      ;
    STA.L SRAM_num_pages_in_curr_text_page_block                       ;049E2D|8F0F0070|70000F;
    RTS                                                                ;049E31|60      |      ;

BRK_1C_2C_at_049E32:
    LDA.W #$007F                                                       ;049E32|A97F00  |      ; set progress flag 0x7F
    JSR.W BRK_1C_23_at_049D6E                                          ;049E35|206E9D  |049D6E;
    LDA.W #$007E                                                       ;049E38|A97E00  |      ; clear progress flag 0x7E
    JSR.W BRK_1C_24_at_049D7D                                          ;049E3B|207D9D  |049D7D;
    LDA.L SRAM_curr_chapter_index_to_text_block_num_list               ;049E3E|AF060070|700006; overwrite most recent progress flags in save file
    AND.W #$00FF                                                       ;049E42|29FF00  |      ;
    DEC A                                                              ;049E45|3A      |      ;
    JSR.W copy_prog_flags_from_scratchpad_to_src_save_file_04A14C      ;049E46|204CA1  |04A14C;
    INC.W $03C3                                                        ;049E49|EEC303  |0103C3; calculate checksum for whole scratchpad save file
    JMP.W BRK_1C_03_at_0498DA                                          ;049E4C|4CDA98  |0498DA;

BRK_1C_2D_at_049E4F:
    JMP.W update_save_file_checksums_049EC3                            ;049E4F|4CC39E  |049EC3;

; ------------------------------------------------------------------------------

case_prog_flag_set_or_clear_based_on_C_flag_049E52:
    BCS case_prog_flag_set_049E5C                                      ;049E52|B008    |049E5C;
case_prog_flag_clear_049E54:
    LDA.B $09,S                                                        ;049E54|A309    |000009; clear the LSB of this stack value
    AND.W #$FFFE                                                       ;049E56|29FEFF  |      ;
    STA.B $09,S                                                        ;049E59|8309    |000009;
    RTS                                                                ;049E5B|60      |      ;
case_prog_flag_set_049E5C:
    LDA.B $09,S                                                        ;049E5C|A309    |000009; set the LSB of this stack value
    ORA.W #$0001                                                       ;049E5E|090100  |      ; what is the purpose for this?
    STA.B $09,S                                                        ;049E61|8309    |000009;
    RTS                                                                ;049E63|60      |      ;

check_for_06CD_at_offset_0C4_in_save_file_A_049E64:
    PHA                                                                ;049E64|48      |      ;
    PHX                                                                ;049E65|DA      |      ;
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049E66|201F9F  |049F1F;
; value got repointed in "insert uncomp text with changing ptr locations.asm"
  ; LDA.W magic_number_06CD_01AC69                                     ;049E69|AD69AC  |01AC69; probably not text, but 06CD matches with な in table file
    LDA.W MagicNumberForSaveFiles
    CMP.L SRAM_copy_of_value_06CD,X                                    ;049E6C|DFC40070|7000C4; store the value here in the save file if it isn't there already
    BEQ PLX_PLA_RTS_049E82                                             ;049E70|F010    |049E82;
    STA.L SRAM_copy_of_value_06CD,X                                    ;049E72|9FC40070|7000C4;
    LDA.W #$0000                                                       ;049E76|A90000  |      ;
    STA.L SRAM_curr_chapter_index_to_text_block_num_list,X             ;049E79|9F060070|700006;
    LDA.B $03,S                                                        ;049E7D|A303    |000003;
    JSR.W update_save_file_checksums_049EC3                            ;049E7F|20C39E  |049EC3;
PLX_PLA_RTS_049E82:
    PLX                                                                ;049E82|FA      |      ;
    PLA                                                                ;049E83|68      |      ;
    RTS                                                                ;049E84|60      |      ;

delete_and_reinit_save_file_A_049E85:
    BCS RTS_049EC2                                                     ;049E85|B03B    |049EC2; if somehow got here despite good checksums, RTS
    PHA                                                                ;049E87|48      |      ;
    PHX                                                                ;049E88|DA      |      ;
    PHY                                                                ;049E89|5A      |      ;
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049E8A|201F9F  |049F1F;
    PHX                                                                ;049E8D|DA      |      ;
    LDA.L $700005,X                                                    ;049E8E|BF050070|700005; keep copy of file's settings byte for stereo/mono toggle
    PHA                                                                ;049E92|48      |      ;
    LDY.W #$0400                                                       ;049E93|A00004  |      ; clear out the save file (data 00 in 0x800 bytes)
    LDA.W #$0000                                                       ;049E96|A90000  |      ;
  - STA.L SRAM_START_save_file_metadata_checksum,X                     ;049E99|9F000070|700000;
    INX #2                                                             ;049E9D|E8      |      ;
    DEY                                                                ;049E9F|88      |      ;
    BNE -                                                              ;049EA0|D0F7    |049E99;
    PLA                                                                ;049EA2|68      |      ;
    PLX                                                                ;049EA3|FA      |      ;
    SEP #$20                                                           ;049EA4|E220    |      ;
    CMP.B #$FF                                                         ;049EA6|C9FF    |      ; if file settings byte was FF, increment it to 00
    BNE +                                                              ;049EA8|D001    |049EAB;
    INC A                                                              ;049EAA|1A      |      ;
  + AND.B #$01                                                         ;049EAB|2901    |      ; preserve only the stereo/mono setting after deleting file
    STA.L $700005,X                                                    ;049EAD|9F050070|700005;
    REP #$20                                                           ;049EB1|C220    |      ;
  ; LDA.W magic_number_06CD_01AC69                                     ;049EB3|AD69AC  |01AC69; write just this particular value to the save file
    LDA.W MagicNumberForSaveFiles
    STA.L SRAM_copy_of_value_06CD,X                                    ;049EB6|9FC40070|7000C4;
    LDA.B $05,S                                                        ;049EBA|A305    |000005;
    JSR.W update_save_file_checksums_049EC3                            ;049EBC|20C39E  |049EC3;
    PLY                                                                ;049EBF|7A      |      ;
    PLX                                                                ;049EC0|FA      |      ;
    PLA                                                                ;049EC1|68      |      ;
RTS_049EC2:
    RTS                                                                ;049EC2|60      |      ;

update_save_file_checksums_049EC3:
    JSR.W calc_checksum_for_save_file_data_049EEC                      ;049EC3|20EC9E  |049EEC;
    BCS calc_checksum_for_save_file_metadata_049ECD                    ;049EC6|B005    |049ECD;
    JSR.W calc_checksum_for_save_file_metadata_049ECD                  ;049EC8|20CD9E  |049ECD;
    CLC                                                                ;049ECB|18      |      ;
    RTS                                                                ;049ECC|60      |      ;

calc_checksum_for_save_file_metadata_049ECD:
    PHA                                                                ;049ECD|48      |      ;
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049ECE|201F9F  |049F1F; get start of save file N
    PHX                                                                ;049ED1|DA      |      ;
    ORA.W #$0004                                                       ;049ED2|090400  |      ; get position of save file offset 0x2 in SRAM
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049ED5|201F9F  |049F1F;
    LDY.W #$0027                                                       ;049ED8|A02700  |      ; get a two byte sum of 0x27 byte pairs in a save file (700002 - 70004F)
    JSR.W sum_Y_byte_pairs_at_X_for_save_file_049F0B                   ;049EDB|200B9F  |049F0B; is this a checksum for the save file "metadata"?
    PLX                                                                ;049EDE|FA      |      ;
    CMP.L SRAM_START_save_file_metadata_checksum,X                     ;049EDF|DF000070|700000; check against existing metadata checksum value
    BEQ +                                                              ;049EE3|F005    |049EEA; if equal, return with carry SET (auto set from CMP)
    STA.L SRAM_START_save_file_metadata_checksum,X                     ;049EE5|9F000070|700000; otherwise, update the value and return with carry CLEAR
    CLC                                                                ;049EE9|18      |      ;
  + PLA                                                                ;049EEA|68      |      ;
    RTS                                                                ;049EEB|60      |      ;

calc_checksum_for_save_file_data_049EEC:
    PHA                                                                ;049EEC|48      |      ;
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049EED|201F9F  |049F1F;
    PHX                                                                ;049EF0|DA      |      ;
    ORA.W #$0008                                                       ;049EF1|090800  |      ; get position for offset 0x50 of save file N in SRAM
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049EF4|201F9F  |049F1F;
    LDY.W #$03D8                                                       ;049EF7|A0D803  |      ; get a two byte sum of all 0x3D8 byte pairs in a save file (700050 - 7007FF)
    JSR.W sum_Y_byte_pairs_at_X_for_save_file_049F0B                   ;049EFA|200B9F  |049F0B;
    PLX                                                                ;049EFD|FA      |      ;
    CMP.L SRAM_save_file_data_checksum,X                               ;049EFE|DF020070|700002; check against this value in the SRAM
    BEQ +                                                              ;049F02|F005    |049F09; if equal, return with carry SET
    STA.L SRAM_save_file_data_checksum,X                               ;049F04|9F020070|700002; if not equal, update it, and return with carry CLEAR
    CLC                                                                ;049F08|18      |      ;
  + PLA                                                                ;049F09|68      |      ;
    RTS                                                                ;049F0A|60      |      ;

sum_Y_byte_pairs_at_X_for_save_file_049F0B:
    PHX                                                                ;049F0B|DA      |      ;
    PHY                                                                ;049F0C|5A      |      ;
    LDA.W #$0000                                                       ;049F0D|A90000  |      ;
    BRA +                                                              ;049F10|8007    |049F19;
  - CLC                                                                ;049F12|18      |      ;
    ADC.L SRAM_START_save_file_metadata_checksum,X                     ;049F13|7F000070|700000;
    INX #2                                                             ;049F17|E8      |      ;
  + DEY                                                                ;049F19|88      |      ;
    BNE -                                                              ;049F1A|D0F6    |049F12;
    PLY                                                                ;049F1C|7A      |      ;
    PLX                                                                ;049F1D|FA      |      ;
    RTS                                                                ;049F1E|60      |      ;

get_SRAM_offset_for_data_in_file_A_049F1F:
    PHA                                                                ;049F1F|48      |      ;
    ASL A                                                              ;049F20|0A      |      ;
    TAX                                                                ;049F21|AA      |      ;
    LDA.W LIST_SRAM_offsets_for_save_file_checksums_0000_018B45,X      ;049F22|BD458B  |018B45;
    TAX                                                                ;049F25|AA      |      ;
    PLA                                                                ;049F26|68      |      ;
    RTS                                                                ;049F27|60      |      ;

copy_save_file_proper_into_scratchpad_049F28:
    PHA                                                                ;049F28|48      |      ;
    PHX                                                                ;049F29|DA      |      ;
    PHY                                                                ;049F2A|5A      |      ;
    LDY.W #$07FF                                                       ;049F2B|A0FF07  |      ; do the whole 0x800 byte save file
    BRA +                                                              ;049F2E|8006    |049F36;
copy_save_file_proper_1st_0x78_bytes_into_scratchpad_049F30:
    PHA                                                                ;049F30|48      |      ;
    PHX                                                                ;049F31|DA      |      ;
    PHY                                                                ;049F32|5A      |      ;
    LDY.W #$0077                                                       ;049F33|A07700  |      ; do just the first 0x78 bytes of the save file
  + TAX                                                                ;049F36|AA      |      ;
    BEQ +                                                              ;049F37|F01C    |049F55;
    PHA                                                                ;049F39|48      |      ;
    ORA.W #$000C                                                       ;049F3A|090C00  |      ; get either 0D, 0E, or 0F
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049F3D|201F9F  |049F1F; kind of tricky, this uses an "implied pointer" to $018B5D
    TYA                                                                ;049F40|98      |      ; transfer size for the MVN
    LDY.W #$0000                                                       ;049F41|A00000  |      ; address to WRITE TO for the MVN
    PHB                                                                ;049F44|8B      |      ; X contains the address to READ FROM for the MVN
    MVN $70,$70                                                        ;049F45|547070  |      ; copy save file's data (full or partial) into the scratchpad
    PLB                                                                ;049F48|AB      |      ;
    PLA                                                                ;049F49|68      |      ;
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049F4A|201F9F  |049F1F; set which save file the scratchpad was sourced from
    LDA.L SRAM_which_save_file_1_2_or_3,X                              ;049F4D|BF780070|700078;
    STA.L SRAM_which_save_file_1_2_or_3                                ;049F51|8F780070|700078;
  + PLY                                                                ;049F55|7A      |      ;
    PLX                                                                ;049F56|FA      |      ;
    PLA                                                                ;049F57|68      |      ;
    RTS                                                                ;049F58|60      |      ;

copy_scratchpad_save_file_into_sourced_save_file_049F59:
    PHA                                                                ;049F59|48      |      ;
    PHX                                                                ;049F5A|DA      |      ;
    PHY                                                                ;049F5B|5A      |      ;
    LDY.W #$07FF                                                       ;049F5C|A0FF07  |      ; copy the whole 0x800 bytes in save file
    BRA +                                                              ;049F5F|8006    |049F67;
copy_scratchpad_save_metadata_into_sourced_save_file_049F61:
    PHA                                                                ;049F61|48      |      ;
    PHX                                                                ;049F62|DA      |      ;
    PHY                                                                ;049F63|5A      |      ;
    LDY.W #$004F                                                       ;049F64|A04F00  |      ; copy just the 0x50 bytes of save file's metadata
  + LDA.L SRAM_which_save_file_1_2_or_3                                ;049F67|AF780070|700078; get save file # that scratchpad was sourced from
    AND.W #$00FF                                                       ;049F6B|29FF00  |      ;
    BEQ +                                                              ;049F6E|F010    |049F80;
    ORA.W #$000C                                                       ;049F70|090C00  |      ; get either 0D, 0E, or 0F
    JSR.W get_SRAM_offset_for_data_in_file_A_049F1F                    ;049F73|201F9F  |049F1F; kind of tricky, this uses an "implied pointer" to $018B5D
    TYA                                                                ;049F76|98      |      ; transfer size for MVN (either whole save file, or just metadata)
    TXY                                                                ;049F77|9B      |      ; address to WRITE TO for MVN
    LDX.W #$0000                                                       ;049F78|A20000  |      ; address to READ from for MVN
    PHB                                                                ;049F7B|8B      |      ;
    MVN $70,$70                                                        ;049F7C|547070  |      ;
    PLB                                                                ;049F7F|AB      |      ;
  + PLY                                                                ;049F80|7A      |      ;
    PLX                                                                ;049F81|FA      |      ;
    PLA                                                                ;049F82|68      |      ;
    RTS                                                                ;049F83|60      |      ;

get_chapter_number_to_print_on_screen_049F84:
    JSR.W get_X_index_for_current_text_page_block_num_04A056           ;049F84|2056A0  |04A056;
    JSR.W copy_curr_text_block_struct_at_SRAM_008_to_2D0_list_04A000   ;049F87|2000A0  |04A000;
    SEP #$30                                                           ;049F8A|E230    |      ;
    LDA.L SRAM_curr_chapter_index_to_text_block_num_list               ;049F8C|AF060070|700006;
    TAX                                                                ;049F90|AA      |      ;
    LDA.L SRAM_max_page_block_num_reached_overall                      ;049F91|AF070070|700007;
    TAY                                                                ;049F95|A8      |      ;
    REP #$30                                                           ;049F96|C230    |      ;
    TXA                                                                ;049F98|8A      |      ;
    BEQ RTS_with_X_0_Y_FFFF_049FB6                                     ;049F99|F01B    |049FB6;
    LDA.L SRAM_num_pages_in_curr_text_page_block                       ;049F9B|AF0F0070|70000F;
    AND.W #$007F                                                       ;049F9F|297F00  |      ;
    BNE +                                                              ;049FA2|D001    |049FA5;
    DEY                                                                ;049FA4|88      |      ;
  + DEY                                                                ;049FA5|88      |      ;
    BMI RTS_with_X_0_Y_FFFF_049FB6                                     ;049FA6|300E    |049FB6;
    DEX                                                                ;049FA8|CA      |      ;
    TYA                                                                ;049FA9|98      |      ;
    SEP #$30                                                           ;049FAA|E230    |      ;
    CMP.L SRAM_LIST_text_page_block_num_for_each_chapter,X             ;049FAC|DF500070|700050;
    REP #$30                                                           ;049FB0|C230    |      ;
    BCC RTS_049FB5                                                     ;049FB2|9001    |049FB5;
    INX                                                                ;049FB4|E8      |      ;
RTS_049FB5:
    RTS                                                                ;049FB5|60      |      ;
RTS_with_X_0_Y_FFFF_049FB6:
    LDX.W #$0000                                                       ;049FB6|A20000  |      ;
    TXY                                                                ;049FB9|9B      |      ;
    DEY                                                                ;049FBA|88      |      ;
    RTS                                                                ;049FBB|60      |      ;

increment_page_block_number_for_chapter_lookup_049FBC:
    SEP #$30                                                           ;049FBC|E230    |      ;
    LDA.L SRAM_curr_chapter_index_to_text_block_num_list               ;049FBE|AF060070|700006;
    TAX                                                                ;049FC2|AA      |      ;
    LDA.L SRAM_max_page_block_num_reached_overall                      ;049FC3|AF070070|700007;
    STA.L SRAM_LIST_text_page_block_num_for_each_chapter,X             ;049FC7|9F500070|700050;
    TXA                                                                ;049FCB|8A      |      ;
    INC A                                                              ;049FCC|1A      |      ;
    STA.L SRAM_curr_chapter_index_to_text_block_num_list               ;049FCD|8F060070|700006;
    REP #$30                                                           ;049FD1|C230    |      ;
    RTS                                                                ;049FD3|60      |      ;

write_curr_text_block_data_to_SRAM_and_init_new_block_049FD4:
    SEP #$20                                                           ;049FD4|E220    |      ;
    LDA.L SRAM_num_pages_in_curr_text_page_block                       ;049FD6|AF0F0070|70000F;
    AND.B #$7F                                                         ;049FDA|297F    |      ;
    STA.L SRAM_num_pages_in_curr_text_page_block                       ;049FDC|8F0F0070|70000F;
    REP #$20                                                           ;049FE0|C220    |      ;
    JSR.W get_X_index_for_current_text_page_block_num_04A056           ;049FE2|2056A0  |04A056;
    JSR.W copy_curr_text_block_struct_at_SRAM_008_to_2D0_list_04A000   ;049FE5|2000A0  |04A000;
    SEP #$20                                                           ;049FE8|E220    |      ;
    LDA.L SRAM_max_page_block_num_reached_overall                      ;049FEA|AF070070|700007; increment text page block number to a maximum of 0xA6
    INC A                                                              ;049FEE|1A      |      ; each save file is 0x800 bytes; (0x800 - 0x2D0) / 8 = 0xA6
    CMP.B #$A6                                                         ;049FEF|C9A6    |      ;
    BEQ +                                                              ;049FF1|F004    |049FF7;
    STA.L SRAM_max_page_block_num_reached_overall                      ;049FF3|8F070070|700007;
  + LDA.B #$00                                                         ;049FF7|A900    |      ;
    STA.L SRAM_num_pages_in_curr_text_page_block                       ;049FF9|8F0F0070|70000F;
    REP #$20                                                           ;049FFD|C220    |      ;
    RTS                                                                ;049FFF|60      |      ;

copy_curr_text_block_struct_at_SRAM_008_to_2D0_list_04A000:
    LDA.L SRAM_data_for_curr_page_block                                ;04A000|AF080070|700008;
    STA.L SRAM_data_struct_for_text_page_block_temp_flags,X            ;04A004|9FD00270|7002D0;
    LDA.L $70000A                                                      ;04A008|AF0A0070|70000A;
    STA.L $7002D2,X                                                    ;04A00C|9FD20270|7002D2;
    LDA.L $70000C                                                      ;04A010|AF0C0070|70000C;
    STA.L SRAM_LIST_ptr_to_start_of_text_page_block,X                  ;04A014|9FD40270|7002D4;
    LDA.L $70000E                                                      ;04A018|AF0E0070|70000E;
    STA.L $7002D6,X                                                    ;04A01C|9FD60270|7002D6;
    RTS                                                                ;04A020|60      |      ;

copy_curr_text_page_block_data_from_RAM_to_scratchpad_04A021:
    SEP #$20                                                           ;04A021|E220    |      ;
    LDA.L SRAM_num_pages_in_curr_text_page_block                       ;04A023|AF0F0070|70000F;
    STA.W $03CC                                                        ;04A027|8DCC03  |0103CC;
    REP #$20                                                           ;04A02A|C220    |      ;
    BRA +                                                              ;04A02C|8019    |04A047;
copy_curr_pg_block_data_with_inc_pg_ctr_to_scratchpad_04A02E:
    SEP #$20                                                           ;04A02E|E220    |      ;
    LDA.L SRAM_num_pages_in_curr_text_page_block                       ;04A030|AF0F0070|70000F;
    STA.W $03CC                                                        ;04A034|8DCC03  |0103CC;
    REP #$20                                                           ;04A037|C220    |      ;
    LDA.W #$0000                                                       ;04A039|A90000  |      ; check scratchpad save file's settings byte
    BRK #$1C                                                           ;04A03C|001C    |      ;
    db $1C                                                             ;04A03E|        |      ;
    AND.W #$0008                                                       ;04A03F|290800  |      ; if able to read prev text, increment copy of # pages in text block
    BNE +                                                              ;04A042|D003    |04A047;
    INC.W $03CC                                                        ;04A044|EECC03  |0103CC;
  + LDX.W #$0006                                                       ;04A047|A20600  |      ;
LOOP_04A04A:
    LDA.W $03C5,X                                                      ;04A04A|BDC503  |0103C5;
    STA.L SRAM_data_for_curr_page_block,X                              ;04A04D|9F080070|700008;
    DEX #2                                                             ;04A051|CA      |      ;
    BPL LOOP_04A04A                                                    ;04A053|10F5    |04A04A;
    RTS                                                                ;04A055|60      |      ;

get_X_index_for_current_text_page_block_num_04A056:
    LDA.L SRAM_max_page_block_num_reached_overall                      ;04A056|AF070070|700007;
    AND.W #$00FF                                                       ;04A05A|29FF00  |      ;
get_X_index_for_text_page_block_num_in_input_04A05D:
    PHA                                                                ;04A05D|48      |      ;
    ASL #3                                                             ;04A05E|0A      |      ; X <- text page block num << 3
    TAX                                                                ;04A061|AA      |      ;
    PLA                                                                ;04A062|68      |      ;
    RTS                                                                ;04A063|60      |      ;

read_prev_text_starting_from_curr_pos_04A064:
    LDA.W $03CF                                                        ;04A064|ADCF03  |0103CF;
    STA.W $03D3                                                        ;04A067|8DD303  |0103D3;
    LDA.W $03CD                                                        ;04A06A|ADCD03  |0103CD;
    STA.W $03D1                                                        ;04A06D|8DD103  |0103D1;
LOOP_04A070:
    DEC.W $03CF                                                        ;04A070|CECF03  |0103CF; check if need to read from previous text page block
    BNE +                                                              ;04A073|D00E    |04A083;
    DEC.W $03CD                                                        ;04A075|CECD03  |0103CD;
  ; BMI restore_03CF_03CD_and_SEC_RTS_04A089                           ;04A078|300F    |04A089;
    bmi restore_03CF_03CD_and_SEC_RTS_04A0C8
    JSR.W set_up_to_read_previous_text_04A0D6                          ;04A07A|20D6A0  |04A0D6;
    JSR.W get_num_pages_to_decompress_from_SRAM_04A13B                 ;04A07D|203BA1  |04A13B;
    STA.W $03CF                                                        ;04A080|8DCF03  |0103CF;
  + JSR.W read_entry_from_ptr_table_for_prev_text_SEC_if_failed_04A111 ;04A083|2011A1  |04A111;
    BCS LOOP_04A070                                                    ;04A086|B0E8    |04A070;
    RTS                                                                ;04A088|60      |      ;
; identical code block to what's below
; restore_03CF_03CD_and_SEC_RTS_04A089:
    ; LDA.W $03D3                                                        ;04A089|ADD303  |0103D3;
    ; STA.W $03CF                                                        ;04A08C|8DCF03  |0103CF;
    ; LDA.W $03D1                                                        ;04A08F|ADD103  |0103D1;
    ; STA.W $03CD                                                        ;04A092|8DCD03  |0103CD;
    ; SEC                                                                ;04A095|38      |      ;
    ; RTS                                                                ;04A096|60      |      ;

read_prev_text_from_chapter_in_list_04A097:
    LDA.W $03CF                                                        ;04A097|ADCF03  |0103CF;
    STA.W $03D3                                                        ;04A09A|8DD303  |0103D3;
    LDA.W $03CD                                                        ;04A09D|ADCD03  |0103CD;
    STA.W $03D1                                                        ;04A0A0|8DD103  |0103D1;
LOOP_04A0A3:
    INC.W $03CF                                                        ;04A0A3|EECF03  |0103CF; inc # pages decompressed
    JSR.W get_num_pages_to_decompress_from_SRAM_04A13B                 ;04A0A6|203BA1  |04A13B;
    CMP.W $03CF                                                        ;04A0A9|CDCF03  |0103CF;
    BCS +                                                              ;04A0AC|B014    |04A0C2; check if need to build pointer table
    INC.W $03CD                                                        ;04A0AE|EECD03  |0103CD;
    LDA.W $03D5                                                        ;04A0B1|ADD503  |0103D5;
    CMP.W $03CD                                                        ;04A0B4|CDCD03  |0103CD;
    BCC restore_03CF_03CD_and_SEC_RTS_04A0C8                           ;04A0B7|900F    |04A0C8;
    JSR.W set_up_to_read_previous_text_04A0D6                          ;04A0B9|20D6A0  |04A0D6;
    LDA.W #$0001                                                       ;04A0BC|A90100  |      ;
    STA.W $03CF                                                        ;04A0BF|8DCF03  |0103CF;
  + JSR.W read_entry_from_ptr_table_for_prev_text_SEC_if_failed_04A111 ;04A0C2|2011A1  |04A111;
    BCS LOOP_04A0A3                                                    ;04A0C5|B0DC    |04A0A3;
    RTS                                                                ;04A0C7|60      |      ;
restore_03CF_03CD_and_SEC_RTS_04A0C8:
    LDA.W $03D3                                                        ;04A0C8|ADD303  |0103D3;
    STA.W $03CF                                                        ;04A0CB|8DCF03  |0103CF;
    LDA.W $03D1                                                        ;04A0CE|ADD103  |0103D1;
    STA.W $03CD                                                        ;04A0D1|8DCD03  |0103CD;
    SEC                                                                ;04A0D4|38      |      ;
    RTS                                                                ;04A0D5|60      |      ;

set_up_to_read_previous_text_04A0D6:
    LDA.W $03CD                                                        ;04A0D6|ADCD03  |0103CD;
    JSR.W get_X_index_for_text_page_block_num_in_input_04A05D          ;04A0D9|205DA0  |04A05D;
    LDA.L SRAM_data_struct_for_text_page_block_temp_flags,X            ;04A0DC|BFD00270|7002D0;
    STA.W playthru_temp_flags                                          ;04A0E0|8DB10B  |010BB1;
    LDA.L $7002D2,X                                                    ;04A0E3|BFD20270|7002D2;
    STA.W $0BB3                                                        ;04A0E7|8DB30B  |010BB3;
    LDA.L SRAM_LIST_ptr_to_start_of_text_page_block,X                  ;04A0EA|BFD40270|7002D4;
    STA.B $08                                                          ;04A0EE|8508    |00123D;
    LDA.L $7002D5,X                                                    ;04A0F0|BFD50270|7002D5;
    STA.B $09                                                          ;04A0F4|8509    |00123E;
    STZ.B $0B                                                          ;04A0F6|640B    |001240;
    LDA.W $03CD                                                        ;04A0F8|ADCD03  |0103CD;
    JSR.W get_prog_flags_for_position_in_script_from_SRAM_04A168       ;04A0FB|2068A1  |04A168;
    LDA.W $03c1                                                        ;04A0FE|ADC103  |0103C1;
    PHA                                                                ;04A101|48      |      ;
    LDA.W #$8000                                                       ;04A102|A90080  |      ;
    STA.W $03c1                                                        ;04A105|8DC103  |0103C1;
    JSL.L read_prev_text_to_create_data_table_about_text_pages_009C60  ;04A108|22609C00|009C60;
    PLA                                                                ;04A10C|68      |      ;
    STA.W $03c1                                                        ;04A10D|8DC103  |0103C1;
    RTS                                                                ;04A110|60      |      ;

read_entry_from_ptr_table_for_prev_text_SEC_if_failed_04A111:
    LDA.W $03CF                                                        ;04A111|ADCF03  |0103CF;
    DEC A                                                              ;04A114|3A      |      ;
    ASL #4                                                             ;04A115|0A      |      ;
    TAX                                                                ;04A119|AA      |      ;
    LDA.W PrevTextPtrTable+1,X                                         ;04A11A|BD0107  |010701; see $009DE0, block for start of each chapter sets these to 0000
    BEQ SEC_RTS_04A139                                                 ;04A11D|F01A    |04A139;
    STA.B $09                                                          ;04A11F|8509    |00123E;
    LDA.W PrevTextPtrTable+0,X                                         ;04A121|BD0007  |010700;
    STA.B $08                                                          ;04A124|8508    |00123D;
    LDA.W PrevTextPtrTable+4,X                                         ;04A126|BD0407  |010704;
    STA.B $0B                                                          ;04A129|850B    |001240;
    LDA.W PrevTextPtrTable+6,X                                         ;04A12B|BD0607  |010706;
    STA.W playthru_temp_flags                                          ;04A12E|8DB10B  |010BB1;
    LDA.W PrevTextPtrTable+8,X                                         ;04A131|BD0807  |010708;
    STA.W $0BB3                                                        ;04A134|8DB30B  |010BB3;
    CLC                                                                ;04A137|18      |      ;
    RTS                                                                ;04A138|60      |      ;
SEC_RTS_04A139:
    SEC                                                                ;04A139|38      |      ;
    RTS                                                                ;04A13A|60      |      ;

get_num_pages_to_decompress_from_SRAM_04A13B:
    PHX                                                                ;04A13B|DA      |      ;
    LDA.W $03CD                                                        ;04A13C|ADCD03  |0103CD;
    INC A                                                              ;04A13F|1A      |      ;
    JSR.W get_X_index_for_text_page_block_num_in_input_04A05D          ;04A140|205DA0  |04A05D;
    LDA.L SRAM_LIST_num_pages_to_decompress_7002D7,X                   ;04A143|BFD70270|7002D7;
    AND.W #$007F                                                       ;04A147|297F00  |      ;
    PLX                                                                ;04A14A|FA      |      ;
    RTS                                                                ;04A14B|60      |      ;

copy_prog_flags_from_scratchpad_to_src_save_file_04A14C:
    ASL #3                                                             ;04A14C|0A      |      ;
    TAX                                                                ;04A14F|AA      |      ;
    LDY.W #$0000                                                       ;04A150|A00000  |      ;
LOOP_04A153:
    PHX                                                                ;04A153|DA      |      ;
    TYX                                                                ;04A154|BB      |      ;
    LDA.L SRAM_file_progress_flags_SCRATCHPAD_ONLY,X                   ;04A155|BF180070|700018;
    PLX                                                                ;04A159|FA      |      ;
    STA.L SRAM_progress_flags_0C8,X                                    ;04A15A|9FC80070|7000C8;
    INX #2                                                             ;04A15E|E8      |      ;
    INY #2                                                             ;04A160|C8      |      ;
    CPY.W #$0008                                                       ;04A162|C00800  |      ;
    BNE LOOP_04A153                                                    ;04A165|D0EC    |04A153;
    RTS                                                                ;04A167|60      |      ;

get_prog_flags_for_position_in_script_from_SRAM_04A168:
    SEP #$30                                                           ;04A168|E230    |      ;
    PHA                                                                ;04A16A|48      |      ;
    LDA.L SRAM_curr_chapter_index_to_text_block_num_list               ;04A16B|AF060070|700006;
    TAX                                                                ;04A16F|AA      |      ;
    PLA                                                                ;04A170|68      |      ;
LOOP_04A171:
    DEX                                                                ;04A171|CA      |      ;
    CMP.L SRAM_LIST_text_page_block_num_for_each_chapter,X             ;04A172|DF500070|700050;
    BCC LOOP_04A171                                                    ;04A176|90F9    |04A171;
    REP #$30                                                           ;04A178|C230    |      ;
    TXA                                                                ;04A17A|8A      |      ;
    ASL #3                                                             ;04A17B|0A      |      ;
    TAX                                                                ;04A17E|AA      |      ;
    LDY.W #$0000                                                       ;04A17F|A00000  |      ;
LOOP_04A182:
    LDA.L SRAM_progress_flags_0C8,X                                    ;04A182|BFC80070|7000C8;
    PHX                                                                ;04A186|DA      |      ;
    TYX                                                                ;04A187|BB      |      ;
    STA.L SRAM_file_progress_flags_SCRATCHPAD_ONLY,X                   ;04A188|9F180070|700018;
    PLX                                                                ;04A18C|FA      |      ;
    INX #2                                                             ;04A18D|E8      |      ;
    INY #2                                                             ;04A18F|C8      |      ;
    CPY.W #$0008                                                       ;04A191|C00800  |      ;
    BNE LOOP_04A182                                                    ;04A194|D0EC    |04A182;
    RTS                                                                ;04A196|60      |      ;

SUB_for_BRK_1C_05_04A197:
    LDX.W #$0001                                                       ;04A197|A20100  |      ;
    LDA.W $0300                                                        ;04A19A|AD0003  |010300;
    LSR A                                                              ;04A19D|4A      |      ;
    CMP.W #$0004                                                       ;04A19E|C90400  |      ;
    BEQ +                                                              ;04A1A1|F001    |04A1A4;
    INX                                                                ;04A1A3|E8      |      ;
  + STX.W $03c1                                                        ;04A1A4|8EC103  |0103C1;
    BRK #$01                                                           ;04A1A7|0001    |      ;
    db $4A                                                             ;04A1A9|        |      ;
    BRK #$00                                                           ;04A1AA|0000    |      ;
    dw $2000                                                           ;04A1AC|        |      ;
    RTS                                                                ;04A1AE|60      |      ;
