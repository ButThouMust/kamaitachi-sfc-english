package tilesets.constants;

public class TileCompConstants {

    public static final int NUM_ROWS_PER_TILE = 8;
    public static final int BITMASK_LIST_SIZE = NUM_ROWS_PER_TILE;

    public static final int END_OF_TILE_DATA = 0x00;

    public static final int BIT_DEPTH = 4; // 4bpp
    public static final int TILE_SIZE = NUM_ROWS_PER_TILE * BIT_DEPTH;

    public static final int TILE_NUM_OF_EMPTY_TILE = 0x000;
    public static final int TILE_NUM_OF_DATA_START = 0x001;
    public static final int MAX_NUM_TILES = 0x400;
    public static final int MAX_TILESET_SIZE = TILE_SIZE * MAX_NUM_TILES;

    public static final int CASE_NOT_VALID = -1;

    public static final int MIN_NUM_BIT_POSITIONS = 3;
    public static final int THRESHOLD_FOR_NUM_BIT_POSITIONS = 5;
    public static final int MAX_NUM_BIT_POSITIONS = 8;
    // the list will contain up to 8 bit position values, plus the FF terminator
    public static final int SIZE_OF_TERMINATED_BIT_POS_LIST = MAX_NUM_BIT_POSITIONS + 1;
    public static final int BIT_POSITION_LIST_TERMINATOR = 0xFF;

    public static final int NUM_GROUPS_OF_8_BITMASKS = 3;
    public static final int BITMASK_GROUP_0 = 0;
    public static final int BITMASK_GROUP_1 = 1;
    public static final int BITMASK_GROUP_2 = 2;

    public static final int MAX_BP_METADATA_ENTRIES = 4;
    public static final int NUM_BYTES_FOR_ENCODED_BP_SUBS = 3;
    public static final int COMMON_BP_SUB_INDEX_DATA_SIZE = MAX_BP_METADATA_ENTRIES * NUM_BYTES_FOR_ENCODED_BP_SUBS;

    public static final int COMMON_BITMASK_BIT_POSITIONS_DATA_SIZE = 0xF;

    public static final int METADATA_HEADER_SIZE =
        COMMON_BP_SUB_INDEX_DATA_SIZE + COMMON_BITMASK_BIT_POSITIONS_DATA_SIZE;

    // -------------------------------------------------------------------------

    public static final int READ_8_RAW_BYTES = 0x00;
    public static final int RLE_BITPLANE = 0x03;

    public static final int FILL_BP_WITH_00 = 0x04;
    public static final int FILL_BP_WITH_FF = 0x05;
    public static final int FILL_BP_WITH_BYTE = 0x06;

    public static final int FILL_BP_WITH_00_SPOT_CHANGES = 0x01;
    public static final int FILL_BP_WITH_FF_SPOT_CHANGES = 0x02;
    public static final int FILL_BP_WITH_BYTE_SPOT_CHANGES = 0x09;

    public static final int FILL_BP_WITH_TWO_BYTE_SEQ = 0x07;
    public static final int FILL_BP_WITH_FOUR_BYTE_SEQ = 0x08;
    public static final int FILL_BP_WITH_TWO_BYTE_SEQ_SPOT_CHANGES = 0x0A;

    public static final int CREATE_BP_FROM_TWO_BIT_INDICES_AND_BYTES = 0x0B;
    public static final int CREATE_BP_FROM_TWO_BIT_INDICES_AND_NIBBLES = 0x0C;
    public static final int COPY_BP_FROM_PREV_TILE = 0x0D;

    public static final int USE_BP0 = 0x0F, USE_NOT_BP0 = 0x11;
    public static final int USE_BP1 = 0x13, USE_NOT_BP1 = 0x15;
    public static final int USE_BP2 = 0x23, USE_NOT_BP2 = 0x25;

