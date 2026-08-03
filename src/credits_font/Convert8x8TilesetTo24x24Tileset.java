package credits_font;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.HashMap;

public class Convert8x8TilesetTo24x24Tileset {
    private static final int BLOCK_WIDTH_IN_TILES = 2;
    private static final int BLOCK_HEIGHT_IN_TILES = 3;
    private static final int NUM_TILES_IN_BLOCK = BLOCK_WIDTH_IN_TILES * BLOCK_HEIGHT_IN_TILES;
    private static final int TILE_WIDTH = 8;
    private static final int TILE_HEIGHT = 8;
    private static final int BLOCK_WIDTH = TILE_WIDTH * BLOCK_WIDTH_IN_TILES;
    private static final int BLOCK_HEIGHT = TILE_HEIGHT * BLOCK_HEIGHT_IN_TILES;

    private static final int TILEMAP_ENTRY_SIZE = 2;

    private static int tilemapWidthTiles;
    private static int tilemapHeightTiles;

    private static int[] tilemap8;
    private static int[] tilemap24;
    private static byte[] tileset8;

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static boolean tilemapFileSizesAreConsistent(String tilemap24Filename, String tilemap8Filename) {
        if (tilemapWidthTiles  % BLOCK_WIDTH_IN_TILES  != 0) {
            System.out.println("Error: tilemap width not a multiple of " + BLOCK_WIDTH);
            return false;
        }
        if (tilemapHeightTiles % BLOCK_HEIGHT_IN_TILES != 0) {
            System.out.println("Error: tilemap height not a multiple of " + BLOCK_HEIGHT);
            return false;
        }

        File tm24 = new File(tilemap24Filename);
        File tm8 = new File(tilemap8Filename);
        int tm24Size = (int) tm24.length();
        int tm8Size = (int) tm8.length();

        // store each 2-byte tilemap entry individually
        tilemap8 = new int[tm8Size / TILEMAP_ENTRY_SIZE];
        tilemap24 = new int[tm24Size / TILEMAP_ENTRY_SIZE];

        System.out.println("# entries for 8x8 and 24x24 tilemaps: " + tilemap8.length + ", " + tilemap24.length);

        boolean isConsistent = tm8Size == tm24Size * NUM_TILES_IN_BLOCK &&
                tm8Size  == TILEMAP_ENTRY_SIZE * tilemapWidthTiles * tilemapHeightTiles;
        if (!isConsistent) {
            System.out.println("Error: tilemaps' file sizes inconsistent with inputted dimensions");
        }
        return isConsistent;
    }

