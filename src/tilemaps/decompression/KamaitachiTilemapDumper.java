package tilemaps.decompression;

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.file.Files;
import java.nio.file.Paths;

import static tilemaps.constants.TilemapCompConstants.*;

public class KamaitachiTilemapDumper {
    private static final int SPECIAL_3F = 0x3F;

    private static final int FIVE_BIT_ENC_SIZE_BITMASK = 0x1F;

    private static final int LOROM_PTR_TO_FILE_START = 0x8000;

    private static final boolean GETTING_PALETTES = true;

    private static int tilemapFilePtr;

    private static int tilemapLowBytes[];
    private static int tilemapHighBytes[];

    private static RandomAccessFile romFile;

    private static final String OUTPUT_FOLDER = "decompressed tilemaps/";

    // #########################################################################
    // #########################################################################

    // useful bitmasks for understanding control flow
    private static final int TOP_4_BITS = 0xF0;
    private static final int TOP_3_BITS = 0xE0;
    private static final int TOP_2_BITS = 0xC0;

    private static int getTop2Bits(int typeByte) {
        return (typeByte & TOP_2_BITS) >> 6;
    }

    private static int getTop3Bits(int typeByte) {
        return (typeByte & TOP_3_BITS) >> 5;
    }

    private static int getTop4Bits(int typeByte) {
        return (typeByte & TOP_4_BITS) >> 4;
    }

    // #########################################################################
    // #########################################################################

    private static final int GFX_PTR_LIST = 0x128000;
    private static final int GFX_PTR_LIST_SIZE = 0x82;

    private static int[] tilemapPtrList = new int[GFX_PTR_LIST_SIZE];

    private static int getROMPtr(int ramPtr) {
        final int BANK_SIZE = 0x8000;
        int bankNum = ramPtr >> 16;
        int bankOffset = ramPtr & 0xFFFF;

        return BANK_SIZE * (bankNum - 1) + bankOffset;
    }

    private static int readPointer() throws IOException {
        int ptr = romFile.readUnsignedByte();
        ptr |= (romFile.readUnsignedByte() << 8);
        ptr |= (romFile.readUnsignedByte() << 16);

        return ptr;
    }

    private static void readGfxPtrs() throws IOException {
        romFile.seek(GFX_PTR_LIST);
        for (int i = 0; i < GFX_PTR_LIST_SIZE; i++) {
            // palettePtrList[i] = readPointer();
            readPointer();
            tilemapPtrList[i] = readPointer();
            // tilePtrList[i] = readPointer();
            readPointer();
        }
    }

    public static void readMetadataFromROM() throws IOException {
        romFile = new RandomAccessFile("rom/Kamaitachi no Yoru (Japan).sfc", "r");
        readGfxPtrs();
    }

    // #########################################################################
    // #########################################################################

    // general note: this decompression ASM port was written more with intent to
    // directly translate it rather than necessarily being easy to read/parse
    // TODO make off-by-one errors harder to accidentally include in any subsequent ports

