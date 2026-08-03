package lzss;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;

public class LZSSRecompress {

    private static final int MAX_DISTANCE_BACK = 0xFFFF;
    private static final int MAX_MATCH_SIZE = 0xFFFF;
    private static final int MAX_LITS_PER_TAG = 0x1f; // default is 0x7F
    private static final int DISTANCE_LIMIT_FOR_TWO_BYTE_CASE = 0xFF - MAX_LITS_PER_TAG;
    private static final int SIZE_THRESHOLD_FOR_FIVE_BYTE_CASE = 0x100;
    private static final int NO_MATCH = -1;

    private static FileInputStream inputDataStream;
    private static FileOutputStream outputFile;
    private static BufferedWriter logFile;
    private static byte[] inputDataBytes;
    private static String inputDataString;

    private static final String OUTPUT_FOLDER = "recompressed LZSS blocks/";
    private static final String FILE_PREFIX = "recompressed ";

    private static final boolean DEBUG = true;

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static class LZTag {
        int ptrToTag;
        int ptrToMatch;
        int length;
        boolean isMatch;

        public LZTag(int ptrToTag, int ptrToMatch, int length, boolean isMatch) {
            this.ptrToTag = ptrToTag;
            this.ptrToMatch = ptrToMatch;
            this.length = length;
            this.isMatch = isMatch;
        }

        public LZTag(LZTag other) {
            ptrToTag = other.ptrToTag;
            ptrToMatch = other.ptrToMatch;
            length = other.length;
            isMatch = other.isMatch;
        }

        public int getDistance() {
            return ptrToTag - ptrToMatch;
        }

        public int getNumOverheadBytes() {
            if (!isMatch) return 1;
            if (length > SIZE_THRESHOLD_FOR_FIVE_BYTE_CASE) return 5;
            if (getDistance() <= DISTANCE_LIMIT_FOR_TWO_BYTE_CASE) return 2;
            return 4;
        }

        public int getNumTagsForLitsCase() {
            if (isMatch) return 0;
            return length / MAX_LITS_PER_TAG +
                   (length % MAX_LITS_PER_TAG == 0 ? 0 : 1);
        }

        public int getNumBytesForTagWhenCompressed() {
            if (isMatch) return getNumOverheadBytes();

            // if literals, enforce limit of 0x7F bytes per tag
            return length + getNumTagsForLitsCase();
        }

        public boolean canOptimizeMatchTwoByteFormat() {
            return isMatch && length <= 2;
        }

        public boolean canOptimizeMatchFourByteFormat() {
            return isMatch && getDistance() > DISTANCE_LIMIT_FOR_TWO_BYTE_CASE && length <= 4;
        }

        public boolean canOptimizeMatch() {
            return canOptimizeMatchTwoByteFormat() || canOptimizeMatchFourByteFormat();
        }

        public boolean equals(Object other) {
            if (other == null) return false;
            if (!(other instanceof LZTag)) return false;
            if (this == other) return true;

            LZTag otherTag = (LZTag) other;
            return (isMatch == otherTag.isMatch) &&
                   ptrToTag == otherTag.ptrToTag &&
                   ptrToMatch == otherTag.ptrToMatch &&
                   length == otherTag.length;
        }

        public String toString() {
            String format = "%4X | %2d | ";
            int overhead = getNumOverheadBytes();
            if (isMatch) {
                format += "0x%3X match @ 0x%4X";
                return String.format(format, ptrToTag, overhead, length, ptrToMatch);
            }
            else {
                format += "0x%3X lits%s";
                String wasOptimized = "";
                if (ptrToMatch != NO_MATCH) {
                    wasOptimized = String.format("  - 0x%4X match optimized out", ptrToMatch);
                }
                if (length > MAX_LITS_PER_TAG) {
                    format += String.format(" (%d tags)", getNumTagsForLitsCase());
                }
                return String.format(format, ptrToTag, overhead, length, wasOptimized);
            }
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static String removeFileExtension(String filename) {
        int periodIndex = filename.lastIndexOf('.');
        return periodIndex == -1 ? filename : filename.substring(0, periodIndex);
    }

    private static void getInputDataAsArray(int cpuOffset) throws IOException {
        int bankNum = (cpuOffset >> 16) & 0xFF;
        int bankOffset = cpuOffset & 0xFFFF;
        int fileOffset = 0x8000 * (bankNum - 1) + bankOffset;

        byte outputBuffer[] = new byte[0x10000];
        int totalSize = 0;

        RandomAccessFile romFile = new RandomAccessFile("rom/Kamaitachi no Yoru (Japan).sfc", "r");
        romFile.seek(fileOffset);
        // fail-safe: terminate if got to end of ROM
        while (romFile.getFilePointer() < 0x300000) {
            // notice the use of readByte() instead of readUnsignedByte()
            // upcasting extends the sign bit, e.g. 0xFFFFFFC0 instead of 0xC0
            int N1 = romFile.readByte();
            if (N1 > 0) {
                // if positive, copy that many literal bytes into the output buffer
                for (int i = 0; i < N1; i++) {
                    outputBuffer[totalSize] = (byte) romFile.readUnsignedByte();
                    totalSize++;
                }
            }
            else if (N1 < 0) {
                // if negative, read byte for data size, and then (size+1) bytes
                // from [totalSize + N1] where "+" assumes N1 is already negative
                // i.e. the match is at most 0xFF bytes, up to 0x80 bytes back
                int dataSize = romFile.readUnsignedByte();
                for (int i = 0; i < dataSize + 1; i++) {
                    outputBuffer[totalSize] = outputBuffer[totalSize + N1];
                    totalSize++;
                }
            }
            else {
                // if got zero, have to read two more bytes from ROM
                // fill in the high bytes of 32-bit int variable with sign bit
                int N2 = romFile.readUnsignedByte();
                N2 |= ((int) romFile.readByte()) << 8;

                if (N2 == 0) {
                    break;
                }
                else if (N2 < 0) {
                    // if N2 is negative, the match is at most 0xFF bytes, any distance back
                    int dataSize = romFile.readUnsignedByte();
                    for (int i = 0; i < dataSize + 1; i++) {
                        outputBuffer[totalSize] = outputBuffer[totalSize + N2];
                        totalSize++;
                    }
                }
                else {
                    // N2 > 0; the match is 0x100+ bytes, and any distance back
                    int dataSize = romFile.readUnsignedByte();
                    dataSize |= (romFile.readUnsignedByte() << 8);

                    for (int i = 0; i < dataSize + 1; i++) {
                        outputBuffer[totalSize] = outputBuffer[totalSize - N2];
                        totalSize++;
                    }
                }
            }
        }
        romFile.close();

        inputDataBytes = new byte[totalSize];
        for (int i = 0; i < inputDataBytes.length; i++) {
            inputDataBytes[i] = outputBuffer[i];
        }
    }

    private static void getInputDataAsArray(String inputFilename) throws IOException {
        // get file's size to know the exact size for the array
        File f = new File(inputFilename);
        long fileLength = f.length();
        inputDataBytes = new byte[(int) fileLength];

        inputDataStream = new FileInputStream(inputFilename);
        inputDataStream.read(inputDataBytes);
        inputDataStream.close();
    }

    private static void buildReversedDataBuffer() {
        // "convert" the raw byte array into a String
        // note that the bytes are copied into the String in reverse order
        // - purpose: find longest match so far, starting from the most recently
        //   added bytes in the search buffer, versus starting from offset 0
        // - takes advantage of how the compression format uses fewer overhead
        //   bytes if a match began within the last added 0x80 bytes
        // in other words, need to search "right-to-left," but since indexOf()
        // searches "left-to-right", we reverse the input data bytes, get search
        // buffers from these reversed bytes, and match with reversed byte seqs
        // and yes, lastIndexOf() exists, but that produced worse file sizes
        inputDataString = "";
        for (byte b : inputDataBytes) {
            inputDataString = ((char) b) + inputDataString;
        }
    }

    /*
    private static String reverseString(String input) {
        int n = input.length();
        char rev[] = input.toCharArray();
        for (int i = 0; i < n/2; i++) {
            char temp = rev[i];
            rev[i] = rev[n - i - 1];
            rev[n - i - 1] = temp;
        }
        return new String(rev);
    }
    */

    private static void printTagsList(ArrayList<LZTag> tags) throws IOException {
        logFile.write(" Size | Pos  | Ov | Description\n");
        logFile.write("------+------+----+------------\n");
        int compressedSize = 0;
        for (LZTag tag : tags) {
            logFile.write(String.format(" %4X | ", compressedSize));
            logFile.write(tag.toString() + "\n");
            compressedSize += tag.getNumBytesForTagWhenCompressed();
        }
        logFile.write("Write \"end of data\" [00 00 00]\n");
        logFile.write(String.format("Total size: %4X ", compressedSize + 3));
    }

    /*
    private static String getBytesOfHexString(String hexString) {
        String output = "";
        char arr[] = hexString.toCharArray();
        for (int i = 0; i < arr.length; i++) {
            char ch = arr[i];
            output += String.format("%02X%s", (int) ch, (i & 0xF) == 0xF ? "\n" : " ");
        }
        return output;
    }
    */

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int getRunLengthAtPosition(int startPos) {
        if (startPos < 0 || startPos >= inputDataBytes.length) return 0;
        byte startChar = inputDataBytes[startPos];
        int currPos = startPos + 1;
        while (currPos < inputDataBytes.length) {
            byte b = inputDataBytes[currPos];
            if (b != startChar) {
                // currPos--;
                break;
            }
            currPos++;
        }
        return currPos - startPos;
    }

    // note: idea of finding matches with substrings and indexOf is from repo:
    // https://github.com/KhaledAshrafH/LZ-77
	private static LZTag getLargestMatch(String inputData, int lookbackSize, int currPos) {
        String searchBuffer = "";
        String stringToSearch = "";

        int indexOfLastMatchFragment = NO_MATCH;

        int endOfReverseRange = inputData.length() - 1;
        int length = 0;
        int startOfLookback = endOfReverseRange - Math.max(currPos - lookbackSize, 0);

        while (currPos < inputData.length()) {
            // search in a range that (with normal data block) begins at data
            // start or up to max lookback distance, and ends just before curr pos
            // with reversed data block, substring "ends" at start of lookback
            // and "starts" to the right of the current position
            searchBuffer = inputData.substring(endOfReverseRange - currPos + 1, startOfLookback + 1);

            // build byte sequence to search for, most recent bytes coming first
            // i.e. prepend characters to beginning, not append them to end
            stringToSearch = inputData.charAt(endOfReverseRange - currPos) + stringToSearch;
            int matchIndex = searchBuffer.indexOf(stringToSearch);

            length = stringToSearch.length();

            // got a match
            if (matchIndex != NO_MATCH) {
                // if within size limit, see if match continues
                if (length < MAX_MATCH_SIZE) {
                    currPos++;
                }
                // if max size reached, just return the match as it is
                // same as if got to the end of the buffer
                else {
                    break;
                }
            }

            else {
                // the most recently added character prevented a match; how much
                // of the search string DID match? let L be the match length
                int matchSize = length - 1;
                int tagPtr = currPos;
                int tagSize = 0;
                int matchPtr = NO_MATCH;
                boolean isMatch = false;

                // L = 0: most recent byte is unique within lookback (1 literal)
                if (matchSize == 0) {
                    tagPtr = currPos;
                    tagSize = 1;
                    isMatch = false;
                    matchPtr = NO_MATCH;
                }

                // L = 1: encode the matched byte as 1 literal
                else if (matchSize == 1) {
                    tagPtr = currPos - 1;
                    tagSize = 1;
                    isMatch = false;
                    matchPtr = NO_MATCH;
                }

                // L = 2: encode the first matched byte as a literal, but
                // the second matched byte may be the start of a match
                // why encode 1st byte as a literal instead of a match?
                // cases as literal:
                // - 1 byte:  combine w/ prev. literals tag if fits [NN ... XX]
                // - 2 bytes: standalone literal tag of [01 XX]
                // cases as match:
                // - 2 bytes: data byte is up to 0x100 bytes back
                // - 4 bytes: data byte is 0x100+ bytes back
                // conclude: 1 byte literal is better or equal to a 1 byte match
                else if (matchSize == 2) {
                    tagPtr = currPos - 2;
                    tagSize = 1;
                    isMatch = false;
                    matchPtr = NO_MATCH;
                }

                // L > 2: create tag for match; don't consume unmatched byte
                else {
                    tagPtr = currPos - matchSize;
                    tagSize = matchSize;
                    isMatch = true;
                    // account for index in reversed input data
                    matchPtr = tagPtr - 1 - indexOfLastMatchFragment;
                }

                return new LZTag(tagPtr, matchPtr, tagSize, isMatch);
            }

            // note: must convert from an index starting from lookback to an
            // index starting at the beginning of the data to compress
            indexOfLastMatchFragment = matchIndex;
        }

        // if got to the end of the buffer, just return whatever match we have
        // again, account for index in reversed input data
        int tagPtr = currPos - length + 1;
        return new LZTag(tagPtr, tagPtr - 1 - indexOfLastMatchFragment, length, true);
    }

    // not perfect but did compress a handful of files down some more;
    // example offsets where this did not work well in $04C004 file:
    // 0x2084
    private static LZTag checkMatchesInLimitedLookback(LZTag tag) {
        // does the absolute best match require 4 overhead bytes, going back
        // 0x81+ bytes? see if downgrading the lookback distance to at most
        // 0x80 bytes (use 2 bytes of overhead) would be worth it
        if (tag.getNumOverheadBytes() == 4) {
            LZTag tagInLimitedLookback = getLargestMatch(inputDataString, DISTANCE_LIMIT_FOR_TWO_BYTE_CASE, tag.ptrToTag);
            int sizeDiff = tag.length - tagInLimitedLookback.length;
            if (tagInLimitedLookback.getNumOverheadBytes() == 2 && sizeDiff <= 2) {
                return tagInLimitedLookback;
            }
        }
        // if not, just return the existing tag
        return tag;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int getOffsetAfterLastTag(ArrayList<LZTag> path) {
        if (path == null || path.isEmpty()) {
            return -1;
        }
        LZTag lastTag = path.get(path.size() - 1);
        return lastTag.ptrToTag + lastTag.length;
    }

    private static int getCompressedSizeOfPath(ArrayList<LZTag> path) {
        int sum = 0;
        for (LZTag tag : path) {
            sum += tag.getNumBytesForTagWhenCompressed();
        }
        return sum;
    }

    private static int getLengthOfPath(ArrayList<LZTag> path) {
        int sum = 0;
        for (LZTag tag : path) {
            sum += tag.length;
        }
        return sum;
    }

    private static ArrayList<LZTag> getBestPathFromTwoStartOptions(LZTag option1, LZTag option2, boolean mostRecentTagWasForLits) {
        if (option1 == null || option2 == null || option1.ptrToTag != option2.ptrToTag) {
            return null;
        }

        // if the two options are identical, just return one of them
        ArrayList<LZTag> path1 = new ArrayList<>();
        path1.add(option1);
        if (option1.equals(option2)) {
            return path1;
        }

        // otherwise, use each option as the start point for a path
        ArrayList<LZTag> path2 = new ArrayList<>();
        path2.add(option2);
        return getBestPathFromTwoPaths(path1, path2, mostRecentTagWasForLits);
    }

    private static ArrayList<LZTag> getBestPathFromTwoPaths(ArrayList<LZTag> path1, ArrayList<LZTag> path2, boolean mostRecentTagWasForLits) {
        if (path1 == null || path2 == null || path1.isEmpty() || path2.isEmpty() ||
            path1.get(0).ptrToTag != path2.get(0).ptrToTag) {
            return null;
        }

        int endOffset1 = getOffsetAfterLastTag(path1);
        int endOffset2 = getOffsetAfterLastTag(path2);
        // see if the two paths have converged at the same offset in the file
        if (endOffset1 == endOffset2) {
            // if yes, check if the last tag for either path is for lits
            if (!path1.get(path1.size() - 1).isMatch || !path2.get(path2.size() - 1).isMatch) {
                // if yes, read as many DEFINITE lits as possible, i.e. until we
                // find the next possible match
                int lookForLitsHere = endOffset1;
                while (lookForLitsHere < inputDataBytes.length) {
                    LZTag nextTag = getLargestMatch(inputDataString, MAX_DISTANCE_BACK, lookForLitsHere);
                    if (nextTag.isMatch) break;
                    path1.add(nextTag);
                    path2.add(nextTag);
                    lookForLitsHere++;
                }
            }
            // combine all the lits together for both paths
            path1 = combineTags(path1);
            path2 = combineTags(path2);

            // return whichever path takes the fewest bytes to compress
            int pathSize1 = getCompressedSizeOfPath(path1);
            int pathSize2 = getCompressedSizeOfPath(path2);
            if (pathSize1 < pathSize2) return path1;
            else if (pathSize2 < pathSize1) return path2;
            else {
                // if compressed sizes are equal, see if tag right before path
                // was for lits; if yes and if either path starts with lits,
                // use that path (reasoning: reuse the literals overhead byte)
                if (mostRecentTagWasForLits) {
                    if (!path1.get(0).isMatch) {
                        return path1;
                    }
                    else if (!path2.get(0).isMatch) {
                        return path2;
                    }
                }
                // otherwise, I suppose we can just break ties based on how many
                // tags each path takes
                int numTags1 = path1.size();
                int numTags2 = path2.size();
                return (numTags1 <= numTags2) ? path1 : path2;
            }
        }
        else {
            // if paths have not converged, look for a match starting at the
            // earlier of the two offsets, i.e. allow that path to catch up
            int findMatchHere = Math.min(endOffset1, endOffset2);
            LZTag nextTag = getLargestMatch(inputDataString, MAX_DISTANCE_BACK, findMatchHere);

            // look for the best path to take from the current position
            // by default, start with the largest possible match we can get
            ArrayList<LZTag> bestPathToTakeFromHere = new ArrayList<>();
            bestPathToTakeFromHere.add(nextTag);

            // if the match can be optimized, see that gives you a better path
            if (nextTag.canOptimizeMatch()) {
                LZTag singleLitAtMatch = new LZTag(nextTag.ptrToTag, nextTag.ptrToMatch, 1, false);
                ArrayList<LZTag> bestAfterLit = new ArrayList<>();
                bestAfterLit.add(singleLitAtMatch);
                bestPathToTakeFromHere = getBestPathFromTwoPaths(bestPathToTakeFromHere, bestAfterLit, mostRecentTagWasForLits);
            }

            // if a decent match exists within limited lookback, see that gives you a better path
            LZTag limitedLookback = checkMatchesInLimitedLookback(nextTag);
            if (!nextTag.equals(limitedLookback)) {
                ArrayList<LZTag> bestAfterLimitedLookback = new ArrayList<>();
                bestAfterLimitedLookback.add(limitedLookback);
                bestPathToTakeFromHere = getBestPathFromTwoPaths(bestPathToTakeFromHere, bestAfterLimitedLookback, mostRecentTagWasForLits);
            }

            // add the tags for the best path to take, to the appropriate path
            if (findMatchHere == endOffset1) {
                path1.addAll(bestPathToTakeFromHere);
            }
            else {
                path2.addAll(bestPathToTakeFromHere);
            }

            // continue getting tags until the two paths converge
            return getBestPathFromTwoPaths(path1, path2, mostRecentTagWasForLits);
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static ArrayList<LZTag> getLZSSTags() {
        // initialize the search buffer with the first byte of data
        ArrayList<LZTag> tags = new ArrayList<>();
        LZTag firstTag = new LZTag(0, NO_MATCH, 1, false);
        tags.add(firstTag);

        int currPos = 1;
        while (currPos < inputDataBytes.length) {
            // special case if a single value (e.g. 00) repeats 0x101+ times
            // don't try to find longest match for it, and just do new match now
            // no reversing nonsense necessary; use byte array in normal order
            int runLength = getRunLengthAtPosition(currPos);
            if (runLength > SIZE_THRESHOLD_FOR_FIVE_BYTE_CASE) {
                // if the run's value is not already the most recent byte,
                // output the value as a literal
                if (inputDataBytes[currPos] != inputDataBytes[currPos - 1]) {
                    tags.add(new LZTag(currPos, NO_MATCH, 1, false));
                    currPos++;
                    runLength--;
                }
                // create a tag for the match starting on the run's first byte
                tags.add(new LZTag(currPos, currPos-1, runLength, true));
                currPos += runLength;

                // match might be at the end of the data block
                continue;
            }

            LZTag biggestMatch = getLargestMatch(inputDataString, MAX_DISTANCE_BACK, currPos);
            // if encoding run of the same byte as a 4 byte match or multiple 2
            // byte matches (can happen if given right combination of distance
            // back and match size), you can save a byte if it's after a lit:
            // 1 lit + 2 byte match < 4 byte match or multiple 2 byte matches
            //
            // [method: encode run's value as a literal (leech off overhead byte
            //  for previous lit) and do a 2 byte match starting after it]
            // note: if match follows another match, this would require 2 bytes
            //       for the literal (overhead byte, value itself); 2+2 bytes
            //       won't save any space over just encoding a 4 byte match
            int matchLength = biggestMatch.length;
            /*
            if (biggestMatch.getNumOverheadBytes() == 4 &&
                    runLength == biggestMatch.length && runLength > 1) {
            */
            if (((biggestMatch.getNumOverheadBytes() == 2 && runLength > matchLength) ||
                 (biggestMatch.getNumOverheadBytes() == 4 && runLength == matchLength)) &&
                  runLength > 1) {
                LZTag lastTag = tags.get(tags.size() - 1);
                if (!lastTag.isMatch) {
                    LZTag firstByte = new LZTag(currPos, NO_MATCH, 1, false);
                    LZTag restOfRun = new LZTag(currPos + 1, currPos, runLength - 1, true);
                    tags.add(firstByte);
                    tags.add(restOfRun);

                    currPos += runLength;
                    continue;
                }
            }

            ArrayList<LZTag> bestPath = new ArrayList<>();
            bestPath.add(biggestMatch);

            // sore spots for this logic: 0x203E in $5F8000, and that's about it
            LZTag limitedLookback = checkMatchesInLimitedLookback(biggestMatch);
            if (!biggestMatch.equals(limitedLookback)) {
                // System.out.println("Limited lookback @ 0x" + Integer.toHexString(currPos));
                bestPath = getBestPathFromTwoStartOptions(biggestMatch, limitedLookback, false);
            }
            if (bestPath.get(0).canOptimizeMatch()) {
                // System.out.println("Optimizable match @ 0x" + Integer.toHexString(currPos));
                boolean mostRecentTagWasForLits = !tags.isEmpty() && !tags.get(tags.size() - 1).isMatch;
                LZTag tag1 = bestPath.get(0);
                LZTag singleLitAtMatch = new LZTag(tag1.ptrToTag, tag1.ptrToMatch, 1, false);
                ArrayList<LZTag> bestPathFromLit = new ArrayList<>();
                bestPathFromLit.add(singleLitAtMatch);
                bestPath = getBestPathFromTwoPaths(bestPath, bestPathFromLit, mostRecentTagWasForLits);
            }

            tags.addAll(bestPath);
            currPos += getLengthOfPath(bestPath);
        }

        return tags;
    }

    private static ArrayList<LZTag> combineTags(ArrayList<LZTag> oldTags) {
        ArrayList<LZTag> tags = new ArrayList<>();
        tags.add(oldTags.get(0));
        for (int i = 1; i < oldTags.size(); i++) {
            LZTag tag = new LZTag(oldTags.get(i));

            // particular optimizations for Kamaitachi no Yoru:
            // a match up to size 0x100 & distance 0-0x80 is encoded in 2 bytes
            // a match up to size 0x100 & distance 0x81+  is encoded in 4 bytes
            // 1: 00 [dl dh] 00, or 01 [b0] ->          better as lits
            // 2: 00 [dl dh] 01, or 02 [b0 b1] ->       better as lits
            // 3: 00 [dl dh] 02, or 03 [b0 b1 b2] ->    equal as lits
            // 4: 00 [dl dh] 03, or 04 [b0 b1 b2 b3] -> it depends:
			// worse if surrounded by matches, equal if lits on either side

            // see if can combine with most recently added new tag
            LZTag lastTag = tags.get(tags.size() - 1);
            // combine two consecutive tags of literals
            // 0x7F size limit will be enforced in output to compressed data
            boolean consecLiteralTags = !tag.isMatch && !lastTag.isMatch;
            if (consecLiteralTags || (!lastTag.isMatch && tag.canOptimizeMatch())) {
                lastTag.length += tag.length;
            }
            else if (lastTag.canOptimizeMatch() && !tag.isMatch) {
                LZTag combinedLits = new LZTag(lastTag.ptrToTag, lastTag.ptrToMatch, lastTag.length + tag.length, false);
                tags.set(tags.size() - 1, combinedLits);
            }
            else {
                tags.add(tag);
            }
        }
        return tags;
    }

    /*
    private static void fixWronglyOptimizedFourByteMatches(ArrayList<LZTag> tags) {
        for (int i = 0; i < tags.size(); i++) {
            LZTag tag = tags.get(i);
            // check if the current tag is literals optimized from a match
            if (!tag.isMatch && tag.ptrToMatch != NO_MATCH) {
                // if yes, check if current tag is surrounded by matches
                // tags.get(-1) and tags.get(tags.size()) are out of bounds but
                // are considered to be matches for purposes of "is surrounded"
                // note the boolean short-circuiting
                boolean prevTagIsMatch = i == 0 || tags.get(i - 1).isMatch;
                boolean nextTagIsMatch = i == tags.size() - 1 || tags.get(i + 1).isMatch;
                if (prevTagIsMatch && nextTagIsMatch) {
                    // get back the original match that got optimized
                    LZTag oldMatch = getLargestMatch(inputDataString, MAX_DISTANCE_BACK, tag.ptrToTag);
                    // if original match and current lits tag both encode same
                    // # bytes and if encoding as a match is strictly smaller,
                    // restore the match from the "optimized" lits
                    int matchEncodingSize = oldMatch.getNumBytesForTagWhenCompressed();
                    int litsEncodingSize = tag.getNumBytesForTagWhenCompressed();
                    if (oldMatch.length == tag.length && matchEncodingSize < litsEncodingSize) {
                        tags.set(i, oldMatch);
                    }
                }
            }
        }
    }
    */

    // fill this in according to the particular game you are working on
    private static int generateCompressedFile(ArrayList<LZTag> tags) throws IOException {
        int currPos = 0;
        int compressedSize = 0;
        for (LZTag tag : tags) {
            if (!tag.isMatch) {
                // didn't limit tags for literals to be 0x7F or smaller, so have
                // to enforce that now; split up into groups of 0x7F or less
                int numTagsToOutput = tag.getNumTagsForLitsCase();
                int totalBytes = tag.length;
                for (int tagNum = 0; tagNum < numTagsToOutput; tagNum++) {
                    // determine how many literals to output for this tag:
                    // 0x7F for all but the last one, which is the remainder
                    int numBytes = 0;
                    if (tagNum == numTagsToOutput - 1) {
                        numBytes = totalBytes;
                    }
                    else {
                        numBytes = MAX_LITS_PER_TAG;
                        totalBytes -= MAX_LITS_PER_TAG;
                    }

                    // write # of bytes for indicator, then the raw data itself
                    outputFile.write(numBytes);
                    for (int i = 0; i < numBytes; i++) {
                        outputFile.write(inputDataBytes[currPos++]);
                    }
                }
                compressedSize += numTagsToOutput + tag.length;
            }
            else {
                currPos += tag.length;
                int dist = tag.getDistance();
				int encodedSize = tag.length - 1;
                // 0x101+ byte match, any distance back
                if (tag.length > SIZE_THRESHOLD_FOR_FIVE_BYTE_CASE) {
                    // [00] indicator byte
                    outputFile.write(0x00);

                    // write the distance back as two bytes
                    outputFile.write(dist & 0xFF);
                    outputFile.write((dist >> 8) & 0xFF);

                    // write the size as two bytes
                    outputFile.write(encodedSize & 0xFF);
                    outputFile.write((encodedSize >> 8) & 0xFF);
                }
                else {
                    // 0x01-0x100 byte match, at most 0x80 bytes back
                    if (dist <= DISTANCE_LIMIT_FOR_TWO_BYTE_CASE) {
                        // write negated distance back as 1 byte
                        dist = -dist;
                        outputFile.write(dist & 0xFF);

                        // write the size as one byte
                        outputFile.write(encodedSize & 0xFF);
                    }
                    // 0x01-0x100 byte match, over 0x80 bytes back
                    else {
                        // write [00] indicator byte
                        outputFile.write(0x00);

                        // write negated distance back as 2 bytes
                        dist = -dist;
                        outputFile.write(dist & 0xFF);
                        outputFile.write((dist >> 8) & 0xFF);

                        // write the size as one byte
                        outputFile.write(encodedSize & 0xFF);
                    }
                }
                compressedSize += tag.getNumOverheadBytes();
            }
        }

        // output the [00 00 00] termination sequence
        outputFile.write(0x00);
        outputFile.write(0x00);
        outputFile.write(0x00);

        compressedSize += 3;
        return compressedSize;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int recompressDataAtOffset(int cpuOffset) throws IOException {
        getInputDataAsArray(cpuOffset);
        return recompressInputData(String.format("$%06X.bin", cpuOffset));
    }

    private static int recompressFile(String inputFile) throws IOException {
        // allow using a wildcard like: java LZSSRecompress *.bin
        // however, do not compress any binary files that themselves are
        // the result of compressing a binary file with this program
        int folderPathLength = inputFile.lastIndexOf("/");
        String folderPath = folderPathLength == -1 ? "" : inputFile.substring(0, folderPathLength);
        String filename = inputFile.substring(folderPath.length() + 1);

        // System.out.println("Folder path: " + folderPath);
        // System.out.println("Filename: " + filename);

        if (filename.startsWith(FILE_PREFIX)) {
            return 0;
        }

        getInputDataAsArray(inputFile);
        if (inputDataBytes.length == 0) {
            System.out.println("You cannot compress an empty file.");
            return 0;
        }

        return recompressInputData(filename);
    }

    private static int recompressInputData(String outputFilename) throws IOException {
        buildReversedDataBuffer();

        ArrayList<LZTag> tags = getLZSSTags();
        ArrayList<LZTag> combinedTags = combineTags(tags);

        if (DEBUG) {
            String logFilename = OUTPUT_FOLDER + "LOG " + removeFileExtension(outputFilename) + ".txt";
            logFile = new BufferedWriter(new FileWriter(logFilename));

            // printTagsList(tags);
            // logFile.newLine();
            // logFile.newLine();

            printTagsList(combinedTags);
            logFile.flush();
            logFile.close();
        }

        outputFile = new FileOutputStream(OUTPUT_FOLDER + FILE_PREFIX + outputFilename);
        int compressedSize = generateCompressedFile(combinedTags);
        outputFile.close();

        return compressedSize;
    }

    public static void main(String args[]) throws IOException {
        if (args.length == 0) {
            System.out.println("Sample usage:");
            System.out.println("java LZSSRecompress --files data1.bin [data2.bin data3.bin ...]");
            System.out.println("--OR--");
            System.out.println("java LZSSRecompress --offsets cpuOffset1 [cpuOffset2 cpuOffset3 ...]");
            return;
        }

        int totalCompressedSize = 0;
        if (args[0].equals("--files")) {
            Files.createDirectories(Paths.get(OUTPUT_FOLDER));
            for (int i = 1; i < args.length; i++) {
                String inputFile = args[i];
                totalCompressedSize += recompressFile(inputFile);
            }
        }

        else if (args[0].equals("--offsets")) {
            Files.createDirectories(Paths.get(OUTPUT_FOLDER));
            for (int i = 1; i < args.length; i++) {
                int cpuOffset = Integer.parseInt(args[i], 16);
                totalCompressedSize += recompressDataAtOffset(cpuOffset);
            }
        }

        System.out.printf("Max lits, dist limit: 0x%X, 0x%X\n", MAX_LITS_PER_TAG, DISTANCE_LIMIT_FOR_TWO_BYTE_CASE);
        System.out.printf("Total size: 0x%X (%d)\n", totalCompressedSize, totalCompressedSize);
    }
}
