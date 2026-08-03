package font;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;

public class FontImage {

    // *************************************************************************
    // Constants
    // *************************************************************************

    /**
     * A tile is 8 pixels wide.
     */
    public final static int TILE_WIDTH  = 8;

    /**
     * A tile is 8 pixels tall.
     */
    public final static int TILE_HEIGHT = 8;

    private final static String DEFAULT_FILENAME = "malformed";

    private static boolean DEBUG = false;

    // *************************************************************************
    // Fields
    // *************************************************************************

    /**
     * Name of the file from which to read image data.
     */
    private String filename;

    /**
     * The width of a character in pixels.
     */
    private int charWidth;

    /**
     * The height of a character in pixels.
     */
    private int charHeight;

    /**
     * The color of the text in the image, represented as a 24-bit RGB value.
     */
    private int textColor;

    /**
     * <p>A 2D array representing the image where:</p>
     * <p>If <code>isText[R][C] == true</code>, the color of the pixel in the image at (R,C) is for text.</p>
     * <p>If <code>isText[R][C] == false</code>, the color of the pixel in the image at (R,C) is for the background.
     */
    private boolean isText[][];

    // *************************************************************************
    // Constructor
    // *************************************************************************

    public FontImage(String filename, int charWidth, int charHeight, int textColor) {
        this.filename = filename;
        this.charWidth = charWidth;
        this.charHeight = charHeight;
        this.textColor = textColor;
    }

    // *************************************************************************
    // Field getter methods
    // *************************************************************************

    public int getCharHeight() {
        return charHeight;
    }

    public int getCharWidth() {
        return charWidth;
    }

    // *************************************************************************
    // Helper methods
    // *************************************************************************

    /**
     * Given the name of the image file we are reading from, generate the name
     * of the output binary file.
     * @return the name of the input file with the extension changed to .bin
     */
    public String getOutputFilename() {
        int periodIndex = filename.lastIndexOf('.');
        if (periodIndex == -1) {
            System.err.println("Image file should have a proper file extension.");
            return DEFAULT_FILENAME;
        }
        return filename.substring(0, periodIndex) + " - name entry char grid data.bin";
    }

    private FileOutputStream createOutputStream() {
        FileOutputStream writer = null;
        try {
            writer = new FileOutputStream(getOutputFilename());
        }
        catch (Exception e) {
            System.out.println(e.getMessage());
        }
        return writer;
    }

    /**
     * Mnemonic for the height of the image.
     * @return the height of the image in pixels
     */
    public int getNumPixelRows() {
        return isText.length;
    }

    /**
     * Mnemonic for the width of the image.
     * @return the width of the image in pixels
     */
    public int getNumPixelCols() {
        return isText[0].length;
    }

    /**
     * Given the dimensions of the image and of an individual tile, calculate
     * the number of tiles in the image.
     * @return the number of the tiles in the image
     */
    public int getNumTiles() {
        return getNumPixelRows() * getNumPixelCols() / (TILE_HEIGHT * TILE_WIDTH);
    }

    /**
     * Given the dimensions of the image and of an individual character, calculate
     * the number of characters in the image.
     * @return the number of the characters in the image
     */
    public int getNumChars() {
        return getNumPixelRows() * getNumPixelCols() / (charHeight * charWidth);
    }

    /**
     * Calculate the width of a character in tiles rather than in pixels.
     * @return the width of a character in units of tiles
     */
    public int getCharWidthInTiles() {
        return charWidth / TILE_WIDTH;
    }

    /**
     * Calculate the height of a character in tiles rather than in pixels.
     * @return the height of a character in units of tiles
     */
    public int getCharHeightInTiles() {
        return charHeight / TILE_HEIGHT;
    }

    /**
     * Given the dimensions of an individual character, calculate the number of
     * tiles that a character occupies.
     * @return the number of tiles in a single character
     */
    public int getNumTilesPerChar() {
        return getCharWidthInTiles() * getCharHeightInTiles();
    }

