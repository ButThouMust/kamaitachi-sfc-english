package huffman;

public class HuffScriptPointer implements Comparable<HuffScriptPointer> {
    private int ptrValue;
    private int ptrValueBitOffset;
    private int ptrLocation;
    private int ptrLocationBitOffset;
    private int ptrNum;

    public int getPtrValue() {
        return ptrValue;
    }

    public int getPtrValueBitOffset() {
        return ptrValueBitOffset;
    }

    public int getPtrLocation() {
        return ptrLocation;
    }

    public int getPtrLocationBitOffset() {
        return ptrLocationBitOffset;
    }

    public int getPtrNum() {
        return ptrNum;
    }

    public int compareTo(HuffScriptPointer other) {
        return ptrValue - other.ptrValue;
    }

    public HuffScriptPointer(int ptrValue, int ptrValueBitOffset, int ptrLocation, int ptrLocationBitOffset, int ptrNum) {
        this.ptrValue = ptrValue;
        this.ptrValueBitOffset = ptrValueBitOffset;
        this.ptrLocation = ptrLocation;
        this.ptrLocationBitOffset = ptrLocationBitOffset;
        this.ptrNum = ptrNum;
    }

    public HuffScriptPointer(int ptrValue, int ptrLocation, int ptrNum) {
        this.ptrValue = ptrValue;
        this.ptrValueBitOffset = 0;
        this.ptrLocation = ptrLocation;
        this.ptrLocationBitOffset = 0;
        this.ptrNum = ptrNum;
    }

    public String toString() {
        String format = "Ptr #%4d @ %06X-%d -> %06X-%d";
        return String.format(format, ptrNum, ptrLocation, ptrLocationBitOffset, ptrValue, ptrValueBitOffset);
    }
}
