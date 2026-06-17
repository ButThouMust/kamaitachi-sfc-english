# kamaitachi-sfc-english
In case anyone happens upon this repo, I wanted to put at the top that *I do not have a translation patch file yet*. For the time being, this will just be a place where I'll do project updates, but I will also eventually put my source code and patches here. [Also, I will not make the mistake of separating out the project into multiple repositories; everything related to the project will go here]

**No generative AI or LLMs have touched, nor will touch, any part of this translation project.** All code for my custom tools, all ASM hacks, all graphics edits, and particularly the translated script, were created manually.

TL;DR on project status:
- I think it is reasonable to expect a patch release during 2026. Exactly when, I cannot say.
- I am primarily polishing the script and doing play-testing.
- Most of the necessary assembly code modifications are done.
  - I would like to add text kerning at some point.

## Project overview
I had created a [translation patch](https://github.com/ButThouMust/otogirisou-english) for the Chunsoft sound novel Otogirisou on Super Famicom. At some point during the creation of that patch, I tried digging around in Chunsoft's next game in the same style, and found enough things in common between their internal workings that I wanted to work on it, too.

![](/repo%20images/title%20screen%20screenshot.png)
![](/repo%20images/file%20select%20screen%20translated.png)
![](/repo%20images/english%20script%20insertion.png)
![](/repo%20images/english%20name%20entry%2010%20chars.png)

Kamaitachi no Yoru (かまいたちの夜) is a murder mystery sound novel that takes place in a ski lodge during a blizzard. If you had to translate the title using only English words, it would be *The Night of the Sickle Weasel*.

Some innovations over Otogirisou:
- The script engine is more refined, with faster printing speed and a more comprehensive text lookback feature.
- Background images are mostly digitized photos, with a handful of screens using pixel art.
- There are silhouettes of the cast of characters; some are even animated!
- Your choices can now lead to the story concluding prematurely in a bad ending.
- Upon reaching an ending, you can choose to resume from a previous chapter.

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

## Project priorities
### <ins>English script</ins>
The main things to do with the script are to fully translate (it's ~95% done), and playtest it.
- Quite a few places in the script are difficult to translate.
  - More details in the [spoiler folder's readme](/notes/spoilers/README.md).
  - If I could, I'd like to reach out to the Project Kamai team and ask for permission to use their translation choices for certain parts.
- Nice to have: Create ASM hack for [text kerning](https://en.wikipedia.org/wiki/Kerning).

I attempted to contact the Project Kamai team via an email address that was on a Wayback Machine snapshot of their website. Perhaps as expected, though, sending a message to it gave me an error that the address doesn't exist anymore.

## Solved items
### <ins>Text</ins>
- Dump the Japanese font.
- Dump the compressed Japanese script.
- Compress and reinsert modified versions of the Japanese script into the game.
  - I used this to test scripts for viewing unused content, in particular some silhouettes and visual effects.
- Insert and compress an English font and a translated script into the game.
- Insert translated menu prompts for managing files, like "start game", "delete file", "change names", etc.
- Ten lines of text can fit on screen instead of the original game's nine.
- Make the automatic linebreaking logic work better for English prose.
  - The game's RAM layout let me create a much more robust English linebreaking solution than what I had to resort to for Otogirisou.

### <ins>Name entry screen</ins>
![](/repo%20images/name%20entry%20grid%20original%20jp.png)
![](/repo%20images/kamaitachi%20english%20name%20entry.gif)

Changing this screen for an English patch was complicated enough to deserve its own section.
- Created decompression/recompression tools for the graphics for the letters in the grid (more details in another section).
- Independently of the graphics, changed the character encodings that get used. This was simple.
- The Japanese game had a scrollable grid of 1160 slots for kanji. This is much too many for English, and I was able to edit the menu logic to prevent accessing it.
- Translated the boxes on the sides, and painstakingly updated the absolute myriad of ways they get drawn to the screen.
- *Most difficult of all*, increased the character limit for names from 6 to 10.
  - I thought that six characters in a name was acceptable for Otogirisou, but not for Kamaitachi.
  - Accommodating this feature required updating lots of the game's code.

### <ins>Graphics</ins>
- Insert translated graphics for the stereo/mono option.
- Translate the 終 graphic that the player sees upon reaching a bad end.
  - Exact translated graphics are not set in stone, but easily editable.
- Restore an unused background graphic and a few unused silhouettes.
  - They were added to the PS1 release but do exist in the SFC version's data, and so I decided to incorporate them into the script.
- Reverse engineer the format for how the [end credits](/notes/end%20credits/NOTES%20end%20credits.txt) are displayed.
  - No major work yet on creating translated graphics for the end credits.
- Translate the screen containing the opening credits (thanks to FCandChill for designing the translated graphic!).

### <ins>Graphics compression formats</ins>
| Data type | Decompressor | Recompressor |
| :--- | :---: | :---: |
| Background graphics tile*sets* | Done | Done, improvable |
| Background graphics tile*maps* | Done | Done |
| Name entry character grid font | Done | Done |
| Silhouette graphics | Done | Done |

As a result of doing all this recompression work, I succeeded at a self-imposed challenge to fit the English translation's data into 3 MB, the same size as the original Japanese game.

#### <ins>Background tilesets</ins>
The tileset compression format was really complicated to figure out from the decompression ASM code. I saved ~4 KB from recompressing the game's data.
- After all the work that went into making the program, I was kind of disappointed with saving "only" 4 KB (for scale, original compressed data is over 1 MB), but I suppose I'll take what I can get.
- The format allows you to load uncompressed graphics data, but the programmer in me took making a recompressor as a challenge.
- Compared to Chunsoft's original compressor, my recompressor produces a smaller data block for all but one of the tilesets present in the game.
  - Depending on whether I set two specific comparisons in the code as `>=` or `>`, the results can be slightly smaller or larger.
- I'd spent too much time on something that I'd initially marked as "nice to have" for the patch, and I wanted to move on from it.

#### <ins>Background tilemaps</ins>
My background tilemap recompressor saves ~2.45 KB across all the tilemaps present in the game.
- I saved 1 KB while staying within the confines of the compression formats (note the plural) in the original Japanese game.
- I saved another 1.45 KB from tweaking one format to better handle certain data patterns, as well as allowing some existing compression cases to compress more data at once for all the formats.

#### <ins>LZSS format</ins>
The font graphics for the grid of characters on the name entry screen, and some other graphics, have their own compression format (it's a flavor of LZSS). I made a recompressor for it and tweaked part of the format.
- The font data block has been replaced with one for English, but recompressing the original Japanese font block would save about 700 bytes.
- With all the game's other LZSS data blocks, I saved over 1.2 KB total.

#### <ins>Silhouette graphics</ins>
No silhouettes contain any text to translate, so I initially thought I wouldn't need to create a graphics recompressor for them. However, I discovered some ways to improve the existing compression, which altogether let me free up ~6.9 KB from recompressing the existing data.

A bonus to figuring out the format was that I was able to fix a silhouette that has an apparent error with the graphics: a 16x8 pixel block missing the silhouette color.

![](/repo%20images/silhouette%20gfx%20error%200x06E.png)

## "Nice to have" items
- Translate the end credits (medium).
- Translate other graphics like the title screen (**difficult**), or another screen that references another Chunsoft game (medium, debatably unnecessary). More details [here](/notes/gfx%20translation/README.md).
