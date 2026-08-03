package tilesets.tag_tile;

import static tilesets.constants.TileCompConstants.BIT_DEPTH;
import static tilesets.constants.TileCompConstants.NUM_ROWS_PER_TILE;

import java.util.ArrayList;

public abstract class TileCompressionTag implements Comparable<TileCompressionTag> {
    protected int tileNum;
    protected int bpData[][];
    protected ArrayList<Integer> encodedData;

    protected abstract void encodeData();
    public abstract int getNumBytesSavedFromUsingMetadata();

    public ArrayList<Integer> getEncodedData() {
        if (encodedData == null) encodeData();
        return encodedData;
    }

    public int getTileNum() {
        return tileNum;
    }

    public int getSizeOfEncodedData() {
        if (encodedData == null) encodeData();
        return encodedData.size();
    }

    public int compareTo(TileCompressionTag other) {
        /*
        // purpose: put "not supported" tags at the end of a list when sorting
        boolean thisNotSupported = this == TileCaseNotSupportedTag.getInstance();
        boolean otherNotSupported = other == TileCaseNotSupportedTag.getInstance();
        if (thisNotSupported) {
            if (otherNotSupported) return 0;
            return 1;
        }
        else if (other == TileCaseNotSupportedTag.getInstance()) {
            return -1;
        }
        */

        // assumption: tile numbers are consistent
        return getSizeOfEncodedData() - other.getSizeOfEncodedData();
    }

    public String toString() {
        String output = String.format("Tile %03X data:\n", tileNum);
        for (int bp = 0; bp < BIT_DEPTH; bp++) {
            String bpString = "";
            switch (bp) {
                case 1: case 3:
                    bpString = " ";
                    break;
                case 2:
                    bpString = "\n";
                    break;
            }

            for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
                bpString += r == 0 ? "[" : " ";
                bpString += String.format("%02X", bpData[bp][r]);
            }
            bpString += "]";

            output += bpString;
        }

        return output + "\n";
    }
}
