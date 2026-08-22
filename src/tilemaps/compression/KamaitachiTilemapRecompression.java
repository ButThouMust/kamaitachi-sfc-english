package tilemaps.compression;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;

import tilemaps.constants.TilemapCompConstants;
import tilemaps.decompression.KamaitachiTilemapDumper;
import static tilemaps.constants.TilemapCompConstants.*;

// This is an old version of the tilemap recompressor that uses the original
// compression format as in the Japanese game, without any of my improvements
// to the format (original size ranges, no extra cases for low bytes).

public class KamaitachiTilemapRecompression {

    private static final String OUTPUT_FOLDER = "recompressed tilemaps orig format/";

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int[] tilemapLowBytes;
    private static int[] tilemapIdHighBits;
    private static int[] tilemapPalettes;
    private static int[] tilemapXYFlips;

    private static String inputFilename;

    private static int[] readTilemapEntriesFromFile(String filename) throws IOException {
        int rawTilemapEntries[] = new int[NUM_TILEMAP_ENTRIES];
        FileInputStream inputFile = new FileInputStream(filename);
        int entry = 0;
        for (int i = 0; i < rawTilemapEntries.length; i++) {
            entry = inputFile.read();
            entry |= inputFile.read() << 8;
            rawTilemapEntries[i] = entry;
        }
        inputFile.close();
        return rawTilemapEntries;
    }

    private static void separateOutTilemapEntryComponents(int rawTilemapEntries[]) {
        // format for an SNES tilemap entry: yx0pppnn nnnnnnnn
        // y = Y flip, x = X flip, (assume priority bit 0)
        // ppp = palette #, nn nnnnnnnn = 10-bit tile ID number to use
        tilemapLowBytes = new int[NUM_TILEMAP_ENTRIES];
        tilemapIdHighBits = new int[NUM_TILEMAP_ENTRIES];
        tilemapPalettes = new int[NUM_TILEMAP_ENTRIES];
        tilemapXYFlips = new int[NUM_TILEMAP_ENTRIES];
        for (int i = 0; i < rawTilemapEntries.length; i++) {
            int entry = rawTilemapEntries[i];
            tilemapLowBytes[i]   = entry & 0xFF;
            tilemapIdHighBits[i] = (entry >> 8) & 0x3;
            tilemapPalettes[i]   = (entry >> 10) & 0x7;
            tilemapXYFlips[i]    = (entry >> 14) & 0x3;
        }

        propagateXorUpColumns();
    }

    private static void propagateXorUpColumns() {
        // when decompressing, the XOR is propagated DOWN the tile columns
        // when compressing, the XOR is propagated UP the tile columns
        // this happens for only the high bits and the palettes
        for (int i = NUM_TILEMAP_ENTRIES - 1; i >= NUM_TILES_IN_ROW; i--) {
            tilemapIdHighBits[i] ^= tilemapIdHighBits[i - NUM_TILES_IN_ROW];
            tilemapPalettes[i]   ^= tilemapPalettes[i - NUM_TILES_IN_ROW];
        }
    }

