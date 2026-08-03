package font;

import java.util.Comparator;

public class FontInfoEncodingComparator implements Comparator<FontInfo> {
    public int compare(FontInfo fontInfo1, FontInfo fontInfo2) {
        return fontInfo1.getEncoding().compareTo(fontInfo2.getEncoding());
    }
}