    private static void getTilemapLowBytes(boolean uncompLowBytes) throws IOException {
        if (uncompLowBytes) {
            // implement code at $029ABD, then move on to the next phase
            for (int i = 0; i < NUM_TILEMAP_ENTRIES; i++) {
                tilemapLowBytes[i] = romFile.readUnsignedByte();
            }
            return;
        }

        // otherwise, start with code at $029AD3
        int numBytesDone = 0;
        int currTileNum = STARTING_LOW_BYTE;

        do {
            int typeByte = romFile.readUnsignedByte();
            int top2Bits = getTop2Bits(typeByte);
            switch (top2Bits) {
                // $029B02: case MSBs are 0b00 (range 00-3F)
                case 0x0: {
                    // 00rr rrrr
                    // repeat the current tile ID a total of (typeByte + 2) times
                    int repeatCount = typeByte + REPEAT_CASE_MIN_SIZE;
                    for (int i = 0; i < repeatCount && numBytesDone < NUM_TILEMAP_ENTRIES; i++) {
                        tilemapLowBytes[numBytesDone] = currTileNum;
                        numBytesDone++;
                    }
                    // move on to next tile number
                    currTileNum = (currTileNum + 1) & 0xFF;
                    break;
                }

                // $029B13: case MSBs are 0b01 (range 40-7F) - 0x7F is special case
                case 0x1: {
                    // 01rr rrrr; write sequence of tile IDs that start with the
                    // current tile ID and increase by 1 on each iteration
                    int size = typeByte & INC_SEQ_SIZE_THRESHOLD_3F;
                    if (size == INC_SEQ_SIZE_THRESHOLD_3F) {
                        size = romFile.readUnsignedByte();
                    }
                    size++;

                    while (size > 0 && numBytesDone < NUM_TILEMAP_ENTRIES) {
                        tilemapLowBytes[numBytesDone] = currTileNum;
                        currTileNum = (currTileNum + 1) & 0xFF;
                        numBytesDone++;
                        size--;
                    }
                    break;
                }

                default: {
                    int top3Bits = getTop3Bits(typeByte);
                    switch (top3Bits) {
                        // $029B33: case MSBs are 0x100 (range 80-9F)
                        case 0x4: {
                            // 100r rrrr; go back 0x20 bytes, and copy the
                            // specified number of bytes to the current position
                            int repeatCount = (typeByte & FIVE_BIT_ENC_SIZE_BITMASK) + 1;

                            while (repeatCount > 0 && numBytesDone < NUM_TILEMAP_ENTRIES) {
                                tilemapLowBytes[numBytesDone] = tilemapLowBytes[numBytesDone - NUM_TILES_IN_ROW];
                                numBytesDone++;
                                repeatCount--;
                            } 
                            break;
                        }

                        // $029B4F: case MSBs are 0x101 (range A0-BF)
                        case 0x5: {
                            // 101r rrrr; reuse most recently written low byte
                            int repeatCount = (typeByte & FIVE_BIT_ENC_SIZE_BITMASK) + 1;
                            int lowByteToRepeat = tilemapLowBytes[numBytesDone - 1];

                            while (repeatCount > 0 && numBytesDone < NUM_TILEMAP_ENTRIES) {
                                tilemapLowBytes[numBytesDone] = lowByteToRepeat;
                                numBytesDone++;
                                repeatCount--;
                            }
                            break;
                        }

                        // $029B63: case MSBs are 0x110 (range C0-DF) - 0xDF is special case
                        case 0x6: {
                            // 110r rrrr; read new tile ID from ROM and repeat it
                            int repeatCount = typeByte & FIVE_BIT_ENC_SIZE_BITMASK;
                            if (typeByte == 0xDF) {
                                repeatCount = romFile.readUnsignedByte() - 1;
                            }
                            repeatCount += REPEAT_CASE_MIN_SIZE;
                            int lowByteToRepeat = romFile.readUnsignedByte();

                            while (repeatCount > 0 && numBytesDone < NUM_TILEMAP_ENTRIES) {
                                tilemapLowBytes[numBytesDone] = lowByteToRepeat;
                                numBytesDone++;
                                repeatCount--;
                            }
                            break;
                        }

                        // $029B8B: case MSBs are 0x111 (range E0-FF)
                        case 0x7: {
                            // 111r rrrr; copy directly from ROM into buffer
                            // note that for some reason, gfx ID 01 is set up to
                            // have two literal low bytes at the end when it
                            // only needs one, and you do need to read + discard
                            // the extra byte for decompression as a whole to be
                            // correct to the game's specification
                            int numLiterals = (typeByte & FIVE_BIT_ENC_SIZE_BITMASK) + 1;
                            while (numLiterals > 0) {
                                int lit = romFile.readUnsignedByte();
                                if (numBytesDone < NUM_TILEMAP_ENTRIES) {
                                    tilemapLowBytes[numBytesDone] = lit;
                                    numBytesDone++;
                                }
                                numLiterals--;
                            }
                            break;
                        }
                    }
                }
            }
        }
        while (numBytesDone < NUM_TILEMAP_ENTRIES);
    }

