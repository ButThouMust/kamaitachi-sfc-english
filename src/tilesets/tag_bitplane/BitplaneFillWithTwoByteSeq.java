package tilesets.tag_bitplane;

import static tilesets.constants.TileCompConstants.FILL_BP_WITH_TWO_BYTE_SEQ;
import static tilesets.constants.TileCompConstants.FILL_BP_WITH_TWO_BYTE_SEQ_SPOT_CHANGES;
import static tilesets.constants.TileCompConstants.NUM_ROWS_PER_TILE;

import java.util.ArrayList;

public class BitplaneFillWithTwoByteSeq extends BitplaneCompressionTag {
    private int value0;
    private int value1;

    public BitplaneFillWithTwoByteSeq(int bitplane[], int value0, int value1) {
        this.value0 = value0;
        this.value1 = value1;
        spotChanges = new BitplaneSpotChanges(bitplane, getCanonicalData());
    }

    public int[] getCanonicalData() {
        int canonical[] = new int[NUM_ROWS_PER_TILE];
        for (int i = 0; i < canonical.length / 2; i++) {
            canonical[i*2] = value0;
            canonical[i*2 + 1] = value1;
        }
        return canonical;
    }

    public ArrayList<Integer> encodeData() {
        ArrayList<Integer> data = new ArrayList<>();
        data.add(value0);
        data.add(value1);
        data.addAll(spotChanges.getEncodedData());
        return data;
    }

    public int getBitplaneIndex() {
        int index = FILL_BP_WITH_TWO_BYTE_SEQ;
        if (spotChanges.spotChangesNeeded()) {
            index = FILL_BP_WITH_TWO_BYTE_SEQ_SPOT_CHANGES;
        }
        return index;
    }

    public int getSizeWhenEncoded() {
        return spotChanges.getEncodedData().size() + 2;
    }

    public String toString() {
        String output = String.format("Construct from two-byte sequence [%02X %02X]", value0, value1);
        return output + spotChanges.toString();
    }
}
