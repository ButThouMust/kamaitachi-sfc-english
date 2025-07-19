# kamaitachi-sfc-english
In case anyone happens upon this repo, I wanted to put at the top that *I do not have a translation patch yet*. For the time being, this will just be a place where I'll do project updates, but I will also eventually put my source code and patches here.

I had created a [translation patch](https://github.com/ButThouMust/otogirisou-english) for the Chunsoft sound novel Otogirisou on Super Famicom. At some point during the creation of that patch, I tried digging around in Chunsoft's next game in the same style, and found enough things in common between their internal workings that I wanted to work on it, too.

Kamaitachi no Yoru (かまいたちの夜) is a murder mystery sound novel that takes place in a ski lodge during a blizzard. If you had to translate the title using only English words, it would be *The Night of the Sickle Weasel*.

Some innovations over Otogirisou:
- background images being mostly digitized photos, and a handful of pixel art
- silhouettes of the cast of characters
- bad endings where the story concludes prematurely
- the ability to start from a previous chapter upon reaching an ending

The game was originally released for the Super Famicom in 1994, and has been ported and remade several times in Japan over the years. Most recently, it and its two sequels on PS2 were remade for PS4/Switch/Steam in 2024 for its 30th anniversary. Two versions have been localized into English:
- an official localization *Banshee's Last Cry* for old 32-bit versions of iOS, with the Japanese setting changed to British Columbia
- a [fan localization patch by Project Kamai](https://web.archive.org/web/20230801045909/https://projectkamai.com/) of the Rinne Saisei remake for PC

I'd done a lot of project updates in [this thread](https://discord.com/channels/266412086291070988/1089409844743782440) in the RHDI Discord server, which you can read if you like.

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
  - I used this to test scripts for viewing unused content.
- Compress an English translated script into the format the game expects.
  - It's currently too big for the space I've carved out for it, so I'm working on moving stuff around to let it fit.
- Insert translated menu prompts for managing files, like "start game", "delete file", "change names", etc.

### <ins>Graphics</ins>
- Insert translated graphics for the stereo/mono option.
- Translate the 終 graphic that the player sees upon reaching a bad end.
  - Exact translated graphics are not set in stone, but easily editable.
- Find graphics for the boxes on the name entry screen.
- Reverse engineer the format for how the end credits are displayed.

### <ins>Graphics compression formats</ins>
| Data type | Decompressor? | Recompressor? |
| :--- | :---: | :---: |
| Background graphics tile*sets* | Done | Not started |
| Background graphics tile*maps* | Done | Mostly done |
| Name entry character grid font | Done | Done |
| Silhouettes | Done | Done |

I do want to at least try working on a compressor for the background tilesets, but the compression format is quite intricate. The decompressor was a pain to get working, having to trace through Chunsoft's ASM code and figure out exactly what the code was doing. However, the code does have a case for loading uncompressed graphics data, so that can work as a stopgap if need be.

My background tilemap recompressor saves a total of ~1 KB across all the tilemaps present in the game. I think it can still be improved, but I'm happy with it.

The font for the grid of characters on the name entry screen, and some other graphics, have their own compression format (it's a flavor of LZSS). My recompressor saves about 700 bytes with the Japanese font data block (moot point, will be replaced with English equivalent), and over 1 KB with all the game's other data sets in that format.

At first, I was expecting to not create a recompressor for the silhouettes' graphics data, because none of them contain any text to translate. However, I discovered some ways to improve the existing compression, which altogether let me free up ~6.9 KB from recompressing the existing data.

## Priorities for the project:
Currently, the main priority is taking my map of what are the purposes for all/most of the data blocks in the ROM, and using it to figure out where and how to move stuff around to dedicate as much space as possible for the script.
- Beyond a few blocks of *outright* existing empty space, there are also *implicit* blocks of empty space that I can free up thanks to making better compressor tools.
- It could be possible to fit the translation into a 3 MB file (same as original) if I move stuff around cleverly.

### <ins>English font</ins>
- Insert a new font for the game. (**simple**)
- Change the available characters you can select on the name entry screen
  - The internal character encoding values (**easy**)
  - The visible graphics (**medium**)

### <ins>English script</ins>
- Fully translate the Japanese script to English. (**medium**)
  - Translation mostly done, but quite a few places are difficult to translate.  More details in the [spoiler folder's readme](spoilers/README.md).
  - If I could, I'd like to reach out to the Project Kamai team and ask for permission to use their translation choices for certain parts.
    - A Wayback Machine snapshot of their website had an email address for contacting them. Perhaps as expected, though, sending a message to it gave me an error that the address doesn't exist anymore.
- Format and insert an English-translated script. (**medium**)
  - The game uses dedicated control codes for writing punctuation, usually with some combination of "wait for player input" and/or "do a line break". Need to format the script dump to prepare for insertion.
  - Determine about how much space the translated script will take.
  - Playtest the script. (**simple, but tedious**)
  - Edit the systems for printing Japanese text to better suit English text. (**unsure, but putting medium for now**)

### <ins>Name entry screen</ins>
#### Change logic for menu
The Japanese game allows entering a name with a combination of kanji, hiragana, or katakana. Each category has 488, 90, and 90 slots in their respective grids of characters. 488 is a bit too many for English, so I've been trying to see if it's possible to make an ASM hack to only allow access to the blocks for hiragana or katakana. (**medium**)

For example:
- Replace hiragana with the standard English alphabet.
- Replace katakana with accented letters and other special characters.
- Dummy out the kanji category, and make the player unable to access or interact with it.

#### Character limit for names
I want to be able to change the name entry screen to support a limit of 10+ characters instead of 6 like in the original (**difficult**).
- The code is used for naming the protagonist and his girlfriend, but also for certain points in the story where the player must enter the name of who they believe to be the killer in the murder mystery. Most characters' names are longer than six letters when translated into English.
- Getting this right is very important, because solving the murder mystery opens up more routes and endings for the player to view.

## "Nice to have" items
- Translate the end credits (medium).
- Create a recompressor for the background graphics' tilesets. (**difficult**)
  - Translate a screen of credits that appears before the title screen.
  - Translate the logo on the title screen.
  - Possibly translate a screen that parodies another Chunsoft game.