    public static final int USE_OR_01 = 0x17,  USE_NOT_OR_01 = 0x1D;
    public static final int USE_AND_01 = 0x19, USE_NOT_AND_01 = 0x1F;
    public static final int USE_XOR_01 = 0x1B, USE_NOT_XOR_01 = 0x21;

    public static final int USE_OR_02 = 0x27,  USE_NOT_OR_02 = 0x2D;
    public static final int USE_AND_02 = 0x29, USE_NOT_AND_02 = 0x2F;
    public static final int USE_XOR_02 = 0x2B, USE_NOT_XOR_02 = 0x31;

    public static final int USE_OR_12 = 0x33,  USE_NOT_OR_12 = 0x39;
    public static final int USE_AND_12 = 0x35, USE_NOT_AND_12 = 0x3B;
    public static final int USE_XOR_12 = 0x37, USE_NOT_XOR_12 = 0x3D;

    public static final int USE_OR_012 = 0x3F,  USE_NOT_OR_012 = 0x43;
    public static final int USE_AND_012 = 0x41, USE_NOT_AND_012 = 0x45;

    public static final int MAX_SUB_ID_FOR_BP0 = COPY_BP_FROM_PREV_TILE + 1; // 0xE
    public static final int MAX_SUB_ID_FOR_BP1 = USE_NOT_BP0 + 1; // 0x12
    public static final int MAX_SUB_ID_FOR_BP2 = USE_NOT_XOR_01 + 1; // 0x22
    public static final int MAX_SUB_ID_FOR_BP3 = USE_NOT_AND_012 + 1; // any
    public static final int MAX_SUB_ID_FOR_BP[] = {MAX_SUB_ID_FOR_BP0, MAX_SUB_ID_FOR_BP1, MAX_SUB_ID_FOR_BP2, MAX_SUB_ID_FOR_BP3};

    // -------------------------------------------------------------------------

    public static int getWhichSubIdToDoBeforeSpotChanges(int id) {
        // check if out of range
        if (id < 0 || id > MAX_SUB_ID_FOR_BP3) {
            return CASE_NOT_VALID;
        }

        // check 4 special cases that can't be easily represented by a formula
        switch (id) {
            case FILL_BP_WITH_00_SPOT_CHANGES:
                return FILL_BP_WITH_00;
            case FILL_BP_WITH_FF_SPOT_CHANGES:
                return FILL_BP_WITH_FF;
            case FILL_BP_WITH_BYTE_SPOT_CHANGES:
                return FILL_BP_WITH_BYTE;
            case FILL_BP_WITH_TWO_BYTE_SEQ_SPOT_CHANGES:
                return FILL_BP_WITH_TWO_BYTE_SEQ;
        }

        // check "copy from prev tile" and all the bitwise combinations
        if (id >= COPY_BP_FROM_PREV_TILE && (id & 0x1) == 0) {
            return id - 1;
        }

        // if case doesn't do spot changes, just return the case as-is
        return id;
    }

    public static int getVersionOfSubIdWithSpotChanges(int id) {
        // check if out of range
        if (id < 0 || id > MAX_SUB_ID_FOR_BP3) {
            return CASE_NOT_VALID;
        }

        switch (id) {
            // check 4 special cases that can't be easily represented by a formula
            case FILL_BP_WITH_00_SPOT_CHANGES:
            case FILL_BP_WITH_FF_SPOT_CHANGES:
            case FILL_BP_WITH_BYTE_SPOT_CHANGES:
            case FILL_BP_WITH_TWO_BYTE_SEQ_SPOT_CHANGES:
                return id;

            case FILL_BP_WITH_00:
                return FILL_BP_WITH_00_SPOT_CHANGES;
            case FILL_BP_WITH_FF:
                return FILL_BP_WITH_FF_SPOT_CHANGES;
            case FILL_BP_WITH_BYTE:
                return FILL_BP_WITH_BYTE_SPOT_CHANGES;
            case FILL_BP_WITH_TWO_BYTE_SEQ:
                return FILL_BP_WITH_TWO_BYTE_SEQ_SPOT_CHANGES;

            // cases 00, 03, 08, 0B, 0C do not have corresponding spot change cases
            case READ_8_RAW_BYTES:
            case RLE_BITPLANE:
            case FILL_BP_WITH_FOUR_BYTE_SEQ:
            case CREATE_BP_FROM_TWO_BIT_INDICES_AND_BYTES:
            case CREATE_BP_FROM_TWO_BIT_INDICES_AND_NIBBLES:
                return CASE_NOT_VALID;

            // if (id >= COPY_BP_FROM_PREV_TILE) // that one, plus bitwise combinations
            default:
                if ((id & 0x1) == 0)
                    return id;
                else return id + 1;
        }

        // cases 00, 03, 08, 0B, 0C do not have corresponding spot change cases
        // return CASE_NOT_VALID;
    }

