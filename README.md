# kamaitachi-sfc-english
In case anyone happens upon this repo, I wanted to put at the top that *I do not have a translation patch file yet*. For the time being, this will just be a place where I'll do project updates, but I will also eventually put my source code and patches here.

I had created a [translation patch](https://github.com/ButThouMust/otogirisou-english) for the Chunsoft sound novel Otogirisou on Super Famicom. At some point during the creation of that patch, I tried digging around in Chunsoft's next game in the same style, and found enough things in common between their internal workings that I wanted to work on it, too.

![](/repo%20images/title%20screen%20screenshot.png)
![](/repo%20images/file%20select%20screen%20translated.png)
![](/repo%20images/english%20script%20insertion.png)
![](/repo%20images/name%20entry%20grid%20translated%20-%20pg%201.png)

Kamaitachi no Yoru (かまいたちの夜) is a murder mystery sound novel that takes place in a ski lodge during a blizzard. If you had to translate the title using only English words, it would be *The Night of the Sickle Weasel*.

Some innovations over Otogirisou:
- background images being mostly digitized photos, and a handful of pixel art
- silhouettes of the cast of characters
- bad endings where the story concludes prematurely
- the ability to start from a previous chapter upon reaching an ending

The game was originally released for the Super Famicom in 1994, and has been ported and remade several times in Japan over the years. Most recently, it and its two sequels on PS2 were remade for PS4/Switch/Steam in 2024 for its 30th anniversary. Two versions have been localized into English:
- an official localization *Banshee's Last Cry* for old 32-bit versions of iOS, with the Japanese setting changed to British Columbia
- a [fan localization patch by Project Kamai](https://web.archive.org/web/20230801045909/https://projectkamai.com/) of the Rinne Saisei remake for PC

I'd done a lot of project updates in [this thread](https://discord.com/channels/266412086291070988/1089409844743782440) in the RHDI Discord server, which you can read if you like. I also have a sparsely updated thread in the RHDI forums [here](https://romhack.ing/forum/topic/m4by-ZUB5QO4GBdZ3zyn).

Sample screenshots for the project are in the [`repo images` folder](repo%20images).

Work is being done using a ROM dump from an original cartridge, that conforms to the specification in the [No-Intro database](https://datomatic.no-intro.org/index.php?page=show_record&s=49&n=1301):

```
CRC32:		71c631aa
MD5:		efe8a1e8fbd0c05d1f515e2227e48d11
SHA-1:		4c8f357bd86f9ed909d6a89afb0dbe74913fb333
SHA-256:	3228a3b35f7d234a7bf91f8159ccc56518199222e84d258c14a153f54f9fcbc7
```

## Solved items
### <ins>Text</ins>
- Dump the Japanese font.
- Dump the compressed Japanese script.
- Compress and reinsert modified versions of the Japanese script into the game.
  - I used this to test scripts for viewing unused content, in particular some silhouettes and visual effects.
- Insert and compress an English font and a translated script into the game.
- Insert translated menu prompts for managing files, like "start game", "delete file", "change names", etc.
- Edited the name entry screen to let the player input a name in English.
  - This was more difficult than it sounds, interestingly. The short version is, the graphics for the 9x10 grid of characters does not use the typical font printing routine, but rather its own format. So updating only the text encoding table would not change what characters the player sees on the screen.

### <ins>Graphics</ins>
- Insert translated graphics for the stereo/mono option.
- Translate the 終 graphic that the player sees upon reaching a bad end.
  - Exact translated graphics are not set in stone, but easily editable.
- For the boxes on the name entry screen, translate both their text and painstakingly update the absolute myriad of ways they get drawn to the screen.
- Reverse engineer the format for how the [end credits](/notes/end%20credits/NOTES%20end%20credits.txt) are displayed.

### <ins>Graphics compression formats</ins>
| Data type | Decompressor | Recompressor |
| :--- | :---: | :---: |
| Background graphics tile*sets* | Done | Done, improvable |
| Background graphics tile*maps* | Done | Done |
| Name entry character grid font | Done | Done |
| Silhouette graphics | Done | Done |

The tileset compression format was really complicated to figure out from the decompression ASM code. It already has a case for loading uncompressed graphics data, but the programmer in me took making a recompressor as a challenge.
- Currently, it is not fully optimal and can work better or worse than Chunsoft's original compressor based on the tilesets you feed it. However, it works well enough for my purposes.
  - I've spent too much time on something that I'd initially marked as "nice to have" for the patch, and I want to move on from it.
- If you care what can be improved, compressed tilesets have a data header consisting of two blocks. Two decompression cases allow you to use less data by doing "get 1 byte containing an index or indices for reading data from the header" instead of "get 2 or 3 bytes for the data itself." My method of choosing what data to put into the header is still improvable.

My background tilemap recompressor saves about 2.45 KB across all the tilemaps present in the game.
- I saved 1 KB while staying within the confines of the compression formats (note the plural) in the original Japanese game.
- I saved another 1.45 KB from tweaking one format to better handle certain data patterns, as well as allowing some existing compression cases to compress more data at once for all the formats.

The font graphics for the grid of characters on the name entry screen, and some other graphics, have their own compression format (it's a flavor of LZSS). My recompressor saves about 700 bytes with the Japanese font data block (moot point, it's been replaced with an equivalent English data block), and over 1.2 KB total with all the game's other data sets in that format.

At first, I was expecting to not have to create a recompressor for the silhouettes' graphics data, because none of them contain any text to translate. However, I discovered some ways to improve the existing compression, which altogether let me free up ~6.9 KB from recompressing the existing data.
- A bonus to figuring out the format was that I was able to fix a silhouette that has an apparent error with the graphics. When I was playing the game, I found that a 16x8 pixel block in the top left of this screenshot was missing the silhouette color.

![](/repo%20images/silhouette%20gfx%20error%200x06E.png)

## Priorities for the project
I have recompressed and/or rearranged enough data in the ROM to allow fitting an English script and font into it. Moreover, I succeeded at a self-imposed challenge to do so without needing to expand the ROM like I had to for Otogirisou.

I can technically start playtesting the script and marking pages as needing reformatting or not. However, I first need to do ASM hacks for the text printing logic and the systems related to letting the player enter a name.

### <ins>English script</ins>
![](/repo%20images/english%20script%20insertion.png)

- Create ASM hacks to make the English text look better on screen. (**medium**)
  - More suitable logic for automatically line breaking English text (see above).
  - [Optional] Text kerning, to fix character pairs like `ac` above or `at`.
- Once that's done, playtest the script. (**simple, but tedious**)
- Fully translate the Japanese script to English. (**medium**)
  - Translation mostly done, but quite a few places are difficult to translate.  More details in the [spoiler folder's readme](/notes/spoilers/README.md).
  - If I could, I'd like to reach out to the Project Kamai team and ask for permission to use their translation choices for certain parts.
    - A Wayback Machine snapshot of their website had an email address for contacting them. Perhaps as expected, though, sending a message to it gave me an error that the address doesn't exist anymore.

### <ins>Name entry screen</ins>
![](/repo%20images/name%20entry%20grid%20translated%20-%20pg%201.png)

Getting the name entry screen to work for an English translation is going to take a very extensive ASM hack. I felt that using only in-place ASM code edits would be too restrictive for what I want to do, so I got a disassembly of all the code in bank 04 and started editing it. I saved over 0x500 bytes of code from things like cutting out unneeded code, optimizing out repeated code snippets, and replacing lots of intra-bank `JSL`s with `JSR`s. Hopefully plenty of space to let me do what I want there.

#### <ins>DONE Change menu logic for character grid</ins>
The Japanese game allows entering a name with a combination of kanji, hiragana, or katakana. Each category has 1160, 90, and 90 slots in their respective grids of characters. 1160 slots is much too many for English!

I was able to make an ASM hack to only allow access to the blocks for hiragana/katakana, which I repurposed for the standard alphabet, digits, some punctuation, and accented characters. Below is a GIF of the result.

![](/repo%20images/kamaitachi%20english%20name%20entry.gif)

#### <ins>Character limit for names</ins>
I want to be able to change the name entry screen to support a limit of 10+ characters instead of 6 like in the original (**difficult**).
- The code is used for naming the protagonist and his girlfriend, but also for certain points in the story where the player must enter the name of who they believe to be the killer in the murder mystery. Most characters' names are longer than six letters when translated into English.
- Getting this right is very important, because solving the murder mystery opens up more routes and endings for the player to view.
- See if it would be possible to print the name with the game's VWF, as opposed to printing the characters monospaced.

## "Nice to have" items
- Translate the end credits (medium).
- Translate other graphics like the title screen (**difficult**), or another screen that references another Chunsoft game (medium). More details [here](/notes/gfx translation/README.md).
- Done: Translate the screen containing the opening credits (thanks to FCandChill for designing the translated graphic!).
