package huffman;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.PriorityQueue;
import java.util.Queue;

import static header_files.HelperMethods.*;
import static header_files.TextConstants.*;

public class GenerateHuffmanScript {

    private static final String ANALYSIS_FOLDER = "script/analysis";

    private static RandomAccessFile romFile;

    // -------------------------------------------------------------------------
    // Lists for how many and what types of arguments are there for control codes
    // -------------------------------------------------------------------------

    private static int asmCodeListIndices[] = new int[NUM_CTRL_CODES];
    private static int argMetadata[] = new int[NUM_CTRL_CODES];

    private static void getCtrlCodeArgTable() throws IOException {
        romFile.seek(CTRL_CODE_ARG_TBL);
        for (int i = 0; i < NUM_CTRL_CODES; i++) {
            asmCodeListIndices[i] = romFile.readUnsignedByte();
            argMetadata[i] = romFile.readUnsignedByte();
            romFile.readUnsignedByte();
            romFile.readUnsignedByte();
        }
    }

    // -------------------------------------------------------------------------
    // Table file's data structures and code
    // -------------------------------------------------------------------------

    /**
     * List of hex values for the entries in the table file. Stored as its own
     * array because there are gaps between values with assigned encodings.
     */
    private static ArrayList<Integer> tableHexValues;

    /**
     * Given a table file hex value, obtain its in-game character (or control code) representation.
     */
    private static HashMap<Integer, String> encodings;

    /**
     * Given a table file hex value, obtain the number of times it appears in the script as a control code input.
     */
    private static HashMap<Integer, Integer> ctrlCodeInputCounts;

    /**
     * Given a table file hex value, obtain the number of times it appears in the script.
     */
    private static HashMap<Integer, Integer> charCounts;

    private static void readTableFile(String tableFilename) {
        try {
            // assume file is sorted in increasing order by character code value
            BufferedReader tableFileStream = new BufferedReader(new FileReader(tableFilename));
            tableHexValues = new ArrayList<>(NUM_ENCODINGS);
            encodings = new HashMap<>(NUM_ENCODINGS);
            charCounts = new HashMap<>(NUM_ENCODINGS);
            ctrlCodeInputCounts = new HashMap<>(NUM_ENCODINGS);

            // basic format of a table file line is "[hex value]=[character]\n"
            String line;
            final String EQUAL = "=";
            while ((line = tableFileStream.readLine()) != null) {
                if (line.equals(""))
                    continue;

                String split[] = line.split(EQUAL);

                // ignore combination table entries for making script simpler
                if (split[0].length() > 4)
                    continue;

                int value = Integer.parseInt(split[0], 16);
                tableHexValues.add(value);

                // table entry may be for an equal sign; account for this
                if (split.length == 1) {
                    encodings.put(value, EQUAL);
                }
                else {
                    encodings.put(value, split[1]);
                }
                ctrlCodeInputCounts.put(value, 0);
                charCounts.put(value, 0);
            }

            tableFileStream.close();
        }
        catch (IOException e) {
            System.err.println(e.toString());
        }
        return;
    }

    /**
     * Either increment the number of occurrences for the given character encoding,
     * or (if not in the table file) add the character encoding to the table file
     * with a count of 1.
     * @param data the hex encoding for a character or control code
     */
    private static void incrementCount(int data, boolean isCtrlCodeInput) {
        data = data & 0x1FFF;

        Integer count = charCounts.getOrDefault(data, 0);
        if (charCounts.get(data) == null) {
            // System.out.println("Add to tbl file: 0x" + Integer.toHexString(data));
            tableHexValues.add(data);
        }
        charCounts.put(data, count + 1);

        if (isCtrlCodeInput) {
            count = ctrlCodeInputCounts.getOrDefault(data, 0);
            ctrlCodeInputCounts.put(data, count + 1);
        }
    }

    // -------------------------------------------------------------------------
    // Mnemonics for reading raw binary data from the script
    // -------------------------------------------------------------------------

    private static int readCharacter() throws IOException {
        int byte0 = romFile.readUnsignedByte();
        int byte1 = romFile.readUnsignedByte();
        return (byte0 << 8) | byte1;
    }