    // #########################################################################
    // #########################################################################

    private static int bufferForByteFromPtr;
    private static int numBitPairsLeftInByteBuffer;

    private static int getTwoBitsFromByteFromPtr() throws IOException {
        // implements subroutine at $029EAA
        numBitPairsLeftInByteBuffer--;
        if (numBitPairsLeftInByteBuffer < 0) {
            bufferForByteFromPtr = romFile.readUnsignedByte();
            numBitPairsLeftInByteBuffer = NUM_TWO_BIT_VALS_IN_BUFFER - 1;
        }

        // keep the two MSBs, and shift buffer left to put next bit pair in position
        int bits = bufferForByteFromPtr & 0xC0;
        bufferForByteFromPtr <<= 2;
        return bits;
    }

    private static void getTileIDsHighTwoBits(boolean uncompTileIDHigh2Bits) throws IOException {
        bufferForByteFromPtr = 0;
        numBitPairsLeftInByteBuffer = 0;
        // implements code at $029BA3
        if (uncompTileIDHigh2Bits) {
            for (int i = 0; i < NUM_TILEMAP_ENTRIES; i++) {
                int topTileIDBits = getTwoBitsFromByteFromPtr() >> 6;
                tilemapHighBytes[i] = topTileIDBits;
            }
            return;
        }

        int numBytesDone = 0;
        do {
            int typeByte = romFile.readUnsignedByte();
            int top2Bits = getTop2Bits(typeByte);
            switch (top2Bits) {
                // case MSBs are 0b00 (range 00-3F) - has special case for byte 0x3F
                // see $029BEA
                case 0x0: {
                    // 00rr rrrr
                    int repeatCount = typeByte;
                    if (repeatCount == SPECIAL_3F) {
                        repeatCount = romFile.readUnsignedByte();
                    }
                    repeatCount++;

                    for (int i = 0; i < repeatCount && numBytesDone < NUM_TILEMAP_ENTRIES; i++) {
                        tilemapHighBytes[numBytesDone] = 0x00;
                        numBytesDone++;
                    }
                    break;
                }

                // case MSBs are 0b010 or 0b011 (range 40-5F and 60-7F)
                // these have different repeat counts and ways of getting the high
                // bits but reuse ASM, so combining them together here as well
                case 0x1: {
                    int repeatCount = 0;
                    int tileIDHighBits = 0;
                    if ((typeByte & 0x20) == 0) {
                        // case MSBs are 0b010 (40-5F) - $029C06
                        // 010n nrrr
                        repeatCount = (typeByte & 0x7) + 1;
                        tileIDHighBits = typeByte >> 3;
                    }
                    else {
                        // case MSBs are 0b011 (60-7F) - $029C11
                        // 011r rrrr
                        repeatCount = (typeByte & 0x1F) + HIGH_BITS_00_RUN_THRESHOLD_08 + 1;
                        tileIDHighBits = getTwoBitsFromByteFromPtr() >> 6;
                    }

                    // converge @ $029C1E; first, store a single value for high bits
                    tilemapHighBytes[numBytesDone] = tileIDHighBits & HIGH_BITS_BITMASK;
                    numBytesDone++;

                    // then, fill in the next repeatCount bytes with 0b00
                    // Java arrays are pre-filled with 00 bytes, so can skip bytes?
                    // numBytesDone += repeatCount;
                    for (int i = 0; i < repeatCount && numBytesDone < NUM_TILEMAP_ENTRIES; i++) {
                        tilemapHighBytes[numBytesDone] = 0x00;
                        numBytesDone++;
                    }
                    break;
                }

                // case MSBs are 0b100 or 0b101 (range 80-BF); these similarly reuse code
                case 0x2: {
                    int repeatCount = 0;
                    int tileIDHighBits = 0;
                    if ((typeByte & 0x20) == 0) {
                        // case MSBs are 0b100 (range 80-9F) - $029C30
                        // 100n nrrr
                        repeatCount = (typeByte & 0x7) + REPEAT_CASE_MIN_SIZE;
                        tileIDHighBits = typeByte >> 3;
                    }
                    else {
                        // case MSBs are 0b101 (range A0-BF) - $029C3C
                        // 101r rrrr
                        repeatCount = (typeByte & 0x1F) + HIGH_BITS_REPEAT_VAL_THRESHOLD_09 + 1;
                        tileIDHighBits = getTwoBitsFromByteFromPtr() >> 6;
                    }

                    tileIDHighBits &= HIGH_BITS_BITMASK;

                    // converge @ $029C49; repeat the high bits as many times as specified
                    for (int i = 0; i < repeatCount && numBytesDone < NUM_TILEMAP_ENTRIES; i++) {
                        tilemapHighBytes[numBytesDone] = tileIDHighBits & HIGH_BITS_BITMASK;
                        numBytesDone++;
                    }
                    break;
                }

                // $029C56: case MSBs are 0b11 (range C0-FF)
                case 0x3: {
                    // 11nn rrrr
                    int numLiterals = typeByte & 0xF;

                    int highBits = (typeByte >> 4) & HIGH_BITS_BITMASK;
                    // first, write the high bits from the type byte
                    tilemapHighBytes[numBytesDone] = highBits;
                    numBytesDone++;

                    // and on subsequent iterations, write high bits extracted
                    // from the pointer byte buffer
                    while (numLiterals > 0) {
                        highBits = getTwoBitsFromByteFromPtr() >> 6;
                        if (numBytesDone < NUM_TILEMAP_ENTRIES) {
                            tilemapHighBytes[numBytesDone] = highBits;
                            numBytesDone++;
                        }
                        numLiterals--;
                    }
                    break;
                }
            }
        }
        while (numBytesDone < NUM_TILEMAP_ENTRIES);
    }

