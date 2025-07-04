import java.io.BufferedWriter;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;

public class KamaitachiSilhouetteDecomp {
    private static final int SILH_BUFFER_SIZE = 0x2000;
    private static final int NUM_FRAME_IDS = 0x3AC;
    private static final int NUM_SILH_CTRL_CODE_IDS = 0x2F6;

    private static final int NUM_BITS_IN_WORD = 0x10;
    private static final int END_DATA = 0x00;
    private static final int ADV_BANK = 0x40;
    private static final int BANK_SIZE = 0x8000;

    private static final int SILH_CONSTR_DATA_PTR_LIST_LOCATION = 0x258000; // $4B8000
    private static final int SILH_OAM_PTR_LIST_LOCATION = 0x25A802; // $4BA802
    private static final int FRAME_ID_MAPPING_LOCATION   = 0x25B306; // $4BB306
    private static final int SILH_OAM_GRID_PTR_LIST_LOCATION = 0x259CFE; // $4B9CFE
    private static final int SILH_PTR_LIST_LOCATION     = 0x25BA5E; // $4BBA5E
    private static final int SILH_DATA_SIZES_LOCATION   = 0x25C340; // $4BC340

    private static HashMap<Integer,Integer> silhCtrlCodeInputFromFrameId;
    private static int[] silhGFXPtrs = new int[NUM_SILH_CTRL_CODE_IDS];
    private static int[] silhOAMPtrs = new int[NUM_FRAME_IDS];
    private static int[] silhOAMGridPtrs = new int[NUM_FRAME_IDS];
    private static int[] silhConstrDataPtrs = new int[NUM_SILH_CTRL_CODE_IDS];
    private static int[] silhSizes = new int[NUM_SILH_CTRL_CODE_IDS];
    private static int[] silhBuffer = new int[SILH_BUFFER_SIZE];
    private static HashMap<Integer, ArrayList<Integer>> frameIdListFromInputs;
    private static int silhBufferOffset;

    private static RandomAccessFile romFile;

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static int readWord() throws IOException {
        int word = romFile.readUnsignedByte() |
                  (romFile.readUnsignedByte() << 8);
        return word;
    }

    private static int readPtr() throws IOException {
        int ptr = romFile.readUnsignedByte() |
                 (romFile.readUnsignedByte() << 8) |
                 (romFile.readUnsignedByte() << 16);
        return ptr;
    }

