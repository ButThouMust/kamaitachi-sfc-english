package tilesets.tag_bitplane;

import static tilesets.constants.TileCompConstants.RLE_BITPLANE;

import java.util.ArrayList;

public class BitplaneFillFromRLE extends BitplaneCompressionTag {
    private int rleFlags;
    private int groupBytes[];
    private int indices[];

    public BitplaneFillFromRLE(int bitplane[], int indices[]) {
        this.bitplane = bitplane;
        this.indices = indices;
        spotChanges = null;

        getRleFlags();
        getGroupBytes();
    }

    private void getRleFlags() {
        rleFlags = 0x00;
        for (int i = 0; i < indices.length; i++) {
            rleFlags |= 0x80 >> indices[i];
        }
    }

    private void getGroupBytes() {
        groupBytes = new int[indices.length];
        for (int i = 0; i < indices.length; i++) {
            groupBytes[i] = bitplane[indices[i]];
        }
    }

    public ArrayList<Integer> encodeData() {
        ArrayList<Integer> data = new ArrayList<>();
        data.add(rleFlags);
        for (int value : groupBytes) {
            data.add(value);
        }
        return data;
    }

    public int getSizeWhenEncoded() {
        int arrayListSize = encodeData().size();
        return arrayListSize;
    }

    public int getBitplaneIndex() {
        return RLE_BITPLANE;
    }

    public String toString() {
        String output = String.format("Construct from RLE (flags %02X): values", rleFlags);
        for (int i = 0; i < groupBytes.length; i++) {
            output += String.format(" %02X", groupBytes[i]);
        }
        return output;
    }
}