    // #########################################################################
    // #########################################################################

    private static int threeByteBuffer[] = new int[NUM_BYTES_IN_PALETTE_BUFFER];
    private static int numPalettesLeftIn3ByteBuffer = 0;

    private static int getNthPaletteNumFrom3ByteBuffer(int bitPos) {
        int paletteNum = 0;
        // if you imagine each byte in the 3 byte buffer as 8 bits 76543210
        // and stack them like below, you grab one column of bits at a time
        // 76543210 ; and the number of palettes left is which column to use!
        // 76543210 ; bytes 0, 1, 2 each hold the LSBs, middle bits, MSBs
        // 76543210
        for (int i = NUM_BYTES_IN_PALETTE_BUFFER - 1; i >= 0; i--) {
            int bit = threeByteBuffer[i] & (1 << bitPos);
            if (bit != 0) {
                paletteNum |= (1 << i);
            }
        }
        return paletteNum;
    }

    private static int getNextPaletteNumFrom3ByteBuffer() throws IOException {
        // implements subroutine at $029EC5
        numPalettesLeftIn3ByteBuffer--;
        if (numPalettesLeftIn3ByteBuffer < 0) {
            numPalettesLeftIn3ByteBuffer = NUM_THREE_BIT_VALS_IN_BUFFER - 1;
            for (int i = 0; i < threeByteBuffer.length; i++) {
                threeByteBuffer[i] = romFile.readUnsignedByte();
            }
        }

        int paletteNum = getNthPaletteNumFrom3ByteBuffer(numPalettesLeftIn3ByteBuffer);
        // put into correct position for tilemap entry's standard format
        paletteNum <<= 2;

        return paletteNum;
    }

