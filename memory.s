                include defines.s
                include macros.s

        ; Zeropage variables

                varbase $02

                var loadTempReg                 ;Loader variables
                var loadBufferPos
                var fileOpen

                var zpLenLo                     ;Exomizer 2 depackroutine variables
                var zpSrcLo
                var zpSrcHi
                var zpDestLo
                var zpDestHi
                var zpBitsLo
                var zpBitsHi
                var zpBitBuf

                var xLo                         ;Actor render / spawn coordinates
                var yLo
                var xHi
                var yHi

                var cacheFrame                  ;Sprite render variables
                var sprFrameNum
                var numSpr
                var numBounds
                var actColorAnd
                var actColorOr
                var actYMSB

                var actIndex                    ;Actor variables
                var actLo
                var actHi
                var currFlags
                var wpnLo
                var wpnHi
                var wpnFlags

                var loadRes                     ;Current resource file for load
                var freeMemLo                   ;Memory allocator variables
                var freeMemHi
                var musicDataLo
                var musicDataHi
                var zoneBufferLo
                var zoneBufferHi

                var lastNavArea                 ;Misc game vars
                var nextLvlActIndex

                varrange actXH,MAX_ACT          ;Actor ZP variables
                varrange actYH,MAX_ACT
                varrange actSX,MAX_ACT
                varrange actSY,MAX_ACT
                varrange actF1,MAX_ACT

                checkvarbase $90

                varbase $a6

                var joystick                    ;Input variables
                var prevJoy
                var keyType

                var scrollX                     ;Screen / level variables
                var scrollY
                var scrollSX
                var scrollSY
                var scrCounter
                var blockX
                var blockY
                var mapX
                var mapY
                var mapSizeX
                var mapSizeY
                var levelNum
                var zoneNum

                checkvarbase $b6

                varbase $c0

                varrange sprOrder,MAX_SPR+1

                var atObj                       ;Levelobject variables
                var usableObj
                var autoDeactObj
                var animObj
                var animObjFrame
                var animObjTarget

                var textTime                    ;Text printing variables
                var textLeftMargin
                var textRightMargin
                var textLo
                var textHi

                var irqSaveA                    ;IRQ variables
                var irqSaveX
                var irqSaveY
                var frameNumber
                var firstSortSpr
                var newFrameFlag
                var drawScreenFlag
                var dsBlockX
                var dsBlockY
                var dsStartX

                var pattPtrLo                   ;Playroutine
                var pattPtrHi
                var trackPtrLo
                var trackPtrHi
                var masterVol
                var sfxTemp

                checkvarbase $100

textCursor      = loadBufferPos                 ;Reused during text printing (should never load mid-line!)

dataSizeLo      = xHi                           ;Reused during resource load
dataSizeHi      = yHi

complexSprCount = xHi                           ;Reused during actor render
complexSprTemp  = yHi
oldSprLo        = wpnLo
oldSprHi        = wpnHi
oldSprHeaderLo  = loadTempReg
oldSprHeaderHi  = loadBufferPos
cacheAdr        = wpnLo
sliceMask       = wpnHi

currFireCtrl    = xLo                           ;Reused during actor move / attack
currCtrl        = yLo
edgeCtrl        = xHi
moveSpeed       = yHi
sideOffset      = zpBitsLo
topOffset       = zpBitsHi
slopeX          = zpBitBuf
saveActIndex    = actColorAnd
saveHp          = actColorOr

blockCtrl       = xHi                           ;Reused during attack
aimDir          = zpBitsLo
bulletDir       = zpBitsHi
wpnFlagsDisp    = loadBufferPos

bounceBrake     = yLo                           ;Reused during bounce physics
bouncePrevX     = xHi
bouncePrevY     = yHi

signXDist       = xLo                           ;Reused during AI
absXDist        = xHi
signYDist       = yLo
absYDist        = yHi
targetX         = zpSrcLo
targetY         = zpSrcHi
srcNavArea      = zpDestLo
currentDist     = zpDestHi
bestDist        = zpBitsLo
bestArea        = zpBitsHi
aggression      = zpLenLo

