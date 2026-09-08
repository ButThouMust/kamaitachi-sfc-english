package tilemaps.compression;

import tilemaps.constants.TilemapCompConstants;

public class HighBitTag {
    private HighBitType type;
    private int size;
    private int position;

    private int run00Threshold;

    public HighBitTag(HighBitType type, int size, int position, boolean run00ThresholdIs3F) {
        this.type = type;
        this.size = size;
        this.position = position;

        run00Threshold = TilemapCompConstants.getRun00Threshold(run00ThresholdIs3F);
    }

    public int getSize() {
        return size;
    }

    public int getPosition() {
        return position;
    }

    public HighBitType getType() {
        return type;
    }

    public int getNumBytesToEncodeCase() {
        // RUN_00_THRESHOLD_3F or RUN_00_THRESHOLD_40
        if (type == HighBitType.RunOfZeroes && size > run00Threshold)
            return 2;
        return 1;
    }

    public int getNumValsToReadFromBuffer() {
        int numValsToRead = 0;
        switch (type) {
            case LiteralSequence:
                numValsToRead = size - 1;
                break;
            case NonZeroThenZeroes:
                // size >= 0x9
                int numZeroes = size - 1;
                if (numZeroes > TilemapCompConstants.HIGH_BITS_00_RUN_THRESHOLD_08) {
                    numValsToRead = 1;
                }
                break;
            case RepeatNonZeroVal:
                // size >= 0xA
                if (size > TilemapCompConstants.HIGH_BITS_REPEAT_VAL_THRESHOLD_09) {
                    numValsToRead = 1;
                }
                break;
            default:
                break;
        }
        return numValsToRead;
    }
}