    private static void getPaletteXYs(boolean uncompValues, boolean gettingPalettes) throws IOException {
        numPalettesLeftIn3ByteBuffer = 0;

        bufferForByteFromPtr = 0;              
        numBitPairsLeftInByteBuffer = 0;
        // implement code at $029C73 and $029D93 - all the cases are the same
        // except for a few differences in bit packing of data
        if (uncompValues) {
            if (gettingPalettes) {
                for (int i = 0; i < NUM_TILEMAP_ENTRIES; i++) {
                    int paletteNum = getNextPaletteNumFrom3ByteBuffer();
                    tilemapHighBytes[i] |= paletteNum;
                }
            }
            else {
                for (int i = 0; i < NUM_TILEMAP_ENTRIES; i++) {
                    int xyFlip = getTwoBitsFromByteFromPtr();
                    tilemapHighBytes[i] |= xyFlip;
                }
            }
            return;
        }

        int numBytesDone = 0;
        do {
            int typeByte = romFile.readUnsignedByte();

            int top4Bits = getTop4Bits(typeByte);
            int top2Bits = top4Bits >> 2;
            int top3Bits = top4Bits >> 1;

            // $029CC7 and $029DE9: case MSBs are 0b00 (range 00-3F) - special case with byte 3F
            if (top2Bits == 0x0) {
                // 00rr rrrr
                int repeatCount = typeByte;
                if (repeatCount == SPECIAL_3F) {
                    repeatCount = romFile.readUnsignedByte();
                }
                numBytesDone += repeatCount + 1;
            }

            // next three cases reuse code; obtain a palette or X/Y value, and
            // skip by a set number of bytes in the buffer
            // $029CE7 and $029E09: case MSBs are 0b0100 (range 40-4F)
            else if (top4Bits == 0x4) {
                // 0100 ssss: get value from row up, 0x1-0x10 of 00 values
                int skipCount = (typeByte & 0xF) + 1;
                int reusedValue = tilemapHighBytes[numBytesDone - NUM_TILES_IN_ROW];
                reusedValue &= gettingPalettes ? PALETTE_BITMASK : XY_FLIP_BITMASK;

                tilemapHighBytes[numBytesDone] |= reusedValue;
                numBytesDone += skipCount + 1;
            }

            // $029CFC and $029E1C: case MSBs are 0b011 (range 60-7F)
            else if (top3Bits == 0x3) {
                // 011p ppss or 011y xsss; palette or X/Y value encoded in type
                // byte, and 0x1-0x4 (palettes) or 0x1-0x8 (X/Y) entries of 00
                int skipCount, encodedValue;
                if (gettingPalettes) {
                    skipCount = (typeByte & 0x3) + 1;
                    encodedValue = typeByte & PALETTE_BITMASK;
                }
                else {
                    skipCount = (typeByte & 0x7) + 1;
                    encodedValue = (typeByte << 3) & XY_FLIP_BITMASK;
                }

                tilemapHighBytes[numBytesDone] |= encodedValue;
                numBytesDone += skipCount + 1;
            }
            // $029D06 and $029E27: case MSBs are 0b1010 (range A0-AF)
            else if (top4Bits == 0xA) {
                // 1010 ssss: value encoded in appropriate buffer, followed by
                // 0x5-0x14 (palettes) or 0x9-0x18 (X/Y) entries of 00
                int skipCount = (typeByte & 0xF) + 1 + getThresholdFor00sAfterNewPaletteXyValue(gettingPalettes);

                int newValue;
                if (gettingPalettes) {
                    // skipCount = (typeByte & 0xF) + 5;
                    newValue = getNextPaletteNumFrom3ByteBuffer();
                }
                else {
                    // skipCount = (typeByte & 0xF) + 9;
                    newValue = getTwoBitsFromByteFromPtr();
                }

                tilemapHighBytes[numBytesDone] |= newValue;
                numBytesDone += skipCount + 1;
            }

            // $029D19 and $029E3C: case MSBs are 0b0101 (range 50-5F)
            else if (top4Bits == 0x5) {
                // 0101 rrrr; get the palette or X/Y bits from one tile up, and
                // copy it the specified number of times (0x1-0x10)
                int repeatCount = (typeByte & 0xF) + 1;
                int reusedValue = tilemapHighBytes[numBytesDone - NUM_TILES_IN_ROW];
                reusedValue &= gettingPalettes ? PALETTE_BITMASK : XY_FLIP_BITMASK;

                for (int i = 0; i < repeatCount && numBytesDone < NUM_TILEMAP_ENTRIES; i++) {
                    tilemapHighBytes[numBytesDone] |= reusedValue;
                    numBytesDone++;
                }
            }

            // $029D3E and $029E61: case MSBs are 0b100 (range 80-9F)
            else if (top3Bits == 0x4) {
                // 100p pprr or 100y xrrr; get value stored in type byte, copy
                // it the specified number of times (2-5 palettes, 2-9 X/Y)
                int repeatCount, encodedValue;
                if (gettingPalettes) {
                    repeatCount = (typeByte & 0x3) + REPEAT_CASE_MIN_SIZE;
                    encodedValue = typeByte & PALETTE_BITMASK;
                }
                else {
                    repeatCount = (typeByte & 0x7) + REPEAT_CASE_MIN_SIZE;
                    encodedValue = (typeByte << 3) & XY_FLIP_BITMASK;
                }

                // same loop as for next case, 0b1011
                for (int i = 0; i < repeatCount && numBytesDone < NUM_TILEMAP_ENTRIES; i++) {
                    tilemapHighBytes[numBytesDone] |= encodedValue;
                    numBytesDone++;
                }
            }
            // $029D49 and $029E6D: case MSBs are 0b1011 (range B0-BF)
            else if (top4Bits == 0xB) {
                // 1011 rrrr; get value from respective buffer, and copy it the
                // specified number of times (0x6-0x15 palettes, 0xA-0x19 X/Y)
                int repeatCount = (typeByte & 0xF) + 1 + getThresholdForRepeatNewPaletteXY(gettingPalettes);

                int newValue;
                if (gettingPalettes) {
                    // repeatCount = (typeByte & 0xF) + 6;
                    newValue = getNextPaletteNumFrom3ByteBuffer();
                }
                else {
                    // repeatCount = (typeByte & 0xF) + 0xA;
                    newValue = getTwoBitsFromByteFromPtr();
                }

                // same loop as for last case, 0b100
                for (int i = 0; i < repeatCount && numBytesDone < NUM_TILEMAP_ENTRIES; i++) {
                    tilemapHighBytes[numBytesDone] |= newValue;
                    numBytesDone++;
                }
            }

            // $029D65 and $029E8B: case MSBs are 0b11 (range C0-FF)
            else if (top2Bits == 0x3) {
                // 11pp prrr or 11yx rrrr; write value in "ppp"/"yx" bits ONCE
                int firstLiteral, numLiterals;
                if (gettingPalettes) {
                    firstLiteral = (typeByte >> 1) & PALETTE_BITMASK;
                    numLiterals = typeByte & 0x7;
                }
                else {
                    firstLiteral = (typeByte << 2) & XY_FLIP_BITMASK;
                    numLiterals = typeByte & 0xF;
                }
                tilemapHighBytes[numBytesDone] |= firstLiteral;
                numBytesDone++;

                // then copy in values from the ROM data however many times
                // note that this counter may be 0 if need be
                // for (int i = 0; i < numLiterals && numBytesDone < NUM_TILEMAP_ENTRIES; i++) {
                while (numLiterals > 0) {
                    int literal = gettingPalettes ?
                        getNextPaletteNumFrom3ByteBuffer() :
                        getTwoBitsFromByteFromPtr();

                    if (numBytesDone < NUM_TILEMAP_ENTRIES) {
                        tilemapHighBytes[numBytesDone] |= literal;
                        numBytesDone++;
                    }
                    numLiterals--;
                }
            }
        }
        while (numBytesDone < NUM_TILEMAP_ENTRIES);
    }

