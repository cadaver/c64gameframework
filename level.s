OBJ_ZONEHEADERS = 0
OBJ_ZONEDATA    = 1

ZONEHEADERSIZE  = 9

ZONEH_SIZEX     = 0
ZONEH_SIZEY     = 1
ZONEH_BG1       = 2
ZONEH_BG2       = 3
ZONEH_BG3       = 4
ZONEH_LASTNAVAREA = 5
ZONEH_CHARSET   = 6
ZONEH_MAPOFFSETLO = 7
ZONEH_MAPOFFSETHI = 8

SCREENSIZEX     = 19
SCREENSIZEY     = 11

OBJ_MODEBITS    = $03
OBJ_TYPEBITS    = $1c
OBJ_AUTODEACT   = $40
OBJ_ACTIVE      = $80

OBJMODE_NONE    = $00
OBJMODE_TRIG    = $01
OBJMODE_MAN     = $02
OBJMODE_MANAD   = $03

OBJTYPE_SIDEDOOR = $00
OBJTYPE_DOOR    = $04
OBJTYPE_LOCKER  = $08
OBJTYPE_COVER   = $0c
OBJTYPE_SWITCH  = $10                       ;Executes script
OBJTYPE_SWITCHCUSTOM = $14                  ;Executes script, custom interaction prompt at entrypoint+1
OBJTYPE_UNUSED1 = $18
OBJTYPE_UNUSED2 = $1c

OBJANIM_DELAY   = 1
AUTODEACT_DELAY = 10

NO_OBJECT       = $ff
NO_SCRIPT       = $ff
NO_LEVEL        = $ff

MINSEQ          = 3
MAXSEQ          = 24
RANGE           = MAXSEQ
ESCAPE          = (256-(2*RANGE))

        ; Get address of save var
        ;
        ; Parameters: X var index
        ; Returns: zpSrcLo,Hi address, Y=0
        ; Modifies: A,Y

GetSaveMiscVar: lda saveMiscVarLo,x
                sta zpSrcLo
                lda saveMiscVarHi,x
                sta zpSrcHi
                ldy #$00
                rts
                
        ; Store state of current level + global actors to savestate
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,temp vars

SaveLevelState: ldy levelNum                    ;When loading game, can be in a "no level" state
                bmi SLS_NoLevel                 ;and then we shouldn't save
                jsr SLS_GetBitOffsetAndClear
                ldy #MAX_SAVEACT                ;Clear actor save table (A=0 here)
SLS_ClearSaveLoop:
                sta saveLvlActT-1,y
                dey
                bne SLS_ClearSaveLoop           ;Y=0 (save table index)
                ldx #MAX_LVLACT-1
SLS_SaveActorLoop:
                lda lvlActT,x                   ;Save actors
                beq SLS_SaveActorNext
                lda lvlActOrg,x
                bpl SLS_SaveActorGlobal
SLS_SaveActorLevelData:
                and #$7f
                sty zpDestLo                    ;Preserve Y (save table index)
                jsr SLS_SetBit
                ldy zpDestLo
                bpl SLS_SaveActorNext
SLS_SaveActorGlobal:
                asl
                bpl SLS_SaveActorNext
                jsr SLS_StoreActor
SLS_SaveActorNext:
                dex
                bpl SLS_SaveActorLoop
                ldx nextLvlActIndex
SLS_SaveItemsLoop:
                cpy #MAX_SAVEACT                ;Then save as many temp items (weapons etc.)
                bcs SLS_SaveItemsDone           ;as possible, from the latest stored
                lda lvlActT,x
                bpl SLS_SaveItemsNext
                lda lvlActOrg,x
                cmp #ORG_GLOBAL
                bcs SLS_SaveItemsNext
                jsr SLS_StoreActor
SLS_SaveItemsNext:
                inx
                cpx #MAX_LVLACT
                bcc SLS_SaveItemsNotOver
                ldx #$00
SLS_SaveItemsNotOver:
                cpx nextLvlActIndex             ;Exit when wrapped
                bne SLS_SaveItemsLoop
SLS_SaveItemsDone:
                lda levelNum
                adc #NUMLEVELS                  ;C=1, add one more
                tay
                jsr SLS_GetBitOffsetAndClear
                tax
                stx zpDestLo                    ;Persistent object index
