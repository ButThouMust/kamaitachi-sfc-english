package font;

public class FontInfo implements Comparable<FontInfo> {
    private short hexValue;
    private String encoding;
    private int width;
    private int height;
    private boolean[][] fontData;

    public short getHexValue() {
        return hexValue;
    }

    public String getEncoding() {
        return encoding;
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public boolean[][] getFontData() {
        return fontData;
    }

    public void setFontData(boolean fontData[][]) {
        this.fontData = fontData;
    }

    // by default, compare FontInfo objects by their hex value
    public int compareTo(FontInfo fontInfo) {
        return hexValue - fontInfo.hexValue;
    }

    public FontInfo(short hexValue, String encoding, int width, int height) {
        this.hexValue = hexValue;
        this.encoding = encoding;
        this.width = width;
        this.height = height;
    }

    public boolean equals(Object obj) {
        if (obj == null) return false;
        if (!(obj instanceof FontInfo)) return false;
        FontInfo objFontInfo = (FontInfo) obj;

        return (hexValue == objFontInfo.hexValue) &&
                (encoding.equals(objFontInfo.encoding)) &&
                (width == objFontInfo.width) &&
                (height == objFontInfo.height);
    }

    public String toString() {
        String format = "%04X '%s' is %2dx%2d";
        return String.format(format, hexValue, encoding, width, height);
    }
}
