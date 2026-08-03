package huffman;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.util.ArrayList;
import java.util.Collections;

import static header_files.HelperMethods.getRAMOffset;
import static header_files.HelperMethods.getFileOffset;
import static header_files.TextConstants.*;

public class HuffScriptDumper {
    private static RandomAccessFile romFile;
    private static BufferedWriter scriptOutput;
    private static BufferedWriter goryDetails;
    private static boolean shouldWriteDetails;

    private static int scriptStart;
    private static int scriptEnd;

    private static int ch1PtrByteOffset;
    private static int ch1PtrBitOffset;
    private static int[] ch1PtrBytes;

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

    private static ArrayList<Integer> tableHexValues;
    private static ArrayList<String> encodings;
    private static final String NO_TABLE_MATCH = "N/A";

    private static void readTableFile(String tableFilename) throws IOException {
        // assume file is sorted in increasing order by character code value
        BufferedReader tableFileStream = new BufferedReader(new FileReader(tableFilename));
        tableHexValues = new ArrayList<>(NUM_ENCODINGS);
        encodings = new ArrayList<>(NUM_ENCODINGS);

        // basic format of a table file line is "[hex value]=[character]\n"
        String line;
        final String EQUALS = "=";
        while ((line = tableFileStream.readLine()) != null) {
            if (line.equals(""))
                continue;

            String split[] = line.split(EQUALS);

            // ignore special combination table entries that keep the script
            // simpler, like for ." or ?! or Mr. or Mrs.
            if (split[0].length() > 4)
                continue;

            int value = Integer.parseInt(split[0], 16);
            tableHexValues.add(value);

            // possible for a table entry to be for the equal sign "="
            if (split.length == 1) {
                encodings.add(EQUALS);
            }
            else {
                encodings.add(split[1]);
            }
        }

        System.out.println("Finished parsing table file.");
        tableFileStream.close();
        return;
    }

    private static String getEncoding(int data) {
        data &= 0x1FFF;
        int index = Collections.binarySearch(tableHexValues, data);

        String encoding = NO_TABLE_MATCH;
        if (index >= 0) {
            encoding = encodings.get(index);
        }
        return encoding;
    }

    // -------------------------------------------------------------------------
    // Data for the Huffman tree structure
    // -------------------------------------------------------------------------

    // whereas I was fine with using a smaller Huffman tree without resizing or
    // repointing with Otogirisou, I plan to only use as much space as I need
    // for Kamaitachi, so instead of having the hard-coded values for the left
    // trees, right trees, and tree size, I put in the pointers to these values

    // e.g. instead of using 0x9952 for the Huffman left trees in the code, use
    // that the [52 99] value is in the ASM at $009B28, or 0x1B28

    private static final int PTR_TO_HUFF_LEFT_TREE_OFFSET = 0x1B28; // 0x9952
    private static final int PTR_TO_HUFF_RIGHT_TREE_OFFSET = 0x1B30; // 0x86BE
    private static final int PTR_TO_HUFF_TREE_SIZE = 0x1B0F; // 0xDE2

    private static int[] huffLeftTrees;
    private static int[] huffRightTrees;

    private static int bitOffset;
    private static int huffmanBuffer;

    // using this because I gave up trying to use RandomAccessFile's internal file
    // pointer for checking pointer targets (EMBWRITEs) and outputting "new page"
    // pointers in script; they would always be off by one
    private static int currByteOffset;

    private static void getHuffmanTreeData() throws IOException {
        // get 0-indexed offset of the end of each block
        romFile.seek(PTR_TO_HUFF_TREE_SIZE);
        int huffTableSize = romFile.readUnsignedByte();
        huffTableSize |= romFile.readUnsignedByte() << 8;

        // convert 0-indexed offset to # table entries, initialize tables
        int numTableEntries = (huffTableSize / 2) + 1;
        huffLeftTrees = new int[numTableEntries];
        huffRightTrees = new int[numTableEntries];

        // get offset of pointer to start of Huffman left trees
        // note: Huffman trees are in bank 01, so the bank offset value here is
        // itself the "ROM file" offset needed for seeking around in it
        romFile.seek(PTR_TO_HUFF_LEFT_TREE_OFFSET);
        int leftTreeOffset = romFile.readUnsignedByte();
        leftTreeOffset |= romFile.readUnsignedByte() << 8;
        // read data for the left trees
        romFile.seek(leftTreeOffset);
        int data = 0;
        for (int i = 0; i < numTableEntries; i++) {
            data = romFile.readUnsignedByte();
            data |= (romFile.readUnsignedByte() << 8);
            huffLeftTrees[i] = data;
        }

        // repeat for the right trees
        romFile.seek(PTR_TO_HUFF_RIGHT_TREE_OFFSET);
        int rightTreeOffset = romFile.readUnsignedByte();
        rightTreeOffset |= romFile.readUnsignedByte() << 8;
        romFile.seek(rightTreeOffset);
        for (int i = 0; i < numTableEntries; i++) {
            data = romFile.readUnsignedByte();
            data |= (romFile.readUnsignedByte() << 8);
            huffRightTrees[i] = data;
        }
        System.out.println("Finished getting Huffman tree's contents.");
    }

