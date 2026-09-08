package tilemaps.compression;

import tilemaps.constants.TilemapCompConstants;

public class PaletteXYTag {
    private PaletteXYType type;
    private int size;
    private int position;

    private int run00Threshold;

    public PaletteXYTag(PaletteXYType type, int size, int position, boolean run00ThresholdIs3F) {
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

    public PaletteXYType getType() {
        return type;
    }

    public int getNumBytesToEncodeCase() {
        if (type == PaletteXYType.RunOfZeroes && size > run00Threshold)
            return 2;
        return 1;
    }

    public int getNumValsToReadFromBuffer(boolean checkingPalettes) {
        int numValsToRead = 0;
        switch (type) {
            case LiteralSequence:
                numValsToRead = size - 1;
                break;
            case NewPaletteXYThenZeroes:
                // convention: the new value is included in the size for the
                // purposes of case comparison; leave out here since we only
                // care about the size of the 00 run
                // # 00 palettes >= 0x5, or # 00 X/Y flips >= 0x9
                if (size - 1 > TilemapCompConstants.getThresholdFor00sAfterNewPaletteXyValue(checkingPalettes)) {
                    numValsToRead = 1;
                }
                break;
            case RepeatNewPaletteXY:
                // # palettes >= 0x6, or # X/Y flips >= 0xA
                if (size > TilemapCompConstants.getThresholdForRepeatNewPaletteXY(checkingPalettes)) {
                    numValsToRead = 1;
                }
                break;
            default:
                break;
        }
        return numValsToRead;
    }
}
