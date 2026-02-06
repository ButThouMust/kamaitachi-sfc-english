package tilesets.decompression;

import java.io.BufferedWriter;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.file.Files;
import java.nio.file.Paths;

import static tilesets.constants.TileCompConstants.*;
import tilesets.constants.BitplaneCombiner;

public class KamaitachiTileDumper {

    // If you think that this code is a giant mess, then you are absolutely correct.

    private static RandomAccessFile romFile;
    private static BufferedWriter log;

    private static final int BYTES_FOR_100_TILES = TILE_SIZE * 0x100;

    private static final int BITPLANE_0 = 0x0;
    private static final int BITPLANE_1 = 0x1;
    private static final int BITPLANE_2 = 0x10;
    private static final int BITPLANE_3 = 0x11;
    private static final int[] BITPLANE_OFFSETS = {BITPLANE_0, BITPLANE_1, BITPLANE_2, BITPLANE_3};

    private static final int NUM_BYTES_PER_ROW_IN_BITPLANE = 2;

    // -------------------------------------------------------------------------

    private static enum BitmaskSubroutines {
        // $029276, $0292A7, $029304
        UseRleFormat, ConstructFromBytes, ConstructFromNibbles;
    }

    private static int bitplaneSubroutineRawBytes[] = new int[NUM_BYTES_FOR_ENCODED_BP_SUBS];

    // covers 0x18 bytes from F69A through F6B1; 3 groups of 8 bytes
    private static int bitmaskGroupsF69A[][] = new int[NUM_GROUPS_OF_8_BITMASKS][BITMASK_LIST_SIZE];
    // the original ASM also covers 0x18 bytes from F6B2 through F6C9, but these
    // just contain the bitwise NOT of the data in F69A; in this implementation,
    // they get calculated on demand
    // private static int bitmasksF6B2[] = new int[BITMASK_LIST_SIZE * NUM_GROUPS_OF_8_BITMASKS];

    private static int combinedBitmaskDataF6CA[] = new int[BITMASK_LIST_SIZE];
    private static int rawBitmaskDataForBytesNibblesCases[] = new int[BITMASK_LIST_SIZE]; // F6DB

    // can contain a list of up to 8 bit positions, plus an FF terminator
    private static int bitPositionListF6D2[] = new int[SIZE_OF_TERMINATED_BIT_POS_LIST];

    private static BitmaskSubroutines subroutineMarkerF6E3;

    // private static final int F6F0_OFFSET = 0xB;
    // private static int tileMetadataF6E5[] = new int[TILE_METADATA_SIZE];
    private static int commonBitplaneSubIndexDataF6E5[];
    private static int commonDataForBitmaskBitPositionListF6F0[];

    private static int countsForBitplaneSubIndexUsage[];
    private static int countsForBitmaskMetadataUsage[];

    private static int tileDataBuffer[] = new int[4 * BYTES_FOR_100_TILES];
    private static int startOfCurrTile;

    private static boolean DEBUG = true;

    // -------------------------------------------------------------------------
    // Run this code when MSB of type byte is set
    // -------------------------------------------------------------------------

    private static void setUpToRunBitplaneSubroutines028E77(int typeByte) throws IOException {
        // see $028E77 -> $029396
        bitplaneSubroutineRawBytes[0] = typeByte;
        bitplaneSubroutineRawBytes[1] = romFile.readUnsignedByte();
        // $029396: check bit 6, 1x__ ____
        if ((typeByte & 0x40) != 0) {
            // $02939A: 11__ ____
            // this case uses 1 fewer byte but limits how to fill in BP0 and BP3

            // subroutine index 3 <- fill BP3 with either 00 or FF (perfect match)
            boolean fillWith00 = (bitplaneSubroutineRawBytes[1] & 0x4) == 0;
            // bitplaneSubroutineRawBytes[2] = fillWith00 ? 0x08 : 0x0A;
            bitplaneSubroutineRawBytes[2] = fillWith00 ? (FILL_BP_WITH_00 << 1) : (FILL_BP_WITH_FF << 1);
            if (DEBUG) {
                String output = "0x%06X: Read one byte %02X; checking (%02X & 4) -> BP3 is all %02X\n";
                log.write(String.format(output, romFile.getFilePointer() - 1, bitplaneSubroutineRawBytes[1], bitplaneSubroutineRawBytes[1], fillWith00 ? 0x00 : 0xFF));
                log.write("");
            }

            // subroutine index 0 <- value range 00-03, so either:
            // 8 bytes, RLE, or fill with 00/FF with spot changes
            int index0 = bitplaneSubroutineRawBytes[1] & 0x3;
            runSubroutinesFrom029422(index0);
        }
        else {
            // $0293BC: 10__ ____
            // this case imposes no such restrictions on bitplanes 0 or 3
            bitplaneSubroutineRawBytes[2] = romFile.readUnsignedByte();
            if (DEBUG) {
                String output = "0x%06X: Read two bytes; $1F0C <- %02X, $1F0D <- %02X\n";
                log.write(String.format(output, romFile.getFilePointer() - 2, bitplaneSubroutineRawBytes[1], bitplaneSubroutineRawBytes[2]));
            }
            rotate1F0D_andDoBitplaneSubroutines();
        }
        return;
    }

    private static void rotate1F0D_andDoBitplaneSubroutines() throws IOException {
        // LDA.B $0C ; ASL.B $0D ; ROL A ; AND.B #$0F
        // start with $0C ; left shift $0D and keep its MSB ; rotate bit into
        // LSB of accumulator ; keep only the low 4 bits
        /* if (DEBUG) {
            log.write("Rotate out bit 7 of $1F0D left, into bit 0 of $1F0C\n");
            log.write(String.format("[%02X %02X] -> ", bitplaneSubroutineRawBytes[1], bitplaneSubroutineRawBytes[2]));
        } */

        int bit = (bitplaneSubroutineRawBytes[2] & 0x80) >> 7;
        bitplaneSubroutineRawBytes[2] = (bitplaneSubroutineRawBytes[2] << 1) & 0xFF;
        int index0 = ((bitplaneSubroutineRawBytes[1] << 1) | bit) & 0xF;

        /* if (DEBUG) {
            log.write(String.format("[%02X %02X]\n", bitplaneSubroutineRawBytes[1], bitplaneSubroutineRawBytes[2]));
        } */
        runSubroutinesFrom029422(index0);
    }

    private static void runSubroutinesFrom029422(int index0) throws IOException {
        // implement code at $0293DE

        // get list of indices for subroutines to fill in a tile's four bitplanes
        // index 0 is the input; calculate the other three indices as below
        // see $0293E8, $0293FB, $029414
        int index1 = (bitplaneSubroutineRawBytes[1] >> 3) & 0x1F;
        int index2 = bitplaneSubroutineRawBytes[0] & 0x3F;
        int index3 = bitplaneSubroutineRawBytes[2] >> 1;
        int indexList[] = {index0, index1, index2, index3};

        if (DEBUG) {
            String format = "Values @ $1F0B: [%02X %02X %02X]\n";
            log.write(String.format(format, bitplaneSubroutineRawBytes[0], bitplaneSubroutineRawBytes[1], bitplaneSubroutineRawBytes[2]));
            format = "Ran $029422 indices: %02X %02X %02X %02X\n";
            log.write(String.format(format, index0, index1, index2, index3));
        }

        // run the four subroutines in order from bitplane 0 to 3
        for (int bp = 0; bp < indexList.length; bp++) {
            int index = indexList[bp];
            if (DEBUG) {
                String format1 = "bp%d: %02X = %s\n";
                log.write(String.format(format1, bp, index, summarizePurposeOfBitplaneIndex(index)));
            }
            runOne029422Subroutine(index, BITPLANE_OFFSETS[bp]);
        }
    }