    private static void readTilemapData(int tilemapData[], String tilemapInputFile) throws IOException {
        FileInputStream tilemapFile = new FileInputStream(tilemapInputFile);
        for (int i = 0; i < tilemapData.length; i++) {
            int entry = tilemapFile.read() & 0xFF;
            entry |= (tilemapFile.read() & 0xFF) << 8;
            tilemapData[i] = entry;
        }

        tilemapFile.close();
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    // Given a position in the 24x24 tilemap, obtain the position in the 8x8
    // tilemap of the 8x8 pixel block in the top left.
    private static int getTilePosFromBlockPos(int blockPos) {
        int tilemapWidthBlocks = tilemapWidthTiles / BLOCK_WIDTH_IN_TILES;
        int blockRow = blockPos / tilemapWidthBlocks;
        int blockCol = blockPos % tilemapWidthBlocks;

        int tileRow = blockRow * BLOCK_HEIGHT_IN_TILES;
        int tileCol = blockCol * BLOCK_WIDTH_IN_TILES;
        return tileCol + tileRow * tilemapWidthTiles;
    }

    // Given a position in the 24x24 tilemap, obtain the nine tilemap IDs at the
    // corresponding position in the 8x8 tilemap.
    private static int[] getTileIDsForBlockPos(int blockPos) {
        int tileIDs[] = new int[NUM_TILES_IN_BLOCK];
        int tilePos = getTilePosFromBlockPos(blockPos);
        int listIndex = 0;
        for (int r = 0; r < BLOCK_HEIGHT_IN_TILES; r++) {
            int leftTilePosInRow = tilePos + r*tilemapWidthTiles;
            for (int c = 0; c < BLOCK_WIDTH_IN_TILES; c++) {
                tileIDs[listIndex] = tilemap8[leftTilePosInRow + c];
                listIndex++;
            }
        }
        return tileIDs;
    }

    // Generate a mapping from block IDs (24x24 tilemap IDs) to lists of nine
    // 8x8 tilemap IDs.
    private static HashMap<Integer, int[]> getTileIdListsForBlockIds() {
        HashMap<Integer, int[]> tileIdListFromBlockIDs = new HashMap<>();
        for (int blockPos = 0; blockPos < tilemap24.length; blockPos++) {
            int blockID = tilemap24[blockPos];
            boolean alreadyFoundBlockID = tileIdListFromBlockIDs.containsKey(blockID);
            
            if (!alreadyFoundBlockID) {
                tileIdListFromBlockIDs.put(blockID, getTileIDsForBlockPos(blockPos));
            }
        }

        return tileIdListFromBlockIDs;
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    private static void read8x8Tileset(String tileset8Filename) throws IOException {
        File tileset8File = new File(tileset8Filename);
        int length = (int) tileset8File.length();

        FileInputStream tilesetStream = new FileInputStream(tileset8Filename);
        tileset8 = new byte[length];
        tilesetStream.read(tileset8);
        tilesetStream.close();
    }

    // Given an 8x8 tilemap ID, obtain the raw 1bpp tile data for it.
    private static byte[] get1bppTileData(int tilemap8ID) {
        // N bits/pixel * 64 pixels/tile / (8 bits/byte) = 8N bytes/tile
        final int bitDepth = 1;
        int tileSize = bitDepth * 8;
        byte tileData[] = new byte[tileSize];

        int tilesetPosition = tilemap8ID * tileSize;
        for (int i = 0; i < tileData.length; i++) {
            tileData[i] = tileset8[tilesetPosition + i];
        }
        return tileData;
    }

    private static void generate24x24Tileset(String tileset24Filename) throws IOException {
        FileOutputStream tileset24Stream = new FileOutputStream(tileset24Filename);
        HashMap<Integer, int[]> tileIDLists = getTileIdListsForBlockIds();

        // note: this assumes that 24x24 block IDs were collected in sorted order
        // i.e. superfamiconv will only use new IDs as they come up
        for (int blockID : tileIDLists.keySet()) {
            int[] tileIDList = tileIDLists.get(blockID);
            for (int tileID : tileIDList) {
                byte tileData[] = get1bppTileData(tileID);
                tileset24Stream.write(tileData);
            }
        }
        tileset24Stream.close();

        System.out.printf("Your %dx%d tileset has 0x%3X unique pixel blocks.", BLOCK_WIDTH, BLOCK_HEIGHT, tileIDLists.size());
    }

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    /*
    private static void testTilePosMethod(int blockPos) {
        System.out.println("Block pos " + blockPos + " -> tile pos " + getTilePosFromBlockPos(blockPos));
    }

    private static void testTileIDListMethod(int blockPos) {
        System.out.print("Block pos " + blockPos + " -> tile IDs: [");
        int list[] = getTileIDsForBlockPos(blockPos);
        for (int tileID : list) {
            System.out.print(String.format("%4X", tileID));
        }
        System.out.println("]");
    }

    private static void testListFromBlockIDMethod() {
        HashMap<Integer, int[]> tileIDLists = getTileIdListsForBlockIds();
        for (Integer blockID : tileIDLists.keySet()) {
            int[] list = tileIDLists.get(blockID);
            System.out.printf("Block ID %3X -> [", blockID);
            for (int tileID : list) {
                System.out.print(String.format("%4X", tileID));
            }
            System.out.println("]");
        }
    }
    */

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------

    public static void main(String args[]) throws IOException {
        if (args.length != 6) {
            System.out.println("Sample usage: java Convert8x8TilesetTo24x24Tileset " + 
            "tilemap24.bin tilemap8.bin tileset8.bin tileset24.bin mapWidth mapHeight");
            return;
        }

        String tilemap24Filename = args[0];
        String tilemap8Filename = args[1];
        String tileset8Filename = args[2];
        String tileset24Filename = args[3];

        tilemapWidthTiles = Integer.parseInt(args[4]);
        tilemapHeightTiles = Integer.parseInt(args[5]);
        if (!tilemapFileSizesAreConsistent(tilemap24Filename, tilemap8Filename)) {
            return;
        }

        readTilemapData(tilemap8, tilemap8Filename);
        readTilemapData(tilemap24, tilemap24Filename);
        read8x8Tileset(tileset8Filename);
        generate24x24Tileset(tileset24Filename);

        // testTilePosMethod(5 + 2*tilemapWidthTiles / BLOCK_WIDTH_IN_TILES);
        // testTilePosMethod(tilemapWidthTiles / BLOCK_WIDTH_IN_TILES - 6);
        // testTilePosMethod(tilemapWidthTiles / BLOCK_WIDTH_IN_TILES);
        // testTilePosMethod(tilemapWidthTiles * tilemapHeightTiles / NUM_TILES_IN_BLOCK - 1);

        // testTileIDListMethod(tilemapWidthTiles * tilemapHeightTiles / NUM_TILES_IN_BLOCK - 1);
        // testTileIDListMethod(tilemapWidthTiles * (tilemapHeightTiles - 1) / NUM_TILES_IN_BLOCK);
        /*
        for (int blockPos = 0; blockPos < tilemap24.length; blockPos++) {
            testTileIDListMethod(blockPos);
        }
        */
        // testListFromBlockIDMethod();
    }
}
