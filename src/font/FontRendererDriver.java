package font;

import java.awt.image.BufferedImage;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;

import javax.imageio.ImageIO;

public class FontRendererDriver {
    public static void main(String args[]) throws IOException {
        // first, load the font image as an array of T/F booleans
        if (args.length != 6) {
            System.out.println("Sample use: java FontRendererDriver text_file table_file image_file text_RGB_value char_width char_height");
            return;
        }

        String tableFileName = args[1];

        int charWidth = Integer.parseInt(args[4]);
        if (charWidth % FontImage.TILE_WIDTH != 0) {
            System.out.println("Character width not a multiple of 8, exiting.");
            return;
        }

        int charHeight = Integer.parseInt(args[5]);
        if (charHeight % FontImage.TILE_HEIGHT != 0) {
            System.out.println("Character height not a multiple of 8, exiting.");
            return;
        }

        String fontFilename = args[2];
        int textColor = Integer.parseUnsignedInt(args[3], 16);

        // BufferedReader bufferedReader = new BufferedReader(new FileReader("lines of text.txt"));
        BufferedReader bufferedReader = new BufferedReader(new FileReader(args[0]));
        ArrayList<String> lines = new ArrayList<>();
        try {
            String text;
            while ((text = bufferedReader.readLine()) != null) {
                if (!text.equals("")) lines.add(text);
            }
        }
        catch (IOException e) {
            System.err.println(e.getMessage());
            return;
        }
        finally {
            bufferedReader.close();
        }

        String numFormat = "%02d";
        for (int i = 0; i < lines.size(); i++) {
            String line = lines.get(i);
            FontRenderer fontRenderer = new FontRenderer(line, tableFileName,
                fontFilename, charWidth, charHeight, textColor, 1, FontRenderer.MAIN_TEXT_KERNING_ID);
            boolean imagePixels[][] = fontRenderer.generateImagePixels();

            BufferedImage outputImage = fontRenderer.generateImage(imagePixels);
            int fontIntOutput[][] = FontImage.convertPixelMatrixToIntMatrix(imagePixels);
            int shadowOutput[][] = fontRenderer.generateShadowing(imagePixels);

            String outputFileName = "file prompts data/" + String.format(numFormat, i) + " " + line;
            File outputFile = new File(outputFileName + ".png");
            try {
                ImageIO.write(outputImage, "png", outputFile);
                // fontRenderer.outputIntMatrixToFile(fontIntOutput, outputFileName + " - font only.bin");
                // fontRenderer.outputIntMatrixToFile(shadowOutput, outputFileName + " - shadow only.bin");
                fontRenderer.outputShadowedFontBinary(fontIntOutput, shadowOutput, outputFileName + ".bin");
            }
            catch (IOException e) {
                System.out.println(e.getMessage());
            }
        }
        // fontImage = new FontImage(fontFilename, charWidth, charHeight, textColor);
    }
}