SLS_ObjLoop:    lda lvlObjFlags,x
                asl                             ;Active bit to carry
                bmi SLS_ObjSkip                 ;If autodeactivating (bit 6), is not persistent
                bcc SLS_ObjSkip2
                lda zpDestLo
                jsr SLS_SetBit
SLS_ObjSkip2:   inc zpDestLo                    ;Increment persistent index
SLS_ObjSkip:    inx
                cpx #MAX_LVLOBJ
                bcc SLS_ObjLoop
SLS_NoLevel:    rts

SLS_GetBitOffsetAndClear:
                lda lvlActBitStart+1,y
                sta zpSrcHi
                lda lvlActBitStart,y
                sta zpSrcLo
                tay
                lda #$00
SLS_ClearBitsLoop:
                cpy zpSrcHi                     ;Clear first. Level may also have no actors
                bcs SLS_ClearBitsDone
                sta saveBits,y
                iny
                bne SLS_ClearBitsLoop
SLS_ClearBitsDone:
                rts

SLS_SetBit:     jsr DecodeBitOfs
                ora saveBits,y
                sta saveBits,y
                rts

SLS_StoreActor: lda lvlActX,x
                sta saveLvlActX,y
                lda lvlActY,x
                sta saveLvlActY,y
                lda lvlActZ,x
                sta saveLvlActZ,y
                lda lvlActT,x
                sta saveLvlActT,y
                lda lvlActWpn,x
                sta saveLvlActWpn,y
                lda lvlActOrg,x
                sta saveLvlActOrg,y
                iny
CL_SameLevel:   rts

        ; Prepare for level / zone change. Load new level, actors & levelobjects.
        ; To be called even if the level is same, for proper actor removal & screen blanking
        ;
        ; Parameters: A new level
        ; Returns: -
        ; Modifies: A,X,Y,loader temp vars, temp vars

ChangeLevel:    sta loadTempReg
                cmp levelNum
                php
                jsr BlankScreen
                ldy autoDeactObj                ;If autodeactivating an object in the old zone, finish now
                bmi CL_NoAutoDeact
                jsr DeactivateObject
CL_NoAutoDeact: jsr RemoveLevelActors
                jsr SaveLevelState
                plp
                beq CL_SameLevel
                lda loadTempReg
                sta levelNum
                ldx #F_LEVEL
                jsr MakeFileName
                lda musicDataLo                 ;Forget zone buffer now to allow maximum memory area while
                sta zoneBufferLo                ;loading
                lda musicDataHi
                sta zoneBufferHi
                ldy #C_LEVEL
                sty loadRes
                jsr PurgeFile                   ;Remove the old level
                jsr LF_CustomFileName           ;This part will be automatically retried on error
                lda #<lvlObjX                   ;After the map data, load the object / actor definitions (compressed normally)
                ldx #>lvlObjX
                jsr LoadFile
                ldy levelNum
                lda lvlActBitStart,y
                sta zpSrcLo
                ldx #MAX_LVLACT-1
CL_InitLevelActors:
                lda lvlActT,x
                beq CL_SkipLevelActor
                txa
                jsr DecodeBitOfs
                and saveBits,y                  ;Check if actor still exists
                beq CL_RemoveLevelActor
                txa
                ora #$80
                sta lvlActOrg,x                 ;Store the leveldata persistence ID
                bmi CL_SkipLevelActor
CL_RemoveLevelActor:
                sta lvlActT,x
CL_SkipLevelActor:
                dex
                bpl CL_InitLevelActors
                ldy levelNum
                lda lvlObjBitStart,y
                sta zpSrcLo
                ldx #$00
                stx zpDestLo
CL_InitLevelObjects:
                lda lvlObjFlags,x               ;Set persistent objects active according to saved bits
                asl
                bmi CL_SkipLevelObject          ;If autodeactivating, not persistent
                lda zpDestLo
                jsr DecodeBitOfs
                and saveBits,y
                beq CL_SkipLevelObject2
                lda lvlObjFlags,x
                ora #OBJ_ACTIVE
                sta lvlObjFlags,x
CL_SkipLevelObject2:
                inc zpDestLo
CL_SkipLevelObject:
                inx
                cpx #MAX_LVLOBJ
                bcc CL_InitLevelObjects
                ldx #$00
