package tilesets.tag_bitplane;

import static tilesets.constants.TileCompConstants.FILL_BP_WITH_FOUR_BYTE_SEQ;

import java.util.ArrayList;

public class BitplaneFillWithFourByteSeq extends BitplaneCompressionTag {
    // private int values[];

    public BitplaneFillWithFourByteSeq(int bitplane[]) {
        this.bitplane = bitplane;
        spotChanges = null;
    }

    public ArrayList<Integer> encodeData() {
        ArrayList<Integer> data = new ArrayList<>();
        for (int i = 0; i < 4; i++) {
            data.add(bitplane[i]);
        }
        return data;
    }

    public int getBitplaneIndex() {
        return FILL_BP_WITH_FOUR_BYTE_SEQ;
    }

    public int getSizeWhenEncoded() {
        return 4;
    }

    public String toString() {
        String output = String.format("Construct from four-byte sequence [%02X %02X %02X %02X]",
            bitplane[0], bitplane[1], bitplane[2], bitplane[3]);
        return output;
    }
}