    private static void runOne029422Subroutine(int index, int bitplane) throws IOException {
        boolean doSpotChanges = indexDoesSpotChanges(index);
        if (doSpotChanges) {
            // see code @ $02992F-$029A37; these indices call existing subroutine
            // before running $029A37: 01, 02, 09, 0A, all even #s 0x0E-0x46
            // convert the spot-change index to the existing subroutine's index
            index = getWhichSubIdToDoBeforeSpotChanges(index);
        }

        if (index >= USE_BP0 && index <= USE_NOT_AND_012 + 1) {
            combineBitplanes(index, bitplane);
        }
        else switch (index) {
            case READ_8_RAW_BYTES: // see $0294B0
                read8RawBytes0294B3(bitplane);
                break;

            // see $0294C5 for these three cases
            case FILL_BP_WITH_00:
                fillBitplaneWithByte0294D6(0x00, bitplane);
                break;
            case FILL_BP_WITH_FF:
                fillBitplaneWithByte0294D6(0xFF, bitplane);
                break;
            case FILL_BP_WITH_BYTE:
                int nextByte = romFile.readUnsignedByte();
                if (DEBUG) {
                    log.write(String.format("     0x%06X: byte is %02X\n", romFile.getFilePointer() - 1, nextByte));
                }
                fillBitplaneWithByte0294D6(nextByte, bitplane);
                break;

            case FILL_BP_WITH_TWO_BYTE_SEQ: // see $0294EF
                fillBitplaneWithFourSetsOfTwoByteSeq0294EF(bitplane);
                break;

            case RLE_BITPLANE: // see $02951A
                fillBitplaneUsingRleFlags_02951A(bitplane);
                break;

            case CREATE_BP_FROM_TWO_BIT_INDICES_AND_BYTES: // see $029545
                constructBitplaneFromUpToFourDistinctBytes029545(bitplane);
                break;
            case CREATE_BP_FROM_TWO_BIT_INDICES_AND_NIBBLES: // see $02959E
                constructBitplaneFromFourDistinctNibbles02959E(bitplane);
                break;

            case FILL_BP_WITH_FOUR_BYTE_SEQ: // see $02962B
                fillBitplaneWithTwoSetsOfFourByteSeq02962B(bitplane);
                break;

            case COPY_BP_FROM_PREV_TILE: // see $029643
                copyBitplaneFromAnotherTile029643(bitplane);
                break;

            default:
                String message = "ERROR: Unrecognized index for $029422 subroutine: %02X";
                if (DEBUG) {
                    log.write(String.format(message, index));
                    log.flush();
                }
                throw new IOException(String.format(message, index));
        }

        if (doSpotChanges) {
            spotChangeBytesInBitplane029A37(bitplane);
        }
    }

    private static boolean indexDoesSpotChanges(int index) {
        int mainIndex = getWhichSubIdToDoBeforeSpotChanges(index);
        return index != mainIndex;
    }

    // --------------------------------------------
    // Work for filling in the bitplanes themselves
    // --------------------------------------------

    private static void spotChangeBytesInBitplane029A37(int bitplane) throws IOException {
        int tileDataPosition = startOfCurrTile + bitplane;
        int bitFlags = romFile.readUnsignedByte();

        if (DEBUG) {
            String format = "     0x%06X: %02X = spot change flag byte\n";
            log.write(String.format(format, romFile.getFilePointer() - 1, bitFlags));
            log.write(String.format("     Spot change data range: 0x%06X-", romFile.getFilePointer()));
        }

        // if N bytes (1 <= N <= 7) need to be changed, do the first N-1 in loop
        do {
            int flag = bitFlags & 0x80;
            bitFlags = (bitFlags << 1) & 0xFF;
            if (bitFlags == 0x00) break;

            if (flag != 0x00) {
                tileDataBuffer[tileDataPosition] = romFile.readUnsignedByte();
            }
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;
        }
        while (true);
        // now do the last spot change
        tileDataBuffer[tileDataPosition] = romFile.readUnsignedByte();

        if (DEBUG) {
            log.write(String.format("0x%06X\n", romFile.getFilePointer() - 1));
        }
    }

