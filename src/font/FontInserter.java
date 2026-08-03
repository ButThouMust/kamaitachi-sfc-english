package font;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;

public class FontInserter {

    private static boolean DEBUG = true;

    // private static final int CHAR_GROUP_SIZE_TABLE = 0xA736;
    // private static final int CHAR_DIMEN_TABLE = 0xA7A0;
    // private static final int CHAR_GROUP_GFX_PTR_TABLE = 0xA80A;
    private static final int MAX_CHAR_GROUPS = 53;
    private static final int MAX_JP_CHAR_ENCODING = 0x74E;

    private String tableFileName;
    // private String romFileName;
    private FontImage fontImage;
    private ArrayList<FontInfo> fontInfoArray;

    // private RandomAccessFile romStream;
    // using RandomAccessFile instead of something like FileOutputStream
    // because RAF gives you a "get current file position" method
    // if you don't seek() anywhere, it functions as a "get file size"
    private RandomAccessFile fontDataOutput;
    private RandomAccessFile fontGroupSizeTable;
    private RandomAccessFile fontDimensionTable;
    private RandomAccessFile fontPointerTable;

    private BufferedWriter newTableFile;
    private BufferedWriter newLETableFile;
    private BufferedWriter newOneByteTableFile;
    private BufferedWriter logFile;

    // *************************************************************************
    // Helper functions
    // *************************************************************************

    /*private void printFontInfoArray() {
        for (int i = 0; i < fontInfoArray.size(); i++) {
            FontInfo fontInfo = fontInfoArray.get(i);
            String format = "i = %04X ; %04X = '%s'\t; %2dx%2d";
            System.out.println(String.format(format, i, fontInfo.getHexValue(),
                               fontInfo.getEncoding(), fontInfo.getWidth(),
                               fontInfo.getHeight()));
        }
        System.out.println();
    }
    */

    private void readTableFile() throws IOException {
        fontInfoArray = new ArrayList<>();
        BufferedReader tableFileStream = new BufferedReader(new FileReader(tableFileName));

        // for this table file, format is "[hex value]\t[character]\t[width]\t[height]"
        String line;
        while ((line = tableFileStream.readLine()) != null) {
            if (line.equals(""))
                continue;

            String split[] = line.split("\t");
            if (split.length != 4) {
                System.out.println("Malformed table file line:\n" + line + "\n");
                tableFileStream.close();
                return;
            }

            short value = Short.parseShort(split[0], 16);
            String encoding = split[1];
            int width  = Integer.parseInt(split[2]);
            int height = Integer.parseInt(split[3]);

            fontInfoArray.add(new FontInfo(value, encoding, width, height));
        }
        if (DEBUG) {
            // printFontInfoArray();
        }
        tableFileStream.close();
    }

    private int getNumEntries() {
        int tableFileSize = fontInfoArray.size();
        int numChars = fontImage.getNumChars();
        return Math.min(tableFileSize, numChars);
    }

    private void combineFontDataWithTableFile() {
        // safety just in case these sizes don't match up
        int numEntries = getNumEntries();

        for (int i = 0; i < numEntries; i++) {
            fontInfoArray.get(i).setFontData(fontImage.getPixelDataForChar(i));
        }
    }

    private int[] getListOfCharNumsToUseInNameEntryGrid() throws IOException {
        String filename = "font/list of chars for name entry.bin";
        long fileLength = new File(filename).length();
        int numCharVals = ((int) fileLength) / 2;
        int output[] = new int[numCharVals];

        FileInputStream listFile = new FileInputStream(filename);
        for (int i = 0; i < output.length; i++) {
            int charNum = listFile.read() << 8;
            charNum |= listFile.read();
            output[i] = charNum;
        }

        listFile.close();
        return output;
    }

