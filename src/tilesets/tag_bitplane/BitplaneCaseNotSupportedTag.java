package tilesets.tag_bitplane;

import static tilesets.constants.TileCompConstants.CASE_NOT_VALID;

import java.util.ArrayList;

// singleton class
public class BitplaneCaseNotSupportedTag extends BitplaneCompressionTag {
    private BitplaneCaseNotSupportedTag() {
        encodeData();
    }

    private static BitplaneCaseNotSupportedTag tag = new BitplaneCaseNotSupportedTag();
    public static BitplaneCaseNotSupportedTag getInstance() {
        return tag;
    }

    public ArrayList<Integer> encodeData() {
        spotChanges = null;
        return null;
    }

    public int getBitplaneIndex() {
        return CASE_NOT_VALID;
    }

    public int getSizeWhenEncoded() {
        // make it larger than any case can possibly compress to
        return 0x10;
    }

    public String toString() {
        String output = String.format("(Case found to not apply)");
        return output;
    }
}