    private static void read8RawBytes0294B3(int bitplane) throws IOException {
        // implement loop at $0294B3, for subroutine 00
        if (DEBUG) {
            log.write(String.format("     Read from 0x%06X\n", romFile.getFilePointer()));
        }
        int tileDataPosition = startOfCurrTile + bitplane;
        for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
            tileDataBuffer[tileDataPosition] = romFile.readUnsignedByte();
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;
        }
    }

    private static void fillBitplaneWithByte0294D6(int dataByte, int bitplane) {
        // implement code at $0294D6, for subroutines 04, 05, 06
        int tileDataPosition = startOfCurrTile + bitplane;
        for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
            tileDataBuffer[tileDataPosition] = dataByte;
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;
        }
    }

    private static void fillBitplaneWithFourSetsOfTwoByteSeq0294EF(int bitplane) throws IOException {
        // implement unrolled loop at $0294EF, for subroutine 07
        int tileDataPosition = startOfCurrTile + bitplane;
        int byte0 = romFile.readUnsignedByte();
        int byte1 = romFile.readUnsignedByte();

        // run loop a total of 4 times
        for (int r = 0; r < NUM_ROWS_PER_TILE / 2; r++) {
            tileDataBuffer[tileDataPosition] = byte0;
            tileDataBuffer[tileDataPosition + NUM_BYTES_PER_ROW_IN_BITPLANE] = byte1;
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE * 2;
        }
        if (DEBUG) {
            log.write(String.format("     0x%06X: %02X %02X\n", romFile.getFilePointer() - 2, byte0, byte1));
        }
    }

    private static void fillBitplaneUsingRleFlags_02951A(int bitplane) throws IOException {
        int tileDataPosition = startOfCurrTile + bitplane;
        int bitFlags = romFile.readUnsignedByte();
        if (DEBUG) {
            log.write(String.format("     0x%06X: RLE flag byte %02X\n", romFile.getFilePointer() - 1, bitFlags));
        }

        // write a sequence of 8 bytes like [00 00 xx xx xx yy yy zz]
        // so sort of like doing a special kind of RLE
        if (DEBUG) {
            log.write(String.format("     Data range for sub 03: 0x%06X-", romFile.getFilePointer()));
        }
        int dataByte = 0x00;
        for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
            if ((bitFlags & 0x80) != 0) {
                dataByte = romFile.readUnsignedByte();
            }
            tileDataBuffer[tileDataPosition] = dataByte;

            bitFlags <<= 1;
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;
        }
        if (DEBUG) {
            log.write(String.format("0x%06X\n", romFile.getFilePointer() - 1));
        }
    }

    private static void constructBitplaneFromUpToFourDistinctBytes029545(int bitplane) throws IOException {
        // for subroutine 0B
        if (DEBUG) {
            log.write(String.format(""));
        }
        int tileDataPosition = startOfCurrTile + bitplane;
        int indices = romFile.readUnsignedByte() << 8;
        indices |= romFile.readUnsignedByte();

        if (DEBUG) {
            log.write(String.format("     0x%06X: Index bytes %04X", romFile.getFilePointer() - 2, indices));
        }

        // if first index (bits 0-1 of indices bytes) is not 0
        int numBytesToRead = 4;
        if ((indices & 0x3) != 0) {
            numBytesToRead = 3;
            indices &= ~0x3;
            // ASM does bitmaskIndices = bitmaskIndices & (numBitmasksToRead ^ 0xFF)
            // so, bitmaskIndices & (3 ^ 0xFF) = bitmaskIndices & ~0x3 (so first index is 0)
        }

        // run loop at $02956C; the ASM puts byte values into $7FF69A, but
        // using dedicated variable for readability
        int byteValues[] = new int[numBytesToRead];
        for (int i = 0; i < byteValues.length; i++) {
            byteValues[i] = romFile.readUnsignedByte();
        }
        if (DEBUG) {
            log.write(String.format(" -- %d bytes", numBytesToRead));
            if (numBytesToRead == 3) {
                log.write(String.format(" (indices now %04X)", indices));
            }
            String output = "\n     Data bytes:";
            for (int i = 0; i < numBytesToRead; i++) {
                output += String.format(" %02X", byteValues[i]);
            }
            log.write(output + "\n");
        }

        // grab one index at a time, and write a byte to the tile data buffer
        for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
            int index = indices & 0x3;
            tileDataBuffer[tileDataPosition] = byteValues[index];
            indices >>= 2;
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;
        }
    }

    private static void constructBitplaneFromFourDistinctNibbles02959E(int bitplane) throws IOException {
        // for subroutine 0C
        if (DEBUG) {
            log.write(String.format("     0x%06X: ", romFile.getFilePointer()));
        }
        int tileDataPosition = startOfCurrTile + bitplane;

        // run loop at $0295A1; these four bytes contain 16 2-bit index values
        // ASM places them at $7FF6CA, but using dedicated variable for the sake
        // of readability and not conflicting with existing variable
        int indexBytes[] = new int[4];
        for (int i = 3; i >= 0; i--) {
            indexBytes[i] = romFile.readUnsignedByte();
        }

        // similarly, ASM places nibbles themselves into F69A, but
        // using dedicated variable for readability
        int byte00 = romFile.readUnsignedByte();
        int byte01 = romFile.readUnsignedByte();
        int nibbleValues[] = new int[4];
        nibbleValues[0] = byte00 >> 4;  // store 4 low bits to F69B, 4 high bits to F69A
        nibbleValues[1] = byte00 & 0xF;
        nibbleValues[2] = byte01 >> 4;  // symmetric for F69D and F69C
        nibbleValues[3] = byte01 & 0xF;

        if (DEBUG) {
            log.write(String.format("Index bytes"));
            for (int i = 0; i < 4; i++) {
                log.write(String.format(" %02X", indexBytes[i]));
            }
            log.write(String.format(", Data nibbles"));
            for (int i = 0; i < 4; i++) {
                log.write(String.format(" %1X", nibbleValues[i]));
            }
            log.write("\n");
        }

        // run loop at $0295E6
        for (int i = 0; i < NUM_ROWS_PER_TILE; i++) {
            // grab two 2-bit indices at a time
            // the "& 0xF" is not needed but hopefully makes it more clear
            int nibbleIndices = indexBytes[i >> 1] & 0xF;
            indexBytes[i >> 1] >>= 4;

            // use indices to get two nibbles, and combine them into a byte
            int bitmaskIndex = nibbleIndices & 0x3;
            int topNibble = (nibbleValues[bitmaskIndex] << 4) & 0xFF;

            bitmaskIndex = (nibbleIndices >> 2) & 0x3;
            int lowNibble = nibbleValues[bitmaskIndex];

            tileDataBuffer[tileDataPosition] = topNibble | lowNibble;
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;
        }
    }

    private static void fillBitplaneWithTwoSetsOfFourByteSeq02962B(int bitplane) throws IOException {
        // for subroutine 08
        int tileDataPosition = startOfCurrTile + bitplane;
        String info = String.format("     0x%06X:", romFile.getFilePointer());
        for (int r = 0; r < NUM_ROWS_PER_TILE / 2; r++) {
            int dataByte = romFile.readUnsignedByte();

            // store as data for rows i and (i+4) in the bitplane
            tileDataBuffer[tileDataPosition] = dataByte;
            tileDataBuffer[tileDataPosition + 4 * NUM_BYTES_PER_ROW_IN_BITPLANE] = dataByte;

            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;

            if (DEBUG) {
                info += String.format(" %02X", dataByte);
            }
        }
        if (DEBUG) {
            log.write(info + "\n");
        }
    }

    private static void copyBitplaneFromAnotherTile029643(int bitplane) throws IOException {
        int tileDataPosition = startOfCurrTile + bitplane;
        // load byte from pointer, store to $00 and to $02
        int flagsByte = romFile.readUnsignedByte();

        // load another byte from pointer, store in top half of accumulator
        int tileNumLowByte = romFile.readUnsignedByte();

        // the ASM code processes the two bytes using this format:
        // byte 0, bit  7:   flag to copy data in reverse (1) or forward (0) order
        // byte 0, bits 6-4: unused
        // byte 0, bits 3-2: bitplane number, 0-3
        // byte 0, bits 1-0: 0x100s place of tile number to copy from (0-3)
        // byte 1, bits 7-0: low 8 bits of tile number to copy from
        // visually: r---bpnn nnnnnnn
        boolean reverseOrder = (flagsByte & 0x80) != 0;
        int bpNum = (flagsByte >> 2) & 0x3;
        int tileNum = tileNumLowByte | ((flagsByte & 0x3) << 8);
        int srcTileDataOffset = tileNum * TILE_SIZE + BITPLANE_OFFSETS[bpNum];

        if (DEBUG) {
            String summary = "     0x%06X: Bytes %02X%02X -> Copy bp%d from tile %03X%s\n";
            summary = String.format(summary, romFile.getFilePointer() - 2, flagsByte,
                      tileNumLowByte, bpNum, tileNum, !reverseOrder ? "" : " in reverse order");
            log.write(summary);
        }

        int direction = 1;
        if (reverseOrder) {
            direction = -1;
            // srcTileDataOffset += 0xE;
            srcTileDataOffset += NUM_BYTES_PER_ROW_IN_BITPLANE * (NUM_ROWS_PER_TILE - 1);
        }

        int skipSize = direction * NUM_BYTES_PER_ROW_IN_BITPLANE;
        for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
            tileDataBuffer[tileDataPosition] = tileDataBuffer[srcTileDataOffset];
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;
            srcTileDataOffset += skipSize;
        }
    }

    private static void combineBitplanes(int index, int destBitplane) throws IOException {
        BitplaneCombiner combinationType = getBitplaneCombinationType(index);
        boolean invertResult = bitplaneCombinationTypeDoesBitwiseNOT(index);

        int rowRInTile = startOfCurrTile;
        int tileDataPosition = startOfCurrTile + destBitplane;
        int result = 0;
        int bp0, bp1, bp2;
        for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
            bp0 = tileDataBuffer[rowRInTile];
            bp1 = tileDataBuffer[rowRInTile + BITPLANE_1];
            bp2 = tileDataBuffer[rowRInTile + BITPLANE_2];
            switch (combinationType) {
                case COPY_0: result = bp0;
                    break;
                case COPY_1: result = bp1;
                    break;
                case COPY_2: result = bp2;
                    break;

                case OR_01: result = bp0 | bp1;
                    break;
                case OR_02: result = bp0 | bp2;
                    break;
                case OR_12: result = bp1 | bp2;
                    break;
                case OR_012: result = bp0 | bp1 | bp2;
                    break;

                case AND_01: result = bp0 & bp1;
                    break;
                case AND_02: result = bp0 & bp2;
                    break;
                case AND_12: result = bp1 & bp2;
                    break;
                case AND_012: result = bp0 & bp1 & bp2;
                    break;

                case XOR_01: result = bp0 ^ bp1;
                    break;
                case XOR_02: result = bp0 ^ bp2;
                    break;
                case XOR_12: result = bp1 ^ bp2;
                    break;
            }
            if (invertResult) {
                result = ~result;
            }
            tileDataBuffer[tileDataPosition] = result & 0xFF;
            rowRInTile += NUM_BYTES_PER_ROW_IN_BITPLANE;
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    // For cases with type byte 00xx xxxx

    private static void case00to3F_028E0E(int typeByte) throws IOException {
        // see $028E0E; if bits 6-7 are 00, use bits 0-2 to know what to do next
        int index028E1B = typeByte & 0x7;
        switch (index028E1B) {
            case 0x0: // 00xx x000, see $028E2B; check bits 3-4
                if (((typeByte >> 3) & 0x3) == 0) {
                    // type byte 00 "end of data" is handled in dumpTiles()
                    // so here, 00x0 0000 must be 0010 0000 = 0x20
                    read0x20BytesOfRawTileData028E5D();
                }
                else {
                    useOneSetOf8BytesToFillBitplanes029021_02903B_029055(typeByte);
                }
                break;

            case 0x1:
                // 00xx 0001, see $028E42
                if ((typeByte & 0x8) == 0) {
                    useTilesetMetadataToDoBitplaneSubroutines028E46(typeByte);
                }
                // 00xx 1001, see $028E7D
                else {
                    reuseExistingTileWithNewRows028E7D(typeByte);
                }
                break;

            case 0x2: // 00xx x010, see $029114
            case 0x3: // 00xx x011, see $0290D8
                constructTileFromBitmaskGroups(BitmaskSubroutines.UseRleFormat, typeByte);
                break;
            case 0x4: // 00xx x100, see $029119
            case 0x5: // 00xx x101, see $0290DD
                constructTileFromBitmaskGroups(BitmaskSubroutines.ConstructFromBytes, typeByte);
                break;
            case 0x6: // 00xx x110, see $02911E
            case 0x7: // 00xx x111, see $0290E2
                constructTileFromBitmaskGroups(BitmaskSubroutines.ConstructFromNibbles, typeByte);
                break;
        }
    }

    private static void read0x20BytesOfRawTileData028E5D() throws IOException {
        // see $028E5D; read full 0x20 bytes for tile
        if (DEBUG) {
            log.write(String.format("%06X: Read 0x20 raw bytes for tile\n", romFile.getFilePointer()));
        }
        int tileDataPosition = startOfCurrTile;
        for (int i = 0; i < TILE_SIZE; i++) {
            tileDataBuffer[tileDataPosition + i] = romFile.readUnsignedByte();
        }
    }

    private static void useOneSetOf8BytesToFillBitplanes029021_02903B_029055(int typeByte) throws IOException {
        // high level: get 8 bytes of data and construct bitplanes where each
        // bitplane is either [all 00], [8 bytes], ~[8 bytes], or [all FF]
        // the 8 bytes can either be compressed or uncompressed

        // see $029021, $02903B, $029055 for cases 01, 02, 03:
        // store type byte in $00
        // read another byte from pointer, push to stack
        // if 000x x000, run $02906F = call $02925E with X=0000, then run $029075
        // if 001x x000, call [sub based on xx] with X=0000, and run $029075
        // 1 -> $029277, 2 -> $0292A8, 3 -> $029305
        int casesByte = romFile.readUnsignedByte();
        if (DEBUG) {
            log.write(String.format("0x%06X: Bitpacked cases byte %02X\n", romFile.getFilePointer() - 1, casesByte));
        }

        boolean bit5IsZero = (typeByte & 0x20) == 0;
        if (bit5IsZero) {
            // 000x x000 where "xx" is not 00, so set {08 10 18}
            // perhaps note that 10 and 18 are not used in the JP game
            read8RawBytesForBitmaskGroup(BITMASK_GROUP_0);
        }
        else switch ((typeByte >> 3) & 0x3) {
            // 001x x000 where "xx" is not 00, so set {28 30 38}
            case 0x1: // 0010 1000
                getBitmaskDataFromRleFormat029277(BITMASK_GROUP_0);
                break;
            case 0x2: // 0011 0000
                constructBitmaskDataFromUniqueBytes0292A8(BITMASK_GROUP_0);
                break;
            case 0x3: // 0011 1000
                getBitmaskDataFromCombiningNibbles029305(BITMASK_GROUP_0);
                break;
        }
        generateTileDataFromBitmaskArrays029075(casesByte);
    }

    private static void generateTileDataFromBitmaskArrays029075(int casesByte) throws IOException {
        int tileDataPosition = startOfCurrTile;

        // 8-bit input consists of four 2-bit flags, one for each bitplane
        int cases[] = new int[BIT_DEPTH];
        for (int bp = 0; bp < cases.length; bp++) {
            cases[bp] = casesByte & 0x3;
            casesByte >>= 2;
        }

        if (DEBUG) {
            String summary = "Bitplane bytes:";
            for (int bp = 0; bp < cases.length; bp++) {
                String type = "";
                switch (cases[bp]) {
                    case 0x0: type = " 00"; break;
                    case 0x1: type = " nn"; break;
                    case 0x2: type = " ~nn"; break;
                    case 0x3: type = " FF"; break;
                }
                summary += type;
            }
            log.write(summary + "\n");
        }

        for (int y = 0; y < BITMASK_LIST_SIZE; y++) {
            for (int bp = 0; bp < cases.length; bp++) {
                int accumulator = 0x00;
                switch (cases[bp]) {
                    case 0x0: // 0b00 - use 0x00
                        accumulator = 0; break;
                    case 0x1: // 0b01 - use byte from $7FF69A
                        accumulator = bitmaskGroupsF69A[BITMASK_GROUP_0][y]; break;
                    case 0x2: // 0b10 - use byte from $7FF6B2 (bitwise NOT of $7FF69A)
                        accumulator = bitmaskGroupsF69A[BITMASK_GROUP_0][y] ^ 0xFF; break;
                    case 0x3: // 0b11 - bitwise OR the bytes from both, should be 0xFF
                        accumulator = 0xFF; break;
                }
                tileDataBuffer[tileDataPosition + BITPLANE_OFFSETS[bp]] = accumulator & 0xFF;
            }
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;
        }
    }

    private static void useTilesetMetadataToDoBitplaneSubroutines028E46(int typeByte) throws IOException {
        // 00xx 0001, see $028E42; use bytes at F6E5+(xx), F6E9+(xx), F6ED+(xx)
        int offset = (typeByte >> 4) & 0x3;
        bitplaneSubroutineRawBytes[0] = commonBitplaneSubIndexDataF6E5[offset];
        bitplaneSubroutineRawBytes[1] = commonBitplaneSubIndexDataF6E5[offset + 0x4];
        bitplaneSubroutineRawBytes[2] = commonBitplaneSubIndexDataF6E5[offset + 0x8];

        if (DEBUG) {
            String details = "Get subroutine IDs from tileset metadata, column %d ($028E46)\n";
            log.write(String.format(details, offset));
            countsForBitplaneSubIndexUsage[offset] += 1;
        }
        rotate1F0D_andDoBitplaneSubroutines();
    }

    private static void reuseExistingTileWithNewRows028E7D(int typeByte) throws IOException {
        // 00xx 1001: see $028E7D
        // get the byte offset of an existing tile (ID # in range 000-3FF)
        // the "xx" bits are the multiple of 0x100; next byte is the rest
        int tileNumLowByte = romFile.readUnsignedByte();
        int tileNumHighBits = (typeByte & 0x30) << 4;
        int srcTileNum = tileNumHighBits | tileNumLowByte;
        int existingTileOffset = srcTileNum * TILE_SIZE;

        int tileDataPosition = startOfCurrTile;
        int rowFlags = romFile.readUnsignedByte();

        if (DEBUG) {
            log.write(String.format("Use tile %03X as basis: replace rows\n", srcTileNum));
            log.write(String.format("%06X: flag byte %02X, tile num low byte %02X\n", romFile.getFilePointer() - 2, rowFlags, tileNumLowByte));
        }

        for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
            int flag = rowFlags & 0x80;
            rowFlags <<= 1;
            // flag 0 -> reuse the current row from the existing tile
            if (flag == 0) {
                tileDataBuffer[tileDataPosition] = tileDataBuffer[existingTileOffset];
                tileDataBuffer[tileDataPosition + BITPLANE_1] = tileDataBuffer[existingTileOffset + BITPLANE_1];
                tileDataBuffer[tileDataPosition + BITPLANE_2] = tileDataBuffer[existingTileOffset + BITPLANE_2];
                tileDataBuffer[tileDataPosition + BITPLANE_3] = tileDataBuffer[existingTileOffset + BITPLANE_3];
            }
            // flag 1 -> get a new row of data
            else {
                tileDataBuffer[tileDataPosition] = romFile.readUnsignedByte();
                tileDataBuffer[tileDataPosition + BITPLANE_1] = romFile.readUnsignedByte();
                tileDataBuffer[tileDataPosition + BITPLANE_2] = romFile.readUnsignedByte();
                tileDataBuffer[tileDataPosition + BITPLANE_3] = romFile.readUnsignedByte();
            }
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;
            existingTileOffset += NUM_BYTES_PER_ROW_IN_BITPLANE;
        }
    }

    // --------------------

    private static void debugBitmaskGroupBytes(int bitmaskGroup) throws IOException {
        if (bitmaskGroup >= NUM_GROUPS_OF_8_BITMASKS) return;

        String normalBytes = "[";
        String invertBytes = "[";
        String byteFormat = "%02X ";
        for (int i = 0; i < BITMASK_LIST_SIZE; i++) {
            int value = bitmaskGroupsF69A[bitmaskGroup][i];
            normalBytes += String.format(byteFormat, value);
            invertBytes += String.format(byteFormat, value ^ 0xFF);
        }
        normalBytes = normalBytes.trim() + "]";
        invertBytes = invertBytes.trim() + "]";

        log.write(String.format(" Grp %d bytes: %s\n", bitmaskGroup, normalBytes));
        log.write(String.format("~Grp %d bytes: %s\n", bitmaskGroup, invertBytes));
    }

    private static void read8RawBytesForBitmaskGroup(int bitmaskGroup) throws IOException {
        // determine if need to write to F69A (B2), F6A2 (BA), or F6AA (C2)
        if (DEBUG) {
            log.write("----------\n");
            log.write(String.format("0x%06X: Read 8 bytes of bitmask data, group %d\n", romFile.getFilePointer(), bitmaskGroup));
        }
        // int baseOffset = BITMASK_LIST_SIZE * bitmaskGroup;
        for (int i = 0; i < BITMASK_LIST_SIZE; i++) {
            int dataByte = romFile.readUnsignedByte();
            bitmaskGroupsF69A[bitmaskGroup][i] = dataByte;
            // bitmasksF6B2[i + baseOffset] = dataByte ^ 0xFF;
        }
        if (DEBUG) {
            debugBitmaskGroupBytes(bitmaskGroup);
        }
    }

    private static void getBitmaskDataFromRleFormat029277(int bitmaskGroup) throws IOException {
        int bitFlags = romFile.readUnsignedByte();
        if (DEBUG) {
            log.write("----------\n");
            log.write(String.format("0x%06X: RLE flags byte %02X for $029277, group %d\n", romFile.getFilePointer() - 1, bitFlags, bitmaskGroup));
        }

        // fill in new bitmasks like [00 00 xx xx xx yy yy zz]
        // int baseOffset = bitmaskGroup * BITMASK_LIST_SIZE;
        int dataByte = 0x00;
        for (int i = 0; i < BITMASK_LIST_SIZE; i++) {
            int bit = bitFlags & 0x80;
            if (bit != 0){
                dataByte = romFile.readUnsignedByte();
            }
            bitFlags = (bitFlags << 1) & 0xFF;

            bitmaskGroupsF69A[bitmaskGroup][i] = dataByte;
            // bitmasksF6B2[i + baseOffset] = dataByte ^ 0xFF;
        }
        if (DEBUG) {
            log.write(String.format("0x%06X: End data for $029277\n", romFile.getFilePointer() - 1));
            debugBitmaskGroupBytes(bitmaskGroup);
        }
    }

    private static void constructBitmaskDataFromUniqueBytes0292A8(int bitmaskGroup) throws IOException {
        int byte01 = romFile.readUnsignedByte();
        int byte00 = romFile.readUnsignedByte();
        int bitmaskIndices = byte00 | (byte01 << 8);

        // determine how many unique bytes are used in the bitmask sequence
        int numDataBytes = 0x4;
        if ((bitmaskIndices & 0x3) != 0) {
            numDataBytes = 0x3;
            bitmaskIndices &= ~0x3;
            // ASM @ $029562 is [DEX ; TXA ; TRB $00] where X starts out with 4
            // and becomes how many bytes to read, and $00 contains the indices
            // $00 <- $00 & ~(4 - 1) = $00 & ~3
            // so this both sets the first index to 0 and reduces # bytes to read
        }

        if (DEBUG) {
            log.write("----------\n");
            log.write(String.format("0x%06X: Read 2 bytes containing 8 2-bit indices %02X%02X, group %d\n", romFile.getFilePointer() - 2, byte01, byte00, bitmaskGroup));

            log.write(String.format("0x%06X: Bitmask constructed from %d unique bytes\n", romFile.getFilePointer(), numDataBytes));
        }

        for (int i = 0; i < numDataBytes; i++) {
            rawBitmaskDataForBytesNibblesCases[i] = romFile.readUnsignedByte();
        }

        // int baseOffset = bitmaskGroup * BITMASK_LIST_SIZE;
        int bitmaskF6DBPosition = 0;
        for (int i = 0; i < BITMASK_LIST_SIZE; i++) {
            bitmaskF6DBPosition = bitmaskIndices & 0x3;
            bitmaskIndices >>= 2;

            bitmaskGroupsF69A[bitmaskGroup][i] = rawBitmaskDataForBytesNibblesCases[bitmaskF6DBPosition];
            // bitmasksF6B2[i + baseOffset] = rawBitmaskDataForBytesNibblesCases[bitmaskF6DBPosition] ^ 0xFF;
        }
        if (DEBUG) {
            debugBitmaskGroupBytes(bitmaskGroup);
        }
    }

    private static void getBitmaskDataFromCombiningNibbles029305(int bitmaskGroup) throws IOException {
        if (DEBUG) {
            log.write("----------\n");
            log.write(String.format("0x%06X: Construct bitmask data from 4 unique nibbles, group %d\n", romFile.getFilePointer(), bitmaskGroup));
        }

        // int baseOffset = bitmaskGroup * BITMASK_LIST_SIZE;
        for (int i = 3; i >= 0; i--) {
            rawBitmaskDataForBytesNibblesCases[i] = romFile.readUnsignedByte();
        }
        // fill in F6E0 and F6DF
        int nextByte = romFile.readUnsignedByte();
        rawBitmaskDataForBytesNibblesCases[5] = nextByte & 0xF;
        rawBitmaskDataForBytesNibblesCases[4] = nextByte >> 4;

        // fill in F6E2 and F6E1
        nextByte = romFile.readUnsignedByte();
        rawBitmaskDataForBytesNibblesCases[7] = nextByte & 0xF;
        rawBitmaskDataForBytesNibblesCases[6] = nextByte >> 4;

        int indexF6DB = 0;
        boolean readHighNibble = false;
        for (int byte0 = 0; byte0 < BITMASK_LIST_SIZE; byte0++) {
            // bytes 0-3 at F6DB pack 16 2-bit indices: read from 4-7 in F6DB
            // access two nibbles at a time on each iteration
            int byte3 = rawBitmaskDataForBytesNibblesCases[indexF6DB];

            int resultHiNibble = rawBitmaskDataForBytesNibblesCases[4 + (byte3 & 0x3)];
            int resultLoNibble = rawBitmaskDataForBytesNibblesCases[4 + ((byte3 >> 2) & 0x3)];
            int result = (resultHiNibble << 4) | resultLoNibble;

            bitmaskGroupsF69A[bitmaskGroup][byte0] = result;
            // bitmasksF6B2[byte0 + baseOffset] = result ^ 0xFF;

            // increment byte index in F6DB array on every other loop iteration
            if (!readHighNibble) {
                readHighNibble = true;
                rawBitmaskDataForBytesNibblesCases[indexF6DB] = byte3 >> 4;
            }
            else {
                readHighNibble = false;
                indexF6DB++;
            }
        }
        if (DEBUG) {
            debugBitmaskGroupBytes(bitmaskGroup);
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int flagsByteForGettingBitmaskData;

    // see $0290E5 for even cases, $029121 for odd cases
    private static void constructTileFromBitmaskGroups(BitmaskSubroutines y, int typeByte) throws IOException {
        // 00xx x010, 00xx x100, 00xx x110
        // 00xx x011, 00xx x101, 00xx x111
        subroutineMarkerF6E3 = y;
        flagsByteForGettingBitmaskData = typeByte << 2;

        int bitFlagsInput = useTypeByteToGetBitpackedListPositions(typeByte);

        // see $02913E; fill current tile with 0x20 [00] bytes
        int tileDataPosition = startOfCurrTile;
        for (int i = 0; i < TILE_SIZE; i++) {
            tileDataBuffer[tileDataPosition + i] = 0x00;
        }

        int bitPosListSize = createListOfSetBitsAndReturnSize029151(bitFlagsInput);
        if (DEBUG) {
            log.write(String.format("Got bitpacked list: [%02X%02X]\n", bitFlagsInput >> 8, bitFlagsInput & 0xFF));
            printSetBitListToLog();
        }

        // $02916B: set $1F0C <- 0x02, $1F0D <- size of the list
        // in interest of keeping port simple to read, leaving out
        // memory1F0C = NUM_GROUPS_OF_8_BITMASKS - 1;
        // memory1F0D = bitPosListSize;

        boolean fiveOrMoreListEntries = bitPosListSize >= 5;
        getSetsOfBitmaskData029175(fiveOrMoreListEntries);
        combineBitmasksBasedOnListPos(fiveOrMoreListEntries);
    }

    private static int useTypeByteToGetBitpackedListPositions(int typeByte) throws IOException {
        int byte0 = 0;
        int byte1 = 0;

        // if bit 0 is 1, read 1 byte to get 2 bytes from the tileset's metadata
        // 00xx x011, 00xx x101, or 00xx x111 (see $0290D8, $0290DD, or $0290E2)
        // in particular, see $0290E8-$029112
        if ((typeByte & 0x1) != 0) {
            byte1 = romFile.readUnsignedByte();
            byte0 = 0;

            if (DEBUG) {
                String line = "0x%06X: Read 1 byte %02X\n";
                log.write(String.format(line, romFile.getFilePointer() - 1, byte1));
            }

            // get byte from memory range $F6F1-$F6FF, or just use 00
            int index0 = byte1 >> 4;
            int index1 = byte1 & 0xF;
            if (index0 != 0) {
                // implementation detail: the value is encoded as 1-indexed, but
                // we need 0-indexed for a Java array
                byte0 = commonDataForBitmaskBitPositionListF6F0[index0 - 1];
                if (DEBUG) {
                    String line = "Get byte from tileset metadata: %02X\n";
                    log.write(String.format(line, byte0));
                    countsForBitmaskMetadataUsage[index0 - 1] += 1;
                }
            }
            if (index1 != 0) {
                // similar to above
                byte1 = commonDataForBitmaskBitPositionListF6F0[index1 - 1];
                if (DEBUG) {
                    String line = "Get byte from tileset metadata: %02X\n";
                    log.write(String.format(line, byte1));
                    countsForBitmaskMetadataUsage[index1 - 1] += 1;
                }
            }
        }

        // if bit 0 is 0, just read 2 bytes from the ROM
        // 00xx x010, 00xx x100, or 00xx x110 (see $029114, $029119, or $02911E)
        // in particular, see $029124-$02913C
        else {
            byte0 = romFile.readUnsignedByte();
            byte1 = romFile.readUnsignedByte();
            if (DEBUG) {
                String line = "0x%06X: Read 2 bytes for bit positions\n";
                log.write(String.format(line, romFile.getFilePointer() - 2));
            }
        }

        return byte0 | (byte1 << 8);
    }

    private static int createListOfSetBitsAndReturnSize029151(int bitFlagsInput) throws IOException {
        // convert the input from a 16-bit value to a list (FF-terminated) of
        // the positions with bit 1 in it (MSB = bit 0, LSB = bit F)
        int bitPositionListPos = 0;
        int bitPos = 0;
        do {
            // shift out a bit in buffer
            int bit = bitFlagsInput & 0x8000;
            bitFlagsInput = (bitFlagsInput << 1) & 0xFFFF;

            // if shifted out a 1, take note of its bit position
            if (bit != 0x00) {
                // this check is not in the original code, but putting here if
                // somehow the data is malformed and desyncs from the intended decompression
                if (bitPositionListPos >= MAX_NUM_BIT_POSITIONS) {
                    String error = "ERROR: got 9+ bit positions in bitpacked list";
                    if (DEBUG) {
                        log.write(error + "\n");
                        log.flush();
                    }
                    throw new IOException(error);
                }
                bitPositionListF6D2[bitPositionListPos] = bitPos;
                bitPositionListPos++;
            }

            // if buffer is now 0, write an FF terminator
            if (bitFlagsInput == 0x0) {
                bitPositionListF6D2[bitPositionListPos] = BIT_POSITION_LIST_TERMINATOR;
            }

            bitPos++;
        } while (bitFlagsInput != 0x0);

        // return the position of the list terminator
        return bitPositionListPos;
    }

    private static void printSetBitListToLog() throws IOException {
        log.write("Got bit positions:");
        int i = 0;
        while (true) {
            int bitPos = bitPositionListF6D2[i];
            i++;
            if (bitPos == BIT_POSITION_LIST_TERMINATOR) break;
            log.write(String.format(" %01X", bitPos));
        }
        log.write(String.format(" (size %d)\n", i-1));
    }

    private static void getSetsOfBitmaskData029175(boolean fiveOrMoreListEntries) throws IOException {
        int numSetsOfBitmaskData = !fiveOrMoreListEntries ? 2 : 3;
        for (int bitmaskGroup = 0; bitmaskGroup < numSetsOfBitmaskData; bitmaskGroup++) {
            int bit = flagsByteForGettingBitmaskData & 0x80;
            flagsByteForGettingBitmaskData = (flagsByteForGettingBitmaskData << 1) & 0xFF;
            if (bit == 0x0) {
                read8RawBytesForBitmaskGroup(bitmaskGroup);
            }
            else switch (subroutineMarkerF6E3) {
                case UseRleFormat:
                    getBitmaskDataFromRleFormat029277(bitmaskGroup);
                    break;
                case ConstructFromBytes:
                    constructBitmaskDataFromUniqueBytes0292A8(bitmaskGroup);
                    break;
                case ConstructFromNibbles:
                    getBitmaskDataFromCombiningNibbles029305(bitmaskGroup);
                    break;
            }
        }
    }

    private static void combineBitmasksBasedOnListPos(boolean fiveOrMoreListEntries) throws IOException {
        // after reading the bitmask data, # of set bits tells whether to go to
        // $029194 or $0291D1; both are the same except that $0291D1 adds
        // an extra step with the bitmask combination
        int listPos = 0;
        int bitPosValue = bitPositionListF6D2[listPos];

        if (DEBUG) {
            log.write("---------\n");
        }
        while (bitPosValue != BIT_POSITION_LIST_TERMINATOR) {
            for (int i = BITMASK_LIST_SIZE - 1; i >= 0; i--) {
                // combine bitmasks based on list position
                int groupZeroValue = bitmaskGroupsF69A[BITMASK_GROUP_0][i];
                int groupOneValue = bitmaskGroupsF69A[BITMASK_GROUP_1][i];
                int groupTwoValue = 0xFF;

                if ((listPos & 0x1) == 0) {
                    groupZeroValue ^= 0xFF;
                }
                if ((listPos & 0x2) == 0) {
                    groupOneValue ^= 0xFF;
                }
                if (fiveOrMoreListEntries) {
                    groupTwoValue = bitmaskGroupsF69A[BITMASK_GROUP_2][i];
                    if ((listPos & 0x4) == 0) {
                        groupTwoValue ^= 0xFF;
                    }
                }

                combinedBitmaskDataF6CA[i] = groupZeroValue & groupOneValue & groupTwoValue;
            }

            if (DEBUG) {
                log.write(String.format("Pos. %1X masks: [", bitPosValue));
                String bitmaskBytes = "";
                for (int i = 0; i < BITMASK_LIST_SIZE; i++) {
                    bitmaskBytes += String.format("%02X ", combinedBitmaskDataF6CA[i]);
                }
                log.write(bitmaskBytes.trim() + "] ; bp: ");
                log.write((bitPosValue & 0x8) == 0 ? "-" : "3");
                log.write((bitPosValue & 0x4) == 0 ? "-" : "2");
                log.write((bitPosValue & 0x2) == 0 ? "-" : "1");
                log.write((bitPosValue & 0x1) == 0 ? "-" : "0");

                log.write(" ; groups ");
                if (fiveOrMoreListEntries) {
                    log.write(((listPos & 0x4) == 0 ? "~" : " ") + "2 & ");
                }
                log.write(((listPos & 0x2) == 0 ? "~" : " ") + "1 & ");
                log.write(((listPos & 0x1) == 0 ? "~" : " ") + "0");

                log.write("\n");
            }

            fillInBytesInBitplane029218(bitPosValue);
            listPos++;
            bitPosValue = bitPositionListF6D2[listPos];
        }
    }

    private static void fillInBytesInBitplane029218(int bitPosValue) throws IOException {
        int tileDataPosition = startOfCurrTile;

        for (int i = 0; i < combinedBitmaskDataF6CA.length; i++) {
            // each bit of the bit position value represents which tile bitplane to
            // modify; e.g. 0x3 (0b0011) does bp 0 and 1; 0x8 does bp 3 only
            for (int bp = 0; bp < BIT_DEPTH; bp++) {
                boolean modifyBitplane = (bitPosValue & (1 << bp)) != 0;
                if (modifyBitplane) {
                    int bpPosition = tileDataPosition + BITPLANE_OFFSETS[bp];
                    tileDataBuffer[bpPosition] |= combinedBitmaskDataF6CA[i];
                }
            }
            tileDataPosition += NUM_BYTES_PER_ROW_IN_BITPLANE;
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void reuseExistingTileWithNewBitplanes028EFD(int typeByte) throws IOException {
        // binary 01bb bbnn: see $028EFD
        // this takes an already decompressed tile's data and modifies it into
        // a new tile on a bitplane-by-bitplane basis

        // bits 2-5: flags for which bitplanes to modify (bit 5 -> bp0, bit 2 -> bp3)
        // bits 0-1: top 2 bits of tile number (000-3FF) to reuse
        // next byte: low byte of tile number to reuse
        int flagsBitplanesToModify = (typeByte << 2) & 0xF0;
        int tileNumber = (typeByte & 0x3) << 8;
        tileNumber |= romFile.readUnsignedByte();
        int tileIndex = (tileNumber * TILE_SIZE) & 0xFFFF;

        // $028F1C: copy 0x20 bytes (one 4bpp tile) to use as starting point
        int tileDataPosition = startOfCurrTile;
        for (int i = 0; i < TILE_SIZE; i++) {
            tileDataBuffer[tileDataPosition + i] = tileDataBuffer[tileIndex + i];
        }

        // $028F7E: read new data into $0B-$0E * as appropriate
        // indicate that 1+ of the four bit planes must be altered
        // *: original ASM used $1F0B-$1F0E, but using dedicated variable here
        //    in the interest of readability
        String bitplaneList = "";
        int flagBytes[] = new int[0x4];
        for (int i = 0; i < flagBytes.length; i++) {
            int flag = flagsBitplanesToModify & 0x80;
            int dataByte = 0;
            if (flag != 0) {
                dataByte = romFile.readUnsignedByte();
                bitplaneList += " " + i;
            }
            flagBytes[i] = dataByte;
            flagsBitplanesToModify <<= 1;
        }

        if (DEBUG) {
            String format = "Use tile %03X as basis; alter bitplanes%s\n";
            log.write(String.format(format, tileNumber, bitplaneList));

            String format2 = "Flag bytes for how to alter bitplanes:";
            for (int value : flagBytes) {
                String valString = " --";
                if (value != 0) {
                    valString = String.format(" %02X", value);
                }
                format2 += valString;
            }
            log.write(format2 + "\n");
        }

        // use the data in $0B-$0E as bitmasks for what bytes to modify of the
        // chosen bitplanes
        for (int bpNum = 0; bpNum < flagBytes.length; bpNum++) {
            int bp = BITPLANE_OFFSETS[bpNum];
            int tileRowIndex = startOfCurrTile;
            while (flagBytes[bpNum] != 0) {
                int flag = flagBytes[bpNum] & 0x80;
                flagBytes[bpNum] = (flagBytes[bpNum] << 1) & 0xFF;

                if (flag != 0) {
                    tileDataBuffer[tileRowIndex + bp] = romFile.readUnsignedByte();
                }
                tileRowIndex += NUM_BYTES_PER_ROW_IN_BITPLANE;
            }
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void readTilesetMetadata() throws IOException {
        // read metadata = first 0x1B bytes at ptr
        commonBitplaneSubIndexDataF6E5 = new int[COMMON_BP_SUB_INDEX_DATA_SIZE];
        for (int i = 0; i < commonBitplaneSubIndexDataF6E5.length; i++) { // 0xC bytes
            commonBitplaneSubIndexDataF6E5[i] = romFile.readUnsignedByte();
        }

        commonDataForBitmaskBitPositionListF6F0 = new int[COMMON_BITMASK_BIT_POSITIONS_DATA_SIZE];
        for (int i = 0; i < commonDataForBitmaskBitPositionListF6F0.length; i++) { // 0xF bytes
            commonDataForBitmaskBitPositionListF6F0[i] = romFile.readUnsignedByte();
        }
    }

    private static void logTilesetMetadata() throws IOException {
        String tileMetadataOutput = String.format("Metadata @ 0x%06X:",
            romFile.getFilePointer() - METADATA_HEADER_SIZE);

        countsForBitplaneSubIndexUsage = new int[COMMON_BP_SUB_INDEX_DATA_SIZE];
        countsForBitmaskMetadataUsage = new int[COMMON_BITMASK_BIT_POSITIONS_DATA_SIZE];

        for (int i = 0; i < commonBitplaneSubIndexDataF6E5.length; i++) { // 0xC bytes
            tileMetadataOutput += ((i & 0x3) == 0x0) ? "\n" : " ";
            tileMetadataOutput += String.format("%02X", commonBitplaneSubIndexDataF6E5[i]);
        }
        tileMetadataOutput += "\n";
        for (int i = 0; i < commonDataForBitmaskBitPositionListF6F0.length; i++) { // 0xF bytes
            tileMetadataOutput += String.format("%02X ", commonDataForBitmaskBitPositionListF6F0[i]);
        }
        log.write(tileMetadataOutput + "\n\n");
    }

    private static void logTilesetMetadataUsage() throws IOException {
        log.write("\nUsage for bitplane sub index metadata:");
        int sum = 0;
        for (int i = 0; i < COMMON_BP_SUB_INDEX_DATA_SIZE / NUM_BYTES_FOR_ENCODED_BP_SUBS; i++) {
            int count = countsForBitplaneSubIndexUsage[i];
            log.write(String.format(" %d", count));
            sum += count;
        }
        log.write(String.format(" (%d)", sum));

        log.write("\nUsage for bitmask bit pos list metadata:");
        sum = 0;
        for (int i = 0; i < countsForBitmaskMetadataUsage.length; i++) {
            int count = countsForBitmaskMetadataUsage[i];
            log.write(String.format(" %d", count));
            sum += count;
        }
        log.write(String.format(" (%d)", sum));
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int getFilePos(int loROMPtr) {
        int numBanks = loROMPtr >> 16;
        int offsetInBank = loROMPtr & 0x7FFF;
        return numBanks * 0x8000 + offsetInBank;
    }

    public static void dumpTilesFromStandaloneFile(String pathToFile, boolean debugArg) throws IOException {
        romFile = new RandomAccessFile(pathToFile, "r");
        romFile.seek(0);

        // extract out the path and the file name
        int folderPathLength = pathToFile.lastIndexOf("/");
        String folderPath = folderPathLength == -1 ? "" : pathToFile.substring(0, folderPathLength);
        String filename = pathToFile.substring(folderPathLength + 1);

        // put the decompression output and log in the same folder as the source file
        String outputFilenameFormat = folderPath + "/decompress '%s' tileset.bin";
        String outputName = String.format(outputFilenameFormat, filename);

        DEBUG = debugArg;
        if (DEBUG) {
            log = new BufferedWriter(new FileWriter(String.format(folderPath + "LOG decompress '%s' tileset.txt", pathToFile)));
        }

        dumpTiles();
        outputTileData(outputName, false);
        romFile.close();
    }

    public static void dumpTilesetsFromJapaneseGame(boolean debugArg) throws IOException {
        final int GFX_PTR_LIST = 0x128000;
        final int NUM_GFX_PTRS = 0x82;
        // int loRomPtrs[] = new int[NUM_GFX_PTRS];

        romFile = new RandomAccessFile("rom/Kamaitachi no Yoru (Japan).sfc", "r");
        String outputFolder = "decompressed tilesets from JP game/";
        Files.createDirectories(Paths.get(outputFolder));

        for (int gfxId = 0; gfxId < NUM_GFX_PTRS; gfxId++) {
            // each gfx ID has three 24-bit pointers to gfx data
            // order: palettes, tilemaps, tilesets
            romFile.seek(GFX_PTR_LIST + gfxId*9 + 6);
            int loRomPtr = romFile.readUnsignedByte();
            loRomPtr |= romFile.readUnsignedByte() << 8;
            loRomPtr |= romFile.readUnsignedByte() << 16;
            // loRomPtrs[gfxId] = loRomPtr;

            dumpTilesetFromLoRomPtrInJapaneseGame(loRomPtr, gfxId, outputFolder, debugArg);
        }
        romFile.close();
    }

    private static void dumpTilesetFromLoRomPtrInJapaneseGame(int loRomPtr, int gfxID, String outputFolder, boolean debugArg) throws IOException {
        // two options for name of output files: LoROM pointer to data, or the
        // graphics ID number; latter is easier for Asar insertion
        int filePos = getFilePos(loRomPtr);
        romFile.seek(filePos);

        DEBUG = debugArg;
        if (DEBUG) {
            // log = new BufferedWriter(new FileWriter(String.format(outputFolder + "LOG $%06X tile decompress.txt", loRomPtr)));
            log = new BufferedWriter(new FileWriter(String.format(outputFolder + "LOG decompressed tileset %02X.txt", gfxID)));
        }

        dumpTiles();

        // String outputFilenameFormat = outputFolder + "$%06X tile data.bin";
        // String outputName = String.format(outputFilenameFormat, loRomPtr);
        String outputFilenameFormat = outputFolder + "decompressed tileset %02X.bin";
        String outputName = String.format(outputFilenameFormat, gfxID);

        outputTileData(outputName, false);
    }

    private static void dumpTiles() throws IOException {
        // implement the subroutine at $028DAA
        int filePos = (int) romFile.getFilePointer();

        // create an empty (4bpp) tile of 0x20 bytes that are all [00]
        startOfCurrTile = 0;
        for (int i = 0; i < TILE_SIZE; i++) {
            tileDataBuffer[startOfCurrTile + i] = 0x00;
        }
        startOfCurrTile += TILE_SIZE;

        readTilesetMetadata();
        if (DEBUG) {
            logTilesetMetadata();
        }

        int typeBytePos = (int) romFile.getFilePointer();
        int typeByte = romFile.readUnsignedByte();
        // keep reading bytes from the ROM until you get the "end of data" 0x00
        while (typeByte != END_OF_TILE_DATA) {
            // strongly recommend debug logging if you want to port this program
            if (DEBUG) {
                log.write(String.format("\nType byte @ 0x%06X: %02X\n", typeBytePos, typeByte));
                log.write(String.format("VRAM buffer offset: 0x%4X (tile %3X)\n", startOfCurrTile, startOfCurrTile >> 5));
            }

            // decompress tile data based on what byte you got
            // check if the MSB of the byte is 1 or not
            if ((typeByte & 0x80) != 0) {
                // 1xxx xxxx: see $028E77
                setUpToRunBitplaneSubroutines028E77(typeByte);
            }
            // if MSB is not 1, check if MSBs are 00 or 01
            else if ((typeByte & 0xC0) == 0x00) {
                // 00xx xxxx: see $028E0E
                case00to3F_028E0E(typeByte);
            }
            else {
                // 01bb bbnn: see $028EFD
                reuseExistingTileWithNewBitplanes028EFD(typeByte);
            }

            if (DEBUG) {
                int currPos = (int) romFile.getFilePointer();
                int tagSize = currPos - typeBytePos;
                int totalSizeSoFar = currPos - filePos;
                log.write(String.format("Tag size: 0x%2X (0x%4X)\n", tagSize, totalSizeSoFar));
            }

            // see $028DF2: advance to next tile, and read another type byte
            typeBytePos = (int) romFile.getFilePointer();
            typeByte = romFile.readUnsignedByte();
            startOfCurrTile += TILE_SIZE;
        }

        if (DEBUG) {
            log.write(String.format("\nType byte 0x00 @ 0x%06X, exiting", typeBytePos));
            logTilesetMetadataUsage();

            log.flush();
            log.close();
        }
    }

    private static void outputTileData(String pathToOutputFile, boolean padToMultipleOf100Tiles) throws IOException {
        FileOutputStream tileData = new FileOutputStream(pathToOutputFile);

        int outputSize = startOfCurrTile;
        if (padToMultipleOf100Tiles) {
            // size of the output file is # bytes, rounded up to next multiple of
            // 0x100 tiles' worth of data; only output as much data as necessary
            // I think most people won't want this, but I found this useful when
            // trying to look at the tileset data in YY-CHR and exporting pages
            // of 0x100 tiles at a time to view in Tilemap Studio
            boolean roundUp = (startOfCurrTile % BYTES_FOR_100_TILES) != 0;
            outputSize = BYTES_FOR_100_TILES * ((startOfCurrTile / BYTES_FOR_100_TILES) + (roundUp ? 1 : 0));
        }

        for (int i = 0; i < outputSize; i++) {
            int data = tileDataBuffer[i] & 0xFF;
            if (i >= startOfCurrTile) {
                data = 0x00;
            }
            tileData.write(data);
        }

        tileData.flush();
        tileData.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    public static void main(String args[]) throws IOException {
        dumpTilesetsFromJapaneseGame(true);
    }
}