bboxTop         = zpBitsLo                      ;AI firing dir check
bboxBottom      = zpBitsHi
wpnHeight       = zpBitBuf

lineX           = xLo                           ;Reused during linecheck
lineY           = yLo
lineYCopy       = xHi
lineSlope       = yHi
lineCount       = zpBitsLo

mapPtrLo        = xLo                           ;Zone init
mapPtrHi        = yLo

aoEndFrame      = xLo                           ;Object animation
aoTemp          = yLo

promptIndex     = xLo                           ;Interaction prompts
promptType      = yLo

        ; Memory areas and non-zeropage variables

depackBuffer    = $0100
loadBuffer      = $0200

exomizerCodeStart = $0334

scriptCodeRelocStart = $8000
videoBank       = $c000
fileAreaEnd     = $d000
spriteCache     = $d000
colors          = $d800
panelScreen     = $e000
panelChars      = $e000
blkTL           = $e400
blkTR           = $e500
blkBL           = $e600
blkBR           = $e700
chars           = $e800
blkInfo         = $f000
blkColors       = $f100
charAnimCode    = $f180
lvlObjAnimFrames = $f200
miscVarArea1    = $f240
screen          = $f800
emptySprite     = $fc00
miscVarArea2    = $fc40

                varbase panelScreen+24*40
                varrange boundsAct,MAX_BOUNDS
                varrange sprAct,MAX_SPR
                checkvarbase panelScreen+1016

                varbase screen+SCROLLROWS*40
                varrange sprX,MAX_SPR
                varrange sprY,MAX_SPR
                varrange sprF,MAX_SPR
                varrange sprC,MAX_SPR
                checkvarbase screen+1016

                varbase miscVarArea1

        ; Level objects

                varrange lvlObjX,MAX_LVLOBJ
                varrange lvlObjY,MAX_LVLOBJ
                varrange lvlObjZ,MAX_LVLOBJ
                varrange lvlObjFlags,MAX_LVLOBJ
                varrange lvlObjSize,MAX_LVLOBJ
                varrange lvlObjFrame,MAX_LVLOBJ
                varrange lvlObjDL,MAX_LVLOBJ
                varrange lvlObjDH,MAX_LVLOBJ

        ; Leveldata actors

                varrange lvlActX,MAX_LVLACT
                varrange lvlActY,MAX_LVLACT
                varrange lvlActZ,MAX_LVLACT
                varrange lvlActT,MAX_LVLACT
                varrange lvlActWpn,MAX_LVLACT
                varrange lvlActOrg,MAX_LVLACT

        ; Maprowtable

                varrange mapTblLo,MAX_MAPROWS
                varrange mapTblHi,MAX_MAPROWS

                checkvarbase screen

                varbase screen+SCROLLROWS*40
                varrange sprX,MAX_SPR
                varrange sprY,MAX_SPR
                varrange sprF,MAX_SPR
                varrange sprC,MAX_SPR
                checkvarbase screen+1016

                varbase miscVarArea2

        ; Sprite caching & resources

                varrange fileNumObjects,MAX_CHUNKFILES
                varrange cacheSprAge,MAX_CACHESPRITES
                varrange cacheSprFrame,MAX_CACHESPRITES
                varrange cacheSprFile,MAX_CACHESPRITES
                varrange fileLo,MAX_CHUNKFILES
                varrange fileHi,MAX_CHUNKFILES
                varrange fileAge,MAX_CHUNKFILES

        ; Actor bounds

                varrange boundsL,MAX_BOUNDS
                varrange boundsR,MAX_BOUNDS
                varrange boundsU,MAX_BOUNDS
                varrange boundsD,MAX_BOUNDS

        ; Navareas

                varrange navAreaType,MAX_NAVAREAS
                varrange navAreaL,MAX_NAVAREAS
                varrange navAreaR,MAX_NAVAREAS
                varrange navAreaU,MAX_NAVAREAS
                varrange navAreaD,MAX_NAVAREAS

                checkvarbase $fffa