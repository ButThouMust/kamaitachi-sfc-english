package tilesets.tag_bitplane;

import static tilesets.constants.TileCompConstants.CREATE_BP_FROM_TWO_BIT_INDICES_AND_BYTES;
import static tilesets.constants.TileCompConstants.NUM_ROWS_PER_TILE;

import java.util.ArrayList;

public class BitplaneConstructFromUniqueBytes extends BitplaneCompressionTag {
    private ArrayList<Integer> values;
    private int indices[];

    public BitplaneConstructFromUniqueBytes(int bitplane[]) {
        this.bitplane = bitplane;
        indices = new int[NUM_ROWS_PER_TILE];
        getDataList();
        spotChanges = null;
    }

    private void getDataList() {
        values = new ArrayList<>();
        values.add(bitplane[0]);
        indices[0] = 0;

        for (int i = 1; i < bitplane.length; i++) {
            int bpByte = bitplane[i];
            if (!values.contains(bpByte)) {
                values.add(bpByte);
            }
            indices[i] = values.indexOf(bpByte);
        }
    }
    private int getBitpackedIndices() {
        int output = 0x0000;
        for (int i = 0; i < indices.length; i++) {
            output |= (indices[i] & 0x3) << (2 * i);
        }
        return output;
    }

    public ArrayList<Integer> encodeData() {
        ArrayList<Integer> data = new ArrayList<>();

        // write the bitpacked list of indices as a BIG ENDIAN value
        // if there are 3 or fewer data values, indicate by making 1st index non-zero
        int bitpackedIndices = getBitpackedIndices();
        if (values.size() < 4) {
            bitpackedIndices |= 0x1;
        }
        data.add(bitpackedIndices >> 8);
        data.add(bitpackedIndices & 0xFF);

        int numValuesToWrite = values.size();
        if (numValuesToWrite < 4) {
            numValuesToWrite = 3;
        }
        for (int i = 0; i < numValuesToWrite; i++) {
            // even if there are only 2 unique bytes, you must still write 3 bytes
            if (i >= values.size()) {
                data.add(0x00);
            }
            else {
                data.add(values.get(i));
            }
        }

        return data;
    }

    public int getBitplaneIndex() {
        return CREATE_BP_FROM_TWO_BIT_INDICES_AND_BYTES;
    }

    public int getSizeWhenEncoded() {
        int numValuesToWrite = values.size();
        if (numValuesToWrite < 4) {
            numValuesToWrite = 3;
        }
        return numValuesToWrite + 2;
    }

    public String toString() {
        String output = String.format("Construct from unique bytes:");
        for (int value : values) {
            output += String.format(" %02X", value);
        }
        return output;
    }
}
