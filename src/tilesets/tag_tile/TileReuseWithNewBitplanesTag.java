package tilesets.tag_tile;

import java.util.ArrayList;

import static tilesets.constants.TileCompConstants.NUM_ROWS_PER_TILE;
import static tilesets.constants.TileCompConstants.BIT_DEPTH;

public class TileReuseWithNewBitplanesTag extends TileCompressionTag {
    private int bitplaneFlags;
    private int srcTileNum;
    private int flagsForBytesInBitplane[];

    private static final int BITMASK = 0x40;

    // the best possible case for bitplanes is if both only one bitplane is
    // different, and if only one byte in that bitplane is different
    public static final int BEST_SIZE = 1 + 1;

    public TileReuseWithNewBitplanesTag(int currTileNum, int bpData[][], int srcTileNum, int flagsForBytesInBitplane[], int bitplaneFlags) {
        tileNum = currTileNum;
        this.srcTileNum = srcTileNum;

        this.bpData = bpData;
        this.flagsForBytesInBitplane = flagsForBytesInBitplane;

        this.bitplaneFlags = bitplaneFlags;
    }

    @Override
    protected void encodeData() {
        encodedData = new ArrayList<>();

        int typeByte = BITMASK;
        typeByte |= (srcTileNum >> 8) & 0x3;
        typeByte |= (bitplaneFlags & 0xF) << 2;
        encodedData.add(typeByte);

        encodedData.add(srcTileNum & 0xFF);

        // write all of the flags, and THEN write the data bytes to insert
        for (int bp = 0; bp < BIT_DEPTH; bp++) {
            int flags = flagsForBytesInBitplane[bp];
            boolean bpDifferent = flags != 0x00;
            if (!bpDifferent) continue;

            encodedData.add(flags);
        }
        for (int bp = 0; bp < BIT_DEPTH; bp++) {
            int flags = flagsForBytesInBitplane[bp];
            boolean bpDifferent = flags != 0x00;
            if (!bpDifferent) continue;

            for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
                int bit = flags & (0x80 >> r);
                if (bit != 0) {
                    encodedData.add(bpData[bp][r]);
                }
            }
        }
    }

    public int[] getFlagsForBytesInEachBitplane() {
        return flagsForBytesInBitplane;
    }

    @Override
    public int getNumBytesSavedFromUsingMetadata() {
        return 0;
    }

    public String toString() {
        String output = super.toString();
        output += String.format("Reuse tile %03X with new bitplanes", srcTileNum);
        String flags = "\n- Per BP flags:";
        for (int bp = 0; bp < BIT_DEPTH; bp++) {
            if ((bitplaneFlags & (0x08 >> bp)) != 0) {
                output += " " + bp;
            }
            int byteFlags = flagsForBytesInBitplane[bp];
            flags += (byteFlags == 0x00) ? " --" : String.format(" %02X", byteFlags);
        }
        return output + flags;
    }
}
