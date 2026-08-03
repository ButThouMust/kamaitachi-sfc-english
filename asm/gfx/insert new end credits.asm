includefrom "asm/MAIN recompress repoint graphics.asm"

; -------------------------------------------------------------------------------

; if you see strange behavior where one or two tiles are blanked out on the left
; part of a credit, make sure that your widths are consistent with the image you
; feed to your tilemap extraction program

; the data extends to the end of bank $5E

!EmptyLineID = $00
!SkipThreeLinesDownID = $80
!EndOfLineIdList = $FF

; see "insert new char grid, repoint sfx and bg gfx.asm" for how label gets set
org NewEndCreditsLineIDs
; scenario
    db $01,$02  
    db !SkipThreeLinesDownID,!SkipThreeLinesDownID

; graphics
    db $03,$04,$05,$06,$07,$08,$09
    db !SkipThreeLinesDownID

; music programmer
    db $0a,$0b
    db !SkipThreeLinesDownID

; composer
    db $0c,$0d,$0e
    db !SkipThreeLinesDownID

; development co. and programming director
    db $0f,$10,$11,$12
    db !SkipThreeLinesDownID

; programmer
    db $13,$14,$15,$16,$17,$18
    db !SkipThreeLinesDownID

; assistant
    db $19,$1a,$1b,$1c
    db !SkipThreeLinesDownID

; photography
    db $1d,$1e
    db !SkipThreeLinesDownID

; photography support; JP used 4 lines for this, I only need three, but need to
; keep the # of lines consistent for timing purposes
    db $1f,$20,$21,!EmptyLineID
    db !SkipThreeLinesDownID

; sound effects; 3 in JP, 2 here
    db $22,$23,!EmptyLineID
    db !SkipThreeLinesDownID

; scale models; 3 in JP, 2 here
    db $24,$25,!EmptyLineID
    db !SkipThreeLinesDownID

; support; 3 in JP, 2 here
    db $26,$27,!EmptyLineID
    db !SkipThreeLinesDownID

; assistant producer
    db $28,$29
    db !SkipThreeLinesDownID

; producer
    db $2a,$2b
    db !SkipThreeLinesDownID

; director
    db $2c,$2d
    db !SkipThreeLinesDownID

; produced/copyright by chunsoft
    db $2e,$2f
    db !EndOfLineIdList

; -------------------------------------------------------------------------------