    // -------------------------------------------------------------------------
    // Mnemonics for reading raw binary data from the script
    // -------------------------------------------------------------------------

    // uses the independent "current byte offset"; used for navigating the script
    private static int getCPUOffsetFromOffsetVar() {
        return getRAMOffset(currByteOffset);
    }

    // uses the RandomAccessFile's file pointer; used for start points
    private static int getCPUOffsetFilePointer() throws IOException {
        return getRAMOffset((int) (romFile.getFilePointer() & 0xFFFFFF));
    }

    // read a byte without advancing file pointer
    private static int peekByte() throws IOException {
        int output = romFile.readUnsignedByte();
        romFile.seek(romFile.getFilePointer() - 1);
        return output;
    }

    private static int readCharacter() throws IOException {
        // start going left/right from the root of the Huffman tree

        // internal representation for non-leaves is using BYTE offsets instead
        // of WORD offsets; to avoid putting in a special case, start with word
        // offset for the root of the tree
        int huffTreeValue = (huffLeftTrees.length - 1) << 1;
        int startOffset = getCPUOffsetFromOffsetVar();
        int oldBitOffset = bitOffset;
        String huffCode = "";
        int length = 0;

        // Huffman leaf node (character) indicated by a SET MSB in tree value
        while ((huffTreeValue & 0x8000) == 0) {
            // read another byte if exhausted all 8 bits in buffer
            // important note: by default, getFilePointer() will point to the byte
            // AFTER the current Huffman code when we call readUnsignedByte()
            // we want to keep the file pointer AT the current byte of the Huffman
            // code, so to read the next byte, we must advance the pointer by 1
            // and peek the next/"current" byte
            if (bitOffset == 0) {
                romFile.readUnsignedByte();
                huffmanBuffer = peekByte();
            }

            // LSB = 0 -> left tree ------ LSB = 1 -> right tree
            boolean useLeftTree = (huffmanBuffer & 0x1) == 0;

            // update state of and position in the Huffman buffer
            bitOffset = (bitOffset + 1) & 0x7;
            huffmanBuffer >>= 1;

            // update current position in the ROM
            if (bitOffset == 0) {
                currByteOffset++;
            }

            // read from either the left or right tree -- the >> 1 is for how
            // the offsets are BYTE offsets instead of WORD offsets
            // for example, left entry @ root is 0x0DE0 -> array offset 0x6F0
            if (useLeftTree) {
                huffTreeValue = huffLeftTrees[huffTreeValue >> 1];
                huffCode += "0";
            }
            else {
                huffTreeValue = huffRightTrees[huffTreeValue >> 1];
                huffCode += "1";
            }

            // put spaces between every 8 bits in a Huffman code
            if ((++length & 0x7) == 0) {
                huffCode += " ";
            }
        }

        if (shouldWriteDetails) {
            String format = "%06X-%d: %04X = 0b%s\n";
            goryDetails.write(String.format(format, startOffset, oldBitOffset, huffTreeValue, huffCode));
        }
        return huffTreeValue & 0x1FFF;
    }

