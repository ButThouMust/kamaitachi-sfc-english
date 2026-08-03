package font;

import java.io.BufferedReader;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.awt.image.BufferedImage;

/**
 * Given a String, a font file, and a table file with font widths/heights,
 * create an image from the String using the widths/heights supplied in the
 * table file. Applications: pre-rendered text for the file management prompts
 * and the "please name the ___" prompts in the name entry screen
 */
public class FontRenderer {

    private static final int PIXELS_BETWEEN_CHARS = 1;
    private static final int TEXT_RIGHT_BOUND = 0xF8;
    private static final int TEXT_LEFT_BOUND  = 0x08;
    private static final int MAX_LINE_WIDTH_PIXELS = TEXT_RIGHT_BOUND - TEXT_LEFT_BOUND;

    private static final int WHITE_RGB = 0xFFFFFF;
    private static final int BLACK_RGB = 0x000000;

    public static final int MAIN_TEXT_KERNING_ID = 1;
    public static final int CREDITS_KERNING_ID = 2;

    private static boolean DEBUG = false;

    private String text;
    private String tableFileName;
    private FontImage fontImage;
    private ArrayList<FontInfo> fontInfoArray;
    private ArrayList<String> encodings;
    private HashMap<String, Integer> kerningPairs;

    private int imageWidth;
    private int imageHeight;

    private int startX;

    private int kerningTableID;
    private boolean doKerning;

    // *************************************************************************
    // Constructor
    // *************************************************************************

    public FontRenderer(String text, String tableFileName, String fontImageFile,
            int charWidth, int charHeight, int textColor, int startX, int kernTableID)
    {
        this.text = text;
        this.tableFileName = tableFileName;
        fontImage = new FontImage(fontImageFile, charWidth, charHeight, textColor);
        imageHeight = charHeight;
        this.startX = startX;

        this.kerningTableID = kernTableID;
        this.doKerning = kernTableID != 0;
    }

    // *************************************************************************
    // Kerning tables; add to these as you see fit
    // *************************************************************************

    private void getMainTextKerningPairs() {
        kerningPairs = new HashMap<>();
        kerningPairs.put("We", 1);
        kerningPairs.put("ad", 1);
        kerningPairs.put("pt", 1);
        kerningPairs.put("av", 1);
        kerningPairs.put("ro", 1);
        kerningPairs.put("Ye", 1);

        kerningPairs.put("ac", 1);
        kerningPairs.put("Yo", 2);
    }

    private void getCreditsKerningPairs() {
        kerningPairs = new HashMap<>();
        kerningPairs.put("Ya", 2);

        kerningPairs.put("at", 2);
        kerningPairs.put("ct", 2);
        kerningPairs.put("ht", 2);
        kerningPairs.put("Lt", 2);
        kerningPairs.put("nt", 2);
        kerningPairs.put("ot", 1);
        kerningPairs.put("rt", 2);
        kerningPairs.put("st", 2);

        kerningPairs.put("Ef", 2);
        kerningPairs.put("ff", 3);
        kerningPairs.put("fe", 3);
        kerningPairs.put("ct", 2);
    }

    // *************************************************************************
    // Helper functions
    // *************************************************************************

    private void printFontInfoArray() {
        for (int i = 0; i < fontInfoArray.size(); i++) {
            FontInfo fontInfo = fontInfoArray.get(i);
            String format = "i = %04X ; %04X = '%s' ; %2dx%2d";
            System.out.println(String.format(format, i, fontInfo.getHexValue(), fontInfo.getEncoding(), fontInfo.getWidth(), fontInfo.getHeight()));
        }
    }

