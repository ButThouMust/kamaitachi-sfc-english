package font;

import java.io.IOException;

public class FontInserterDriver {
    public static void main(String args[]) throws IOException {
        if (args.length != 5) {
            System.out.println("Sample use: java FontInserterDriver new_font_table_file image_file text_RGB_value char_width char_height");
            return;
        }

        String table = args[0];

        int charWidth = Integer.parseInt(args[3]);
        if (charWidth % 8 != 0) {
            System.out.println("Character width not a multiple of 8, exiting.");
            return;
        }

        int charHeight = Integer.parseInt(args[4]);
        if (charHeight % 8 != 0) {
            System.out.println("Character height not a multiple of 8, exiting.");
            return;
        }

        String image = args[1];
        int textColor = Integer.parseUnsignedInt(args[2], 16);
        FontImage fontImage = new FontImage(image, charWidth, charHeight, textColor);
        FontInserter inserter = new FontInserter(table, fontImage);

        inserter.initialize();
        inserter.generateCharGridDataBlockToBeCompressed();
        inserter.convertFontDataToGameFormat();
        // inserter.convertFontDataToUncompGameFormat();
    }
}
