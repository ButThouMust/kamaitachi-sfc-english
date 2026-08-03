package tilesets.tag_tile;

import static tilesets.constants.TileCompConstants.BIT_POSITION_LIST_TERMINATOR;
import static tilesets.constants.TileCompConstants.MAX_NUM_BIT_POSITIONS;

import java.util.ArrayList;

import tilesets.compression.KamaitachiTilesetRecompression;
import tilesets.tag_bitplane.BitplaneCaseNotSupportedTag;
import tilesets.tag_bitplane.BitplaneCompressionTag;
import tilesets.tag_bitplane.BitplaneUncompressed;

public class TileCombineBitmaskData extends TileCompressionTag {
    private int bitmaskData[][];
    private int bitmaskDataToEncode[][];
    private int bitPositionsList[];
    private BitplaneCompressionTag bitmaskCompression[];

    private static final int RLE_BITMASK = 0x02;    // 00xx x01y
    private static final int BYTE_BITMASK = 0x04;   // 00xx x10y
    private static final int NIBBLE_BITMASK = 0x06; // 00xx x11y

    public static final int USE_METADATA_BITMASK = 0x01; // y bit 1 = use metadata

    private int typeByteBitmask;
    private int bitpackedBitPosList;

    public TileCombineBitmaskData(int tileNum, int bpData[][], int bitmaskDataWithBitPositions[][], int bitmaskDataToEncode[][]) {
        this.tileNum = tileNum;
        this.bpData = bpData;
        bitmaskData = bitmaskDataWithBitPositions;
        this.bitmaskDataToEncode = bitmaskDataToEncode;
        bitPositionsList = bitmaskDataWithBitPositions[MAX_NUM_BIT_POSITIONS];

        calculateBitpackedBitPosList();
        compressBitmaskData();
    }

    // -------------------------------------------------------------------------

    public int getBitpackedBitPosList() {
        return bitpackedBitPosList;
    }

    private void calculateBitpackedBitPosList() {
        if (bitPositionsList.length != MAX_NUM_BIT_POSITIONS) {
            bitpackedBitPosList = 0xFFFF;
            return;
        }

        bitpackedBitPosList = 0x0000;
        for (int i = 0; i < bitPositionsList.length; i++) {
            int bitPos = bitPositionsList[i];
            if (bitPos == BIT_POSITION_LIST_TERMINATOR) break;
            bitpackedBitPosList |= 0x8000 >> bitPos;
        }
    }

    // -------------------------------------------------------------------------

    @Override
    protected void encodeData() {
        // purposefully leaving out the bit position list because format allows
        // you to instead read from the metadata
        // encodedData.add(bitpackedBitPosList >> 8);
        // encodedData.add(bitpackedBitPosList & 0xFF);
        for (BitplaneCompressionTag tag : bitmaskCompression) {
            encodedData.addAll(tag.encodeData());
        }
    }

    public int calculateTypeByte() {
        // fill in what compression type to use (RLE, byte construct, nibble construct)
        int typeByte = typeByteBitmask;

        // fill in the three bits for which groups are compressed or not
        for (int i = 0; i < bitmaskCompression.length; i++) {
            boolean groupIsCompressed = !(bitmaskCompression[i] instanceof BitplaneUncompressed);
            if (groupIsCompressed) {
                typeByte |= 0x20 >> i;
            }
        }
        return typeByte;
    }

    public int getNumBitmaskGroups() {
        return bitmaskDataToEncode.length;
    }

    @Override
    public int getSizeOfEncodedData() {
        // assume that you must encode the bitpacked bit position list directly,
        // instead of using metadata; type byte + list bytes + compressed data
        return 1 + 2 + super.getSizeOfEncodedData();
    }

    @Override
    public int getNumBytesSavedFromUsingMetadata() {
        return 1;
    }

    // -------------------------------------------------------------------------

