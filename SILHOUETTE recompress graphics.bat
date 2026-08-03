:: turn off printing the full path to current directory
prompt $g

@set srcPath=".\src"

@javac .\src\silhouettes\RecompressSilhouetteGfx.java
java -classpath %srcPath% silhouettes.RecompressSilhouetteGfx