; see the next section; this requires relative offsets from the start of the
; data block of graphics block IDs
NewListOfOffsetsToBlockIds:
    dw -NewListsOfBlockIds+EmptyLineBlockIds

    dw -NewListsOfBlockIds+ScenarioBlockIds
    dw -NewListsOfBlockIds+AbikoBlockIds

    dw -NewListsOfBlockIds+GraphicsBlockIds
    dw -NewListsOfBlockIds+KoizumiBlockIds
    dw -NewListsOfBlockIds+OchiaiBlockIds
    dw -NewListsOfBlockIds+SasakiBlockIds
    dw -NewListsOfBlockIds+SatouBlockIds
    dw -NewListsOfBlockIds+HasegawaBlockIds
    dw -NewListsOfBlockIds+HaradaBlockIds

    dw -NewListsOfBlockIds+MusicProgrammerBlockIds
    dw -NewListsOfBlockIds+MitsumataBlockIds

    dw -NewListsOfBlockIds+ComposerBlockIds
    dw -NewListsOfBlockIds+KatouBlockIds
    dw -NewListsOfBlockIds+NakashimaBlockIds

    dw -NewListsOfBlockIds+DevelopmentCoBlockIds
    dw -NewListsOfBlockIds+AquamarineBlockIds
    dw -NewListsOfBlockIds+ProgrammingDirectorBlockIds
    dw -NewListsOfBlockIds+MasayoshiSaitouBlockIds

    dw -NewListsOfBlockIds+ProgrammerBlockIds
    dw -NewListsOfBlockIds+NiiBlockIds
    dw -NewListsOfBlockIds+YamadaBlockIds
    dw -NewListsOfBlockIds+OgawaBlockIds
    dw -NewListsOfBlockIds+NakajimaBlockIds
    dw -NewListsOfBlockIds+OhmoritaBlockIds

    dw -NewListsOfBlockIds+AssistantBlockIds
    dw -NewListsOfBlockIds+HitomiSaitouBlockIds
    dw -NewListsOfBlockIds+KurodaBlockIds
    dw -NewListsOfBlockIds+ShionoBlockIds

    dw -NewListsOfBlockIds+PhotographyBlockIds
    dw -NewListsOfBlockIds+YamauraBlockIds

    dw -NewListsOfBlockIds+PhotographySupportBlockIds
    dw -NewListsOfBlockIds+PensionKnulpBlockIds
    dw -NewListsOfBlockIds+HakubaNaganoBlockIds

    dw -NewListsOfBlockIds+SoundEffectsBlockIds
    dw -NewListsOfBlockIds+MagicalBlockIds

    dw -NewListsOfBlockIds+ScaleModelsBlockIds
    dw -NewListsOfBlockIds+LuckyWideBlockIds

    dw -NewListsOfBlockIds+SupportBlockIds
    dw -NewListsOfBlockIds+PinpointBlockIds

    dw -NewListsOfBlockIds+AssistantProducerBlockIds
    dw -NewListsOfBlockIds+NakanishiBlockIds

    dw -NewListsOfBlockIds+ProducerBlockIds
    dw -NewListsOfBlockIds+NakamuraBlockIds

    dw -NewListsOfBlockIds+DirectorBlockIds
    dw -NewListsOfBlockIds+AsanoBlockIds

    dw -NewListsOfBlockIds+ProduceCopyrightBlockIds
    dw -NewListsOfBlockIds+ChunsoftBlockIds

; ------------------------------------------------------------------------------

NewListsOfBlockIds:

; you can just do a "db $ff" here if you want, but making an explicit line for
; this helped with assigning 00 to empty graphics blocks for tilemap generation
EmptyLineBlockIds:
    incbin "end credits/tile id lists/01 empty block ID list.bin"

ScenarioBlockIds:
    incbin "end credits/tile id lists/02 scenario block ID list.bin"
AbikoBlockIds:
    incbin "end credits/tile id lists/03 takemaru abiko block ID list.bin"

GraphicsBlockIds:
    incbin "end credits/tile id lists/04 graphics block ID list.bin"
KoizumiBlockIds:
    incbin "end credits/tile id lists/05 fuyuhiko koizumi block ID list.bin"
OchiaiBlockIds:
    incbin "end credits/tile id lists/06 shinya ochiai block ID list.bin"
SasakiBlockIds:
    incbin "end credits/tile id lists/07 shinji sasaki block ID list.bin"
SatouBlockIds:
    incbin "end credits/tile id lists/08 keiko satou block ID list.bin"
HasegawaBlockIds:
    incbin "end credits/tile id lists/09 kaoru hasegawa block ID list.bin"
HaradaBlockIds:
    incbin "end credits/tile id lists/10 kumiko harada block ID list.bin"

MusicProgrammerBlockIds:
    incbin "end credits/tile id lists/11 music programmer block ID list.bin"
MitsumataBlockIds:
    incbin "end credits/tile id lists/12 chiyoko mitsumata block ID list.bin"

ComposerBlockIds:
    incbin "end credits/tile id lists/13 composer block ID list.bin"
KatouBlockIds:
    incbin "end credits/tile id lists/14 kouta katou block ID list.bin"
NakashimaBlockIds:
    incbin "end credits/tile id lists/15 koujirou nakashima block ID list.bin"

DevelopmentCoBlockIds:
    incbin "end credits/tile id lists/16 development co block ID list.bin"
AquamarineBlockIds:
    incbin "end credits/tile id lists/17 aquamarine co ltd block ID list.bin"
ProgrammingDirectorBlockIds:
    incbin "end credits/tile id lists/18 programming director block ID list.bin"
