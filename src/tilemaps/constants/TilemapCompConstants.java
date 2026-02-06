package tilemaps.constants;

public class TilemapCompConstants {
    public static final int TILEMAP_ENTRY_SIZE = 2;
    public static final int NUM_TILES_IN_ROW = 0x20;
    public static final int NUM_TILES_IN_COL = 0x1C;
    public static final int NUM_TILEMAP_ENTRIES = NUM_TILES_IN_ROW * NUM_TILES_IN_COL;
    public static final int TILEMAP_BYTES = NUM_TILEMAP_ENTRIES * TILEMAP_ENTRY_SIZE;

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

    public static final int STARTING_LOW_BYTE = 0x01;
    public static final int REPEAT_CASE_MIN_SIZE = 2;
    public static final int INC_SEQ_SIZE_THRESHOLD_3F = 0x3F;

    public static final int HIGH_BITS_00_RUN_THRESHOLD_08 = 0x8;
    public static final int HIGH_BITS_REPEAT_VAL_THRESHOLD_09 = 0x9;

    public static int getThresholdFor00sAfterNewPaletteXyValue(boolean checkingPalettes) {
        return checkingPalettes ? 0x4 : 0x8;
    }

    public static int getThresholdForRepeatNewPaletteXY(boolean checkingPalettes) {
        return checkingPalettes ? 0x5 : 0x9;
    }
}