    private void compressBitmaskData() {
        // test all three compression methods: RLE, byte construct, nibble construct
        int numBitmaskGroups = getNumBitmaskGroups();
        BitplaneCompressionTag rleGroups[] = new BitplaneCompressionTag[numBitmaskGroups];
        BitplaneCompressionTag byteConstructGroups[] = new BitplaneCompressionTag[numBitmaskGroups];
        BitplaneCompressionTag nibbleConstructGroups[] = new BitplaneCompressionTag[numBitmaskGroups];

        // it is possible that the byte/nibble construction cases won't work with
        // some bitmask groups, so generate the uncompressed variants to fall back on
        BitplaneCompressionTag uncompressedGroups[] = new BitplaneCompressionTag[numBitmaskGroups];
        for (int i = 0; i < numBitmaskGroups; i++) {
            uncompressedGroups[i] = new BitplaneUncompressed(bitmaskDataToEncode[i]);
        }

        for (int i = 0; i < numBitmaskGroups; i++) {
            // if there are 7 or 8 indices for RLE compression, it'd be just as
            // or more space-efficient to just encode the data uncompressed
            rleGroups[i] = KamaitachiTilesetRecompression.checkEncodingAsRleGroups(bitmaskDataToEncode[i]);
            if (rleGroups[i] == BitplaneCaseNotSupportedTag.getInstance()) {
                rleGroups[i] = uncompressedGroups[i];
            }

            byteConstructGroups[i] = KamaitachiTilesetRecompression.checkForBitplaneThatUsesThreeOrFourUniqueBytes(bitmaskDataToEncode[i]);
            if (byteConstructGroups[i] == BitplaneCaseNotSupportedTag.getInstance()) {
                byteConstructGroups[i] = uncompressedGroups[i];
            }

            nibbleConstructGroups[i] = KamaitachiTilesetRecompression.checkForBitplaneThatUsesFourUniqueNibbles(bitmaskDataToEncode[i]);
            if (nibbleConstructGroups[i] == BitplaneCaseNotSupportedTag.getInstance()) {
                // System.out.println("Nibble case not valid for group " + i);
                nibbleConstructGroups[i] = uncompressedGroups[i];
            }
        }

        // combine the data for each compression method
        ArrayList<Integer> rleCompressedData = new ArrayList<>();
        ArrayList<Integer> byteCompressedData = new ArrayList<>();
        ArrayList<Integer> nibbleCompressedData = new ArrayList<>();
        for (int i = 0; i < numBitmaskGroups; i++) {
            rleCompressedData.addAll(rleGroups[i].encodeData());
            byteCompressedData.addAll(byteConstructGroups[i].encodeData());
            nibbleCompressedData.addAll(nibbleConstructGroups[i].encodeData());
        }

        // determine which method is the most space-efficient (can only pick one,
        // and can't mix and match); tends to be RLE in the JP game's data
        int rleSize = rleCompressedData.size();
        int byteSize = byteCompressedData.size();
        int nibbleSize = nibbleCompressedData.size();
        // System.out.printf("Compare methods: %d, %d, %d\n", rleSize, byteSize, nibbleSize);

        if (rleSize <= byteSize && rleSize <= nibbleSize) {
            typeByteBitmask = RLE_BITMASK;
            bitmaskCompression = rleGroups;
            encodedData = rleCompressedData;
        }
        else if (byteSize < rleSize && byteSize <= nibbleSize) {
            typeByteBitmask = BYTE_BITMASK;
            bitmaskCompression = byteConstructGroups;
            encodedData = byteCompressedData;
        }
        else if (nibbleSize < rleSize && nibbleSize < byteSize) {
            typeByteBitmask = NIBBLE_BITMASK;
            bitmaskCompression = nibbleConstructGroups;
            encodedData = nibbleCompressedData;
        }
    }

    // all the cases for comparing sizes (ranked 1st - 3rd in sizes):
    // ties: if RLE = byte, pick RLE; if RLE = nibble, pick RLE; if byte = nibble, pick byte
    // R B N | descr.    | condense cases | selection
    // ------+-----------+----------------+----------- three-way tie
    // 1 1 1 | R = B = N | R <= B, R <= N | rle
    // ------+-----------+----------------+----------- two-way tie for 1st
    // 1 1 2 | R = B < N | R <= B, R <= N | rle
    // 1 2 1 | R = N < B | R <= B, R <= N | rle
    // 2 1 1 | B = N < R | B < R,  B <= N | byte
    // ------+-----------+----------------+----------- two-way tie for 2nd (for illustrating combining cases)
    // 1 2 2 | R < B = N | R < B,  R < N  | rle
    // 2 1 2 | B < R = N | B < R,  B <= N | byte
    // 2 2 1 | N < B = R | N < B,  N < R  | nibble
    // ------+-----------+----------------+----------- no ties
    // 1 2 3 | R < B < N | R < B,  R < N  | rle
    // 1 3 2 | R < N < B | R < B,  R < N  | rle
    // 2 1 3 | B < R < N | B < R,  B <= N | byte
    // 3 1 2 | B < N < R | B < R,  B <= N | byte
    // 2 3 1 | N < R < B | N < B,  N < R  | nibble
    // 3 2 1 | N < B < R | N < B,  N < R  | nibble

    public String toString() {
        String tileNumString = String.format("Tile %03X:\n", tileNum);
        String bitPosString = "Bit pos list:";
        String bitmaskDataString = "";
        for (int i = 0; i < MAX_NUM_BIT_POSITIONS; i++) {
            int bitPos = bitPositionsList[i];
            if (bitPos == BIT_POSITION_LIST_TERMINATOR) break;

            bitPosString += String.format(" %X", bitPos);
        }
            
        for (int i = 0; i < MAX_NUM_BIT_POSITIONS; i++) {
            int bitPos = bitPositionsList[i];
            if (bitPos == BIT_POSITION_LIST_TERMINATOR) break;

            bitmaskDataString += String.format("\nPos %X masks:", bitPos);
            for (int j = 0; j < bitmaskData[i].length; j++) {
                bitmaskDataString += String.format(" %02X", bitmaskData[i][j]);
            }
            bitmaskDataString += " (bp: ";
            bitmaskDataString += (bitPos & 0x8) == 0 ? "-" : "3";
            bitmaskDataString += (bitPos & 0x4) == 0 ? "-" : "2";
            bitmaskDataString += (bitPos & 0x2) == 0 ? "-" : "1";
            bitmaskDataString += (bitPos & 0x1) == 0 ? "-" : "0";
            bitmaskDataString += ")";
        }

        String compressionInfo = "\n---";
        for (int groupNum = 0; groupNum < bitmaskCompression.length; groupNum++) {
            compressionInfo += String.format("\nGrp %d:", groupNum);
            for (int i = 0; i < bitmaskDataToEncode[groupNum].length; i++) {
                compressionInfo += String.format(" %02X", bitmaskDataToEncode[groupNum][i]);
            }
            compressionInfo += "\n     - " + bitmaskCompression[groupNum].toString();
        }

        return tileNumString + bitPosString + bitmaskDataString + compressionInfo;
    }
}