    private static int getRomPtr(int cpuPtr) {
        int bankNum = cpuPtr >> 16;
        int bankOffset = cpuPtr & 0xFFFF;
        return (bankNum - 1) * BANK_SIZE + bankOffset;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void getGraphicsSizes() throws IOException {
        romFile.seek(SILH_DATA_SIZES_LOCATION);
        for (int i = 0; i < NUM_SILH_CTRL_CODE_IDS; i++) {
            silhSizes[i] = readWord();
        }
    }

    private static void getFrameIdMappings() throws IOException {
        romFile.seek(FRAME_ID_MAPPING_LOCATION);
        silhCtrlCodeInputFromFrameId = new HashMap<>();
        for (int i = 0; i < NUM_FRAME_IDS; i++) {
            silhCtrlCodeInputFromFrameId.put(i, readWord());
        }
    }

    private static void getSilhGFXPtrs() throws IOException {
        romFile.seek(SILH_PTR_LIST_LOCATION);
        for (int i = 0; i < NUM_SILH_CTRL_CODE_IDS; i++) {
            silhGFXPtrs[i] = readPtr();
        }
    }

    private static void getSilhOAMPtrs() throws IOException {
        romFile.seek(SILH_OAM_PTR_LIST_LOCATION);
        for (int i = 0; i < NUM_FRAME_IDS; i++) {
            silhOAMPtrs[i] = readPtr();
        }
    }

    private static void getSilhOAMGridPtrs() throws IOException {
        romFile.seek(SILH_OAM_GRID_PTR_LIST_LOCATION);
        for (int i = 0; i < NUM_FRAME_IDS; i++) {
            silhOAMGridPtrs[i] = readPtr();
        }
    }

    private static void getSilhConstrDataPtrs() throws IOException {
        romFile.seek(SILH_CONSTR_DATA_PTR_LIST_LOCATION);
        for (int i = 0; i < NUM_SILH_CTRL_CODE_IDS; i++) {
            silhConstrDataPtrs[i] = readPtr();
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static HashMap<Integer, ArrayList<Integer>> getFrameIdListsForCtrlCodeInputs() {
        // assemble a HashMap that, given a silhouette ctrl code input, outputs
        // a list of the frame IDs that it accesses; e.g. in JP game, input 0x2E
        // should give the list {04D, 04E, 04F, ..., 05C, 05D}
        frameIdListFromInputs = new HashMap<>(NUM_SILH_CTRL_CODE_IDS);
        for (int frameIdNum = 0; frameIdNum < NUM_FRAME_IDS; frameIdNum++) {
            // get silhouette ctrl code input from frame ID
            int ctrlCodeInput = silhCtrlCodeInputFromFrameId.get(frameIdNum);

            // get the list of frame IDs for the particular ctrl code input
            // either get a populated list, or an empty list (not null)
            ArrayList<Integer> frameListForThisInput = frameIdListFromInputs.get(ctrlCodeInput);
            if (frameListForThisInput == null) {
                frameListForThisInput = new ArrayList<>();
            }

            // add the current frame ID, and update HashMap entry for
            // the corresponding control code input
            frameListForThisInput.add(frameIdNum);
            frameIdListFromInputs.put(ctrlCodeInput, frameListForThisInput);
        }

        return frameIdListFromInputs;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void outputListOfFrameIdsForCtrlCodeInputs() throws IOException {
        BufferedWriter table = new BufferedWriter(new FileWriter("silhouette set lists.txt"));

        for (int ctrlCodeInput = 0; ctrlCodeInput < NUM_SILH_CTRL_CODE_IDS; ctrlCodeInput++) {
            String line = String.format("%03X: ", ctrlCodeInput);
            ArrayList<Integer> frameIdList = frameIdListFromInputs.get(ctrlCodeInput);

            boolean firstInList = true;
            for (int frameID : frameIdList) {
                String format = "%03X";
                if (!firstInList) {
                    format =  ", " + format;
                }
                line += String.format(format, frameID);
                firstInList = false;
            }
            table.write(line + "\n");
        }

        table.flush();
        table.close();
    }

    private static void outputTableOfSilhPtrs() throws IOException {
        BufferedWriter table = new BufferedWriter(new FileWriter("silhouette pointer table.txt"));

        table.write("Tables: $4BB306   $4B8000    $4BA802    $4BBA5E    $4B9CFE    $4BC340\n");
        table.write(" Frame | Input | Construct | OAM data | GFX data | X/Y grid |  Size   | 32x32?\n");
        table.write("-------+-------+-----------+----------+----------+----------+---------+--------\n");

        String format = "  %3X  |  %s  |  %s  | $%06X  | %s  | $%06X  |   %s   | %s\n";
        for (int frameId = 0; frameId < NUM_FRAME_IDS; frameId++) {
            int ctrlCodeInput = silhCtrlCodeInputFromFrameId.get(frameId);
            int lastCtrlCodeInput = -1;
            if (frameId > 0) {
                lastCtrlCodeInput = silhCtrlCodeInputFromFrameId.get(frameId - 1);
            }

            String ctrlCodeInputHexString = String.format("%03X", ctrlCodeInput);
            String gfxPtrString = "";
            String constrPtrString = "";
            String sizeString = "";
            String largeSprites = "";
            if (ctrlCodeInput == lastCtrlCodeInput) {
                ctrlCodeInputHexString = "---";
                gfxPtrString = "-------";
                constrPtrString = "-------";
                sizeString = "---";
            }
            else {
                int gfxPtr = silhGFXPtrs[ctrlCodeInput];
                int size = silhSizes[ctrlCodeInput];
                int constrPtr = silhConstrDataPtrs[ctrlCodeInput];

                gfxPtrString = String.format("$%06X", gfxPtr);
                constrPtrString = String.format("$%06X", constrPtr);
                sizeString = String.format("%3X", size);

                boolean smallSprites = frameIdHasSmallSprites(frameId);
                if (!smallSprites) {
                    largeSprites = "32x32";
                }
            }

            int oamPtr = silhOAMPtrs[frameId];
            int gridPtr = silhOAMGridPtrs[frameId];
            table.write(String.format(format, frameId, ctrlCodeInputHexString, constrPtrString, oamPtr, gfxPtrString, gridPtr, sizeString, largeSprites));
        }

        table.flush();
        table.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // Silhouette construction data

    private static void outputAllConstructionBinaryData() throws IOException {
        // create a text file and write the data to it
        BufferedWriter textFile = new BufferedWriter(new FileWriter("silhouette construction data.txt"));

        String dataFormat = "%04X";
        for (int ctrlCodeInput = 0; ctrlCodeInput < silhConstrDataPtrs.length; ctrlCodeInput++) {
            int constrPtr = getRomPtr(silhConstrDataPtrs[ctrlCodeInput]);
            romFile.seek(constrPtr);

            int firstWord = readWord();
            String line = String.format("Input 0x%3X: " + dataFormat, ctrlCodeInput, firstWord);
            while (true) {
                int word = readWord();

                // terminate if value has MSB set
                if ((word & 0x8000) != 0) break;

                // special case for printing color value for silhouette
                if ((word & 0x6000) == 0x6000) {
                    int colorVal = readWord();
                    line += String.format(" [%04X %04X]", word, colorVal);
                }

                else {
                    line += String.format(" " + dataFormat, word);
                }
            }
            textFile.write(line);

            if ((firstWord & 0x2000) != 0) {
                textFile.write(" LARGE SPRITES");
            }
            textFile.newLine();
        }

        textFile.flush();
        textFile.close();
    }

    private static boolean frameIdHasSmallSprites(int frameId) throws IOException {
        // preserve file pointer for romFile after this call
        long filePtr = romFile.getFilePointer();

        int ctrlCodeInput = silhCtrlCodeInputFromFrameId.get(frameId);
        int constrPtr = getRomPtr(silhConstrDataPtrs[ctrlCodeInput]);
        romFile.seek(constrPtr);
        int firstWord = readWord();

        romFile.seek(filePtr);
        return (firstWord & 0x2000) == 0;
    }

    private static void outputConstructionData(int ctrlCodeInput, String outputFolder) throws IOException {
        if (ctrlCodeInput < 0 || ctrlCodeInput >= NUM_SILH_CTRL_CODE_IDS)
            return;

        // create a text file and write the data to it
        String fileName = String.format(outputFolder + "/! silh ctrl code input 0x%03X info.txt", ctrlCodeInput);
        BufferedWriter textFile = new BufferedWriter(new FileWriter(fileName));

        String dataFormat = "%04X";
        int constrPtr = getRomPtr(silhConstrDataPtrs[ctrlCodeInput]);
        romFile.seek(constrPtr);

        // keep track of color value for the sprites
        final int DEFAULT_COLOR_VAL = 0x04E7;
        int colorValue = DEFAULT_COLOR_VAL;

        // keep track of what silhouette graphics need to be loaded
        int frameIdWithCorrectGfxData = 0;

        // keep track of what frame(s) need to be displayed
        ArrayList<Integer> frameData = new ArrayList<>();

        int firstWord = readWord();
        int baseFrameId = firstWord & 0x1FFF;

        // first, just write all the raw data from the pointer
        String line = String.format("Raw data for input 0x%3X:\n" + dataFormat, ctrlCodeInput, firstWord);
        while (true) {
            int word = readWord();

            // terminate if value has MSB set
            if ((word & 0x8000) != 0) break;

            // check for word with frame data
            if (word >= 0 && word <= 0x1FFF) {
                frameData.add(word);
            }

            // check for range 2000-3FFF
            if (word >= 0x2000 && word <= 0x3FFF) {
                frameIdWithCorrectGfxData = word & 0x1FFF;
            }

            // special case for printing color value for silhouette
            if ((word & 0x6000) == 0x6000) {
                colorValue = readWord();
                line += String.format(" [%04X %04X]", word, colorValue);
            }
            else {
                line += String.format(" " + dataFormat, word);
            }
        }
        textFile.write(line + "\n");

        // indicate size of sprites
        textFile.write("Sprites are ");
        textFile.write((firstWord & 0x2000) == 0 ? "SMALL (16x16)\n" : "LARGE (32x32)\n");

        // indicate color value for the sprites
        textFile.write(String.format("Color value is 0x%04X", colorValue));
        if (colorValue != DEFAULT_COLOR_VAL) {
            textFile.write(" - NOT default color for sprites!\n");
        }
        else {
            textFile.write(" (default)\n");
        }

        // indicate source of graphics data for the frame
        int ctrlCodeInputForGfx = silhCtrlCodeInputFromFrameId.get(frameIdWithCorrectGfxData);
        String gfxDataFormat = "Gfx data sourced from frame 0x%03X (code input 0x%03X)\n";
        textFile.write(String.format(gfxDataFormat, frameIdWithCorrectGfxData, ctrlCodeInputForGfx));
        if (frameIdWithCorrectGfxData != baseFrameId) {
            textFile.write("NOTE: Mismatch between base frame # for OAM, and frame # for gfx data!\n");
        }

        textFile.write("\nThe order of silhouette frames to be displayed:\n");
        for (int frameWord : frameData) {
            int offset = frameWord >> 8;
            int numFrames = frameWord & 0xFF;

            String format = "ID %03X for %d frames\n";
            textFile.write(String.format(format, baseFrameId + offset, numFrames));
        }

        // special case of unused animation frames for one control code input
        if (ctrlCodeInput == 0x13A) {
            textFile.write("\nNOTE: Chunsoft forgot to also use frame IDs 184, 185, 186, 187 with this animation");
        }

        textFile.flush();
        textFile.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // Silhouette raw OAM data from pointer

    private static int getSizeOfRawOamData(int frameId) throws IOException {
        int numEntries = 0;

        int gridPtr = getRomPtr(silhOAMGridPtrs[frameId]);
        romFile.seek(gridPtr);

        final int BITMASK = 0x8000;
        int rowWord = readWord();
        for (int r = 0; r < NUM_BITS_IN_WORD; r++) {
            int rowBitFlag = rowWord & BITMASK;
            if (rowBitFlag != 0) {
                int colWord = readWord();
                for (int c = 0; c < NUM_BITS_IN_WORD; c++) {
                    numEntries += colWord & 0x1;
                    colWord >>= 1;
                }
            }
            rowWord <<= 1;
        }

        return numEntries * 2;
    }

    private static void outputRawOamDataFromPointer(int frameId, String outputFolder) throws IOException {
        String outputName = String.format(outputFolder + "/silh frame 0x%03X raw OAM data.bin", frameId);
        FileOutputStream rawData = new FileOutputStream(outputName);

        // first, need to calculate # bytes to read, from grid data
        int numBytes = getSizeOfRawOamData(frameId);
        int oamPtr = getRomPtr(silhOAMPtrs[frameId]);
        romFile.seek(oamPtr);

        for (int i = 0; i < numBytes; i++) {
            rawData.write(romFile.readUnsignedByte());
        }

        rawData.flush();
        rawData.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // Silhouette X/Y grid decompression

    private static ArrayList<Integer> getPixelPositionsForGridValue(int gridValue) {
        // counting from 0 starting @ MSB, return list of positions of 1 bits in
        // input; e.g. 96CF -> 1001 0110 1100 1111 -> 0, 3, 5, 6, 8, 9, C, D, E, F
        ArrayList<Integer> pixelPositions = new ArrayList<>();
        final int BITMASK = 0x8000;
        for (int i = 0; i < NUM_BITS_IN_WORD; i++) {
            int bit = gridValue & BITMASK;
            if (bit != 0) {
                pixelPositions.add(i << 4);
            }
            gridValue <<= 1;
        }

        return pixelPositions;
    }

    private static void getXYGridData(int frameId, String outputFolder) throws IOException {
        String outputName = String.format(outputFolder + "/silh frame 0x%03X X Y data.bin", frameId);
        FileOutputStream output = new FileOutputStream(outputName);

        int gridPtr = getRomPtr(silhOAMGridPtrs[frameId]);
        romFile.seek(gridPtr);

        int rowBytes = readWord();
        ArrayList<Integer> rows = getPixelPositionsForGridValue(rowBytes);
        for (int r : rows) {
            int colBytes = readWord();
            ArrayList<Integer> cols = getPixelPositionsForGridValue(colBytes);
            for (int c : cols) {
                output.write(c);
                output.write(r);
            }
        }
        output.flush();
        output.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // Converting OAM data to tilemap data - see code at $03AB0D for Chunsoft's example

    private static void convertOneSmallSpriteToTilemap(int oamEntry, int tileRow, int tileCol, int tilemap[][]) {
        // convert 16x16 sprite to four 8x8 tile entries; see ASM at $03AB69
        int oamFlipBits = oamEntry & 0xC000;
        int left = tileCol;
        int right = tileCol + 1;
        int top = tileRow;
        int bottom = tileRow + 1;

        switch (oamFlipBits) {
            // no flip
            case 0x0000:
                tilemap[top][left] = oamEntry;
                tilemap[top][right] = oamEntry + 0x1;
                tilemap[bottom][left] = oamEntry + 0x10;
                tilemap[bottom][right] = oamEntry + 0x11;
                break;
            // X flip only
            case 0x4000:
                tilemap[top][right] = oamEntry;
                tilemap[top][left] = oamEntry + 0x1;
                tilemap[bottom][right] = oamEntry + 0x10;
                tilemap[bottom][left] = oamEntry + 0x11;
                break;
            // Y flip only
            case 0x8000:
                tilemap[bottom][left] = oamEntry;
                tilemap[bottom][right] = oamEntry + 0x1;
                tilemap[top][left] = oamEntry + 0x10;
                tilemap[top][right] = oamEntry + 0x11;
                break;
            // both X and Y flip
            case 0xC000:
                tilemap[bottom][right] = oamEntry;
                tilemap[bottom][left] = oamEntry + 0x1;
                tilemap[top][right] = oamEntry + 0x10;
                tilemap[top][left] = oamEntry + 0x11;
                break;
        }
    }

    private static void fillInOneRowOfLargeSprite(int oamEntry, int tileRow, int tileCol, int tilemap[][], boolean xFlip) {
        if (!xFlip) {
            tilemap[tileRow][tileCol] = oamEntry;
            tilemap[tileRow][tileCol + 1] = oamEntry + 1;
            tilemap[tileRow][tileCol + 2] = oamEntry + 2;
            tilemap[tileRow][tileCol + 3] = oamEntry + 3;
        }
        else {
            tilemap[tileRow][tileCol + 3] = oamEntry;
            tilemap[tileRow][tileCol + 2] = oamEntry + 1;
            tilemap[tileRow][tileCol + 1] = oamEntry + 2;
            tilemap[tileRow][tileCol] = oamEntry + 3;
        }
    }

    private static void convertOneLargeSpriteToTilemap(int oamEntry, int tileRow, int tileCol, int tilemap[][]) {
        // convert 32x32 sprite to sixteen 8x8 tile entries; see ASM at $03ABD9
        int row0 = tileRow;
        int row1 = tileRow + 1;
        int row2 = tileRow + 2;
        int row3 = tileRow + 3;
        boolean xFlip = (oamEntry & 0x4000) != 0;
        boolean yFlip = (oamEntry & 0x8000) != 0;

        if (!yFlip) {
            fillInOneRowOfLargeSprite(oamEntry, row0, tileCol, tilemap, xFlip);
            fillInOneRowOfLargeSprite(oamEntry + 0x10, row1, tileCol, tilemap, xFlip);
            fillInOneRowOfLargeSprite(oamEntry + 0x20, row2, tileCol, tilemap, xFlip);
            fillInOneRowOfLargeSprite(oamEntry + 0x30, row3, tileCol, tilemap, xFlip);
        }
        else {
            fillInOneRowOfLargeSprite(oamEntry, row3, tileCol, tilemap, xFlip);
            fillInOneRowOfLargeSprite(oamEntry + 0x10, row2, tileCol, tilemap, xFlip);
            fillInOneRowOfLargeSprite(oamEntry + 0x20, row1, tileCol, tilemap, xFlip);
            fillInOneRowOfLargeSprite(oamEntry + 0x30, row0, tileCol, tilemap, xFlip);
        }
    }

    private static void convertOamToTilemap(int frameId, String outputFolder) throws IOException {
        // generate a 32x32 tilemap where all the entries are initially set to
        // use tile ID 0x3FF, palette 0, priority 0, and no X/Y flipping
        // must do this because sprites cannot necessarily assume tile ID 0 is empty
        int tilemap[][] = new int[0x20][0x20];
        for (int r = 0; r < tilemap.length; r++) {
            for (int c = 0; c < tilemap[r].length; c++) {
                tilemap[r][c] = 0x03FF;
            }
        }

        // get the decompressed X Y data from the corresponding file
        String xyDataFileName = String.format(outputFolder + "/silh frame 0x%03X X Y data.bin", frameId);
        FileInputStream xyFile = new FileInputStream(xyDataFileName);
        byte xyData[] = xyFile.readAllBytes();
        xyFile.close();

        boolean smallSprites = frameIdHasSmallSprites(frameId);

        // seek in the ROM to the raw OAM data for the silhouette set
        int oamPtr = getRomPtr(silhOAMPtrs[frameId]);
        romFile.seek(oamPtr);

        for (int filePos = 0; filePos < xyData.length; filePos += 2) {
            int tileCol = (((int) xyData[filePos]) & 0xFF) >> 3;
            int tileRow = (((int) xyData[filePos + 1]) & 0xFF) >> 3;

            // read sprite's tile number and attributes
            // keep only tile # and flip bits; disregard palette; set priority 2
            int oamEntry = readWord();
            oamEntry = (oamEntry & 0xC1FF) | 0x2000;

            if (smallSprites) {
                convertOneSmallSpriteToTilemap(oamEntry, tileRow, tileCol, tilemap);
            }
            else {
                convertOneLargeSpriteToTilemap(oamEntry, tileRow, tileCol, tilemap);
            }
        }

        String outputName = String.format(outputFolder + "/silh frame 0x%03X converted tilemap.bin", frameId);
        writeConvertedTilemapToFile(outputName, tilemap);
    }

    private static void writeConvertedTilemapToFile(String outputName, int[][] tilemap) throws IOException {
        FileOutputStream output = new FileOutputStream(outputName);
        for (int r = 0; r < tilemap.length; r++) {
            for (int c = 0; c < tilemap[r].length; c++) {
                output.write(tilemap[r][c] & 0xFF);
                output.write(tilemap[r][c] >> 8);
            }
        }
        output.flush();
        output.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // Converting gold bookmark OAM data to tilemap data - see code at $01E66F

    private static final int GOLD_BOOKMARK_SHINE_PTR = 0x1F0C0;
    private static final int GOLD_BOOKMARK_OAM_TABLE_PTR = 0xEABA; // $01EABA
    private static final int GOLD_BOOKMARK_OAM_TABLE_SIZE = 0xA;

    private static void convertGoldBookmarkOamToTilemap(int frameNum) throws IOException {
        // do nothing if frame number is not in correct range
        if (frameNum < 0 || frameNum >= GOLD_BOOKMARK_OAM_TABLE_SIZE)
            return;

        // tilemap for animation is 0xE tile rows tall; carry over 0x20 tile width
        int tilemap[][] = new int[0xE][0x20];
        for (int r = 0; r < tilemap.length; r++) {
            for (int c = 0; c < tilemap[r].length; c++) {
                tilemap[r][c] = 0x03FF;
            }
        }

        // read pointer table entry for the bookmark shine animation's frame #
        int ptrTablePosition = GOLD_BOOKMARK_OAM_TABLE_PTR + 3 * frameNum;
        romFile.seek(ptrTablePosition);
        int oamPtr = readPtr();

        // seek to the pointer and start reading the raw OAM data
        romFile.seek(getRomPtr(oamPtr));
        do {
            // byte 0 = X coord (low byte; assume high bit 0 here), byte 1 = Y coord
            // data is terminated by [FF FF] byte sequence at this point
            int xyCoord = readWord();
            if (xyCoord == 0xFFFF) break;

            // extract out the tile column and tile row
            int tileCol = (xyCoord & 0xFF) >> 3;
            int tileRow = ((xyCoord >> 8) & 0xFF) >> 3;

            // read sprite's tile number and attributes
            // keep only tile # and flip bits; disregard palette; set priority 2
            int oamEntry = readWord();
            oamEntry = (oamEntry & 0xC1FF) | 0x2000;

            // for the gold bookmark animation, sprites are all small = 16x16
            convertOneSmallSpriteToTilemap(oamEntry, tileRow, tileCol, tilemap);
        } while (true);

        String outputName = String.format("gold bookmark data/gold bookmark frame %d converted tilemap.bin", frameNum);
        writeConvertedTilemapToFile(outputName, tilemap);
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // Silhouette graphics data decompression

    private static void fillWithDataByte(int dataByte, int size) throws IOException {
        while (size != 0 && silhBufferOffset < SILH_BUFFER_SIZE) {
            silhBuffer[silhBufferOffset] = dataByte;
            silhBufferOffset++;
            size--;
        }
    }

    private static void readLiteralData(int typeByte) throws IOException {
        // implement $0286D9
        int size = (typeByte & 0x3F) + 1;
        while (size != 0 && silhBufferOffset < SILH_BUFFER_SIZE) {
            silhBuffer[silhBufferOffset] = romFile.readUnsignedByte();
            silhBufferOffset++;
            size--;
        }
    }

    private static void decompressSilhouetteGfxFromPtr(int gfxPtr, String outputFolder) throws IOException {
        int startOffset = getRomPtr(gfxPtr);
        romFile.seek(startOffset);

        String debugLogFilename = String.format("%s/$%06X sprite gfx log.txt", outputFolder, gfxPtr);
        BufferedWriter debugLog = new BufferedWriter(new FileWriter(debugLogFilename));

        debugLog.write("ROM pos (size) | Offset | Data  | Description\n");
        debugLog.write("---------------+--------+-------+------------\n");
        String lineFormat = " %06X (%4X) |  %4X  | %-5s | %s\n";

        int typeByte = romFile.readUnsignedByte();
        silhBufferOffset = 0;
        while (typeByte != END_DATA && silhBufferOffset < SILH_BUFFER_SIZE) {
            int size = typeByte & 0x3F;
            int romPos = (int) romFile.getFilePointer() - 1;
            int compSizeSoFar = romPos - startOffset;
            int uncompSizeSoFar = silhBufferOffset;
            String dataPrintout = String.format("%02X", typeByte);
            String description = "";

            if (typeByte == ADV_BANK) {
                // the ASM sets bank offset to 0x8000, and increments bank num;
                // when reading data from the contiguous file, this is automatic

                String notice = "Got 0x40 \"bank advance\" byte at 0x%06X";
                notice = String.format(notice, (int) romFile.getFilePointer() - 1);
                System.out.println(notice);
                description = "Bank advance byte";

                while ((romFile.getFilePointer() & 0x7FFF) != 0) {
                    romFile.readUnsignedByte();
                }
            }
            else switch (typeByte >> 6) {
                case 0x0:
                    fillWithDataByte(0x00, size);
                    description = String.format("%2X run of 00", size);
                    break;
                case 0x1:
                    fillWithDataByte(0xFF, size);
                    description = String.format("%2X run of FF", size);
                    break;
                case 0x2:
                    // size = (typeByte & 0x3F) + 1;
                    description = String.format("%02X lits", size + 1);
                    readLiteralData(typeByte);

                    // check for specific case that Chunsoft missed
                    if (size + 1 == 1) {
                        int value = silhBuffer[silhBufferOffset - 1];
                        if (value == 0x00 || value == 0xFF) {
                            description += " - is 00 or FF, could have been optimized!";
                        }
                    }
                    break;
                case 0x3:
                    int dataByte = romFile.readUnsignedByte();
                    description = String.format("%2X run of %02X", size + 1, dataByte);
                    dataPrintout += String.format(" %02X", dataByte);
                    // size = (typeByte & 0x3F) + 1;
                    fillWithDataByte(dataByte, size + 1);
                    break;
            }
            typeByte = romFile.readUnsignedByte();
            debugLog.write(String.format(lineFormat, romPos, compSizeSoFar, uncompSizeSoFar, dataPrintout, description));
        }

        int endOfDataOffset = (int) romFile.getFilePointer() - 1;
        debugLog.write(String.format("\nEnd of data @ %06X (%4X), decompressed size of %X", endOfDataOffset, endOfDataOffset - startOffset + 1, silhBufferOffset));

        debugLog.flush();
        debugLog.close();
    }

    // use for gold bookmark animation's tile data
    private static void writeSilhDataFromPtr(int gfxPtr) throws IOException {
        String outputName = String.format("gold bookmark data/gold bookmark $%06X gfx data.2bpp", gfxPtr);
        writeSilhGfxDataToFile(true, outputName);
	
		outputName = String.format("gold bookmark data/gold bookmark $%06X raw decompressed gfx.bin", gfxPtr);
		writeSilhGfxDataToFile(false, outputName);
    }

    private static void writeSilhGfxDataForCodeInput(int silhID, String outputFolder) throws IOException {
        String outputName = String.format(outputFolder + "/silh code input 0x%03X gfx data.2bpp", silhID);
        writeSilhGfxDataToFile(true, outputName);
		
		outputName = String.format(outputFolder + "/silh code input 0x%03X raw decompressed gfx.bin", silhID);
		writeSilhGfxDataToFile(false, outputName);
    }

    private static void writeSilhGfxDataToFile(boolean interleave, String outputFilePath) throws IOException {
        FileOutputStream output = new FileOutputStream(outputFilePath);

        // directly writing the data to the file
		if (!interleave) {
			for (int i = 0; i < silhBufferOffset; i++) {
				output.write(silhBuffer[i]);
			}
        }

        // raw decompression output is in the NES's 2bpp standard format, but
        // in the interest of having Tilemap Studio auto-detect the graphics,
        // it would be better to convert it to the SNES's 2bpp standard format
        // NES 2bpp:  [r0p0 r1p0 r2p0 ... r7p0 r0p1 r1p1 r2p1 ... r7p1]
        // indices:   [0    1    2    ... 7    8    9    A    ... F]
        // SNES 2bpp: [r0p0 r0p1 r1p0 r1p1 r2p0 r2p1 ... r7p0 r7p1]
        // new order: [0    8    1    9    2    A    ... 7    F]
		else {
			int interleaveSequence[] = {0, 8, 1, 9, 2, 0xa, 3, 0xb, 4, 0xc, 5, 0xd, 6, 0xe, 7, 0xf};
			for (int tileNum = 0; tileNum < silhBufferOffset; tileNum += interleaveSequence.length) {
				for (int i = 0; i < interleaveSequence.length; i++) {
					output.write(silhBuffer[tileNum + interleaveSequence[i]]);
					// output.write(silhBuffer[tileNum + (i & 0x1) * 8 + (i >> 1)]);
				}
			}
		}

        output.flush();
        output.close();
    }

    private static void decompressSilhouetteGfxForCodeInput(int ctrlCodeInput, String outputFolder) throws IOException {
        int gfxPtr = silhGFXPtrs[ctrlCodeInput];
        // add ctrl code input number to the log file
        decompressSilhouetteGfxFromPtr(gfxPtr, outputFolder);
        writeSilhGfxDataForCodeInput(ctrlCodeInput, outputFolder);
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void getAllDataForCtrlCodeInput(int ctrlCodeInput) throws IOException {
        // create a folder to write data files into
        String outputFolder = String.format("output/0x%03X silh code input", ctrlCodeInput);
        Files.createDirectories(Paths.get(outputFolder));

        decompressSilhouetteGfxForCodeInput(ctrlCodeInput, outputFolder);
        outputConstructionData(ctrlCodeInput, outputFolder);
        ArrayList<Integer> frameList = frameIdListFromInputs.get(ctrlCodeInput);
        for (int frameId : frameList) {
            getXYGridData(frameId, outputFolder);
            outputRawOamDataFromPointer(frameId, outputFolder);
            convertOamToTilemap(frameId, outputFolder);
        }
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void readPointerTables() throws IOException {
        getFrameIdMappings();
        getSilhGFXPtrs();
        getGraphicsSizes();
        getSilhOAMPtrs();
        getSilhOAMGridPtrs();
        getSilhConstrDataPtrs();
        getFrameIdListsForCtrlCodeInputs();
    }

    private static void outputDataForSilhCtrlCodeIDs() throws IOException {
        outputAllConstructionBinaryData();
        outputTableOfSilhPtrs();
        getAllDataForCtrlCodeInput(0x13A);
        outputListOfFrameIdsForCtrlCodeInputs();
        for (int ctrlCodeInput = 0; ctrlCodeInput < NUM_SILH_CTRL_CODE_IDS; ctrlCodeInput++) {
            getAllDataForCtrlCodeInput(ctrlCodeInput);
        }
    }

    private static void outputDataForGoldBookmark() throws IOException {
        String goldBookmarkFolder = "gold bookmark data";
        Files.createDirectories(Paths.get(goldBookmarkFolder));
        decompressSilhouetteGfxFromPtr(GOLD_BOOKMARK_SHINE_PTR, goldBookmarkFolder);
        writeSilhDataFromPtr(GOLD_BOOKMARK_SHINE_PTR);
        for (int frameNum = 0; frameNum < GOLD_BOOKMARK_OAM_TABLE_SIZE; frameNum++) {
            convertGoldBookmarkOamToTilemap(frameNum);
        }
    }

    public static void main(String args[]) throws IOException {
        romFile = new RandomAccessFile("Kamaitachi no Yoru (Japan).sfc", "r");
        readPointerTables();
        outputDataForSilhCtrlCodeIDs();
        outputDataForGoldBookmark();
        romFile.close();
    }
}
