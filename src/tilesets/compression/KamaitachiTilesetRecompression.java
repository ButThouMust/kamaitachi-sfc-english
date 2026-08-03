package tilesets.compression;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.PriorityQueue;

import static tilesets.constants.TileCompConstants.*;
import static tilesets.tag_tile.TileBitplaneSubroutinesTag.FORCE_THREE_BYTES;

import tilesets.constants.BitplaneCombiner;
import tilesets.constants.TileCompConstants;
import tilesets.tag_tile.*;
import tilesets.tag_bitplane.*;

public class KamaitachiTilesetRecompression {

    private static int gfxData[];
    private static int arrayOfTiles[][];
    private static int arrayOfBitplanes[][][];

    private static FileOutputStream outputFile;
    private static BufferedWriter log;

    private static final boolean RESTRICT_00_FF = true;
    private static final String COMPRESSED_FILE_PREFIX = "RECOMPRESSED ";
    private static final String OUTPUT_FOLDER = "recompressed tilesets";

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void getInputDataAsRawArray(String filepath) throws IOException {
        File f = new File(filepath);
        long fileSize = f.length();
        if (fileSize % TILE_SIZE != 0 || fileSize > MAX_TILESET_SIZE) {
            System.out.println("Invalid file size for \"" + filepath + "\"");
            gfxData = null;
            return;
        }

        gfxData = new int[(int) fileSize];
        FileInputStream stream = new FileInputStream(filepath);
        for (int i = 0; i < gfxData.length; i++) {
            gfxData[i] = stream.read() & 0xFF;
        }
        stream.close();
    }

    private static void splitInputDataIntoTilesAndBitplanes() {
        if (gfxData == null) return;

        int numTiles = gfxData.length / TILE_SIZE;
        arrayOfTiles = new int[numTiles][TILE_SIZE];
        arrayOfBitplanes = new int[numTiles][BIT_DEPTH][NUM_ROWS_PER_TILE];
        // byte: 00 01 02 03 04 05 06 07 ; 08 09 0a 0b 0c 0d 0e 0f
        // row:   0  0  1  1  2  2  3  3    4  4  5  5  6  6  7  7
        // bp:    0  1  0  1  0  1  0  1 ;  0  1  0  1  0  1  0  1

        // byte: 10 11 12 13 14 15 16 17 ; 18 19 1a 1b 1c 1d 1e 1f
        // row:   0  0  1  1  2  2  3  3    4  4  5  5  6  6  7  7
        // bp:    2  3  2  3  2  3  2  3 ;  2  3  2  3  2  3  2  3

        for (int tile = 0; tile < arrayOfTiles.length; tile++) {
            int tilePos = tile * TILE_SIZE;
            for (int b = 0; b < TILE_SIZE; b++) {
                // bp = parity of position in tile, plus 2 if pos >= 0x10
                int bp = ((b & 0x10) >> 3) + (b & 0x1);
                int row = (b & 0xF) >> 1;
                arrayOfTiles[tile][b] = gfxData[tilePos + b];
                arrayOfBitplanes[tile][bp][row] = gfxData[tilePos + b];
            }
        }
    }

    // run this once on all your files for easier debugging when comparing the
    // uncompressed data in a hex editor against your compression logs
    // put all 8 rows of a bitplane together, instead of interleaving them like in SNES standard format
    private static void outputUncompressedFileWithBitplanesUninterleaved(String inputFilepath) throws IOException {
        if (gfxData == null) return;

        int slashIndex = inputFilepath.lastIndexOf('/');
        String folderPath = inputFilepath.substring(0, slashIndex);
        String inputFilename = inputFilepath.substring(slashIndex);
        int periodIndex = inputFilename.lastIndexOf('.');
        String outputFilename = inputFilename.substring(0, periodIndex) + " - uninterleaved.4bpp";
        String outputFilepath = folderPath + outputFilename;

        FileOutputStream outputFile = new FileOutputStream(outputFilepath);
        for (int tile = 0; tile < arrayOfBitplanes.length; tile++) {
            // for (int bp = 0; bp < arrayOfBitplanes[tile].length; bp++) {
            for (int bp = 0; bp < BIT_DEPTH; bp++) {
                // for (int row = 0; row < arrayOfBitplanes[tile][bp].length; row++) {
                for (int row = 0; row < NUM_ROWS_PER_TILE; row++) {
                    outputFile.write(arrayOfBitplanes[tile][bp][row]);
                }
            }
        }
        outputFile.flush();
        outputFile.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    // use cases for this method:
    // - size of the HashMap's keyset = # unique bytes in bitplane
    // - check how many 00s or FFs are in the bitplane
    @SuppressWarnings("unused")
    private static HashMap<Integer,Integer> getHistogramOfBytesInBitplane(int tileNum, int bp) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES ||
            bp < 0 || bp >= BIT_DEPTH) return null;