CL_RestoreSavedActors:
                jsr GetLevelActorIndex
                lda saveLvlActT,x
                beq CL_SavedActorsDone
                sta lvlActT,y
                lda saveLvlActX,x
                sta lvlActX,y
                lda saveLvlActY,x
                sta lvlActY,y
                lda saveLvlActZ,x
                sta lvlActZ,y
                lda saveLvlActWpn,x
                sta lvlActWpn,y
                lda saveLvlActOrg,x
                sta lvlActOrg,y
                inx
                bne CL_RestoreSavedActors
CL_SavedActorsDone:
                rts

        ; Change zone. Depack zone map & load charset
        ;
        ; Parameters: A new zone
        ; Returns: -
        ; Modifies: A,X,Y,loader temp vars,temp vars

ChangeZone:     sta zoneNum
                ldy #ZONEHEADERSIZE
                ldx #<zpBitsLo
                jsr MulU                        ;Calculate zone header start offset
                lda #OBJ_ZONEHEADERS            ;Get the zone headers baseaddress
                jsr GetLevelResourceObject
                ldy #<zpSrcLo
                jsr Add16                       ;Add baseaddress to get zone ptr
                ldy #ZONEHEADERSIZE-1
CZ_CopyZoneHeader:
                lda (zpBitsLo),y                ;Copy all zone header vars to zeropage
                sta mapSizeX,y
                dey
                bpl CZ_CopyZoneHeader
                lda zoneCharset
CZ_LoadedCharset:
                cmp #$ff
                beq CZ_SameCharset
                sta CZ_LoadedCharset+1
                ldx #F_CHARSET
                jsr MakeFileName
                lda #<blkTL
                ldx #>blkTL
                jsr LoadFile
CZ_SameCharset:
                ldy #MAX_LVLOBJ-1               ;Find levelobjects in zone
                ldx #$00
                stx actNavArea+ACTI_PLAYER      ;Reset player's navarea to make sure is not referring to an illegal one
CZ_FindLevelObjects:
                lda lvlObjZ,y
                cmp zoneNum
                bne CZ_FLONext
                tya
                sta zoneLvlObjList,x
                inx
CZ_FLONext:     dey
                bpl CZ_FindLevelObjects
                lda #NO_OBJECT
                sta zoneLvlObjList,x            ;Endmark
                lda mapSizeX
                sec
                sbc #SCREENSIZEX
                sta SL_MapXLimit+1              ;Calculate limits for scrolling
                sta UF_MapXLimit+1
                lda mapSizeY
                tay
                sbc #SCREENSIZEY                ;C=1
                sta SL_MapYLimit+1
                sta UF_MapYLimit+1
                iny                             ;Map data must be an even amount of rows + one extra for shake effect
                tya
                lsr
                bcc CZ_EvenSize
                iny
CZ_EvenSize:    lda mapSizeX
                ldx #<zoneBufferLo
                jsr MulU
                lda musicDataLo                 ;Calculate zone mapdata start
                sec
                sbc zoneBufferLo
                sta zoneBufferLo
                lda musicDataHi
                sbc zoneBufferHi
                sta zoneBufferHi
                jsr PurgeUntilFreeNoNew         ;Purge files until there's room for the zone mapdata
                lda zoneBufferLo
                sta zpSrcLo
                lda zoneBufferHi
                sta zpSrcHi
                clc
                ldy #$00
                ldx #<zpSrcLo
CZ_MapRowLoop:  lda zpSrcLo
                sta mapTblLo,y
                adc #$01
                sta mapTblLo+1,y
                lda zpSrcHi
                sta mapTblHi,y
                adc #$00
                sta mapTblHi+1,y
                jsr GetNext2MapRows
                iny
                iny
                cpy #MAX_MAPROWS                ;For simplicity, always input the whole maprowtable
                bcc CZ_MapRowLoop
                lda #OBJ_ZONEDATA               ;Get the zone packed datas baseaddress
                jsr GetLevelResourceObject
                ldx #<zpSrcLo                   ;zpSrcLo,Hi = current zone's packed data start
                ldy #<zoneDataOffsetLo
                jsr Add16
                ldy #$00                        ;Src.index
                sty yLo                         ;Row number
                sty CZ_SequenceSta+1
                jsr CZ_NextRow
CZ_DepackZone:  lda (zpSrcLo),y
                iny
                bne CZ_InputNoMSB
                inc zpSrcHi
