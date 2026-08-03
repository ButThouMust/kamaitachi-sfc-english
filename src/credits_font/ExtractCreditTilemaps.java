package credits_font;

// purpose: given a tilemap of the translated credits generated from Tilemap
// Studio, plus a text file with dimensions for each credit's tilemap, extract
// out the individual tilemaps for each credit into their own files

import java.io.BufferedReader;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.file.Files;
import java.nio.file.Paths;

public class ExtractCreditTilemaps {
    private static final int NUM_CREDIT_LINES = 48;
    private static final int TILEMAP_ID_SIZE = 2;

    private static int[] tilemapWidths;
    // private static int[] tilemapHeights;
    private static String[] tilemapNames;

     // 0xF blocks that are each 16 pixels wide
    private static final int MAX_LINE_WIDTH = 240 / 16;

    private static final int ID_FOR_EMPTY_BLOCK = 0x00;
    private static final int ID_FOR_BACKSPACE = 0xFE;
    private static final int ID_FOR_END_OF_LINE = 0xFF;

    private static final String OUTPUT_FOLDER = "end credits/tile id lists";

    // -------------------------------------------------------------------------

    private static void parseSizesCsv(String sizesCSV) throws IOException {
        BufferedReader sizesReader = new BufferedReader(new FileReader(sizesCSV));
        // tilemapHeights = new int[NUM_CREDIT_LINES];
        tilemapWidths = new int[NUM_CREDIT_LINES];
        tilemapNames  = new String[NUM_CREDIT_LINES];

        int lineNum = 0;
        String line = "";
        while ((line = sizesReader.readLine()) != null && lineNum < NUM_CREDIT_LINES) {
            if (line.equals("")) continue;

            // lines are expected to be formatted like "WW,description"
            // where WW is the width of each tilemap in 16 pixel blocks
            String[] split = line.split(",");
            tilemapWidths[lineNum]  = Integer.parseInt(split[0], 16);
            tilemapNames[lineNum]   = split[1];

            // tilemapHeights[lineNum] = Integer.parseInt(split[1], 16);
            // tilemapNames[lineNum]   = split[2];
            lineNum++;
        }
        sizesReader.close();
    }

    // -------------------------------------------------------------------------

    private static void readTilemapData(String combinedTilemapFilename) throws IOException {
        RandomAccessFile combinedTilemap = new RandomAccessFile(combinedTilemapFilename, "r");
        int numBytesInRow = MAX_LINE_WIDTH * TILEMAP_ID_SIZE;

        for (int tilemapNum = 0; tilemapNum < NUM_CREDIT_LINES; tilemapNum++) {
            int width = tilemapWidths[tilemapNum];
            String tilemapOutputName = getTilemapOutputName(tilemapNum);
            FileOutputStream newTilemap = new FileOutputStream(tilemapOutputName, false);

            // assume that each tilemap starts at x=8 on screen for overscan
            if (width != 0) {
                newTilemap.write(ID_FOR_EMPTY_BLOCK);
            }

            long startOfRowInFile = combinedTilemap.getFilePointer();
            for (int col = 0; col < width; col++) {
                int blockID = combinedTilemap.readUnsignedByte();

                // superfamiconv creates an SNES format tilemap (2 bytes/entry),
                // but we need only the low byte of each entry; this being said,
                // you may be able to use this to detect if the tilemap was not
                // generated correctly for the credits (e.g. it has X/Y flip,
                // nonzero palette, or a block ID from 0xFE to 0x3FF)
                combinedTilemap.readUnsignedByte();

                checkIfNeedToInsertBackspace(tilemapNum, col, newTilemap);

                // I chose 2 tiles right as my standard for indenting names
                // have to write two 00 bytes
                if (col == 0 && blockID == ID_FOR_EMPTY_BLOCK) {
                    newTilemap.write(ID_FOR_EMPTY_BLOCK);
                }
                newTilemap.write(blockID);
            }
            // go to next row; skip empty tiles past this line's right edge
            combinedTilemap.seek(startOfRowInFile + numBytesInRow);

            newTilemap.write(ID_FOR_END_OF_LINE);
            newTilemap.close();
        }

        combinedTilemap.close();
    }

    private static String getTilemapOutputName(int tilemapNum) {
        // String format = "%02d %s SNES TILEMAP 0x%02X x 0x%02X.bin";
        // return String.format(format, tilemapNum + 1, tilemapNames[tilemapNum], tilemapWidths[tilemapNum], tilemapHeights[tilemapNum]);

        String format = OUTPUT_FOLDER + "/%02d %s block ID list.bin";
        return String.format(format, tilemapNum + 1, tilemapNames[tilemapNum]);
    }

    // the JP game sets 00 as "go right 8 pixels", and I found it useful to make
    // an ASM hack to set a value (I picked FE) as "go left 8 pixels"
    private static void checkIfNeedToInsertBackspace(int tilemapNum, int col, FileOutputStream newTilemap) throws IOException {
        boolean writeBackspace =
            // add to or change this list as needed
            // (tilemapNum == 0x00 && col == 0x00) ||
            (tilemapNum == 18 && col == 0x7) || // Masayos<hi Saito
            (tilemapNum == 27 && col == 0x6) || // Tsuyos<hi Kuroda
            (tilemapNum == 30 && col == 0x5) || // Shōic<hirō Yamaura
            (tilemapNum == 37 && col == 0x9);   // Lucky Wide Co., Ltd.

        if (writeBackspace) {
            newTilemap.write(ID_FOR_BACKSPACE);
        }
    }

    // -------------------------------------------------------------------------

    public static void main(String args[]) throws IOException {
        // sample usage: java ExtractCreditTilemaps combined_tilemap.bin tilemap_sizes.csv
        if (args.length != 2){ 
            System.out.println("Sample usage: java ExtractTilemaps combined_tilemap.bin tilemap_sizes.csv");
            return;
        }

        String combinedTilemapFile = args[0];
        String tilemapSizesFile = args[1];

        Files.createDirectories(Paths.get(OUTPUT_FOLDER));

        parseSizesCsv(tilemapSizesFile);
        readTilemapData(combinedTilemapFile);
    }
}
