package header_files;

public class TextConstants {

    // constants for control code argument table
    public static final int NUM_CTRL_CODES = 0x63;
    public static final int CTRL_CODE_ARG_TBL = 0x0A901;
    public static final int CHAR_ARG = 0;
    public static final int PTR_ARG = 1;

    public static final int MIN_CTRL_CODE_ID = 0x1000;

    // control codes for special cases when interpretting or when printing scripts
    public static final int MIN_CTRL_CODE = 0x1000;
    public static final int AUTO_ADV_02 = 0x1002;
    public static final int LINE_0E = 0x100E;
    public static final int JMP_0F = 0x100F;
    public static final int JMP_10 = 0x1010;
    public static final int JMP_11 = 0x1011;
    public static final int JMP_12 = 0x1012;
    // public static final int END_CHOICE_15 = 0x1015;
    public static final int END_GAME_18 = 0x1018;
    public static final int TOURU_1B = 0x101B;
    public static final int MARI_1C = 0x101C;
    public static final int CULPRIT_GUESS_1D = 0x101D;
    public static final int CULPRIT_GUESS_1E = 0x101E;
    public static final int CULPRIT_GUESS_1F = 0x101F;
    public static final int SET_FLAG_20 = 0x1020;
    public static final int CLEAR_FLAG_21 = 0x1021;
    public static final int SET_TEMP_FLAG_22 = 0x1022;
    public static final int CLEAR_TEMP_FLAG_23 = 0x1023;
    public static final int CLEAR_25  = 0x1025;
    // public static final int CLEAR_27  = 0x1027;
    public static final int CHOICE_50 = 0x1050;
    public static final int CHOICE_51 = 0x1051;
    public static final int CHOICE_52 = 0x1052;
    public static final int CHOICE_53 = 0x1053;
    public static final int CHOICE_54 = 0x1054;
    public static final int CHOICE_55 = 0x1055;
    public static final int CHOICE_56 = 0x1056;
    public static final int CHOICE_57 = 0x1057;
    public static final int PERIOD_58 = 0x1058;
    public static final int R_QUOTE_59 = 0x1059;
    public static final int R_IN_QUOTE_5A = 0x105A;
    public static final int COMMA_5B = 0x105B;
    public static final int EXCL_5C = 0x105C;
    public static final int QUES_5D = 0x105D;
    public static final int L_QUOTE_60 = 0x1060;
    public static final int L_IN_QUOTE_61 = 0x1061;

    // note: these two control codes respectively output an exclamation mark or
    // a question mark to the text buffer, with nothing after it
    // so nearly useless, but 105E does get used in the game
    public static final int EXCL_5E = 0x105E;
    public static final int QUES_5F = 0x105F;

    // 
    public static final int NUM_ENCODINGS = 2000;

    // constants related to Huffman encoding for script
    public static final String LEFT_BIT = "0";
    public static final String RIGHT_BIT = "1";
    public static final int LEFT_BIT_INT = 0;
    public static final int RIGHT_BIT_INT = 1;
    public static final int NO_HEX_VAL = -1;

    public static final int MAX_NUM_HUFFMAN_ENTRIES = 0x6F2;
    // public static final int ROOT_ENTRY_POS = NUM_HUFFMAN_ENTRIES - 1;
    // public static final int HUFF_LEFT_OFFSET = 0x9952;
    // public static final int HUFF_RIGHT_OFFSET = 0x8B6E;

    // There are five points that the game can go to for demo mode
    //   see the list of five 21+3 bit pointers at $018359
    public static final int ATTRACT_MODE_PTRS_LOCATION = 0x8359;
    public static final int NUM_ATTRACT_MODE_START_POINTS = 5;
    public static final int NUM_POINTERS_TOTAL = 750;

    // There are eight special pointers for the game:
    // - two for the script overall (assume to reuse in the final patch)
    //   [08 E7] at $008B0A, and [2F 00] at $008B10; 2FE708 -> $05FCE1-0 (2FCE1)
	//   [08 E7] at $009C2F, and [2F]    at $009C38; 2FE708 -> $05FCE1-0 (2FCE1)
    //   (second one was not discovered until later, so in ASM hack, I just
    //    hard-code reusing the value of the first one)
    //
    // - one for going to title screen from letting attract/demo mode finish
    //   [B1 E7] at $01CE6D, and [2F 00] at $01CE73; 2FE7B1 -> $05FCF6-1
    //
    // - three for going to file select (Chunsoft logo, title screen, demo mode)
    //   [0D E8] at $008AA6, and [2F 00] at $008AAC; 2FE80D -> $05FD01-5
    //   [0D E8] at $008E5D, and [2F 00] at $008E63
    //   [0D E8] at $01CE7E, and [2F 00] at $01CE84
    //
    // - two that go to all the "clear temp flag" codes section before main text
    //   [89 F1] at $008F44, and [2F 00] at $008F4A; 2FF189 -> $05FE31-1
    //   [89 F1] at $049A6C, and [2F 00] at $049A72 (location not set in stone for patched game!)
    public static final int[] SPECIAL_POINTERS_BANK_OFFSET_LOCATIONS = {0xAA6, 0xB0A, 0xE5D, 0xF44, 0xCE6D, 0xCE7E, 0x21A6C};
    public static final int[] SPECIAL_POINTERS_BANK_NUMBER_LOCATIONS = {0xAAC, 0xB10, 0xE63, 0xF4A, 0xCE73, 0xCE84, 0x21A72};
    public static final int NUM_SPECIAL_POINTERS = SPECIAL_POINTERS_BANK_OFFSET_LOCATIONS.length;
    public static final int INDEX_FOR_FIRST_SPECIAL_POINTER = NUM_ATTRACT_MODE_START_POINTS;
    public static final int NUM_POINTERS_OUTSIDE_SCRIPT = NUM_ATTRACT_MODE_START_POINTS + NUM_SPECIAL_POINTERS;

    public static boolean isCtrlCode(int charEncoding) {
        return charEncoding >= MIN_CTRL_CODE;
    }

    public static boolean isChoiceCode(int charEncoding) {
        return charEncoding >= CHOICE_50 && charEncoding <= CHOICE_57;
    }
}