    private void readTableFile() {
        fontInfoArray = new ArrayList<>();
        encodings = new ArrayList<>();
        try {
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
                encodings.add(encoding);
            }
            if (DEBUG) {
                printFontInfoArray();
            }
            tableFileStream.close();
        }
        catch (IOException e) {
            System.err.println(e.getMessage());
        }
    }

    public int calculatePixelWidthOfText() {
        int imageWidth = startX;

        for (int ch = 0; ch < text.length(); ch++) {
            String character = text.substring(ch, ch + 1);

            // create a dummy FontInfo object with the character in the string
            FontInfo dummy = new FontInfo((short) 0, character, 0, 0);
            int arrayPos = Collections.binarySearch(fontInfoArray, dummy, new FontInfoEncodingComparator());
            // int arrayPos = encodings.indexOf(character);

            if (arrayPos < 0) {
                String format = "Binary search for '%s' failed! Return value: %04X";
                System.err.println(String.format(format, character, arrayPos));
                return arrayPos;
            }
            FontInfo hit = fontInfoArray.get(arrayPos);

            // add character width and spacing
            imageWidth += hit.getWidth();
            imageWidth += PIXELS_BETWEEN_CHARS;

            // subtract kerning if pair exists
            if (doKerning && ch + 1 < text.length()) {
                String charPair = text.substring(ch, ch + 2);
                int kerning = kerningPairs.getOrDefault(charPair, 0);
                imageWidth -= kerning;
            }
        }
        if (DEBUG) {
            String format = "As an image, the string \"%s\" would be %dx%d.";
            System.out.println(String.format(format, text, imageWidth, imageHeight));
        }

        return imageWidth;
    }

    private void initialize() {
        try {
            fontImage.initialize();
        }
        catch (IOException e) {
            System.err.println("Error when opening file as image:\n" + e.getMessage());
            return;
        }

        readTableFile();
        switch (kerningTableID) {
            case MAIN_TEXT_KERNING_ID:
                getMainTextKerningPairs();
                break;
            case CREDITS_KERNING_ID:
                getCreditsKerningPairs();
                break;
        }

        Collections.sort(fontInfoArray, new FontInfoEncodingComparator());
        if (DEBUG) {
            System.out.println("\nAfter sorting by encoding:");
            printFontInfoArray();
        }

        imageWidth = calculatePixelWidthOfText();
        if (imageWidth < PIXELS_BETWEEN_CHARS) {
            return;
        }
        if (imageWidth >= MAX_LINE_WIDTH_PIXELS) {
            String format = "Notice: \"%s\" is %d >= %d pixels wide, will require <LINE> code";
            System.out.println(String.format(format, text, imageWidth, MAX_LINE_WIDTH_PIXELS));
        }
    }

    public boolean[][] generateImagePixels() {
        initialize();

        boolean imagePixels[][] = new boolean[imageHeight][imageWidth];
        int pixelCol = startX;
        for (int ch = 0; ch < text.length(); ch++) {
            // IMPORTANT: taking one character at a time assumes no control codes
            String character = text.substring(ch, ch + 1);
            FontInfo dummy = new FontInfo((short) 0, character, 0, 0);
            int arrayPos = Collections.binarySearch(fontInfoArray, dummy, new FontInfoEncodingComparator());

            FontInfo fontInfo = fontInfoArray.get(arrayPos);
            int charPos = fontInfo.getHexValue();
            boolean[][] charFontData = fontImage.getPixelDataForChar(charPos);
            for (int r = 0; r < charFontData.length; r++) {
                for (int c = 0; c < fontInfo.getWidth(); c++) {
                    // using OR is necessary for kerning, as opposed to normally assigning it
                    imagePixels[r][pixelCol + c] |= charFontData[r][c];
                    // if (DEBUG) {
                        // String format = "Writing RGB %06X to pixel %d, %d";
                        // System.out.println(String.format(format, rgb, pixelCol + c, r));
                    // }
                }
            }

            pixelCol += PIXELS_BETWEEN_CHARS + fontInfo.getWidth();
            if (doKerning && ch + 1 < text.length()) {
                String charPair = text.substring(ch, ch + 2);
                int kerning = kerningPairs.getOrDefault(charPair, 0);
                pixelCol -= kerning;
            }
        }
        return imagePixels;
    }

    public int[][] generateShadowing(boolean imagePixels[][]) {
        int font[][] = FontImage.convertPixelMatrixToIntMatrix(imagePixels);
        int shadow[][] = new int[font.length][font[0].length];

        for (int r = 0; r < font.length; r++) {
            int up = r - 1;
            int down = r + 1;
            boolean rowUpExists = up > 0;
            boolean rowDownExists = down != font.length;

            for (int tc = 0; tc < font[r].length; tc++) {
                int left = tc - 1;
                int right = tc + 1;
                boolean tileExistsToLeft = left >= 0;
                boolean tileExistsToRight = right < font[r].length;

                // copy row left; first statement covers bits 6-0 moving into
                // same tile one pixel left; if statement covers bit 7 moving
                // into the tile one to the left on the right edge
                shadow[r][tc] |= (font[r][tc] << 1) & 0xFF;
                if (tileExistsToLeft) {
                    shadow[r][left] |= font[r][tc] >> 7;
                }

                // copy row right; first statement covers bits 7-1 moving into
                // same tile one pixel left; if statement covers bit 0 moving
                // into the tile one to the right, on the left edge
                shadow[r][tc] |= font[r][tc] >> 1;
                if (tileExistsToRight) {
                    shadow[r][right] |= (font[r][tc] << 7) & 0xFF;
                }

                // copy up a row, and offset it both left and right a pixel
                if (rowDownExists) {
                    // up
                    shadow[r][tc] |= font[down][tc];

                    // up + left
                    shadow[r][tc] |= (font[down][tc] << 1) & 0xFF;
                    if (tileExistsToLeft) {
                        shadow[r][left] |= font[down][tc] >> 7;
                    }

                    // up + right
                    shadow[r][tc] |= font[down][tc] >> 1;
                    if (tileExistsToRight) {
                        shadow[r][right] |= (font[down][tc] << 7) & 0xFF;
                    }
                }

                // copy down a row, and offset it both left and right a pixel
                if (rowUpExists) {
                    // down
                    shadow[r][tc] |= font[up][tc];

                    // down + left
                    shadow[r][tc] |= (font[up][tc] << 1) & 0xFF;
                    if (tileExistsToLeft) {
                        shadow[r][left] |= font[up][tc] >> 7;
                    }

                    // down + right
                    shadow[r][tc] |= font[up][tc] >> 1;
                    if (tileExistsToRight) {
                        shadow[r][right] |= (font[up][tc] << 7) & 0xFF;
                    }
                }
            }
        }

        // clear out all shadow pixels that lie on a font pixel
        // S F | shadow     
        // ----+--------    Truth table indicates S <- S & ~F
        // 0 0 |   0        No shadow -> no shadow, don't care if font or not
        // 0 1 |   0        
        // 1 0 |   1        Shadow and not font -> shadow
        // 1 1 |   0        Shadow AND font -> no shadow; font takes precedence
        for (int r = 0; r < font.length; r++) {
            for (int tc = 0; tc < font[r].length; tc++) {
                shadow[r][tc] = shadow[r][tc] & ~font[r][tc];
            }
        }

        return shadow;
    }

    public void outputIntMatrixToFile(int matrix1bpp[][], String filename) throws IOException {
        FileOutputStream file = new FileOutputStream(filename);
        int numTileRows = matrix1bpp.length / FontImage.TILE_HEIGHT;
        numTileRows += (matrix1bpp.length % FontImage.TILE_HEIGHT != 0) ? 1 : 0;
        for (int tr = 0; tr < numTileRows; tr++) {
            for (int tc = 0; tc < matrix1bpp[0].length; tc++) {
                for (int r = 0; r < FontImage.TILE_HEIGHT; r++) {
                    int pixelRow = tr * FontImage.TILE_HEIGHT + r;
                    if (pixelRow >= matrix1bpp.length) {
                        break;
                    }
                    file.write(matrix1bpp[pixelRow][tc]);
                }
            }
        }
        file.flush();
        file.close();
    }

    public void outputShadowedFontBinary(int font[][], int shadow[][], String filename) throws IOException {
        FileOutputStream file = new FileOutputStream(filename);
        int numTileRows = font.length / FontImage.TILE_HEIGHT;
        numTileRows += (font.length % FontImage.TILE_HEIGHT != 0) ? 1 : 0;
        for (int tr = 0; tr < numTileRows; tr++) {
            for (int tc = 0; tc < font[0].length; tc++) {
                for (int r = 0; r < FontImage.TILE_HEIGHT; r++) {
                    int pixelRow = tr * FontImage.TILE_HEIGHT + r;
                    if (pixelRow >= font.length) {
                        break;
                    }
                    file.write(font[pixelRow][tc]);
                    file.write(shadow[pixelRow][tc]);
                }
            }
        }

        file.flush();
        file.close();
    }

    public BufferedImage generateImage(boolean imagePixels[][]) {
        BufferedImage outputImage = new BufferedImage(imageWidth, imageHeight, BufferedImage.TYPE_INT_RGB);
        for (int r = 0; r < imagePixels.length; r++) {
            for (int c = 0; c < imagePixels[r].length; c++) {
                boolean isPixelText = imagePixels[r][c];
                int rgb = isPixelText ? WHITE_RGB : BLACK_RGB;
                outputImage.setRGB(c, r, rgb);
                // pixels are automatically set to black if not explicitly set
            }
        }
        outputImage.flush();
        return outputImage;
    }
}
