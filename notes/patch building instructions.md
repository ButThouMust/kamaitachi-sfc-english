# Patch building instructions
These instructions are a work in progress. I just want to have something out there for this.

## Prerequisites
You will need a *legally obtained* ROM image of the original Japanese game. Beyond using it as the basis for creating the patched game and the patch itself, some of the custom tools for the project involve decompressing data from it and recompressing them to take less space. This was necessary to get a large enough contiguous space for fitting the script.

The custom tools for this project are coded in Java, so you will need to install the JDK on your machine. I have Java 21 when I run `java --version` in a PowerShell terminal.

The build scripts are Windows batch files because they rely on external `.exe` programs like Asar and Atlas. And speaking of those, please see the [tools README](/tools/README.md) for where you can obtain them.

## Function of each batch file
All the batch files assume the JP ROM is present unless otherwise specified.

### Patch creation
- `BUILD patched game.bat`
  - Insert data for English script, menu text, recompressed data. Builds the script from scratch.
  - Assumes that tilesets, tilemaps, LZSS data blocks have already been recompressed.
- `BUILD patched game reuse script.bat`
  - Insert data for English script, menu text, recompressed data. Reuses the already generated script, assuming that you have already run `BUILD patched game.bat` at least once.
  - Same assumption as above regarding recompressed data.
- `TEST SCRIPT with Atlas.bat`
  - Does what it says on the tin. You can make sure that the script is being correctly parsed by Atlas before doing the whole build process.

### JP game data <ins>de</ins>compression
- `DUMP jp script.bat`
  - Self-explanatory.
- `DECOMPRESS jp game silhouettes.bat`
  - Dumps all the data available for the silhouettes.
- `DECOMPRESS jp game tilemaps.bat`
  - Dumps all the background graphics tilemaps present in the game.
- `DECOMPRESS jp game tilesets.bat`
  - Dumps all the background graphics tilesets present in the game.

### JP game data <ins>re</ins>compression
- `LZSS recompress rom blocks.bat`
  - Recompress the reused LZSS blocks in the JP game (all except $5E8000).
  - The new data block for the grid of characters (lookup table + graphics data) is handled separately, when building the patch.
- `SILHOUETTE recompress graphics.bat`
  - Recompresses only the graphics data for the silhouettes.
  - This *does not* require running `DECOMPRESS jp game silhouettes.bat` in advance.
- `TILEMAPS recompress improved ranged.bat`
  - Recompress the background graphics' tilemaps.
  - This *does not* require running `DECOMPRESS jp game tilemaps.bat` in advance.
- `TILESETS recompress.ps1`
  - Recompress the background graphics' tilesets.
  - This *DOES* require running `DECOMPRESS jp game tilesets.bat` in advance, because the tilesets take longer to decompress than silhouettes or tilemaps.
  - Notice that this is a PowerShell script instead of a batch file.

### End credits generation
These do not require the ROM to be present, but do require superfamiconv.
- `END CREDITS generate tilesets and maps from text.bat`
  - Given a mockup image with all the lines of the credits combined together, generate the tileset and tilemap data that the patched game expects for it.
- `END CREDITS generate images from credits font.bat`
  - Given a font for the end credits, data about each character's dimensions, and lines of text for the credits, generate a series of images, with one credit line per image.
  - Use this if you want to make your own end credits not *wholly* from scratch. You still need to stitch them all together in an image editor, preferably one with layers like GIMP.

## Order of batch files to run
Before you can run `BUILD patched game.bat` or `BUILD patched game reuse script.bat`, you must run the following batch files.

### Initial setup with generating data
A warning about disk space, if this concerns you: This section will eat up about 80 MB because of the detailed text logs for compression and decompression.

Open a PowerShell terminal in the root directory of your clone of this repo. You need to recompress data from the JP game:
1. `DECOMPRESS jp game tilesets.bat` and `TILESETS recompress.ps1`
2. `SILHOUETTE recompress graphics.bat`
3. `TILEMAPS recompress improved ranges.bat`
4. `LZSS recompress rom blocks.bat`

You also need to generate the binary data for the end credits from the supplied mockup image, as well as a lookup table for the name entry screen's character graphics data.

5. `END CREDITS generate tilesets and maps from mockup.bat`
6. `NAME ENTRY generate char GFX lookup table.bat`

### Building the patch
Recommended if doing script edits: run `TEST SCRIPT with atlas.bat` to make sure the script doesn't have any uncommented anomalous characters.

Finally, you can run:

7. `BUILD patched game.bat`

And if you need to test something without doing any script modifications, you
can then run `BUILD patched game reuse script.bat`.
