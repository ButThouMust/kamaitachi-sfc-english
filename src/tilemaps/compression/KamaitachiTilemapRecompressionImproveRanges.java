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

import tilemaps.decompression.KamaitachiTilemapDumper;
import static tilemaps.constants.TilemapCompConstants.*;

public class KamaitachiTilemapRecompressionImproveRanges {

    // packing 0x380 two-bit values into 0x380 * 2 / 8 = 0xE0 bytes
    private static final int NUM_BYTES_FOR_ALL_BITPACKED_TWO_BIT_VALS =
        NUM_TILEMAP_ENTRIES / NUM_TWO_BIT_VALS_IN_BUFFER;
    // packing 0x380 three-bit values into 0x380 * 3 / 8 = 0x150 bytes
    private static final int NUM_BYTES_FOR_ALL_BITPACKED_THREE_BIT_VALS =
        NUM_TILEMAP_ENTRIES * NUM_BYTES_IN_PALETTE_BUFFER / NUM_THREE_BIT_VALS_IN_BUFFER;

    private static final int ONE_BYTE_FOR_COMP_BLOCK_FLAGS = 1;

    private static final int CASE_NOT_VALID = 0;
    // private static final int RUN_00_THRESHOLD_3F = 0x3F;
    private static final int RUN_00_THRESHOLD_40 = 0x40;
    private static final int TAG_SIZE_LIMIT_100 = 0x100;

    private static final boolean USING_PALETTES = true;
    private static final boolean USING_X_Y_FLIP = false;

    private static final String OUTPUT_FOLDER = "recompressed tilemaps/";
    private static final String RECOMPRESSED_FILE_PREFIX = "RECOMPRESSED ";

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
            int highByte = entry >> 8;