    private static int readPointer() throws IOException {
        int byte0 = romFile.readUnsignedByte();
        int byte1 = romFile.readUnsignedByte();
        int byte2 = romFile.readUnsignedByte();
        return (byte2 << 16) | (byte1 << 8) | byte0;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int getCPUOffset() throws IOException {
        int romOffset = (int) (romFile.getFilePointer() & 0xFFFFFF);
        return getRAMOffset(romOffset);
    }

    // -------------------------------------------------------------------------
    // determine frequencies of characters; needed for creating a Huffman coding
    // -------------------------------------------------------------------------

    private static int numPointers = 0;
    private static int scriptStart;
    private static int scriptEnd;

    /**
     * "Pointer table" = list of where all the pointers are in the uncompressed script.
     * Each is encoded as a linear file offset.
     */
    private static ArrayList<Integer> ptrLocations;
    /**
     * Given the location of a pointer in the uncompressed script, obtain its value
     * (to text in the uncompressed script), encoded as a 24-bit CPU LoROM offset.
     */
    private static HashMap<Integer, Integer> ptrValues;
    /**
     * Given the location of a pointer in the uncompressed script, obtain the
     * location of that pointer in the Huffman compressed script (encoded as a
     * 21+3 Huffman linear offset into the script = # bits into script).
     */
    private static HashMap<Integer, Integer> huffPtrLocations;
    /**
     * Given the location of a pointer in the uncompressed script, obtain the
     * value of that pointer in the Huffman compressed script (encoded as the
     * # of bits into script).
     */
    private static HashMap<Integer, Integer> huffPtrValues;

    /**
     * Given a position in the uncompressed script, obtain a set of locations of
     * pointers that have the given position as a value. Gets constructed when
     * counting characters and collecting pointers.
     */
    private static HashMap<Integer, HashSet<Integer>> ptrsWithPositionAsValue;

    private static void addToSetOfPtrsToLocation(int value, int location) {
        HashSet<Integer> locations = ptrsWithPositionAsValue.get(value);
        if (locations == null) {
            locations = new HashSet<>();
            ptrsWithPositionAsValue.put(value, locations);
        }
        locations.add(location);
    }

    private static void getDemoModeStartPoints() throws IOException {
        ptrLocations = new ArrayList<>();
        ptrValues = new HashMap<>();
        ptrsWithPositionAsValue = new HashMap<>();

        romFile.seek(ATTRACT_MODE_PTRS_LOCATION);
        for (int i = 0; i < NUM_ATTRACT_MODE_START_POINTS; i++) {
            int location = (int) romFile.getFilePointer();
            ptrLocations.add(location);

            int ptr = romFile.readUnsignedByte();
            ptr |= romFile.readUnsignedByte() << 8;
            ptr |= romFile.readUnsignedByte() << 16;
            ptrValues.put(ptrLocations.get(i), ptr);

            addToSetOfPtrsToLocation(ptr, location);
        }
    }

    private static void getSpecialPointersOutsideScript() throws IOException {
        for (int i = 0; i < SPECIAL_POINTERS_BANK_OFFSET_LOCATIONS.length; i++) {
            int romOffsetOfPointers = SPECIAL_POINTERS_BANK_OFFSET_LOCATIONS[i];
            romFile.seek(romOffsetOfPointers);

            ptrLocations.add(romOffsetOfPointers);

            int ptr = romFile.readUnsignedByte();
            ptr |= romFile.readUnsignedByte() << 8;
            ptr |= romFile.readUnsignedByte() << 16;
            ptrValues.put(romOffsetOfPointers, ptr);

            addToSetOfPtrsToLocation(ptr, romOffsetOfPointers);
        }
    }

    /**
     * Count the number of occurrences of all characters in the script, which is
     * necessary to create a Huffman encoding for the script. In the process,
     * this also gets data for all of the script pointers in the game.
     * @throws IOException
     */
    private static void countCharacters() throws IOException {
        System.out.println("Getting frequencies of characters...");
        romFile.seek(scriptStart);
        numPointers = NUM_ATTRACT_MODE_START_POINTS;

        // go to start of reinserted script and start reading characters
        while (romFile.getFilePointer() < scriptEnd) {
            // get a character and increment its # of occurrences
            int charEncoding = readCharacter();
            incrementCount(charEncoding, false);

            // if got a control code, have to count its non-pointer arguments
            // take note of the uncompressed pointers' positions and values
            if (isCtrlCode(charEncoding)) {
                int codeID = charEncoding & 0xFF;
                int numArgs = argMetadata[codeID] & 0x3;
                int argTypes = argMetadata[codeID] >> 2;

                // choices are special cases that the regular algorithm doesn't cover
                if (isChoiceCode(charEncoding)) {
                    // choice codes take # of arguments in list, N, and use
                    // N+3 as # of Huffman codes, and N+2 as # of pointers
                    int numChoiceArgs = numArgs + 3;
                    for (int i = 0; i < numChoiceArgs; i++) {
                        incrementCount(readCharacter(), true);
                    }

                    int numPtrs = numArgs + 2;
                    for (int i = 0; i < numPtrs; i++) {
                        int location = (int) romFile.getFilePointer();
                        int value = readPointer();

                        ptrLocations.add(location);
                        ptrValues.put(location, value);
                        addToSetOfPtrsToLocation(value, location);
                        numPointers++;
                    }
                }

                // get # of arguments and interpret each one properly
                else {
                    for (int i = 0; i < numArgs; i++) {
                        switch (argTypes & 0x1) {
                            case CHAR_ARG:
                                incrementCount(readCharacter(), true);
                                break;
                            case PTR_ARG:
                                int location = (int) romFile.getFilePointer();
                                int value = readPointer();

                                ptrLocations.add(location);
                                ptrValues.put(location, value);
                                addToSetOfPtrsToLocation(value, location);
                                numPointers++;
                                break;
                        }
                        argTypes >>= 1;
                    }
                }

                // indicate general progress as program runs
                if (charEncoding == END_GAME_18) {
                    String format = "Found 'END GAME 18' @ [$%06X]";
                    System.out.println(String.format(format, getCPUOffset()));
                }
            }
        }
        System.out.println("Done");
    }

    private static void outputCountsToTextFile(String romPath) throws IOException {
        // if filename contains path to file, remove the names of all folders
        int lastSlashIndex = romPath.lastIndexOf("\\");
        String romName = romPath;
        if (lastSlashIndex != -1) {
            romName = romPath.substring(lastSlashIndex + 1);
        }

        String charCountsFile = ANALYSIS_FOLDER + "/char counts for '" + romName + "'.txt";
        BufferedWriter charCountsOutput = new BufferedWriter(new FileWriter(charCountsFile));

        String tableHeader = "       | number | number |        |\n" +
                             " value | inputs | chars  | total  | encoding\n" +
                             "-------+--------+--------+--------+----------\n";
        charCountsOutput.write(tableHeader);

        Collections.sort(tableHexValues);
        String format = " %04X  | %6d | %6d | %6d | %s\n";
        for (Integer tblValue : tableHexValues) {
            int numCodeInputs = ctrlCodeInputCounts.get(tblValue);
            int total = charCounts.get(tblValue);
            int numChars = total - numCodeInputs;
            String outputLine = String.format(format, tblValue, numCodeInputs, numChars, total, encodings.get(tblValue));
            charCountsOutput.write(outputLine);
        }

        charCountsOutput.flush();
        charCountsOutput.close();
    }

    // may not need this, they also get output when outputting their equivalent
    // compressed pointers; keep if you need to change something and want to debug
    /*
    private static void outputUncompPtrs() throws IOException {
        BufferedWriter pointerInfo = new BufferedWriter(new FileWriter(ANALYSIS_FOLDER + "/uncomp pointer info.txt"));

        for (Integer ptrLoc : ptrLocations) {
            Integer ptrVal = ptrValues.get(ptrLoc);
            String format = "0x%05X -> $%06X\n";
            pointerInfo.write(String.format(format, ptrLoc, ptrVal));
        }

        pointerInfo.flush();
        pointerInfo.close();
    }
    */

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    /* Note about this implementation: Huffman codes are stored primarily as ints
     * with their lengths separate, and secondarily as Strings of binary digits.
     * You may or may not need to use 64-bit longs instead of 32-bit ints.
     */

    /**
     * Given a table file hex value, obtain its Huffman code as a numeric value.
     */
    private static HashMap<Integer, Integer> huffmanCodesBits;
    /**
     * Given a table file hex value, obtain the length of its Huffman code.
     */
    private static HashMap<Integer, Integer> huffmanCodeLengths;
    /**
     * Given a table file hex value, obtain its Huffman code as a String of bits.
     */
    private static HashMap<Integer, String> huffmanCodes;

    private static class HuffmanNode implements Comparable<HuffmanNode> {
        private int hexValue;
        private int count;
        private HuffmanNode left;
        private HuffmanNode right;

        public HuffmanNode(int hexValue, int count) {
            this.hexValue = hexValue;
            this.count = count;
            left = null;
            right = null;
        }

        // natural ordering: sort by frequencies, break ties using hex values
        public int compareTo(HuffmanNode other) {
            int compareCounts = count - other.count;
            if (compareCounts != 0) {
                return compareCounts;
            }
            return hexValue - other.hexValue;
        }

        public boolean isLeaf() {
            return left == null && right == null;
        }
    }

    /**
     * Given that each character's number of occurrences has been counted,
     * generate the Huffman tree from all the characters used in the script.
     * @return the root of the generated Huffman tree
     */
    private static HuffmanNode createHuffmanTree() {
        PriorityQueue<HuffmanNode> q = new PriorityQueue<>(tableHexValues.size());
        for (Integer hexValue : tableHexValues) {
            Integer count = charCounts.get(hexValue);
            if (count != null && count != 0) {
                q.add(new HuffmanNode(hexValue, count));
            }
        }

        while (q.size() > 1) {
            HuffmanNode first = q.remove();
            HuffmanNode second = q.remove();
            HuffmanNode combine = new HuffmanNode(NO_HEX_VAL, first.count + second.count);
            combine.left = first;
            combine.right = second;
            q.add(combine);
        }

        return q.poll();
    }

    private static int getNumHuffmanEntries(HuffmanNode root) {
        // An array index corresponds to a particular non-leaf node in the tree.
        //     -0-      Left: An example indexing for a perfect 3 level tree.
        //    /   \     Goal: start at root, go left to right at each level
        //   1     2          and assign a unique value to each non-leaf.
        //  / \   / \   Basic breadth first traversal, so use a queue.
        // x   x x   x
        Queue<HuffmanNode> traversal = new LinkedList<>();

        // first, determine how many non-leaves are in the tree, to know how
        // much space the tree will take in the game
        traversal.add(root);
        int numEntries = 0;
        while (!traversal.isEmpty()) {
            HuffmanNode node = traversal.poll();
            if (!node.isLeaf()) {
                numEntries++;
                if (node.left != null)
                    traversal.add(node.left);
                if (node.right != null)
                    traversal.add(node.right);
            }
        }

        // print a warning if too many non-leaves in the tree; hopefully not an
        // issue since 0x6F2 = 1778 and English uses a smaller "alphabet",
        // but this may still happen
        if (numEntries > MAX_NUM_HUFFMAN_ENTRIES) {
            System.out.println("WARNING: Huffman tree will not fit in original space");
            String format = "Used 0x%X non-leaf nodes of 0x%X";
            System.out.println(String.format(format, numEntries, MAX_NUM_HUFFMAN_ENTRIES));
        }
        return numEntries;
    }

    private static HashMap<HuffmanNode, Integer> assignIndexNumberToAllInnerNodes(int numEntries, HuffmanNode root) {
        // assign a unique number to all the non-leaves as above; note that the
        // game expects root to be at the end, so go in decreasing order to match
        int dataIndex = numEntries - 1;
        HashMap<HuffmanNode, Integer> dataIndexForNode = new HashMap<>();

        Queue<HuffmanNode> traversal = new LinkedList<>();
        traversal.add(root);
        while (!traversal.isEmpty()) {
            HuffmanNode node = traversal.poll();

            if (!node.isLeaf()) {
                // assign monotonically decreasing value to each non-leaf
                dataIndexForNode.put(node, dataIndex);
                dataIndex--;

                // add the non-null subtrees to the queue
                HuffmanNode left = node.left;
                if (left != null) {
                    traversal.add(left);
                }

                HuffmanNode right = node.right;
                if (right != null) {
                    traversal.add(right);
                }
            }
        }
        return dataIndexForNode;
    }

    /**
     * "Flatten out" the Huffman tree into a linear data block in the format
     * that the game expects, and output the data block to a binary file.
     * @param root the root of the Huffman tree
     */
    private static int[][] convertTreeToGameFormat(HuffmanNode root) {
        // target data format: two linear data blocks each with <= 0x6F2 entries
        // for how to navigate the Huffman tree; take all of the non-leaf nodes
        // improvement: use only as many entries as necessary and do an ASM edit
        // to alter root position, plus trees' size and pointers

        int numEntries = getNumHuffmanEntries(root);
        HashMap<HuffmanNode, Integer> dataIndexForNode = assignIndexNumberToAllInnerNodes(numEntries, root);

        // with all the values collected, fill in the data arrays
        int leftSubtreeData[] = new int[numEntries];
        int rightSubtreeData[] = new int[numEntries];

        Queue<HuffmanNode> traversal = new LinkedList<>();
        traversal.add(root);
        while (!traversal.isEmpty()) {
            HuffmanNode node = traversal.poll();
            int position = dataIndexForNode.get(node);

            if (!node.isLeaf()) {
                // WLOG, check left node; only add to queue if not a leaf (and not null);
                // if a leaf, data format is to use left node's hex value | 0x8000
                // otherwise, set node's left data entry to "point to" the left subtree
                HuffmanNode left = node.left;
                if (left != null) {
                    if (!left.isLeaf()) {
                        traversal.add(left);
                        leftSubtreeData[position] = dataIndexForNode.get(left) << 1;
                        // note left shift with data indices -- lone difference from Otogirisou
                    }
                    else {
                        leftSubtreeData[position] = node.left.hexValue | 0x8000;
                    }
                }

                HuffmanNode right = node.right;
                if (right != null) {
                    if (!right.isLeaf()) {
                        traversal.add(right);
                        rightSubtreeData[position] = dataIndexForNode.get(right) << 1;
                    }
                    else {
                        rightSubtreeData[position] = right.hexValue | 0x8000;
                    }
                }
            }
        }

        int subtreeData[][] = {leftSubtreeData, rightSubtreeData};
        return subtreeData;
    }

    private static void outputConvertedHuffmanTreeToFile(int subtreeData[][]) throws IOException {
        // data all filled in, so output it to a file that can be incorporated
        // into a "write binary file's contents into ROM" script
        // write each 2 byte entry in little endian format
        int leftSubtreeData[] = subtreeData[0];
        int rightSubtreeData[] = subtreeData[1];

        String huffmanOutputFile = "script/huffman tree - game data format.bin";
        FileOutputStream huffmanTreeDataBlock = new FileOutputStream(huffmanOutputFile);
        for (int entry : rightSubtreeData) {
            huffmanTreeDataBlock.write(entry & 0xFF);
            huffmanTreeDataBlock.write((entry >> 8) & 0xFF);
        }
        for (int entry : leftSubtreeData) {
            huffmanTreeDataBlock.write(entry & 0xFF);
            huffmanTreeDataBlock.write((entry >> 8) & 0xFF);
        }
        huffmanTreeDataBlock.close();

        String status = "Huffman tree (0x%X entries) converted to game format is in '%s'";
        System.out.println(String.format(status, leftSubtreeData.length, huffmanOutputFile));
    }

    /**
     * Perform a depth-first traversal of the Huffman tree to generate all the
     * Huffman codes as binary Strings.
     * @param node the Huffman node to examine
     * @param code the Huffman code for how to traverse the tree to reach this particular node
     */
    private static void collectHuffmanCodeStrings(HuffmanNode node, String code) {
        if (node == null) {
            return;
        }
        if (node.left == null && node.right == null) {
            huffmanCodes.put(node.hexValue, code);
            return;
        }
        // assemble bits for the code from left to right with Strings
        collectHuffmanCodeStrings(node.left, code + LEFT_BIT);
        collectHuffmanCodeStrings(node.right, code + RIGHT_BIT);
    }

    /**
     * Perform a depth-first traversal of the Huffman tree to generate all the
     * Huffman codes as numeric values.
     * @param node the Huffman node to examine
     * @param codeSoFar the Huffman code for how to traverse the tree to reach this particular node
     * @param length the depth of the current Huffman node
     */
    private static void collectHuffmanCodeBits(HuffmanNode node, int codeSoFar, int length) {
        if (node == null) {
            return;
        }
        if (node.left == null && node.right == null) {
            // print a basic warning about whether longs are needed
            if (length >= 32) {
                String message = "WARNING: 0x%04X has Huff code of length %2d > 32; need longs instead of ints";
                System.out.println(String.format(message, node.hexValue, length));
            }
            huffmanCodesBits.put(node.hexValue, codeSoFar);
            huffmanCodeLengths.put(node.hexValue, length);
            return;
        }

        // important difference from String implementation:
        // assemble the bits starting from the LSB of the int variable
        // i.e. from "right to left" instead of "left to right" as with Strings
        // purpose: make the "write bits to script" function easier
        int leftCode = codeSoFar | (LEFT_BIT_INT << length);
        int rightCode = codeSoFar | (RIGHT_BIT_INT << length);
        collectHuffmanCodeBits(node.left, leftCode, length + 1);
        collectHuffmanCodeBits(node.right, rightCode, length + 1);
    }

    /**
     * Output the Huffman codes for each character in the Huffman tree to a
     * text file.
     * @param root the root of the Huffman tree
     * @throws IOException
     */
    private static void printHuffmanCodes(HuffmanNode root) throws IOException {
        int numHuffCodes = tableHexValues.size();
        huffmanCodes = new HashMap<>(numHuffCodes);
        huffmanCodesBits = new HashMap<>(numHuffCodes);
        huffmanCodeLengths = new HashMap<>(numHuffCodes);

        for (Integer hexValue : tableHexValues) {
            huffmanCodes.put(hexValue, "");
            huffmanCodesBits.put(hexValue, 0);
            huffmanCodeLengths.put(hexValue, 0);
        }
        collectHuffmanCodeStrings(root, "");
        collectHuffmanCodeBits(root, 0x0, 0);

        BufferedWriter huffmanWriter = new BufferedWriter(new FileWriter(ANALYSIS_FOLDER + "/huffman output.txt"));
        huffmanWriter.write("  #   | count  | Huffman code (size and bits)  | encoding\n");
        huffmanWriter.write("------+--------+-------------------------------+------------\n");
        String lineFormat = " %04X | %6d | %2d bits: %-20s | \"%s\"\n";
        for (Integer hexVal : tableHexValues) {
            String huffCode = huffmanCodes.get(hexVal);
            if (huffCode != null && !huffCode.equals("")) {
                // if no available encoding for hex value, use the value itself
                // in brackets as the String encoding (only used as code input)
                String encoding = encodings.get(hexVal);
                if (encoding == null) {
                    encoding = String.format("[%04X]", hexVal);
                }

                int charCount = charCounts.get(hexVal);
                // String format = "0x%04X '%s' has %2d bit Huff code: %s";
                huffmanWriter.write(String.format(lineFormat, hexVal, charCount, huffCode.length(), huffCode, encoding));
            }
            /*
            else {
                String format = "No Huff code for 0x%04X";
                huffmanWriter.write(String.format(format, hexVal));
                huffmanWriter.newLine();
            }
            */
        }
        huffmanWriter.flush();
        huffmanWriter.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    /**
     * A data block that represents the Huffman compressed script.
     */
    private static RandomAccessFile huffmanScript;
    /**
     * An eight bit buffer for accumulating together bits of Huffman codes to be
     * inserted into the Huffman script.
     */
    private static int huffmanBuffer;
    /**
     * The current bit position (0 to 7) for where to bitwise OR in a bit of a
     * Huffman code.
     */
    private static int huffmanBitOffset;

    /*
    private static void writeHuffmanCodeStringToScript(int hexValue) throws IOException {
        String huffCode = huffmanCodes.get(hexValue);
        for (int i = 0; i < huffCode.length(); i++) {
            // read one bit at a time and write it into a one byte buffer
            // ASCII: '0' = 0x30, '1' = 0x31; simply subtract value of '0' for corresponding bit value
            int bit = huffCode.charAt(i) - '0';
            huffmanBuffer |= (bit << huffmanBitOffset);

            huffmanBitOffset = (huffmanBitOffset + 1) & 0x7;
            if (huffmanBitOffset == 0) {
                huffmanScript.writeByte(huffmanBuffer);
                huffmanBuffer = 0;
            }
        }
    }
    */

    /**
     * Write the bits of the Huffman code for the specified character into the
     * Huffman script.
     * @param hexValue a 16-bit character encoding
     * @throws IOException
     */
    private static void writeHuffmanCodeToScript(int hexValue) throws IOException {
        int huffCode = huffmanCodesBits.get(hexValue);
        int length = huffmanCodeLengths.get(hexValue);

        // combine the Huffman code (assume up to 32 bits; in practice up to 20)
        // with the current state of the Huffman buffer (up to 7 bits) into a long
        long combinedBuffer = huffmanBuffer | (((long) huffCode) << huffmanBitOffset);
        // int combinedBuffer = huffmanBuffer | (huffCode << huffmanBitOffset);
        int combinedSize = length + huffmanBitOffset;

        // write as many groups of 8 bits as possible
        while (combinedSize >= NUM_BITS_IN_BYTE) {
            int dataByte = (int) (combinedBuffer & 0xFF);
            huffmanScript.write(dataByte);
            combinedSize -= NUM_BITS_IN_BYTE;
            combinedBuffer >>= NUM_BITS_IN_BYTE;
        }
        huffmanBuffer = (int) (combinedBuffer & 0xFF);
        // huffmanBuffer = combinedBuffer & 0xFF;
        huffmanBitOffset = combinedSize;
    }

    /**
     * Insert placeholder 00 bits into the Huffman script where pointers should
     * later have their values inserted.
     * @throws IOException
     */
    private static void padScriptWithZeroesForPointer() throws IOException {
        // this method is intended to be run as Huffman pointers are being collected
        // it assumes the current Huffman buffer and bit offset are accurate; 'x' = "don't care" bit
        // little endian: [0000]xxxx [00000000] [00000000] xxxx[0000] ; bit offset = 4
        // special case:  [00000000] [00000000] [00000000] xxxxxxxx   ; bit offset = 0

        // since unfilled bits in the buffer are 0, can just write current state and two bytes
        huffmanScript.writeByte(huffmanBuffer);
        huffmanScript.writeByte(0x00);
        huffmanScript.writeByte(0x00);

        // after this, have to set huffman buffer to 0, which gets filled with the
        // next character's bits, or the next pointer's placeholder bytes
        huffmanBuffer = 0;
    }

    /**
     * Determine the size of the Huffman script (all characters and pointers)
     * in bits.
     */
    private static int calculateHuffmanScriptSize() {
        // note: this calculates the size in bits because of Huffman coding
        // for sense of scale, original JP Huffman script is from AE401 - F95A7
        // (4B1A7 bytes = 258D38 bits); size should fit within a Java 32-bit int

        int size = numPointers * NUM_BITS_IN_PTR;
        for (Integer hexValue : tableHexValues) {
            size += huffmanCodeLengths.get(hexValue) * charCounts.get(hexValue);
        }
        return size;
    }

    /**
     * Once all the Huffman codes have been generated, write all the Huffman
     * codes into a file that represents the Huffman script. Space for Huffman
     * pointers get filled with placeholder 00 bytes, because cannot know all
     * their locations and values until done running through the whole script.
     * @throws IOException
     */
    private static void generateHuffmanScript() throws IOException {
        // given that we have created the Huffman tree and gotten all the codes,
        // walk the uncompressed script and determine where we need to insert
        // pointer values between the Huffman codes; may as well also calculate pointer targets
        romFile.seek(scriptStart);
        huffmanScript = new RandomAccessFile("script/huffman script.bin", "rw");
        huffPtrLocations = new HashMap<>();
        huffPtrValues = new HashMap<>();

        // initialize the Huffman buffer
        huffmanBuffer = 0;
        huffmanBitOffset = 0;

        // calculate the size of the script in bits; note that as we go along,
        // this also represents our current position in the Huffman script
        int compressedSize = 0;

        // keep track of how many start points we have found, as well as which
        // one we should be looking for; the pointer table in original JP ROM:
        // $06DA04-2, $0C9FA1-2, $06BDAB-7, $0BD1FA-4, $068E36-5
        // sorted by values, order is 5th, 3rd, 1st, 4th, 2nd
        int numStartPointsFound = 0;
        int startPointsToLookFor[] = {4, 2, 0, 3, 1};

        // keep track of how many special pointers we have found, as well as which
        // one we should be looking for; list of pointers sorted by value:
        // $008B0A < $01CE6D < $008AA6 = $008E5D = $01CE7E < $008F44 = $049A6C
        int numSpecialPointersFound = 0;
        int specialPointersToLookFor[] = {1, 4, 0, 2, 5, 3, 6};
        for (int i = 0; i < specialPointersToLookFor.length; i++) {
            specialPointersToLookFor[i] = specialPointersToLookFor[i] + INDEX_FOR_FIRST_SPECIAL_POINTER;
        }

        System.out.println("Now collecting Huffman pointer locations and values...");
        while (romFile.getFilePointer() < scriptEnd) {
            // as we walk the uncompressed script, get a list of locations for
            // all the equivalent Huffman pointers
            int filePos = (int) romFile.getFilePointer();

            // check to see if we are at one of the start points for demo play
            if (numStartPointsFound < NUM_ATTRACT_MODE_START_POINTS) {
                int startPointToLookFor = startPointsToLookFor[numStartPointsFound];
                int startLoc = ptrLocations.get(startPointToLookFor);
                int startLocationValue = ptrValues.get(startLoc);

                if (startLocationValue == getCPUOffset()) {
                    huffPtrLocations.put(startLoc, compressedSize);

                    String format = "Huffman script 0x%5X-%d: Demo play start point #%d";
                    System.out.println(String.format(format, compressedSize >> 3, compressedSize & 0x7, startPointToLookFor));

                    numStartPointsFound++;
                }
            }

            // check to see if we are at one of the special pointers
            while (numSpecialPointersFound < NUM_SPECIAL_POINTERS) {
                int specialPointerToLookFor = specialPointersToLookFor[numSpecialPointersFound];
                int startLoc = ptrLocations.get(specialPointerToLookFor);
                int startLocationValue = ptrValues.get(startLoc);
                if (startLocationValue != getCPUOffset()) {
                    break;
                }
                huffPtrLocations.put(startLoc, compressedSize);

                String format = "Huffman script 0x%5X-%d: Target for special ptr @ 0x%6X";
                System.out.println(String.format(format, compressedSize >> 3, compressedSize & 0x7, startLoc));

                numSpecialPointersFound++;
            }

            // we can also get Huffman pointers' values in the same loop
            // first check if we are at the target/value of an embedded pointer
            // in the uncompressed script; convert linear ROM file offset to CPU offset
            int currCPUOffset = getCPUOffset();
            if (ptrValues.containsValue(currCPUOffset)) {
                // get all uncompressed pointers that have the current position
                // as a target and set the equivalent Huffman pointers' targets
                // to the current script size

                HashSet<Integer> ptrsWithTarget = ptrsWithPositionAsValue.get(currCPUOffset);
                for (Integer ptr : ptrsWithTarget) {
                    huffPtrValues.put(ptr, compressedSize);
                }
            }

            // get character, write Huffman code to script, update Huffman position
            int charEncoding = readCharacter();
            // writeHuffmanCodeStringToScript(charEncoding);
            writeHuffmanCodeToScript(charEncoding);
            compressedSize += huffmanCodeLengths.get(charEncoding);

            // if got a control code, we need to do two things:
            // - for non-pointer arguments, insert their Huffman codes
            // - for pointer arguments, note their locations in the script, and
            //   insert 24 placeholder 0 bits to properly align the data
            if (isCtrlCode(charEncoding)) {
                int codeID = charEncoding & 0xFF;
                int numArgs = argMetadata[codeID] & 0x3;
                int argTypes = argMetadata[codeID] >> 2;

                if (isChoiceCode(charEncoding)) {
                    // choice codes take # of arguments in list, N, and use
                    // N+3 as # of Huffman codes, and N+2 as # of pointers
                    int numChoiceArgs = numArgs + 3;
                    for (int i = 0; i < numChoiceArgs; i++) {
                        int choiceArgs = readCharacter();
                        // writeHuffmanCodeStringToScript(choiceArgs[i]);
                        writeHuffmanCodeToScript(choiceArgs);
                        compressedSize += huffmanCodeLengths.get(choiceArgs);
                    }

                    int numPtrs = numArgs + 2;
                    for (int i = 0; i < numPtrs; i++) {
                        // to handle a pointer, take note of current position
                        // in Huffman script; pad with 0s for alignment;
                        // update Huffman script's size
                        filePos = (int) romFile.getFilePointer();
                        if (ptrLocations.contains(filePos)) {
                            huffPtrLocations.put(filePos, compressedSize);
                        }
                        // read bytes but ignore value; got when creating Huff tree
                        readPointer();

                        padScriptWithZeroesForPointer();
                        compressedSize += NUM_BITS_IN_PTR;
                    }
                }

                // otherwise, get # args and interpret each one properly
                else {
                    for (int i = 0; i < numArgs; i++) {
                        switch (argTypes & 0x1) {
                            case CHAR_ARG:
                                int arg = readCharacter();
                                // writeHuffmanCodeStringToScript(arg);
                                writeHuffmanCodeToScript(arg);
                                compressedSize += huffmanCodeLengths.get(arg);
                                break;
                            case PTR_ARG:
                                filePos = (int) romFile.getFilePointer();
                                if (ptrLocations.contains(filePos)) {
                                    huffPtrLocations.put(filePos, compressedSize);
                                }
                                readPointer();
                                padScriptWithZeroesForPointer();
                                compressedSize += NUM_BITS_IN_PTR;
                                break;
                        }
                        argTypes >>= 1;
                    }
                }

                // for debugging purposes only, indicate progress
                if (charEncoding == END_GAME_18) {
                    String format = "Huffman script 0x%5X-%d: 'END GAME 18'";
                    System.out.println(String.format(format, compressedSize >> 3, compressedSize & 0x7));
                }
            }
        }
        System.out.println(String.format("\nGot to position 0x%06X in uncomp script", romFile.getFilePointer()));
        String format = "Finished getting Huffman pointers - %d locations, %d values.";
        System.out.println(String.format(format, huffPtrLocations.size(), huffPtrValues.size()));
    }

    /**
     * Output the Huffman pointer values for the five demo play start points' to
     * their own file.
     * Note: The game expects the start points to use an absolute pointer format
     * (21 bit CPU offset, 3 bit "bit in byte" offset). However, this requires
     * knowing where the script will be inserted in the ROM, so that calculation
     * is left up to an Asar assembly file later.
     * @throws IOException
     */
    private static void insertStartPoints() throws IOException {
        FileOutputStream startPointData = new FileOutputStream("script/start points' script offsets.bin");
        for (int i = 0; i < NUM_ATTRACT_MODE_START_POINTS; i++) {
            int ptrLocation = ptrLocations.get(i);
            int huffScriptOffset = huffPtrLocations.get(ptrLocation);

            // list is contiguous, so can just write the Huffman offsets themselves
            startPointData.write(huffScriptOffset & 0xFF);
            startPointData.write((huffScriptOffset >> 8) & 0xFF);
            startPointData.write((huffScriptOffset >> 16) & 0xFF);
        }
        startPointData.close();
        System.out.println("Script offsets for the five demo play start points are in \"script/start points' script offsets.bin\"");

        FileOutputStream specialPointerData = new FileOutputStream("script/special pointers' script offsets.bin");
        for (int i = 0; i < NUM_SPECIAL_POINTERS; i++) {
            int specialPtrIndex = i + INDEX_FOR_FIRST_SPECIAL_POINTER;
            int ptrLocation = ptrLocations.get(specialPtrIndex);
            int huffScriptOffset = huffPtrLocations.get(ptrLocation);

            // list is NOT contiguous, so need to write the offsets themselves,
            // as well as where to write them
            int ptrLocationCPUOffset = getRAMOffset(ptrLocation);
            specialPointerData.write(ptrLocationCPUOffset & 0xFF);
            specialPointerData.write((ptrLocationCPUOffset >> 8) & 0xFF);
            specialPointerData.write((ptrLocationCPUOffset >> 16) & 0xFF);

            specialPointerData.write(huffScriptOffset & 0xFF);
            specialPointerData.write((huffScriptOffset >> 8) & 0xFF);
            specialPointerData.write((huffScriptOffset >> 16) & 0xFF);
        }
        specialPointerData.close();
        System.out.println("Script offsets for the six special pointers are in \"script/special pointers' script offsets.bin\"");
    }

    /**
     * Once we know the locations and values for all of the Huffman pointers,
     * insert their values at the correct locations in the script.
     * @throws IOException
     */
    private static void insertEmbeddedPtrs() throws IOException {
        System.out.println("Now inserting Huffman pointers into script...");

        for (int i = NUM_POINTERS_OUTSIDE_SCRIPT; i < ptrLocations.size(); i++) {
            int ptrLocation = ptrLocations.get(i);
            int huffPtrLocation = huffPtrLocations.get(ptrLocation);
            int locationBytes = huffPtrLocation >> 3;
            int locationBits = huffPtrLocation & 0x7;

            // take the pointer value and shift it left based on the location's bit offset
            int huffPtrValue = huffPtrValues.get(ptrLocation);
            huffPtrValue <<= locationBits;

            // "peek" the byte where we have to insert the pointer
            huffmanScript.seek(locationBytes);
            int currByte = huffmanScript.readUnsignedByte();
            huffmanScript.seek(locationBytes);

            // write (bit_offset) bits of the pointer into the first byte
            huffmanScript.writeByte((huffPtrValue & 0xFF) | currByte);

            // the next two bytes should be [00] because space for pointers was
            // padded with [00] bytes, so just write the data as-is without ORs
            huffmanScript.writeByte((huffPtrValue >> 8) & 0xFF);
            huffmanScript.writeByte((huffPtrValue >> 16) & 0xFF);

            // the last byte should get the pointer's last (8 - bit_offset) bits

            // special case if at EOF: doing seek() to EOF won't let you output
            // the last byte of the Huffman pointer here
            currByte = 0;
            if (huffmanScript.getFilePointer() < huffmanScript.length() - 1) {
                long pos = huffmanScript.getFilePointer();
                currByte = huffmanScript.readUnsignedByte();
                huffmanScript.seek(pos);
            }
            huffmanScript.writeByte((huffPtrValue >> 24) | currByte);
        }
        huffmanScript.close();
        System.out.println("Done.");
    }

    /**
     * Generate a text file that shows how the pointers in the uncompressed script
     * are converted into pointers in the Huffman compressed script.
     */
    private static void outputPointerInfo() throws IOException {
        BufferedWriter pointerInfo = new BufferedWriter(new FileWriter(ANALYSIS_FOLDER + "/pointer info.txt"));
        for (Integer ptrLoc : ptrLocations) {
            Integer ptrVal = ptrValues.get(ptrLoc);
            Integer huffPtrLoc = huffPtrLocations.get(ptrLoc);
            Integer huffPtrVal = huffPtrValues.get(ptrLoc);
            String format = "0x%05X -> $%06X --- 0x%5X-%d -> 0x%6X-%d\n";
            pointerInfo.write(String.format(format, ptrLoc, ptrVal, huffPtrLoc >> 3, huffPtrLoc & 0x7, huffPtrVal >> 3, huffPtrVal & 0x7));
        }

        pointerInfo.flush();
        pointerInfo.close();
    }

    /**
     * Generate a text file that details how much space is saved by compressing
     * the script into Huffman format.
     */
    private static void analyzeCompression() throws IOException {
        BufferedWriter compressionFile = new BufferedWriter(new FileWriter(ANALYSIS_FOLDER + "/compression analysis.txt"));

        int uncompressedSize = scriptEnd - scriptStart + 1;
        String format0 = "Uncompressed script: %d bits = 0x%X bytes";
        compressionFile.write(String.format(format0, uncompressedSize * NUM_BITS_IN_BYTE, uncompressedSize));
        compressionFile.newLine();

        int compressedSize = calculateHuffmanScriptSize();
        int leftoverBits = compressedSize & 0x7;
        int compressedSizeBytes = compressedSize >> 3;
        String format1 = "Compressed script:   %d bits = 0x%X-%d bytes (theoretical)";
        compressionFile.write(String.format(format1, compressedSize, compressedSizeBytes, leftoverBits));
        compressionFile.newLine();

        int allScriptPtrSize = numPointers * NUM_BITS_IN_PTR;
        String format2 = "%d pointers -> %d bits (0x%X bytes)";
        compressionFile.write(String.format(format2, numPointers, allScriptPtrSize, allScriptPtrSize >> 3));
        compressionFile.newLine();

        int uncompSizeNoPtrs = uncompressedSize * NUM_BITS_IN_BYTE - allScriptPtrSize;
        int compSizeNoPtrs = compressedSize - allScriptPtrSize;
        String format3 = "Not counting pointers,  %d bits vs. %d bits -> %2.2f%% compression.";
        double compRatio3 = 100.0 * ((double) compSizeNoPtrs) / ((double) uncompSizeNoPtrs);
        compressionFile.write(String.format(format3, uncompSizeNoPtrs, compSizeNoPtrs, compRatio3));
        compressionFile.newLine();

        String format4 = "When counting pointers, %d bits vs. %d bits -> %2.2f%% compression.";
        int uncompressedSizeBits = uncompressedSize * NUM_BITS_IN_BYTE;
        double compRatio4 = 100.0 * ((double) compressedSize) / ((double) (uncompressedSizeBits));
        compressionFile.write(String.format(format4, uncompressedSizeBits, compressedSize, compRatio4));
        compressionFile.newLine();

        compressionFile.flush();
        compressionFile.close();

        System.out.println("Huffman compression analysis details are in 'compression analysis.txt'");
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    public static void main(String args[]) throws IOException {
        if (args.length != 3) {
            System.out.println("Sample usage: java GenerateHuffmanScript rom_name table_file script_start");
            return;
        }
        /*
        if (args.length != 4) {
            System.out.println("Sample usage: java GenerateHuffmanScript rom_name table_file script_start script_end");
            return;
        }
        */

        String romFilename = args[0];
        String tableFilename = args[1];
        scriptStart = Integer.parseInt(args[2], 16);

        File f = new File(romFilename);
        scriptEnd = (int) f.length();
        
        // scriptEnd = Integer.parseInt(args[3], 16);

        /*
        if (scriptStart >= scriptEnd) {
            System.out.println("Error - script end point must be after script start point");
            System.exit(1);
            return;
        }
        */

		romFile = new RandomAccessFile(romFilename, "r");

		readTableFile(tableFilename);
		getCtrlCodeArgTable();
		getDemoModeStartPoints();
		getSpecialPointersOutsideScript();

		// to prepare for generating the Huffman tree, we need to:
		// - count occurrences for each character
		// - get data for all the pointers in the script itself
		countCharacters();

        Files.createDirectories(Paths.get(ANALYSIS_FOLDER));
		outputCountsToTextFile(romFilename);
		// outputUncompPtrs();

		// generate the Huffman tree; output useful info about it plus the
		// tree itself converted to the format the game expects
		HuffmanNode root = createHuffmanTree();
		printHuffmanCodes(root);

		int subtreeData[][] = convertTreeToGameFormat(root);
        outputConvertedHuffmanTreeToFile(subtreeData);

		analyzeCompression();

		// write Huffman script to binary file; collect Huffman pointers'
		// locations and values along the way, and insert their values
		// at the correct locations
		generateHuffmanScript();
		outputPointerInfo();
		insertStartPoints();
		insertEmbeddedPtrs();

		romFile.close();
    }
}
