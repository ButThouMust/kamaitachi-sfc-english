package tilemaps.compression;

public enum PaletteXYType {
    RunOfZeroes(4),
    ReuseFromOneRowUpThenZeroes(3),
    ReuseFromOneRowUpAndRepeat(3),
    NewPaletteXYThenZeroes(2),
    RepeatNewPaletteXY(2),
    LiteralSequence(1);

    int priority;

    private PaletteXYType(int priority) {
        this.priority = priority;
    }

    public int getPriority() {
        return priority;
    }
}