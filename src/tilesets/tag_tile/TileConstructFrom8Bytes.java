package tilesets.tag_tile;

import java.util.ArrayList;
import java.util.PriorityQueue;

import tilesets.compression.KamaitachiTilesetRecompression;
import tilesets.tag_bitplane.BitplaneCaseNotSupportedTag;
import tilesets.tag_bitplane.BitplaneCompressionTag;
import tilesets.tag_bitplane.BitplaneConstructFromUniqueBytes;
import tilesets.tag_bitplane.BitplaneConstructFromUniqueNibbles;
import tilesets.tag_bitplane.BitplaneFillFromRLE;
import tilesets.tag_bitplane.BitplaneUncompressed;

public class TileConstructFrom8Bytes extends TileCompressionTag {
    private int bitmaskData[];
    private int bitplaneTypes[];
    private BitplaneCompressionTag bitmaskCompression;
    private int typeByteBitmask;

    private static final int UNCOMP_BITMASK = 0x08; // 0x10 and 0x18 also work
    private static final int RLE_BITMASK    = 0x28;
    private static final int BYTE_BITMASK   = 0x30;
    private static final int NIBBLE_BITMASK = 0x38;

    public static final int ALL_00 = 0x00;
    public static final int ALL_FF = 0xFF;
    public static final int OTHER = 0x7F;
    public static final int OTHER_NOT = OTHER ^ 0xFF;

    private static final int BITS_00 = 0x0;
    private static final int BITS_NN = 0x1;
    private static final int BITS_NN_NOT = 0x2;
    private static final int BITS_FF = 0x3;

    public TileConstructFrom8Bytes(int tileNum, int bpData[][], int bitplaneTypes[]) {
        this.tileNum = tileNum;
        this.bpData = bpData;
        this.bitplaneTypes = bitplaneTypes;

        getBitmaskDataFromBitplanes();
        compressBitmaskData();
    }

    @Override
    protected void encodeData() {
        encodedData = new ArrayList<>();
        encodedData.add(typeByteBitmask);
        encodedData.add(getBitpackedBitplaneTypes());
        encodedData.addAll(bitmaskCompression.encodeData());
    }

    @Override
    public int getNumBytesSavedFromUsingMetadata() {
        return 0;
    }

    // -------------------------------------------------------------------------

    private int getBitpackedBitplaneTypes() {
        int output = 0x00;
        for (int bp = 0; bp < bitplaneTypes.length; bp++) {
            int type = bitplaneTypes[bp];
            int bits = 0x00;
            switch (type) {
                case ALL_00:
                    bits = BITS_00; break;
                case OTHER:
                    bits = BITS_NN; break;
                case OTHER_NOT:
                    bits = BITS_NN_NOT; break;
                case ALL_FF:
                    bits = BITS_FF; break;
            }
            output |= bits << (bp * 2);
        }
        return output;
    }

    private void getBitmaskDataFromBitplanes() {
        // situational optimization for the RLE case: if NN data block starts
        // with at least one FF byte, you can invert the block's data so that
        // the FF byte(s) are instead 00 byte(s), which lets you imply the value
        // instead of encode it; this will not negatively affect how effective
        // the byte/nibble cases would be

        // assumption: the initial list of bitplane categorizations has at least
        // one bitplane of NN; find it
        int firstBitplaneWithNN = 0;
        for (int i = 0; i < bitplaneTypes.length; i++) {
            int type = bitplaneTypes[i];
            if (type == OTHER) {
                firstBitplaneWithNN = i;
                break;
            }
        }

        int bitplaneDataNN[] = bpData[firstBitplaneWithNN];
        boolean canOptimize = bitplaneDataNN[0] == 0xFF;

        // fill in the bitmask data (DEEP copy), applying the optimization if need be
        int xorMask = canOptimize ? 0xFF : 0x00;
        bitmaskData = new int[bitplaneDataNN.length];
        for (int i = 0; i < bitplaneDataNN.length; i++) {
            bitmaskData[i] = bitplaneDataNN[i] ^ xorMask;
        }

        // if we did the optimization, we need to appropriately account for this
        // with the bitplane types
        if (canOptimize) {
            for (int i = 0; i < bitplaneTypes.length; i++) {
                int type = bitplaneTypes[i];
                if (type == OTHER || type == OTHER_NOT) {
                    bitplaneTypes[i] ^= 0xFF;
                }
            }
        }
    }

