package tilesets.tag_tile;

import static tilesets.constants.TileCompConstants.TILE_SIZE;

import java.util.ArrayList;

// singleton class
public class TileCaseNotSupportedTag extends TileCompressionTag {
    private TileCaseNotSupportedTag() {
        encodeData();
    }

    private static TileCaseNotSupportedTag tag = new TileCaseNotSupportedTag();
    public static TileCaseNotSupportedTag getInstance() {
        return tag;
    }

    @Override
    protected void encodeData() {
        tileNum = 0;
        encodedData = new ArrayList<>(2 * TILE_SIZE);
    }

    @Override
    public int getSizeOfEncodedData() {
        return 2 * TILE_SIZE;
    }

    @Override
    public int getNumBytesSavedFromUsingMetadata() {
        return 0;
    }

    @Override
    public String toString() {
        return "(Tile case not supported)";
    }
}
