package font;

import java.util.Comparator;

/**
 * Class for comparing FontInfo objects by their widths and heights.
 */
public class FontInfoDimensionComparator implements Comparator<FontInfo> {
    public int compare(FontInfo fontInfo1, FontInfo fontInfo2) {
        // first, sort by widths
        int compareWidths = fontInfo1.getWidth() - fontInfo2.getWidth();
        if (compareWidths != 0) {
            return compareWidths;
        }

        // then, sort by heights
        int compareHeights = fontInfo1.getHeight() - fontInfo2.getHeight();
        if (compareHeights != 0) {
            return compareHeights;
        }

        // if widths and heights are identical, sort by their hex values
        return fontInfo1.compareTo(fontInfo2);
    }
}