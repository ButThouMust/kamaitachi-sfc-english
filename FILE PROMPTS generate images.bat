:: I have no qualms about putting the patch's binary graphics data for the file
:: prompts into the repo because they are not sourced from the JP game.
:: If people want to make their own graphics for this, here you go.
:: THIS BATCH FILE HAS NOT BEEN TESTED!

:: Important note: I had to shoehorn in a font table file with a space character
:: because I had used to define it in the font table file, but not any more.

prompt $g

@set srcPath=".\src"

javac %srcPath%\font\*.java
java -classpath %srcPath% font.FontRendererDriver "./file prompts data/lines of text.txt" "./file prompts data/kamaitachi font dimensions - for file prompts.tbl" "./file prompts data/kamaitachi font.png" 000000 16 16
pause
