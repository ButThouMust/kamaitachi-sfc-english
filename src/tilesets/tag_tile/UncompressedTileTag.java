package tilesets.tag_tile;

import java.util.ArrayList;

public class UncompressedTileTag extends TileCompressionTag {
    private int[] tileData;
    private static final int CASE_BYTE = 0x20;

    public UncompressedTileTag(int tileNum, int tileData[]) {
        this.tileNum = tileNum;
        // not sure if the deep array copy is truly required, but putting in
        this.tileData = new int[tileData.length];
        for (int i = 0; i < tileData.length; i++) {
            this.tileData[i] = tileData[i];
        }
    }

    @Override
    protected void encodeData() {
        encodedData = new ArrayList<>();
        encodedData.add(CASE_BYTE);
        for (int i = 0; i < tileData.length; i++) {
            encodedData.add(tileData[i]);
        }
    }

    @Override
    public int getNumBytesSavedFromUsingMetadata() {
        return 0;
    }

    @Override
    public String toString() {
        return String.format("Tile %03X:\n0x20 uncompressed bytes", tileNum);
    }
}