    private static void propagateXOR() {
        // see $029D86 for ASM code; propagate an XOR thru tilemap's high bytes
        // to undo an operation to improve the compression for high bits/palettes
        // start at row 1, and XOR each tilemap entry with entry directly above it
        for (int i = NUM_TILES_IN_ROW; i < NUM_TILEMAP_ENTRIES; i++) {
            tilemapHighBytes[i] ^= tilemapHighBytes[i - NUM_TILES_IN_ROW];
        }
    }

    // #########################################################################
    // #########################################################################

    /*
    private static boolean getHighBytes(int flagsByte) throws IOException {
        // next comes the high 2 bits for each tile ID number
        boolean uncompTileIDHigh2Bits = (flagsByte & 0x1) == 0x0;
        flagsByte >>= 1;
        boolean allCasesCovered = getTileIDsHighTwoBits(uncompTileIDHigh2Bits);

        // then the palette numbers for each tile
        boolean uncompPaletteNums = (flagsByte & 0x1) == 0x0;
        flagsByte >>= 1;
        allCasesCovered = getPaletteNums(uncompPaletteNums) && allCasesCovered;

        // propagate XOR down through the tile columns
        propagateXOR();

        // and finally the X/Y flip bits for each tile (note: priority assumed to be 0)
        boolean uncompXYFlip = (flagsByte & 0x1) == 0x0;
        flagsByte >>= 1;
        allCasesCovered = getXYFlipBits(uncompXYFlip) && allCasesCovered;

        return allCasesCovered;
    }
    */

