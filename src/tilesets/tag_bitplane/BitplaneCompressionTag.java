package tilesets.tag_bitplane;

import java.util.ArrayList;

public abstract class BitplaneCompressionTag implements Comparable<BitplaneCompressionTag> {
    protected int bitplane[];
    protected BitplaneSpotChanges spotChanges = null;

    public abstract ArrayList<Integer> encodeData();
    public abstract int getBitplaneIndex();
    public abstract int getSizeWhenEncoded();

    public int compareTo(BitplaneCompressionTag other) {
        /*
        // purpose: move "not supported" tags to the end of a list when sorting
        boolean thisNotSupported = this == BitplaneCaseNotSupportedTag.getInstance();
        boolean otherNotSupported = other == BitplaneCaseNotSupportedTag.getInstance();
        if (thisNotSupported) {
            if (otherNotSupported) return 0;
            return 1;
        }
        else if (other == BitplaneCaseNotSupportedTag.getInstance()) {
            return -1;
        }
        */

        return getSizeWhenEncoded() - other.getSizeWhenEncoded();
    }
}