    private int[] generateNameEntryGridLookupTable(int listCharNums[]) {
        // font data for each character is 0x20 bytes
        final int FONT_BLOCK_SIZE = 0x20;
        // first 8 entries in lookup table are for a space (0000) and seven of
        // the "char slot not filled in" placeholder character
        final int NUM_PLACEHOLDER_VALS = 8;
        final int START_OF_SELECTABLE_CHARS = FONT_BLOCK_SIZE * NUM_PLACEHOLDER_VALS;
        final int CHAR_NOT_USED = -1;

        // prefill a list of offsets of 1st occurrences w/ "character not used"
        int listFirstOccurrencesOfCharNum[] = new int[fontInfoArray.size()];
        for (int i = 0; i < listFirstOccurrencesOfCharNum.length; i++) {
            listFirstOccurrencesOfCharNum[i] = CHAR_NOT_USED;
        }

        // if you do not account for empty spaces, characters' font data will be
        // skipped over in the lookup table
        int emptySpacesFound = 0;
        // 1st char # is for "char slot not filled in"; don't get 1st occurrence
        for (int i = 1; i < listCharNums.length; i++) {
            int charNum = listCharNums[i];
            if (charNum == 0) {
                emptySpacesFound++;
                continue;
            }

            charNum--;
            if (listFirstOccurrencesOfCharNum[charNum] == CHAR_NOT_USED) {
                listFirstOccurrencesOfCharNum[charNum] = i - 1 - emptySpacesFound;
            }
        }

        // fill in the empty spots in the lookup table with an index (not just
        // 0000) that leads to a block of all 00 bytes; I had to change this
        // when increasing letter limit in names from 6 to 10
        int lookupTableSize = listCharNums.length - 1 + NUM_PLACEHOLDER_VALS;
        int offsetToAfterLookupTable = lookupTableSize * FONT_BLOCK_SIZE;

        int lookupTable[] = new int[lookupTableSize];
        for (int i = 0; i < NUM_PLACEHOLDER_VALS; i++) {
            lookupTable[i] = i * FONT_BLOCK_SIZE;
        }
        for (int i = 1; i < listCharNums.length; i++) {
            int charNum = listCharNums[i];
            if (charNum == 0) {
                lookupTable[i - 1 + NUM_PLACEHOLDER_VALS] = offsetToAfterLookupTable;
                continue;
            }
            charNum--;

            int firstOccurrence = listFirstOccurrencesOfCharNum[charNum];
            int tableEntry = START_OF_SELECTABLE_CHARS + firstOccurrence * FONT_BLOCK_SIZE;
            lookupTable[i - 1 + NUM_PLACEHOLDER_VALS] = tableEntry;
        }
        return lookupTable;
    }

    private void writeLookupTableToFile(int lookupTable[], FileOutputStream writer) throws IOException {
        for (int i = 0; i < lookupTable.length; i++) {
            int loByte = lookupTable[i] & 0xFF;
            int hiByte = lookupTable[i] >> 8;
            writer.write(loByte);
            writer.write(hiByte);
        }
        for (int i = lookupTable.length << 1; i < 0xB00; i++) {
            writer.write(0x00);
        }
    }

    public void generateCharGridDataBlockToBeCompressed() throws IOException {
        // fontImage.convertToBinaryDataForNameEntryCharGrid();
        FileOutputStream writer = new FileOutputStream(fontImage.getOutputFilename());
        int listCharNums[] = getListOfCharNumsToUseInNameEntryGrid();
        int lookupTable[] = generateNameEntryGridLookupTable(listCharNums);

        // this writes both the lookup table and the font data itself to a file,
        // which is what you need to send to the LZSS recompressor
        writeLookupTableToFile(lookupTable, writer);
        fontImage.convertToBinaryDataForNameEntryCharGrid(listCharNums, writer);
    }

    public void initialize() throws IOException {
        readTableFile();

        // get the font data from the image
        fontImage.initialize();
        // generateCharGridDataBlockToBeCompressed();

        // associate the font data for each character with its appropriate entry
        combineFontDataWithTableFile();

        /*
        if (DEBUG) {
            printFontInfoArray();
        }
        */
    }

    // *************************************************************************
    // Constuctor
    // *************************************************************************

    public FontInserter(String tableFileName, FontImage fontImage) {
        // note: leaving to driver class to instantiate FontImage object
        this.tableFileName = tableFileName;
        this.fontImage = fontImage;
    }