    @SuppressWarnings("unused")
    private static void outputSeparatedEntryComponentsToFiles(String filename) throws IOException {
        // remove file extension
        int periodIndex = filename.indexOf(".");
        String noExtension = filename.substring(0, periodIndex);

        FileOutputStream lowBytesFile = new FileOutputStream(OUTPUT_FOLDER + noExtension + " low bytes.bin");
        FileOutputStream highBitsFile = new FileOutputStream(OUTPUT_FOLDER + noExtension + " high bits - XOR'd.bin");
        FileOutputStream palettesFile = new FileOutputStream(OUTPUT_FOLDER + noExtension + " palettes - XOR'd.bin");
        FileOutputStream flipBitsFile = new FileOutputStream(OUTPUT_FOLDER + noExtension + " XY flips.bin");

        for (int i = 0; i < NUM_TILEMAP_ENTRIES; i++) {
            lowBytesFile.write(tilemapLowBytes[i]);
            highBitsFile.write(tilemapIdHighBits[i]);
            palettesFile.write(tilemapPalettes[i]);
            flipBitsFile.write(tilemapXYFlips[i]);
        }

        lowBytesFile.flush();
        highBitsFile.flush();
        palettesFile.flush();
        flipBitsFile.flush();

        lowBytesFile.close();
        highBitsFile.close();
        palettesFile.close();
        flipBitsFile.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int getRunLengthAtPosition(int data[], int position, int maxSize) {
        if (position < 0) return 0;

        int size = 1;
        int value = data[position];

        int currPos = position + 1;
        while (currPos < data.length) {
            if (value != data[currPos] || size >= maxSize) {
                break;
            }
            currPos++;
            size++;
        }
        return size;
    }

    private static int nextWriteToPaletteBuffer(int numValuesWritten) {
        // focusing on values modulo 7:
        // 0: return argument + 1
        // else: return (next multiple of 8 after argument) + 1
        return nextWriteToBuffer(numValuesWritten, NUM_THREE_BIT_VALS_IN_BUFFER);
    }

    private static int nextWriteToTwoBitSetBuffer(int numValuesWritten) {
        return nextWriteToBuffer(numValuesWritten, NUM_TWO_BIT_VALS_IN_BUFFER);
    }

    private static int nextWriteToBuffer(int numValuesWritten, int numSetsInBuffer) {
        // example for numSetsInBuffer being 4 (high bits, X/Y):
        // N   : 0 1 2 3 / 4 5 6 7 / 8 9 A B / C  D  E  F / 10 11 ...
        // f(N): 1 5 5 5 / 5 9 9 9 / 9 D D D / D 11 11 11 / 11 15 ...
        int modulo = numValuesWritten % numSetsInBuffer;
        if (modulo == 0) {
            return numValuesWritten + 1;
        }
        else {
            return 1 + ((numValuesWritten / numSetsInBuffer) + 1) * numSetsInBuffer;
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int checkForRepeatingCurrID(int currPos, int currTileID) {
        currTileID &= 0xFF;
        if (tilemapLowBytes[currPos] != currTileID) {
            return CASE_NOT_VALID;
        }

        // note: must enforce max size here because this compression case alters
        // the current tile ID number; can't compress 0x42+ copies of the same
        // byte with two back-to-back instances of this particular case
        int size = getRunLengthAtPosition(tilemapLowBytes, currPos, REPEAT_CURR_ID_LIMIT_41);
        if (size < REPEAT_CASE_MIN_SIZE) {
            size = CASE_NOT_VALID;
        }
        return size;
    }

    private static int checkForIncreasingSequence(int currPos, int currTileID) {
        // must also enforce max size here due to altering current tile ID #
        int size = 0;

        int tileIDToCheck = currTileID & 0xFF;
        for (int pos = currPos; pos < tilemapLowBytes.length; pos++) {
            boolean isMatch = tilemapLowBytes[pos] == tileIDToCheck;
            if (!isMatch || size >= TAG_SIZE_LIMIT_100) {
                break;
            }
            size++;
            tileIDToCheck = (tileIDToCheck + 1) & 0xFF;
        }

        if (size == 0) {
            return CASE_NOT_VALID;
        }

        // special case: if sequence's last value repeats like [01 02 03 03 03],
        // you have two options for how to compress the run at the end:
        // [01 02] [03 03 03 03], IncSeq 2 + CurrentTileID 4 (size limit 0x41)
        // [01 02 03] [03 03 03], IncSeq 3 + RepeatRecent  3 (size limit 0x20)
        // if you had to decide one way or another, I suppose you could base it
        // on whether the value after the run follows the sequence, e.g. like:
        // [01 02 03 03 03 04 ...] or [01 02 03 03 03 05 ...]
        int endOfSequence = currPos + size - 1;
        int idAtEndOfSequence = tilemapLowBytes[endOfSequence];
        if (checkForRepeatingCurrID(endOfSequence, idAtEndOfSequence) > 0) {
            size--;
        }

        // handle special case for data block at offsets 241-249 in $47F675:
        // [19 1b 00 00 00 00 00 19 1a], current tile ID of 19; save 2 bytes:
        // pass over the 1 byte increasing sequence for now, & encode as 2 lits
        // then you get a two-byte increasing sequence later
        if (size == 1) {
            // find the next occurrence of the current tile ID
            int nextOccurrence = -1;
            for (int pos = currPos + size; pos < tilemapLowBytes.length; pos++) {
                // if on the way, you find the new current tile ID were you to
                // take the increasing sequence right now, take it
                if (tilemapLowBytes[pos] == ((currTileID + 1) & 0xFF)) 
                    break;
                else if (tilemapLowBytes[pos] == currTileID) {
                    nextOccurrence = pos;
                    break;
                }
            }
            if (nextOccurrence != -1) {
                int nextSize = checkForIncreasingSequence(nextOccurrence, currTileID);
                if (nextSize > size) return CASE_NOT_VALID;
            }
        }

        return size;
    }

    private static int checkForReuseBlockFromOneRowUp(int currPos) {
        int size = 0;
        for (int pos = currPos; pos < tilemapLowBytes.length; pos++) {
            // note the use of boolean short-circuiting
            boolean isMatch = pos >= NUM_TILES_IN_ROW &&
                              tilemapLowBytes[pos] == tilemapLowBytes[pos - NUM_TILES_IN_ROW];
            if (!isMatch || size >= REUSE_LOW_BYTE_SIZE_LIMIT_20) {
                break;
            }
            size++;
        }
        return size;
    }

    private static int checkForReuseMostRecentVal(int currPos) {
        // this case will not work at the very start of the array
        if (currPos == 0) {
            return CASE_NOT_VALID;
        }

        int valueToCheck = tilemapLowBytes[currPos - 1];
        int size = 0;
        for (int pos = currPos; pos < tilemapLowBytes.length; pos++) {
            if (tilemapLowBytes[pos] != valueToCheck || size >= REUSE_LOW_BYTE_SIZE_LIMIT_20) {
                break;
            }
            size++;
        }

        return size;
    }

    private static int checkForRepeatNewID(int currPos, int currTileID) {
        // this compression type will not work at the end of the array
        if (currPos == tilemapLowBytes.length - 1) {
            return CASE_NOT_VALID;
        }

        // final int MIN_SIZE = 2;
        // final int MAX_SIZE = 0x100;

        int size = getRunLengthAtPosition(tilemapLowBytes, currPos, TAG_SIZE_LIMIT_100);
        if (size < REPEAT_CASE_MIN_SIZE) return CASE_NOT_VALID;

        // optimization: if the repeated value is the current tile ID and has a
        // repeat count in the range 0x42-0x61, it is better to encode as two
        // blocks [repeat curr ID 0x41 times] + [reuse 0x1-0x20 times] (2 bytes)
        // instead of as one block [repeat new ID 0x42-0x61 times] (3 bytes)
        if (tilemapLowBytes[currPos] == currTileID &&
            REPEAT_CURR_ID_LIMIT_41 < size &&
            size <= REPEAT_CURR_ID_LIMIT_41 + REUSE_LOW_BYTE_SIZE_LIMIT_20) {
            return CASE_NOT_VALID;
        }

        // optimization: if the repeated value is the current tile ID and if the
        // value after the run is (curr tile ID + 1), subtract 1 from the size;
        // purpose is to take advantage of the increasing sequence case
        if (tilemapLowBytes[currPos] == currTileID &&
            currPos + size < tilemapLowBytes.length &&
            tilemapLowBytes[currPos + size] == currTileID + 1) {
            size--;
        }

        // optimization motivated by $46E220 @ 0x34D: if value is repeated 0x21+
        // times (encoded in 3 bytes) here and repeated in a block one row up,
        // and remaining part of the current block after reusing from a row up
        // is at most 0x20 (limit for reusing the most recent byte i.e. run's
        // value), you can encode the run in 2 bytes instead of 3
        if (size > REPEAT_NEW_LOW_BYTE_THRESHOLD_20 && currPos > NUM_TILES_IN_ROW) {
            int checkReuseFromRowUp = checkForReuseBlockFromOneRowUp(currPos);
            if (checkReuseFromRowUp != 0) {
                int remainder = size - checkReuseFromRowUp;
                if (remainder <= REUSE_LOW_BYTE_SIZE_LIMIT_20) {
                    size = CASE_NOT_VALID;
                }
            }
        }
        return size;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static ArrayList<LowByteTag> examineLowBytes() {
        int currentTileID = STARTING_LOW_BYTE;
        int currPos = 0;
        final int MAX_LITERALS = 0x20;

        ArrayList<LowByteTag> compressionSequence = new ArrayList<>();
        while (currPos < tilemapLowBytes.length) {
            // basic idea: check each different compression technique, and pick
            // the one that compresses the most raw data; if none of them work,
            // write a single literal byte

            int repeatCurrIDCount = checkForRepeatingCurrID(currPos, currentTileID);
            int incSequenceCount  = checkForIncreasingSequence(currPos, currentTileID);
            int reuseOneRowUpCount = checkForReuseBlockFromOneRowUp(currPos);
            int reuseMostRecentCount = checkForReuseMostRecentVal(currPos);
            int repeatNewIDCount = checkForRepeatNewID(currPos, currentTileID);

            HashMap<LowByteType, Integer> counts = new HashMap<>();
            counts.put(LowByteType.RepeatCurrID, repeatCurrIDCount);
            counts.put(LowByteType.IncreasingSequence, incSequenceCount);
            counts.put(LowByteType.ReuseBlockFromOneRowUp, reuseOneRowUpCount);
            counts.put(LowByteType.ReuseMostRecentValue, reuseMostRecentCount);
            counts.put(LowByteType.RepeatNewID, repeatNewIDCount);

            // determine which compression method to use
            int maxSize = CASE_NOT_VALID;
            LowByteType bestType = LowByteType.LiteralSequence;
            for (LowByteType type : counts.keySet()) {
                int size = counts.get(type);
                if (size > maxSize) {
                    maxSize = size;
                    bestType = type;
                }
                // 0 represents that the compression method doesn't work right now
                else if (size != 0 && size == maxSize) {
                    // break ties by prioritizing some methods over others
                    if (type.getPriority() > bestType.getPriority()) {
                        bestType = type;
                    }
                }
            }
            // int oldCurrID = currentTileID;

            // encode a single literal byte if either:
            // 1. none of the compression methods work here
            if (maxSize == CASE_NOT_VALID) {
                maxSize = 1;
                bestType = LowByteType.LiteralSequence;
            }
            // 2. the most recent case was literals and the current case is for
            //    a length 1 reuse of data (note: NOT an increasing sequence)
            // (optimization based on tilemap low bytes for $4494C7 at 0x1B5)
            // idea is to combine multiple literal tags together and avoid using
            // multiple overhead bytes for seperate literal tags
            else if (maxSize == 1 && bestType != LowByteType.IncreasingSequence) {
                int totalCompSize = compressionSequence.size();
                if (totalCompSize > 0) {
                    LowByteType lastType = compressionSequence.get(totalCompSize - 1).getType();
                    if (lastType == LowByteType.LiteralSequence) {
                        maxSize = 1;
                        bestType = LowByteType.LiteralSequence;
                    }
                }
            }

            // update current tile ID # for next iteration
            switch (bestType) {
                case RepeatCurrID:
                    currentTileID++;
                    break;
                case IncreasingSequence:
                    currentTileID += maxSize;
                    break;
                default:
                    break;
            }
            currentTileID &= 0xFF;

            // if both the current and last iterations were for literal bytes,
            // just combine the size of the current iteration into the last one,
            // if the combined size fits into the 0x20 literal byte limit
            int compSeqLength = compressionSequence.size();
            if (compSeqLength > 0 && bestType == LowByteType.LiteralSequence) {
                LowByteTag lastSet = compressionSequence.get(compSeqLength - 1);
                LowByteType lastType = lastSet.getType();
                int combinedSize = lastSet.getSize() + maxSize;
                int lastPos = lastSet.getPosition();

                if (lastType == bestType && combinedSize <= MAX_LITERALS) {
                    // in this case, update last iteration, and advance past this literal
                    lastSet = new LowByteTag(lastType, combinedSize, lastPos);
                    compressionSequence.set(compSeqLength - 1, lastSet);
                    currPos += maxSize;
                    continue;
                }
            }

            // advance past all the bytes that get covered under current iteration
            compressionSequence.add(new LowByteTag(bestType, maxSize, currPos));
            currPos += maxSize;
        }
        return compressionSequence;
    }

    private static ArrayList<Integer> generateCompressedLowBytesBlock(ArrayList<LowByteTag> compressionSequence) {
        // don't know how much data the blocks will take when compressed
        ArrayList<Integer> compressedData = new ArrayList<>();
        for (LowByteTag currentBlock : compressionSequence) {
            LowByteType type = currentBlock.getType();
            int position = currentBlock.getPosition();
            int size = currentBlock.getSize();

            switch (type) {
                case RepeatCurrID: {
                    // 00xx xxxx (00-3F)
                    int infoByte = (size - REPEAT_CASE_MIN_SIZE) & 0x3F;
                    compressedData.add(infoByte);
                    break;
                }
                case IncreasingSequence: {
                    // 01xx xxxx (40-7F, with 7F as a special case)
                    final int BITMASK = 0x40;
                    final int SPECIAL_CASE_BYTE = 0x7F;

                    int encodedSize = size - 1;
                    if (size <= INC_SEQ_SIZE_THRESHOLD_3F) {
                        compressedData.add(encodedSize | BITMASK);
                    }
                    else {
                        compressedData.add(SPECIAL_CASE_BYTE);
                        compressedData.add(encodedSize);
                    }
                    break;
                }
                case ReuseBlockFromOneRowUp: {
                    // 100x xxxx (80-9F)
                    final int BITMASK = 0x80;
                    int encodedSize = size - 1;
                    compressedData.add(encodedSize | BITMASK);
                    break;
                }
                case ReuseMostRecentValue: {
                    // 101x xxxx (A0-BF)
                    final int BITMASK = 0xA0;
                    int encodedSize = size - 1;
                    compressedData.add(encodedSize | BITMASK);
                    break;
                }
                case RepeatNewID: {
                    // 110x xxxx (C0-DF)
                    // final int SIZE_LIMIT = 0x1F + 2;
                    final int BITMASK = 0xC0;
                    final int SPECIAL_CASE_BYTE = 0xDF;

                    // first, write the type indicator and the size
                    if (size <= REPEAT_NEW_LOW_BYTE_THRESHOLD_20) {
                        int encodedSize = size - REPEAT_CASE_MIN_SIZE;
                        compressedData.add(encodedSize | BITMASK);
                    }
                    else {
                        int encodedSize = size - 1;
                        compressedData.add(SPECIAL_CASE_BYTE);
                        compressedData.add(encodedSize);
                    }

                    // next, write the byte that has to be repeated
                    compressedData.add(tilemapLowBytes[position]);
                    break;
                }
                case LiteralSequence: {
                    // 111x xxxx (E0-FF)
                    final int BITMASK = 0xE0;

                    // first, encode the number of literal bytes
                    int encodedSize = size - 1;
                    compressedData.add(encodedSize | BITMASK);

                    // next, write the bytes themselves
                    for (int i = 0; i < size; i++) {
                        compressedData.add(tilemapLowBytes[position + i]);
                    }
                    break;
                }

                // the original format does not use these cases
                case DecreasingSequence:
                case IsolatedIncreasingSequence:
                case SetCurrID:
                    break;
            }
        }
        return compressedData;
    }

    private static void printLogForLowByteCompression(ArrayList<LowByteTag> compressionSequence, BufferedWriter outputLog) throws IOException {
        // BufferedWriter outputLog = new BufferedWriter(new FileWriter(logFilename));

        outputLog.write("Compressing low bytes...\n\n");
        outputLog.write(" Pos | Size | CompSize | Curr tile | Description\n");
        outputLog.write("-----+------+----------+-----------+-------------\n");

        // first byte in compressed block is "compressed blocks" flag
        int totalCompSize = ONE_BYTE_FOR_COMP_BLOCK_FLAGS;
        int currID = STARTING_LOW_BYTE;
        for (LowByteTag block : compressionSequence) {
            String tileIdChange = "        ";

            int change;
            switch (block.getType()) {
                case IncreasingSequence:
                    change = block.getSize();
                    tileIdChange = String.format("%02X", currID & 0xFF);
                    currID += change;
                    currID &= 0xFF;
                    tileIdChange += String.format(" -> %02X", (currID - 1) & 0xFF);
                    break;
                case RepeatCurrID:
                    change = 1;
                    tileIdChange = String.format("%02X      ", currID & 0xFF);
                    currID = (currID + 1) & 0xFF;
                    break;
                default:
                    break;
            }

            int compSize = block.getNumBytesWhenCompressed();
            String info = " %3X |  %3X | %2X (%3X) | %s  | %s\n";
            outputLog.write(String.format(info, block.getPosition(), block.getSize(), compSize, totalCompSize, tileIdChange, block.getType().toString()));
            totalCompSize += compSize;
        }

        outputLog.flush();
        // outputLog.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static ArrayList<HighBitTag> examineHighBits() {
        // unlike the other compression formats, the high bits don't have a case
        // for checking back one tile row, and for the most part, the cases are
        // mutually exclusive of one another
        int currPos = 0;
        ArrayList<HighBitTag> compressionSequence = new ArrayList<>();
        final int MAX_LITERALS = 0x10;

        while (currPos < tilemapIdHighBits.length) {
            int value = tilemapIdHighBits[currPos];

            // set default values to fall back on
            HighBitType type = HighBitType.LiteralSequence;
            int length = 1;

            // if at a 00, see how many there are in a row
            if (value == 0) {
                length = getRunLengthAtPosition(tilemapIdHighBits, currPos, TAG_SIZE_LIMIT_100);
                if (length > 1) type = HighBitType.RunOfZeroes;
            }
            // if not at a 00, check the next value, *if available*; otherwise,
            // fall back on the default values above
            else if (currPos + 1 < tilemapIdHighBits.length) {
                int nextValue = tilemapIdHighBits[currPos + 1];

                // one non-zero value that is repeated up to 0x29 times
                if (nextValue == value) {
                    length = getRunLengthAtPosition(tilemapIdHighBits, currPos, HIGH_BITS_MAX_REPEAT_LENGTH_29);
                    type = HighBitType.RepeatNonZeroVal;
                }

                // if a non-zero value followed by a different non-zero value,
                // just use the default values listed above

                // one non-zero value, followed by up to 0x28 zeroes
                // note: if followed by only one 00, check if it'd be better to
                // just incorporate into literal sequence
                else if (nextValue == 0) {
                    // you can avoid writing the non-zero value to the buffer if
                    // non-limited run length of 00 bytes is in certain ranges
                    // length = getRunLengthAtPosition(tilemapIdHighBits, currPos + 1, HIGH_BITS_MAX_00_RUN_AFTER_VAL_28);
                    length = getRunLengthAtPosition(tilemapIdHighBits, currPos + 1, NUM_TILEMAP_ENTRIES);

                    // if 0x29 <= length <= 0x47, two options for encoding:
                    // 0x8 + (0x21 <= N <= 0x3F), or 0x28 + (0x1 <= N <= 0x1F)
                    // both cases need to encode a one byte run, but 0x8 doesn't
                    // need to write a high bits value to the buffer
                    boolean needOneByte2ndRunAnyway =
                        length > HIGH_BITS_MAX_00_RUN_AFTER_VAL_28 &&
                        length <= RUN_00_THRESHOLD_ORIGINAL_3F + HIGH_BITS_00_RUN_THRESHOLD_08;

                    // if 0x68 <= length <= 0x108, two options for encoding:
                    // 0x8 + (0x60 <= N <= 0x100), or 0x28 + (0x40 <= N <= 0xE0)
                    // both cases need to encode a two byte run, but 0x8 doesn't
                    // need to write a high bits value to the buffer
                    boolean needTwoByte2ndRunAnyway =
                        length > RUN_00_THRESHOLD_ORIGINAL_3F + HIGH_BITS_MAX_00_RUN_AFTER_VAL_28 &&
                        length <= TAG_SIZE_LIMIT_100 + HIGH_BITS_00_RUN_THRESHOLD_08;

                    // if length >= 0x129, you need 3 runs anyway, so limit 1st run
                    // 0x28 + 0x100 + (0x1-0x17), or 0x8 + 0x100 + (0x21-0x3F)
                    boolean needAtLeastThreeRunsAnyway =
                        length > TAG_SIZE_LIMIT_100 + HIGH_BITS_MAX_00_RUN_AFTER_VAL_28;

                    // if either case is true, limit the length to 8, and get
                    // the rest on the next iteration
                    if (needOneByte2ndRunAnyway || needTwoByte2ndRunAnyway || needAtLeastThreeRunsAnyway) {
                        length = HIGH_BITS_00_RUN_THRESHOLD_08;
                    }
                    // otherwise, limit the length to at most 0x28
                    else {
                        length = Math.min(length, HIGH_BITS_MAX_00_RUN_AFTER_VAL_28);
                    }

                    // encode tag's actual length, including the non-zero value
                    length++;
                    type = HighBitType.NonZeroThenZeroes;
                }
            }

            // optimizations for combining into last iteration if possible
            int compSeqLength = compressionSequence.size();
            if (compSeqLength > 0) {
                HighBitTag lastInfo = compressionSequence.get(compSeqLength - 1);
                int lastSize = lastInfo.getSize();

                if (lastInfo.getType() == HighBitType.LiteralSequence) {
                    // combine consecutive literal sequences if they fit
                    if (type == HighBitType.LiteralSequence) {
                        int combinedSize = length + lastSize;
                        if (combinedSize <= MAX_LITERALS) {
                            lastInfo = new HighBitTag(HighBitType.LiteralSequence,
                                combinedSize, lastInfo.getPosition(),
                                TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                            compressionSequence.set(compSeqLength - 1, lastInfo);

                            currPos += length;
                            continue;
                        }
                    }

                    // if [literals][one non-zero + run of 00s], can combine if
                    // the run of 00s is either 1 byte long, or got limited by
                    // having to use that case
                    else if (type == HighBitType.NonZeroThenZeroes) {
                        int numZeroes = length - 1;
                        int trueLengthOfZeroRun = getRunLengthAtPosition(tilemapIdHighBits, currPos + 1, TAG_SIZE_LIMIT_100);
                        int combinedSize = lastSize + 1;

                        // if yes, combine the non-zero value into the literals
                        if ((numZeroes == 1 || trueLengthOfZeroRun > numZeroes) && combinedSize <= MAX_LITERALS) {
                            lastInfo = new HighBitTag(HighBitType.LiteralSequence,
                                combinedSize, lastInfo.getPosition(),
                                TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                            compressionSequence.set(compSeqLength - 1, lastInfo);

                            currPos++;
                            continue;
                        }
                    }

                    // if [literals][run of some value] where the run is at most
                    // 2 vals long, you can combine the short run into the lits
                    else {
                        int combinedSize = lastSize + length;
                        if (length <= 0x2 && combinedSize <= MAX_LITERALS) {
                            lastInfo = new HighBitTag(HighBitType.LiteralSequence,
                                combinedSize, lastInfo.getPosition(),
                                TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                            compressionSequence.set(compSeqLength - 1, lastInfo);

                            currPos += length;
                            continue;
                        }
                    }
                }

                else if (lastInfo.getSize() <= 2 && length <= 2) {
                    int combinedSize = lastInfo.getSize() + length;
                    if (combinedSize < MAX_LITERALS) {
                        lastInfo = new HighBitTag(HighBitType.LiteralSequence,
                            combinedSize, lastInfo.getPosition(),
                            TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                        compressionSequence.set(compSeqLength - 1, lastInfo);

                        currPos += length;
                        continue;
                    }
                }
            }

            HighBitTag lastValue = new HighBitTag(type, length, currPos,
                TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
            compressionSequence.add(lastValue);
            currPos += length;
        }

        return compressionSequence;
    }

    private static ArrayList<Integer> getHighBitValuesToWriteToBuffer(ArrayList<HighBitTag> compressionSequence) {
        ArrayList<Integer> bufferValues = new ArrayList<>();

        for (HighBitTag block : compressionSequence) {
            int numHighBitsToWrite = block.getNumValsToReadFromBuffer();
            if (numHighBitsToWrite > 0) {
                HighBitType type = block.getType();
                int size = block.getSize();
                int startPos = block.getPosition();

                if (type == HighBitType.LiteralSequence) {
                    // the first literal is encoded directly into the type byte
                    startPos++;
                    size--;
                    for (int i = 0; i < size; i++) {
                        bufferValues.add(tilemapIdHighBits[startPos + i]);
                    }
                }
                else if (type != HighBitType.RunOfZeroes) {
                    bufferValues.add(tilemapIdHighBits[startPos]);
                }
            }
        }

        // append 00 values to the end until list's size is a multiple of 4
        while (bufferValues.size() % NUM_TWO_BIT_VALS_IN_BUFFER != 0) {
            bufferValues.add(0x00);
        }

        return bufferValues;
    }

    // note: can reuse this for the X/Y flip bits
    private static int[] getRawTwoBitBufferBytesToWrite(ArrayList<Integer> bufferValues) {
        int numBuffersToWrite = bufferValues.size() / NUM_TWO_BIT_VALS_IN_BUFFER;
        int rawBytes[] = new int[numBuffersToWrite];

        for (int i = 0; i < numBuffersToWrite; i++) {
            // get 4 values and combine them into one byte
            int bufferValue = 0x00;

            int bufferValuesStartIndex = i * NUM_TWO_BIT_VALS_IN_BUFFER;
            for (int bit = 0; bit < NUM_TWO_BIT_VALS_IN_BUFFER; bit++) {
                bufferValue <<= 2;
                int highBitValue = bufferValues.get(bufferValuesStartIndex + bit);
                bufferValue |= highBitValue;
            }
            rawBytes[i] = bufferValue;
        }

        return rawBytes;
    }

    private static void printLogForHighBitCompression(ArrayList<HighBitTag> compressionSequence, BufferedWriter outputLog, int totalCompSize) throws IOException {
        // BufferedWriter outputLog = new BufferedWriter(new FileWriter(logFilename));

        outputLog.write("\n--------------------------------------------------------------------------------\n\n");
        outputLog.write("Compressing tile ID high bits...\n\n");

        outputLog.write(" Pos | Size | CompSize | Description\n");
        outputLog.write("-----+------+----------+-------------\n");
        String line =   " %3X |  %3X |  %X (%3X) | %s\n";

        // String line = "Pos %3X: %s (case %s)\n";

        int totalValsReadFromBuffer = 0;
        int numValsPerBuffer = NUM_TWO_BIT_VALS_IN_BUFFER;
        for (HighBitTag block : compressionSequence) {
            int posToExpectToWriteBufferContents = nextWriteToTwoBitSetBuffer(totalValsReadFromBuffer);

            int size = block.getSize();
            int pos = block.getPosition();

            String info = "";
            int compSize = block.getNumBytesToEncodeCase();
            switch (block.getType()) {
                case RunOfZeroes:
                    info = String.format("0x%3X sets of 00", size);
                    break;
                case NonZeroThenZeroes:
                    // size counts both the number of 00s and the value
                    info = String.format("0x%3X sets of 00, after %d", size - 1, tilemapIdHighBits[pos]);
                    break;
                case RepeatNonZeroVal:
                    info = String.format("0x%3X sets of %2d", size, tilemapIdHighBits[pos]);
                    break;
                case LiteralSequence:
                    info = String.format("0x%3X literals:", size);
                    for (int i = 0; i < size; i++) {
                        info += String.format(" %d", tilemapIdHighBits[pos + i]);
                    }
                    break;
            }

            // outputLog.write(String.format(line, pos, info, block.getType().toString()));
            outputLog.write(String.format(line, pos, size, compSize, totalCompSize, info));
            totalCompSize += compSize;

            int numValsToRead = block.getNumValsToReadFromBuffer();
            totalValsReadFromBuffer += numValsToRead;

            if (totalValsReadFromBuffer >= posToExpectToWriteBufferContents) {
                int difference = totalValsReadFromBuffer - posToExpectToWriteBufferContents;
                int numBytesToWrite = 1 + difference / NUM_TWO_BIT_VALS_IN_BUFFER;
                outputLog.write(String.format("^ Write %d buffer (%3X)\n", numBytesToWrite, totalCompSize));
                totalCompSize += numBytesToWrite;
            }
            if (numValsToRead != 0) {
                int numBuffers = totalValsReadFromBuffer / numValsPerBuffer;
                int numValsInCurrBuffer = totalValsReadFromBuffer % numValsPerBuffer;
                outputLog.write(String.format("-- Read %d buffer values (0x%X*%d+%d)\n", numValsToRead, numBuffers, numValsPerBuffer, numValsInCurrBuffer));
            }
        }

        int numBuffers = totalValsReadFromBuffer / numValsPerBuffer;
        if (totalValsReadFromBuffer % numValsPerBuffer != 0) {
            numBuffers++;
        }
        String bufferValsPrintout = "\nTotal high bit buff vals: 0x%2X (0x%2X buffers)\n";
        outputLog.write(String.format(bufferValsPrintout, totalValsReadFromBuffer, numBuffers));

        outputLog.flush();
        // outputLog.close();
    }

    private static ArrayList<Integer> generateCompressedHighBitsBlock(ArrayList<HighBitTag> compressionSequence) {
        // don't know how much data the blocks will take when compressed
        ArrayList<Integer> compressedData = new ArrayList<>();
        int numHighBitBufferValuesWritten = 0;

        int highBitBufferBytes[] = getRawTwoBitBufferBytesToWrite(getHighBitValuesToWriteToBuffer(compressionSequence));
        int bytePosition = 0;

        for (HighBitTag currentBlock : compressionSequence) {
            HighBitType type = currentBlock.getType();
            int position = currentBlock.getPosition();
            int size = currentBlock.getSize();

            int posToExpectToWriteBufferContents = nextWriteToTwoBitSetBuffer(numHighBitBufferValuesWritten);

            switch (type) {
                case RunOfZeroes: {
                    // 00nn nnnn (00-3F, with 3F as special case)
                    int encodedSize = size - 1;
                    if (size > RUN_00_THRESHOLD_ORIGINAL_3F) {
                        compressedData.add(RUN_00_THRESHOLD_ORIGINAL_3F);
                    }
                    compressedData.add(encodedSize);
                    break;
                }
                case NonZeroThenZeroes: {
                    // 0x1 <= size <= 0x 8: 010h hnnn
                    // 0x9 <= size <= 0x28: 110n nnnn
                    final int BITMASK_FIT = 0x40;
                    final int BITMASK_NOT_FIT = 0x60;

                    int numZeroes = size - 1;
                    int encodedSize = numZeroes - 1;

                    // if size fits, encode case bits, the size, and value in one byte
                    if (numZeroes <= HIGH_BITS_00_RUN_THRESHOLD_08) {
                        int nonZeroVal = tilemapIdHighBits[position];
                        int infoByte = BITMASK_FIT | encodedSize | (nonZeroVal << 3);
                        compressedData.add(infoByte);
                    }
                    else {
                        // encode (# 00 bytes) - 9
                        encodedSize = numZeroes - (HIGH_BITS_00_RUN_THRESHOLD_08 + 1);
                        int infoByte = BITMASK_NOT_FIT | encodedSize;
                        compressedData.add(infoByte);
                    }

                    break;
                }
                case RepeatNonZeroVal: {
                    // 0x2 <= size <= 0x 9: 100h hnnn
                    // 0xA <= size <= 0x29: 101n nnnn
                    final int BITMASK_FIT = 0x80;
                    final int BITMASK_NOT_FIT = 0xA0;

                    if (size <= HIGH_BITS_REPEAT_VAL_THRESHOLD_09) {
                        int nonZeroVal = tilemapIdHighBits[position];
                        int encodedSize = size - 2;

                        int infoByte = BITMASK_FIT | encodedSize | (nonZeroVal << 3);
                        compressedData.add(infoByte);
                    }
                    else {
                        int encodedSize = size - (HIGH_BITS_REPEAT_VAL_THRESHOLD_09 + 1);
                        int infoByte = BITMASK_NOT_FIT | encodedSize;
                        compressedData.add(infoByte);
                    }
                    break;
                }
                case LiteralSequence: {
                    // 11hh nnnn
                    final int BITMASK = 0xC0;

                    int encodedSize = size - 1;
                    int firstValue = tilemapIdHighBits[position];

                    int infoByte = BITMASK | encodedSize | (firstValue << 4);
                    compressedData.add(infoByte);
                    break;
                }
            }

            int numValsToRead = currentBlock.getNumValsToReadFromBuffer();
            numHighBitBufferValuesWritten += numValsToRead;

            if (numHighBitBufferValuesWritten >= posToExpectToWriteBufferContents) {
                int difference = numHighBitBufferValuesWritten - posToExpectToWriteBufferContents;
                int numBytesToWrite = 1 + difference / NUM_TWO_BIT_VALS_IN_BUFFER;

                for (int i = 0; i < numBytesToWrite; i++) {
                    compressedData.add(highBitBufferBytes[bytePosition]);
                    bytePosition++;
                }
            }
        }
        return compressedData;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int checkForRunOfZeroes(int data[], int currPos) {
        if (data[currPos] != 0) {
            return CASE_NOT_VALID;
        }
        return getRunLengthAtPosition(data, currPos, TAG_SIZE_LIMIT_100);
    }

    private static int checkForReuseFromOneRowUpThenZeroes(int data[], int currPos) {
        // note use of boolean short-circuiting: will not check one row up if
        // still in the first row
        boolean matchWithRowUp = currPos >= NUM_TILES_IN_ROW &&
                                 data[currPos] == data[currPos - NUM_TILES_IN_ROW] &&
                                 data[currPos - NUM_TILES_IN_ROW] != 0;

        boolean followedByZero = currPos < data.length - 1 &&
                                 data[currPos + 1] == 0;

        if (!followedByZero || !matchWithRowUp) {
            return CASE_NOT_VALID;
        }
        return getRunLengthAtPosition(data, currPos + 1, SIZE_LIMIT_REUSE_PALETTE_XY_CASES) + 1;
    }

    private static int checkForReuseFromOneRowUpAndRepeat(int data[], int currPos) {
        // again, note use of boolean short-circuiting
        if (currPos < NUM_TILES_IN_ROW || currPos == data.length - 1 ||
              data[currPos] != data[currPos - NUM_TILES_IN_ROW]) {
            return CASE_NOT_VALID;
        }

        return getRunLengthAtPosition(data, currPos, SIZE_LIMIT_REUSE_PALETTE_XY_CASES);
    }

    private static int checkForRepeatNewPaletteXY(int data[], int currPos, boolean checkingPalettes) {
        if (data[currPos] == 0) {
            return CASE_NOT_VALID;
        }

        // final int MIN_SIZE = 2;
        int maxSize = checkingPalettes ? 0x15 : 0x19;

        // get the actual run length and limit it later
        // int size = getRunLengthAtPosition(data, currPos, maxSize);
        int fullLength = getRunLengthAtPosition(data, currPos, NUM_TILEMAP_ENTRIES);
        int size = Integer.min(fullLength, maxSize);
        if (size < REPEAT_CASE_MIN_SIZE) {
            return CASE_NOT_VALID;
        }

        // check for special cases where "reuse data" case should get priority
        if (currPos >= NUM_TILES_IN_ROW && data[currPos] == data[currPos - NUM_TILES_IN_ROW]) {
            // case driven by $44B65F tilemap X/Y flip bits: if it is possible
            // to repeat a value from 1 row up exactly 0x11 times (exceeds size
            // limit for case), and a run of 0s is after the last value, the
            // "row up" case should take priority, so decrement size for now
            if (size == SIZE_LIMIT_REUSE_PALETTE_XY_CASES + 1 &&
                currPos + size < data.length && data[currPos + size] == 0) {
                size--;
            }
            // case driven by palettes @ 1C4-1DD $46C1B8: if run length forces
            // you to use 2 type bytes anyway, you can might as well avoid
            // writing a value to the buffer by using the reuse data case
            else if (fullLength > maxSize &&
                     fullLength <= SIZE_LIMIT_REUSE_PALETTE_XY_CASES * 2) {
                size = CASE_NOT_VALID;
            }
        }

        return size;
    }

    private static int checkForNewPaletteXYThenZeroes(int data[], int currPos, boolean checkingPalettes) {
        // make sure that current value is not zero, and next value is 0
        if (data[currPos] == 0 || currPos == data.length - 1 || data[currPos + 1] != 0) {
            return CASE_NOT_VALID;
        }

        int maxSize = getSizeLimitFor00sAfterNewPaletteXyValue(checkingPalettes);
        int sizeThreshold = getThresholdFor00sAfterNewPaletteXyValue(checkingPalettes);
        int length = getRunLengthAtPosition(data, currPos + 1, NUM_TILEMAP_ENTRIES);

        // see if length requires 2nd run of 00 bytes anyway, encoded in 1 byte
        // - for palettes,  if 0x15 <= length <= 0x43, two options for encoding:
        //   0x4 + (0x11 <= N <= 0x3F), or 0x14 + (0x1 <= N <= 0x2F)
        // - for X/Y flips, if 0x19 <= length <= 0x47, symmetric options:
        //   0x8 + (0x11 <= N <= 0x3F), or 0x18 + (0x1 <= N <= 0x2F)
        boolean needOneByte2ndRunAnyway =
            length > maxSize &&
            length <= RUN_00_THRESHOLD_ORIGINAL_3F + sizeThreshold;

        // see if length requires 2nd run of 00 bytes anyway, encoded in 2 bytes
        // for palettes,  if 0x54 <= length <= 0x104, two options for encoding:
        // 0x4 + (0x50 <= N <= 0x100), or 0x14 + (0x40 <= N <= 0xF0)
        // for X/Y flips, if 0x58 <= length <= 0x108, symmetric options:
        // 0x8 + (0x50 <= N <= 0x100), or 0x18 + (0x40 <= N <= 0xF0)
        boolean needTwoByte2ndRunAnyway =
            length > RUN_00_THRESHOLD_ORIGINAL_3F + maxSize &&
            length <= TAG_SIZE_LIMIT_100 + sizeThreshold;

        // if palette run >= 0x115 or X/Y flip run >= 0x119, you need three runs
        // anyway, so limit the first run
        boolean needAtLeastThreeRunsAnyway = length > TAG_SIZE_LIMIT_100 + maxSize;

        // if any case is true, you can avoid writing a palette or X/Y flip
        // value to the buffer, without negatively affecting the compression
        if (needOneByte2ndRunAnyway || needTwoByte2ndRunAnyway || needAtLeastThreeRunsAnyway) {
            length = sizeThreshold;
        }
        // otherwise, limit the length accordingly
        else {
            length = Math.min(length, maxSize);
        }

        return length + 1;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    // it turns out that the analysis phase is identical for both palettes and
    // X/Y flips minus size ranges for some of the cases

    private static ArrayList<PaletteXYTag> examinePalettes() {
        return examinePaletteXY(tilemapPalettes, USING_PALETTES);
    }

    private static ArrayList<PaletteXYTag> examineXYFlips() {
        return examinePaletteXY(tilemapXYFlips, USING_X_Y_FLIP);
    }

    private static ArrayList<PaletteXYTag> examinePaletteXY(int data[], boolean checkingPalettes) {
        final int MAX_LITERALS = checkingPalettes ? 0x8 : 0x10;
        ArrayList<PaletteXYTag> compressionSequence = new ArrayList<>();
        int currPos = 0;

        while (currPos < data.length) {
            // check sizes for all the different cases (limit sizes as appropriate)
            int runOfZeroesCount             = checkForRunOfZeroes(data, currPos);
            int reuseFromOneRowUpZeroesCount = checkForReuseFromOneRowUpThenZeroes(data, currPos);
            int reuseFromOneRowUpRepeatCount = checkForReuseFromOneRowUpAndRepeat(data, currPos);
            int newPaletteXYThenZeroesCount  = checkForNewPaletteXYThenZeroes(data, currPos, checkingPalettes);
            int repeatNewPaletteXYCount      = checkForRepeatNewPaletteXY(data, currPos, checkingPalettes);

            HashMap<PaletteXYType, Integer> counts = new HashMap<>();
            counts.put(PaletteXYType.RunOfZeroes, runOfZeroesCount);
            counts.put(PaletteXYType.ReuseFromOneRowUpThenZeroes, reuseFromOneRowUpZeroesCount);
            counts.put(PaletteXYType.ReuseFromOneRowUpAndRepeat, reuseFromOneRowUpRepeatCount);
            counts.put(PaletteXYType.NewPaletteXYThenZeroes, newPaletteXYThenZeroesCount);
            counts.put(PaletteXYType.RepeatNewPaletteXY, repeatNewPaletteXYCount);

            // determine which compression method to use
            int maxSize = CASE_NOT_VALID;
            PaletteXYType bestType = PaletteXYType.LiteralSequence;
            for (PaletteXYType type : counts.keySet()) {
                int size = counts.get(type);
                if (size > maxSize) {
                    maxSize = size;
                    bestType = type;
                }
                // 0 represents that the compression method doesn't work right now
                else if (size != CASE_NOT_VALID && size == maxSize) {
                    // break ties by prioritizing some methods over others
                    if (type.getPriority() > bestType.getPriority()) {
                        bestType = type;
                    }
                }
            }
            // simply encode a single literal byte either if:
            // - none of the compression methods work here
            // - the best compression method only covers 1 byte (adding this
            //   was a big improvement, over 200 bytes!)
            if (maxSize <= 1) {
                maxSize = 1;
                bestType = PaletteXYType.LiteralSequence;
            }

            // special cases for optimizing (part of) a block into previous literal sequence
            int compSeqLength = compressionSequence.size();
            if (compSeqLength > 0) {
                PaletteXYTag lastInfo = compressionSequence.get(compSeqLength - 1);
                PaletteXYType lastType = lastInfo.getType();
                int lastSize = lastInfo.getSize();
                int lastPos = lastInfo.getPosition();

                // if last iteration was for a literal sequence, and we have a
                // literal now, you can combine the lit into the sequence
                if (lastType == PaletteXYType.LiteralSequence &&
                    bestType == PaletteXYType.LiteralSequence) {
                    int combinedSize = lastSize + 1;

                    if (combinedSize <= MAX_LITERALS) {
                        lastInfo = new PaletteXYTag(lastType, combinedSize, lastPos,
                            TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                        compressionSequence.set(compSeqLength - 1, lastInfo);
                        currPos += 1;
                        continue;
                    }
                }

                // if last iteration was for [a new value followed by 0s; or a
                // value reused from one row up once and followed by 0s], check
                // length for the run of 0s, not limited by using the case
                // - # 0s = 1? might as well just encode it & first val as lits
                // - # 0s <= max # 0s for case? encode case as-is (icing on the
                //   cake if under size threshold for packing value in byte)
                // - # 0s > max # 0s for case? encode 1st val as lit, and take
                //   care of the full-length run on next iteration
                if (lastType == PaletteXYType.LiteralSequence &&
                    (bestType == PaletteXYType.NewPaletteXYThenZeroes ||
                     bestType == PaletteXYType.ReuseFromOneRowUpThenZeroes)) {

                    int sizeLimit = bestType == PaletteXYType.NewPaletteXYThenZeroes ?
                        getSizeLimitFor00sAfterNewPaletteXyValue(checkingPalettes) :
                        SIZE_LIMIT_REUSE_PALETTE_XY_CASES;

                    int trueLength = getRunLengthAtPosition(data, currPos + 1, TAG_SIZE_LIMIT_100);
                    if (trueLength > sizeLimit || maxSize <= 2) {
                        int combinedSize = lastSize + 1;
                        if (combinedSize <= MAX_LITERALS) {
                            lastInfo = new PaletteXYTag(lastType, combinedSize, lastPos,
                                TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                            compressionSequence.set(compSeqLength - 1, lastInfo);
                            currPos += 1;
                            continue;
                        }
                    }
                }

                // suppose a run of 1 or 2 of the same value is right after
                // a literal sequence; IN ISOLATION, it is more efficient to
                // encode the run as literals (up to 4 or 6 bits) vs encoding
                // the size in its own dedicated type byte (8 bits)
                // - apply to X/Y flips ("extra data" buffer of only 1 byte)
                // however, overusing this can worsen compression for palettes
                // because they use an "extra data" buffer of 3 bytes
                else if (lastType == PaletteXYType.LiteralSequence &&
                         (bestType == PaletteXYType.RunOfZeroes ||
                          bestType == PaletteXYType.ReuseFromOneRowUpAndRepeat ||
                          bestType == PaletteXYType.RepeatNewPaletteXY) &&
                         // (!checkingPalettes && maxSize <= 2)) {
                         maxSize <= 2) {
                    int combinedSize = lastSize + maxSize;

                    if (combinedSize <= MAX_LITERALS) {
                        lastInfo = new PaletteXYTag(lastType, combinedSize, lastPos,
                            TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                        compressionSequence.set(compSeqLength - 1, lastInfo);
                        currPos += maxSize;
                        continue;
                    }
                }

                // do the same thing in the case this happens with the literals
                // FOLLOWING the run
                else if (bestType == PaletteXYType.LiteralSequence &&
                         (lastType == PaletteXYType.RunOfZeroes ||
                          lastType == PaletteXYType.ReuseFromOneRowUpAndRepeat ||
                          lastType == PaletteXYType.RepeatNewPaletteXY) &&
                         // (!checkingPalettes && lastSize <= 2)) {
                         lastSize <= 2) {
                    int combinedSize = lastSize + maxSize;

                    if (combinedSize <= MAX_LITERALS) {
                        lastInfo = new PaletteXYTag(PaletteXYType.LiteralSequence,
                            combinedSize, lastPos,
                            TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                        compressionSequence.set(compSeqLength - 1, lastInfo);
                        currPos += maxSize;
                        continue;
                    }
                }
            }

            PaletteXYTag compressionInfo = new PaletteXYTag(bestType, maxSize, currPos,
                TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
            compressionSequence.add(compressionInfo);
            currPos += maxSize;
        }

        return compressionSequence;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void printLogForPaletteCompression(ArrayList<PaletteXYTag> compressionSequence, BufferedWriter outputLog, int totalCompSize) throws IOException {
        printLogForPaletteXYCompression(compressionSequence, outputLog, USING_PALETTES, totalCompSize);
    }

    private static void printLogForXYFlipCompression(ArrayList<PaletteXYTag> compressionSequence, BufferedWriter outputLog, int totalCompSize) throws IOException {
        printLogForPaletteXYCompression(compressionSequence, outputLog, USING_X_Y_FLIP, totalCompSize);
    }

    private static void printLogForPaletteXYCompression(ArrayList<PaletteXYTag> compressionSequence, BufferedWriter outputLog, boolean loggingPalettes, int totalCompSize) throws IOException {
        // BufferedWriter outputLog = new BufferedWriter(new FileWriter(logFilename));
        outputLog.write("\n--------------------------------------------------------------------------------\n\n");

        int data[];
        if (loggingPalettes) {
            data = tilemapPalettes;
            outputLog.write("Compressing palettes...\n\n");
        }
        else {
            data = tilemapXYFlips;
            outputLog.write("Compressing X/Y flip bits...\n\n");
        }

        outputLog.write(" Pos | Size | CompSize | Description\n");
        outputLog.write("-----+------+----------+-------------\n");
        String line =   " %3X |  %3X |  %X (%3X) | %s\n";

        int totalValsReadFromBuffer = 0;
        int numValsPerBuffer = loggingPalettes ? NUM_THREE_BIT_VALS_IN_BUFFER : NUM_TWO_BIT_VALS_IN_BUFFER;
        for (PaletteXYTag block : compressionSequence) {
            int posToExpectToWriteBufferContents = loggingPalettes ?
                nextWriteToPaletteBuffer(totalValsReadFromBuffer) :
                nextWriteToTwoBitSetBuffer(totalValsReadFromBuffer);

            int size = block.getSize();
            int pos = block.getPosition();

            String info = "";
            int compSize = block.getNumBytesToEncodeCase();
            switch (block.getType()) {
                case RunOfZeroes:
                    info = String.format("0x%3X sets of 00", size);
                    break;
                case ReuseFromOneRowUpThenZeroes:
                    info = String.format("0x%3X sets of 00, after reusing %d from one row up", size - 1, data[pos]);
                    break;
                case ReuseFromOneRowUpAndRepeat:
                    info = String.format("0x%3X sets of %2d, reused from one row up", size, data[pos]);
                    break;
                case NewPaletteXYThenZeroes:
                    info = String.format("0x%3X sets of 00, after new val %d", size - 1, data[pos]);
                    break;
                case RepeatNewPaletteXY:
                    info = String.format("0x%3X sets of %2d", size, data[pos]);
                    break;
                case LiteralSequence:
                    info = String.format("0x%3X literals:", size);
                    for (int i = 0; i < size; i++) {
                        info += String.format(" %d", data[pos + i]);
                    }
                    break;
            }
            outputLog.write(String.format(line, pos, size, compSize, totalCompSize, info));
            totalCompSize += compSize;

            int numValsToRead = block.getNumValsToReadFromBuffer(loggingPalettes);
            totalValsReadFromBuffer += numValsToRead;

            if (totalValsReadFromBuffer >= posToExpectToWriteBufferContents) {
                // if logging palettes, only one set of 8 vals can be written at a time
                if (loggingPalettes) {
                    outputLog.write(String.format("^ Write 1 buffer (%3X)\n", totalCompSize));
                    totalCompSize += NUM_BYTES_IN_PALETTE_BUFFER;
                }
                // if logging X/Y flips, count how many bytes must be written
                else {
                    int difference = totalValsReadFromBuffer - posToExpectToWriteBufferContents;
                    int numBytesToWrite = 1 + difference / NUM_TWO_BIT_VALS_IN_BUFFER;
                    outputLog.write(String.format("^ Write %d buffer (%3X)\n", numBytesToWrite, totalCompSize));
                    totalCompSize += numBytesToWrite;
                }
            }
            if (numValsToRead != 0) {
                int numBuffers = totalValsReadFromBuffer / numValsPerBuffer;
                int numValsLeftInBuffer = totalValsReadFromBuffer % numValsPerBuffer;
                outputLog.write(String.format("-- Read %d buffer values (0x%X*%d+%d)\n", numValsToRead, numBuffers, numValsPerBuffer, numValsLeftInBuffer));
            }
        }

        int numBuffers = totalValsReadFromBuffer / numValsPerBuffer;
        if (totalValsReadFromBuffer % numValsPerBuffer != 0) {
            numBuffers++;
        }
        String type = loggingPalettes ? "palette " : "X/Y flip";
        String bufferValsPrintout = "\nTotal %s buff vals: 0x%2X (0x%2X buffers)\n";
        outputLog.write(String.format(bufferValsPrintout, type, totalValsReadFromBuffer, numBuffers));

        outputLog.flush();
        // outputLog.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int getNumPaletteXYBufferValues(ArrayList<PaletteXYTag> compressionSequence, boolean checkingPalettes) {
        int total = 0;
        for (PaletteXYTag block : compressionSequence) {
            total += block.getNumValsToReadFromBuffer(checkingPalettes);
        }
        return total;
    }

    private static ArrayList<Integer> getPaletteXYValuesToWriteToBuffer(ArrayList<PaletteXYTag> compressionSequence, boolean checkingPalettes) {
        ArrayList<Integer> bufferValues = new ArrayList<>();
        int dataSet[] = (checkingPalettes ? tilemapPalettes : tilemapXYFlips);

        for (PaletteXYTag block : compressionSequence) {
            int numPalettesToWrite = block.getNumValsToReadFromBuffer(checkingPalettes);
            if (numPalettesToWrite > 0) {
                PaletteXYType type = block.getType();
                int size = block.getSize();
                int startPos = block.getPosition();

                if (type == PaletteXYType.LiteralSequence) {
                    // the first literal is encoded directly into the type byte
                    startPos++;
                    size--;
                    for (int i = 0; i < size; i++) {
                        bufferValues.add(dataSet[startPos + i]);
                    }
                }
                else if (type == PaletteXYType.NewPaletteXYThenZeroes ||
                         type == PaletteXYType.RepeatNewPaletteXY) {
                    bufferValues.add(dataSet[startPos]);
                }
            }
        }

        int numValuesPerBuffer = checkingPalettes ? NUM_THREE_BIT_VALS_IN_BUFFER : NUM_TWO_BIT_VALS_IN_BUFFER;

        // if size of list is not a multiple of 4 (palettes) or 8 (X/Y flips),
        // pad the list with 00 values until the size is such a multiple
        while (bufferValues.size() % numValuesPerBuffer != 0) {
            bufferValues.add(0x00);
        }

        return bufferValues;
    }

    private static ArrayList<PaletteXYTag> optimizeNumBufferVals(ArrayList<PaletteXYTag> compressionSequence, boolean checkingPalettes) {
        // if got 8N+1 thru 8N+4 buffer values while doing palettes, the extra
        // values represent three bytes that are mostly wasted on lots of empty
        // space; print a notice if this occurs, and see if you can claw back
        // the values in the final buffer to save a byte or two
        int totalBufferVals = getNumPaletteXYBufferValues(compressionSequence, checkingPalettes);
        int numValuesPerBuffer = checkingPalettes ? NUM_THREE_BIT_VALS_IN_BUFFER : NUM_TWO_BIT_VALS_IN_BUFFER;
        int numValuesInLastBuffer = totalBufferVals % numValuesPerBuffer;

        if (checkingPalettes && numValuesInLastBuffer >= 1 && numValuesInLastBuffer <= 4) {
            // System.out.printf("%s: 0x%2X palette buffer vals (%d in last)\n", inputFilename, totalBufferVals, numValuesInLastBuffer);
            return reducePaletteBufferValues(compressionSequence, numValuesInLastBuffer);
        }
        // TODO if doing all that didn't save a buffer for us, we can might as
        // well try to convert small tags to lit sequences to fill in the last
        // buffer as much as possible and save some type bytes along the way
        return compressionSequence;
        /*
        if (newSequence != null && newSequence.equals(compressionSequence)) {
            return compressionSequence;
        }
        else {
            return newSequence;
        }
        */
    }

    private static ArrayList<PaletteXYTag> reducePaletteBufferValues(ArrayList<PaletteXYTag> paletteCompression, int numExtraValues) {
        int totalExtraValues = numExtraValues;
        int numExtraTypeBytesUsed = 0;
        ArrayList<PaletteXYTag> newCompression = new ArrayList<>();
        // do most efficient case first: if a run of length 2 was reencoded as
        // the start/end of a literal sequence, splitting it off from the lits
        // will sacrifice 1 byte to get rid of 2 buffer values:
        // - 1, 2: uses 1 new type byte,  gain 3 bytes from no buffer - profit
        // - 3, 4: uses 2 new type bytes, gain 3 bytes from no buffer - profit
        // - 5, 6: uses 3 new type bytes, gain 3 bytes from no buffer - even
        // - 7, 8: uses 4 new type bytes, gain 3 bytes from no buffer - loss
        for (int i = 0; i < paletteCompression.size(); i++) {
            PaletteXYTag block = paletteCompression.get(i);
            if (block.getType() != PaletteXYType.LiteralSequence) {
                newCompression.add(block);
                continue;
            }

            int size = block.getSize();
            if (size <= 2 || numExtraValues <= 0) {
                newCompression.add(block);
                continue;
            }

            int pos = block.getPosition();
            boolean runOfTwoAtStart = tilemapPalettes[pos] == tilemapPalettes[pos+1];
            boolean runOfTwoAtEnd = tilemapPalettes[pos + size - 2] == tilemapPalettes[pos + size - 1];

            if (runOfTwoAtStart) {
                PaletteXYType type = tilemapPalettes[pos] == 0 ?
                    PaletteXYType.RunOfZeroes :
                    PaletteXYType.RepeatNewPaletteXY;
                PaletteXYTag run = new PaletteXYTag(type, 2, pos,
                    TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                PaletteXYTag lits = new PaletteXYTag(PaletteXYType.LiteralSequence, size - 2, pos + 2,
                    TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);

                newCompression.add(run);
                numExtraValues -= 2;
                numExtraTypeBytesUsed++;

                // a group of literals can possibly have runs of 2 on both ends
                if (runOfTwoAtEnd && numExtraValues > 0) {
                    lits = new PaletteXYTag(PaletteXYType.LiteralSequence, size - 4, pos + 2,
                        TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);

                    PaletteXYType type2 = tilemapPalettes[pos + size - 2] == 0 ?
                        PaletteXYType.RunOfZeroes :
                        PaletteXYType.RepeatNewPaletteXY;
                    PaletteXYTag run2 = new PaletteXYTag(type2, 2, pos + size - 2,
                        TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);

                    newCompression.add(lits);
                    newCompression.add(run2);

                    numExtraValues -= 2;
                    numExtraTypeBytesUsed++;
                }
                else {
                    newCompression.add(lits);
                }
            }
            else if (runOfTwoAtEnd) {
                PaletteXYType type = tilemapPalettes[pos + size - 2] == 0 ?
                    PaletteXYType.RunOfZeroes :
                    PaletteXYType.RepeatNewPaletteXY;
                PaletteXYTag lits = new PaletteXYTag(PaletteXYType.LiteralSequence, size - 2, pos,
                    TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                PaletteXYTag run = new PaletteXYTag(type, 2, pos + size - 2,
                    TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);

                newCompression.add(lits);
                newCompression.add(run);

                numExtraValues -= 2;
                numExtraTypeBytesUsed++;

                // it's possible that multiple 2-byte runs got added to the end
                // of a literal sequence, but would rewinding back onto the now
                // shorter literal sequence mess up the ordering?
            }
            else {
                newCompression.add(block);
            }
        }
        if (numExtraValues <= 0 && numExtraTypeBytesUsed < NUM_BYTES_IN_PALETTE_BUFFER) {
            String format = "%s: Saved %d bytes from using %d fewer palette buffer vals (2 run(s) at start/end of lits)\n";
            System.out.printf(format, inputFilename, NUM_BYTES_IN_PALETTE_BUFFER - numExtraTypeBytesUsed, totalExtraValues - numExtraValues);
            return newCompression;
        }

        // if that didn't save you a buffer, next best option is looking for the
        // "repeat a value" case; you can exchange 1 value for 1 or 2 bytes
        // based on how many times the full length can be divided into the size
        // threshold for encoding the size in a byte
        final int REPEAT_THRESHOLD_5 = 0x5;
        for (int i = 0; i < newCompression.size(); i++) {
            PaletteXYTag block = newCompression.get(i);
            if (block.getType() != PaletteXYType.RepeatNewPaletteXY) {
                continue;
            }

            int size = block.getSize();
            if (size <= REPEAT_THRESHOLD_5 || numExtraValues <= 0) {
                continue;
            }

            // calculating # tags from size of the run (N > 1 by def. of run):
            // N:     0 1 2 3 4 5 | 6 7 8 9 A | B C D E F | 10 11 12 13 14 | 15
            // tags:  - - 1 1 1 1 | 2 2 2 2 2 | 3 3 3 3 3 |  4  4  4  4  4 |  5
            // extra: - - 0 0 0 0 | 1 1 1 1 1 | 2 2 2 2 2 |  3  3  3  3  3 |  4
            // vals:  - - 0 0 0 0 | 1 1 1 1 1   1 1 1 1 1    1  1  1  1  1    1
            // doing this is only worth it if:
            // # *additional* tags + # type bytes used so far < 3
            int extraTags = (size - 1) / REPEAT_THRESHOLD_5;
            if (extraTags + numExtraTypeBytesUsed >= NUM_BYTES_IN_PALETTE_BUFFER) {
                continue;
            }

            // replace full-length tag with a new tag restricted to length 5
            int pos = block.getPosition();
            PaletteXYType runType = PaletteXYType.RepeatNewPaletteXY;
            PaletteXYTag run1 = new PaletteXYTag(PaletteXYType.RepeatNewPaletteXY, REPEAT_THRESHOLD_5, pos,
                    TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
            newCompression.set(i, run1);

            // if # extra tags is 2, add another tag of length 5
            for (int tagNum = 1; tagNum < extraTags; tagNum++) {
                int runPos = pos + REPEAT_THRESHOLD_5 * tagNum;
                PaletteXYTag run = new PaletteXYTag(runType, REPEAT_THRESHOLD_5, runPos,
                    TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                newCompression.add(i + tagNum, run);
            }

            // add the last tag with the rest of the run; if full length is 6 or
            // B (5*1 + 1, 5*2 + 1), then the last one must be added as a lit,
            // which must be its own tag if followed by a lit sequence
            int lastRunSize = size % REPEAT_THRESHOLD_5;
            int lastRunPos = pos + REPEAT_THRESHOLD_5 * extraTags;
            PaletteXYType lastRunType = lastRunSize >= 2 ? PaletteXYType.RepeatNewPaletteXY : PaletteXYType.LiteralSequence;
            PaletteXYTag lastRun = new PaletteXYTag(lastRunType, lastRunSize, lastRunPos,
                    TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
            newCompression.add(i + extraTags, lastRun);

            numExtraValues--;
            numExtraTypeBytesUsed += extraTags;
        }
        if (numExtraValues <= 0 && numExtraTypeBytesUsed < NUM_BYTES_IN_PALETTE_BUFFER) {
            String format = "%s: Saved %d bytes from using %d fewer palette buffer vals (split up \"repeat value\" tag)\n";
            System.out.printf(format, inputFilename, NUM_BYTES_IN_PALETTE_BUFFER - numExtraTypeBytesUsed, totalExtraValues - numExtraValues);
            return newCompression;
        }

        // if still didn't cut out a buffer, next step would be to look for 2
        // byte runs that are in the middle of literal sequences; splitting it
        // off into its own case requires 2 bytes to save 2 values:
        // - [01 02 02 03]       -> [01]    [02 02] [03]
        // - [00 01 02 02 03 04] -> [00 01] [02 02] [03 04]
        //
        // so if # extra type bytes used so far >= 1, may as well just keep the
        // old sequence since you're gaining no extra space from this
        if (numExtraTypeBytesUsed > 0) {
            return paletteCompression;
        }

        for (int i = 0; i < paletteCompression.size(); i++) {
            PaletteXYTag block = paletteCompression.get(i);
            if (block.getType() != PaletteXYType.LiteralSequence) {
                continue;
            }

            int size = block.getSize();
            if (size <= 3 || numExtraValues <= 0) {
                continue;
            }

            int pos = block.getPosition();
            boolean usedCase = false;
            for (int offset = 1; offset < size - 1; offset++) {
                if (tilemapPalettes[pos + offset] == tilemapPalettes[pos + offset + 1]) {
                    PaletteXYType type = tilemapPalettes[pos + offset] == 0 ? PaletteXYType.RunOfZeroes : PaletteXYType.RepeatNewPaletteXY;
                    PaletteXYTag lits1 = new PaletteXYTag(PaletteXYType.LiteralSequence, offset, pos,
                        TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                    PaletteXYTag run = new PaletteXYTag(type, 2, pos + offset,
                        TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);
                    PaletteXYTag lits2 = new PaletteXYTag(PaletteXYType.LiteralSequence, size - offset - 2, pos + offset + 2,
                        TilemapCompConstants.USE_RUN_00_RANGE_ORIGINAL);

                    newCompression.set(i, lits1);
                    newCompression.add(i + 1, run);
                    newCompression.add(i + 2, lits2);

                    numExtraTypeBytesUsed += 2;
                    numExtraValues -= 2;

                    usedCase = true;
                    break;
                }
            }
            if (usedCase) break;
        }
        if (numExtraValues <= 0 && numExtraTypeBytesUsed < NUM_BYTES_IN_PALETTE_BUFFER) {
            String format = "%s: Saved %d bytes from using %d fewer palette buffer vals (2 run in middle of lits)\n";
            System.out.printf(format, inputFilename, NUM_BYTES_IN_PALETTE_BUFFER - numExtraTypeBytesUsed, totalExtraValues - numExtraValues);
            return newCompression;
        }
        return paletteCompression;

        /*
        ArrayList<PaletteXYTag> newCompression = new ArrayList<>();
        for (int i = 0; i < paletteCompression.size(); i++) {
            PaletteXYTag block = paletteCompression.get(i);

            int numBuffVals = block.getNumValsToReadFromBuffer(USING_PALETTES);
            if (numBuffVals == 0 || numExtraValues == 0) {
                newCompression.add(block);
                continue;
            }

            PaletteXYType type = block.getType();
            int size = block.getSize();
            int currPos = block.getPosition();
            if (type == PaletteXYType.LiteralSequence) {
            }
            else if (type == PaletteXYType.NewPaletteXYThenZeroes) {
                // easy, split into two tags
                int newSize1 = getThresholdFor00sAfterNewPaletteXyValue(USING_PALETTES);
                int newSize2 = size - newSize1;
                PaletteXYTag newBlock1 = new PaletteXYTag(type, newSize1, currPos);
                PaletteXYTag newBlock2 = new PaletteXYTag(PaletteXYType.RunOfZeroes, newSize2, currPos + newSize1);
                newCompression.add(newBlock1);
                newCompression.add(newBlock2);
                numExtraValues--;
            }
            else if (type == PaletteXYType.RepeatNewPaletteXY) {
            }
        }

        return newCompression;
        */
    }

    // note: reuse "get raw high bits buffer bytes" for the X/Y flip bits
    private static int[] getRawPaletteBufferBytesToWrite(ArrayList<Integer> bufferValues) {
        final int NUM_BYTES_PER_BUFFER = 3;

        // first, calculate the size of the list:
        // # buffers to write = # palette values / 8
        int numBuffersToWrite = bufferValues.size() / NUM_THREE_BIT_VALS_IN_BUFFER;

        // total # bytes = # buffers * 3, because each byte holds either low/mid/hi bits
        int rawBytes[] = new int[numBuffersToWrite * NUM_BYTES_PER_BUFFER];
        for (int bufferNum = 0; bufferNum < numBuffersToWrite; bufferNum++) {
            // get 8 palette values and combine them into three bytes
            int lowBits = 0x00;
            int midBits = 0x00;
            int hiBits  = 0x00;

            // String debugLine = "";
            int bufferValuesStartIndex = bufferNum * NUM_THREE_BIT_VALS_IN_BUFFER;
            int shiftAmount = NUM_THREE_BIT_VALS_IN_BUFFER - 1;

            for (int bit = 0; bit < NUM_THREE_BIT_VALS_IN_BUFFER; bit++) {
                int paletteValue = bufferValues.get(bufferValuesStartIndex + bit);

                // shift bit 0 left 7 times, 6 times for bit 1, ..., 0 times for bit 7
                lowBits |=  (paletteValue & 0x1) << shiftAmount;
                midBits |= ((paletteValue >> 1) & 0x1) << shiftAmount;
                hiBits  |= ((paletteValue >> 2) & 0x1) << shiftAmount;

                shiftAmount--;
                // debugLine += String.format("%d ", paletteValue);
            }

            rawBytes[bufferNum*NUM_BYTES_PER_BUFFER + 0] = lowBits;
            rawBytes[bufferNum*NUM_BYTES_PER_BUFFER + 1] = midBits;
            rawBytes[bufferNum*NUM_BYTES_PER_BUFFER + 2] = hiBits;

            // debugLine += String.format("-> [%02X %02X %02X]\n", lowBits, midBits, hiBits);
            // System.out.println(debugLine);
        }

        return rawBytes;
    }

    private static ArrayList<Integer> generateCompressedPaletteXYBlock(ArrayList<PaletteXYTag> compressionSequence, boolean checkingPalettes) {
        ArrayList<Integer> compressedData = new ArrayList<>();

        ArrayList<Integer> paletteXYBufferValues = getPaletteXYValuesToWriteToBuffer(compressionSequence, checkingPalettes);
        int rawBufferBytes[] = checkingPalettes ?
            getRawPaletteBufferBytesToWrite(paletteXYBufferValues) :
            getRawTwoBitBufferBytesToWrite(paletteXYBufferValues);

        // use the correct set of tilemap data
        int dataSet[] = checkingPalettes ? tilemapPalettes : tilemapXYFlips;

        int bufferBytesListPos = 0;
        int numBufferValsWritten = 0;

        for (int blockNum = 0; blockNum < compressionSequence.size(); blockNum++) {
            PaletteXYTag block = compressionSequence.get(blockNum);
            int nextExpectedDataWritePos = checkingPalettes ?
                nextWriteToPaletteBuffer(numBufferValsWritten) :
                nextWriteToTwoBitSetBuffer(numBufferValsWritten);

            PaletteXYType type = block.getType();
            int size = block.getSize();
            int position = block.getPosition();
            switch (type) {
                case RunOfZeroes: {
                    // both: 00nn nnnn, where 3F is a special case
                    final int SPECIAL_CASE_BYTE = 0x3F;

                    int encodedSize = size - 1;
                    if (size > RUN_00_THRESHOLD_ORIGINAL_3F) {
                        compressedData.add(SPECIAL_CASE_BYTE);
                    }
                    compressedData.add(encodedSize);

                    break;
                }
                case ReuseFromOneRowUpThenZeroes: {
                    // both: 0100 nnnn
                    final int BITMASK = 0x40;

                    int numZeroes = size - 1;
                    int encodedSize = numZeroes - 1;
                    compressedData.add(BITMASK | encodedSize);
                    break;
                }
                case ReuseFromOneRowUpAndRepeat: {
                    // both: 0101 nnnn
                    final int BITMASK = 0x50;

                    int encodedSize = size - 1;
                    compressedData.add(BITMASK | encodedSize);
                    break;
                }
                case NewPaletteXYThenZeroes: {
                    // palettes for 0x1 <= size <= 0x 4: 011p ppnn (2 n bits)
                    // X/Y flip for 0x1 <= size <= 0x 8: 011y xnnn (3 n bits)
                    // palettes for 0x5 <= size <= 0x14: 1010 nnnn
                    // X/Y flip for 0x9 <= size <= 0x18: 1010 nnnn
                    final int BITMASK_FIT = 0x60;
                    final int BITMASK_NOT_FIT = 0xA0;
                    int threshold = getThresholdFor00sAfterNewPaletteXyValue(checkingPalettes);
                    int numZeroes = size - 1;

                    if (numZeroes <= threshold) {
                        final int SHIFT_AMOUNT = checkingPalettes ? 2 : 3;
                        int value = dataSet[position];
                        int encodedSize = numZeroes - 1;

                        int infoByte = BITMASK_FIT | (value << SHIFT_AMOUNT) | encodedSize;
                        compressedData.add(infoByte);
                    }
                    else {
                        // (# 00s - 5) for palettes, (# 00s - 9) for X/Y flip
                        int encodedSize = numZeroes - (threshold + 1);

                        int infoByte = BITMASK_NOT_FIT | encodedSize;
                        compressedData.add(infoByte);
                    }
                    break;
                }
                case RepeatNewPaletteXY: {
                    // palettes for 0x2 <= size <= 0x 5: 100p ppnn (2 n bits)
                    // X/Y flip for 0x2 <= size <= 0x 9: 100y xnnn (3 n bits)
                    // palettes for 0x6 <= size <= 0x15: 1011 nnnn
                    // X/Y flip for 0xA <= size <= 0x19: 1011 nnnn
                    final int BITMASK_FIT = 0x80;
                    final int BITMASK_NOT_FIT = 0xB0;
                    final int SIZE_THRESHOLD = checkingPalettes ? 0x5 : 0x9;

                    if (size <= SIZE_THRESHOLD) {
                        final int SHIFT_AMOUNT = checkingPalettes ? 2 : 3;

                        int value = dataSet[position];
                        int encodedSize = size - 2;

                        int infoByte = BITMASK_FIT | (value << SHIFT_AMOUNT) | encodedSize;
                        compressedData.add(infoByte);
                    }
                    else {
                        // (size - 6) for palettes, (size - 0xA) for X/Y flip
                        int encodedSize = size - (SIZE_THRESHOLD + 1);

                        int infoByte = BITMASK_NOT_FIT | encodedSize;
                        compressedData.add(infoByte);
                    }
                    break;
                }
                case LiteralSequence: {
                    // palettes for 0x1 <= size <= 0x 8: 11pp pnnn (3 n bits)
                    // X/Y flip for 0x1 <= size <= 0x10: 11yx nnnn (4 n bits)
                    final int BITMASK = 0xC0;
                    final int SHIFT_AMOUNT = checkingPalettes ? 3 : 4;

                    int encodedSize = size - 1;
                    int firstValue = dataSet[position];

                    int infoByte = BITMASK | (firstValue << SHIFT_AMOUNT) | encodedSize;
                    compressedData.add(infoByte);
                    break;
                }
            }

            // write the appropriate number of extra bytes after the info byte
            int numValsToRead = block.getNumValsToReadFromBuffer(checkingPalettes);
            numBufferValsWritten += numValsToRead;

            if (numBufferValsWritten >= nextExpectedDataWritePos) {
                // String debugStr = "Pos 0x%3X: 0x%2X >= 0x%2X, write %s buffer bytes\n";
                // System.out.printf(debugStr, position, numBufferValsWritten, nextExpectedDataWritePos, (checkingPalettes ? "palette" : "X/Y flip"));

                if (checkingPalettes) {
                    int bytePosition = bufferBytesListPos * 3;
                    bufferBytesListPos++;

                    compressedData.add(rawBufferBytes[bytePosition + 0]);
                    compressedData.add(rawBufferBytes[bytePosition + 1]);
                    compressedData.add(rawBufferBytes[bytePosition + 2]);
                }

                else {
                    int difference = numBufferValsWritten - nextExpectedDataWritePos;
                    int numBytesToWrite = 1 + difference / NUM_TWO_BIT_VALS_IN_BUFFER;

                    for (int i = 0; i < numBytesToWrite; i++) {
                        compressedData.add(rawBufferBytes[bufferBytesListPos]);
                        bufferBytesListPos++;
                    }
                }
            }
        }

        return compressedData;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void writeIntegerArrayListToFile(ArrayList<Integer> dataBlock, FileOutputStream stream) throws IOException {
        for (int value : dataBlock) {
            stream.write(value);
        }
    }

    private static void generateCompressedTilemap(String pathToInputFile) throws IOException {
        int folderPathLength = pathToInputFile.lastIndexOf("/");
        String folderPath = folderPathLength == -1 ? "" : pathToInputFile.substring(0, folderPathLength);
        String filename = pathToInputFile.substring(folderPath.length() + 1);

        if (filename.startsWith(RECOMPRESSED_FILE_PREFIX)) {
            return;
        }

        int rawTilemapEntries[] = readTilemapEntriesFromFile(pathToInputFile);
		generateCompressedTilemap(rawTilemapEntries, filename);
	}
	
	public static void generateCompressedTilemap(int gfxID) throws IOException {
        int decompressedTilemap[] = KamaitachiTilemapDumper.decompressTilemapROM(gfxID, OUTPUT_FOLDER);
        String outputFilename = String.format("tilemap %02X.bin", gfxID);
        generateCompressedTilemap(decompressedTilemap, outputFilename);
	}

	private static void generateCompressedTilemap(int rawTilemapEntries[], String outputFileDescription) throws IOException {
		inputFilename = outputFileDescription;
        separateOutTilemapEntryComponents(rawTilemapEntries);

        Files.createDirectories(Paths.get(OUTPUT_FOLDER));
        // recommendation: run main() just once with this line not commented
        // out, then comment it out to save time on subsequent executions
        // outputSeparatedEntryComponentsToFiles(inputFilename);

        ArrayList<LowByteTag> lowByteCompression = examineLowBytes();
        ArrayList<HighBitTag> highBitCompression = examineHighBits();
        ArrayList<PaletteXYTag> paletteCompression = examinePalettes();
        paletteCompression = optimizeNumBufferVals(paletteCompression, USING_PALETTES);
        ArrayList<PaletteXYTag> xyFlipCompression = examineXYFlips();

        ArrayList<Integer> lowBytesCompressedBlock = generateCompressedLowBytesBlock(lowByteCompression);
        ArrayList<Integer> highBitsCompressedBlock = generateCompressedHighBitsBlock(highBitCompression);
        ArrayList<Integer> paletteCompressedBlock = generateCompressedPaletteXYBlock(paletteCompression, USING_PALETTES);
        ArrayList<Integer> xyFlipCompressedBlock  = generateCompressedPaletteXYBlock(xyFlipCompression, USING_X_Y_FLIP);

        // ----------

        final boolean DEBUG = true;
        if (DEBUG) {
            String logName = OUTPUT_FOLDER + "LOG recompress '" + inputFilename + "'.txt";
            BufferedWriter outputLog = new BufferedWriter(new FileWriter(logName));

            printLogForLowByteCompression(lowByteCompression, outputLog);
            int lowBytesCompSize = lowBytesCompressedBlock.size();
            outputLog.write(String.format("Total low bytes size: 0x%X\n", lowBytesCompSize));
            int totalCompSize = 1 + lowBytesCompSize;

            printLogForHighBitCompression(highBitCompression, outputLog, totalCompSize);
            int highBitsCompSize = highBitsCompressedBlock.size();
            outputLog.write(String.format("Total high bits size: 0x%X\n", highBitsCompSize));
            totalCompSize += highBitsCompSize;

            printLogForPaletteCompression(paletteCompression, outputLog, totalCompSize);
            int palettesCompSize = paletteCompressedBlock.size();
            outputLog.write(String.format("Total palettes  size: 0x%X\n", palettesCompSize));
            totalCompSize += palettesCompSize;

            printLogForXYFlipCompression(xyFlipCompression, outputLog, totalCompSize);
            int xyFlipCompSize = xyFlipCompressedBlock.size();
            outputLog.write(String.format("Total X/Y flips size: 0x%X\n", xyFlipCompSize));
            totalCompSize += xyFlipCompSize;

            outputLog.write(String.format("\n\nWhole tilemap compressed to: 0x%X\n", totalCompSize));

            outputLog.flush();
            outputLog.close();
        }

        // ----------
        // determine if attempting to compress a block ended up creating a
        // larger block than if you just wrote it uncompressed + bitpacked
        int compressedFlagsByte = 0x0;
        boolean useCompressedLowBytes = lowBytesCompressedBlock.size() < NUM_TILEMAP_ENTRIES;
        boolean useCompressedHighBits = highBitsCompressedBlock.size() < NUM_BYTES_FOR_ALL_BITPACKED_TWO_BIT_VALS;
        boolean useCompressedPalettes = paletteCompressedBlock.size() < NUM_BYTES_FOR_ALL_BITPACKED_THREE_BIT_VALS;
        boolean useCompressedXYFlips = xyFlipCompressedBlock.size() < NUM_BYTES_FOR_ALL_BITPACKED_TWO_BIT_VALS;

        // write a byte that indicates which of the four different blocks are
        // compressed (bit 1) or uncompressed (bit 0)
        // 0x1 = low bytes, 0x2 = high bits, 0x4 = palettes, 0x8 = X/Y flips
        compressedFlagsByte |= (useCompressedLowBytes ? FLAG_COMP_LOW_BYTES : 0);
        compressedFlagsByte |= (useCompressedHighBits ? FLAG_COMP_HIGH_BITS : 0);
        compressedFlagsByte |= (useCompressedPalettes ? FLAG_COMP_PALETTES  : 0);
        compressedFlagsByte |= (useCompressedXYFlips  ? FLAG_COMP_XY_BITS   : 0);

        String outputFilename = OUTPUT_FOLDER + RECOMPRESSED_FILE_PREFIX + inputFilename;
        FileOutputStream outputFile = new FileOutputStream(outputFilename);
        // outputFile.write(0x0F);
        outputFile.write(compressedFlagsByte);

        writeIntegerArrayListToFile(lowBytesCompressedBlock, outputFile);
        writeIntegerArrayListToFile(highBitsCompressedBlock, outputFile);
        writeIntegerArrayListToFile(paletteCompressedBlock,  outputFile);
        writeIntegerArrayListToFile(xyFlipCompressedBlock,   outputFile);

        outputFile.flush();
        outputFile.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    public static void main(String args[]) throws IOException {
        if (args.length == 0) {
            // System.out.println("Sample usage: java KamaitachiTilemapRecompression tilemap1.bin [tilemap2.bin tilemap3.bin ...]");
            for (int gfxID = 0; gfxID < 0x82; gfxID++) {
                generateCompressedTilemap(gfxID);
            }
            return;
        }

        for (String filename : args) {
            File sizeTester = new File(filename);
            long fileSize = sizeTester.length();
            if (fileSize != TILEMAP_BYTES) {
                String error = "'%s' is not correct size: 0x%X, should be 0x%X";
                System.out.println(String.format(error, filename, fileSize, TILEMAP_BYTES));
                continue;
            }

            generateCompressedTilemap(filename);
        }
    }
}