    private static void writeByteSetToFile(int bytes[], String filename) throws IOException {
        FileOutputStream bytesFile = new FileOutputStream(filename);
        for (int i = 0; i < bytes.length; i++) {
            bytesFile.write(bytes[i]);
        }
        bytesFile.close();
    }

    private static int[] getFullTilemapAsIndividualBytes() {
        int fullTilemap[] = new int[NUM_TILEMAP_ENTRIES * 2];
        for (int i = 0; i < NUM_TILEMAP_ENTRIES; i++) {
            fullTilemap[i*2]   = tilemapLowBytes[i];
            fullTilemap[i*2+1] = tilemapHighBytes[i];
        }
        return fullTilemap;
    }

    private static int[] getFullTilemapAsTwoByteEntries() {
        int fullTilemap[] = new int[NUM_TILEMAP_ENTRIES];
        for (int i = 0; i < NUM_TILEMAP_ENTRIES; i++) {
            fullTilemap[i] = tilemapLowBytes[i] | (tilemapHighBytes[i] << 8);
        }
        return fullTilemap;
    }

    /*
    private static void writeLowAndHighBytesToFiles(int tilemapPtr, String outputFolder) throws IOException {
        // write the low and high bytes each into separate files
        String offsetStr = (tilemapPtr == LOROM_PTR_TO_FILE_START) ? "" : String.format("$%06X ", tilemapPtr);
        String lowBytesFilename = outputFolder + offsetStr + "tilemap low bytes.bin";
        String highBytesFilename = outputFolder + offsetStr + "tilemap high bytes.bin";
        writeByteSetToFile(tilemapLowBytes, lowBytesFilename);
        writeByteSetToFile(tilemapHighBytes, highBytesFilename);
    }
    */

    private static void writeFullTilemapToFile(int tilemapPtr, String outputFolder) throws IOException {
        String offsetStr = (tilemapPtr == LOROM_PTR_TO_FILE_START) ? "" : String.format("$%06X ", tilemapPtr);

        String combinedFilename = outputFolder + offsetStr + "combined tilemap.bin";
        int fullTilemap[] = getFullTilemapAsIndividualBytes();
        writeByteSetToFile(fullTilemap, combinedFilename);
        /*
        FileOutputStream combinedTilemap = new FileOutputStream(combinedFilename);
        for (int i = 0; i < NUM_TILEMAP_ENTRIES; i++) {
            combinedTilemap.write(tilemapLowBytes[i]);
            combinedTilemap.write(tilemapHighBytes[i]);
        }
        combinedTilemap.close();
        */
    }

    // #########################################################################
    // #########################################################################

    public static int[] decompressTilemapFile(String inputDataFile) throws IOException {
        romFile = new RandomAccessFile(inputDataFile, "r");
        int output[] = decompressTilemap(LOROM_PTR_TO_FILE_START);
        romFile.close();
        return output;
    }