    // *************************************************************************
    // Kerning, punctuation, control codes
    // *************************************************************************

    /**
     * Maps from single characters (from an in-game storage perspective) to
     * their hexadecimal values, such as "AUTO ADV 13" -> 0x1013.
     */
    private static HashMap<String, Integer> tableFileHashMap;

    // private static final int AUTO_ADV_VAL = 0x1002;
    // private static final int DELAY_VAL = 0x1000;
	// private static final int WAIT_VAL = 0x100D;
    // private static final int KERN_LEFT_VAL = 0x100A;

    private static String hexAsString(int hexValue) {
        return String.format("%04X", hexValue);
    }

    // add an entry to both the big endian and little endian table files
    private void addTableFileEntry(int hexValue, String encoding) throws IOException {
        // use "\r\n" (not "\n") so that table file works properly with Atlas
        String tableFormat = "%s=%s\r\n";

        String tableFileEntry = String.format(tableFormat, hexAsString(hexValue), encoding);
        newTableFile.write(tableFileEntry);

        int hexValueLE = (hexValue >> 8) | ((hexValue & 0xFF) << 8);
        String tableFileEntryLE = String.format(tableFormat, hexAsString(hexValueLE), encoding);
        newLETableFile.write(tableFileEntryLE);

        String tableFileEntryOneByte = String.format(tableFormat, String.format("%02X", hexValue), encoding);
        newOneByteTableFile.write(tableFileEntryOneByte);
    }

    // DEPRECATED, use ASM hack instead; however, keeping in for posterity
    /*
    // use table file to handle kerning "automatically", without replacing all
    // instances of [char1][char2] with [char1]<KERN><##>[char2] in the script
    private void addKerningPairs() throws IOException {
        final String KERN_LEFT = "<KERN LEFT>";
        String encodings[] = KerningPunctPairs.getKerningEncodings();
        String hexSequenceStrings[][] = KerningPunctPairs.getKerningHexSequences();

        // the lists are essentially hard-coded, so put in a basic sanity check
        // for bad formatting like unmatched brackets
        if (hexSequenceStrings.length != encodings.length) {
            throw new IOException("Source code formatting error: Sizes of lists for kerning combos do not match: " + (hexSequenceStrings.length) + " & " + (encodings.length) );
        }

        String tableFormat = "%s=%s\r\n";
        for (int i = 0; i < hexSequenceStrings.length; i++) {
            // put a new line after every four table entries for formatting
            if ((i & 0x3) == 0) {
                newTableFile.write("\r\n");
            }
            String hexValue = "";
            for (int j = 0; j < hexSequenceStrings[i].length; j++) {
                String hexSequence = hexSequenceStrings[i][j];

                // if got kern left code, first add the code, then the # of pixels
                if (hexSequence.equals(KERN_LEFT)) {
                    hexValue += hexAsString(KERN_LEFT_VAL);

                    String numPixelsString = hexSequenceStrings[i][j + 1];
                    hexValue += numPixelsString;
                    // advance past the entry with the # of pixels
                    j++;
                }

                // otherwise, get the hex value for the character and add it
                else {
                    Integer value = tableFileHashMap.get(hexSequence);
                    if (value == null) {
                        String error = "No mapping for encoding \"%s\" (position %d,%d)";
                        throw new IOException(String.format(error, hexSequence, i, j));
                    }
                    hexValue += hexAsString(value);
                }
            }
            newTableFile.write(String.format(tableFormat, hexValue, encodings[i]));
        }
    }
    */