    // -------------------------------------------------------------------------

    private void compressBitmaskData() {
        BitplaneCompressionTag uncompressedGroup = new BitplaneUncompressed(bitmaskData);

        BitplaneCompressionTag rleGroup = KamaitachiTilesetRecompression.checkEncodingAsRleGroups(bitmaskData);
        if (rleGroup == BitplaneCaseNotSupportedTag.getInstance()) {
            rleGroup = uncompressedGroup;
        }

        // optimization: if the RLE group requires 5 or fewer bytes to encode,
        // that will automatically equal or outperform the byte/nibble construct
        // groups, because even if they work for the bitmask data, they require
        // either 5 or 6 bytes to encode; in this case, we are done
        else if (rleGroup.getSizeWhenEncoded() <= 5) {
            bitmaskCompression = rleGroup;
            typeByteBitmask = RLE_BITMASK;
            return;
        }

        // these are set up to return "not supported" since it's possible the
        // byte/nibble construction cases won't work with the bitmask data
        BitplaneCompressionTag byteConstructGroup = KamaitachiTilesetRecompression.checkForBitplaneThatUsesThreeOrFourUniqueBytes(bitmaskData);
        BitplaneCompressionTag nibbleConstructGroup = KamaitachiTilesetRecompression.checkForBitplaneThatUsesFourUniqueNibbles(bitmaskData);

        PriorityQueue<BitplaneCompressionTag> options = new PriorityQueue<>();
        options.add(rleGroup);
        options.add(byteConstructGroup);
        options.add(nibbleConstructGroup);
        options.add(uncompressedGroup);
        bitmaskCompression = options.peek();

        if (bitmaskCompression instanceof BitplaneUncompressed) {
            typeByteBitmask = UNCOMP_BITMASK;
        }
        else if (bitmaskCompression instanceof BitplaneFillFromRLE) {
            typeByteBitmask = RLE_BITMASK;
        }
        else if (bitmaskCompression instanceof BitplaneConstructFromUniqueBytes) {
            typeByteBitmask = BYTE_BITMASK;
        }
        else if (bitmaskCompression instanceof BitplaneConstructFromUniqueNibbles) {
            typeByteBitmask = NIBBLE_BITMASK;
        }
        /* else if (bitmaskCompression == BitplaneCaseNotSupportedTag.getInstance()) {

        } */
    }

    // -------------------------------------------------------------------------

    public String toString() {
        String output = String.format("Tile %03X:\nBitmask data:", tileNum);
        for (int i = 0; i < bitmaskData.length; i++) {
            output += String.format(" %02X", bitmaskData[i]);
        }

        // output += "\nCompression type: " + bitmaskCompression.getClass().toString();
        output += "\nCompression type: ";
        String compressionType = "";
        if (bitmaskCompression instanceof BitplaneUncompressed) {
            compressionType = "Raw 8 bytes";
        }
        else if (bitmaskCompression instanceof BitplaneFillFromRLE) {
            compressionType = "RLE";
        }
        else if (bitmaskCompression instanceof BitplaneConstructFromUniqueBytes) {
            compressionType = "Unique bytes";
        }
        else if (bitmaskCompression instanceof BitplaneConstructFromUniqueNibbles) {
            compressionType = "Unique nibbles";
        }
        output += compressionType;

        output += "\nBitplanes:";
        for (int bp = 0; bp < bitplaneTypes.length; bp++) {
            int type = bitplaneTypes[bp];
            String description = "";
            switch (type) {
                case ALL_00:
                    description = " 00"; break;
                case OTHER:
                    description = " nn"; break;
                case OTHER_NOT:
                    description = " ~nn"; break;
                case ALL_FF:
                    description = " FF"; break;
                default:
                    description = " ERROR"; break;
            }
            output += description;
        }

        return output;
    }
}
