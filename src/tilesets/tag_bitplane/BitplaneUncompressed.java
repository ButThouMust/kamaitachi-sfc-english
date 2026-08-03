package tilesets.tag_bitplane;

import static tilesets.constants.TileCompConstants.NUM_ROWS_PER_TILE;
import static tilesets.constants.TileCompConstants.READ_8_RAW_BYTES;

import java.util.ArrayList;

public class BitplaneUncompressed extends BitplaneCompressionTag {

    public BitplaneUncompressed(int bitplane[]) {
        this.bitplane = bitplane;
        spotChanges = null;
    }

    public ArrayList<Integer> encodeData() {
        ArrayList<Integer> data = new ArrayList<>();
        for (int value : bitplane) {
            data.add(value);
        }
        return data;
    }
    public int getBitplaneIndex() {
        return READ_8_RAW_BYTES;
    }

    public int getSizeWhenEncoded() {
        return NUM_ROWS_PER_TILE;
    }

    public String toString() {
        String output = String.format("8 raw bytes");
        return output;
    }
}
