package tilesets.tag_tile;

// import static tilesets.constants.TileCompConstants.CREATE_BP_FROM_TWO_BIT_INDICES_AND_BYTES;
// import static tilesets.constants.TileCompConstants.CREATE_BP_FROM_TWO_BIT_INDICES_AND_NIBBLES;
// import static tilesets.constants.TileCompConstants.READ_8_RAW_BYTES;

import static tilesets.constants.TileCompConstants.FILL_BP_WITH_00;
import static tilesets.constants.TileCompConstants.FILL_BP_WITH_FF;
import static tilesets.constants.TileCompConstants.RLE_BITPLANE;
import static tilesets.constants.TileCompConstants.FLAG_FOR_ENCODING_IN_2_BYTES;
import static tilesets.constants.TileCompConstants.FLAG_FOR_INDEX_3_OF_ALL_FF;

import java.util.ArrayList;

import tilesets.constants.TileCompConstants;
import tilesets.tag_bitplane.BitplaneCompressionTag;

public class TileBitplaneSubroutinesTag extends TileCompressionTag {
    public static final boolean FORCE_THREE_BYTES = true;

    public static final int USE_METADATA_BITMASK = 0x01; // 00xx 0001

    private BitplaneCompressionTag bpCompressionTags[];

    public TileBitplaneSubroutinesTag(int tileNum, BitplaneCompressionTag bpCompressionTags[]) {
        this.tileNum = tileNum;
        this.bpCompressionTags = bpCompressionTags;
    }

    public int getEncodedSubroutineIndices(boolean forceThreeBytes) {
        int index0 = bpCompressionTags[0].getBitplaneIndex();
        int index1 = bpCompressionTags[1].getBitplaneIndex();
        int index2 = bpCompressionTags[2].getBitplaneIndex();
        int index3 = bpCompressionTags[3].getBitplaneIndex();

        int output = 0x00;

        // the 0x80 bit doesn't NEED to be set for the metadata bytes, but in
        // the Japanese game's data, they keep the 0x80 bit set anyway
        int typeByte = (index2 & 0x3F) | 0x80;
        int encodedByte1 = (index1 & 0x1F) << 3;
        if (canRestrictBitplanes03() && !forceThreeBytes) {
            typeByte |= FLAG_FOR_ENCODING_IN_2_BYTES;

            // fill the 3 remaining bits of byte 1 with index 0 (bits 0-1) and a
            // flag encoding whether index 3 is "fill with 00" or "fill with FF"
            encodedByte1 |= (index0 & 0x3);
            int bitForIndex3 = (index3 == FILL_BP_WITH_00) ? 0x0 : FLAG_FOR_INDEX_3_OF_ALL_FF;
            encodedByte1 |= bitForIndex3;
        }
        else {
            typeByte &= ~FLAG_FOR_ENCODING_IN_2_BYTES;
            // fill the 3 remaining bits of byte 1 with bits 1-3 of index 0
            encodedByte1 |= (index0 & 0xE) >> 1;

            int encodedByte2 = index3;
            encodedByte2 |= (index0 & 0x1) << 7;

            output = encodedByte2 << 16;
        }

        output |= typeByte;
        output |= encodedByte1 << 8;
        return output;
    }

    public boolean canRestrictBitplanes03() {
        int index0 = bpCompressionTags[0].getBitplaneIndex();
        int index3 = bpCompressionTags[3].getBitplaneIndex();

        return (index0 >= 0 && index0 <= RLE_BITPLANE) &&
            (index3 == FILL_BP_WITH_00 || index3 == FILL_BP_WITH_FF);
    }

    public static boolean bitplanes03AreRestricted(int encodedIndices) {
        return (encodedIndices & FLAG_FOR_ENCODING_IN_2_BYTES) != 0x00;
    }

    public boolean canUseConstructFrom8BytesCase() {
        int index0 = bpCompressionTags[0].getBitplaneIndex();
        int index1 = bpCompressionTags[1].getBitplaneIndex();
        int index2 = bpCompressionTags[2].getBitplaneIndex();
        int index3 = bpCompressionTags[3].getBitplaneIndex();
        int indexList[] = {index0, index1, index2, index3};

        // the other tile case applies if one index is 8 bytes, RLE, 3/4 unique
        // bytes, or 4 unique nibbles; and if the other 3 indices are one of
        // all 00/FF, direct bitplane reuse, or direct ~bitplane reuse;
        // but I think just the reuse condition is the most important here
        int numIndicesWithReuse = 0;
        for (int index : indexList) {
            if (TileCompConstants.bitplaneCombinationTypeDoesBasicReuse(index)) {
                numIndicesWithReuse++;
            }
            /*
            else switch (index) {
                case RLE_BITPLANE:
                case READ_8_RAW_BYTES:
                case CREATE_BP_FROM_TWO_BIT_INDICES_AND_BYTES:
                case CREATE_BP_FROM_TWO_BIT_INDICES_AND_NIBBLES:
                    break;
            }
            */
        }
        return numIndicesWithReuse == 3;
    }

    @Override
    protected void encodeData() {
        // note: the bytes for the index values get encoded differently (or even
        // not at all) depending on what the values are, and if the particular
        // combination can be stored in the tileset metadata
        encodedData = new ArrayList<>();
        for (BitplaneCompressionTag bpCompress : bpCompressionTags) {
            encodedData.addAll(bpCompress.encodeData());
        }
    }

    @Override
    public int getSizeOfEncodedData() {
        // assume that you must encode the indices directly, instead of using metadata
        int overheadSize = canRestrictBitplanes03() ? 2 : 3;
        return super.getSizeOfEncodedData() + overheadSize;
    }

    @Override
    public int getNumBytesSavedFromUsingMetadata() {
        return canRestrictBitplanes03() ? 1 : 2;
    }

    public static int getNumBytesSavedFromUsingMetadata(int encodedIndices) {
        return bitplanes03AreRestricted(encodedIndices) ? 1 : 2;
    }

    public String toString() {
        String output = String.format("Tile %03X:", tileNum);
        for (int bp = 0; bp < bpCompressionTags.length; bp++) {
            BitplaneCompressionTag bpTag = bpCompressionTags[bp];
            output += String.format("\nBP%d: [%d] %s", bp, bpTag.getSizeWhenEncoded(), bpTag.toString());
        }
        return output;
    }
}
