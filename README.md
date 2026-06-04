# kamaitachi-sfc-english
In case anyone happens upon this repo, I wanted to put at the top that *I do not have a translation patch file yet*. For the time being, this will just be a place where I'll do project updates, but I will also eventually put my source code and patches here. [Also, I will not make the mistake of separating out the project into multiple repositories; everything related to the project will go here]

**No generative AI or LLMs have touched, nor will touch, any part of this translation project.** All code for my custom tools, all ASM hacks, all graphics edits, and particularly the translated script, were created manually.

I had created a [translation patch](https://github.com/ButThouMust/otogirisou-english) for the Chunsoft sound novel Otogirisou on Super Famicom. At some point during the creation of that patch, I tried digging around in Chunsoft's next game in the same style, and found enough things in common between their internal workings that I wanted to work on it, too.

![](/repo%20images/title%20screen%20screenshot.png)
![](/repo%20images/file%20select%20screen%20translated.png)
![](/repo%20images/english%20script%20insertion.png)
![](/repo%20images/name%20entry%20grid%20translated%20-%20pg%201.png)

Kamaitachi no Yoru (かまいたちの夜) is a murder mystery sound novel that takes place in a ski lodge during a blizzard. If you had to translate the title using only English words, it would be *The Night of the Sickle Weasel*.

Some innovations over Otogirisou:
- background images being mostly digitized photos, and a handful of pixel art
- silhouettes of the cast of characters; some are even animated!
- bad endings where the story concludes prematurely
- the ability to start from a previous chapter upon reaching an ending

The game was originally released for the Super Famicom in 1994, and has been ported and remade several times in Japan over the years. Most recently, it and its two sequels on PS2 were remade for PS4/Switch/Steam in 2024 for its 30th anniversary (albeit with only the main mystery scenarios for the first two games). Two versions have been localized into English:
- an official localization *Banshee's Last Cry* for old 32-bit versions of iOS, with the Japanese setting changed to British Columbia
- a [fan localization patch by Project Kamai](https://web.archive.org/web/20230801045909/https://projectkamai.com/) of the Rinne Saisei remake for PC

I've put most of my project updates in [this thread](https://discord.com/channels/266412086291070988/1089409844743782440) in the RHDI Discord server. Feel free to check it out.

I also have a sparsely updated thread in the RHDI forums [here](https://romhack.ing/forum/topic/m4by-ZUB5QO4GBdZ3zyn).

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
  - This was more difficult than it sounds, interestingly.
  - Short version: the graphics for the 9x10 grid of characters does not use the typical font printing routine, but rather its own format.
  - Updating only the text encoding table would not change what characters are displayed in the grid.

### <ins>Graphics</ins>
- Insert translated graphics for the stereo/mono option.
- Translate the 終 graphic that the player sees upon reaching a bad end.
  - Exact translated graphics are not set in stone, but easily editable.
- For the boxes on the name entry screen, both translate their text and painstakingly update the absolute myriad of ways they get drawn to the screen.
- Restore an unused background graphic and a few unused silhouettes.
  - They were added to the PS1 release but do exist in the SFC version's data, and so I decided to incorporate them into the script.
- Reverse engineer the format for how the [end credits](/notes/end%20credits/NOTES%20end%20credits.txt) are displayed.
- Translate the screen containing the opening credits (thanks to FCandChill for designing the translated graphic!).

### <ins>Graphics compression formats</ins>
| Data type | Decompressor | Recompressor |
| :--- | :---: | :---: |
| Background graphics tile*sets* | Done | Done, improvable |
| Background graphics tile*maps* | Done | Done |
| Name entry character grid font | Done | Done |
| Silhouette graphics | Done | Done |

The tileset compression format was really complicated to figure out from the decompression ASM code. I saved ~4 KB from recompressing the game's data.
- After all the work that went into making the program, I was kind of disappointed with saving "only" 4 KB (for scale, original compressed data is over 1 MB), but I suppose I'll take what I can get.
- The format allows you to load uncompressed graphics data, but the programmer in me took making a recompressor as a challenge.
- Compared to Chunsoft's original compressor, my recompressor produces a smaller data block for all but one of the tilesets present in the game.
  - Depending on whether I set two specific comparisons in the code as `>=` or `>`, the results can be slightly smaller or larger.
- I'd spent too much time on something that I'd initially marked as "nice to have" for the patch, and I wanted to move on from it.

My background tilemap recompressor saves ~2.45 KB across all the tilemaps present in the game.
- I saved 1 KB while staying within the confines of the compression formats (note the plural) in the original Japanese game.
- I saved another 1.45 KB from tweaking one format to better handle certain data patterns, as well as allowing some existing compression cases to compress more data at once for all the formats.

The font graphics for the grid of characters on the name entry screen, and some other graphics, have their own compression format (it's a flavor of LZSS). I made a recompressor for it and tweaked part of the format.
- The font data block has been replaced with one for English, but recompressing the original Japanese font block would save about 700 bytes.
- With all the game's other LZSS data blocks, I saved over 1.2 KB total.

No silhouettes contain any text to translate, so I initially thought I wouldn't need to create a graphics recompressor for them. However, I discovered some ways to improve the existing compression, which altogether let me free up ~6.9 KB from recompressing the existing data.
- A bonus to figuring out the format was that I was able to fix a silhouette that has an apparent error with the graphics: a 16x8 pixel block missing the silhouette color.

![](/repo%20images/silhouette%20gfx%20error%200x06E.png)

## Priorities for the project
I have recompressed and/or rearranged enough data in the ROM to allow fitting an English script and font into it. Moreover, I succeeded at a self-imposed challenge to do so without needing to expand the ROM like I had to for Otogirisou.

With the automatic linebreaking updated to work better for English, I can start playtesting the script and marking pages as needing reformatting or not. But before investing too much time into a save file for that, I need to modify the systems related to letting the player enter a name.

### <ins>Name entry screen</ins>
![](/repo%20images/name%20entry%20grid%20translated%20-%20pg%201.png)

Getting the name entry screen to work for an English translation will take some extensive ASM edits. I felt that solely in-place ASM code edits would be too restrictive for what I want to do, so I got a disassembly of all the associated code and started editing it. I shrunk its assembled size as much as I reasonably could.

#### <ins>Character limit for names</ins>
I want to be able to change the name entry screen to support a limit of 10+ characters instead of 6 like in the original (**difficult**).

*I would say this is the main thing holding me back from releasing a patch.* Expectations for what I have to do:
- Change storage format for names in memory and the save data (one byte per character instead of two)
- Find every single piece of code that processes their data in some way, and update them all
- Change how the game prints the currently entered name to the screen (use a proportional font instead of the original monospace)

This is an important change mainly because at certain points in the murder mystery, the player must enter the name of who they believe to be the killer. Most characters' names are longer than six letters when translated into English.

Another reason this is important is that solving the murder mystery will open up more routes and endings for the player to view. I don't want to release a patch that uses the original system, and then another patch later that uses a new system.

#### <ins>DONE Change menu logic for character grid</ins>
The Japanese game allows entering a name with a combination of kanji, hiragana, or katakana. Each category has 1160, 90, and 90 slots in their respective grids of characters. 1160 slots is much too many for English!

I was able to make an ASM hack to only allow access to the blocks for hiragana/katakana, which I repurposed for the standard alphabet, digits, some punctuation, and accented characters. Below is a GIF of the result.

![](/repo%20images/kamaitachi%20english%20name%20entry.gif)

### <ins>English script</ins>
![](/repo%20images/english%20script%20insertion.png)

- Create ASM hacks to make the English text look better on screen. (**medium**)
  - DONE: Better logic for automatically line breaking English text (fix what you see in the above screenshot).
    - Fixed for both the usual text printing, as well as the mode for showing text that the player has previously read.
  - Planned: Text kerning, to fix character pairs like `ac` above or `aj`.
- Once that's done, playtest the script. (**simple, but tedious**)
- Fully translate the Japanese script to English. (**medium**)
  - Translation mostly done, but quite a few places are difficult to translate.  More details in the [spoiler folder's readme](/notes/spoilers/README.md).
  - If I could, I'd like to reach out to the Project Kamai team and ask for permission to use their translation choices for certain parts.
    - A Wayback Machine snapshot of their website had an email address for contacting them. Perhaps as expected, though, sending a message to it gave me an error that the address doesn't exist anymore.

## "Nice to have" items
- Translate the end credits (medium).
- Translate other graphics like the title screen (**difficult**), or another screen that references another Chunsoft game (medium, debatably unnecessary). More details [here](/notes/gfx%20translation/README.md).
