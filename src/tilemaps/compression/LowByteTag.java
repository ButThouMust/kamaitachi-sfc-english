package tilemaps.compression;

import static tilemaps.constants.TilemapCompConstants.INC_SEQ_SIZE_THRESHOLD_3F;
import static tilemaps.constants.TilemapCompConstants.REPEAT_NEW_LOW_BYTE_THRESHOLD_20;
import static tilemaps.constants.TilemapCompConstants.SET_CURR_ID_SIZE;

public class LowByteTag implements Comparable<LowByteTag> {
    private LowByteType type;
    private int size;
    private int position;

    public LowByteTag(LowByteType type, int size, int position) {
        this.type = type;
        this.size = size;
        this.position = position;
    }

    public int getSize() {
        return size;
    }

    public int getPosition() {
        return position;
    }

    public LowByteType getType() {
        return type;
    }

    public int compareTo(LowByteTag other) {
        // first, compare by sizes of data
        int sizeDiff = size - other.size;
        if (sizeDiff != 0) return sizeDiff;

        // if sizes happen to tie, compare by priority
        else return type.getPriority() - other.type.getPriority();
    }

    public int getNumBytesWhenCompressed() {
        // unlike the other compression formats, this value is the exact
        // size of the compression tag, due to not using extra data buffers
        int compSize = 0;
        switch (type) {
            case RepeatCurrID:
            case ReuseBlockFromOneRowUp:
            case ReuseMostRecentValue:
                compSize = 1;
                break;

            case IncreasingSequence:
                compSize = size > INC_SEQ_SIZE_THRESHOLD_3F ? 2 : 1;
                break;

            case RepeatNewID:
                compSize = size > REPEAT_NEW_LOW_BYTE_THRESHOLD_20 ? 3 : 2;
                break;

            case LiteralSequence:
                compSize = size + 1;
                break;

            case DecreasingSequence:
            case IsolatedIncreasingSequence:
                compSize = 2;
                break;

            case SetCurrID:
                compSize = SET_CURR_ID_SIZE;
                break;
        }
        return compSize;
    }
}