    public static int[] decompressTilemapROM(int gfxID, String outputFolder) throws IOException {
        if (gfxID < 0 || gfxID > tilemapPtrList.length) {
            return new int[0];
        }

        if (romFile == null) {
            // romFile = new RandomAccessFile("rom/Kamaitachi no Yoru (Japan).sfc", "r");
            readMetadataFromROM();
        }

        int tilemapPtr = tilemapPtrList[gfxID];
        // implement the subroutine at $028D47
        boolean ptrIsForTwoBlocks = (tilemapPtr & 0x8000) == 0;
        if (ptrIsForTwoBlocks) {
            String notice = "Tilemap pointer $%06X is special case.";
            System.out.println(String.format(notice, tilemapPtr));
            tilemapPtr |= 0x8000;
            decompressTilemap(0x46C1B8);
			writeFullTilemapToFile(0x46C1B8, outputFolder);
        }

        // getting tilemap entries comes in four phases: low bytes, tile ID high
        // bits, palette numbers, and "X/Y flip" bit flags
        // romFile = new RandomAccessFile("rom/Kamaitachi no Yoru (Japan).sfc", "r");
        return decompressTilemap(tilemapPtr);
    }

    private static int[] decompressTilemap(int tilemapPtr) throws IOException {
        tilemapFilePtr = getROMPtr(tilemapPtr);
        romFile.seek(tilemapFilePtr);
        int flagsByte = romFile.readUnsignedByte();

        tilemapLowBytes = new int[NUM_TILEMAP_ENTRIES];
        tilemapHighBytes = new int[NUM_TILEMAP_ENTRIES];

        try {
            // first, get the low bytes
            boolean uncompLowBytes = (flagsByte & FLAG_COMP_LOW_BYTES) == 0x0;
            getTilemapLowBytes(uncompLowBytes);

            // next, the high 2 bits for each tile ID number
            boolean uncompTileIDHigh2Bits = (flagsByte & FLAG_COMP_HIGH_BITS) == 0x0;
            getTileIDsHighTwoBits(uncompTileIDHigh2Bits);

            // then, the palette numbers for each tile
            boolean uncompPaletteNums = (flagsByte & FLAG_COMP_PALETTES) == 0x0;
            getPaletteXYs(uncompPaletteNums, GETTING_PALETTES);

            // propagate XOR down the tile columns for high bits, palettes
            propagateXOR();

            // and finally the X/Y flip bits for each tile (assume priority = 0)
            boolean uncompXYFlip = (flagsByte & FLAG_COMP_XY_BITS) == 0x0;
            getPaletteXYs(uncompXYFlip, !GETTING_PALETTES);
        }
        catch (ArrayIndexOutOfBoundsException e) {
            e.printStackTrace();
        }
        return getFullTilemapAsTwoByteEntries();
    }

    public static void main(String args[]) throws IOException {
        if (args.length == 0) {
            readMetadataFromROM();
            // romFile = new RandomAccessFile("rom/Kamaitachi no Yoru (Japan).sfc", "r");
            // readGfxPtrs();
            Files.createDirectories(Paths.get(OUTPUT_FOLDER));
            // for (int tilemapPtr : tilemapPtrList) {
            for (int gfxID = 0; gfxID < tilemapPtrList.length; gfxID++) {
                String outputFolder = String.format(OUTPUT_FOLDER + "%02X ", gfxID);
                // int tilemap[] = decompressTilemapROM(gfxID, outputFolder);
                decompressTilemapROM(gfxID, outputFolder);
				writeFullTilemapToFile(tilemapPtrList[gfxID] | 0x8000, outputFolder);
            }
            romFile.close();
        }
        else for (String inputFile : args) {
            // note: use input file's name without extension as unique marker for
            // its decompressed data; not exactly intended by me, but it works
            decompressTilemapFile(inputFile);
            String filenameNoExtension = inputFile.substring(0, inputFile.lastIndexOf("."));
            writeFullTilemapToFile(LOROM_PTR_TO_FILE_START, filenameNoExtension);
        }
    }
}