MasayoshiSaitouBlockIds:
    incbin "end credits/tile id lists/19 masayoshi saitou block ID list.bin"

ProgrammerBlockIds:
    incbin "end credits/tile id lists/20 programmer block ID list.bin"
NiiBlockIds:
    incbin "end credits/tile id lists/21 masahiro nii block ID list.bin"
YamadaBlockIds:
    incbin "end credits/tile id lists/22 nobuhiro yamada block ID list.bin"
OgawaBlockIds:
    incbin "end credits/tile id lists/23 kazumi ogawa block ID list.bin"
NakajimaBlockIds:
    incbin "end credits/tile id lists/24 yasuo nakajima block ID list.bin"
OhmoritaBlockIds:
    incbin "end credits/tile id lists/25 fukashi ohmorita block ID list.bin"

AssistantBlockIds:
    incbin "end credits/tile id lists/26 assistant block ID list.bin"
HitomiSaitouBlockIds:
    incbin "end credits/tile id lists/27 hitomi saitou block ID list.bin"
KurodaBlockIds:
    incbin "end credits/tile id lists/28 tsuyoshi kuroda block ID list.bin"
ShionoBlockIds:
    incbin "end credits/tile id lists/29 katsuhiko shiono block ID list.bin"

PhotographyBlockIds:
    incbin "end credits/tile id lists/30 photography block ID list.bin"
YamauraBlockIds:
    incbin "end credits/tile id lists/31 shouichirou yamaura block ID list.bin"

PhotographySupportBlockIds:
    incbin "end credits/tile id lists/32 photography support block ID list.bin"
PensionKnulpBlockIds:
    incbin "end credits/tile id lists/33 pension knulp block ID list.bin"
HakubaNaganoBlockIds:
    incbin "end credits/tile id lists/34 hakuba nagano block ID list.bin"

SoundEffectsBlockIds:
    incbin "end credits/tile id lists/35 sound effects block ID list.bin"
MagicalBlockIds:
    incbin "end credits/tile id lists/36 magical co ltd block ID list.bin"

ScaleModelsBlockIds:
    incbin "end credits/tile id lists/37 scale models block ID list.bin"
LuckyWideBlockIds:
    incbin "end credits/tile id lists/38 lucky wide co ltd block ID list.bin"

SupportBlockIds:
    incbin "end credits/tile id lists/39 support block ID list.bin"
PinpointBlockIds:
    incbin "end credits/tile id lists/40 pinpoint co ltd block ID list.bin"

AssistantProducerBlockIds:
    incbin "end credits/tile id lists/41 assistant producer block ID list.bin"
NakanishiBlockIds:
    incbin "end credits/tile id lists/42 kazuhiko nakanishi block ID list.bin"

ProducerBlockIds:
    incbin "end credits/tile id lists/43 producer block ID list.bin"
NakamuraBlockIds:
    incbin "end credits/tile id lists/44 kouichi nakamura block ID list.bin"

DirectorBlockIds:
    incbin "end credits/tile id lists/45 director block ID list.bin"
AsanoBlockIds:
    incbin "end credits/tile id lists/46 kazuya asano block ID list.bin"

ProduceCopyrightBlockIds:
; shift this 32 pixels right to get it centered on screen
    db $00,$00,$00,$00
    incbin "end credits/tile id lists/47 produced (c) by block ID list.bin"
ChunsoftBlockIds:
    incbin "end credits/tile id lists/48 chunsoft co ltd block ID list.bin"

; ------------------------------------------------------------------------------

NewCreditsGraphicsData:
; leave out the block of all 00s
    incbin "end credits/TILESET test credits 16x24.bin":$30..0

; ------------------------------------------------------------------------------

; print hex(NewEndCreditsLineIDs),": end credits line ID table"
; print hex(NewListOfOffsetsToBlockIds),": end credits block ID offsets"
; print hex(NewListsOfBlockIds),": end credits block ID lists"
; print hex(NewCreditsGraphicsData),": end credits graphics data"
