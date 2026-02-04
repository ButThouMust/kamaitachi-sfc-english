# Background GFX translation
TL;DR, graphics to translate are: end credits, opening credits, Kamaitachi title logo, and a graphic that's debatably a funny spoiler (check the spoiler README).

This page will focus on just the graphics that are encoded as background images. The end credits are in a separate format, and I have dedicated notes for them [here](/end%20credits/NOTES%20end%20credits.txt).

Kamaitachi does not have that many graphics to translate, and none of the translatable graphics are strictly necessary for understanding the story, either. However, the reinsertion process will be fairly difficult due to the complicated compression format.

## Opening credits
![](/repo%20images/opening%20credits%20screenshot.png)

When you boot up the game, there is a screen of copyrights after the "Chunsoft Presents" logo. I'd say this is the simplest graphic to translate, and interestingly, there is a reason to translate it.
```
(c) 1994 Chunsoft
(c) 1994 Takemaru Abiko
         Pinpoint
```

## Kamaitachi title screen
![](/repo%20images/title%20screen%20screenshot.png)

This is definitely the most involved and difficult graphic to translate. It has several moving parts and uses two graphics layers: the logo itself, and the background. For context, the title screen has a two-frame "animation" of blood splattering over it before it fades in the title logo. The order goes:
- Fade from black to the title screen background.
- Cut in splatter animation frame 1 (small splatter).
- Cut in splatter animation frame 2 (large splatter).
- Fade colors from frame 2 to the title logo.

From solely a translation point of view, I personally would like to translate the text as "The Night of the Kamaitachi", or "Kamaitachi no Yoru" if the former wouldn't work.

### Title screen background
![](/repo%20images/title%20screen%20background%20basic.png)
![](/repo%20images/title%20screen%20background%20frame%201.png)
![](/repo%20images/title%20screen%20background%20frame%202.png)

The gray background for the title screen has its graphics data arranged so that depending on the palette you apply to it, a pixel will either be:
- red on both frames 1 and 2
- red on just frame 2
- always gray

Red pixels will default to gray if not on the frame where they should be red.

### Title logo
![](/repo%20images/title%20logo%20isolated.png)

One notable thing about the title logo itself is that with the final palette you see after the fade, the Japanese characters have gray borders around them. It looks incomplete in isolation but has the empty spots filled in with the gray background.

![](/repo%20images/title%20screen%20in%20middle%20of%20fade%20to%20logo.png)

And if you're wondering, yes, the shape of the splatter was designed with the Japanese title logo in mind. Some contours of the splatter fit with the logo, which you can see if you take a screenshot in the middle of the fade like above.
