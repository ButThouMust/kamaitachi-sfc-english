package tilesets.tag_tile;

import java.util.ArrayList;

import static tilesets.constants.TileCompConstants.BIT_DEPTH;
import static tilesets.constants.TileCompConstants.NUM_ROWS_PER_TILE;

public class TileReuseWithNewRowsTag extends TileCompressionTag {
    private int rowFlags;
    private int srcTileNum;

    private static final int BITMASK = 0x09;

    // the best possible case for rows is if only one row is different, which
    // would require encoding 1 byte of flags and the 4 bytes of the row
    public static final int BEST_SIZE = 1 + BIT_DEPTH;

    public TileReuseWithNewRowsTag(int currTileNum, int bpData[][], int srcTileNum, int rowFlags) {
        tileNum = currTileNum;
        this.srcTileNum = srcTileNum;
        this.bpData = bpData;
        this.rowFlags = rowFlags;
    }

    @Override
    protected void encodeData() {
        encodedData = new ArrayList<>();

        int typeByte = BITMASK;
        typeByte |= (srcTileNum >> 4) & 0x30;
        encodedData.add(typeByte);
        encodedData.add(srcTileNum & 0xFF);

        encodedData.add(rowFlags);

        for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
            // example: if row 0 is different, bit 7 will be set
            int rowFlag = rowFlags & (0x80 >> r);
            if (rowFlag == 0) continue;

            encodedData.add(bpData[0][r]);
            encodedData.add(bpData[1][r]);
            encodedData.add(bpData[2][r]);
            encodedData.add(bpData[3][r]);
        }
    }

    @Override
    public int getNumBytesSavedFromUsingMetadata() {
        return 0;
    }

    public String toString() {
        String output = super.toString();
        output += String.format("Reuse tile %03X with new rows (flags %02X)", srcTileNum, rowFlags);
        return output;
    }
}
