package silhouettes;

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

public class RecompressSilhouetteGfx {

    private static class DataGroup {
        private boolean isRun;
        private int length;
        private int position;

        public DataGroup(boolean isRun, int length, int position) {
            // do special case where a single 00 or FF should be encoded as a
            // "run" of length 1, instead of as a literal
            if (!isRun && length == 1) {
                int value = gfxData[position];
                isRun = value == 0x00 || value == 0xFF;
            }
            this.isRun = isRun;
            this.length = length;
            this.position = position;
        }

        public int getNumBytesWhenCompressed() {
            if (!isRun) return 1 + length;

            int result = 1;
            int value = gfxData[position];
            if (value != 0x00 && value != 0xFF) result++;
            return result;
        }

        public boolean equals(Object obj) {
            if (obj == null) return false;
            if (!(obj instanceof DataGroup)) return false;
            DataGroup other = (DataGroup) obj;
            return (isRun == other.isRun) &&
                   (length == other.length) &&
                   (position == other.position);
        }

        public String toString() {
            String format = "0x%4X: 0x%2X %s";
            String type = "";
            if (isRun) {
                type = String.format("run of %02X", gfxData[position]);
            }
            else {
                type = "lits";
            }
            return String.format(format, position, length, type);
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static FileInputStream graphics;
    private static FileOutputStream outputFile;
    private static BufferedWriter logFile;
    private static int[] gfxData;
    private static ArrayList<DataGroup> dataGroups;
    private static int totalSizeOfRecompressedSilhs;
    private static RandomAccessFile romFile;

    // experiment with each category's max lengths to see what minimizes sizes
    private static final int MAX_RUN_NN_LENGTH = 0xa;
    private static final int MAX_CONSEC_LITERALS = 0xe;
    private static final int MAX_RUN_FF_LENGTH = 0x38;
    private static final int MAX_RUN_00_LENGTH = 0x100 - MAX_RUN_NN_LENGTH - MAX_CONSEC_LITERALS - MAX_RUN_FF_LENGTH;

    private static final int END_OF_DATA = 0x00;
    private static final int BITMASK_LITERALS = 0x00;
    private static final int BITMASK_RUN_OTHER = 1 + MAX_CONSEC_LITERALS;
    private static final int BITMASK_RUN_FF = MAX_CONSEC_LITERALS + MAX_RUN_NN_LENGTH;
    private static final int BITMASK_RUN_00 = 0x100 - MAX_RUN_00_LENGTH;

    private static final int CHUNSOFT_BANK_ADV = 0x40;
    private static final int BANK_SIZE = 0x8000;

    private static final int SPRITE_BUFFER_SIZE = 0x2000;
    private static final int BYTES_PER_TILE = 0x10;

    private static final int BANK_ADV = 0x10;
    private static final int FILLER_FF = 0xFF;
    private static final int LAST_OFFSET_IN_BANK = BANK_SIZE - 1;

    private static final int SILH_GFX_PTR_TABLE = 0x25BA5E; // $4BBA5E
    private static final int SILH_GFX_TABLE_SIZE = 0x2F6;

    private static final String OUTPUT_FOLDER = "recompressed silh gfx/";

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void decompressSilhGfxBlockNum(int idNum) throws IOException {
        // read pointer from pointer table and convert to file offset
        romFile.seek(SILH_GFX_PTR_TABLE + idNum*3);
        int bankOffset = romFile.readUnsignedByte();
        bankOffset |= romFile.readUnsignedByte() << 8;
        int bankNum = romFile.readUnsignedByte();

        int filePos = (bankNum - 1) * 0x8000 + bankOffset;
        decompressSilhGfxBlockAtRomPosition(filePos);
    }

    private static void decompressSilhGfxBlockAtRomPosition(int filePos) throws IOException {
        romFile.seek(filePos);

        int spriteData[] = new int[SPRITE_BUFFER_SIZE];

        int gfxSize = 0;
        int typeByte = romFile.readUnsignedByte();
        int groupSize = 0;
        while (gfxSize < spriteData.length && typeByte != END_OF_DATA) {
            groupSize = typeByte & 0x3F;
            // bank advance case
            if (typeByte == CHUNSOFT_BANK_ADV) {
                while ((romFile.getFilePointer() & LAST_OFFSET_IN_BANK) != 0) {
                    romFile.readUnsignedByte();
                }
            }
            else {
                int caseNum = typeByte >> 6;
                // literal data case
                if (caseNum == 0x2) {
                    groupSize++;
                    while (groupSize != 0 && gfxSize < spriteData.length) {
                        spriteData[gfxSize] = romFile.readUnsignedByte();
                        gfxSize++;
                        groupSize--;
                    }
                }
                else {
                    // use same loop for the three run cases: 00, FF, NN
                    int dataByte = 0x00;
                    // if (caseNum == 0x0) dataByte = 0x00;
                    if (caseNum == 0x1) {
                        dataByte = 0xFF;
                    }
                    else if (caseNum == 0x3) {
                        dataByte = romFile.readUnsignedByte();
                        groupSize++;
                    }
                    while (groupSize != 0 && gfxSize < spriteData.length) {
                        spriteData[gfxSize] = dataByte;
                        gfxSize++;
                        groupSize--;
                    }
                }
            }
            typeByte = romFile.readUnsignedByte();
        }

        gfxData = new int[gfxSize];
        for (int i = 0; i < gfxData.length; i++) {
            gfxData[i] = spriteData[i];
        }
    }

    private static void spotChangeCertainTilesets(int idNum) {
        if (idNum == 0x6E) {
            // fix: two tiles for sprite 001 are empty space but should be full
            // this is in the spy route at $0b89ad-4 in the JP game script
            for (int i = 0; i < 0x8; i++) {
                gfxData[0x2 * BYTES_PER_TILE + 0x8 + i] = 0xFF;
                gfxData[0x3 * BYTES_PER_TILE + 0x8 + i] = 0xFF;
            }
        }
        else if (idNum == 0x1E9) {
            // fix: two tiles in animation frame 0x267 that don't seem to fit
            // with the existing silhouette of Kanako
            for (int i = 0; i < 0x8; i++) {
                gfxData[0x119 * BYTES_PER_TILE + 8 + i] = 0x00;
                gfxData[0x11D * BYTES_PER_TILE + 8 + i] = 0x00;
            }
        }
        else if (idNum == 0x1EA) {
            // fix: one PIXEL between Tooru and Kanako in animation frame 0x26B
            // shouldn't be there
            gfxData[0x75 * BYTES_PER_TILE + 7] = 0x00;

            // fix: one tile in animation frame 0x26D looks out of place with
            // the existing silhouette of Kanako
            for (int i = 0; i < 0x8; i++) {
                gfxData[0xDD * BYTES_PER_TILE + i] = 0x00;
            }
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    @SuppressWarnings("unused")
    private static String removeFileExtension(String filename) {
        int periodIndex = filename.lastIndexOf('.');
        return periodIndex == -1 ? filename : filename.substring(0, periodIndex);
    }

    @SuppressWarnings("unused")
    private static void getGfxDataAsArray(String inputFile) throws IOException {
        // get file's size to know the exact size for the array
        File gfxFile = new File(inputFile);
        long fileLength = gfxFile.length();
        gfxData = new int[(int) fileLength];

        graphics = new FileInputStream(inputFile);
        // graphics.read(gfxData);
        for (int i = 0; i < gfxData.length; i++) {
            gfxData[i] = graphics.read();
        }
        graphics.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int getRunLengthAtPosition(int startPos) {
        if (startPos < 0 || startPos >= gfxData.length) return 0;

        int sizeLimit = 0;
        int startVal = gfxData[startPos];
        switch (startVal) {
            case 0x00:
                sizeLimit = MAX_RUN_00_LENGTH;
                break;
            case 0xFF:
                sizeLimit = MAX_RUN_FF_LENGTH;
                break;
            default:
                sizeLimit = MAX_RUN_NN_LENGTH;
                break;
        }

        int size = 1;
        while (startPos + size < gfxData.length && size < sizeLimit) {
            if (startVal != gfxData[startPos + size]) {
                break;
            }
            size++;
        }
        return size;
    }

    private static void getDataGroups() {
        dataGroups = new ArrayList<>();

        int pos = 0;
        int numLits = 0;
        while (pos < gfxData.length) {
            int runLength = getRunLengthAtPosition(pos);
            if (runLength == 1) {
                numLits++;
                if (numLits == MAX_CONSEC_LITERALS) {
                    DataGroup lits = new DataGroup(false, numLits, pos - numLits + 1);
                    dataGroups.add(lits);
                    numLits = 0;
                }
            }
            else {
                if (numLits != 0) {
                    DataGroup group = new DataGroup(false, numLits, pos - numLits);

                    dataGroups.add(group);
                    numLits = 0;
                }

                DataGroup run = new DataGroup(true, runLength, pos);
                dataGroups.add(run);
            }
            pos += runLength;
        }

        // output any straggling literals at end of data
        if (numLits > 0) {
            DataGroup group = new DataGroup(false, numLits, pos - numLits);
            dataGroups.add(group);
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    // used this when analyzing the data to check absolute sizes of lits/runs
    /*
    private static int getAbsoluteRunLengthAtPosition(int startPos) {
        if (startPos < 0 || startPos >= gfxData.length) return 0;

        // do not limit the max size of the run
        int size = 1;
        int startVal = gfxData[startPos];
        while (startPos + size < gfxData.length) {
            if (startVal != gfxData[startPos + size]) {
                break;
            }
            size++;
        }
        return size;
    }

    private static ArrayList<DataGroup> getGroupsWithoutSizeLimits() {
        ArrayList<DataGroup> groups = new ArrayList<>();

        int pos = 0;
        int numLits = 0;
        while (pos < gfxData.length) {
            int runLength = getAbsoluteRunLengthAtPosition(pos);
            if (runLength == 1) {
                numLits++;
            }
            else {
                if (numLits != 0) {
                    DataGroup group = new DataGroup(false, numLits, pos - numLits);

                    groups.add(group);
                    numLits = 0;
                }

                DataGroup run = new DataGroup(true, runLength, pos);
                groups.add(run);
            }
            pos += runLength;
        }

        // output any straggling literals at end of data
        if (numLits > 0) {
            DataGroup group = new DataGroup(false, numLits, pos - numLits);
            groups.add(group);
        }
        return groups;
    }
    */

    @SuppressWarnings("unused")
    private static void interpretGroups() throws IOException {
        interpretGroups(dataGroups);
    }

    private static void interpretGroups(ArrayList<DataGroup> groups) throws IOException {
        // for debugging group creation process -- sizes, starts, types
        for (DataGroup dg : groups) {
            logFile.write(dg.toString() + "\n");
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int getNumBanks(int size) {
        // return size >> 15;
        return size / BANK_SIZE;
    }

    private static void writeByteToCompressedFile(int value) throws IOException {
        outputFile.write(value);
        totalSizeOfRecompressedSilhs++;
    }

    private static void generateCompressedFile() throws IOException {
        int startTotalSize = totalSizeOfRecompressedSilhs;
        for (DataGroup dg : dataGroups) {
            // writeCompressedDataForGroup(dg, startTotalSize);
            writeCompressedDataForGroupNoBankChecking(dg, startTotalSize);
        }

        // write the format's end of data marker; it is perfectly acceptable to
        // have it at the end of the bank
        logFile.write(String.format("(0x%5X, 0x%4X) 00 terminator\n", totalSizeOfRecompressedSilhs, totalSizeOfRecompressedSilhs - startTotalSize));
        writeByteToCompressedFile(END_OF_DATA);

        logFile.write(String.format("(0x%5X, 0x%4X) End of data\n", totalSizeOfRecompressedSilhs, totalSizeOfRecompressedSilhs - startTotalSize));
    }

    private static void writeCompressedDataForGroupNoBankChecking(DataGroup dg, int startTotalSize) throws IOException {
        int sizeOfFileSoFar = totalSizeOfRecompressedSilhs - startTotalSize;
        if (!dg.isRun) {
            logFile.write(String.format("(0x%5X, 0x%4X) %s\n", totalSizeOfRecompressedSilhs, sizeOfFileSoFar, dg.toString()));

            // encode literal case and size of the group
            int ctrlByte = BITMASK_LITERALS + dg.length;
            writeByteToCompressedFile(ctrlByte);

            // write the sequence's bytes from file into output
            for (int i = 0; i < dg.length; i++) {
                writeByteToCompressedFile(gfxData[dg.position + i]);
            }
        }
        else {
            int bitmask = 0;
            int encodedSize = dg.length - 1;

            // encode the run length and the case
            int runValue = gfxData[dg.position];
            if (runValue == 0x00) {
                bitmask = BITMASK_RUN_00;
            }
            else if (runValue == 0xFF) {
                bitmask = BITMASK_RUN_FF;
            }
            else {
                bitmask = BITMASK_RUN_OTHER;
                encodedSize--;
                // a run of any byte except 00 or FF is assumed to be length 2+
            }

            logFile.write(String.format("(0x%5X, 0x%4X) %s\n", totalSizeOfRecompressedSilhs, sizeOfFileSoFar, dg.toString()));
            writeByteToCompressedFile(bitmask + encodedSize);
            // write the data byte for the run if not 0x00 or 0xFF
            if (runValue != 0x00 && runValue != 0xFF) {
                writeByteToCompressedFile(runValue);
            }
        }
    }
 
    // keeping this here to give you an idea of how much more work it takes to
    // compress if you don't have an ASM hack for automatic bank wrapping :P
    @SuppressWarnings("unused")
    private static void writeCompressedDataForGroup(DataGroup dg, int startTotalSize) throws IOException {
        // if you want ideas for how to implement, see logs for ctrl code IDs:
        // 02B 04B 073 0A8 0CF 100 125 156 17E 1AB 1D3 206 233 258 283 2AD 2D9
        int compressedSize = dg.getNumBytesWhenCompressed();
        int startOffset = totalSizeOfRecompressedSilhs;
        int endOffset = startOffset + compressedSize - 1;
        int sizeOfFileSoFar = totalSizeOfRecompressedSilhs - startTotalSize;
        boolean groupFitsInCurrentBank = getNumBanks(startOffset) == getNumBanks(endOffset);
        boolean enoughSpaceForBankAdv = (endOffset & LAST_OFFSET_IN_BANK) < LAST_OFFSET_IN_BANK;

        if (!dg.isRun) {
            if (groupFitsInCurrentBank && enoughSpaceForBankAdv) {
                logFile.write(String.format("(0x%5X, 0x%4X) %s\n", totalSizeOfRecompressedSilhs, sizeOfFileSoFar, dg.toString()));

                // encode literal case and size of the group
                int ctrlByte = BITMASK_LITERALS | dg.length;
                writeByteToCompressedFile(ctrlByte);

                // write the sequence's bytes from file into output
                for (int i = 0; i < dg.length; i++) {
                    writeByteToCompressedFile(gfxData[dg.position + i]);
                }
            }
            else if (groupFitsInCurrentBank && !enoughSpaceForBankAdv) {
                // were you to write the whole group now, its last data byte
                // would be at the end of the bank (at LoROM offset $nnFFFF)
                // so write (N-1 bytes) group, bank adv, and (last byte) group

                // but if N=1, writing a 0 lit group doesn't make sense, so must
                // write bank advance and fill last byte with something
                if (dg.length == 1) {
                    logFile.write(String.format("(0x%5X, 0x%4X) Bank adv + FF\n", totalSizeOfRecompressedSilhs, sizeOfFileSoFar));
                    writeByteToCompressedFile(BANK_ADV);
                    writeByteToCompressedFile(FILLER_FF);
                }
                else {
                    DataGroup allButLastByte = new DataGroup(false, dg.length - 1, dg.position);
                    writeCompressedDataForGroup(allButLastByte, startTotalSize);
                    logFile.write(String.format("(0x%5X, 0x%4X) Bank adv\n", totalSizeOfRecompressedSilhs, sizeOfFileSoFar + dg.getNumBytesWhenCompressed()));
                    writeByteToCompressedFile(BANK_ADV);
                }
                writeCompressedDataForGroup(new DataGroup(false, 1, dg.position + dg.length - 1), startTotalSize);
            }
            else {
                // if group doesn't fit into bank, get # bytes left in the bank
                int numBytesLeftInBank = BANK_SIZE - (LAST_OFFSET_IN_BANK & totalSizeOfRecompressedSilhs);
                if (numBytesLeftInBank == 1) {
                    // if only one byte left, just write bank advance, then the
                    // group in the next bank
                    logFile.write(String.format("(0x%5X, 0x%4X) Bank adv\n", totalSizeOfRecompressedSilhs, sizeOfFileSoFar));
                    writeByteToCompressedFile(BANK_ADV);
                    writeCompressedDataForGroup(dg, startTotalSize);
                }
                else if (numBytesLeftInBank == 2) {
                    // if two bytes left, writing bank advance leaves you room
                    // for only a "0 lits" type byte with no data, so must write
                    // bank advance, fill offset $xxFFFF with something, and
                    // write the group in the next bank
                    logFile.write(String.format("(0x%5X, 0x%4X) Bank adv + FF\n", totalSizeOfRecompressedSilhs, sizeOfFileSoFar));
                    writeByteToCompressedFile(BANK_ADV);
                    writeByteToCompressedFile(FILLER_FF);
                    writeCompressedDataForGroup(dg, startTotalSize);
                }
                else {
                    // if 3+ bytes left, we can fit in a lits tag with as many
                    // bytes as we can before the bank advance byte
                    DataGroup group1 = new DataGroup(false, numBytesLeftInBank - 2, dg.position);
                    writeCompressedDataForGroup(group1, startTotalSize);
                    logFile.write(String.format("(0x%5X, 0x%4X) Bank adv", totalSizeOfRecompressedSilhs, sizeOfFileSoFar));
                    writeByteToCompressedFile(BANK_ADV);

                    // group 1 possibly could have been a single 00 or FF, which
                    // gets encoded as 1 byte instead of the typical 2 for a lit
                    // in this case, must fill $nnFFFF with something
                    if (group1.getNumBytesWhenCompressed() == 1) {
                        logFile.write(" + FF");
                        writeByteToCompressedFile(FILLER_FF);
                    }
                    logFile.write("\n");

                    // write the group's remaining bytes in the next bank
                    DataGroup group2 = new DataGroup(false, dg.length - group1.length, dg.position + group1.length);
                    writeCompressedDataForGroup(group2, startTotalSize);
                }
            }
        }
        else {
            int bitmask = 0;
            int encodedSize = dg.length - 1;

            // encode the run length and the case
            int runValue = gfxData[dg.position];
            if (runValue == 0x00) {
                bitmask = BITMASK_RUN_00;
            }
            else if (runValue == 0xFF) {
                bitmask = BITMASK_RUN_FF;
            }
            else {
                bitmask = BITMASK_RUN_OTHER;
            }

            if (groupFitsInCurrentBank) {
                if (enoughSpaceForBankAdv) {
                    logFile.write(String.format("(0x%5X, 0x%4X) %s\n", totalSizeOfRecompressedSilhs, sizeOfFileSoFar, dg.toString()));
                    writeByteToCompressedFile(bitmask + encodedSize);
                    // write the data byte for the run if not 0x00 or 0xFF
                    if (runValue != 0x00 && runValue != 0xFF) {
                        writeByteToCompressedFile(runValue);
                    }
                }
                else {
                    // if encoded run would end on LoROM bank offset $nnFFFF,
                    // write bank advance here
                    logFile.write(String.format("(0x%5X, 0x%4X) Bank adv", totalSizeOfRecompressedSilhs, sizeOfFileSoFar));
                    writeByteToCompressedFile(BANK_ADV);

                    // if compressed size is 2, the bank advance was written at
                    // $nnFFFE, so must fill in $nnFFFF with something
                    if (compressedSize == 2) {
                        logFile.write(" + FF");
                        writeByteToCompressedFile(FILLER_FF);
                    }
                    logFile.write("\n");

                    writeCompressedDataForGroup(dg, startTotalSize);
                }
            }
            else {
                // if run is encoded in 2 bytes and would start on LoROM bank
                // offset $nnFFFF, just write bank advance, and then the run
                logFile.write(String.format("(0x%5X, 0x%4X) Bank adv\n", totalSizeOfRecompressedSilhs, sizeOfFileSoFar));
                writeByteToCompressedFile(BANK_ADV);
                writeCompressedDataForGroup(dg, startTotalSize);
            }
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void recompressGoldBookmarkSprites() throws IOException {
        String outputFilename = OUTPUT_FOLDER + "recompressed gold bookmark sprites $01F0C0.bin";
        String logFilename = OUTPUT_FOLDER + "LOG gold bookmark sprites $01F0C0.txt";

        totalSizeOfRecompressedSilhs = 0;
        decompressSilhGfxBlockAtRomPosition(0xf0c0);
        getDataGroups();

        outputFile = new FileOutputStream(outputFilename);
        logFile = new BufferedWriter(new FileWriter(logFilename));
        generateCompressedFile();

        outputFile.close();
        logFile.flush();
        logFile.close();
        System.out.printf("Recompressed size of gold bookmark sprites: %d = 0x%X\n\n", totalSizeOfRecompressedSilhs, totalSizeOfRecompressedSilhs);
    }

    public static void main(String args[]) throws IOException {
        /*
        if (args.length == 0) {
            System.out.println("Sample usage: java RecompressSilhouetteGfx data1.bin [data2.bin data3.bin ...]");
            return;
        }
        */
		
        System.out.printf("Size limits:  00,FF,LL,NN -> %02X,%02X,%02X,%02X\n",
               MAX_RUN_00_LENGTH, MAX_RUN_FF_LENGTH, MAX_CONSEC_LITERALS, MAX_RUN_NN_LENGTH);
        System.out.printf("Range starts: LL,NN,FF,00 -> %02X,%02X,%02X,%02X\n",
               BITMASK_LITERALS + 1, BITMASK_RUN_OTHER, BITMASK_RUN_FF, BITMASK_RUN_00);


        String romFilename = "rom/Kamaitachi no Yoru (Japan).sfc";
        romFile = new RandomAccessFile(romFilename, "r");

        Files.createDirectories(Paths.get(OUTPUT_FOLDER));

        recompressGoldBookmarkSprites();

        totalSizeOfRecompressedSilhs = 0;
        for (int idNum = 0; idNum < SILH_GFX_TABLE_SIZE; idNum++) {
            String outputFilename = String.format(OUTPUT_FOLDER + "recompressed silh sprites block 0x%03X.bin", idNum);
            String logFilename = String.format(OUTPUT_FOLDER + "LOG silh sprites block 0x%03X.txt", idNum);

            decompressSilhGfxBlockNum(idNum);
            spotChangeCertainTilesets(idNum);
            getDataGroups();

            int prevSize = totalSizeOfRecompressedSilhs;
            outputFile = new FileOutputStream(outputFilename);
            logFile = new BufferedWriter(new FileWriter(logFilename));
            generateCompressedFile();
            outputFile.close();
            logFile.flush();
            logFile.close();

            if (getNumBanks(totalSizeOfRecompressedSilhs) > getNumBanks(prevSize)) {
                System.out.printf("Bank crossed with silh gfx block 0x%3X\n",idNum);
            }
        }
        romFile.close();

        /*
        final String FILE_PREFIX = "recompressed ";
        for (String inputFile : args) {
            // allow using a wildcard like: java RecompressGraphics *.bin
            // however, do not compress any binary files that themselves are
            // the result of compressing a binary file with this program
            if (inputFile.startsWith(FILE_PREFIX)) {
                continue;
            }

            String outputFilename = FILE_PREFIX + inputFile;
            String logFilename = "LOG " + removeFileExtension(inputFile) + ".txt";

            getGfxDataAsArray(inputFile);
            getDataGroups();

            int prevSize = totalSizeOfRecompressedSilhs;
            outputFile = new FileOutputStream(outputFilename);
            logFile = new BufferedWriter(new FileWriter(logFilename));
            // interpretGroups(getGroupsWithoutSizeLimits());
            generateCompressedFile();
            outputFile.close();
            logFile.flush();
            logFile.close();

            if (getNumBanks(totalSizeOfRecompressedSilhs) > getNumBanks(prevSize)) {
                System.out.println("Bank crossed with " + inputFile);
            }
        }
        */
        System.out.printf("Total space: %d = 0x%X\n", totalSizeOfRecompressedSilhs, totalSizeOfRecompressedSilhs);
    }
}
