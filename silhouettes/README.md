# Silhouette decompression tool
This is a tool for decompressing the silhouette data for the game. Some prerequisites for running:
- Installation of Java
- A ROM dump of Kamaitachi no Yoru that matches the No-Intro specification

Place your game dump in this folder, open a terminal, and execute the two commands:
- `javac KamaitachiSilhouetteDecomp.java`
- `java KamaitachiSilhouetteDecomp`

For information about the underlying systems for storing silhouettes, see [my notes](/silhouettes/kamaitachi%20silhouette%20decompression.txt) that I had taken about them.

## How to view the silhouettes
The tool groups together silhouette data based on control code inputs. If you want to see the silhouettes from the dumped data, download the utility [Tilemap Studio](https://github.com/Rangi42/tilemap-studio) and run it.

In a folder for a control code input, locate the `.2bpp` file (graphics data) and any of the `converted tilemap.bin` files (each is one frame). Drag and drop the graphics file into the left half, and a tilemap file into the right half.

If you care about why "converted tilemap", it is because the game primarily displays the silhouettes on screen as sprites but sometimes will convert the sprites' OAM data into a tilemap (SNES background layer). This OAM-to-tilemap conversion happens to work well with using Tilemap Studio, and it wasn't too hard to port over Chunsoft's ASM code that accomplishes it.

Sometimes, the silhouettes will show up exactly as you would expect:\
![](/repo%20images/example%20silhouette%20-%20basic.png)

Other times, not so much. This is because in the game, Chunsoft had to use some palette trickery to fit all the sprites' tiles within a limit of 0x200 tiles. Below is an example comparing three things:
- the dumper's output in Tilemap Studio
- what you would see if you looked at an SNES emulator's sprite viewer with the correct palettes filled in
- what the silhouettes look like in the game itself

![](/repo%20images/example%20silhouette%20-%20not%20basic.png)
![](/repo%20images/silhouette%20set%20008%20in%20sprite%20viewer%20-%20gray%20bg.png)
![](/repo%20images/silhouette%20set%20008%20screenshot.png)