        int bpData[] = arrayOfBitplanes[tileNum][bp];
        return getHistogramOfBytesInBitplane(bpData);
    }
    private static HashMap<Integer,Integer> getHistogramOfBytesInBitplane(int bpData[]) {
        // get list of counts of all the unique bytes in a bitplane, e.g. 5 of 00
        if (bpData.length != NUM_ROWS_PER_TILE) {
            System.out.println("WARNING: attempted to get histogram for bitplane that was not size 8");
            return null;
        }

        HashMap<Integer,Integer> histogram = new HashMap<>();
        for (int i = 0; i < bpData.length; i++) {
            int data = bpData[i];
            int count = histogram.getOrDefault(data, 0);
            histogram.put(data, count + 1);
        }
        return histogram;
    }

    private static ArrayList<Integer> getModesOfHistogram(HashMap<Integer,Integer> hist, boolean restrict00FF) {
        // first, find the largest count in the histogram
        // optionally choose to ignore the counts for 00 or FF
        int bestCount = 0;
        for (int byteValue : hist.keySet()) {
            if (restrict00FF && (byteValue == 0x00 || byteValue == 0xFF))
                continue;

            int repeatCount = hist.get(byteValue);
            if (repeatCount > bestCount) {
                bestCount = repeatCount;
            }
        }

        // next, find the elements that have the best count
        ArrayList<Integer> modes = new ArrayList<>();
        for (int byteValue : hist.keySet()) {
            int repeatCount = hist.get(byteValue);
            if (repeatCount == bestCount) {
                modes.add(byteValue);
            }
        }
        return modes;
    }

    private static boolean USE_00 = true;
    private static boolean USE_FF = false;
    @SuppressWarnings("unused")
    private static BitplaneCompressionTag checkForBitplaneFilledWith00orFF(int tileNum, int bp, boolean use00) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES ||
            bp < 0 || bp >= BIT_DEPTH)
            return BitplaneCaseNotSupportedTag.getInstance();

        int bpData[] = arrayOfBitplanes[tileNum][bp];
        return checkForBitplaneFilledWith00orFF(bpData, use00);
    }
    private static BitplaneCompressionTag checkForBitplaneFilledWith00orFF(int bpData[], boolean use00) {
        HashMap<Integer,Integer> hist = getHistogramOfBytesInBitplane(bpData);
        return checkForBitplaneFilledWith00orFF(bpData, hist, use00);
    }
    private static BitplaneCompressionTag checkForBitplaneFilledWith00orFF(int bpData[], HashMap<Integer,Integer> hist, boolean use00) {
        int value = use00 ? 0x00 : 0xFF;
        int count = hist.getOrDefault(value, 0);
        BitplaneCompressionTag output = BitplaneCaseNotSupportedTag.getInstance();
        if (count > 0) {
            return new BitplaneFillWithByte(bpData, value);
        }
        return output;
    }

    // note: this will return the bytes themselves as opposed to their frequencies like for 00/FF
    @SuppressWarnings("unused")
    private static ArrayList<Integer> checkForBitplaneFilledWithArbitraryByte(int tileNum, int bp) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES ||
            bp < 0 || bp >= BIT_DEPTH)
            return new ArrayList<>();

        int bpData[] = arrayOfBitplanes[tileNum][bp];
        return checkForBitplaneFilledWithArbitraryByte(bpData);
    }
    private static ArrayList<Integer> checkForBitplaneFilledWithArbitraryByte(int bpData[]) {
        HashMap<Integer,Integer> hist = getHistogramOfBytesInBitplane(bpData);
        return checkForBitplaneFilledWithArbitraryByte(hist);
    }
    private static ArrayList<Integer> checkForBitplaneFilledWithArbitraryByte(HashMap<Integer,Integer> hist) {
        ArrayList<Integer> modes = getModesOfHistogram(hist, RESTRICT_00_FF);
        if (modes.size() == 1) return modes;

        // if there are multiple modes for the bitplane, then each one can only
        // appear up to 4 times; assume that this case will not encode a 00 or FF
        ArrayList<Integer> output = new ArrayList<>();
        for (int value : modes) {
            if (value != 0x00 && value != 0xFF) {
                output.add(value);
            }
        }
        return output;
    }

    @SuppressWarnings("unused")
    private static BitplaneCompressionTag checkEncodingAsRleGroups(int tileNum, int bp) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES ||
            bp < 0 || bp >= BIT_DEPTH)
            return BitplaneCaseNotSupportedTag.getInstance();

        int bpData[] = arrayOfBitplanes[tileNum][bp];
        return checkEncodingAsRleGroups(bpData);
    }
    // can reuse this for bitmask combination
    public static BitplaneCompressionTag checkEncodingAsRleGroups(int bpData[]) {
        int indices[] = new int[bpData.length];

        // note: if bpData[0] is 0x00, you do not need to encode the value
        int currentValue = bpData[0];
        int numGroups = 0;
        if (currentValue != 0x00) {
            numGroups = 1;
            indices[0] = 0;
        }

        for (int i = 1; i < bpData.length; i++) {
            if (currentValue != bpData[i]) {
                indices[numGroups] = i;
                numGroups++;
                currentValue = bpData[i];
            }
        }

        // if 7+ values to encode, may as well just do the uncompressed case
        if (numGroups + 1 < NUM_ROWS_PER_TILE) {
            int output[] = new int[numGroups];
            for (int i = 0; i < output.length; i++) {
                output[i] = indices[i];
            }
            return new BitplaneFillFromRLE(bpData, output);
        }
        return BitplaneCaseNotSupportedTag.getInstance();
    }

    @SuppressWarnings("unused")
    private static BitplaneCompressionTag checkWhatBytesToUseForAlternatingTwoBytes(int tileNum, int bp) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES ||
            bp < 0 || bp >= BIT_DEPTH)
            return BitplaneCaseNotSupportedTag.getInstance();

        int bpData[] = arrayOfBitplanes[tileNum][bp];
        return checkWhatBytesToUseForAlternatingTwoBytes(bpData);
    }
    private static BitplaneCompressionTag checkWhatBytesToUseForAlternatingTwoBytes(int bpData[]) {
        if (bpData.length != NUM_ROWS_PER_TILE)
            return BitplaneCaseNotSupportedTag.getInstance();

        // this case with spot changes only pops up in JP game once (gfx ID 08)
        // bp1 @ 0x15C0 has data [ed fb ff fd ff fb f7 fb], which got compressed
        // using data [FF FB]:   [-- fb ff -- ff fb -- fb]

        // since this case allows spot changes, my best idea for a solution is
        // to determine the most common value in each of the even/odd indices;
        // analyze cases for # occurrences of the mode(s):
        // 4: perfect:  list of # occurrences = [4]
        // 3: good:     list = [3 1]
        // 2: adequate: list either [2 1 1] (pick it) or [2 2] (pick either)
        // 1: bad fit:  list = [1 1 1 1] (pick any)
        HashMap<Integer,Integer> evenHist = new HashMap<>();
        HashMap<Integer,Integer> oddHist = new HashMap<>();
        for (int i = 0; i < NUM_ROWS_PER_TILE / 2; i++) {
            int evenData = bpData[i*2];
            int evenCount = evenHist.getOrDefault(evenData, 0);
            evenHist.put(evenData, evenCount + 1);

            int oddData = bpData[i*2 + 1];
            int oddCount = oddHist.getOrDefault(oddData, 0);
            oddHist.put(oddData, oddCount + 1);
        }

        ArrayList<Integer> modesForEvens = getModesOfHistogram(evenHist, !RESTRICT_00_FF);
        ArrayList<Integer> modesForOdds  = getModesOfHistogram(oddHist,  !RESTRICT_00_FF);
        int modeForEvens = modesForEvens.get(0);
        int modeForOdds = modesForOdds.get(0);

        // if (modeForEvens == MODE_NOT_AVAILABLE || modeForOdds == MODE_NOT_AVAILABLE)
            // return BitplaneCaseNotSupportedTag.getInstance();

        BitplaneCompressionTag bpTwoBytes = new BitplaneFillWithTwoByteSeq(bpData, modeForEvens, modeForOdds);
        if (bpTwoBytes.getSizeWhenEncoded() >= NUM_ROWS_PER_TILE) {
            bpTwoBytes = BitplaneCaseNotSupportedTag.getInstance();
        }
        return bpTwoBytes;
    }

    // this compression method requires an exact fit
    @SuppressWarnings("unused")
    private static BitplaneCompressionTag checkForUsingFourByteSequenceTwice(int tileNum, int bp) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES ||
            bp < 0 || bp >= BIT_DEPTH)
            return BitplaneCaseNotSupportedTag.getInstance();

        int bpData[] = arrayOfBitplanes[tileNum][bp];
        return checkForUsingFourByteSequenceTwice(bpData);
    }
    private static BitplaneCompressionTag checkForUsingFourByteSequenceTwice(int bpData[]) {
        if (bpData.length != NUM_ROWS_PER_TILE)
            return BitplaneCaseNotSupportedTag.getInstance();

        if (bpData[0] == bpData[4] && bpData[1] == bpData[5] &&
            bpData[2] == bpData[6] && bpData[3] == bpData[7]) {
            return new BitplaneFillWithFourByteSeq(bpData);
        }
        return BitplaneCaseNotSupportedTag.getInstance();
    }

    // this compression method requires an exact fit
    @SuppressWarnings("unused")
    private static BitplaneCompressionTag checkForBitplaneThatUsesThreeOrFourUniqueBytes(int tileNum, int bp) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES ||
            bp < 0 || bp >= BIT_DEPTH)
            return BitplaneCaseNotSupportedTag.getInstance();

        int bpData[] = arrayOfBitplanes[tileNum][bp];
        return checkForBitplaneThatUsesThreeOrFourUniqueBytes(bpData);
    }
    // can reuse this for bitmask combination, but need this strange setup with
    // passing in both the bitplane data itself and the histogram to allow that
    public static BitplaneCompressionTag checkForBitplaneThatUsesThreeOrFourUniqueBytes(int bpData[]) {
        return checkForBitplaneThatUsesThreeOrFourUniqueBytes(bpData, getHistogramOfBytesInBitplane(bpData));
    }
    private static BitplaneCompressionTag checkForBitplaneThatUsesThreeOrFourUniqueBytes(int bpData[], HashMap<Integer,Integer> histogram) {
        // TODO would 2 unique bytes be acceptable here?
        int numUniqueBytes = histogram.keySet().size();
        if (numUniqueBytes == 3 || numUniqueBytes == 4) {
            return new BitplaneConstructFromUniqueBytes(bpData);
        }
        return BitplaneCaseNotSupportedTag.getInstance();
    }

    @SuppressWarnings("unused")
    private static HashMap<Integer,Integer> getHistogramOfNibblesInBitplane(int tileNum, int bp) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES ||
            bp < 0 || bp >= BIT_DEPTH) return null;

        int bpData[] = arrayOfBitplanes[tileNum][bp];
        return getHistogramOfNibblesInBitplane(bpData);
    }
    private static HashMap<Integer,Integer> getHistogramOfNibblesInBitplane(int bpData[]) {
        // get list of counts of all the unique NIBBLES in a bitplane
        if (bpData.length != NUM_ROWS_PER_TILE) return null;

        HashMap<Integer,Integer> histogram = new HashMap<>();
        for (int i = 0; i < bpData.length; i++) {
            int nibble1 = bpData[i] & 0xF;
            int count1 = histogram.getOrDefault(nibble1, 0);
            histogram.put(nibble1, count1 + 1);

            int nibble2 = bpData[i] >> 4;
            int count2 = histogram.getOrDefault(nibble2, 0);
            histogram.put(nibble2, count2 + 1);
        }
        return histogram;
    }

    // this compression method requires an exact fit
    @SuppressWarnings("unused")
    private static BitplaneCompressionTag checkForBitplaneThatUsesFourUniqueNibbles(int tileNum, int bp) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES ||
            bp < 0 || bp >= BIT_DEPTH)
            return BitplaneCaseNotSupportedTag.getInstance();

        int bpData[] = arrayOfBitplanes[tileNum][bp];
        return checkForBitplaneThatUsesFourUniqueNibbles(bpData);
    }
    // can reuse this for bitmask combination, similar to above
    public static BitplaneCompressionTag checkForBitplaneThatUsesFourUniqueNibbles(int bpData[]) {
        HashMap<Integer,Integer> histogram = getHistogramOfNibblesInBitplane(bpData);
        int numUniqueNibbles = histogram.keySet().size();
        if (numUniqueNibbles == 3 || numUniqueNibbles == 4) {
            // TODO would 3 unique nibbles be acceptable here?
            // note: 2 unique nibbles [X Y] -> 4 possible bytes [XX XY YX YY],
            // which you can do with the dedicated "4 unique bytes" case
            return new BitplaneConstructFromUniqueNibbles(bpData);
        }
        return BitplaneCaseNotSupportedTag.getInstance();
    }

    // this may take a long time to get a result that is adequate at best,
    // so best to leave as a last resort
    private static BitplaneCompressionTag checkForReusingBitplaneFromPrevTile(int currTileNum, int currBp) {
        if (currTileNum <= TILE_NUM_OF_EMPTY_TILE || currTileNum >= MAX_NUM_TILES ||
            currBp < 0 || currBp >= BIT_DEPTH) {
            return BitplaneCaseNotSupportedTag.getInstance();
        }

        int tileNumOfBestMatch = TILE_NUM_OF_EMPTY_TILE;
        int bpOfBestMatch = 0;
        int bestMatchSize = 0;
        boolean reverse = false;

        int bpData[] = arrayOfBitplanes[currTileNum][currBp];
        int revBpData[] = new int[NUM_ROWS_PER_TILE];
        for (int i = 0; i < revBpData.length; i++) {
            revBpData[i] = bpData[NUM_ROWS_PER_TILE - 1 - i];
        }

        // TODO better performance than an exhaustive search of all bitplanes
        for (int tile = 0; tile < currTileNum; tile++) {
            for (int bp = 0; bp < BIT_DEPTH; bp++) {
                int bpDataToCheck[] = arrayOfBitplanes[tile][bp];
                int forwardMatchSize = 0;
                int reverseMatchSize = 0;
                for (int i = 0; i < bpData.length; i++) {
                    if (bpData[i] == bpDataToCheck[i])    forwardMatchSize++;
                    if (revBpData[i] == bpDataToCheck[i]) reverseMatchSize++;
                }

                if (forwardMatchSize > bestMatchSize) {
                    bestMatchSize = forwardMatchSize;
                    tileNumOfBestMatch = tile;
                    bpOfBestMatch = bp;
                    reverse = false;
                }
                if (reverseMatchSize > bestMatchSize) {
                    bestMatchSize = reverseMatchSize;
                    tileNumOfBestMatch = tile;
                    bpOfBestMatch = bp;
                    reverse = true;
                }
                // if found a perfect match, no reason to keep checking
                if (bestMatchSize == NUM_ROWS_PER_TILE) break;
            }
            if (bestMatchSize == NUM_ROWS_PER_TILE) break;
        }

        int srcBitplaneData[] = arrayOfBitplanes[tileNumOfBestMatch][bpOfBestMatch];
        BitplaneCompressionTag output = new BitplaneReuseFromPrevTile(bpData,
            tileNumOfBestMatch, bpOfBestMatch, srcBitplaneData, reverse);
        if (output.getSizeWhenEncoded() >= NUM_ROWS_PER_TILE) {
            output = BitplaneCaseNotSupportedTag.getInstance();
        }
        return output;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int[] calculateDataByCombiningBitplanes(int tileNum, int subroutineIndex) {
        int result[] = calculateDataByCombiningBitplanes(tileNum,
            getBitplaneCombinationType(subroutineIndex),
            bitplaneCombinationTypeDoesBitwiseNOT(subroutineIndex));
        return result;
    }
    private static int[] calculateDataByCombiningBitplanes(int tileNum,
        BitplaneCombiner combine, boolean invertResult
    ) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES) return new int[0];

        int bpData[][] = arrayOfBitplanes[tileNum];
        int output[] = new int[NUM_ROWS_PER_TILE];
        int value = 0;
        for (int i = 0; i < output.length; i++) {
            switch (combine) {
                case COPY_0:  value = bpData[0][i]; break;
                case COPY_1:  value = bpData[1][i]; break;
                case COPY_2:  value = bpData[2][i]; break;

                case OR_01:   value = bpData[0][i] | bpData[1][i]; break;
                case OR_02:   value = bpData[0][i] | bpData[2][i]; break;
                case OR_12:   value = bpData[1][i] | bpData[2][i]; break;
                case OR_012:  value = bpData[0][i] | bpData[1][i] | bpData[2][i]; break;

                case AND_01:  value = bpData[0][i] & bpData[1][i]; break;
                case AND_02:  value = bpData[0][i] & bpData[2][i]; break;
                case AND_12:  value = bpData[1][i] & bpData[2][i]; break;
                case AND_012: value = bpData[0][i] & bpData[1][i] & bpData[2][i]; break;

                case XOR_01:  value = bpData[0][i] ^ bpData[1][i]; break;
                case XOR_02:  value = bpData[0][i] ^ bpData[2][i]; break;
                case XOR_12:  value = bpData[1][i] ^ bpData[2][i]; break;
            }

            if (invertResult) value = value ^ 0xFF;
            output[i] = value;
        }
        return output;
    }

    private static BitplaneCompressionTag getBestWayToCombineBitplanes(int tileNum, int currBp) {
        // you cannot reuse bitplanes if you are getting data for bitplane 0
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES ||
            currBp <= 0 || currBp >= BIT_DEPTH)
            return BitplaneCaseNotSupportedTag.getInstance();

        int bestIndex = CASE_NOT_VALID;
        int bestMatchSize = 0;
        int bpData[] = arrayOfBitplanes[tileNum][currBp];
        int calculatedDataForBestMatch[] = {};
        for (int index = USE_BP0; index < MAX_SUB_ID_FOR_BP[currBp]; index += 2) {
            int matchSize = 0;
            int calculatedBpData[] = calculateDataByCombiningBitplanes(tileNum, index);
            for (int i = 0; i < bpData.length; i++) {
                matchSize += (bpData[i] == calculatedBpData[i]) ? 1 : 0;
            }

            if (calculatedDataForBestMatch.length == 0 || matchSize > bestMatchSize) {
                bestIndex = index;
                bestMatchSize = matchSize;
                calculatedDataForBestMatch = calculatedBpData;
            }
            if (bestMatchSize == NUM_ROWS_PER_TILE) break;
        }

        BitplaneCompressionTag output =
            new BitplaneCombineOtherBitplanes(bestIndex, bpData, calculatedDataForBestMatch);
        if (output.getSizeWhenEncoded() >= NUM_ROWS_PER_TILE) {
            output = BitplaneCaseNotSupportedTag.getInstance();
        }

        return output;
    }

    private static BitplaneCompressionTag getBestCompressionForBitplane(
        int tileNum, int currBp, boolean canRestrictBP3
    ) {
        boolean checkBp0 = canRestrictBP3 && (currBp == 0);

        int currBpData[] = arrayOfBitplanes[tileNum][currBp];
        HashMap<Integer,Integer> hist = getHistogramOfBytesInBitplane(currBpData);

        // adding options to this automatically moves the best one to the front
        PriorityQueue<BitplaneCompressionTag> bpOptionsQueue = new PriorityQueue<>();

        // list of options sorted by the absolute best case for encoded size:
        // 0: fill with 00/FF, combine previous bitplanes
        // 1: fill with value
        // 2: RLE starting with 00 run, then run of XX
        //    "repeat two byte" sequence
        //    reuse bitplane from previous tile (very time-intensive)
        //    *any of the 0 byte cases, but off by 1 byte
        // 3: RLE that requires encoding two bytes for the groups
        //    *any of the 0 byte cases, but off by 2 bytes
        //    *fill with value, but off by 1 byte
        // 4: "repeat four byte" sequence
        // 5: construct from 3 unique bytes
        // 6: construct from 4 unique bytes, construct from 4 unique nibbles
        // 8: uncompressed data

        // caveat: if BP3 is all 00/FF, four options for BP0 would effectively
        // require one fewer byte to encode thanks to encoding indices in 2 bytes
        // 1*: all 00 or all FF, except for one byte out
        // 7*: uncompressed data
        // N*: RLE with N byte groups to encode

        // check for filling with 00 or FF; if either is a perfect match,
        // no need to check the other cases
        BitplaneCompressionTag bpFill00 = checkForBitplaneFilledWith00orFF(currBpData, hist, USE_00);
        int bpFill00Size = bpFill00.getSizeWhenEncoded();
        if (bpFill00Size == 0) {
            // logBestBitplaneOption(bp, bpFill00);
            return bpFill00;
        }
        BitplaneCompressionTag bpFillFF = checkForBitplaneFilledWith00orFF(currBpData, hist, USE_FF);
        int bpFillFFSize = bpFillFF.getSizeWhenEncoded();
        if (bpFillFFSize == 0) {
            // logBestBitplaneOption(bp, bpFillFF);
            return bpFillFF;
        }

        // it's possible for previous BPs to perfectly align to let you
        // encode the current BP with 0 bytes, so give priority over others
        BitplaneCompressionTag bpCombine = getBestWayToCombineBitplanes(tileNum, currBp);
        if (bpCombine.getSizeWhenEncoded() == 0) {
            // logBestBitplaneOption(bp, bpCombine);
            return bpCombine;
        }

        // the above three cases either take 0 bytes to encode (perfect match)
        // or 2 bytes to encode (need one spot change for lone unmatching byte);
        // however, if BP0 is all 00 or all FF minus one byte when BP3 is all 00
        // or all FF, you can effectively encode BP0 with just 1 byte
        if (checkBp0 && bpFill00Size == 2) {
            return bpFill00;
        }
        if (checkBp0 && bpFillFFSize == 2) {
            return bpFillFF;
        }

        bpOptionsQueue.add(bpFill00);
        bpOptionsQueue.add(bpFillFF);
        bpOptionsQueue.add(bpCombine);

        // -----------------------------------------------------------------

        // check for filling with some other byte; in the case of multiple
        // modes in the distribution, we only need one of them here
        ArrayList<Integer> modes = checkForBitplaneFilledWithArbitraryByte(hist);
        BitplaneCompressionTag bpFillArbitrary = BitplaneCaseNotSupportedTag.getInstance();
        if (modes.size() > 0) { // make sure that BP doesn't only use 00 or FF
            int mode = modes.get(0);
            // if any byte in the bitplane appears at most once, it means all 8
            // bytes are unique, so this case won't work
            if (hist.get(mode) > 1) {
                bpFillArbitrary = new BitplaneFillWithByte(currBpData, mode);
            }
        }
        // if the arbitrary byte option is a perfect match, this only requires 1
        // byte to encode, which would be the best possible outcome now
        if (bpFillArbitrary.getSizeWhenEncoded() == 1) {
            return bpFillArbitrary;
        }
        bpOptionsQueue.add(bpFillArbitrary);

        // RLE can take as little as 2 bytes to encode (flags byte + single data
        // byte), and effectively 1 byte (if for BP0 when BP3 is all 00/FF)
        BitplaneCompressionTag bpRle = checkEncodingAsRleGroups(currBpData);
        if (bpRle.getSizeWhenEncoded() <= 2) {
            // logBestBitplaneOption(bp, bpRle);
            return bpRle;
        }
        bpOptionsQueue.add(bpRle);

        // if best option at this point requires 2 bytes to encode, no other
        // option can possibly do better
        BitplaneCompressionTag bestOptionSoFar = bpOptionsQueue.peek();
        if (bestOptionSoFar.getSizeWhenEncoded() <= 2) {
            // logBestBitplaneOption(bp, bestOptionSoFar);
            return bestOptionSoFar;
        }

        // -----------------------------------------------------------------

        BitplaneCompressionTag bpTwoBytes = checkWhatBytesToUseForAlternatingTwoBytes(currBpData);
        if (bpTwoBytes.getSizeWhenEncoded() <= 2) {
            // logBestBitplaneOption(bp, bpTwoBytes);
            return bpTwoBytes;
        }
        bpOptionsQueue.add(bpTwoBytes);

        // -----------------------------------------------------------------
        bestOptionSoFar = bpOptionsQueue.peek();
        if (bestOptionSoFar.getSizeWhenEncoded() > 4) {
            BitplaneCompressionTag bpFourBytesTwice = checkForUsingFourByteSequenceTwice(currBpData);
            bpOptionsQueue.add(bpFourBytesTwice);
        }

        bestOptionSoFar = bpOptionsQueue.peek();
        if (bestOptionSoFar.getSizeWhenEncoded() > 5) {
            BitplaneCompressionTag bpUniqueBytes = checkForBitplaneThatUsesThreeOrFourUniqueBytes(currBpData, hist);
            bpOptionsQueue.add(bpUniqueBytes);
        }

        bestOptionSoFar = bpOptionsQueue.peek();
        if (bestOptionSoFar.getSizeWhenEncoded() > 6) {
            BitplaneCompressionTag bpUniqueNibbles = checkForBitplaneThatUsesFourUniqueNibbles(currBpData);
            bpOptionsQueue.add(bpUniqueNibbles);
        }

        // this can burn a lot of CPU time for only an adequate result, but
        // also can potentially require only 2 bytes to encode if there is a
        // perfect match; in my opinion, this is the big limiting factor
        BitplaneCompressionTag bpReuseFromPrevTile = checkForReusingBitplaneFromPrevTile(tileNum, currBp);
        bpOptionsQueue.add(bpReuseFromPrevTile);

        // -----------------------------------------------------------------

        BitplaneCompressionTag bestOption = bpOptionsQueue.poll();
        int bestEncodedSize = bestOption.getSizeWhenEncoded();

        // if BP3 is all 00/FF, see if an option for BP0 lets you encode the
        // subroutine indices in 2 bytes instead of 3 while still saving space
        // or breaking even on it
        if (checkBp0 && bestOption.getBitplaneIndex() > RLE_BITPLANE) {
            while (!bpOptionsQueue.isEmpty()) {
                BitplaneCompressionTag nextBestOption = bpOptionsQueue.poll();
                int nextBestOptionSize = nextBestOption.getSizeWhenEncoded();
                if (nextBestOptionSize > bestEncodedSize + 1) break;

                int nextBestOptionIndex = nextBestOption.getBitplaneIndex();
                if (nextBestOptionIndex <= RLE_BITPLANE) {
                    bestOption = nextBestOption;
                    break;
                }
            }
        }

        if (bestEncodedSize >= NUM_ROWS_PER_TILE) {
            bestOption = new BitplaneUncompressed(currBpData);
        }

        /*
        // for debugging, print out every available option for a particular tile
        try {
            for (BitplaneCompressionTag option : bpOptionsQueue) {
                // System.out.println(option.toString());
                log.write(option.toString() + "\n");
            }
            logBestBitplaneOption(bp, bestOption);
        }
        catch (IOException e) {
            System.out.println(e.toString());
        }
        */

        return bestOption;
    }

    // application: try applying the four indices of a so-far common bitplane case
    // to the current tile's bitplanes, and see if it EQUALS the best option
    // determined above; if yes, you can save another byte or two with metadata
    private static BitplaneCompressionTag testBitplaneSubIndex(int tileNum, int currBp, int index) {
        index = getWhichSubIdToDoBeforeSpotChanges(index);
        int currBpData[] = arrayOfBitplanes[tileNum][currBp];
        HashMap<Integer,Integer> hist = getHistogramOfBytesInBitplane(currBpData);

        BitplaneCompressionTag result = BitplaneCaseNotSupportedTag.getInstance();
        if (index >= USE_BP0 && index <= USE_NOT_AND_012 + 1) {
            int calculatedBpData[] = calculateDataByCombiningBitplanes(tileNum, index);
            result = new BitplaneCombineOtherBitplanes(index, currBpData, calculatedBpData);
        }
        else switch (index) {
            case READ_8_RAW_BYTES:
                result = new BitplaneUncompressed(currBpData);
                break;
            case RLE_BITPLANE:
                result = checkEncodingAsRleGroups(currBpData);
                break;
            case FILL_BP_WITH_00:
                result = checkForBitplaneFilledWith00orFF(currBpData, hist, USE_00);
                break;
            case FILL_BP_WITH_FF:
                result = checkForBitplaneFilledWith00orFF(currBpData, hist, USE_FF);
                break;
            case FILL_BP_WITH_BYTE:
                // check for filling with some other byte; if distribution has
                // multiple modes, we only need one of them here
                ArrayList<Integer> modes = checkForBitplaneFilledWithArbitraryByte(hist);
                if (modes.size() > 0) { // make sure that BP doesn't only use 00 or FF
                    int mode = modes.get(0);
                    // if any byte in the bitplane appears at most once, it means all 8
                    // bytes are unique, so this case won't work
                    if (hist.get(mode) > 1) {
                        result = new BitplaneFillWithByte(currBpData, mode);
                    }
                }
                break;

            case FILL_BP_WITH_TWO_BYTE_SEQ:
                result = checkWhatBytesToUseForAlternatingTwoBytes(currBpData);
                break;
            case FILL_BP_WITH_FOUR_BYTE_SEQ:
                result = checkForUsingFourByteSequenceTwice(currBpData);
                break;

            case CREATE_BP_FROM_TWO_BIT_INDICES_AND_BYTES:
                result = checkForBitplaneThatUsesThreeOrFourUniqueBytes(currBpData, hist);
                break;
            case CREATE_BP_FROM_TWO_BIT_INDICES_AND_NIBBLES:
                result = checkForBitplaneThatUsesFourUniqueNibbles(currBpData);
                break;
            case COPY_BP_FROM_PREV_TILE:
                result = checkForReusingBitplaneFromPrevTile(tileNum, currBp);
                break;
        }
        return result;
    }

    @SuppressWarnings("unused")
    private static void logBestBitplaneOption(int bp, BitplaneCompressionTag bestOption) {
        System.out.printf("BP%d: %s\n\n", bp, bestOption.toString());
        try {
            if (bestOption != BitplaneCaseNotSupportedTag.getInstance()) {
                log.write(String.format("BP%d: %s\n\n", bp, bestOption.toString()));
            }
        }
        catch (IOException e) {
            System.out.println(e.toString());
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    @SuppressWarnings("unused")
    private static TileCompressionTag checkForReusingPrevTileAndModifyingBitplanes(int currTileNum) {
        if (currTileNum <= TILE_NUM_OF_EMPTY_TILE || currTileNum >= MAX_NUM_TILES)
            return TileCaseNotSupportedTag.getInstance();

        // - need to keep track of tile number with the fewest different bytes,
        //   as well as which (and how many) bitplanes must be modified
        // - minus the type byte and the low byte of the source tile #, size of
        //   encoded data = # bitplanes + # bytes
        // - worst case: 0x24 = all 0x20 bytes in all 4 bitplanes are different
        // - best case:  0x 2 = only 1 byte in 1 bitplane is different
        // (reasonable assumption: no tiles share the exact same 0x20 bytes)
        int tileNumOfBestMatch = TILE_NUM_OF_EMPTY_TILE;
        int smallestEncodedSize = TILE_SIZE + BIT_DEPTH;
        int differentBitplanes = 0x0F;

        int tileBpData[][] = arrayOfBitplanes[currTileNum];
        int differentByteFlagsList[] = new int[BIT_DEPTH];

        // TODO better performance than an exhaustive search of all tiles
        for (int tile = 0; tile < currTileNum; tile++) {
            int numDifferentBytes = 0;
            int currentDifferentBitplanes = 0;
            int numDifferentBitplanes = 0;
            int currentFlagsForDifferentBytes[] = new int[BIT_DEPTH];

            int bpDataToCheck[][] = arrayOfBitplanes[tile];
            for (int bp = 0; bp < BIT_DEPTH; bp++) {
                boolean bitplaneIsDifferent = false;
                for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
                    boolean byteIsDifferent = tileBpData[bp][r] != bpDataToCheck[bp][r];
                    if (byteIsDifferent) {
                        currentFlagsForDifferentBytes[bp] |= 0x80 >> r;
                        numDifferentBytes++;
                    }
                    bitplaneIsDifferent = bitplaneIsDifferent || byteIsDifferent;
                }
                if (bitplaneIsDifferent) {
                    currentDifferentBitplanes |= 0x08 >> bp;
                    numDifferentBitplanes++;
                }
            }

            int encodedSize = numDifferentBytes + numDifferentBitplanes;
            if (encodedSize < smallestEncodedSize) {
                smallestEncodedSize = encodedSize;
                tileNumOfBestMatch = tile;
                differentBitplanes = currentDifferentBitplanes;
                differentByteFlagsList = currentFlagsForDifferentBytes;
            }

            // if found best possible case, no reason to keep checking
            if (smallestEncodedSize == TileReuseWithNewBitplanesTag.BEST_SIZE) break;
        }

        TileReuseWithNewBitplanesTag output = new TileReuseWithNewBitplanesTag(currTileNum,
            tileBpData, tileNumOfBestMatch, differentByteFlagsList, differentBitplanes);
        return output;
    }

    @SuppressWarnings("unused")
    private static TileCompressionTag checkForReusingPrevTileAndModifyingRows(int currTileNum) {
        if (currTileNum <= TILE_NUM_OF_EMPTY_TILE || currTileNum >= MAX_NUM_TILES)
            return TileCaseNotSupportedTag.getInstance();

        // need to keep track of tile number with the fewest different rows,
        // as well as which (and how many) rows must be modified
        // since the modifying ROWS compression case uses a constant 1 byte for
        // which rows must be modified, we only need to track fewest different rows
        int tileNumOfBestMatch = TILE_NUM_OF_EMPTY_TILE;
        int fewestDifferentRows = NUM_ROWS_PER_TILE;
        int differentRowsFlagByte = 0xFF;

        int tileBpData[][] = arrayOfBitplanes[currTileNum];

        // TODO better performance than an exhaustive search of all tiles
        for (int tile = 0; tile < currTileNum; tile++) {
            int currentDifferentRowsFlagByte = 0;
            int numDifferentRows = 0;

            int bpDataToCheck[][] = arrayOfBitplanes[tile];
            for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
                boolean rowIsDifferent = false;
                for (int bp = 0; bp < BIT_DEPTH && !rowIsDifferent; bp++) {
                    // if any one byte in the row is different, so is the whole row
                    boolean byteIsDifferent = tileBpData[bp][r] != bpDataToCheck[bp][r];
                    rowIsDifferent = rowIsDifferent || byteIsDifferent;
                }
                if (rowIsDifferent) {
                    currentDifferentRowsFlagByte |= 0x80 >> r;
                    numDifferentRows++;
                }
            }

            if (numDifferentRows < fewestDifferentRows) {
                fewestDifferentRows = numDifferentRows;
                tileNumOfBestMatch = tile;
                differentRowsFlagByte = currentDifferentRowsFlagByte;
            }

            // if found best possible case, no reason to keep checking
            if (fewestDifferentRows == 0x1) break;
        }

        TileReuseWithNewRowsTag output = new TileReuseWithNewRowsTag(currTileNum, tileBpData, tileNumOfBestMatch, differentRowsFlagByte);
        return output;
    }

    // combine the "reuse with new rows" and "reuse with new bitplanes" detection
    // code into one loop and only return the best one; this will also ignore the
    // rows case if the best match so far for the bitplanes case outperforms it
    private static TileCompressionTag checkForReusingPrevTileWithEitherNewBitplanesOrRows(int currTileNum) {
        if (currTileNum <= TILE_NUM_OF_EMPTY_TILE || currTileNum >= MAX_NUM_TILES)
            return TileCaseNotSupportedTag.getInstance();

        // for best match with replacing bitplanes
        int tileNumOfBestMatchBitplanes = TILE_NUM_OF_EMPTY_TILE;
        int smallestEncodedSizeBitplanes = TILE_SIZE + BIT_DEPTH;
        int differentBitplanes = 0x0F;
        int differentByteFlagsList[] = new int[BIT_DEPTH];

        // for best match with replacing rows
        int tileNumOfBestMatchRows = TILE_NUM_OF_EMPTY_TILE;
        int fewestDifferentRows = NUM_ROWS_PER_TILE;
        int differentRowsFlagByte = 0xFF;

        int tileBpData[][] = arrayOfBitplanes[currTileNum];
        for (int tile = 0; tile < currTileNum; tile++) {
            int numDifferentBytes = 0;
            int currentDifferentBitplanes = 0;
            int numDifferentBitplanes = 0;
            int currentFlagsForDifferentBytes[] = new int[BIT_DEPTH];

            int currentDifferentRowsFlagByte = 0;
            int numDifferentRows = 0;

            // -----------------------------------------------------------------

            // we always have to check the bitplanes, so put this first
            int bpDataToCheck[][] = arrayOfBitplanes[tile];
            for (int bp = 0; bp < BIT_DEPTH; bp++) {
                boolean bitplaneIsDifferent = false;
                for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
                    boolean byteIsDifferent = tileBpData[bp][r] != bpDataToCheck[bp][r];
                    if (byteIsDifferent) {
                        currentFlagsForDifferentBytes[bp] |= 0x80 >> r;
                        numDifferentBytes++;
                    }
                    bitplaneIsDifferent = bitplaneIsDifferent || byteIsDifferent;
                }
                if (bitplaneIsDifferent) {
                    currentDifferentBitplanes |= 0x08 >> bp;
                    numDifferentBitplanes++;
                }
            }

            // update info for best case with bitplanes if necessary
            int encodedSizeBitplanes = numDifferentBytes + numDifferentBitplanes;
            if (encodedSizeBitplanes < smallestEncodedSizeBitplanes) {
                smallestEncodedSizeBitplanes = encodedSizeBitplanes;
                tileNumOfBestMatchBitplanes = tile;
                differentBitplanes = currentDifferentBitplanes;
                differentByteFlagsList = currentFlagsForDifferentBytes;
            }

            // if found best possible case, no reason to keep checking
            if (smallestEncodedSizeBitplanes == TileReuseWithNewBitplanesTag.BEST_SIZE)
                break;

            // -----------------------------------------------------------------

            // now check for rows case; since the bitplanes case can outperform
            // the rows case, only check rows if it could be better than the best
            // bitplane match that we have found so far
            if (smallestEncodedSizeBitplanes <= TileReuseWithNewRowsTag.BEST_SIZE ||
                fewestDifferentRows == 1) continue;

            for (int r = 0; r < NUM_ROWS_PER_TILE; r++) {
                boolean rowIsDifferent = false;
                for (int bp = 0; bp < BIT_DEPTH && !rowIsDifferent; bp++) {
                    // if any one byte in the row is different, so is the whole row
                    boolean byteIsDifferent = tileBpData[bp][r] != bpDataToCheck[bp][r];
                    rowIsDifferent = rowIsDifferent || byteIsDifferent;
                }
                if (rowIsDifferent) {
                    currentDifferentRowsFlagByte |= 0x80 >> r;
                    numDifferentRows++;
                }
            }
            if (numDifferentRows < fewestDifferentRows) {
                fewestDifferentRows = numDifferentRows;
                tileNumOfBestMatchRows = tile;
                differentRowsFlagByte = currentDifferentRowsFlagByte;
            }
        }

        int sizeOfBestMatchForRows = 1 + BIT_DEPTH * fewestDifferentRows;
        // System.out.printf("Compare row/bp sizes: 0x%X with tile %03X, 0x%X with tile %03X\n",
            // sizeOfBestMatchForRows, tileNumOfBestMatchRows, smallestEncodedSizeBitplanes, tileNumOfBestMatchBitplanes);

        int encodedSize = 0;
        // if there is a tie, the rows case is simpler to decompress on an SFC?
        TileCompressionTag output = TileCaseNotSupportedTag.getInstance();
        if (sizeOfBestMatchForRows <= smallestEncodedSizeBitplanes) {
            output = new TileReuseWithNewRowsTag(currTileNum, tileBpData,
                tileNumOfBestMatchRows, differentRowsFlagByte);
            encodedSize = output.getSizeOfEncodedData();
            if (encodedSize > TILE_SIZE)
                output = TileCaseNotSupportedTag.getInstance();
        }
        else {
            output = new TileReuseWithNewBitplanesTag(currTileNum, tileBpData,
                tileNumOfBestMatchBitplanes, differentByteFlagsList, differentBitplanes);
            encodedSize = output.getSizeOfEncodedData();
            if (output.getSizeOfEncodedData() > TILE_SIZE)
                output = TileCaseNotSupportedTag.getInstance();
        }
        // System.out.printf("Encoded size: %X\n", encodedSize);
        return output;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static TileCompressionTag checkIfBitplanesCanBeRepresentedBy00NNFF_OrNotNN(int tileNum) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES)
            return TileCaseNotSupportedTag.getInstance();

        int tileBpData[][] = arrayOfBitplanes[tileNum];
        int bitplaneTypes[] =
            {TileConstructFrom8Bytes.ALL_00, TileConstructFrom8Bytes.ALL_00,
             TileConstructFrom8Bytes.ALL_00, TileConstructFrom8Bytes.ALL_00};

        // categorize each bitplane as being either: full of 00; full of FF; or
        // neither of those (the choice of what's NN or ~NN is decided later,
        // based on whichever can be encoded in fewer bytes)
        for (int bp = 0; bp < BIT_DEPTH; bp++) {
            int bpData[] = tileBpData[bp];
            for (int i = 0; i < bpData.length; i++) {
                int value = bpData[i];
                // assumption: "all 00" is the default
                if (value == 0xFF) {
                    // if bp[0] = 0xFF, see if the whole bitplane is FF
                    if (i == 0) {
                        bitplaneTypes[bp] = TileConstructFrom8Bytes.ALL_FF;
                    }
                    else {
                        // if got FF and the bitplane is (so far) all 00, this
                        // now classifies the bitplane as "other"
                        if (bitplaneTypes[bp] != TileConstructFrom8Bytes.ALL_FF) {
                            bitplaneTypes[bp] = TileConstructFrom8Bytes.OTHER;
                            break;
                        }
                    }
                }
                else if (value == 0x00 && bitplaneTypes[bp] != TileConstructFrom8Bytes.ALL_00) {
                    bitplaneTypes[bp] = TileConstructFrom8Bytes.OTHER;
                    break;
                }
                else {
                    bitplaneTypes[bp] = TileConstructFrom8Bytes.OTHER;
                    break;
                }
            }
        }

        // next, you must see if all bitplanes with "other" data use either the
        // same data or the same data but bitwise NOTted; it is acceptable for
        // there to be only one bitplane of NN, but if tile data has ZERO of NN/~NN
        // bitplanes (i.e. all bitplanes are 8 00s or 8 FFs), this won't qualify
        int indexOfFirstBitplaneWithNN = BIT_DEPTH;
        for (int i = 0; i < bitplaneTypes.length; i++) {
            if (bitplaneTypes[i] == TileConstructFrom8Bytes.OTHER) {
                indexOfFirstBitplaneWithNN = i;
                break;
            }
        }
        if (indexOfFirstBitplaneWithNN == BIT_DEPTH) {
            return TileCaseNotSupportedTag.getInstance();
        }

        int firstBitplaneWithNN[] = tileBpData[indexOfFirstBitplaneWithNN];
        // the first bitplane of NN qualifies (or should qualify) by definition;
        // start checking with all the subsequent bitplanes
        for (int bp = indexOfFirstBitplaneWithNN + 1; bp < bitplaneTypes.length; bp++) {
            if (bitplaneTypes[bp] != TileConstructFrom8Bytes.OTHER) continue;

            // check the first value in the bitplane, to see if we should expect
            // a bitplane of NN or a bitplane of ~NN, or even if this tile's
            // data doesn't qualify for this case
            boolean expectInvert = false;
            int value0 = tileBpData[bp][0];
            if (value0 == firstBitplaneWithNN[0]) {
                expectInvert = false;
            }
            else if (value0 == (firstBitplaneWithNN[0] ^ 0xFF)) {
                expectInvert = true;
            }
            else {
                return TileCaseNotSupportedTag.getInstance();
            }
            int xorMask = expectInvert ? 0xFF : 0x00;

            // now check the rest of the bitplane's data
            for (int i = 1; i < NUM_ROWS_PER_TILE; i++) {
                int value = tileBpData[bp][i];
                if (value != (firstBitplaneWithNN[i] ^ xorMask)) {
                    return TileCaseNotSupportedTag.getInstance();
                }
            }

            // if got here, the bitplane passed the test; update its bitplane
            // type accordingly
            bitplaneTypes[bp] ^= xorMask;
        }

        // whole tile qualifies for this case, so get a tag that compresses it
        return new TileConstructFrom8Bytes(tileNum, tileBpData, bitplaneTypes);
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int[][] checkGetBitplanesFromBitmaskDataGroups(int tileNum) {
        if (tileNum <= TILE_NUM_OF_EMPTY_TILE || tileNum >= MAX_NUM_TILES) return new int[0][0];

        int bpData[][] = arrayOfBitplanes[tileNum];

        // 8 rows for the bitmask data itself, and one row for the list of bit positions
        int bitmaskDataForBitPositions[][] = new int[SIZE_OF_TERMINATED_BIT_POS_LIST][BITMASK_LIST_SIZE];
        int numBitPositions = 0;
        for (int i = 0; i < BITMASK_LIST_SIZE; i++) {
            bitmaskDataForBitPositions[bitmaskDataForBitPositions.length - 1][i] = BIT_POSITION_LIST_TERMINATOR;
        }

        // generate all 16 different sets of bits that are unique to a particular
        // way you can possibly bitwise-NOT bitplanes and bitwise-AND them together
        // e.g. bit position C (binary 1100) -> ~bp3 & ~bp2 & bp1 & bp0
        for (int bitPos = 0; bitPos < 1<<BIT_DEPTH; bitPos++) {
            // start with all the bits set so you can just AND in data on demand
            // int calcData[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
            int calcData[] = new int[BITMASK_LIST_SIZE];
            for (int r = 0; r < calcData.length; r++) {
                calcData[r] = 0xFF;
            }

            // System.out.printf("\nBit pos %X: ", bitPos);
            // calculate all the data
            for (int bp = 0; bp < BIT_DEPTH; bp++) {
                int invertMask = (bitPos & (1 << bp)) == 0 ? 0xFF : 0x00;
                for (int i = 0; i < calcData.length; i++) {
                    calcData[i] &= bpData[bp][i] ^ invertMask;
                }
            }

            // now check if any of its bytes are nonzero and should be accounted for
            boolean bitPositionHasActualData = false;
            for (int i = 0; i < calcData.length && !bitPositionHasActualData; i++) {
                bitPositionHasActualData = (calcData[i] != 0x00) || bitPositionHasActualData;
                // System.out.printf(" %02X", calcData[i]);
            }
            if (bitPositionHasActualData) {
                // check if limit exceeded or not; must exit if yes
                if (numBitPositions >= MAX_NUM_BIT_POSITIONS) {
                    // System.out.printf("\nToo many bit positions for bitmask groups case (reached 9 with bit pos %X)\n", bitPos);
                    return new int[0][0];
                }

                // copy the data in and take note of the bit position
                for (int i = 0; i < calcData.length; i++) {
                    bitmaskDataForBitPositions[numBitPositions][i] = calcData[i];
                }
                bitmaskDataForBitPositions[bitmaskDataForBitPositions.length - 1][numBitPositions] = bitPos;
                numBitPositions++;
            }
        }

        // to be able to recover group 0 of the data to encode for this case,
        // there must be at least 3 sets of bitmask data
        if (numBitPositions < MIN_NUM_BIT_POSITIONS) {
            // System.out.printf("Too few bit positions (%d) to encode tile with bitmask groups case\n", numBitPositions);
            return new int[0][0];
        }
        return bitmaskDataForBitPositions;
    }

    private static int[][] calculateBitmaskGroupsToBeEncoded(int bitmaskDataForBitPositions[][]) {
        if (bitmaskDataForBitPositions.length != SIZE_OF_TERMINATED_BIT_POS_LIST) {
            return new int[0][0];
        }

        // first, determine how many bit positions needed data
        int numBitPositions = 0;
        int bitPositionsList[] = bitmaskDataForBitPositions[bitmaskDataForBitPositions.length - 1];
        for (int i = 0; i < bitPositionsList.length; i++) {
            if (bitPositionsList[i] == BIT_POSITION_LIST_TERMINATOR) break;
            numBitPositions++;
        }

        // if under 5 bit positions, use 2 groups
        if (numBitPositions < THRESHOLD_FOR_NUM_BIT_POSITIONS) {
            int bitmaskGroups[][] = new int[NUM_GROUPS_OF_8_BITMASKS - 1][BITMASK_LIST_SIZE];
            for (int i = 0; i < BITMASK_LIST_SIZE; i++) {
                bitmaskGroups[BITMASK_GROUP_0][i] = // bit pos 1 | bit pos 3
                    bitmaskDataForBitPositions[1][i] | bitmaskDataForBitPositions[3][i];
                bitmaskGroups[BITMASK_GROUP_1][i] = // bit pos 2 | bit pos 3
                    bitmaskDataForBitPositions[2][i] | bitmaskDataForBitPositions[3][i];
            }
            return bitmaskGroups;
        }
        // if 5 or more bit positions, use 3 groups
        else {
            int bitmaskGroups[][] = new int[NUM_GROUPS_OF_8_BITMASKS][BITMASK_LIST_SIZE];
            for (int i = 0; i < BITMASK_LIST_SIZE; i++) {
                bitmaskGroups[BITMASK_GROUP_0][i] = // bit pos 1 | bit pos 3 | bit pos 5 | bit pos 7
                    bitmaskDataForBitPositions[1][i] | bitmaskDataForBitPositions[3][i] |
                    bitmaskDataForBitPositions[5][i] | bitmaskDataForBitPositions[7][i];
                bitmaskGroups[BITMASK_GROUP_1][i] = // bit pos 2 | bit pos 3 | bit pos 6 | bit pos 7
                    bitmaskDataForBitPositions[2][i] | bitmaskDataForBitPositions[3][i] |
                    bitmaskDataForBitPositions[6][i] | bitmaskDataForBitPositions[7][i];
                bitmaskGroups[BITMASK_GROUP_2][i] = // bit pos 4 | bit pos 5 | bit pos 6 | bit pos 7
                    bitmaskDataForBitPositions[4][i] | bitmaskDataForBitPositions[5][i] |
                    bitmaskDataForBitPositions[6][i] | bitmaskDataForBitPositions[7][i];
            }
            return bitmaskGroups;
        }
    }

    private static TileCompressionTag testGeneratingBitmaskGroupsFromBitplanes(int tileNum) {
        int bitmaskDataForBitPositions[][] = checkGetBitplanesFromBitmaskDataGroups(tileNum);
        int bitmaskDataToBeEncoded[][] = calculateBitmaskGroupsToBeEncoded(bitmaskDataForBitPositions);

        if (bitmaskDataToBeEncoded.length == 0) return TileCaseNotSupportedTag.getInstance();

        TileCombineBitmaskData tag = new TileCombineBitmaskData(tileNum,
            arrayOfBitplanes[tileNum], bitmaskDataForBitPositions, bitmaskDataToBeEncoded);
        // System.out.println(tag.toString());
        return tag;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static TileCompressionTag testBitplaneSubroutineCase(int tileNum) {
        BitplaneCompressionTag bpTagList[] = new BitplaneCompressionTag[BIT_DEPTH];

        BitplaneCompressionTag bpTag3 = getBestCompressionForBitplane(tileNum, BIT_DEPTH - 1, false);
        boolean canRestrictBP3 = (bpTag3 instanceof BitplaneFillWithByte) &&
            bpTag3.getSizeWhenEncoded() == 0;
        bpTagList[BIT_DEPTH - 1] = bpTag3;

        for (int bp = 0; bp < BIT_DEPTH - 1; bp++) {
            bpTagList[bp] = getBestCompressionForBitplane(tileNum, bp, canRestrictBP3);
        }

        // situational optimization: if BP3 is all 00/FF and the best option for
        // BP0 requires 7 bytes to encode while not being indices 1-3 (RLE, or
        // fill 00/FF with spot changes), you can equivalently encode the tile
        // with an uncompressed BP0; you lose a byte on the bitplane but gain it
        // back by encoding the indices in 2 bytes instead of 3 bytes

        // not a worthless change; converting BP0 from a possibly exotic index
        // with spot changes (e.g. 2-byte seq, reuse tile's BP) to a common one
        // can help with choosing frequent options for bitplane sub metadata
        if (canRestrictBP3) {
            BitplaneCompressionTag bpTag0 = bpTagList[0];
            int bpIndex0 = bpTag0.getBitplaneIndex();
            int bp0EncodedSize = bpTag0.getSizeWhenEncoded();
            if (bpIndex0 > RLE_BITPLANE && bp0EncodedSize == NUM_ROWS_PER_TILE - 1) {
                bpTagList[0] = new BitplaneUncompressed(arrayOfBitplanes[tileNum][0]);
            }
        }

        // this popped up for some tilesets (5C) in testing; must explicitly
        // prevent this case if *all four* tags were for "8 raw bytes", which
        // would be better encoded with the uncompressed tile case
        int encodedSize = 0;
        for (BitplaneCompressionTag bpTag : bpTagList) {
            encodedSize += bpTag.getSizeWhenEncoded();
        }
        if (encodedSize >= TILE_SIZE) return TileCaseNotSupportedTag.getInstance();

        return new TileBitplaneSubroutinesTag(tileNum, bpTagList);
    }

    @SuppressWarnings("unused")
    private static TileCompressionTag testBitplaneSubsOfOtherTileForTile(
        int tileNum, TileBitplaneSubroutinesTag otherTag
    ) {
        if (tileNum <= 0 || tileNum > MAX_NUM_TILES || tileNum == otherTag.getTileNum())
            return TileCaseNotSupportedTag.getInstance();

        int encodedIndices = otherTag.getEncodedSubroutineIndices(FORCE_THREE_BYTES);
        return testBitplaneSubsForTile(tileNum, encodedIndices);
    }

    private static TileCompressionTag testBitplaneSubsForTile(
        int tileNum, int encodedIndices
    ) {
        int indices[] = decodeBitplaneIndices(encodedIndices);

        BitplaneCompressionTag bpTagList[] = new BitplaneCompressionTag[BIT_DEPTH];
        for (int bp = 0; bp < bpTagList.length; bp++) {
            int index = indices[bp];
            BitplaneCompressionTag tag = testBitplaneSubIndex(tileNum, bp, index);

            // if either the case is not valid, or if current tile needs spot
            // changes and source tile doesn't need spot changes (or vice versa),
            // we just have to say the whole thing won't work
            if (tag == BitplaneCaseNotSupportedTag.getInstance() ||
                index != tag.getBitplaneIndex()) {
                return TileCaseNotSupportedTag.getInstance();
            }
            bpTagList[bp] = tag;
        }

        TileBitplaneSubroutinesTag output = new TileBitplaneSubroutinesTag(tileNum, bpTagList);
        return output;
    }

    /*
    private static TileCompressionTag testConstructFromEightBytes(int tileNum) {
        TileCompressionTag tag = checkIfBitplanesCanBeRepresentedBy00NNFF_OrNotNN(tileNum);
        System.out.println(tag.toString());
        return tag;
    }

    private static TileCompressionTag testReuseWithNewRows(int tileNum) {
        TileCompressionTag tag = checkForReusingPrevTileAndModifyingRows(tileNum);
        System.out.println(tag.toString());
        return tag;
    }

    private static TileCompressionTag testReuseWithNewBitplanes(int tileNum) {
        TileCompressionTag tag = checkForReusingPrevTileAndModifyingBitplanes(tileNum);
        System.out.println(tag.toString());
        return tag;
    }

    private static TileCompressionTag testCheckUseNewRowsOrBitplanes(int tileNum) {
        TileCompressionTag tag = checkForReusingPrevTileWithEitherNewBitplanesOrRows(tileNum);
        System.out.println(tag.toString());
        return tag;
    }
    */

    // -------------------------------------------------------------------------

    private static void createOutputFileAndLog(String inputFilepath) throws IOException {
        getInputDataAsRawArray(inputFilepath);

        int slashIndex = inputFilepath.lastIndexOf('/');
        int periodIndex = inputFilepath.lastIndexOf('.');
        // String path = inputFilepath.substring(0, slashIndex);
        String filename = inputFilepath.substring(slashIndex + 1, periodIndex);

        Files.createDirectories(Paths.get(OUTPUT_FOLDER));

        String logFilename = "LOG " + filename + ".txt";
        // log = new BufferedWriter(new FileWriter(path + "/" + logFilename));
        log = new BufferedWriter(new FileWriter(OUTPUT_FOLDER + "/" + logFilename));

        String outputFilename = COMPRESSED_FILE_PREFIX + filename + ".bin";
        // outputFile = new FileOutputStream(path + "/" + outputFilename);
        outputFile = new FileOutputStream(OUTPUT_FOLDER + "/" + outputFilename);
    }

    private static void getOptimalCasesForEachTileAndOutputData() {
        if (gfxData == null) return;

        splitInputDataIntoTilesAndBitplanes();
        // to avoid off-by-one errors later, put in a placeholder null entry for
        // the empty tile
        ArrayList<TileCompressionTag> bestOptionForEachTile = new ArrayList<>();
        bestOptionForEachTile.add(null);

        HashMap<Integer,TileBitplaneSubroutinesTag> bitplaneSubTagsThatCanBeOptimal = new HashMap<>();
        HashMap<Integer,TileCombineBitmaskData> bitmaskGroupTagsThatCanBeOptimal = new HashMap<>();

        for (int tile = TILE_NUM_OF_DATA_START; tile < arrayOfTiles.length; tile++) {
            // System.out.printf("%03X ", tile);
            // do the relatively constant-time checks first, then the more time-
            // intensive checks later

            // TileCompressionTag eightBytes = testConstructFromEightBytes(tile);
            TileCompressionTag eightBytes = checkIfBitplanesCanBeRepresentedBy00NNFF_OrNotNN(tile);
            TileCompressionTag bitmaskGroups = testGeneratingBitmaskGroupsFromBitplanes(tile);
            TileCompressionTag bitplaneSubs = testBitplaneSubroutineCase(tile);
            // TileCompressionTag reuseTile = testCheckUseNewRowsOrBitplanes(tile);
            TileCompressionTag reuseTile = checkForReusingPrevTileWithEitherNewBitplanesOrRows(tile);

            PriorityQueue<TileCompressionTag> queue = new PriorityQueue<>();
            queue.add(eightBytes);
            queue.add(bitmaskGroups);
            queue.add(bitplaneSubs);
            queue.add(reuseTile);

            TileCompressionTag bestOption = queue.peek();
            int bestOptionTagSize = bestOption.getSizeOfEncodedData();

            // choosing how to compress the tiles themselves is not quite as
            // straightforward, because tags for bitplane subs and bitmask group
            // combination can be 1 or 2 bytes smaller if their data (encoded
            // subroutine indices, bytes of the bitpacked bit positions list)
            // appears often enough in the tileset to be included as metadata
            int bitplaneSubsTagSize = bitplaneSubs.getSizeOfEncodedData();
            int bitmaskGroupsTagSize = bitmaskGroups.getSizeOfEncodedData();

            // if there's a tie for the best size, prioritize types in the order:
            // bitplane subs > bitmask groups > others
            if (bestOption != bitplaneSubs && bestOptionTagSize == bitplaneSubsTagSize) {
                // bestOptionForEachTile.add(bitplaneSubs);
                bestOption = bitplaneSubs;
            }
            else if (bestOption != bitmaskGroups && bestOptionTagSize == bitmaskGroupsTagSize) {
                // bestOptionForEachTile.add(bitmaskGroups);
                bestOption = bitmaskGroups;
            }
            bestOptionForEachTile.add(bestOption);

            int possibleBitplaneSubsMetadataSavings = bitplaneSubs.getNumBytesSavedFromUsingMetadata();
            int possibleBitmaskGroupsMetadataSavings = bitmaskGroups.getNumBytesSavedFromUsingMetadata();

            // TODO using > here usually is better versus >=, with exceptions
            // most tilemaps compress better with >, others better with >=
            // note: this double counts, but tiles will only use one or the other
            if (bitplaneSubs instanceof TileBitplaneSubroutinesTag &&
                // bestOptionTagSize >= bitplaneSubsTagSize - possibleBitplaneSubsMetadataSavings ) {
                bestOptionTagSize > bitplaneSubsTagSize - possibleBitplaneSubsMetadataSavings ) {
                bitplaneSubTagsThatCanBeOptimal.put(tile, (TileBitplaneSubroutinesTag) bitplaneSubs);
            }
            if (bitmaskGroups instanceof TileCombineBitmaskData &&
                // bestOptionTagSize >= bitmaskGroupsTagSize - possibleBitmaskGroupsMetadataSavings) {
                bestOptionTagSize > bitmaskGroupsTagSize - possibleBitmaskGroupsMetadataSavings) {
                bitmaskGroupTagsThatCanBeOptimal.put(tile, (TileCombineBitmaskData) bitmaskGroups);
            }
        }

        try {
            outputCompressedDataToFile(bestOptionForEachTile,
                bitplaneSubTagsThatCanBeOptimal, bitmaskGroupTagsThatCanBeOptimal);
            outputFile.flush();
            outputFile.close();
            log.flush();
            log.close();
        }
        catch (IOException e) {
            System.out.println(e.toString());
        }
    }

    private static void outputCompressedDataToFile(ArrayList<TileCompressionTag> bestOptionForEachTile,
        HashMap<Integer,TileBitplaneSubroutinesTag> bitplaneSubTagsThatCanBeOptimal,
        HashMap<Integer,TileCombineBitmaskData> bitmaskGroupTagsThatCanBeOptimal
    ) throws IOException {
        // TODO see if this line actually helps you or not
        bitplaneSubTagsThatCanBeOptimal =
            attemptToConvertTagsToUseCommonSubroutines(bitplaneSubTagsThatCanBeOptimal);

        ArrayList<Integer> bestBitplaneMetadataValues =
            getBitplaneMetadataValuesToLookFor(bitplaneSubTagsThatCanBeOptimal);
        ArrayList<Integer> bestBitmaskMetadataValues =
            getBitmaskMetadataValuesToLookFor(bitmaskGroupTagsThatCanBeOptimal,
                bitplaneSubTagsThatCanBeOptimal, bestBitplaneMetadataValues);

        int bpMetadataValue0 = bestBitplaneMetadataValues.get(0);
        int bpMetadataValue1 = bestBitplaneMetadataValues.get(1);
        int bpMetadataValue2 = bestBitplaneMetadataValues.get(2);
        int bpMetadataValue3 = bestBitplaneMetadataValues.get(3);
        for (int i = 0; i < NUM_BYTES_FOR_ENCODED_BP_SUBS; i++) {
            outputFile.write((bpMetadataValue0 >> i*8) & 0xFF);
            outputFile.write((bpMetadataValue1 >> i*8) & 0xFF);
            outputFile.write((bpMetadataValue2 >> i*8) & 0xFF);
            outputFile.write((bpMetadataValue3 >> i*8) & 0xFF);
        }

        for (int i = 0; i < COMMON_BITMASK_BIT_POSITIONS_DATA_SIZE; i++) {
            int bitmaskMetadataValue = 0x00;
            if (i < bestBitmaskMetadataValues.size()) {
                bitmaskMetadataValue = bestBitmaskMetadataValues.get(i);
            }
            outputFile.write(bitmaskMetadataValue);
        }

        doBitplaneMetadataPrintout(bestBitplaneMetadataValues);
        doBitmaskMetadataPrintout(bestBitmaskMetadataValues);

        int numBpMetadataMatches = 0;
        int numBitmaskMetadataMatches = 0;

        int totalCompressedSize = METADATA_HEADER_SIZE;

        for (int tile = TILE_NUM_OF_DATA_START; tile < arrayOfTiles.length; tile++) {
            TileCompressionTag bestOption = bestOptionForEachTile.get(tile);

            // check if possible for the bitplane case to outperform the best option
            TileBitplaneSubroutinesTag bpSubTag = bitplaneSubTagsThatCanBeOptimal.get(tile);
            if (bpSubTag != null && tile == bpSubTag.getTileNum()) {
                int encodedIndices = bpSubTag.getEncodedSubroutineIndices(FORCE_THREE_BYTES);
                if (bestBitplaneMetadataValues.contains(encodedIndices)) {
                    // System.out.printf("Tile %03X: Got BP subroutine metadata value match\n", tile);
                    numBpMetadataMatches++;
                    int index = bestBitplaneMetadataValues.indexOf(encodedIndices);

                    int typeByte = (index & 0x3) << 4;
                    typeByte |= TileBitplaneSubroutinesTag.USE_METADATA_BITMASK;
                    outputFile.write(typeByte);

                    for (Integer value : bpSubTag.getEncodedData()) {
                        outputFile.write(value);
                    }

                    log.write(String.format("Use metadata index %d\n", index));
                    if (bpSubTag.canUseConstructFrom8BytesCase()) {
                        log.write("NOTE: tile can use the \"construct from 8 bytes\" case\n");
                    }
                    // log.write(bestOption.toString() + "\n\n");
                    log.write(bpSubTag.toString() + "\n");

                    int tagSize = bpSubTag.getSizeOfEncodedData() - bpSubTag.getNumBytesSavedFromUsingMetadata();
                    totalCompressedSize += tagSize;
                    log.write(String.format("Size for tag: 0x%2X (0x%4X)\n\n", tagSize, totalCompressedSize));
                    continue;
                }
            }

            // check if possible for the bitmask case to outperform the best option
            TileCombineBitmaskData bitmaskTag = bitmaskGroupTagsThatCanBeOptimal.get(tile);
            if (bitmaskTag != null && tile == bitmaskTag.getTileNum()) {
                int encodedIndices = bitmaskTag.getBitpackedBitPosList();
                int byte0 = encodedIndices & 0xFF;
                int byte1 = encodedIndices >> 8;

                int indexOfByte0 = bestBitmaskMetadataValues.indexOf(byte0);
                int indexOfByte1 = bestBitmaskMetadataValues.indexOf(byte1);
                boolean byte0IsZero = byte0 == 0x00;
                boolean byte1IsZero = byte1 == 0x00;
                boolean byte0InList = indexOfByte0 != -1 && indexOfByte0 < COMMON_BITMASK_BIT_POSITIONS_DATA_SIZE;
                boolean byte1InList = indexOfByte1 != -1 && indexOfByte1 < COMMON_BITMASK_BIT_POSITIONS_DATA_SIZE;

                if ((byte0IsZero || byte0InList) && (byte1IsZero || byte1InList)) {
                // if ((byte0IsZero ^ byte0InList) && (byte1IsZero ^ byte1InList)) {
                    numBitmaskMetadataMatches++;
                    // System.out.printf("Tile %03X: Got bitmask metadata value match(es)\n", tile);
                    // the encoded indices are (index + 1) because an index of 0
                    // represents "use 00 for the byte"
                    int encodedByte0Index = ((indexOfByte0 + 1) & 0xF) << 4;
                    int encodedByte1Index = (indexOfByte1 + 1) & 0xF;

                    int indexByte = 0x00;
                    indexByte |= !byte0IsZero ? encodedByte0Index : 0x00;
                    indexByte |= !byte1IsZero ? encodedByte1Index : 0x00;

                    int typeByte = bitmaskTag.calculateTypeByte();
                    typeByte |= TileCombineBitmaskData.USE_METADATA_BITMASK;

                    outputFile.write(typeByte);
                    outputFile.write(indexByte);
                    for (Integer value : bitmaskTag.getEncodedData()) {
                        outputFile.write(value);
                    }

                    log.write(String.format("Use metadata indices %X,%X -> %02X %02X\n",
                        encodedByte1Index, encodedByte0Index >> 4, byte1, byte0));
                    // log.write(bestOption.toString() + "\n\n");
                    log.write(bitmaskTag.toString() + "\n");

                    int tagSize = bitmaskTag.getSizeOfEncodedData() - bitmaskTag.getNumBytesSavedFromUsingMetadata();
                    totalCompressedSize += tagSize;
                    log.write(String.format("Size for tag: 0x%2X (0x%4X)\n\n", tagSize, totalCompressedSize));
                    continue;
                }
                // both bytes of the bit position list being 0 should not occur
                // if the case has already been detected
            }

            // otherwise, output the best option you have
            // default to uncompressed tile if necessary
            if (bestOption.getSizeOfEncodedData() > TILE_SIZE) {
                bestOption = new UncompressedTileTag(tile, arrayOfTiles[tile]);
            }
            // output bitplane subs tag with its initial metadata
            else if (bestOption instanceof TileBitplaneSubroutinesTag) {
                bpSubTag = (TileBitplaneSubroutinesTag) bestOption;
                int encodedIndices = bpSubTag.getEncodedSubroutineIndices(!FORCE_THREE_BYTES);
                int typeByte = encodedIndices & 0xFF;
                int byte1 = (encodedIndices >> 8) & 0xFF;
                int byte2 = (encodedIndices >> 16) & 0xFF;

                int numOverheadBytes = 2;
                outputFile.write(typeByte);
                outputFile.write(byte1);

                String infoFormat = "%d overhead bytes: %02X %02X";
                if (!bpSubTag.canRestrictBitplanes03()) {
                    outputFile.write(byte2);
                    numOverheadBytes = 3;
                    infoFormat += String.format(" %02X", byte2);
                }
                log.write(String.format(infoFormat, numOverheadBytes, typeByte, byte1) + "\n");
                if (bpSubTag.canUseConstructFrom8BytesCase()) {
                    log.write("NOTE: tile can use the \"construct from 8 bytes\" case\n");
                }
            }
            // output bitmask groups tag with its initial metadata
            else if (bestOption instanceof TileCombineBitmaskData) {
                bitmaskTag = (TileCombineBitmaskData) bestOption;
                int typeByte = bitmaskTag.calculateTypeByte();
                int encodedIndices = bitmaskTag.getBitpackedBitPosList();
                outputFile.write(typeByte);
                outputFile.write(encodedIndices & 0xFF);
                outputFile.write(encodedIndices >> 8);
            }

            for (Integer value : bestOption.getEncodedData()) {
                outputFile.write(value);
            }
            log.write(bestOption.toString() + "\n");

            int tagSize = bestOption.getSizeOfEncodedData();
            totalCompressedSize += tagSize;
            log.write(String.format("Size for tag: 0x%2X (0x%4X)\n\n", tagSize, totalCompressedSize));
        }
        // write the "end of data" terminator byte
        outputFile.write(END_OF_TILE_DATA);

        String finalSize = String.format("\nTotal compressed size: 0x%X\n", totalCompressedSize + 1);
        String bpMatchesPrintout = String.format("BP subroutine metadata value matches: %d\n", numBpMetadataMatches);
        String bitmaskMatchesPrintout = String.format("Bitmask index metadata value matches: %d\n", numBitmaskMetadataMatches);
        log.write(finalSize);
        log.write(bpMatchesPrintout);
        log.write(bitmaskMatchesPrintout);

        System.out.print(finalSize);
        System.out.print(bpMatchesPrintout);
        System.out.print(bitmaskMatchesPrintout);
    }

    // -------------

    private static HashMap<Integer,Integer> countOptionsForBitplaneSubMetadata(
        HashMap<Integer,TileBitplaneSubroutinesTag> bitplaneSubTagsThatCanBeOptimal
    ) {
        // because it's possible for this case to save TWO bytes instead of just
        // one, you should count how many bytes a certain option would save if
        // you could encode it into the metadata, instead of just how many times
        // the value would appear
        HashMap<Integer,Integer> countsForEncodedIndices = new HashMap<>();
        // for (int tile = TILE_NUM_OF_DATA_START; tile < arrayOfTiles.length; tile++) {
        for (int tile : bitplaneSubTagsThatCanBeOptimal.keySet()) {
            TileBitplaneSubroutinesTag tag = bitplaneSubTagsThatCanBeOptimal.get(tile);
            // if (tag == null) continue;

            int encodedIndices = tag.getEncodedSubroutineIndices(FORCE_THREE_BYTES);
            int increment = tag.getNumBytesSavedFromUsingMetadata();
            int count = countsForEncodedIndices.getOrDefault(encodedIndices, 0);
            countsForEncodedIndices.put(encodedIndices, count + increment);
        }

        /*
        System.out.println("Counts for encoded bitplane subroutine indices:");
        for (int key : countsForEncodedIndices.keySet()) {
            System.out.printf("%6X -> %d\n", key, countsForEncodedIndices.get(key));
        }
        System.out.println();
        */

        return countsForEncodedIndices;
    }

    private static ArrayList<Integer> getBitplaneMetadataValuesToLookFor(
        HashMap<Integer,TileBitplaneSubroutinesTag> bitplaneSubTagsThatCanBeOptimal
    ) {
        HashMap<Integer,Integer> countsForMetadataOptions =
            countOptionsForBitplaneSubMetadata(bitplaneSubTagsThatCanBeOptimal);
        ArrayList<Integer> bitplaneOptions = new ArrayList<>(countsForMetadataOptions.keySet());

        // create a priority queue to implement a MAX heap instead of a min heap,
        // because we want fast access to the largest counts
        PriorityQueue<Integer> bitplaneCounts = new PriorityQueue<>(Collections.reverseOrder());
        for (int option : bitplaneOptions) {
            bitplaneCounts.add(countsForMetadataOptions.get(option));
        }

        int bestBitplaneCounts[] = new int[MAX_BP_METADATA_ENTRIES];
        for (int i = 0; i < bestBitplaneCounts.length && !bitplaneCounts.isEmpty(); i++) {
            bestBitplaneCounts[i] = bitplaneCounts.poll();
        }

        ArrayList<Integer> bestBitplaneMetadataValues = new ArrayList<>();
        for (int i = 0; i < bestBitplaneCounts.length; i++) {
            int count = bestBitplaneCounts[i];
            if (count == 0x00) continue;

            // bear in mind that it is possible for counts to tie
            int numMetadataValuesWithCount = 1;
            for (int j = i + 1; j < bestBitplaneCounts.length; j++) {
                if (count == bestBitplaneCounts[j]) {
                    numMetadataValuesWithCount++;
                }
                else break;
            }

            // if there are N encoded values for bitplane indices that have the
            // same best count, get that many UNIQUE values, or at least until
            // you get 4 encoded values total
            for (int bitplaneOption : bitplaneOptions) {
                int countForOption = countsForMetadataOptions.get(bitplaneOption);
                // if (!TileBitplaneSubroutinesTag.bitplanes03AreRestricted(bitplaneOption)) {
                    // countForOption *= 2;
                // }
                if (countForOption == count && !bestBitplaneMetadataValues.contains(bitplaneOption)) {
                    bestBitplaneMetadataValues.add(bitplaneOption);
                    numMetadataValuesWithCount--;
                }

                if (numMetadataValuesWithCount == 0 ||
                    bestBitplaneMetadataValues.size() >= MAX_BP_METADATA_ENTRIES) {
                    break;
                }
            }
        }

        while (bestBitplaneMetadataValues.size() < MAX_BP_METADATA_ENTRIES) {
            bestBitplaneMetadataValues.add(0x00);
        }
        return bestBitplaneMetadataValues;
    }

    private static HashMap<Integer,TileBitplaneSubroutinesTag> attemptToConvertTagsToUseCommonSubroutines(
        HashMap<Integer,TileBitplaneSubroutinesTag> bitplaneSubTagsThatCanBeOptimal
    ) {
        HashMap<Integer,Integer> countsForMetadataOptions = countOptionsForBitplaneSubMetadata(bitplaneSubTagsThatCanBeOptimal);

        ArrayList<Integer> bitplaneOptions = new ArrayList<>(countsForMetadataOptions.keySet());
        ArrayList<EncodedBitplaneIndicesWithCount> bitplaneCountObjs = new ArrayList<>();
        // PriorityQueue<Integer> bitplaneCounts = new PriorityQueue<>(Collections.reverseOrder());
        for (int option : bitplaneOptions) {
            int count = countsForMetadataOptions.get(option);
            EncodedBitplaneIndicesWithCount bitplaneCountObj = new EncodedBitplaneIndicesWithCount(option, count);
            bitplaneCountObjs.add(bitplaneCountObj);
        }
        Collections.sort(bitplaneCountObjs, Collections.reverseOrder());

        HashMap<Integer,TileBitplaneSubroutinesTag> output = new HashMap<>();
        ArrayList<Integer> tileNumsToCheck = new ArrayList<>(bitplaneSubTagsThatCanBeOptimal.keySet());
        for (int tileID : tileNumsToCheck) {
            TileBitplaneSubroutinesTag tag = bitplaneSubTagsThatCanBeOptimal.get(tileID);
            // if the tag does not already use one of the four most common
            // subroutine index sets for the tileset, check if applying any set
            // to it will encode to the SAME size as the best option

            // alternate heuristic: if not for one of the four most common, see
            // if you can convert the current indices to *A* more common set of
            // indices period; you can probably re-iterate this process
            int originalEncodedIndices = tag.getEncodedSubroutineIndices(FORCE_THREE_BYTES);
            int bestSize = tag.getSizeOfEncodedData();

            boolean updated = false;
            for (int i = 0; i < MAX_BP_METADATA_ENTRIES && i < bitplaneCountObjs.size(); i++) {
            // for (int i = 0; i < bitplaneCountObjs.size(); i++) {
                EncodedBitplaneIndicesWithCount bitplaneCountObj = bitplaneCountObjs.get(i);
                int commonEncodedIndicesToCheck = bitplaneCountObj.getEncodedIndices();
                if (commonEncodedIndicesToCheck == tag.getEncodedSubroutineIndices(FORCE_THREE_BYTES)) {
                    continue;
                }

                TileCompressionTag testResult = testBitplaneSubsForTile(tileID, commonEncodedIndicesToCheck);
                if (testResult == TileCaseNotSupportedTag.getInstance()) {
                    continue;
                }

                int testSize = testResult.getSizeOfEncodedData();
                if (testSize == bestSize) {
                    // if sizes match, update counts for both the set that you're
                    // converting TO and the set that you're switching FROM
                    for (int j = bitplaneCountObjs.size() - 1; j >= 0; j--) {
                        EncodedBitplaneIndicesWithCount originalBitplaneCountObj = bitplaneCountObjs.get(j);
                        if (originalBitplaneCountObj.getEncodedIndices() == originalEncodedIndices) {
                            originalBitplaneCountObj.decrementCount();
                            bitplaneCountObjs.set(j, originalBitplaneCountObj);
                            break;
                        }
                    }
                    bitplaneCountObj.incrementCount();
                    bitplaneCountObjs.set(i, bitplaneCountObj);

                    Collections.sort(bitplaneCountObjs, Collections.reverseOrder());

                    output.put(tileID, (TileBitplaneSubroutinesTag) testResult);
                    updated = true;
                    break;
                }
            }
            if (!updated) {
                output.put(tileID, tag);
            }
        }

        return output;
    }

    private static void doBitplaneMetadataPrintout(ArrayList<Integer> bestBitplaneMetadataValues
    ) throws IOException {
        for (int i = 0; i < bestBitplaneMetadataValues.size(); i++) {
            log.write("Bitplane metadata index " + i + ":\n");
            int bpMetadataValue = bestBitplaneMetadataValues.get(i);
            log.write(TileCompConstants.getBitplaneMetadataPrintout(bpMetadataValue) + "\n");
        }
        log.write("--------------------\n\n");
    }

    // -------------

    private static HashMap<Integer,Integer> countOptionsForBitmaskCombinationMetadata(
        HashMap<Integer,TileCombineBitmaskData> bitmaskGroupTagsThatCanBeOptimal,
        HashMap<Integer,TileBitplaneSubroutinesTag> bitplaneSubTagsThatCanBeOptimal,
        ArrayList<Integer> bestBitplaneMetadataValues
    ) {
        HashMap<Integer,Integer> countsForBitPosListBytes = new HashMap<>();
        for (int tile = TILE_NUM_OF_DATA_START; tile < arrayOfTiles.length; tile++) {
            TileCombineBitmaskData tag = bitmaskGroupTagsThatCanBeOptimal.get(tile);
            if (tag == null) continue;

            // attempt to fix the double counting issue mentioned above:
            // - if this tile's data has already been found to work for bitplane
            //   metadata, we don't need to count the bitmask indices for it
            // - problem: this does work better for some tilesets, but also does
            //   worse with others, and no easy way to tell which way it'll go
            TileBitplaneSubroutinesTag bpTag = bitplaneSubTagsThatCanBeOptimal.get(tile);
            if (bpTag != null) {
                int bpMetadata = bpTag.getEncodedSubroutineIndices(FORCE_THREE_BYTES);
                if (bestBitplaneMetadataValues.contains(bpMetadata)) continue;
            }

            int bitPosList = tag.getBitpackedBitPosList();
            int byte0 = bitPosList & 0xFF;
            int byte1 = bitPosList >> 8;
            if (byte0 != 0) {
                int count = countsForBitPosListBytes.getOrDefault(byte0, 0);
                countsForBitPosListBytes.put(byte0, count + 1);
            }
            if (byte1 != 0) {
                int count = countsForBitPosListBytes.getOrDefault(byte1, 0);
                countsForBitPosListBytes.put(byte1, count + 1);
            }
        }

        /*
        System.out.println("Counts for bitmask bit position bytes:");
        for (int key : countsForBitPosListBytes.keySet()) {
            System.out.printf("%02X -> %3d\n", key, countsForBitPosListBytes.get(key));
        }
        */

        return countsForBitPosListBytes;
    }

    private static ArrayList<Integer> getBitmaskMetadataValuesToLookFor(
        HashMap<Integer,TileCombineBitmaskData> bitmaskGroupTagsThatCanBeOptimal,
        HashMap<Integer,TileBitplaneSubroutinesTag> bitplaneSubTagsThatCanBeOptimal,
        ArrayList<Integer> bestBitplaneMetadataValues
    ) {

        HashMap<Integer,Integer> bitmaskGroupMetadataOptions =
            countOptionsForBitmaskCombinationMetadata(bitmaskGroupTagsThatCanBeOptimal,
                bitplaneSubTagsThatCanBeOptimal, bestBitplaneMetadataValues
            );
        ArrayList<Integer> bitmaskOptions = new ArrayList<>(bitmaskGroupMetadataOptions.keySet());
        // System.out.printf("# bitmask byte options: %d\n", bitmaskOptions.size());

        PriorityQueue<Integer> bitmaskCounts = new PriorityQueue<>(Collections.reverseOrder());
        for (int option : bitmaskOptions) {
            bitmaskCounts.add(bitmaskGroupMetadataOptions.get(option));
        }
        // System.out.printf("# bitmask byte option counts: %d\n", bitmaskCounts.size());
        int bestBitmaskCounts[] = new int[COMMON_BITMASK_BIT_POSITIONS_DATA_SIZE];
        for (int i = 0; i < bestBitmaskCounts.length && !bitmaskCounts.isEmpty(); i++) {
            bestBitmaskCounts[i] = bitmaskCounts.poll();
        }
        // System.out.printf("# bitmask byte option counts after taking best ones: %d\n", bitmaskCounts.size());

        ArrayList<Integer> bestBitmaskMetadataValues = new ArrayList<>();
        for (int i = 0; i < bestBitmaskCounts.length; i++) {
            int count = bestBitmaskCounts[i];
            if (count == 0x00) continue;

            // bear in mind that it is possible for counts to tie
            int numMetadataValuesWithCount = 1;
            for (int j = i + 1; j < bestBitmaskCounts.length; j++) {
                if (count == bestBitmaskCounts[j]) {
                    numMetadataValuesWithCount++;
                }
                else break;
            }

            // if there are N encoded values for bit position list bytes with the
            // same best count, get that many UNIQUE values, or at least until
            // you get 0xF encoded values total
            for (int bitmaskOption : bitmaskOptions) {
                int countForOption = bitmaskGroupMetadataOptions.get(bitmaskOption);
                if (countForOption == count && !bestBitmaskMetadataValues.contains(bitmaskOption)) {
                    bestBitmaskMetadataValues.add(bitmaskOption);
                    numMetadataValuesWithCount--;
                    if (numMetadataValuesWithCount == 0 ||
                        bestBitmaskMetadataValues.size() >= COMMON_BITMASK_BIT_POSITIONS_DATA_SIZE) {
                        break;
                    }
                }
            }
        }

        /*
        while (bestBitmaskMetadataValues.size() < COMMON_BITMASK_BIT_POSITIONS_DATA_SIZE) {
            bestBitmaskMetadataValues.add(0x00);
        }
        */
        return bestBitmaskMetadataValues;
    }

    private static void doBitmaskMetadataPrintout(ArrayList<Integer> bestBitmaskMetadataValues) throws IOException {
        log.write("Bitmask metadata values:\n");
        for (int i = 0; i < COMMON_BITMASK_BIT_POSITIONS_DATA_SIZE; i++) {
            int metadataValue = 0x00;
            if (i < bestBitmaskMetadataValues.size()) {
                metadataValue = bestBitmaskMetadataValues.get(i);
            }
            else break;

            String info = String.format("%X: %02X ->", i + 1, metadataValue);
            for (int bitPos = 0; bitPos < 8; bitPos++) {
                int bit = metadataValue & 0x80;
                metadataValue <<= 1;
                if (bit != 0) {
                    info += String.format(" %X", bitPos);
                }
            }
            log.write(info + "\n");
        }
        log.write("\n--------------------\n\n");
    }

    // -------------------------------------------------------------------------

    public static void main(String args[]) throws IOException {
        // String testFile = "test data from game/$2584B1 tile data.bin";
        // String testFile = "test data from game/$46C500 tile data.bin";
        // getInputDataAsRawArray(testFile);
        // splitInputDataIntoTilesAndBitplanes();
        // getOptimalCasesForEachTileAndOutputData(testFile);
        // outputUncompressedFileWithBitplanesUninterleaved(testFile);

        // testHashmapWithArraysAsKeys();

        // testGeneratingBitmaskGroupsFromBitplanes(0x0cf);
        // testBitplaneSubroutineCase(0x111);
        // testConstructFromEightBytes(0x1f2);
        // testReuseWithNewRows(0x112);
        // testReuseWithNewBitplanes(0x066);
        // testCheckUseNewRowsOrBitplanes(0x00d);

        for (String filepath : args) {
            int slashIndex = filepath.lastIndexOf('/');
            String inputFilename = filepath.substring(slashIndex + 1);
            if (inputFilename.startsWith(COMPRESSED_FILE_PREFIX)) {
                gfxData = null;
                continue;
            }

            getInputDataAsRawArray(filepath);
            splitInputDataIntoTilesAndBitplanes();
            createOutputFileAndLog(filepath);
            getOptimalCasesForEachTileAndOutputData();
            // outputUncompressedFileWithBitplanesUninterleaved(filepath);
        }
    }
}