    /**
     * Given the width of an individual character and of the full image,
     * calculate the number of tiles that are in a full row of characters.
     * @return the number of tiles in a row of characters
     */
    public int getNumTilesPerCharRow() {
        return getNumPixelCols() * getNumTilesPerChar() / charWidth;
    }

    /**
     * Given the width of an individual character and of the full image,
     * calculate the number of characters that are in a full row of characters.
     * @return the number of characters in a row of characters
     */
    public int getNumCharsPerCharRow() {
        return getNumTilesPerCharRow() / getNumTilesPerChar();
    }

    /**
     * Calculate how many tile rows down a tile is in the image when traversing
     * in tile editor order.
     * @param tileNum an integer in the range [0,<code>getNumTiles()</code>)
     * @return the row of the tile in units of tiles
     */
    public int getTileRow(int tileNum) {
        // first, determine what character row we are in
        int tileRow = tileNum / getNumTilesPerCharRow();

        // convert from a character row value to a tile row value
        tileRow *= getCharHeightInTiles();

        // add 0 or 1 depending on whether tile is top/bottom half of the character
        // first, normalize tile number to be in character 0
        // if 16x16, normalize to be in tile column 0; if 8x8, doesn't matter
        tileRow += ((tileNum % getNumTilesPerChar()) / getCharWidthInTiles()) % getCharHeightInTiles();
        return tileRow;
    }

    /**
     * Calculate how many tile columns to the right a tile is in the image when
     * traversing in tile editor order.
     * @param tileNum an integer in the range [0,<code>getNumTiles()</code>)
     * @return the column of the tile in units of tiles
     */
    public int getTileCol(int tileNum) {
        // to explain this method, assume tileNum = 13, 4 tiles/char, and 8 tiles/char row

        // first, normalize tileNum to be in character row 0
        // e.g. if at tile 13, and 8 tiles per char row, similar to tile 5 in char row 0 (13 % 8 = 5)
        int tileCol = tileNum % getNumTilesPerCharRow();

        // determine what character column we are in for the row
        // e.g. tile 5 in char row 0 is in the first character to the right (5 / 4 = 1)
        tileCol /= getNumTilesPerChar();

        // convert character column value to a tile column value
        // e.g. character 1 is two tiles to the right (0 1 [2] 3 4 5 6 7)
        tileCol *= getCharWidthInTiles();

        // for 16x16, add 0 or 1 depending on whether tile is left/right half of the character
        // for 8x16, this calculation doesn't matter
        tileCol += tileNum % getCharWidthInTiles();

        return tileCol;
    }

    // *************************************************************************
    // Main working methods
    // *************************************************************************

    public void initialize() throws IOException {
        convertPixelsToBits();
    }

    /** 
     * Turns an image into a 2D array of booleans according to the rules in the
     * Javadoc for <code>isText[][]</code>. <b>After running the constructor,
     * this must be the very first method you call, before anything else.</b>
     */
    private void convertPixelsToBits() throws IOException {
        BufferedImage image = ImageIO.read(new File(filename));
        image = ImageIO.read(new File(filename));
        int numPixelRows = image.getHeight();
        int numPixelCols = image.getWidth();
        isText = new boolean[numPixelRows][numPixelCols];

        for (int r = 0; r < numPixelRows; r++) {
            for (int c = 0; c < numPixelCols; c++) {
                int rgb = image.getRGB(c, r) & 0x00FFFFFF;
                isText[r][c] = rgb == textColor;
            }
        }
    }

    public boolean[][] getPixelDataForTile(int tileNum) {
        boolean tileData[][] = new boolean[TILE_HEIGHT][TILE_WIDTH];
        int tileRow = getTileRow(tileNum);
        int tileCol = getTileCol(tileNum);
        if (DEBUG) {
            String format = "Tile %d is at %d, %d";
            System.out.println(String.format(format, tileNum, tileRow, tileCol));
        }

        for (int r = 0; r < tileData.length; r++) {
            for (int c = 0; c < tileData[r].length; c++) {
                int rowInImage = tileRow * TILE_HEIGHT + r;
                int colInImage = tileCol * TILE_WIDTH + c;
                tileData[r][c] = isText[rowInImage][colInImage];
            }
        }
        return tileData;
    }

