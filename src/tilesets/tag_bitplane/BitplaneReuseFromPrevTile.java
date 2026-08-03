package tilesets.tag_bitplane;

import static tilesets.constants.TileCompConstants.COPY_BP_FROM_PREV_TILE;
import static tilesets.constants.TileCompConstants.NUM_ROWS_PER_TILE;
import static tilesets.constants.TileCompConstants.getVersionOfSubIdWithSpotChanges;

import java.util.ArrayList;

public class BitplaneReuseFromPrevTile extends BitplaneCompressionTag {
    private int srcTileNum;
    private int srcBitplaneNum;
    private int srcBitplane[];
    private boolean reverse;

    public BitplaneReuseFromPrevTile(int bitplane[], int srcTileNum, int srcBitplaneNum, int srcBitplane[], boolean reverse) {
        this.bitplane = bitplane;
        this.srcTileNum = srcTileNum;
        this.srcBitplane = srcBitplane;
        this.srcBitplaneNum = srcBitplaneNum;
        this.reverse = reverse;

        spotChanges = new BitplaneSpotChanges(bitplane, getCanonicalSrcBitplane());
    }

    private int[] getCanonicalSrcBitplane() {
        int canonicalBitplane[] = new int[NUM_ROWS_PER_TILE];
        int direction = !reverse ? 1 : -1;
        int index = !reverse ? 0 : NUM_ROWS_PER_TILE - 1;

        for (int i = 0; i < NUM_ROWS_PER_TILE; i++) {
            canonicalBitplane[i] = srcBitplane[index];
            index += direction;
        }
        return canonicalBitplane;
    }

    public ArrayList<Integer> encodeData() {
        ArrayList<Integer> data = new ArrayList<>();

        // first byte contains reverse flag, src bitplane #, bits 8-9 of src tile #
        int flagsByte = (srcTileNum >> 8) & 0x3;
        flagsByte |= (srcBitplaneNum & 0x3) << 2;
        flagsByte |= reverse ? 0x80 : 0x00;
        data.add(flagsByte);

        data.add(srcTileNum & 0xFF);

        data.addAll(spotChanges.getEncodedData());

        return data;
    }
    public int getBitplaneIndex() {
        int index = COPY_BP_FROM_PREV_TILE;
        if (spotChanges.spotChangesNeeded()) {
            index = getVersionOfSubIdWithSpotChanges(index);
        }
        return index;
    }

    public int getSizeWhenEncoded() {
        return spotChanges.getEncodedData().size() + 2;
    }

    public String toString() {
        String output = String.format("Reuse tile %03X bp%d%s", srcTileNum, srcBitplaneNum,
            (reverse ? " (reversed)" : ""));
        return output + spotChanges.toString();
    }
}
