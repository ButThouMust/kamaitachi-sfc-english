package tilemaps.constants;

public class TilemapCompConstants {
    public static final String RECOMPRESSED_FILE_PREFIX = "RECOMPRESSED ";

    public static final int TILEMAP_ENTRY_SIZE = 2;
    public static final int NUM_TILES_IN_ROW = 0x20;
    public static final int NUM_TILES_IN_COL = 0x1C;
    public static final int NUM_TILEMAP_ENTRIES = NUM_TILES_IN_ROW * NUM_TILES_IN_COL;
    public static final int TILEMAP_BYTES = NUM_TILEMAP_ENTRIES * TILEMAP_ENTRY_SIZE;

    public static final int ONE_BYTE_FOR_COMP_BLOCK_FLAGS = 1;
    public static final int FLAG_COMP_LOW_BYTES = 0x1;
    public static final int FLAG_COMP_HIGH_BITS = 0x2;
    public static final int FLAG_COMP_PALETTES = 0x4;
    public static final int FLAG_COMP_XY_BITS = 0x8;

    public static final int HIGH_BITS_BITMASK = 0x03;
    public static final int PALETTE_BITMASK = 0x1C;
    public static final int XY_FLIP_BITMASK = 0xC0;

    public static final int NUM_TWO_BIT_VALS_IN_BUFFER = 4;
    public static final int NUM_THREE_BIT_VALS_IN_BUFFER = 8;
    public static final int NUM_BYTES_IN_PALETTE_BUFFER = 3;

    public static final boolean USING_PALETTES = true;
    public static final boolean USING_X_Y_FLIP = false;

    // packing 0x380 two-bit values into 0x380 * 2 / 8 = 0xE0 bytes
    public static final int NUM_BYTES_FOR_ALL_BITPACKED_TWO_BIT_VALS =
        NUM_TILEMAP_ENTRIES / NUM_TWO_BIT_VALS_IN_BUFFER;

    // packing 0x380 three-bit values into 0x380 * 3 / 8 = 0x150 bytes
    public static final int NUM_BYTES_FOR_ALL_BITPACKED_THREE_BIT_VALS =
        NUM_TILEMAP_ENTRIES * NUM_BYTES_IN_PALETTE_BUFFER / NUM_THREE_BIT_VALS_IN_BUFFER;

    public static final int CASE_NOT_VALID = 0;
    public static final int TAG_SIZE_LIMIT_100 = 0x100;

    // -------------------------------------------------------------------------
    // in updated compression formats for high bits, palettes, and X/Y flips,
    // I shift up the range for the single-byte "run of 00s" case from 0x01-0x3F
    // to 0x02-0x40
    public static final int RUN_00_MIN_SIZE_ORIGINAL_1 = 1;
    public static final int RUN_00_MIN_SIZE_UPDATED_2 = RUN_00_MIN_SIZE_ORIGINAL_1 + 1;

    public static final int RUN_00_THRESHOLD_ORIGINAL_3F = 0x3F;
    public static final int RUN_00_THRESHOLD_UPDATED_40 = RUN_00_THRESHOLD_ORIGINAL_3F + 1;

    public static final boolean USE_RUN_00_RANGE_ORIGINAL = true;
    public static final boolean USE_RUN_00_RANGE_UPDATED = false;

    public static int getRun00MinSize(boolean useOriginalRange) {
        return useOriginalRange ? RUN_00_MIN_SIZE_ORIGINAL_1 : RUN_00_MIN_SIZE_UPDATED_2;
    }

    public static int getRun00Threshold(boolean useOriginalRange) {
        return useOriginalRange ? RUN_00_THRESHOLD_ORIGINAL_3F : RUN_00_THRESHOLD_UPDATED_40;
    }

    // -------------------------------------------------------------------------
    // constants for low bytes

    public static final int REPEAT_CASE_MIN_SIZE = 2; // common to low, high, palettes, X/Y

    public static final int STARTING_LOW_BYTE = 0x01;
    public static final int INC_SEQ_SIZE_THRESHOLD_3F = 0x3F;
    public static final int REUSE_LOW_BYTE_SIZE_LIMIT_20 = 0x20;
    public static final int REPEAT_NEW_LOW_BYTE_THRESHOLD_20 = 0x1E + REPEAT_CASE_MIN_SIZE;
    public static final int REPEAT_CURR_ID_LIMIT_41 = REPEAT_CASE_MIN_SIZE + 0x3F;

    // constants for new cases for low bytes
    public static final int DEC_SEQ_MIN_LENGTH_02 = 0x2;
    public static final int DEC_SEQ_MAX_LENGTH_10 = 0x10;
    public static final int SET_CURR_ID_SIZE = 2;
    public static final int ISOLATED_INC_SEQ_MIN_LENGTH_02 = 0x2;
    public static final int ISOLATED_INC_SEQ_MAX_LENGTH_05 = 0x5;

    // -------------------------------------------------------------------------
    // constants for high bits

    public static final int HIGH_BITS_00_RUN_THRESHOLD_08 = 0x8;
    public static final int HIGH_BITS_REPEAT_VAL_THRESHOLD_09 = 0x9;

    public static final int HIGH_BITS_MAX_00_RUN_AFTER_VAL_28 = 0x28; // 1 + 8 + 1f
    public static final int HIGH_BITS_MAX_REPEAT_LENGTH_29 = 0x29;    // 2 + 8 + 1f

    // -------------------------------------------------------------------------
    // constants for palettes and X/Y flip

    public static final int SIZE_LIMIT_REUSE_PALETTE_XY_CASES = 0x10;

    public static int getThresholdFor00sAfterNewPaletteXyValue(boolean checkingPalettes) {
        return checkingPalettes ? 0x4 : 0x8;
    }
    public static int getSizeLimitFor00sAfterNewPaletteXyValue(boolean checkingPalettes) {
        // return checkingPalettes ? 0x14 : 0x18;
        return 0x10 + getThresholdFor00sAfterNewPaletteXyValue(checkingPalettes);
    }

    public static int getThresholdForRepeatNewPaletteXY(boolean checkingPalettes) {
        return checkingPalettes ? 0x5 : 0x9;
    }
    public static int getSizeLimitForRepeatNewPaletteXyValue(boolean checkingPalettes) {
        // return checkingPalettes ? 0x15 : 0x19;
        return 0x10 + getThresholdForRepeatNewPaletteXY(checkingPalettes);
    }
}