    public boolean[][] getPixelDataForChar(int charNum) {
        boolean charData[][] = new boolean[charHeight][charWidth];
        int tileNum = charNum * getNumTilesPerChar();
        int tileRow = getTileRow(tileNum);
        int tileCol = getTileCol(tileNum);
        if (DEBUG) {
            String format = "Char %d is at tile %d, %d";
            System.out.println(String.format(format, charNum, tileRow, tileCol));
        }

        for (int r = 0; r < charData.length; r++) {
            for (int c = 0; c < charData[r].length; c++) {
                int rowInImage = tileRow * TILE_HEIGHT + r;
                int colInImage = tileCol * TILE_WIDTH + c;
                charData[r][c] = isText[rowInImage][colInImage];
            }
        }
        return charData;

        // inefficient implementation with getting each tile in the character
        // and combining together into one matrix
        /*int numTilesPerChar = getNumTilesPerChar();
        for (int tileNumInChar = 0; tileNumInChar < numTilesPerChar; tileNumInChar++) {
            int tileNumInImage = tileNumInChar + charNum * numTilesPerChar;
            if (DEBUG) {
                String format = "Tile %d in character %d = tile %d in image";
                System.out.println(String.format(format, tileNumInChar, charNum, tileNumInImage));
            }
            boolean tileData[][] = getPixelDataForTile(tileNumInImage);
            for (int r = 0; r < tileData.length; r++) {
                for (int c = 0; c < tileData[r].length; c++) {
                    int rowInChar = r + getTileRow(tileNumInChar) * TILE_HEIGHT;
                    int colInChar = c + getTileCol(tileNumInChar) * TILE_WIDTH;
                    charData[rowInChar][colInChar] = tileData[r][c];
                }
            }
        }
        return charData;
        */
    }

    public static int[][] convertPixelMatrixToIntMatrix(boolean pixelData[][]) {
        int numRows = pixelData.length;
        int numTileCols = (pixelData[0].length / TILE_WIDTH) + (pixelData[0].length % TILE_WIDTH != 0 ? 1 : 0);
        int matrix1bpp[][] = new int[numRows][numTileCols];

        // convert horizontal stretches of 8 booleans to ints
        // e.g. TFTFTFTF -> binary 10101010 = 0xAA
        for (int r = 0; r < numRows; r++) {
            for (int tc = 0; tc < numTileCols; tc++) {
                int tileRowData = 0;
                for (int c = 0; c < TILE_WIDTH; c++) {
                    // column 0 in a tile would be at bit position 7
                    // similar for col 3 and pos 4, col 7 and pos 0, etc.
                    // why do it this way instead of ORing in at LSB and shifting
                    // the whole byte left once: have to account for last tile's
                    // worth of pixel data
                    int pixelCol = tc * TILE_WIDTH + c;
                    if (pixelCol >= pixelData[r].length) {
                        break;
                    }
                    int bit = pixelData[r][tc * TILE_WIDTH + c] ? 1 : 0;
                    tileRowData |= (bit << (TILE_WIDTH - c - 1));
                }
                matrix1bpp[r][tc] = tileRowData;
            }
        }
        return matrix1bpp;
    }