    private void addCompoundPunctuation() throws IOException {
        String encodings[] = KerningPunctPairs.getPunctuationEncodings();
        // use these lists as keys to the HashMap tableFileHashMap
        String hexSequenceStrings[][] = KerningPunctPairs.getPunctuationHexSequences();

        // tableFileHashMap.put(KerningPunctPairs.AUTO_ADV_STR, AUTO_ADV_VAL);
        // tableFileHashMap.put(KerningPunctPairs.DELAY_STR, DELAY_VAL);
		// tableFileHashMap.put(KerningPunctPairs.WAIT_STR, WAIT_VAL);

        // System.out.println("tableFileHashMap has " + tableFileHashMap.size() + " mappings in it");

        // the lists are essentially hard-coded, so put in a basic sanity check
        // for bad formatting like unmatched brackets
        if (hexSequenceStrings.length != encodings.length) {
            throw new IOException("Source code formatting error: Sizes of lists for punctuation combos do not match: " + (hexSequenceStrings.length) + " & " + (encodings.length) );
        }

        String tableFormat = "%s=%s\r\n";
        for (int i = 0; i < hexSequenceStrings.length; i++) {
            // put a new line after every four table entries for formatting
            if ((i & 0x3) == 0) {
                newTableFile.write("\r\n");
            }
            String hexValue = "";
            for (int j = 0; j < hexSequenceStrings[i].length; j++) {
                String hexSequence = hexSequenceStrings[i][j];
                Integer value = tableFileHashMap.get(hexSequence);
                if (value == null) {
                    throw new IOException("No mapping for the encoding \"" + hexSequence + "\" (position " + i + "," + j + ")");
                }
                hexValue += hexAsString(value);
            }
            newTableFile.write(String.format(tableFormat, hexValue, encodings[i]));
        }
    }

    /**
     * Generate a binary file with the (little endian) hex values for characters
     * that should have the property "line break after this character if past
     * right margin"
     * @throws IOException
     */
    private void createListOfLinebreakChars() throws IOException {
        FileOutputStream lineBreakListFile = new FileOutputStream("font/auto linebreak chars.bin");

        String linebreakList[] = {" ", "-", "　"};
        for (String str : linebreakList) {
            // take the hex value for the file
            Integer hexValue = tableFileHashMap.get(str);
            if (hexValue != null && tableFileHashMap.containsKey(str)) {
                // write the hex value in little endian order to the file
                lineBreakListFile.write(hexValue & 0xFF);
                lineBreakListFile.write((hexValue >> 8) & 0xFF);
            }
        }

        // write the list terminator 0xFFFF
        lineBreakListFile.write(0xFF);
        lineBreakListFile.write(0xFF);

        lineBreakListFile.close();
    }

    private void addCtrlCodesToGeneratedTbl() throws IOException {
		BufferedReader ctrlCodesTbl = new BufferedReader(new FileReader("tables/control codes for patch.tbl"));
        String entry = "";
        while ((entry = ctrlCodesTbl.readLine()) != null) {
            newTableFile.write(entry + "\r\n");
			newLETableFile.write(entry.substring(2,4) + entry.substring(0,2) + entry.substring(4) + "\r\n");
			String tableEntryComponents[] = entry.split("=");
			tableFileHashMap.put(tableEntryComponents[1], Integer.parseInt(tableEntryComponents[0], 16));
        }
        ctrlCodesTbl.close();
    }

    // -------------------------------------------------------------------------
    // Generate font in uncompressed format
    // -------------------------------------------------------------------------

    private int getFontDataRow(boolean pixelRow[]) {
        int dataBuffer = 0x0000;
        for (int c = 0; c < pixelRow.length; c++) {
            dataBuffer |= (pixelRow[c] ? 1 : 0) << (pixelRow.length - 1 - c);
        }
        return dataBuffer;
    }

