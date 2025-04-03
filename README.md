# kamaitachi-sfc-english
In case anyone happens upon this repo, I wanted to put at the top that *I do not have a translation patch yet*. This will just be a place where I'll do project updates.

I had created a [translation patch](https://github.com/ButThouMust/otogirisou-english) for the Chunsoft sound novel Otogirisou. At some point during the creation of that patch, I tried digging around in Chunsoft's next game in the same style, and found enough things in common between their internal workings that I wanted to work on it, too.

Kamaitachi no Yoru (かまいたちの夜) is a murder mystery sound novel that takes place in a ski lodge during a blizzard. If you had to translate the title using only English words, it would be *The Night of the Sickle Weasel*.

Some innovations over Otogirisou:
- background images being mostly digitized photos (some pixel art)
- silhouettes of the cast of characters
- bad endings where the story concludes prematurely

The game has been ported and remade several times in Japan over the years. Two versions have been localized into English:
- an official localization *Banshee's Last Cry* for old 32-bit versions of iOS
- a [fan localization patch by Project Kamai](https://web.archive.org/web/20230801045909/https://projectkamai.com/) of the Rinne Saisei remake for PC

I'd done a lot of project updates in [this thread](https://discord.com/channels/266412086291070988/1089409844743782440) in the RHDI Discord server, which you can read if you like.

## Solved items
### <ins>Text</ins>
- Dump the Japanese font.
- Dump the compressed Japanese script.
- Reinsert modified versions of the Japanese script into the game.
  - I used this to test scripts for viewing unused content.
- Insert translated menu prompts for managing files, like "start game", "delete file", "change names", etc.

### <ins>Graphics</ins>
- Insert translated graphics for the stereo/mono option.
- Translate the 終 graphic that the player sees upon reaching a bad end.
  - Exact translated graphics are not set in stone, but easily editable.
- Find graphics for the boxes on the name entry screen.

### <ins>Graphics compression formats</ins>
| Data type | Decompressor? | Recompressor? |
| :--- | :---: | :---: |
| Background graphics tile*sets* | Done | Not started\* |
| Background graphics tile*maps* | Done | Done |
| Name entry character grid font | Done | Done |
| Silhouette data | Done | Not planned\*\* |

\*: I do want to at least try working on this, but the compression format is quite intricate. Even just the decompressor, with Chunsoft's ASM code to follow as an example, was a pain to get working.

\*\*: No silhouettes contain any text.

## Priorities, with relative difficulties:
### <ins>English font</ins>
- Insert a new font for the game. (**simple**)
- Change the available characters you can select on the name entry screen
  - The internal character encoding values (**easy**)
  - The visible graphics (**medium**)

### <ins>English script</ins>
- Fully translate the Japanese script to English. (**medium**)
  - Translation mostly done, but quite a few places are difficult to translate.  More details in the [spoiler folder's readme](spoilers/README.md).
  - I was considering trying find a way to reach out to the Project Kamai team (sadly, their website has gone down, but is in the Wayback Machine) and asking for their permission to use their translation choices for certain parts.
- Format and insert an English-translated script. (**medium**)
  - The game uses dedicated control codes for writing punctuation, usually with some combination of "wait for player input" and/or "do a line break". Need to format the script dump to prepare for insertion.
  - Playtest the script. (**simple, but tedious**)
  - Edit the systems for printing Japanese text to better suit English text. (**unsure, but putting medium for now**)

### <ins>Name entry screen</ins>
#### Change logic for menu
The Japanese game allows entering a name with a combination of kanji, hiragana, or katakana. Each category has, respectively, 488, 90, and 90 slots in their grid of characters. 488 is a bit too many for English, so I've been trying to see if it's possible to make an ASM hack to only allow access to the blocks for hiragana or katakana. (**medium**)

For example:
- Replace hiragana with the standard English alphabet.
- Replace katakana with accented letters and other special characters.
- Dummy out the kanji category, and make the player unable to access or interact with it.

#### Character limit for names

I want to be able to change the name entry screen to support a limit of 10+ characters instead of 6 like in the original (**difficult**).
- The code is used for naming the protagonist and his girlfriend, but also for certain points in the story where the player must enter the name of who they believe to be the killer in the murder mystery. The six letter limit is too short for English.
- Getting this right is very important, because solving the murder mystery opens up more routes and endings for the player to view.

## "Nice to have" items, with relative difficulties:
- Translate the end credits (medium).
- Create a recompressor for the background graphics' tilesets. (**difficult**)
  - Translate a screen of credits that appears before the title screen.
  - Translate the logo on the title screen.
  - Possibly translate a screen that parodies another Chunsoft game.
