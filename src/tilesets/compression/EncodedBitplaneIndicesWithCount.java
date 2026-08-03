package tilesets.compression;

import tilesets.tag_tile.TileBitplaneSubroutinesTag;

public class EncodedBitplaneIndicesWithCount implements Comparable<EncodedBitplaneIndicesWithCount> {
    private int encodedIndices;
    private int count;

    public EncodedBitplaneIndicesWithCount(int encodedIndices) {
        this(encodedIndices, 0);
    }

    public EncodedBitplaneIndicesWithCount(int encodedIndices, int count) {
        this.encodedIndices = encodedIndices;
        this.count = count;
    }

    public int getEncodedIndices() {
        return encodedIndices;
    }

    public int getCount() {
        return count;
    }

    public int incrementCount() {
        count += TileBitplaneSubroutinesTag.getNumBytesSavedFromUsingMetadata(encodedIndices);
        return count;
    }

    public int decrementCount() {
        count -= TileBitplaneSubroutinesTag.getNumBytesSavedFromUsingMetadata(encodedIndices);
        return count;
    }

    public int compareTo(EncodedBitplaneIndicesWithCount other) {
        int countCompare = count - other.count;
        if (countCompare != 0) return countCompare;
        return encodedIndices - other.encodedIndices;
    }
}
