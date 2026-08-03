
package header_files;

public class HelperMethods {

    public static final int NUM_BITS_IN_BYTE = 8;
    public static final int NUM_BYTES_IN_PTR = 3;
    public static final int NUM_BITS_IN_PTR = NUM_BITS_IN_BYTE * NUM_BYTES_IN_PTR;

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    // convert a LoROM offset into a "hex editor" file offset
    public static int getFileOffset(int ramOffset) {
        int bankNum = (ramOffset >> 16) & 0xFF;
        int bankOffset = ramOffset & 0xFFFF;
        return 0x8000 * (bankNum - 1) + bankOffset;
    }

    public static int getRAMOffset(int fileOffset) {
        int bankOffset = (fileOffset & 0xFFFF) | 0x8000;
        int bankNum = 1 + (fileOffset - bankOffset) / 0x8000;
        return (bankNum << 16) | bankOffset;
    }

    public static boolean isValidRomOffset(int ramOffset) {
        // Kamaitachi no Yoru is a LoROM game
        // bank offset must be in range 0x8000 - 0xFFFF
        int bankOffset = ramOffset & 0xFFFF;
        // int bankNum = (ramOffset >> 16) & 0xFF;

        return bankOffset >= 0x8000;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    public static String removeFileExtension(String filename) {
        int periodIndex = filename.lastIndexOf('.');
        return periodIndex == -1 ? filename : filename.substring(0, periodIndex);
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    public static int convertBGR15ToRGB24(int colorValue15) {
        // convert 15-bit BGR to 24-bit RGB
        // 0 BBBBB GGGGG RRRRR -> RRRRRRRR GGGGGGGG BBBBBBBB
        // source: https://wiki.superfamicom.org/palettes
        int red5 = colorValue15 & 0x1F;
        int green5 = (colorValue15 >> 5) & 0x1F;
        int blue5 = (colorValue15 >> 10) & 0x1F;

        int red8 = red5 << 3;
        int green8 = green5 << 3;
        int blue8 = blue5 << 3;

        red8 += red8 >> 5;
        green8 += green8 >> 5;
        blue8 += blue8 >> 5;
        int colorValue24 = (red8 << 16) | (green8 << 8) | blue8;
        return colorValue24;
    }
}
