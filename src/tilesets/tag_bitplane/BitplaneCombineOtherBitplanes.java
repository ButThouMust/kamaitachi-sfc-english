package tilesets.tag_bitplane;

import static tilesets.constants.TileCompConstants.getVersionOfSubIdWithSpotChanges;

import java.util.ArrayList;

import tilesets.constants.TileCompConstants;

public class BitplaneCombineOtherBitplanes extends BitplaneCompressionTag {
    private int index;

    public BitplaneCombineOtherBitplanes(int index, int bitplane[], int canonicalData[]) {
        this.bitplane = bitplane;
        spotChanges = new BitplaneSpotChanges(bitplane, canonicalData);

        if (spotChanges.spotChangesNeeded()) {
            index = getVersionOfSubIdWithSpotChanges(index);
        }
        this.index = index;
    }

    public ArrayList<Integer> encodeData() {
        ArrayList<Integer> data = new ArrayList<>();
        data.addAll(spotChanges.getEncodedData());
        return data;
    }
    public int getBitplaneIndex() {
        return index;
    }

    public int getSizeWhenEncoded() {
        return spotChanges.getEncodedData().size();
    }

    public String toString() {
        String output = TileCompConstants.summarizePurposeOfBitplaneIndex(index);
        output += spotChanges.toString();
        return output;
    }
}