            tilemapLowBytes[i]   = entry & 0xFF;
            tilemapIdHighBits[i] = highByte & HIGH_BITS_BITMASK;
            tilemapPalettes[i]   = (highByte & PALETTE_BITMASK) >> 2; // (entry >> 10) & 0x7;
            tilemapXYFlips[i]    = (highByte & XY_FLIP_BITMASK) >> 6; // (entry >> 14) & 0x3;
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
    private static void outputSeparatedEntryComponentsToFiles(int rawTilemapEntries[], String filename) throws IOException {
        // remove file extension
        int periodIndex = filename.indexOf(".");
        String noExtension = filename.substring(0, periodIndex);

        FileOutputStream lowBytesFile = new FileOutputStream(OUTPUT_FOLDER + noExtension + " low bytes.bin");
        FileOutputStream highBitsFile = new FileOutputStream(OUTPUT_FOLDER + noExtension + " high bits - XOR'd.bin");
        FileOutputStream palettesFile = new FileOutputStream(OUTPUT_FOLDER + noExtension + " palettes - XOR'd.bin");
        FileOutputStream flipBitsFile = new FileOutputStream(OUTPUT_FOLDER + noExtension + " XY flips.bin");

        // two options for how to go about this:
        // - write the separated out components individually - useful for
        //   debugging the recompression process
        boolean debugRecompress = true;
        if (!debugRecompress) {
            for (int i = 0; i < NUM_TILEMAP_ENTRIES; i++) {
                lowBytesFile.write(tilemapLowBytes[i]);
                highBitsFile.write(tilemapIdHighBits[i]);
                palettesFile.write(tilemapPalettes[i]);
                flipBitsFile.write(tilemapXYFlips[i]);
            }
        }
        // write the data you get after each stage of decompression is done
        // - useful for debugging the game decompressing the data you feed it
        // (state after propagating XOR down the columns is not included)
        else {
            for (int i = 0; i < NUM_TILEMAP_ENTRIES; i++) {
                lowBytesFile.write(tilemapLowBytes[i]);
                highBitsFile.write(tilemapIdHighBits[i]);
                palettesFile.write(tilemapIdHighBits[i] | (tilemapPalettes[i] << 2));
                flipBitsFile.write(rawTilemapEntries[i] >> 8);
            }
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

    private static ArrayList<Integer> convertIntArrayToArrayList(int data[]) {
        ArrayList<Integer> output = new ArrayList<>(data.length);
        for (int val : data) {
            output.add(val);
        }
        return output;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static final int REUSE_LOW_BYTE_SIZE_LIMIT_20 = 0x20;
    private static final int REPEAT_NEW_LOW_BYTE_THRESHOLD_20 = 0x1E + REPEAT_CASE_MIN_SIZE;
    private static final int REPEAT_NEW_LOW_BYTE_LIMIT_120 = REPEAT_NEW_LOW_BYTE_THRESHOLD_20 + TAG_SIZE_LIMIT_100;
    private static final int INC_SEQ_SIZE_LIMIT_13F = INC_SEQ_SIZE_THRESHOLD_3F + TAG_SIZE_LIMIT_100;
    private static final int REPEAT_CURR_ID_LIMIT_41 = REPEAT_CASE_MIN_SIZE + 0x3F;

    private static final int DEC_SEQ_MIN_LENGTH_02 = 0x2;
    private static final int DEC_SEQ_MAX_LENGTH_10 = 0x10;
    private static final int SET_CURR_ID_SIZE = 2;
    private static final int ISOLATED_INC_SEQ_MIN_LENGTH_02 = 0x2;
    private static final int ISOLATED_INC_SEQ_MAX_LENGTH_05 = 0x5;

    private static enum LowByteType {
        RepeatCurrID(6),
        IncreasingSequence(5),
        ReuseBlockFromOneRowUp(4),
        ReuseMostRecentValue(3),
        RepeatNewID(2),
        LiteralSequence(1),
        // new cases for improved format
        SetCurrID(1),
        DecreasingSequence(2),
        IsolatedIncreasingSequence(2);

        private int priority;

        private LowByteType(int priority) {
            this.priority = priority;
        }

        public int getPriority() {
            return priority;
        }
    }

    private static class LowByteTag implements Comparable<LowByteTag> {
        private LowByteType type;
        private int size;
        private int position;

        public LowByteTag(LowByteType type, int size, int position) {
            this.type = type;
            this.size = size;
            this.position = position;
        }

        public int getSize() {
            return size;
        }

        public int getPosition() {
            return position;
        }

        public LowByteType getType() {
            return type;
        }

        public int compareTo(LowByteTag other) {
            // first, compare by sizes of data
            int sizeDiff = size - other.size;
            if (sizeDiff != 0) return sizeDiff;

            // if sizes happen to tie, compare by priority
            else return type.priority - other.type.priority;
        }

        public int getNumBytesWhenCompressed() {
            // unlike the other compression formats, this value is the exact
            // size of the compression tag, due to not using extra data buffers
            int compSize = 0;
            switch (type) {
                case RepeatCurrID:
                case ReuseBlockFromOneRowUp:
                case ReuseMostRecentValue:
                    compSize = 1;
                    break;

                case IncreasingSequence:
                    compSize = size > INC_SEQ_SIZE_THRESHOLD_3F ? 2 : 1;
                    break;

                case RepeatNewID:
                    compSize = size > REPEAT_NEW_LOW_BYTE_THRESHOLD_20 ? 3 : 2;
                    break;

                case LiteralSequence:
                    compSize = size + 1;
                    break;

                case DecreasingSequence:
                case IsolatedIncreasingSequence:
                    compSize = 2;
                    break;

                case SetCurrID:
                    compSize = SET_CURR_ID_SIZE;
                    break;
            }
            return compSize;
        }
    }

    // -------------

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

    // check pattern without needing to worry about what's at position
    private static int checkForIncreasingSequence(int currPos) {
        return checkForIncreasingSequence(currPos, tilemapLowBytes[currPos]);
    }

    // check pattern while enforcing what MUST be the value at the position
    private static int checkForIncreasingSequence(int currPos, int currTileID) {
        // must also enforce max size here due to altering current tile ID #
        int size = 0;

        int tileIDToCheck = currTileID & 0xFF;
        for (int pos = currPos; pos < tilemapLowBytes.length; pos++) {
            boolean isMatch = tilemapLowBytes[pos] == tileIDToCheck;
            // if (!isMatch || size >= TAG_SIZE_LIMIT_100) {
            if (!isMatch || size >= INC_SEQ_SIZE_LIMIT_13F) {
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

    // note: checking this usually doesn't require knowing the current tile ID,
    // but the decreasing sequence case and the "pass over increasing sequence
    // for now" logic above created a situation at 0x18C in $44B48F where this
    // case will reuse a block from one row up, with the current ID at the end
    // that would start an increasing sequence of length 2; however, when I put
    // in code to handle that special case, it ended up compressing worse by 1
    // byte, so leaving out
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

        // int size = getRunLengthAtPosition(tilemapLowBytes, currPos, TAG_SIZE_LIMIT_100);
        int size = getRunLengthAtPosition(tilemapLowBytes, currPos, REPEAT_NEW_LOW_BYTE_LIMIT_120);
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

    private static int checkIfSettingCurrIdIsWorthIt(int currPos, int currTileID) {
        int checkSettingForIncSequence = checkSettingCurrIdForIncSeq(currPos, currTileID);
        if (checkSettingForIncSequence != CASE_NOT_VALID) {
            return checkSettingForIncSequence;
        }

        int checkSettingForRepeatCurrId = checkSettingCurrIdForRepeatCurrId(currPos, currTileID);
        if (checkSettingForRepeatCurrId != CASE_NOT_VALID) {
            return checkSettingForRepeatCurrId;
        }

        return CASE_NOT_VALID;
    }

    private static int checkSettingCurrIdForRepeatCurrId(int currPos, int currTileID) {
        // confirm that case would work here
        int runLength = checkForRepeatingCurrID(currPos, tilemapLowBytes[currPos]);
        if (runLength == CASE_NOT_VALID) {
            return CASE_NOT_VALID;
        }

        // also confirm that you would find the incremented new current ID soon
        // after the run; definition of "soon" is up to you
        final int SEARCH_DIST = 0x3;
        int posAfterRun = currPos + runLength + 1;
        for (int pos = posAfterRun; pos < posAfterRun + SEARCH_DIST; pos++) {
            if (tilemapLowBytes[pos] == tilemapLowBytes[currPos] + 1) {
                return runLength;
            }
        }
        return CASE_NOT_VALID;
    }

    private static int checkSettingCurrIdForIncSeq(int currPos, int currTileID) {
        // check if there is an increasing sequence at the current position,
        // supposing that the current tile ID is indeed whatever is there now
        int possibleIncSeqLength = checkForIncreasingSequence(currPos);
        if (possibleIncSeqLength == CASE_NOT_VALID || possibleIncSeqLength <= SET_CURR_ID_SIZE) {
            return CASE_NOT_VALID;
        }

        // special case with tilemap 0B at offset 0x36D (curr ID = AB)
        // the data is [56 AA AB AC ...] to end of low bytes block
        // better to do: 4 bytes = (3) 2 lits + (1) inc seq 0x11
        // using set ID: 5 bytes = (2) 1 lit + (2) set AA + (1) inc seq 0x12
        // to do this in a general way, we must consider FF -> 00 wraparound
        // because the below line is flawed and picks up false positives:
        // "if (currTileID > seqStartValue && currTileID - seqStartValue <= 1)"
        int seqStartValue = tilemapLowBytes[currPos];
        for (int i = 0; i < possibleIncSeqLength; i++) {
            int tileIdToTest = (seqStartValue + i) & 0xFF;
            if (currTileID == tileIdToTest) {
                // change the "i <= 1" as you see fit
                if (i <= 1) return CASE_NOT_VALID;
                break;
            }
        }

        // suppose the current ID (were you to not set it for this increasing
        // sequence) appears soon after with a sequence of its own; you'd have
        // to set the current ID twice instead of just once; is that still
        // worth it? (again, how you define "soon" is up to you)
        final int SEARCH_DIST = 0x3;
        int posAfterSeq = currPos + possibleIncSeqLength;
        for (int pos = posAfterSeq; pos < posAfterSeq + SEARCH_DIST && pos < tilemapLowBytes.length; pos++) {
            if (tilemapLowBytes[pos] == currTileID) {
                int nextSeqLength = checkForIncreasingSequence(pos);
                if (nextSeqLength != CASE_NOT_VALID && possibleIncSeqLength > SET_CURR_ID_SIZE * 2) {
                    return possibleIncSeqLength;
                }
                return CASE_NOT_VALID;
            }
        }
        return possibleIncSeqLength;
    }

    private static int checkForDecreasingSequence(int currPos, boolean currPosHasCurrId) {
        // simplistic performance boost: start checking for the decreasing sequence at
        // the byte right after the current position
        final int START_OFFSET = 1;
        int size = START_OFFSET;

        int tileIDToCheck = (tilemapLowBytes[currPos] - 1) & 0xFF;
        for (int pos = currPos + START_OFFSET; pos < tilemapLowBytes.length; pos++) {
            boolean isMatch = tilemapLowBytes[pos] == tileIDToCheck;
            if (!isMatch || size >= DEC_SEQ_MAX_LENGTH_10) {
                break;
            }
            size++;
            tileIDToCheck = (tileIDToCheck - 1) & 0xFF;
        }

        if (size < DEC_SEQ_MIN_LENGTH_02) {
            return CASE_NOT_VALID;
        }

        // if current position both has the current ID and happens to be the
        // start of a decreasing sequence, you should typically prioritize the
        // increasing sequence (only 1 byte, but advances curr ID) regardless
        // of the decreasing sequence's size; however, see if the current ID is
        // right after the decreasing sequence to get both [dec seq] [inc seq]
        if (currPosHasCurrId) {
            final int SEARCH_DIST = 1;
            boolean foundCurrIdAfterDecSeq = false;
            for (int i = 0; i < SEARCH_DIST && foundCurrIdAfterDecSeq; i++) {
                foundCurrIdAfterDecSeq = foundCurrIdAfterDecSeq || tilemapLowBytes[currPos] == tilemapLowBytes[currPos + size + i];
            }
            if (!foundCurrIdAfterDecSeq) {
                return CASE_NOT_VALID;
            }
            System.out.println("Found dec seq with curr ID, followed by inc seq of curr ID");
        }

        return size;
    }

    private static int checkForShortIsolatedIncreasingSequence(int currPos, int currID) {
        if (currID == tilemapLowBytes[currPos]) return CASE_NOT_VALID;

        int size = checkForIncreasingSequence(currPos);
        if (size < ISOLATED_INC_SEQ_MIN_LENGTH_02 || size > ISOLATED_INC_SEQ_MAX_LENGTH_05) {
            return CASE_NOT_VALID;
        }

        // handle special case that popped up with gfx ID 0x6F @ 0x131
        // current ID = 8F, data is [8E 8F 90 91 92 ; 4E 4E 4E 4E ; 93 94]
        for (int i = 1; i < size; i++) {
            if (tilemapLowBytes[currPos + i] == currID) {
                return CASE_NOT_VALID;
            }
        }

        // I made this case to handle some shortcomings I found with the "set
        // current ID case", but sometimes, doing "set ID" is better
        // here is an attempt to check if this is indeed the case or not
        final int SEARCH_DIST = 0x2;
        int idToSearchFor = (tilemapLowBytes[currPos] + size) & 0xFF;
        for (int i = 0; i < SEARCH_DIST; i++) {
            int posAfterSeq = currPos + size + i;
            if (posAfterSeq >= tilemapLowBytes.length) break; 

            if (tilemapLowBytes[posAfterSeq] == idToSearchFor) {
                return CASE_NOT_VALID;
            }
        }

        return size;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static ArrayList<LowByteTag> examineLowBytes() {
        int currentTileID = STARTING_LOW_BYTE;
        int currPos = 0;
        // this is 0x20 in Chunsoft's compression format; reduce limit to make
        // space for the decreasing sequence, isolated increasing sequence, and
        // set current ID cases
        final int MAX_LITERALS = 0xC;

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

            // new: add check for decreasing sequence, only if increasing
            // sequence is not valid
            boolean canDoIncSeq = incSequenceCount != CASE_NOT_VALID;
            int decSequenceCount = checkForDecreasingSequence(currPos, canDoIncSeq);

            // new: add check for short, self-contained increasing sequence,
            // only if regular increasing sequence is not valid
            int isolatedIncSequenceCount = CASE_NOT_VALID;
            if (!canDoIncSeq) {
                isolatedIncSequenceCount = checkForShortIsolatedIncreasingSequence(currPos, currentTileID);
            }

            HashMap<LowByteType, Integer> counts = new HashMap<>();
            counts.put(LowByteType.RepeatCurrID, repeatCurrIDCount);
            counts.put(LowByteType.IncreasingSequence, incSequenceCount);
            counts.put(LowByteType.ReuseBlockFromOneRowUp, reuseOneRowUpCount);
            counts.put(LowByteType.ReuseMostRecentValue, reuseMostRecentCount);
            counts.put(LowByteType.RepeatNewID, repeatNewIDCount);
            counts.put(LowByteType.DecreasingSequence, decSequenceCount);
            counts.put(LowByteType.IsolatedIncreasingSequence, isolatedIncSequenceCount);

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

            // encode a single literal byte if:
            // 1. none of the compression methods work here
            if (maxSize == CASE_NOT_VALID) {
                maxSize = 1;
                bestType = LowByteType.LiteralSequence;
            }
            // 2. the most recent case was literals and the current case is for
            //    a length 1 reuse of data (note: NOT an increasing sequence)
            // (optimization based on low bytes for tilemap 4B at 0x1B6)
            // idea is to combine multiple literal tags together and avoid using
            // multiple overhead bytes for seperate literal tags
            //
            // 3. the most recent case was for literals, and the current case is
            //    for a length 2 decreasing sequence or length 2 isolated
            //    increasing sequence
            // the two blocks can be equivalently encoded as one block of 3 lits
            else if ((bestType != LowByteType.IncreasingSequence && maxSize == 1) ||
                     (bestType == LowByteType.DecreasingSequence && maxSize == DEC_SEQ_MIN_LENGTH_02) ||
                     (bestType == LowByteType.IsolatedIncreasingSequence && maxSize == ISOLATED_INC_SEQ_MIN_LENGTH_02))
            {
                int numTags = compressionSequence.size();
                if (numTags > 0) {
                    LowByteTag lastTag = compressionSequence.get(numTags - 1);
                    LowByteType lastType = lastTag.getType();
                    int lastSize = lastTag.getSize();
                    if (lastType == LowByteType.LiteralSequence && lastSize + maxSize <= MAX_LITERALS) {
                        bestType = LowByteType.LiteralSequence;
                    }
                }
            }

            // new: if literal, see if setting the current ID would create an
            // increasing sequence now (must be long enough to be worth it)
            // TODO see how isolated increasing sequence affects this
            if (bestType == LowByteType.LiteralSequence) {
                int checkSettingCurrID = checkIfSettingCurrIdIsWorthIt(currPos, currentTileID);
                if (checkSettingCurrID != CASE_NOT_VALID) {
                    bestType = LowByteType.SetCurrID;
                    maxSize = 0;
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
                case SetCurrID:
                    currentTileID = tilemapLowBytes[currPos];
                    break;
                default:
                    break;
            }
            currentTileID &= 0xFF;

            // if both the current and last iterations were for literal bytes,
            // just combine the size of the current iteration into the last one,
            // if the combined size fits into the 0x10 literal byte limit
            //
            // this can also handle the reverse of "case 3" above: most recent
            // case was a length 2 decreasing sequence (or isolated increasing
            // sequence), and the current case is for a literal
            // again, equivalently encodable as 1 block of 3 lits
            // (optimization based on low bytes for $2C9A31 at 0x367)
            int numTags = compressionSequence.size();
            if (numTags > 0 && bestType == LowByteType.LiteralSequence) {
                LowByteTag lastSet = compressionSequence.get(numTags - 1);
                LowByteType lastType = lastSet.getType();
                int lastSize = lastSet.getSize();

                int combinedSize = lastSize + maxSize;

                if ((lastType == LowByteType.LiteralSequence && combinedSize <= MAX_LITERALS) ||
                    (lastType == LowByteType.DecreasingSequence && lastSet.getSize() == DEC_SEQ_MIN_LENGTH_02) ||
                    (lastType == LowByteType.IsolatedIncreasingSequence && lastSet.getSize() == ISOLATED_INC_SEQ_MIN_LENGTH_02)) {
                    // update last iteration, advance past this literal
                    int lastPos = lastSet.getPosition();
                    lastSet = new LowByteTag(LowByteType.LiteralSequence, combinedSize, lastPos);
                    compressionSequence.set(numTags - 1, lastSet);
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

    // to be used if "compressing" a data block results in a larger block than
    // if you just used the 0x380 byte block
    private static ArrayList<Integer> generateUncompressedLowBytesBlock() {
        return convertIntArrayToArrayList(tilemapLowBytes);
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

                    // int encodedSize = size - 1;
                    if (size <= INC_SEQ_SIZE_THRESHOLD_3F) {
                        int encodedSize = size - 1;
                        compressedData.add(encodedSize | BITMASK);
                    }
                    else {
                        compressedData.add(SPECIAL_CASE_BYTE);
                        int encodedSize = size - (INC_SEQ_SIZE_THRESHOLD_3F + 1);
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
                        // int encodedSize = size - 1;
                        int encodedSize = size - (REPEAT_NEW_LOW_BYTE_THRESHOLD_20 + 1);
                        compressedData.add(SPECIAL_CASE_BYTE);
                        compressedData.add(encodedSize);
                    }

                    // next, write the byte that has to be repeated
                    compressedData.add(tilemapLowBytes[position]);
                    break;
                }
                case LiteralSequence: {
                    // 111x xxxx (E0-FF) - originally
                    // 1110 xxxx (E0-EB) - new
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
                case DecreasingSequence: {
                    // 1111 xxxx (F0-FE) - new
                    final int BITMASK = 0xF0;

                    // first, encode the sequence length
                    int encodedSize = size - DEC_SEQ_MIN_LENGTH_02;
                    compressedData.add(encodedSize | BITMASK);

                    // write the first byte in the sequence
                    compressedData.add(tilemapLowBytes[position]);
                    break;
                }
                case SetCurrID: {
                    final int SET_CURR_ID_TYPE_BYTE = 0xFF;
                    compressedData.add(SET_CURR_ID_TYPE_BYTE);
                    compressedData.add(tilemapLowBytes[position]);
                    break;
                }
                case IsolatedIncreasingSequence: {
                    // 1110 11xx (EC-EF) - new
                    final int ISOL_INC_SEQ_TYPE_BYTE_BASE = 0xEC;

                    // first, encode sequence length; note how here, we ADD, not
                    // use bitwise OR
                    int encodedSize = size - ISOLATED_INC_SEQ_MIN_LENGTH_02;
                    compressedData.add(ISOL_INC_SEQ_TYPE_BYTE_BASE + encodedSize);
                    compressedData.add(tilemapLowBytes[position]);
                    break;
                }
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
                case SetCurrID:
                    currID = tilemapLowBytes[block.getPosition()];
                    tileIdChange = String.format("%02X - SET", currID);
                    break;
                // optional: print the starting value of the decreasing seq
                case DecreasingSequence:
                case IsolatedIncreasingSequence:
                    String sign = (block.getType() == LowByteType.DecreasingSequence) ? "-" : "+";
                    tileIdChange = String.format("  (%02X)%s ", tilemapLowBytes[block.getPosition()], sign);
                    break;
                default:
                    break;
            }

            int compSize = block.getNumBytesWhenCompressed();
            String info = " %3X |  %3X | %2X (%3X) | %s  | %s\n";
            outputLog.write(String.format(info, block.getPosition(), block.getSize(), compSize, totalCompSize, tileIdChange, block.getType().toString()));
            totalCompSize += compSize;
        }

        // none of the game's tilemaps should trigger this, but it's possible to
        // feed a data block that when "compressed" takes more space than if you
        // just wrote the 0x380 bytes as-is (e.g. 0x38 blocks of 0x10 literals)
        if (totalCompSize - ONE_BYTE_FOR_COMP_BLOCK_FLAGS > NUM_TILEMAP_ENTRIES) {
            String info = "NOTE: 0x%3X > 0x%3X, so better stored uncompressed";
            outputLog.write(String.format(info, totalCompSize - 1, NUM_TILEMAP_ENTRIES));
        }

        outputLog.flush();
        // outputLog.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static final int HIGH_BITS_MAX_00_RUN_AFTER_VAL_28 = 0x28; // 1 + 8 + 1f
    private static final int HIGH_BITS_MAX_REPEAT_LENGTH_29 = 0x29;    // 2 + 8 + 1f
    private static final int RUN_00_SIZE_LIMIT_140 = TAG_SIZE_LIMIT_100 + RUN_00_THRESHOLD_40;

    private static enum HighBitType {
        RunOfZeroes,
        NonZeroThenZeroes,
        RepeatNonZeroVal,
        LiteralSequence;
    }

    private static class HighBitTag {
        private HighBitType type;
        private int size;
        private int position;

        public HighBitTag(HighBitType type, int size, int position) {
            this.type = type;
            this.size = size;
            this.position = position;
        }

        public int getSize() {
            return size;
        }

        public int getPosition() {
            return position;
        }

        public HighBitType getType() {
            return type;
        }

        public int getNumBytesToEncodeCase() {
            if (type == HighBitType.RunOfZeroes && size > RUN_00_THRESHOLD_40)
                return 2;
            return 1;
        }

        public int getNumValsToReadFromBuffer() {
            int numValsToRead = 0;
            switch (type) {
                case LiteralSequence:
                    numValsToRead = size - 1;
                    break;
                case NonZeroThenZeroes:
                    // size >= 0x9
                    int numZeroes = size - 1;
                    if (numZeroes > HIGH_BITS_00_RUN_THRESHOLD_08) {
                        numValsToRead = 1;
                    }
                    break;
                case RepeatNonZeroVal:
                    // size >= 0xA
                    if (size > HIGH_BITS_REPEAT_VAL_THRESHOLD_09) {
                        numValsToRead = 1;
                    }
                    break;
                default:
                    break;
            }
            return numValsToRead;
        }
    }

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
                // length = getRunLengthAtPosition(tilemapIdHighBits, currPos, TAG_SIZE_LIMIT_100);
                length = getRunLengthAtPosition(tilemapIdHighBits, currPos, RUN_00_SIZE_LIMIT_140);
                if (length >= REPEAT_CASE_MIN_SIZE) type = HighBitType.RunOfZeroes;
            }
            // if not at a 00, check the next value, *if available*; otherwise,
            // fall back on the default values above
            else if (currPos + 1 < tilemapIdHighBits.length) {
                int nextValue = tilemapIdHighBits[currPos + 1];
                // one non-zero value, followed by up to 0x28 zeroes
                // note: if followed by only one 00, check if it'd be better to
                // just incorporate into literal sequence
                if (nextValue == 0) {
                    // you can avoid writing the non-zero value to the buffer if
                    // non-limited run length of 00 bytes is in certain ranges
                    // length = getRunLengthAtPosition(tilemapIdHighBits, currPos + 1, HIGH_BITS_MAX_00_RUN_AFTER_VAL_28);
                    length = getRunLengthAtPosition(tilemapIdHighBits, currPos + 1, NUM_TILEMAP_ENTRIES);

                    // if 0x29 <= length <= 0x48, two options for encoding:
                    // 0x8 + (0x21 <= N <= 0x40), or 0x28 + (0x1 <= N <= 0x20)
                    // both cases need to encode a one byte run, but 0x8 doesn't
                    // need to write a high bits value to the buffer
                    boolean needOneByte2ndRunAnyway =
                        length > HIGH_BITS_MAX_00_RUN_AFTER_VAL_28 &&
                        length <= RUN_00_THRESHOLD_40 + HIGH_BITS_00_RUN_THRESHOLD_08;

                    // if 0x68 <= length <= 0x148, two options for encoding:
                    // 0x8 + (0x60 <= N <= 0x140), or 0x28 + (0x40 <= N <= 0x120)
                    // both cases need to encode a two byte run, but 0x8 doesn't
                    // need to write a high bits value to the buffer
                    boolean needTwoByte2ndRunAnyway =
                        length > RUN_00_THRESHOLD_40 + HIGH_BITS_MAX_00_RUN_AFTER_VAL_28 &&
                        // length <= TAG_SIZE_LIMIT_100 + HIGH_BITS_00_RUN_THRESHOLD_08;
                        length <= RUN_00_SIZE_LIMIT_140 + HIGH_BITS_00_RUN_THRESHOLD_08;

                    // if length >= 0x169, you need 3 runs anyway, so limit 1st run
                    // 0x28 + 0x140 + (0x1-0x20), or 0x8 + 0x140 + (0x21-0x40)
                    // boolean needAtLeastThreeRunsAnyway = length > TAG_SIZE_LIMIT_100 + HIGH_BITS_MAX_00_RUN_AFTER_VAL_28;
                    boolean needAtLeastThreeRunsAnyway = length > RUN_00_SIZE_LIMIT_140 + HIGH_BITS_MAX_00_RUN_AFTER_VAL_28;

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

                // one non-zero value that is repeated up to 0x29 times
                else if (nextValue == value) {
                    length = getRunLengthAtPosition(tilemapIdHighBits, currPos, HIGH_BITS_MAX_REPEAT_LENGTH_29);
                    type = HighBitType.RepeatNonZeroVal;
                }

                // if a non-zero value followed by a different non-zero value,
                // just use the default values listed above
            }

            // optimizations for combining into last iteration if possible
            int numTags = compressionSequence.size();
            if (numTags > 0) {
                HighBitTag lastTag = compressionSequence.get(numTags - 1);
                int lastSize = lastTag.getSize();

                if (lastTag.getType() == HighBitType.LiteralSequence) {
                    // combine consecutive literal sequences if they fit
                    if (type == HighBitType.LiteralSequence) {
                        int combinedSize = length + lastSize;
                        if (combinedSize <= MAX_LITERALS) {
                            lastTag = new HighBitTag(HighBitType.LiteralSequence, combinedSize, lastTag.getPosition());
                            compressionSequence.set(numTags - 1, lastTag);

                            currPos += length;
                            continue;
                        }
                    }

                    // if [literals][one non-zero + run of 00s], can combine if
                    // the run of 00s is either 1 byte long, or got limited by
                    // having to use that case
                    else if (type == HighBitType.NonZeroThenZeroes) {
                        int numZeroes = length - 1;
                        // int trueLengthOfZeroRun = getRunLengthAtPosition(tilemapIdHighBits, currPos + 1, TAG_SIZE_LIMIT_100);
                        int trueLengthOfZeroRun = getRunLengthAtPosition(tilemapIdHighBits, currPos + 1, RUN_00_SIZE_LIMIT_140);
                        int combinedSize = lastSize + 1;

                        // if yes, combine the non-zero value into the literals
                        if ((numZeroes == 1 || trueLengthOfZeroRun > numZeroes) && combinedSize <= MAX_LITERALS) {
                            lastTag = new HighBitTag(HighBitType.LiteralSequence, combinedSize, lastTag.getPosition());
                            compressionSequence.set(numTags - 1, lastTag);

                            currPos++;
                            continue;
                        }
                    }

                    // if [literals][run of some value] where the run is at most
                    // 2 vals long, you can combine the short run into the lits
                    else {
                        int combinedSize = lastSize + length;
                        if (length <= 0x2 && combinedSize <= MAX_LITERALS) {
                            lastTag = new HighBitTag(HighBitType.LiteralSequence, combinedSize, lastTag.getPosition());
                            compressionSequence.set(numTags - 1, lastTag);

                            currPos += length;
                            continue;
                        }
                    }
                }

                else if (lastTag.getSize() <= 2 && length <= 2) {
                    int combinedSize = lastTag.getSize() + length;
                    if (combinedSize < MAX_LITERALS) {
                        lastTag = new HighBitTag(HighBitType.LiteralSequence, combinedSize, lastTag.getPosition());
                        compressionSequence.set(numTags - 1, lastTag);

                        currPos += length;
                        continue;
                    }
                }
            }

            HighBitTag lastValue = new HighBitTag(type, length, currPos);
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

        // keep copy of the starting value for totalCompSize to know whether
        // it's better to store all the values uncompressed
        int inputTotalCompSize = totalCompSize;

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

        // none of the game's tilemaps should trigger this, but it's possible to
        // feed a data block that when "compressed" takes more space than if you
        // just wrote the 0x380 values as-is (e.g. 0x38 blocks of 0x10 literals)
        if (totalCompSize - inputTotalCompSize > NUM_BYTES_FOR_ALL_BITPACKED_TWO_BIT_VALS) {
            String info = "NOTE: 0x%3X > 0x%3X, so better stored uncompressed";
            outputLog.write(String.format(info, totalCompSize - 1, NUM_BYTES_FOR_ALL_BITPACKED_TWO_BIT_VALS));
        }

        outputLog.flush();
        // outputLog.close();
    }

    // to be used if "compressing" a data block results in a larger block than
    // if you just bitpacked all the raw values together
    private static ArrayList<Integer> generateUncompressedHighBitsBlock() {
        return generateUncompressedBlockOfTwoBitValues(tilemapIdHighBits);
    }
    private static ArrayList<Integer> generateUncompressedBlockOfTwoBitValues(int data[]) {
        ArrayList<Integer> rawDataList = convertIntArrayToArrayList(data);
        int bitpackedDataArray[] = getRawTwoBitBufferBytesToWrite(rawDataList);
        return convertIntArrayToArrayList(bitpackedDataArray);
    }

    private static ArrayList<Integer> generateCompressedHighBitsBlock(ArrayList<HighBitTag> compressionSequence) {
        // don't know how much data the blocks will take when compressed
        ArrayList<Integer> compressedData = new ArrayList<>();
        int numHighBitBufferValuesWritten = 0;

        int highBitBufferBytes[] = getRawTwoBitBufferBytesToWrite(getHighBitValuesToWriteToBuffer(compressionSequence));
        int bufferByteListPos = 0;

        for (HighBitTag currentBlock : compressionSequence) {
            HighBitType type = currentBlock.getType();
            int position = currentBlock.getPosition();
            int size = currentBlock.getSize();

            int posToExpectToWriteBufferContents = nextWriteToTwoBitSetBuffer(numHighBitBufferValuesWritten);

            switch (type) {
                case RunOfZeroes: {
                    // 00nn nnnn (00-3F, with 3F as special case)
                    final int SPECIAL_CASE_BYTE = 0x3F;
                    if (size <= RUN_00_THRESHOLD_40) {
                        int encodedSize = size - REPEAT_CASE_MIN_SIZE;
                        compressedData.add(encodedSize);
                    }
                    else {
                        compressedData.add(SPECIAL_CASE_BYTE);
                        int encodedSize = size - (RUN_00_THRESHOLD_40 + 1);
                        compressedData.add(encodedSize);
                    }
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
                        int encodedSize = size - REPEAT_CASE_MIN_SIZE;

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
                    compressedData.add(highBitBufferBytes[bufferByteListPos]);
                    bufferByteListPos++;
                }
            }
        }
        return compressedData;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static enum PaletteXYType {
        RunOfZeroes(4),
        ReuseFromOneRowUpThenZeroes(3),
        ReuseFromOneRowUpAndRepeat(3),
        NewPaletteXYThenZeroes(2),
        RepeatNewPaletteXY(2),
        LiteralSequence(1);

        int priority;

        private PaletteXYType(int priority) {
            this.priority = priority;
        }

        public int getPriority() {
            return priority;
        }
    }

    private static class PaletteXYTag {
        private PaletteXYType type;
        private int size;
        private int position;

        public PaletteXYTag(PaletteXYType type, int size, int position) {
            this.type = type;
            this.size = size;
            this.position = position;
        }

        public int getSize() {
            return size;
        }

        public int getPosition() {
            return position;
        }

        public PaletteXYType getType() {
            return type;
        }

        public int getNumBytesToEncodeCase() {
            if (type == PaletteXYType.RunOfZeroes && size > RUN_00_THRESHOLD_40)
                return 2;
            return 1;
        }

        public int getNumValsToReadFromBuffer(boolean checkingPalettes) {
            int numValsToRead = 0;
            switch (type) {
                case LiteralSequence:
                    numValsToRead = size - 1;
                    break;
                case NewPaletteXYThenZeroes:
                    // convention: the new value is included in the size for the
                    // purposes of case comparison; leave out here since we only
                    // care about the size of the 00 run
                    // # 00 palettes >= 0x5, or # 00 X/Y flips >= 0x9
                    if (size - 1 > getThresholdFor00sAfterNewPaletteXyValue(checkingPalettes)) {
                        numValsToRead = 1;
                    }
                    break;
                case RepeatNewPaletteXY:
                    // # palettes >= 0x6, or # X/Y flips >= 0xA
                    if (size > getThresholdForRepeatNewPaletteXY(checkingPalettes)) {
                        numValsToRead = 1;
                    }
                    break;
                default:
                    break;
            }
            return numValsToRead;
        }
    }

    // ----------

    private static final int SIZE_LIMIT_REUSE_PALETTE_XY_CASES = 0x10;

    /* private static int getThresholdFor00sAfterNewPaletteXyValue(boolean checkingPalettes) {
        return checkingPalettes ? 0x4 : 0x8;
    }
    */
    private static int getSizeLimitFor00sAfterNewPaletteXyValue(boolean checkingPalettes) {
        // return checkingPalettes ? 0x14 : 0x18;
        return 0x10 + getThresholdFor00sAfterNewPaletteXyValue(checkingPalettes);
    }

    /* private static int getThresholdForRepeatNewPaletteXY(boolean checkingPalettes) {
        return checkingPalettes ? 0x5 : 0x9;
    }
    */
    private static int getSizeLimitForRepeatNewPaletteXyValue(boolean checkingPalettes) {
        // return checkingPalettes ? 0x15 : 0x19;
        return 0x10 + getThresholdForRepeatNewPaletteXY(checkingPalettes);
    }

    // ----------

    private static int checkForRunOfZeroes(int data[], int currPos) {
        if (data[currPos] != 0) {
            return CASE_NOT_VALID;
        }
        // return getRunLengthAtPosition(data, currPos, TAG_SIZE_LIMIT_100);
        return getRunLengthAtPosition(data, currPos, RUN_00_SIZE_LIMIT_140);
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
            return 0;
        }

        final int MIN_SIZE = 2;
        int maxSize = getSizeLimitForRepeatNewPaletteXyValue(checkingPalettes);

        // get the actual run length and limit it later
        // int size = getRunLengthAtPosition(data, currPos, maxSize);
        int fullLength = getRunLengthAtPosition(data, currPos, NUM_TILEMAP_ENTRIES);
        int size = Integer.min(fullLength, maxSize);
        if (size < MIN_SIZE) {
            size = CASE_NOT_VALID;
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
                size = 0;
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
            length <= RUN_00_THRESHOLD_40 + sizeThreshold;

        // see if length requires 2nd run of 00 bytes anyway, encoded in 2 bytes
        // for palettes,  if 0x54 <= length <= 0x104, two options for encoding:
        // 0x4 + (0x50 <= N <= 0x100), or 0x14 + (0x40 <= N <= 0xF0)
        // for X/Y flips, if 0x58 <= length <= 0x108, symmetric options:
        // 0x8 + (0x50 <= N <= 0x100), or 0x18 + (0x40 <= N <= 0xF0)
        boolean needTwoByte2ndRunAnyway =
            length > RUN_00_THRESHOLD_40 + maxSize &&
            // length <= TAG_SIZE_LIMIT_100 + sizeThreshold;
            length <= RUN_00_SIZE_LIMIT_140 + sizeThreshold;

        // if palette run >= 0x115 or X/Y flip run >= 0x119, you need three runs
        // anyway, so limit the first run
        // boolean needAtLeastThreeRunsAnyway = length > TAG_SIZE_LIMIT_100 + maxSize;
        boolean needAtLeastThreeRunsAnyway = length > RUN_00_SIZE_LIMIT_140 + maxSize;

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
            int numTags = compressionSequence.size();
            if (numTags > 0) {
                PaletteXYTag lastTag = compressionSequence.get(numTags - 1);
                PaletteXYType lastType = lastTag.getType();
                int lastSize = lastTag.getSize();
                int lastPos = lastTag.getPosition();

                // if last iteration was for a literal sequence, and we have a
                // literal now, you can combine the lit into the sequence
                if (lastType == PaletteXYType.LiteralSequence &&
                    bestType == PaletteXYType.LiteralSequence) {
                    int combinedSize = lastSize + 1;

                    if (combinedSize <= MAX_LITERALS) {
                        lastTag = new PaletteXYTag(lastType, combinedSize, lastPos);
                        compressionSequence.set(numTags - 1, lastTag);
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

                    // int trueLength = getRunLengthAtPosition(data, currPos + 1, TAG_SIZE_LIMIT_100);
                    int trueLength = getRunLengthAtPosition(data, currPos + 1, RUN_00_SIZE_LIMIT_140);
                    if (trueLength > sizeLimit || maxSize <= 2) {
                        int combinedSize = lastSize + 1;
                        if (combinedSize <= MAX_LITERALS) {
                            lastTag = new PaletteXYTag(lastType, combinedSize, lastPos);
                            compressionSequence.set(numTags - 1, lastTag);
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
                        lastTag = new PaletteXYTag(lastType, combinedSize, lastPos);
                        compressionSequence.set(numTags - 1, lastTag);
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
                        lastTag = new PaletteXYTag(PaletteXYType.LiteralSequence, combinedSize, lastPos);
                        compressionSequence.set(numTags - 1, lastTag);
                        currPos += maxSize;
                        continue;
                    }
                }
            }

            PaletteXYTag compressionInfo = new PaletteXYTag(bestType, maxSize, currPos);
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

        // keep copy of the starting value for totalCompSize to know whether
        // it's better to store all the values uncompressed
        int inputTotalCompSize = totalCompSize;

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

        // none of the game's tilemaps should trigger this, but it's possible to
        // feed a data block that when "compressed" takes more space than if you
        // just wrote the 0x380 values as-is (e.g. 0x38 blocks of 0x10 literals)
        int uncompSize = loggingPalettes ?
            NUM_BYTES_FOR_ALL_BITPACKED_THREE_BIT_VALS :
            NUM_BYTES_FOR_ALL_BITPACKED_TWO_BIT_VALS;
        if (totalCompSize - inputTotalCompSize > uncompSize) {
            String info = "NOTE: 0x%3X > 0x%3X, so better stored uncompressed";
            outputLog.write(String.format(info, totalCompSize - 1, uncompSize));
        }

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

        ArrayList<PaletteXYTag> newSequence = null;
        if (checkingPalettes && numValuesInLastBuffer >= 1 && numValuesInLastBuffer <= 4) {
            // System.out.printf("%s: 0x%2X palette buffer vals (%d in last)\n", inputFilename, totalBufferVals, numValuesInLastBuffer);
            newSequence = reducePaletteBufferValues(compressionSequence, numValuesInLastBuffer);
            return newSequence;
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
                PaletteXYTag run = new PaletteXYTag(type, 2, pos);
                PaletteXYTag lits = new PaletteXYTag(PaletteXYType.LiteralSequence, size - 2, pos + 2);

                newCompression.add(run);
                numExtraValues -= 2;
                numExtraTypeBytesUsed++;

                // a group of literals can possibly have runs of 2 on both ends
                if (runOfTwoAtEnd && numExtraValues > 0) {
                    lits = new PaletteXYTag(PaletteXYType.LiteralSequence, size - 4, pos + 2);

                    PaletteXYType type2 = tilemapPalettes[pos + size - 2] == 0 ?
                        PaletteXYType.RunOfZeroes :
                        PaletteXYType.RepeatNewPaletteXY;
                    PaletteXYTag run2 = new PaletteXYTag(type2, 2, pos + size - 2);

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
                PaletteXYTag lits = new PaletteXYTag(PaletteXYType.LiteralSequence, size - 2, pos);
                PaletteXYTag run = new PaletteXYTag(type, 2, pos + size - 2);

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
            PaletteXYTag run1 = new PaletteXYTag(PaletteXYType.RepeatNewPaletteXY, REPEAT_THRESHOLD_5, pos);
            newCompression.set(i, run1);

            // if # extra tags is 2, add another tag of length 5
            for (int tagNum = 1; tagNum < extraTags; tagNum++) {
                int runPos = pos + REPEAT_THRESHOLD_5 * tagNum;
                PaletteXYTag run = new PaletteXYTag(runType, REPEAT_THRESHOLD_5, runPos);
                newCompression.add(i + tagNum, run);
            }

            // add the last tag with the rest of the run; if full length is 6 or
            // B (5*1 + 1, 5*2 + 1), then the last one must be added as a lit,
            // which must be its own tag if followed by a lit sequence
            int lastRunSize = size % REPEAT_THRESHOLD_5;
            int lastRunPos = pos + REPEAT_THRESHOLD_5 * extraTags;
            PaletteXYType lastRunType = lastRunSize >= 2 ? PaletteXYType.RepeatNewPaletteXY : PaletteXYType.LiteralSequence;
            PaletteXYTag lastRun = new PaletteXYTag(lastRunType, lastRunSize, lastRunPos);
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
                    PaletteXYTag lits1 = new PaletteXYTag(PaletteXYType.LiteralSequence, offset, pos);
                    PaletteXYTag run = new PaletteXYTag(type, 2, pos + offset);
                    PaletteXYTag lits2 = new PaletteXYTag(PaletteXYType.LiteralSequence, size - offset - 2, pos + offset + 2);

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
        // first, calculate the size of the list:
        // # buffers to write = # palette values / 8
        int numBuffersToWrite = bufferValues.size() / NUM_THREE_BIT_VALS_IN_BUFFER;

        // total # bytes = # buffers * 3, because each byte holds either low/mid/hi bits
        int rawBytes[] = new int[numBuffersToWrite * NUM_BYTES_IN_PALETTE_BUFFER];
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

            rawBytes[bufferNum*NUM_BYTES_IN_PALETTE_BUFFER + 0] = lowBits;
            rawBytes[bufferNum*NUM_BYTES_IN_PALETTE_BUFFER + 1] = midBits;
            rawBytes[bufferNum*NUM_BYTES_IN_PALETTE_BUFFER + 2] = hiBits;

            // debugLine += String.format("-> [%02X %02X %02X]\n", lowBits, midBits, hiBits);
            // System.out.println(debugLine);
        }

        return rawBytes;
    }

    // to be used if "compressing" a data block results in a larger block than
    // if you just bitpacked all the raw values together
    private static ArrayList<Integer> generateUncompressedPaletteBlock() {
        ArrayList<Integer> rawDataList = convertIntArrayToArrayList(tilemapPalettes);
        int bitpackedDataArray[] = getRawPaletteBufferBytesToWrite(rawDataList);
        return convertIntArrayToArrayList(bitpackedDataArray);
    }
    private static ArrayList<Integer> generateUncompressedXYBlock() {
        return generateUncompressedBlockOfTwoBitValues(tilemapXYFlips);
    }

    private static ArrayList<Integer> generateCompressedPaletteXYBlock(ArrayList<PaletteXYTag> compressionSequence, boolean checkingPalettes) {
        ArrayList<Integer> compressedData = new ArrayList<>();

        ArrayList<Integer> paletteXYBufferValues = getPaletteXYValuesToWriteToBuffer(compressionSequence, checkingPalettes);
        int rawBufferBytes[] = checkingPalettes ?
            getRawPaletteBufferBytesToWrite(paletteXYBufferValues) :
            getRawTwoBitBufferBytesToWrite(paletteXYBufferValues);

        // use the correct set of tilemap data
        int dataSet[] = checkingPalettes ? tilemapPalettes : tilemapXYFlips;

        int bufferByteListPos = 0;
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

                    if (size <= RUN_00_THRESHOLD_40) {
                        int encodedSize = size - REPEAT_CASE_MIN_SIZE;
                        compressedData.add(encodedSize);
                    }
                    else {
                        int encodedSize = size - (RUN_00_THRESHOLD_40 + 1);
                        compressedData.add(SPECIAL_CASE_BYTE);
                        compressedData.add(encodedSize);
                    }

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
                        int shiftAmount = checkingPalettes ? 2 : 3;
                        int value = dataSet[position];
                        int encodedSize = numZeroes - 1;

                        int infoByte = BITMASK_FIT | (value << shiftAmount) | encodedSize;
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
                    int threshold = getThresholdForRepeatNewPaletteXY(checkingPalettes);
                    // final int SIZE_THRESHOLD = checkingPalettes ? 0x5 : 0x9;

                    if (size <= threshold) {
                        int shiftAmount = checkingPalettes ? 2 : 3;

                        int value = dataSet[position];
                        int encodedSize = size - REPEAT_CASE_MIN_SIZE;

                        int infoByte = BITMASK_FIT | (value << shiftAmount) | encodedSize;
                        compressedData.add(infoByte);
                    }
                    else {
                        // (size - 6) for palettes, (size - 0xA) for X/Y flip
                        int encodedSize = size - (threshold + 1);

                        int infoByte = BITMASK_NOT_FIT | encodedSize;
                        compressedData.add(infoByte);
                    }
                    break;
                }
                case LiteralSequence: {
                    // palettes for 0x1 <= size <= 0x 8: 11pp pnnn (3 n bits)
                    // X/Y flip for 0x1 <= size <= 0x10: 11yx nnnn (4 n bits)
                    final int BITMASK = 0xC0;
                    int shiftAmount = checkingPalettes ? 3 : 4;

                    int encodedSize = size - 1;
                    int firstValue = dataSet[position];

                    int infoByte = BITMASK | (firstValue << shiftAmount) | encodedSize;
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
                    int bytePosition = bufferByteListPos * 3;
                    bufferByteListPos++;

                    compressedData.add(rawBufferBytes[bytePosition + 0]);
                    compressedData.add(rawBufferBytes[bytePosition + 1]);
                    compressedData.add(rawBufferBytes[bytePosition + 2]);
                }

                else {
                    int difference = numBufferValsWritten - nextExpectedDataWritePos;
                    int numBytesToWrite = 1 + difference / NUM_TWO_BIT_VALS_IN_BUFFER;

                    for (int i = 0; i < numBytesToWrite; i++) {
                        compressedData.add(rawBufferBytes[bufferByteListPos]);
                        bufferByteListPos++;
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
        // recommendation: run main() just once with below line not commented
        // out, then comment it out to save time on subsequent executions
        // outputSeparatedEntryComponentsToFiles(rawTilemapEntries, inputFilename);

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
            int totalCompSize = ONE_BYTE_FOR_COMP_BLOCK_FLAGS + lowBytesCompSize;

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

        ArrayList<Integer> dataBlock;
        dataBlock = useCompressedLowBytes ? lowBytesCompressedBlock : generateUncompressedLowBytesBlock();
        writeIntegerArrayListToFile(dataBlock, outputFile);

        dataBlock = useCompressedHighBits ? highBitsCompressedBlock : generateUncompressedHighBitsBlock();
        writeIntegerArrayListToFile(dataBlock, outputFile);

        dataBlock = useCompressedPalettes ? paletteCompressedBlock : generateUncompressedPaletteBlock();
        writeIntegerArrayListToFile(dataBlock, outputFile);

        dataBlock = useCompressedXYFlips ? xyFlipCompressedBlock : generateUncompressedXYBlock();
        writeIntegerArrayListToFile(dataBlock, outputFile);


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