CZ_InputNoMSB:  cmp #ESCAPE
                bcc CZ_Literal
                beq CZ_DepackDone
                cmp #ESCAPE+2
                sta zpLenLo
                lda (zpSrcLo),y
                iny
                bne CZ_InputNoMSB2
                inc zpSrcHi
CZ_InputNoMSB2: bcs CZ_SequenceOrRLE            ;Escaped literal or actual sequence?
CZ_Literal:     jsr CZ_OutputByte
                bne CZ_DepackZone
CZ_SequenceOrRLE:
                pha                             ;Offset or literal byte to repeat
                lda zpLenLo
                sbc #ESCAPE                     ;C=1
                sta zpLenLo                     ;Length of RLE
                sbc #RANGE
                bcc CZ_SkipLength
                sta zpLenLo                     ;Length of sequence
CZ_SkipLength:  pla
                bcc CZ_UseRLE                   ;Store first RLE byte
                eor #$ff                        ;Add current pos to get ringbuffer offset
                adc CZ_SequenceSta+1            ;Is stored negative to get slightly better Exomizer compression
                sec
                sta CZ_SequenceLda+1
CZ_SequenceLoop:bcc CZ_UseRLE
CZ_SequenceLda: lda screen
                inc CZ_SequenceLda+1
CZ_UseRLE:      jsr CZ_OutputByte
                dec zpLenLo
                bpl CZ_SequenceLoop
                bmi CZ_DepackZone
CZ_DepackDone:  lda lastNavArea
CZ_CopyNavAreas:tax
                lda (zpSrcLo),y                 ;Copy navarea data stored after zone map
                iny                             ;Note: order will be reversed, but it doesn't matter
                bne CZ_CopyNavAreasNoMSB
                inc zpSrcHi
CZ_CopyNavAreasNoMSB:
                sta navAreaType,x
                txa
                clc
                adc #MAX_NAVAREAS               ;Move to next var
                cmp #MAX_NAVAREAS*5
                bcc CZ_CopyNavAreas
                sbc #MAX_NAVAREAS*5+1           ;Move to next navarea after all vars
                bpl CZ_CopyNavAreas
                lda #<zoneLvlObjList
                sta CZ_AnimLevelObjects+1
CZ_AnimLevelObjects:
                ldy zoneLvlObjList              ;Animate level objects now
                bmi CZ_AnimLevelObjectsDone
                inc CZ_AnimLevelObjects+1
                lda lvlObjFlags,y
                bpl CZ_AnimLevelObjects
                jsr DrawLevelObjectEndFrame
                lda lvlObjFlags,y               ;If object is a locker, reveal any hidden items at it
                and #OBJ_TYPEBITS
                cmp #OBJTYPE_LOCKER
                bne CZ_AnimLevelObjects
                jsr RevealLevelActors
                bmi CZ_AnimLevelObjects
CZ_AnimLevelObjectsDone:
                sty animObj                     ;Disable any ongoing level object animation
                sty usableObj
                sty SLO_LastX+1                 ;Reset levelobject search (enough to reset X, since it can never be $ff)
                rts

        ; Output map byte in an interleaved manner while depacking zone
        ;
        ; Parameters: A byte, X output index, xLo pos within row-counter, yLo row counter
        ; Returns: X incremented, Z=0
        ; Modifies: X

CZ_OutputByte:
CZ_Sta:         sta $1000,x
CZ_SequenceSta: sta screen                      ;Save also to screen as non-interleaved (sequence ringbuffer)
                inc CZ_SequenceSta+1
                inx
                inx
                bne CZ_OutputNoMSB
                inc CZ_Sta+2
CZ_OutputNoMSB: dec xLo
                bne CZ_NoNextRow
CZ_NextRow:     pha
                ldx yLo
                lda mapTblLo,x
                sta CZ_Sta+1
                lda mapTblHi,x
                sta CZ_Sta+2
                lda mapSizeX
                sta xLo
                pla
                ldx #$00
                inc yLo
CZ_NoNextRow:   rts

        ; Place actor at the center of a levelobject
        ;
        ; Parameters: Y object index, X actor index
        ; Returns: A=0
        ; Modifies: A,zpSrcLo

