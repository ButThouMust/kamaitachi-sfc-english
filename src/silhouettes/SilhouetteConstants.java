package silhouettes;

public class SilhouetteConstants {
    public static final int NUM_SILH_CTRL_CODE_IDS = 0x2F6;
    public static final int SILH_BUFFER_SIZE = 0x2000;

    public static final int END_OF_DATA = 0x00;
    public static final int CHUNSOFT_BANK_ADV = 0x40;
    public static final int BANK_SIZE = 0x8000;

    public static final int SILH_GFX_PTR_TABLE = 0x25BA5E; // $4BBA5E

    public static final int GOLD_BOOKMARK_SHINE_GFX_PTR = 0x1F0C0;

    public static final String JP_ROM_FILEPATH = "rom/Kamaitachi no Yoru (Japan).sfc";

    public static int getRomPtr(int cpuPtr) {
        int bankNum = cpuPtr >> 16;
        int bankOffset = cpuPtr & 0xFFFF;
        return (bankNum - 1) * BANK_SIZE + bankOffset;
    }
}