    public static BitplaneCombiner getBitplaneCombinationType(int index) {
        index = getWhichSubIdToDoBeforeSpotChanges(index);
        switch (index) {
            case USE_BP0:     case USE_NOT_BP0:     return BitplaneCombiner.COPY_0;  // see $02968F, $0296D4
            case USE_BP1:     case USE_NOT_BP1:     return BitplaneCombiner.COPY_1;  // see $029693, $0296D8
            case USE_BP2:     case USE_NOT_BP2:     return BitplaneCombiner.COPY_2;  // see $029698, $0296DD

            case USE_OR_01:   case USE_NOT_OR_01:   return BitplaneCombiner.OR_01;   // see $0296FD, $02980B
            case USE_OR_02:   case USE_NOT_OR_02:   return BitplaneCombiner.OR_02;   // see $029715, $029825
            case USE_OR_12:   case USE_NOT_OR_12:   return BitplaneCombiner.OR_12;   // see $02972D, $02983F
            case USE_OR_012:  case USE_NOT_OR_012:  return BitplaneCombiner.OR_012;  // see $029745, $029859

            case USE_AND_01:  case USE_NOT_AND_01:  return BitplaneCombiner.AND_01;  // see $029760, $029876
            case USE_AND_02:  case USE_NOT_AND_02:  return BitplaneCombiner.AND_02;  // see $029778, $029890
            case USE_AND_12:  case USE_NOT_AND_12:  return BitplaneCombiner.AND_12;  // see $029790, $0298AA
            case USE_AND_012: case USE_NOT_AND_012: return BitplaneCombiner.AND_012; // see $0297A8, $0298C4

            case USE_XOR_01:  case USE_NOT_XOR_01:  return BitplaneCombiner.XOR_01;  // see $0297C3, $0298E1
            case USE_XOR_02:  case USE_NOT_XOR_02:  return BitplaneCombiner.XOR_02;  // see $0297DB, $0298FB
            case USE_XOR_12:  case USE_NOT_XOR_12:  return BitplaneCombiner.XOR_12;  // see $0297F3, $029915

            default:
                return null;
        }
    }

    public static boolean bitplaneCombinationTypeDoesBitwiseNOT(int index) {
        index = getWhichSubIdToDoBeforeSpotChanges(index);
        switch (index) {
            case USE_NOT_BP0:    case USE_NOT_BP1:    case USE_NOT_BP2:
            case USE_NOT_OR_01:  case USE_NOT_OR_02:  case USE_NOT_OR_12:  case USE_NOT_OR_012:
            case USE_NOT_AND_01: case USE_NOT_AND_02: case USE_NOT_AND_12: case USE_NOT_AND_012:
            case USE_NOT_XOR_01: case USE_NOT_XOR_02: case USE_NOT_XOR_12:
                return true;

            default:
                return false;
        }
    }