    public void convertBitsToBinFile() throws IOException {
        FileOutputStream writer = createOutputStream();
        if (writer == null) {
            return;
        }

        char pixelBuffer = 0; // fill up a one byte buffer with pixel data
        int bitOffset = 0;    // write to buffer when the bit offset is 8
        if (DEBUG) {
            int numPixelCols = getNumPixelCols();
            int numPixelRows = getNumPixelRows();

            String format1 = "%d * %d = %d pixels = %d tiles total";
            System.out.println(String.format(format1, numPixelCols, numPixelRows,
            (numPixelCols * + numPixelRows), getNumTiles()));

            String format2 = "%d tiles per char, %d tiles per row of chars";
            System.out.println(String.format(format2, getNumTilesPerChar(), getNumTilesPerCharRow()));
        }

        int numTiles = getNumTiles();
        for (int tile = 0; tile < numTiles; tile++) {
            boolean tileData[][] = getPixelDataForTile(tile);

            for (int r = 0; r < tileData.length; r++) {
                for (int c = 0; c < tileData[r].length; c++) {
                    if (tileData[r][c]) {
                        pixelBuffer |= 1;
                    }

                    bitOffset = (bitOffset + 1) & 0x7;
                    if (bitOffset == 0) {
                        // buffer is full, so write to file; reset state
                        if (DEBUG) {
                            System.out.println("Writing byte: " + Integer.toHexString(pixelBuffer));
                        }
                        writer.write(pixelBuffer);
                        pixelBuffer = 0;
                    }
                    else {
                        pixelBuffer <<= 1;
                    }
                }
                // flush after every row
                writer.flush();
            }
        }
        writer.close();
    }

    public void convertToBinaryDataForNameEntryCharGrid() throws IOException {
        convertToBinaryDataForNameEntryCharGrid(null, new FileOutputStream(getOutputFilename()));
    }

    public void convertToBinaryDataForNameEntryCharGrid(int charNumList[], FileOutputStream writer) throws IOException {
        // allow writing a specific sequence of font data for the name entry
        // grid; use cases include making characters not selectable for a name,
        // characters using identical font data, or most importantly, a custom
        // order of character data to take advantage of the LZ recompression

        // by default, just write all the characters in order
        int numChars = getNumChars();
        if (charNumList == null || charNumList.length == 0) {
            charNumList = new int[numChars];
            for (int charNum = 0; charNum < numChars; charNum++) {
                charNumList[charNum] = charNum;
            }
        }

        // write data to END of the file so you don't have to concat two files
        // FileOutputStream writer = new FileOutputStream(getOutputFilename(), true);

        int numTilesPerChar = getNumTilesPerChar();
        boolean alreadyGotFontData[] = new boolean[numChars];

        // first, write a space character
        for (int i = 0; i < TILE_HEIGHT * numTilesPerChar; i++) {
            writer.write(0x00);
        }
        alreadyGotFontData[0] = true;

        // then write 7 copies of the font data for the "character slot not
        // filled in yet" character
        // int fillerChar = charNumList[0] - 1;
        int fillerChar = charNumList[0];
        for (int i = 0; i < 7; i++) {
            writeTileDataForCharInFormatForGrid(fillerChar, writer);
        }

        // write font data for each character as four 8x8 tiles: TL/TR/BL/BR
        for (int i = 1; i < charNumList.length; i++) {
            int charNum = charNumList[i];
            if (alreadyGotFontData[charNum])
                continue;

            alreadyGotFontData[charNum] = true;
            // charNum--;
            writeTileDataForCharInFormatForGrid(charNum, writer);
        }
        writer.flush();
        writer.close();
    }

    private void writeTileDataForCharInFormatForGrid(int charNum, FileOutputStream writer) throws IOException {
        char pixelBuffer = 0;
        int bitOffset = 0;

        int numTilesPerChar = getNumTilesPerChar();
        for (int tileNumInChar = 0; tileNumInChar < numTilesPerChar; tileNumInChar++) {
            // TODO get rid of the decrement, add space to ALL table files
            int tile = tileNumInChar + (charNum - 1) * numTilesPerChar;
            boolean tileData[][] = getPixelDataForTile(tile);
            for (int r = 0; r < tileData.length; r++) {
                for (int c = 0; c < tileData[r].length; c++) {
                    if (tileData[r][c]) {
                        pixelBuffer |= 1;
                    }

                    bitOffset = (bitOffset + 1) & 0x7;
                    if (bitOffset == 0) {
                        writer.write(pixelBuffer);
                        pixelBuffer = 0;
                    }
                    pixelBuffer <<= 1;
                }
            }
        }
    }
}
