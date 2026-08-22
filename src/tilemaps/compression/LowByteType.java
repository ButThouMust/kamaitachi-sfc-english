package tilemaps.compression;

public enum LowByteType {
    RepeatCurrID(6),
    IncreasingSequence(5),
    ReuseBlockFromOneRowUp(4),
    ReuseMostRecentValue(3),
    RepeatNewID(2),
    LiteralSequence(1),
    // new cases for improved format
    SetCurrID(1),
    DecreasingSequence(2),
    IsolatedIncreasingSequence(2);

    private int priority;

    private LowByteType(int priority) {
        this.priority = priority;
    }

    public int getPriority() {
        return priority;
    }
}