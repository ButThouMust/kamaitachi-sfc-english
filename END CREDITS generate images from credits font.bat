@set srcPath=".\src"

javac %srcPath%\font\*.java
java -classpath %srcPath% font.EndCreditsRendererDriver "./end credits/credits text.txt" "./end credits/creditfont.tbl" "./end credits/creditfont.png" 000000 16 24
pause