SetActorAtObject:
                lda lvlObjSize,y
                and #$0c
                lsr
                lsr
                sec
                adc lvlObjY,y                   ;C becomes 0
                sta actYH,x
                lda lvlObjSize,y
                and #$03
                sty zpSrcLo
                tay
                lda lvlObjCenterLoTbl,y
                sta actXL,x
                lda lvlObjCenterHiTbl,y
                ldy zpSrcLo
                adc lvlObjX,y
                sta actXH,x
                lda #$00
                sta actYL,x
                rts

        ; Toggle a levelobject
        ;
        ; Parameters: Y object index
        ; Returns: -
        ; Modifies: A,X,Y,loader zp vars

ToggleObject:   lda lvlObjFlags,y
                bmi DeactivateObject

        ; Activate a levelobject
        ;
        ; Parameters: Y object index
        ; Returns: -
        ; Modifies: A,X,Y,loader zp vars,more possibly depending on script

ActivateObject: lda lvlObjFlags,y
                bmi AO_AlreadyActive
                ora #OBJ_ACTIVE
                sta lvlObjFlags,y
                and #OBJ_AUTODEACT
                beq AO_NoAutoDeact              ;Autodeactivating?
                lda autoDeactObj                ;If another object already deactivating,
                bmi AO_NoPreviousAutoDeact      ;deactivate it immediately
                cpy autoDeactObj
                beq AO_NoPreviousAutoDeact      ;If same object deactivating, no need to do that
                sty loadTempReg
                tay
                jsr DeactivateObject
                ldy loadTempReg
AO_NoPreviousAutoDeact:
                sty autoDeactObj
                lda #AUTODEACT_DELAY
                sta ULO_AutoDeactDelay+1
AO_NoAutoDeact: jsr AnimateObject               ;Animate now before object action
                lda lvlObjFlags,y               ;Check object action type
                and #OBJ_TYPEBITS               ;TODO: implement these
                cmp #OBJTYPE_LOCKER
                beq AO_Locker
                cmp #OBJTYPE_SWITCH
                beq AO_ExecScript
                cmp #OBJTYPE_SWITCHCUSTOM
                beq AO_ExecScript
AO_NoEffect:    rts

AO_ExecScript:  lda lvlObjDL,y
                ldx lvlObjDH,y
                sty ES_Param+1
                jmp ExecScript

        ; Deactivate a levelobject
        ;
        ; Parameters: Y object index
        ; Returns: -
        ; Modifies: A,loader zp vars,temp7-temp8

DeactivateObject:
                lda lvlObjFlags,y
                bpl DO_NotActive
                and #$ff-OBJ_ACTIVE
                sta lvlObjFlags,y
                cpy autoDeactObj            ;If this object was autodeactivating, reset it now
                bne DO_NoAutoDeact
                lda #NO_OBJECT
                sta autoDeactObj
DO_NoAutoDeact: jmp AnimateObject           ;TODO: implement action on deactivation, if needed
AO_NoScript:
AO_AlreadyActive:
DO_NotActive:   rts

        ; Reveal hidden actors at object (weapon lockers)
        ;
        ; Parameters: Y object index
        ; Returns: N=1
        ; Modifies: A,X,loader zp vars

AO_Locker:
RevealLevelActors:
                jsr GetLevelObjectSize
                lda lvlObjX,y
                adc zpBitsLo
                sta zpBitsLo
                lda lvlObjY,y
                ora #$80
                sta zpDestLo
                adc zpBitsHi
                sta zpBitsHi
                ldx #MAX_LVLACT-1
RvLA_Loop:      lda lvlActZ,x                   ;Zone must match
                cmp lvlObjZ,y
                bne RvLA_Next
                lda lvlActX,x                   ;Check whether actor within object's bounds
                cmp lvlObjX,y
                bcc RvLA_Next
                cmp zpBitsLo
                bcs RvLA_Next
                lda lvlActY,x
                cmp zpDestLo
                bcc RvLA_Next
                cmp zpBitsHi
                bcs RvLA_Next
                and #$7f
                sta lvlActY,x
RvLA_Next:      dex
                bpl RvLA_Loop
                rts

        ; Start levelobject animation to either active or inactive state
        ;
        ; Parameters: Y object index
        ; Returns: -
        ; Modifies: A,loader zp vars