    public static String summarizePurposeOfBitplaneIndex(int index) {
        int mainIndex = getWhichSubIdToDoBeforeSpotChanges(index);
        boolean doSpotChanges = index != mainIndex;

        String result = "";
        switch (mainIndex) {
            case READ_8_RAW_BYTES:  result = "bp <- 8 raw bytes"; break;
            case RLE_BITPLANE:        result = "Pseudo-RLE with byte chunks"; break;
            case FILL_BP_WITH_00:   result = "bp <- all 00"; break;
            case FILL_BP_WITH_FF:   result = "bp <- all FF"; break;
            case FILL_BP_WITH_BYTE: result = "bp <- all next byte from ROM"; break;

            case FILL_BP_WITH_TWO_BYTE_SEQ:
                result = "Read 2 bytes B0, B1; bp <- [B0 B1 B0 B1 B0 B1 B0 B1]"; break;
            case FILL_BP_WITH_FOUR_BYTE_SEQ:
                result = "Read 4 bytes B0-B3; bp <- [B0 B1 B2 B3 B0 B1 B2 B3]"; break;

            case CREATE_BP_FROM_TWO_BIT_INDICES_AND_BYTES:
                result = "Build bp data from 8 2-bit indices and 3 or 4 BYTES"; break;
            case CREATE_BP_FROM_TWO_BIT_INDICES_AND_NIBBLES:
                result = "Build bp data from 16 2-bit indices and four NIBBLES"; break;
            case COPY_BP_FROM_PREV_TILE:
                result = "Copy one bp (can be reversed) from a tile"; break;

            case USE_BP0:         result = "bp <- bp0"; break;
            case USE_NOT_BP0:     result = "bp <- ~bp0"; break;
            case USE_BP1:         result = "bp <- bp1"; break;
            case USE_NOT_BP1:     result = "bp <- ~bp1"; break;
            case USE_BP2:         result = "bp <- bp2"; break;
            case USE_NOT_BP2:     result = "bp <- ~bp2"; break;

            case USE_OR_01:       result = "bp <- bp0 | bp1"; break;
            case USE_AND_01:      result = "bp <- bp0 & bp1"; break;
            case USE_XOR_01:      result = "bp <- bp0 ^ bp1"; break;
            case USE_NOT_OR_01:   result = "bp <- ~(bp0 | bp1)"; break;
            case USE_NOT_AND_01:  result = "bp <- ~(bp0 & bp1)"; break;
            case USE_NOT_XOR_01:  result = "bp <- ~(bp0 ^ bp1)"; break;

            case USE_OR_02:       result = "bp <- bp0 | bp2"; break;
            case USE_AND_02:      result = "bp <- bp0 & bp2"; break;
            case USE_XOR_02:      result = "bp <- bp0 ^ bp2"; break;
            case USE_NOT_OR_02:   result = "bp <- ~(bp0 | bp2)"; break;
            case USE_NOT_AND_02:  result = "bp <- ~(bp0 & bp2)"; break;
            case USE_NOT_XOR_02:  result = "bp <- ~(bp0 ^ bp2)"; break;

            case USE_OR_12:       result = "bp <- bp1 | bp2"; break;
            case USE_AND_12:      result = "bp <- bp1 & bp2"; break;
            case USE_XOR_12:      result = "bp <- bp1 ^ bp2"; break;
            case USE_NOT_OR_12:   result = "bp <- ~(bp1 | bp2)"; break;
            case USE_NOT_AND_12:  result = "bp <- ~(bp1 & bp2)"; break;
            case USE_NOT_XOR_12:  result = "bp <- ~(bp1 ^ bp2)"; break;

            case USE_OR_012:      result = "bp <- bp0 | bp1 | bp2"; break;
            case USE_AND_012:     result = "bp <- bp0 & bp1 & bp2"; break;
            case USE_NOT_OR_012:  result = "bp <- ~(bp0 | bp1 | bp2)"; break;
            case USE_NOT_AND_012: result = "bp <- ~(bp0 & bp1 & bp2)"; break;

            default: result = String.format("BAD INPUT (%02X)", index);
        }

        if (doSpotChanges) result += ", and do spot changes";
        return result;
    }
}