    public void convertFontDataToUncompGameFormat() throws IOException {
        // generate the font in the format that it ultimately gets decompressed
        // to, instead of the compression format used in the original game
        int numChars = getNumEntries();

        // originally, this overwrote data in the ROM file itself, but
        // this now writes data to their own individual files instead
        fontDataOutput = new RandomAccessFile("font/new uncomp font data.bin", "rw");

        // NOTE: let Asar handle insertion and updating bank # instead

        // keep two table files: one with big endian entries (actual script),
        // and another with little endian entries (name entry screen, lists
        // of characters for things like "auto WAIT" or choice option letters)
        newTableFile = new BufferedWriter(new FileWriter("tables/uncomp font.tbl"));
        newLETableFile = new BufferedWriter(new FileWriter("tables/uncomp font LE.tbl"));
        newOneByteTableFile = new BufferedWriter(new FileWriter("tables/uncomp font one byte.tbl"));
        logFile = new BufferedWriter(new FileWriter("logs/uncomp font insertion log.txt"));

        tableFileHashMap = new HashMap<>();

        // always first write the entry for a space
        addTableFileEntry(0x0000, " ");
        tableFileHashMap.put(" ", 0x0000);

        for (int ch = 0; ch < numChars; ch++) {
            FontInfo fontInfo = fontInfoArray.get(ch);
            int charHeight = fontImage.getCharHeight();

            int width = fontInfo.getWidth();
            int height = fontInfo.getHeight();

			// ch + 1 to account for space
            if (DEBUG) {
                String format = "Char %04X '%s' is %dx%d\r\n";
                logFile.write(String.format(format, ch, fontInfo.getEncoding(), fontInfo.getWidth(), fontInfo.getHeight()));
            }

            // write a byte containing the width and height
            int whByte = (width << 4) | height;
            fontDataOutput.write(whByte);

            // then write an empty byte for alignment purposes
            fontDataOutput.write(0x00);

            // Kamaitachi calculates its heights going from the bottom up
            // need to determine top row of the character and start there in 16x16 buffer
            int startRow = charHeight - fontInfo.getHeight();
            boolean charData[][] = fontInfo.getFontData();

            for (int r = 0; r < height; r++) {
                // for uncompressed font format, take a whole row and write
                // it in big endian, for ease of use with a tile editor
                boolean pixelRow[] = charData[startRow + r];
                int rowData = getFontDataRow(pixelRow);

                if (DEBUG) {
                    String format = "0x%05X: %04X\r\n";
                    logFile.write(String.format(format, fontDataOutput.getFilePointer(), rowData));
                }
                fontDataOutput.write(rowData >> 8);
                fontDataOutput.write(rowData & 0xFF);
            }
            for (int r = height; r < charHeight - 1; r++) {
                // for the remaining empty rows, simply write 0x00 bytes
                fontDataOutput.write(0x00);
                fontDataOutput.write(0x00);
            }

            // create entry in new table files
            // add mapping to the table file HashMap
			// ch + 1 to account for space
            addTableFileEntry(fontInfo.getHexValue() + 1, fontInfo.getEncoding());
            tableFileHashMap.put(fontInfo.getEncoding(), (int) fontInfo.getHexValue() + 1);
        }

        fontDataOutput.close();

        addCtrlCodesToGeneratedTbl();
        addCompoundPunctuation();
        // addKerningPairs();
        createListOfLinebreakChars();

        newTableFile.flush();
        newTableFile.close();
        newLETableFile.flush();
        newLETableFile.close();
        newOneByteTableFile.flush();
        newOneByteTableFile.close();

        logFile.flush();
        logFile.close();
    }

    // -------------------------------------------------------------------------
    // Insert font in original, compressed format
    // -------------------------------------------------------------------------

    private void printErrorForTooManyPairs(FontInfo fontInfo, int ch) throws IOException {
        String errorMessage = "ERROR - supplied font has too many distinct WxH pairs!";

        String format = "Execution halted with %dx%d char %04X = '%s'";
        String output = String.format(format, fontInfo.getWidth(),
            fontInfo.getHeight(), ch, fontInfo.getEncoding());

        logFile.write(errorMessage + "\r\n");
        logFile.write(output + "\r\n");
        logFile.flush();

        System.out.println(errorMessage);
        System.out.println("Please check \"font insertion log.txt\"");
    }

    private void fillInEntryForMetadataTables(int numCharsInGroup, int height, int width, int groupStartOffset) throws IOException {
        // update font metadata tables
        // char group size table just stores # chars (two bytes)
        fontGroupSizeTable.writeByte(numCharsInGroup & 0xFF);
        fontGroupSizeTable.writeByte(numCharsInGroup >> 8);

        // font dimension table has two-byte entries:
        // byte 0 = HW, byte 1 = product H*W
        int dimenByte0 = (height << 4) | width;
        int dimenByte1 = height * width;
        fontDimensionTable.writeByte(dimenByte0);
        fontDimensionTable.writeByte(dimenByte1);

        // font pointer table has 3-byte entries; the actual 24-bit
        // pointer will be calculated by Asar (depends on where font
        // itself will be inserted), but store relative file offset
        fontPointerTable.writeByte(groupStartOffset & 0xFF);
        fontPointerTable.writeByte((groupStartOffset >> 8) & 0xFF);
        fontPointerTable.writeByte((groupStartOffset >> 16) & 0xFF);
    }