AnimateObject:  lda lvlObjZ,y                   ;If has more than one frame and is in same zone, animate
                cmp zoneNum
                bne AO_NoAnimation
                jsr GetLevelObjectFrames
                beq AO_NoAnimation
                asl
                adc #$01                        ;Tweak endframe so that deactivation animation doesn't start too fast
                sta aoEndFrame
                lda animObj
                bmi AO_AnimationFree
                cpy animObj                     ;If animating the same object, just overwrite
                beq AO_AnimationFree
                sty aoTemp
                tay
                lda animObjTarget
                lsr
                jsr DrawLevelObjectFrame        ;Finish existing animation forcibly now if needed
                ldy aoTemp                      ;(only 1 animation at a time)
AO_AnimationFree:
                sty animObj
                lda lvlObjFlags,y
                asl
                lda #$00
                bcs AO_AnimateToEnd
AO_AnimateToStart:
                lda aoEndFrame
AO_AnimateToEnd:sta animObjFrame
                eor aoEndFrame
                sta animObjTarget
AO_NoAnimation: rts

        ; Get number of frames on a levelobject - 1
        ;
        ; Parameters: Y object index
        ; Returns: A number of frames - 1
        ; Modifies: A

GetLevelObjectFrames:
                lda lvlObjSize,y
                lsr
                lsr
                lsr
                lsr
DLOEF_NoAnim:   rts

        ; Get levelobject size
        ;
        ; Parameters: Y object index
        ; Returns: zpBitsLo X size, zpBitsHi Y size
        ; Modifies: A

GetLevelObjectSize:
                lda lvlObjSize,y
                pha
                and #$0c
                lsr
                lsr
                adc #$01                        ;C=0
                sta zpBitsHi
                pla
                and #$03
                adc #$01                        ;C=0
                sta zpBitsLo
                rts

        ; Draw end frame for a levelobject. If not animating, no-op
        ;
        ; Parameters: Y object index
        ; Returns: C=1
        ; Modifies: A,loader zp vars

DrawLevelObjectEndFrame:
                jsr GetLevelObjectFrames
                beq DLOEF_NoAnim

        ; Draw animation frame for a levelobject
        ;
        ; Parameters: Y object index A frame number
        ; Returns: C=1
        ; Modifies: A,loader zp vars

DrawLevelObjectFrame:
                stx zpBitBuf
                sty zpLenLo
                pha
                jsr GetLevelObjectSize
                ldy zpBitsHi
                ldx #<zpSrcLo
                jsr MulU                        ;Get size of frame in bytes
                ldy zpSrcLo
                pla
                jsr MulU                        ;Get offset to frameblocktable
                ldy zpLenLo
                lda zpSrcLo
                clc
                adc lvlObjFrame,y
                adc #<lvlObjAnimFrames
                sta DLOF_Lda+1
                lda lvlObjX,y
                asl
                sta zpDestLo                    ;zpDestLo,Hi = 16bit X-offset to maprow (multiplied by 2 due to interleaved mapdata layout)
                lda #$00
                rol
                sta zpDestHi
                asl zpBitsLo
                lda lvlObjY,y
                tax
                adc zpBitsHi
                sta zpBitsHi
DLOF_XReload:   lda mapTblLo,x                  ;C always 0 here
                adc zpDestLo
                sta zpSrcLo
                lda mapTblHi,x
                adc zpDestHi
                sta zpSrcHi
                sta UF_BlockUpdateFlag+1
                ldy #$00
DLOF_Lda:       lda lvlObjAnimFrames
                inc DLOF_Lda+1
                sta (zpSrcLo),y
                iny
                iny
                cpy zpBitsLo
                bcc DLOF_Lda
                inx
                cpx zpBitsHi
                bcc DLOF_XReload
                ldx zpBitBuf
                ldy zpLenLo
DLOF_Skip:      rts

        ; Update level objects
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,various

UpdateLevelObjects:
                inc frameNumber                 ;Increment the global framenumber
                ldy autoDeactObj                ;Perform object autodeactivation
                bmi ULO_NoAutoDeact
                cpy animObj                     ;If animating, let the animation finish first
                beq ULO_NoAutoDeact
ULO_AutoDeactDelay:
                lda #$00
                bne ULO_AutoDeactOK
                cpy atObj                       ;Some further checks if player standing at it
                bne ULO_AutoDeactOK
                lda lvlObjFlags,y
                cmp #OBJTYPE_SIDEDOOR|OBJMODE_TRIG|OBJ_AUTODEACT|OBJ_ACTIVE
                beq ULO_NoAutoDeact             ;Triggered sidedoor doesn't close until player outside it
