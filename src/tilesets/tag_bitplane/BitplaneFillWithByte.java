package tilesets.tag_bitplane;

import static tilesets.constants.TileCompConstants.FILL_BP_WITH_00;
import static tilesets.constants.TileCompConstants.FILL_BP_WITH_BYTE;
import static tilesets.constants.TileCompConstants.FILL_BP_WITH_FF;
import static tilesets.constants.TileCompConstants.NUM_ROWS_PER_TILE;
import static tilesets.constants.TileCompConstants.getVersionOfSubIdWithSpotChanges;

import java.util.ArrayList;

public class BitplaneFillWithByte extends BitplaneCompressionTag {
    private int value;

    public BitplaneFillWithByte(int bitplane[], int value) {
        this.bitplane = bitplane;
        this.value = value;

        int canonical[] = new int[NUM_ROWS_PER_TILE];
        for (int i = 0; i < canonical.length; i++) {
            canonical[i] = value;
        }
        this.spotChanges = new BitplaneSpotChanges(bitplane, canonical);
    }

    public ArrayList<Integer> encodeData() {
        ArrayList<Integer> output = new ArrayList<>();
        if (value != 0x00 && value != 0xFF) {
            output.add(value);
        }
        output.addAll(spotChanges.getEncodedData());
        return output;
    }

    public int getBitplaneIndex() {
        int index = 0;
        switch (value) {
            case 0x00: index = FILL_BP_WITH_00; break;
            case 0xFF: index = FILL_BP_WITH_FF; break;
            default:   index = FILL_BP_WITH_BYTE; break;
        }
        if (spotChanges.spotChangesNeeded()) {
            index = getVersionOfSubIdWithSpotChanges(index);
        }
        return index;
    }

    public int getSizeWhenEncoded() {
        return encodeData().size();
    }

    public String toString() {
        String output = String.format("Fill with %02X", value);
        output += spotChanges.toString();
        return output;
    }
}
