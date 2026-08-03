package tilesets.tag_bitplane;

import java.util.ArrayList;

public class BitplaneSpotChanges {
    // the actual data, versus what data you'd get from the format on its own
    private int bitplane[];
    private int canonical[];
    private ArrayList<Integer> encodedData;

    public BitplaneSpotChanges(int bitplane[], int canonical[]) {
        this.bitplane = bitplane;
        this.canonical = canonical;
        encodeData();
    }

    private void encodeData() {
        encodedData = new ArrayList<>();

        int flags = 0x00;
        encodedData.add(flags);
        for (int i = 0; i < bitplane.length; i++) {
            if (bitplane[i] != canonical[i]) {
                flags |= 0x80 >> i;
                encodedData.add(bitplane[i]);
            }
        }

        if (flags == 0x00) {
            encodedData = new ArrayList<>();
        }
        else {
            encodedData.set(0, flags);
        }
    }

    public ArrayList<Integer> getEncodedData() {
        return encodedData;
    }

    public boolean spotChangesNeeded() {
        return encodedData.size() != 0;
    }

    public String toString() {
        if (encodedData.size() == 0) {
            return "";
        }
        int flags = encodedData.get(0);
        if (flags == 0x00) return "";

        String output = String.format("; Spot changes flag %02X (need %d+1 bytes)", flags, encodedData.size() - 1);
        return output;
    }
}
