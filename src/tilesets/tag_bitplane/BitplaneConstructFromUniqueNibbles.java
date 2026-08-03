package tilesets.tag_bitplane;

import static tilesets.constants.TileCompConstants.CREATE_BP_FROM_TWO_BIT_INDICES_AND_NIBBLES;
import static tilesets.constants.TileCompConstants.NUM_ROWS_PER_TILE;

import java.util.ArrayList;

public class BitplaneConstructFromUniqueNibbles extends BitplaneCompressionTag {
    private ArrayList<Integer> uniqueNibbles;
    private int indices[];

    public BitplaneConstructFromUniqueNibbles(int bitplane[]) {
        this.bitplane = bitplane;
        indices = new int[NUM_ROWS_PER_TILE * 2];
        getDataList();
    }

    private int[] getNibbleList() {
        int nibbles[] = new int[NUM_ROWS_PER_TILE * 2];
        for (int i = 0; i < bitplane.length; i++) {
            nibbles[i*2] = bitplane[i] >> 4;
            nibbles[i*2 + 1] = bitplane[i] & 0xF;
        }
        return nibbles;
    }

    private void getDataList() {
        uniqueNibbles = new ArrayList<>();
        int allNibbles[] = getNibbleList();

        uniqueNibbles.add(allNibbles[0]);
        indices[0] = 0;

        for (int i = 1; i < allNibbles.length; i++) {
            int value = allNibbles[i];
            if (!uniqueNibbles.contains(value)) {
                uniqueNibbles.add(value);
            }
            indices[i] = uniqueNibbles.indexOf(value);
        }

        while (uniqueNibbles.size() < 4) {
            uniqueNibbles.add(0x0);
        }
    }

    private int getBitpackedIndices() {
        int output = 0x00000000;
        for (int i = 0; i < indices.length; i++) {
            output |= (indices[i] & 0x3) << (2 * i);
        }
        return output;
    }

    public ArrayList<Integer> encodeData() {
        ArrayList<Integer> data = new ArrayList<>();

        // write the bitpacked list of indices as a BIG ENDIAN value
        int bitpackedIndices = getBitpackedIndices();
        data.add((bitpackedIndices >> 24) & 0xFF);
        data.add((bitpackedIndices >> 16) & 0xFF);
        data.add((bitpackedIndices >>  8) & 0xFF);
        data.add(bitpackedIndices & 0xFF);

        int uniqueNibblesByte0 = (uniqueNibbles.get(0) << 4) | (uniqueNibbles.get(1));
        int uniqueNibblesByte1 = (uniqueNibbles.get(2) << 4) | (uniqueNibbles.get(3));
        data.add(uniqueNibblesByte0);
        data.add(uniqueNibblesByte1);

        return data;
    }

    public int getBitplaneIndex() {
        return CREATE_BP_FROM_TWO_BIT_INDICES_AND_NIBBLES;
    }

    public int getSizeWhenEncoded() {
        return 6;
    }

    public String toString() {
        String output = String.format("Construct from unique nibbles:");
        for (int value : uniqueNibbles) {
            output += String.format(" %X", value);
        }
        return output;
    }
}