    private static int readPointer() throws IOException {
        // it is possible for the 24-bit pointer to be spread across four bytes
        // in the ROM, like: [0000]0000 [11111111] [22222222] 3333[3333]
        // or in big endian: 3333[3333] [22222222] [11111111] [0000]0000

        // range from: 3[3333333] [22222222] [11111111] [0]0000000 (offset 7)
        //       to:   33[333333] [22222222] [11111111] [00]000000 (offset 6) 
        //       to:   333[33333] [22222222] [11111111] [000]00000 (offset 5) 
        //       to:   3333[3333] [22222222] [11111111] [0000]0000 (offset 4) 
        //       to:   33333[333] [22222222] [11111111] [00000]000 (offset 3) 
        //       to:   333333[33] [22222222] [11111111] [000000]00 (offset 2) 
        //       to:   3333333[3] [22222222] [11111111] [0000000]0 (offset 1) 
        //       to:   33333333   [22222222] [11111111] [00000000] (offset 0) 
        // byte 0's part of the pointer is already in huffmanBuffer
        // the rest of it was already consumed from a previous Huffman code (character)
        // upon exiting, value of huffmanBuffer must be byte 3, shifted right "bitOffset" times

        int cpuOffset = getCPUOffsetFromOffsetVar();

        // advance past byte 0, get 3 bytes, stop file pointer at the third byte
        romFile.readUnsignedByte();
        int byte1 = romFile.readUnsignedByte();
        int byte2 = romFile.readUnsignedByte();
        int byte3 = peekByte();
        currByteOffset += 3;

        // combine the raw data into one variable, and truncate to 24 bits
        // purpose of shifting out 8 if byte aligned: the Huffman buffer will
        // contain 00 from byte before the pointer i.e. we don't care about it
        // for calculating the pointer
        boolean byteAligned = (bitOffset & 0x7) == 0;
        int shiftAmount = byteAligned ? 8 : bitOffset;
        int rawData = huffmanBuffer;
        rawData |= byte1 << (1 * 8 - shiftAmount);
        rawData |= byte2 << (2 * 8 - shiftAmount);
        rawData |= byte3 << (3 * 8 - shiftAmount);
        rawData = rawData & 0xFFFFFF;

        if (shouldWriteDetails) {
            String format = "[%02X %02X %02X %02X] -> (%02X%02X%02X << %d) | %02X = %06X\n";
            goryDetails.write(String.format(format, huffmanBuffer, byte1, byte2, byte3, byte3, byte2, byte1, 8 - shiftAmount, huffmanBuffer, rawData));
        }

        // calculate the pointer info encoded in the three bytes of raw data
        // [76] [5432] [2107654 32107654] [3210]; top two MSBs unused
        int ptrBitOffset = rawData & 0x7;
        int ptrNumBytes = (rawData >> 3) & 0x7FFF;
        int ptrNumBanks = (rawData >> 18) & 0xF;

        // return a Huffman CPU pointer encoded like the start points: 21+3 bits
        int ptrBankOffset = (scriptStartBankOffset + ptrNumBytes) | 0x8000;
        int ptrBank = scriptStartBankNumber + ptrNumBanks;
        int pointer = (ptrBank << 16) + ptrBankOffset;
        pointer = (pointer << 3) | ptrBitOffset;

        // write the script pointer's location, its data, and its decoded target
        if (shouldWriteDetails) {
            String format2 = "%06X-%d: %06X -> %06X-%d\n";
            goryDetails.write(String.format(format2, cpuOffset, bitOffset & 0x7, rawData, pointer >> 3, ptrBitOffset));
        }

        huffmanBuffer = byte3 >> shiftAmount;
        if (shouldWriteDetails) {
            goryDetails.write(String.format("Huffman buffer: %02X\n", huffmanBuffer));
        }
        return pointer;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void printChar(int charValue) throws IOException {
        // obtain the corresponding character from the table file
        // print to the script output text file
        String encoding = getEncoding(charValue);
        if (encoding.equals(NO_TABLE_MATCH)) {
            String format = "ERROR - character value 0x%04X @ 0x%06X-%d ($%06X-%d) not in table file!\n";
            throw new IOException(String.format(format, charValue, currByteOffset, bitOffset, getCPUOffsetFromOffsetVar(), bitOffset));
        }
        scriptOutput.write(encoding);
    }

    private static void printArg(int charEncoding) throws IOException {
        // print the two bytes of the encoding individually
        int hiByte = charEncoding >> 8;
        int lowByte = charEncoding & 0xFF;

        String format = "<$%02X><$%02X>";
        scriptOutput.write(String.format(format, hiByte, lowByte));
    }

    private static void printPtr(int ptrValue) throws IOException {
        // used this for debugging, but may hinder readability in script dump
        String format1 = "// PTR = 0x%06X -> [$%06X-%d]";
        scriptOutput.newLine();
        scriptOutput.write(String.format(format1, ptrValue, ptrValue >> 3, ptrValue & 0x7));

        String format2 = "#EMBSET(%04d)";
        scriptOutput.newLine();
        scriptOutput.write(String.format(format2, currPtrNum++));
    }

    private static void printROMFilePos() throws IOException {
        int cpuOffset = getCPUOffsetFromOffsetVar();

        // calculate convenient data for playtesting: the four bytes at $05FE63
        // through $05FE66 have # bits from start of script space for where text
        // properly begins in the script; this gets read for starting a new file
        // or for selecting "restart" and lets you jump anywhere in the script
        // pointer is at $05FE63-6: [91 14 03 00] -> 00031491 (>> 6) 00000C52
        int startPoint = (cpuOffset << 3) | (bitOffset & 0x7);

        // similar logic as from readPointer() above
        String format = "//[$%06X-%d] -> 0x%06X";
        scriptOutput.write(String.format(format, cpuOffset, bitOffset & 0x7, startPoint));

        // only output the bytes for what to change where "chapter 1" begins
        // if actually after the pointer for chapter 1
        int cpuOffsetOfCh1Ptr = getRAMOffset(ch1PtrByteOffset);
        if (cpuOffset >= cpuOffsetOfCh1Ptr) {
            int numBytes = currByteOffset - scriptStart;
            int numBits = (numBytes << 3) | bitOffset;
            int dataBytes = numBits << ch1PtrBitOffset;

            if (ch1PtrBitOffset == 0) {
                int byte0 = dataBytes & 0xFF;
                int byte1 = (dataBytes >> 8) & 0xFF;
                int byte2 = (dataBytes >> 16) & 0xFF;

                String bytesFormat = " -> [%02X %02X %02X]";
                scriptOutput.write(String.format(bytesFormat, byte0, byte1, byte2));
            }
            else {
                int byte0 = dataBytes & 0xFF | ch1PtrBytes[0];
                int byte1 = (dataBytes >> 8) & 0xFF;
                int byte2 = (dataBytes >> 16) & 0xFF;
                int byte3 = ((dataBytes >> 24) & 0xFF) | ch1PtrBytes[3];

                String bytesFormat = " -> [%02X %02X %02X %02X]";
                scriptOutput.write(String.format(bytesFormat, byte0, byte1, byte2, byte3));
            }
        }
        scriptOutput.newLine();
    }

    /*
    private static int getFileOffset(int cpuOffset) {
        int bankNum = cpuOffset >> 16;
        int bankOffset = cpuOffset & 0xFFFF;
        return 0x8000 * (bankNum - 1) + bankOffset;
    }
    */

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int scriptStartBankOffset;
    private static int scriptStartBankNumber;

    private static ArrayList<HuffScriptPointer> scriptPointers;
    private static int currPtrNum;

    private static void getScriptStartPoints() throws IOException {
        for (int i = 0; i < NUM_SPECIAL_POINTERS - 1; i++) {
            // first read the bank offset
            romFile.seek(SPECIAL_POINTERS_BANK_OFFSET_LOCATIONS[i]);
            int ptrLocation = getCPUOffsetFilePointer();
            int ptr = (romFile.readUnsignedByte()) | (romFile.readUnsignedByte() << 8);

            // then read the bank number
            romFile.seek(SPECIAL_POINTERS_BANK_NUMBER_LOCATIONS[i]);
            ptr |= (romFile.readUnsignedByte() << 16);

            int ptrBitOffset = ptr & 0x7;
            int ptrCPUAddr = ptr >> 3;
            scriptPointers.add(new HuffScriptPointer(ptrCPUAddr, ptrBitOffset, ptrLocation, bitOffset, i));

            // special: value at $008B0A encodes start of the script as a whole
            // keep track of it for printing pointer comments
            // NOTE: this assumes that the script starts byte-aligned
            if (i == 1) {
                scriptStartBankOffset = ptrCPUAddr & 0xFFFF;
                scriptStartBankNumber = ptrCPUAddr >> 16;
                System.out.printf("Script start from pointer at $008B0A: $%06X-%d\n", ptrCPUAddr, ptrBitOffset);
            }

            // special: value at $049A6C in the JP game is a copy of the pointer
            // at $008F44, but the location in the patched game is not set in
            // stone; thankfully, can just reuse the pointer value
            if (i == 3) {
                romFile.seek(SPECIAL_POINTERS_BANK_OFFSET_LOCATIONS[NUM_SPECIAL_POINTERS - 1]);
                ptrLocation = getCPUOffsetFilePointer();

                scriptPointers.add(new HuffScriptPointer(ptrCPUAddr, ptrBitOffset, ptrLocation, bitOffset, NUM_SPECIAL_POINTERS - 1));
            }
        }
    }

    private static void getAttractModeStartPoints() throws IOException {
        romFile.seek(ATTRACT_MODE_PTRS_LOCATION);
        for (int i = 0; i < NUM_ATTRACT_MODE_START_POINTS; i++) {
            // read 24-bit ptr value, isolate out bank offset and bits
            int ptrLocation = getCPUOffsetFilePointer();
            int ptr = romFile.readUnsignedByte() |
                     (romFile.readUnsignedByte() << 8) |
                     (romFile.readUnsignedByte() << 16);

            int ptrBitOffset = ptr & 0x7;
            int ptrCPUAddr = ptr >> 3;
            scriptPointers.add(new HuffScriptPointer(ptrCPUAddr, ptrBitOffset, ptrLocation, 0, i + NUM_SPECIAL_POINTERS));
        }
    }

    // it is possible to start at any script position you want by altering a
    // pointer at a specific position in the script (in JP game, $05FE63-6)
    // this method determines the byte+bit position of that pointer based on how
    // it is the argument for the first <JMP 0F> you reach after finding the
	// block of <CLEAR TEMP FLAG 23> codes in the script
    private static void getPtrToChapter1() throws IOException {
        romFile.seek(scriptStart);
        currByteOffset = scriptStart;

        // initialize Huffman buffer
        huffmanBuffer = peekByte();
        bitOffset = 8;

        boolean foundClearTempFlag = false;

        // go to start of script and start reading characters
        while (romFile.getFilePointer() < scriptEnd) {
            // pointers in the script can only appear directly after certain
            // control codes, as in not after actual characters
            int charEncoding = readCharacter();
            if (charEncoding >= MIN_CTRL_CODE_ID) {
                int codeID = charEncoding & 0xFF;
                int numArgs = argMetadata[codeID] & 0x3;
                int argTypes = argMetadata[codeID] >> 2;

                foundClearTempFlag = foundClearTempFlag || (charEncoding == CLEAR_TEMP_FLAG_23);
                if (charEncoding == JMP_0F && foundClearTempFlag) {
                    break;
                }

                // choices are special cases that the regular algorithm doesn't cover
                if (isChoiceCode(charEncoding)) {
                    // choice codes take # of arguments in list, N, and use
                    // N+3 as # of Huffman codes, and N+2 as # of pointers
                    int numChoiceArgs = numArgs + 3;
                    for (int i = 0; i < numChoiceArgs; i++) {
                        readCharacter();
                    }

                    int numPtrs = numArgs + 2;
                    for (int i = 0; i < numPtrs; i++) {
                        readPointer();
                    }
                }

                // otherwise, get # of arguments and interpret each one properly
                else {
                    for (int i = 0; i < numArgs; i++) {
                        switch (argTypes & 0x1) {
                            case CHAR_ARG:
                                readCharacter();
                                break;
                            case PTR_ARG:
                                readPointer();
                                break;
                        }
                        argTypes >>= 1;
                    }
                }
            }
            // do nothing if not a control code
        }

        ch1PtrByteOffset = currByteOffset;
        ch1PtrBitOffset = bitOffset;
        System.out.println(String.format("ROM offset of pointer to Chapter 1: 0x%06X-%d.", ch1PtrByteOffset, ch1PtrBitOffset));

        // next, get the ROM bytes at ptr to ch1, but with the ptr data stripped
        // out, i.e. only keep the bits for the surrounding Huffman codes
        boolean byteAligned = ch1PtrBitOffset == 0;

        // if byte aligned, the three bytes *ARE* the pointer, so array of 00s is what we need
        if (byteAligned) {
            ch1PtrBytes = new int[3];
        }
        // otherwise, we have to keep the surrounding data bits in bytes 0 and 3
        else {
            ch1PtrBytes = new int[4];
            // for byte 0, only keep the bottom (bitOffset) bits
            // skip bytes 1 and 2; keep the top (8 - bitOffset) bits for byte 3
            romFile.seek(ch1PtrByteOffset);
            ch1PtrBytes[0] = romFile.readUnsignedByte();
            romFile.readUnsignedByte();
            romFile.readUnsignedByte();
            ch1PtrBytes[3] = romFile.readUnsignedByte();

            // an appropriate bitmask for "bottom N bits" is (1 << N) - 1
            // e.g. bottom 3 bits -> (1 << 3) - 1 = 0x8 - 1 = 0x7
            // to get a bitmask for "top 8-N bits", simply flip the bits
            int bitmask = (1 << ch1PtrBitOffset) - 1;
            ch1PtrBytes[0] &= bitmask;
            ch1PtrBytes[3] &= (bitmask ^ 0xFF);
        }
    }


    // not all the pointers in the script necessarily point to right after a
    // CLEAR code, JMP code, or CHOICE code; this collects all of them
    private static void getScriptPointers() throws IOException {
        romFile.seek(scriptStart);
        currByteOffset = scriptStart;

        // it is important to PEEK at the byte here instead of READ it, to not
        // advance the file pointer for pointer locations and "start of page"
        // print outs in the script dump
        huffmanBuffer = peekByte();

        // indicate start of script with bit offset of "0", but do not update
        // Huffman buffer from having an actual bit offset of 0
        bitOffset = 8;

        System.out.print("Now getting pointers from script... ");

        // go to start of script and start reading characters
        while (romFile.getFilePointer() < scriptEnd) {
            // pointers in the script can only appear directly after certain
            // control codes, as in not after actual characters
            int charEncoding = readCharacter();
            if (charEncoding >= MIN_CTRL_CODE_ID) {
                int codeID = charEncoding & 0xFF;
                int numArgs = argMetadata[codeID] & 0x3;
                int argTypes = argMetadata[codeID] >> 2;

                // choices are special cases that the regular algorithm doesn't cover
                if (isChoiceCode(charEncoding)) {
                    // choice codes take # of arguments in list, N, and use
                    // N+3 as # of Huffman codes, and N+2 as # of pointers
                    int numChoiceArgs = numArgs + 3;
                    for (int i = 0; i < numChoiceArgs; i++) {
                        readCharacter();
                    }

                    int numPtrs = numArgs + 2;
                    for (int i = 0; i < numPtrs; i++) {
                        int ptrLocation = getCPUOffsetFromOffsetVar();
                        int ptr = readPointer();

                        int ptrCPUAddr = ptr >> 3;
                        int ptrBitOffset = ptr & 0x7;
                        scriptPointers.add(new HuffScriptPointer(ptrCPUAddr, ptrBitOffset, ptrLocation, bitOffset, scriptPointers.size()));
                    }
                }

                // otherwise, get # of arguments and interpret each one properly
                else {
                    for (int i = 0; i < numArgs; i++) {
                        switch (argTypes & 0x1) {
                            case CHAR_ARG:
                                readCharacter();
                                break;
                            case PTR_ARG:
                                int ptrLocation = getCPUOffsetFromOffsetVar();
                                int ptr = readPointer();

                                int ptrCPUAddr = ptr >> 3;
                                int ptrBitOffset = ptr & 0x7;
                                scriptPointers.add(new HuffScriptPointer(ptrCPUAddr, ptrBitOffset, ptrLocation, bitOffset, scriptPointers.size()));
                                break;
                        }
                        argTypes >>= 1;
                    }
                }
            }
            // do nothing if not a control code
        }
        System.out.println(String.format("Done, %d.", scriptPointers.size()));
    }

    private static void outputScriptPointers() throws IOException {
        BufferedWriter pointerListOutput = new BufferedWriter(new FileWriter("script/script pointers list.txt"));
        String format = "Ptr #%4d @ $%06X-%d -> $%06X-%d";
        for (HuffScriptPointer ptr : scriptPointers) {
            pointerListOutput.write(String.format(format, ptr.getPtrNum(), ptr.getPtrLocation(), ptr.getPtrLocationBitOffset(), ptr.getPtrValue(), ptr.getPtrValueBitOffset()));
            pointerListOutput.newLine();
        }
        pointerListOutput.flush();
        pointerListOutput.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void addAtlasHeader(String tableFilename) throws IOException {
        int ch1PtrCPUOffset = getRAMOffset(ch1PtrByteOffset);
        scriptOutput.write(String.format("// CPU offset of pointer to chapter 1: $%06X-%d.", ch1PtrCPUOffset, ch1PtrBitOffset));
        scriptOutput.newLine();

        scriptOutput.write("#VAR(Table, TABLE)");
        scriptOutput.newLine();
        // use whatever table file that was included when running this tool
        String tableReferenceFormat = "#ADDTBL(\"%s\", Table)";
        scriptOutput.write(String.format(tableReferenceFormat, tableFilename));
        scriptOutput.newLine();

        scriptOutput.write("#ACTIVETBL(Table)");
        scriptOutput.newLine();
        scriptOutput.write("#SMA(\"LOROM00\")");
        scriptOutput.newLine();
        scriptOutput.write("#EMBTYPE(\"LOROM00\", 24, $0)");
        scriptOutput.newLine();
        scriptOutput.newLine();

        String commentLine = "// -----------------------------------------------------------------------------";
        scriptOutput.write(commentLine);
        scriptOutput.newLine();
        scriptOutput.newLine();

        scriptOutput.write("// Update special points for control flow with menus and title screen");
        scriptOutput.newLine();
        for (int i = 0; i < NUM_SPECIAL_POINTERS; i++) {
            scriptOutput.write(String.format("#JMP($%X)", SPECIAL_POINTERS_BANK_OFFSET_LOCATIONS[i]));
            scriptOutput.newLine();
            scriptOutput.write(String.format("#EMBSET(%04d)", i));
            scriptOutput.newLine();
            scriptOutput.newLine();
        }

        scriptOutput.write("// Update the five start points for game's attract mode");
        scriptOutput.newLine();
        scriptOutput.write("#JMP($8359)");
        scriptOutput.newLine();
        for (int i = 0; i < NUM_ATTRACT_MODE_START_POINTS; i++) {
            scriptOutput.write(String.format("#EMBSET(%04d)", i + NUM_SPECIAL_POINTERS));
            scriptOutput.newLine();
        }
        scriptOutput.newLine();

        scriptOutput.write(commentLine);
        scriptOutput.newLine();
        scriptOutput.write("// Insert uncompressed script in 4th MB");
        scriptOutput.newLine();

        scriptOutput.write("#JMP($300000)");
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static boolean currPointerMatches(int listPos, HuffScriptPointer currHuffPtr) throws IOException {
        boolean inArrayBounds = listPos < scriptPointers.size();
        boolean matchOffsets = getFileOffset(currHuffPtr.getPtrValue()) == currByteOffset;
        boolean matchBitOffsets = currHuffPtr.getPtrValueBitOffset() == (bitOffset & 0x7);

        return inArrayBounds && matchOffsets && matchBitOffsets;
    }

    private static boolean isCharEncodingText(int charEncoding) {
        if (charEncoding < MIN_CTRL_CODE_ID) {
            return true;
        }
        boolean isText = false;
        switch (charEncoding) {
            case LINE_0E:
            case TOURU_1B: case MARI_1C:
            case CULPRIT_GUESS_1D: case CULPRIT_GUESS_1E: case CULPRIT_GUESS_1F:
            case PERIOD_58: case COMMA_5B:
            case EXCL_5C: case QUES_5D:
            case EXCL_5E: case QUES_5F:
            case L_QUOTE_60: case L_IN_QUOTE_61:
            case R_QUOTE_59: case R_IN_QUOTE_5A:
                isText = true;
                break;
        }
        return isText;
    }

    private static void dumpScript() throws IOException {
        System.out.println("Dumping script...");
        // go to start of script and print the starting position to output script file
        romFile.seek(scriptStart);
        currByteOffset = scriptStart;

        // indicate start of script with bit offset of "0", but do not update
        // Huffman buffer from having an actual bit offset of 0
        bitOffset = 8;

        // printROMFilePos();
        huffmanBuffer = peekByte();

        // keep track of what number to use for the EMBSETs (direct)
        currPtrNum = NUM_SPECIAL_POINTERS + NUM_ATTRACT_MODE_START_POINTS;

        // keep track of what number to use for the EMBWRITEs (indirect, use as
        // index into script pointer list, and get that pointer's assigned number)
        int currPosInScriptPtrList = 0;

        // use this to write current CPU offset after finding an EMBWRITE, but
        // only if we hadn't just written it after a control code where we do
        boolean justWrotePointerComment = false;

        // it is useful to know the previous character's encoding value for
        // formatting the script output
        int prevCharEncoding = 0xFFFF;
        boolean printedFirstCharForLine = false;
        boolean onNewLine = true;

        boolean inDialogue = false;
        boolean inQuotedDialogue = false;
        boolean autoAdvFlag = false;

        // go to start of script and start reading characters
        // while (romFile.getFilePointer() < scriptEnd && currPosInScriptPtrList < scriptPointers.size()) {
        while (romFile.getFilePointer() < scriptEnd) {
            // there is text beyond the last embedded pointer
            if (currPosInScriptPtrList < scriptPointers.size()) {
                // check if at a target for an embedded pointer, i.e. an EMBWRITE
                HuffScriptPointer currHuffPtr = scriptPointers.get(currPosInScriptPtrList);
                if (shouldWriteDetails) {
                    goryDetails.write("\nChecking: " + currHuffPtr.toString() + "\n");
                }

                while (currPointerMatches(currPosInScriptPtrList, currHuffPtr)) {
                    // write current position in ROM, but only do it as many times as
                    // necessary, which is to say not like:
                    // [text] [ptr] EMBWRITE(n) [ptr] EMBWRITE(x) [text]
                    if (shouldWriteDetails) {
                        goryDetails.write("Match!\n");
                    }
                    if (!justWrotePointerComment) {
                        scriptOutput.newLine();
                        scriptOutput.newLine();
                        printROMFilePos();
                        justWrotePointerComment = true;
                    }
                    String format = "#EMBWRITE(%04d)";
                    scriptOutput.write(String.format(format, currHuffPtr.getPtrNum()));
                    scriptOutput.newLine();

                    currPosInScriptPtrList++;
                    if (currPosInScriptPtrList < scriptPointers.size()) {
                        currHuffPtr = scriptPointers.get(currPosInScriptPtrList);
                        if (shouldWriteDetails) {
                            goryDetails.write("\nChecking: " + currHuffPtr.toString() + "\n");
                        }
                    }
                    onNewLine = true;
                    printedFirstCharForLine = false;
                }
            }

            // get a character and print it to the text file
            int charEncoding = readCharacter();

            // if character is for text and the line started with non-text control
            // codes, do a line break between the ctrl codes and the character
            boolean isText = isCharEncodingText(charEncoding);
            if (isText && onNewLine && !printedFirstCharForLine) {
                if (!justWrotePointerComment && !isCharEncodingText(prevCharEncoding)) {
                    scriptOutput.newLine();
                    // scriptOutput.write("//");
                }
                printedFirstCharForLine = true;
                onNewLine = false;
            }

            // do a line break before a choice code to emphasize it, but not if
            // after a manual line break code
            if (isChoiceCode(charEncoding) && prevCharEncoding != LINE_0E && !justWrotePointerComment) {
                scriptOutput.newLine();
            }
            
            printChar(charEncoding);

            // if got a control code, have to print its arguments as raw bytes
            // and/or print any pointers
            if (charEncoding >= MIN_CTRL_CODE_ID) {
                int codeID = charEncoding & 0xFF;
                int numArgs = argMetadata[codeID] & 0x3;
                int argTypes = argMetadata[codeID] >> 2;

                // choices are special cases that the regular algorithm doesn't cover
                if (isChoiceCode(charEncoding)) {
                    // choice codes take # of arguments in list, N, and use
                    // N+3 as # of Huffman codes, and N+2 as # of pointers
                    int numChoiceArgs = numArgs + 3;
                    for (int i = 0; i < numChoiceArgs; i++) {
                        int arg = readCharacter();
                        printArg(arg);
                    }

                    int numPtrs = numArgs + 2;
                    for (int i = 0; i < numPtrs; i++) {
                        int ptr = readPointer();
                        printPtr(ptr);
                    }

                    if ((bitOffset & 0x7) == 0) {
                        if (shouldWriteDetails) {
                            goryDetails.write("Bit aligned ptr(s) special case!" + "\n");
                        }
                        romFile.readUnsignedByte();
                        huffmanBuffer = peekByte();
                        bitOffset = 8;
                    }
                }

                // get # of arguments and interpret each one properly
                else {
                    for (int i = 0; i < numArgs; i++) {
                        switch (argTypes & 0x1) {
                            case CHAR_ARG:
                                int arg = readCharacter();
                                printArg(arg);
                                break;
                            case PTR_ARG:
                                int ptr = readPointer();
                                printPtr(ptr);
                                if ((bitOffset & 0x7) == 0) {
                                    goryDetails.write("Bit aligned ptr(s) special case!" + "\n");
                                    romFile.readUnsignedByte();
                                    huffmanBuffer = peekByte();
                                    bitOffset = 8;
                                }
                                break;
                        }
                        argTypes >>= 1;
                    }
                }

                // do special stuff for printing to output script
                switch (charEncoding) {
                    // add line breaks in dump after these control codes
                    case LINE_0E:
                    case SET_FLAG_20:
                    case CLEAR_FLAG_21:
                    case SET_TEMP_FLAG_22:
                    case CLEAR_TEMP_FLAG_23:
                    // case END_CHOICE_15:
                    // if you want to look at when silhouettes get loaded
                    // case 0x102B: case 0x102D: case 0x102F:
                    // case 0x1031: case 0x1032: case 0x1033:
                        scriptOutput.newLine();
                        justWrotePointerComment = false;
                        printedFirstCharForLine = false;
                        onNewLine = true;
                        break;

                    case AUTO_ADV_02:
                        autoAdvFlag = true;
                        justWrotePointerComment = false;
                        printedFirstCharForLine = false;
                        onNewLine = false;
                        break;

                    case L_QUOTE_60:
                        inDialogue = true;
                        autoAdvFlag = false;
                        justWrotePointerComment = false;
                        // printedFirstCharForLine = true;
                        // onNewLine = false;
                        break;
                    case L_IN_QUOTE_61:
                        inQuotedDialogue = true;
                        autoAdvFlag = false;
                        justWrotePointerComment = false;
                        // printedFirstCharForLine = true;
                        // onNewLine = false;
                        break;

                    case R_QUOTE_59:
                        // besides clearing this flag, right quote uses same
                        // line breaking logic as for '。', '！', and '？'
                        inDialogue = false;
                    case PERIOD_58:
                    case EXCL_5C:
                    case QUES_5D:
                        if (!inDialogue && !inQuotedDialogue && !autoAdvFlag) {
                            scriptOutput.newLine();
                            onNewLine = true;
                            printedFirstCharForLine = false;
                        }
                        else {
                            printedFirstCharForLine = true;
                            onNewLine = false;
                        }
                        autoAdvFlag = false;
                        justWrotePointerComment = false;
                        break;

                    case R_IN_QUOTE_5A:
                        // game will insert a WAIT code after this if auto adv.
                        // off and not in dialogue, but won't ever line break
                        // we don't need to handle this in script dumper
                        autoAdvFlag = false;
                        inQuotedDialogue = false;
                        printedFirstCharForLine = true;
                        onNewLine = false;
                        break;

                    // print CPU offset for script after these control codes
                    case JMP_0F: case JMP_10:
                    case JMP_11: case JMP_12:
                    case CHOICE_50: case CHOICE_51:
                    case CHOICE_52: case CHOICE_53:
                    case CHOICE_54: case CHOICE_55:
                    case CHOICE_56: case CHOICE_57:
                    case CLEAR_25:
                        scriptOutput.newLine();
                        scriptOutput.newLine();
                        printROMFilePos();
                        justWrotePointerComment = true;
                        printedFirstCharForLine = false;
                        onNewLine = true;
                        break;

                    // add special script position indicating credits
                    // this code pops up a few times in the control flow "text"
                    // at the start of the Huffman data, so only output this if
                    // after the start of the script proper
                    case END_GAME_18:
                        // int cpuOffsetOfCh1Ptr = getRAMOffset(ch1PtrByteOffset);
                        if (currByteOffset >= ch1PtrByteOffset) {
                            String commentLine = "// ----------------------";

                            scriptOutput.newLine();
                            scriptOutput.newLine();
                            scriptOutput.write(commentLine);
                            scriptOutput.newLine();

                            String format = "[$%06X-%d]";
                            int cpuOffset = getCPUOffsetFromOffsetVar();
                            scriptOutput.write(String.format("//  ENDING @ " + format, cpuOffset, bitOffset));
                            scriptOutput.newLine();

                            scriptOutput.write(commentLine);
                            scriptOutput.newLine();
                        }
                        justWrotePointerComment = false;

                        // indicate progress in command line output
                        // System.out.println(String.format("Got ctrl code 1018 at " + format, cpuOffset, bitOffset));
                        // goryDetails.write(String.format("Got to ending at " + format + "\n", cpuOffset, bitOffset));
                        break;

                    default:
                        justWrotePointerComment = false;
                        // printedFirstCharForLine = true;
                        // onNewLine = false;
                        break;
                }
            }
            else {
                justWrotePointerComment = false;
                onNewLine = false;
                printedFirstCharForLine = true;
            }
            prevCharEncoding = charEncoding;
        }
        scriptOutput.newLine();
        scriptOutput.write("// END OF SCRIPT");
        romFile.close();
        System.out.println("Script dump finished");
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    public static void main(String args[]) throws IOException {
        if (args.length != 4) {
            System.out.println("Sample usage: java HuffScriptDumper rom_name table_file script_start script_end");
            System.out.println("Script range in original JP ROM: 2FCE1 and 7788D");
            return;
        }

        String romFilepath = args[0];
        String tableFilename = args[1];
        scriptStart = Integer.parseInt(args[2], 16);
        scriptEnd = Integer.parseInt(args[3], 16);

        if (scriptStart >= scriptEnd) {
            System.out.println("Error - script start point must be before script end point");
            return;
        }

        romFile = new RandomAccessFile(romFilepath, "r");
		int folderPathLength = romFilepath.lastIndexOf("\\");
        String folderPath = folderPathLength == -1 ? "" : romFilepath.substring(0, folderPathLength);
        String romFilename = romFilepath.substring(folderPath.length() + 1);
		
        scriptOutput = new BufferedWriter(new FileWriter("script/script dump for '" + romFilename + "'.txt"));
        goryDetails = new BufferedWriter(new FileWriter("script/output.txt"));

        readTableFile(tableFilename);
        getCtrlCodeArgTable();
        getHuffmanTreeData();

        shouldWriteDetails = false;

        scriptPointers = new ArrayList<>(NUM_POINTERS_TOTAL);
        getScriptStartPoints();
        getAttractModeStartPoints();
        getPtrToChapter1();
        getScriptPointers();
        // sort script pointers by their values i.e. where they point to (EMBWRITEs)
        // they are assigned numbers based on where to write them (EMBSETs)
        Collections.sort(scriptPointers);
        outputScriptPointers();

        addAtlasHeader(tableFilename);
        shouldWriteDetails = false;
        dumpScript();

        romFile.close();
        scriptOutput.flush();
        scriptOutput.close();
        goryDetails.flush();
        goryDetails.close();
    }
}