    public void convertFontDataToGameFormat() throws IOException {
        // for 1st character in a WxH group, write bits into ROM starting at LSB
        // fill up a byte going from LSB to MSB
        // subsequent characters in group continue at bit where last one ends
        // always start at LSB for new WxH groups
        int bitOffset = 0;
        int numChars = getNumEntries();
        int numCharsInGroup = 0;
        int dataBuffer = 0;
        int numCharGroups = 0;

        // due to nature of Kamaitachi's font storage format, sort characters
        // by width, height and then by encoding
        Collections.sort(fontInfoArray, new FontInfoDimensionComparator());

        fontDataOutput = new RandomAccessFile("font/new font data.bin", "rw");

        fontGroupSizeTable = new RandomAccessFile("font/font size table.bin", "rw");
        fontDimensionTable = new RandomAccessFile("font/font dimension table.bin", "rw");
        fontPointerTable = new RandomAccessFile("font/font pointer table.bin", "rw");

        // NOTE: let Asar handle insertion and updating bank # instead

        // just set it to 0 at the start
        long groupStartOffset = 0x0;

        // keep two table files: one with big endian entries (actual script),
        // and another with little endian entries (name entry screen, lists
        // of characters for things like "auto WAIT" or choice option letters)
        newTableFile = new BufferedWriter(new FileWriter("tables/inserted font.tbl"));
        newLETableFile = new BufferedWriter(new FileWriter("tables/inserted font LE.tbl"));
        newOneByteTableFile = new BufferedWriter(new FileWriter("tables/inserted font one byte.tbl"));
        logFile = new BufferedWriter(new FileWriter("tables/font insertion log.txt"));

        tableFileHashMap = new HashMap<>();

        // always first write the entry for a space
        addTableFileEntry(0x0000, " ");
        tableFileHashMap.put(" ", 0x0000);

        for (int ch = 0; ch < numChars; ch++) {
            FontInfo fontInfo = fontInfoArray.get(ch);

            // note: original game has space for at most 53 structures
            // possibly allow specifying a different location for them
            // with more space, similar for the font data itself
            if (numCharGroups >= MAX_CHAR_GROUPS) {
                printErrorForTooManyPairs(fontInfo, ch);
                break;
            }

			// ch + 1 to account for space
            if (DEBUG) {
                String format = "Char %04X '%s' is %dx%d\r\n";
                logFile.write(String.format(format, ch, fontInfo.getEncoding(), fontInfo.getWidth(), fontInfo.getHeight()));
                logFile.flush();
            }

            // Kamaitachi calculates its heights going from the bottom up
            // need to determine top row of the character and start there in 16x16 buffer
            int startRow = fontImage.getCharHeight() - fontInfo.getHeight();
            boolean charData[][] = fontInfo.getFontData();
            numCharsInGroup++;

            for (int r = 0; r < fontInfo.getHeight(); r++) {
                // if you write bits starting from left, chars are mirrored
                // horizontally, so write bits starting from right instead
                for (int c = fontInfo.getWidth() - 1; c >= 0; c--) {
                    int pixel = charData[startRow + r][c] ? 1 : 0;
                    dataBuffer |= pixel << bitOffset;

                    bitOffset = (bitOffset + 1) & 0x7;
                    if (bitOffset == 0) {
                        if (DEBUG) {
                            String format = "0x%05X: %02X\r\n";
                            logFile.write(String.format(format, fontDataOutput.getFilePointer(), dataBuffer));
                        }
                        fontDataOutput.writeByte(dataBuffer);
                        dataBuffer = 0;
                    }
                }
            }
            logFile.flush();

            // create entry in new table files sorted by heights/widths
            // add mapping to the table file HashMap
			// ch + 1 to account for space
			addTableFileEntry(ch + 1, fontInfo.getEncoding());
            tableFileHashMap.put(fontInfo.getEncoding(), ch + 1);

            // done with char; need to update font lookup table if either:
            // - no characters left to insert
            // - next char has a different height, OR a different width
            // it is assumed that in this loop, (ch != numChars - 1) implies
            // that there is at least 1 more char to look at
            if (ch == numChars - 1 ||
                fontInfo.getWidth()  != fontInfoArray.get(ch + 1).getWidth() ||
                fontInfo.getHeight() != fontInfoArray.get(ch + 1).getHeight()) {

                // if last character does not end on byte boundary,
                // have to write the last N bits of the character
                if (bitOffset != 0) {
                    if (DEBUG) {
                        String format = "0x%05X: %02X - last for group\r\n";
                        logFile.write(String.format(format, fontDataOutput.getFilePointer(), dataBuffer));
                        logFile.flush();
                    }
                    fontDataOutput.writeByte(dataBuffer);
                    dataBuffer = 0;
                    bitOffset = 0;
                }

                // update font metadata tables
                fillInEntryForMetadataTables(numCharsInGroup, fontInfo.getHeight(), fontInfo.getWidth(), (int) groupStartOffset);

                if (DEBUG) {
                    // size of the WxH group in bits
                    int groupSize = numCharsInGroup * fontInfo.getWidth() * fontInfo.getHeight();

                    // print # of chars in group, plus where they are in ROM
                    String format2 = "%d chars are %dx%d from 0x%05X-0 to 0x%05X-%1X\r\n";
                    logFile.write(String.format(format2, numCharsInGroup,
                        fontInfo.getWidth(), fontInfo.getHeight(),
                        groupStartOffset, fontDataOutput.getFilePointer(), groupSize & 0x7));

                    // print # of char groups so far, and size of curr group
                    String format3 = "Group #%d is %d bits = 0x%X-%d bytes\r\n";
                    logFile.write(String.format(format3, numCharGroups + 1,
                        groupSize, groupSize >> 3, groupSize & 0x7));

                    logFile.write("\r\n");
                }

                // initialize variables for the next group of characters
                numCharsInGroup = 0;
                numCharGroups++;
                groupStartOffset = fontDataOutput.getFilePointer();
            }
        }

        
		if (numCharGroups < MAX_CHAR_GROUPS) {
            // GenerateSevenSegFontKamaitachi.writeCompressedFontBlocksForEncodingRange(numChars, MAX_JP_CHAR_ENCODING);
            fillInEntryForMetadataTables(MAX_JP_CHAR_ENCODING - numChars + 1, 1, 1, (int) groupStartOffset);
            numCharGroups++;
        }

        // (optional?) pad metadata tables to 53 structures, to avoid
        // possiblility of reading data from the original Japanese table
        /*
		while (numCharGroups < MAX_CHAR_GROUPS) {
            // meaning: 0xFFF chars are 1x1
            fontGroupSizeTable.writeByte(0xFF);
            fontGroupSizeTable.writeByte(0x0F);

            fontDimensionTable.writeByte(0x11);
            fontDimensionTable.writeByte(0x01);

            fontPointerTable.writeByte(0x00);
            fontPointerTable.writeByte(0x00);
            fontPointerTable.writeByte(0x00);

            numCharGroups++;
        }
		*/

        // for the table file of one byte encodings, put in a new encoding for
        // 0xFF to signify "end of string"

        fontDataOutput.close();
        fontGroupSizeTable.close();
        fontDimensionTable.close();
        fontPointerTable.close();

        addCtrlCodesToGeneratedTbl();
        addCompoundPunctuation();
        // addKerningPairs();
        // createListOfLinebreakChars();

        newTableFile.flush();
        newTableFile.close();
        newLETableFile.flush();
        newLETableFile.close();
        newOneByteTableFile.flush();
        newOneByteTableFile.close();

        logFile.flush();
        logFile.close();
        //convertToGameFormat(fontInfo, 0);
    }
}