ULO_AutoDeactOK:dec ULO_AutoDeactDelay+1
                bpl ULO_NoAutoDeact
                jsr DeactivateObject
ULO_NoAutoDeact:ldy animObj                     ;Perform object animation (1 object either activating
                bmi ULO_NoObjectAnim            ;or deactivating at a time)
                lda animObjFrame
                cmp animObjTarget
                beq ULO_FinishObjectAnim
                bcc ULO_AnimForward
ULO_AnimBackward:
                sbc #$01
                skip2
ULO_AnimForward:adc #$01
ULO_AnimRedraw: sta animObjFrame
                lsr
                bcs ULO_NoObjectAnim            ;Skip the "inbetween" delay frames
                jsr DrawLevelObjectFrame
                bcs ULO_NoObjectAnim
ULO_FinishObjectAnim:
                lda #NO_OBJECT
                sta animObj
ULO_NoObjectAnim:

ULO_ObjDone:    ldy atObj                       ;Check for entering sidedoors
                bmi ULO_NoDoor
                lda actMB+ACTI_PLAYER
                lsr                             ;Need to hit wall at zone edge to enter
                lda lvlObjFlags,y
                and #OBJ_TYPEBITS
                bcc ULO_NoSideDoor
                bne ULO_NoSideDoor
                ldx actXH
                beq ULO_EnterDoor
ULO_NoSideDoorLeft:
                inx
                cpx mapSizeX
                beq ULO_EnterDoor
ULO_NoDoor:
ULO_NoSideDoor: rts

        ; Move player to another level / zone via a door object, and make a checkpoint save
        ;
        ; Parameters: Y door object index
        ; Returns: -
        ; Modifies: A,X,Y,various

ULO_EnterDoor:  lda lvlObjDL,y
                sta atObj
                lda lvlObjDH,y
                jsr ChangeLevel
                ldy atObj
                lda lvlObjZ,y
                jsr ChangeZone
                ldy atObj
                ldx #ACTI_PLAYER
                jsr SetActorAtObject
                jsr ResetSpeed
                jsr SavePlayerState
                ldy atObj
                jsr DrawLevelObjectEndFrame
                jsr ActivateObject              ;Activate the destination door and animate directly to end
                lda #NO_OBJECT
                sta animObj
                bmi CenterPlayer

        ; Restore in-memory checkpoint and resume game
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,various

RestoreCheckpoint:
                ldx #<zpDestLo
                ldy #<zpSrcLo
                jsr CopySaveState
                ldx #NUM_SAVEMISCVARS-3         ;Restore everything except level & zone numbers
RCP_Loop:       jsr GetSaveMiscVar
                lda saveMiscVars,x
                sta (zpSrcLo),y
                dex
                bpl RCP_Loop
                stx levelNum                    ;In "no level" - do not save levelstate when changing level
                lda saveLevelNum                ;Load the level / zone in the save
                jsr ChangeLevel
                lda saveZoneNum
                jsr ChangeZone
                lda #$40                        ;Center player on block
                sta actXL+ACTI_PLAYER
                ldx #ACTI_PLAYER
                stx actYL+ACTI_PLAYER
                jsr InitActor
                lda saveActHp                   ;Restore proper health value from save
                sta actHp+ACTI_PLAYER

        ; Center player, add/update all actors and redraw screen.
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,various

CenterPlayer:   lda actXH+ACTI_PLAYER
                sec
                sbc #9
                bcs CP_NotOverLeft
                lda #0
CP_NotOverLeft: cmp SL_MapXLimit+1
                bcc CP_NotOverRight
                lda SL_MapXLimit+1
CP_NotOverRight:sta mapX
                lda actYH
                sec
                sbc #7
                bcs CP_NotOverUp
                lda #0
CP_NotOverUp:   cmp SL_MapYLimit+1
                bcc CP_NotOverDown
                lda SL_MapYLimit+1
CP_NotOverDown: sta mapY
                lda #MAX_LVLACT                 ;Add / update all actors
                sta AA_EndCmp+1
                lda #$00
                sta AA_Start+1
                jsr AddActors
                jsr UpdateActors
                jmp RedrawScreen

