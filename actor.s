AD_FLAGS        = $00
AD_HEALTH       = $01
AD_UPDATE       = $02
AD_DRAW         = $04
AD_GRAVITY      = $06
AD_SIDEOFFSET   = $07
AD_TOPOFFSET    = $08
AD_DAMAGEMOD    = $09
AD_TAKEDAMAGE   = $0a

GRP_HEROES      = $00
GRP_ENEMIES     = $01
GRP_NEUTRAL     = $02

AF_GROUPFLAGS   = $03
AF_CLIMB        = $04
AF_NOINTERPOLATION = $40
AF_NOREMOVECHECK = $80

NO_BOUNDS       = $ff
NO_MODIFY       = 8

ORG_TEMP        = $00                           ;Temporary actor, may be overwritten by global or leveldata
ORG_GLOBAL      = $40                           ;Global important actor
ORG_LEVELDATA   = $80                           ;Leveldata actor, added/removed at level change
ORG_NONPERSISTENT = $ff
ORG_LEVELNUM    = $3f

LVLACTSEARCH    = 24

MAX_IMPULSESPEED = 6*8

DF_LETHAL       = $01
DF_IMPULSEBITS  = $7e
DF_HITFLASH     = $ff

STATE_UPRIGHT   = 0
STATE_CLIMB     = 1

USESCRIPT       = $8000

        ; Draw all actors as part of the first (non-interpolated) frame, then add new actors for next frame's update
        ;
        ; Parameters: X,Y lowbyte subtract for actor render
        ; Returns: -
        ; Modifies: A,X,Y,several ZP vars

DrawActors:     stx DA_SprSubXL+1
                sty DA_SprSubYL+1
                ldx cacheFrame
                stx DSpr_LastCacheFrame+1
DA_IncCacheFrame:
                inx                             ;Increment framenumber for sprite cache
                beq DA_IncCacheFrame            ;(framenumber is never 0)
                stx cacheFrame
DA_CheckCacheAge:
                txa
                and #MAX_CACHESPRITES-1
                tay
                txa
                sec                             ;If age stored in cache is older than significant, reset
                sbc cacheSprAge,y               ;to prevent overflow error (check one sprite per frame)
                bpl DA_CacheAgeOK
                lda #$00
                sta cacheSprAge,y
DA_CacheAgeOK:  ldx #$00                        ;Reset amount of used sprites
                stx numSpr
                stx numBounds
DA_Loop:        ldy actT,x
                beq DA_Next
                lda actDataTblLo-1,y
                sta actLo
                lda actDataTblHi-1,y
                sta actHi
                lda actXL,x                     ;Convert actor coordinates to screen
                sta actPrevXL,x
                sec
DA_SprSubXL:    sbc #$00
                sta xLo
                lda actXH,x
DA_StorePrevXH: sta actPrevXH,x
DA_SprSubXH:    sbc #$00
                cmp #MAX_ACTX                   ;Skip if significantly outside
                bcs DA_Outside
                tay
                lda xLo
                lsr
                lsr
                lsr
                lsr
                and #$07
                ora xCoordTbl,y
                sta xLo                         ;X pos
                lda actYL,x
                sta actPrevYL,x
                sec
DA_SprSubYL:    sbc #$00
                sta yLo
                lda actYH,x
DA_StorePrevYH: sta actPrevYH,x
DA_SprSubYH:    sbc #$00
                cmp #MAX_ACTY
                bcs DA_Outside
                tay
                lda yLo
                lsr
                lsr
                lsr
                and #$0f
                ora yCoordTbl,y
                sta yLo                         ;Y pos
                stx actIndex
                jsr ActorDrawCall               ;Perform the draw call (produces sprites)
                ldx actIndex
                bpl DA_Next
DA_Outside:     lda #NO_BOUNDS                  ;Mark as having no bounds
                sta actBounds,x
DA_Next:        inx
                cpx #MAX_ACT
                bcc DA_Loop
                ldx numBounds                   ;Make bounds endmark to simplify collision checks
                lda #$ff
                sta boundsAct,x
DA_FillSprites: ldx numSpr                      ;If less sprites used than last frame, set unused Y-coords to max.
DA_FillSpritesLoop:
                sta sprY,x
                inx
DA_LastSprIndex:cpx #MAX_SPR
                bcc DA_FillSpritesLoop
                lda numSpr
                sta DA_LastSprIndex+1           ;Store used sprite count for next frame's cleanup

        ; Add actors to screen. Also perform line-of-sight check for one actor at a time if requested
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,various

AddActors:      lda mapX
                clc
                adc #23
                sta AA_RightCmp+1
                sta UA_RemoveRightCmp+1
                lda mapX
                sbc #$02                        ;C=0, subtract one more
                bcs AA_LeftLimitOK
                lda #$00
AA_LeftLimitOK: sta AA_LeftCmp+1
                sta UA_RemoveLeftCmp+1
                lda mapY
                clc
                adc #13
                sta AA_BottomCmp+1
                sta UA_RemoveBottomCmp+1
                sbc #13                         ;C=0, subtract one more
                bcs AA_TopLimitOK
                lda #$00
AA_TopLimitOK:  sta AA_TopCmp+1
                sta UA_RemoveTopCmp+1
AA_Start:       ldx #$00
AA_Loop:        ldy lvlActT,x
                beq AA_Skip
                lda lvlActOrg,x                 ;Must be either a current level's leveldata actor,
                bmi AA_LevelOK                  ;or a global/temp actor with matching level
                and #ORG_LEVELNUM
                cmp levelNum
                bne AA_Skip
AA_LevelOK:     lda lvlActZ,x
                cmp zoneNum
                bne AA_Skip
                lda lvlActX,x
AA_LeftCmp:     cmp #$00
                bcc AA_Skip
AA_RightCmp:    cmp #$00
                bcs AA_Skip
                lda lvlActY,x
AA_TopCmp:      cmp #$00
                bcc AA_Skip
                cpy #$80                        ;No bottom adjust for items
                bcs AA_BottomCmp
                adc actBottomAdjustTbl-1,y      ;Bottom check adjust for tall actors (C=1 here, so they must be one less)
AA_BottomCmp:   cmp #$00
                bcs AA_Skip
                stx zpDestLo
                jsr AddLevelActor
                ldx zpDestLo
AA_Skip:        inx
AA_EndCmp:      cpx #LVLACTSEARCH
                bne AA_Loop
                cpx #MAX_LVLACT
                bcc AA_IndexNotOver
                ldx #$00
                clc
AA_IndexNotOver:stx AA_Start+1                  ;Store search start & endpositions for next frame
                txa
                adc #LVLACTSEARCH
                sta AA_EndCmp+1
AA_LineCheckActor:
                ldx #ACTI_LASTNPC
                dex
                bne AA_LineNotOver
                ldx #ACTI_LASTNPC
AA_LineNotOver: stx AA_LineCheckActor+1
                lda actTargetFlags,x            ;Actor has requested linecheck?
                bpl AA_LineCheckSkip
                jmp DoLineCheck                 ;Perform one per frame
AA_LineCheckSkip:
                rts

        ; Update actors, interpolate sprites & scan for levelobject at player
        ;
        ; Parameters: X,Y lowbyte subtract for actor render
        ; Returns: -
        ; Modifies: A,X,Y,various

UpdateActors:   txa                             ;Calculate scrolling change from last frame
                eor #$ff
                sec
                adc DA_SprSubXL+1
                and #$7f
                lsr
                lsr
                lsr
                lsr
                cmp #$04
                bcc UA_ScrollXNotNeg
                ora #$f8
UA_ScrollXNotNeg:
                sta UA_ScrollXAdjust+1
                tya
                eor #$ff
                sec
                adc DA_SprSubYL+1
                and #$7f
                lsr
                lsr
                lsr
                cmp #$08
                bcc UA_ScrollYNotNeg
                ora #$f0
UA_ScrollYNotNeg:
                sta UA_ScrollYAdjust+1
                lda #$60                        ;Modify sprite render code for GetConnectPoint
                sta DLS_ComplexNoConnect
                sta DLS_SimpleConnectDone
                ldx #MAX_ACT-1
                stx Irq5_CharAnimFlag+1         ;Enable char animation
                bne UA_ActorLoop
UA_Skip:        dex
                bpl UA_ActorLoop
                jmp UA_ActorsDone
UA_Remove:      jsr RemoveLevelActor            ;Returns with A=0
                beq UA_CalculateMove            ;Need to calculate interpolation also when removing, to avoid last frame glitches
UA_ActorLoop:   ldy actT,x
                beq UA_Skip
                stx actIndex
                lda actFlags,x                  ;Perform remove check?
                sta currFlags
                bmi UA_NoRemoveCheck
                lda actXH,x
UA_RemoveLeftCmp:
                cmp #$00
                bcc UA_Remove
UA_RemoveRightCmp:
                cmp #$00
                bcs UA_Remove
                lda actYH,x
UA_RemoveTopCmp:cmp #$00
                bcc UA_Remove
                adc actBottomAdjustTbl-1,y      ;Bottom check adjust for tall actors (C=1 here, so they must be one less)
                bmi UA_NoRemoveCheck
UA_RemoveBottomCmp:
                cmp #$00
                bcs UA_Remove
UA_NoRemoveCheck:
                lda actDataTblLo-1,y
                sta actLo
                lda actDataTblHi-1,y
                sta actHi
                ldy #AD_UPDATE+1
UA_UpdateCall:  jsr ActorCall                   ;Perform the update call
UA_CalculateMove:
                bit currFlags
                bvc UA_CalculateMoveOK
                lda UA_ScrollXAdjust+1          ;No interpolation: skip average movement calculation,
                sta actPrevXL,x                 ;use just scrolling offset
                lda UA_ScrollYAdjust+1
                bvs UA_StoreYAdjust
UA_CalculateMoveOK:
                lda actXL,x                     ;After update, calculate average movement
                sec                             ;of actor in X-direction
                sbc actPrevXL,x
                tay
                lda actXH,x
UA_SubPrevXH:   sbc actPrevXH,x
                sta zpSrcLo
                tya
                asl
                lsr zpSrcLo
                ror
                lsr
                lsr
                lsr
                lsr
                lsr
                bit zpSrcLo                     ;Sign is now in bit 6
                bvc UA_XMovePos
                ora #$f8
UA_XMovePos:
UA_ScrollXAdjust:
                adc #$00                        ;Add scrolling + LSB
                sta actPrevXL,x                 ;Store offset for sprite movement
                lda actYL,x                     ;Calculate average movement
                sec                             ;of actor in Y-direction
                sbc actPrevYL,x                 ;(max. 31 pixels)
                tay
                lda actYH,x
UA_SubPrevYH:   sbc actPrevYH,x
                sta zpSrcLo
                tya
                asl
                lsr zpSrcLo
                ror
                lsr
                lsr
                lsr
                lsr
                bit zpSrcLo
                bvc UA_YMovePos
                ora #$f0
UA_YMovePos:
UA_ScrollYAdjust:
                adc #$00                        ;Add scrolling + LSB
UA_StoreYAdjust:sta actPrevYL,x
                dex
                bmi UA_ActorsDone
                jmp UA_ActorLoop
UA_ActorsDone:  lda #$4c                        ;Restore sprite draw operation
                sta DLS_ComplexNoConnect
                lda #$06
                sta DLS_SimpleConnectDone

        ; Interpolate sprites according to actor & scroll movement
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,various

InterpolateActors:
                ldx numSpr
                dex
                bmi IA_Done
IA_SprLoop:     lda sprC,x                      ;Process flickering
                cmp #COLOR_FLICKER
                bcc IA_NoFlicker
                eor #COLOR_INVISIBLE            ;If sprite is invisible on this frame,
                sta sprC,x                      ;no need to calculate & add offset
                bmi IA_Next
IA_NoFlicker:   and #COLOR_OVERLAY              ;Overlay sprite that shouldn't scroll?
                bne IA_Next
                ldy sprAct,x                    ;Now add the calculated interpolation offsets
                lda sprY,x
                clc
                adc actPrevYL,y
                sta sprY,x
                lda sprX,x
                clc
                adc actPrevXL,y
                sta sprX,x
IA_Next:        dex
                bpl IA_SprLoop
IA_Done:

        ; Scan levelobject at player
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,various

ScanLevelObjects:
                ldx actXH+ACTI_PLAYER           ;Rescan objects if player occupies different block now
                ldy actYH+ACTI_PLAYER
SLO_LastX:      cpx #$ff
                bne SLO_Rescan
SLO_LastY:      cpy #$ff
                beq SLO_SkipScan
SLO_Rescan:     stx SLO_LastX+1
                sty SLO_LastY+1
                lda #<zoneLvlObjList
                sta SLO_ScanLoop+1
SLO_ScanLoop:   ldy zoneLvlObjList
                bmi SLO_ScanDone                ;Reached endmark?
                inc SLO_ScanLoop+1
                lda actXH+ACTI_PLAYER
                cmp lvlObjX,y
                bcc SLO_ScanLoop                ;Player to the left of levelobject
                lda lvlObjSize,y
                and #$03
                clc
                adc lvlObjX,y
                cmp actXH+ACTI_PLAYER
                bcc SLO_ScanLoop                ;Player to the right of levelobject
                lda actYH+ACTI_PLAYER
                cmp lvlObjY,y
                bcc SLO_ScanLoop                ;Player above levelobject
                lda lvlObjSize,y
                and #$0c
                lsr
                lsr
                sec
                adc lvlObjY,y
                cmp actYH+ACTI_PLAYER
                bcc SLO_ScanLoop                ;Player (too much) below levelobject
SLO_ScanDone:   sty atObj
SLO_SkipScan:   rts

        ; Perform actor draw call. Set color override for damage flash
        ;
        ; Parameters: X actor index, Y ycoord table index, actLo-actHi data structure
        ; Returns: -
        ; Modifies: A,X,Y,various

ActorDrawCall:  lda numBounds
                sta actBounds,x                 ;Store bounds startindex
                cpy #$10
                lda #$00
                sta actColorOr
                ror
                sta actYMSB
                ldy actDmgFlags,x
                iny
                bne ADC_NoDamageFlash
                inc actDmgFlags,x
                inc actColorOr
                lda #$f0
                skip2
ADC_NoDamageFlash: 
                lda #$ff
                sta actColorAnd
                ldy #AD_DRAW+1                  ;Then draw

        ; Perform actor call
        ;
        ; Parameters: X actor index, Y offset to highbyte in actor data structure, actLo-actHi data structure
        ; Returns: -
        ; Modifies: A,(potentially X),Y,various

ActorCall:      lda (actLo),y
                bpl AC_NoScript
AC_UseScript:   stx ES_Param+1
                and #$7f
                tax
                dey
                lda (actLo),y

        ; Execute loadable code (script)
        ;
        ; Parameters: A script entrypoint, X script file
        ; Returns: -
        ; Modifies: A,X,Y,various

ExecScript:     ldy fileHi+C_FIRSTSCRIPT,x
                beq ES_NotInMemory
ES_InMemory:    sty zpDestHi                    ;Fast path when the resource file is already in memory
                ldy fileLo+C_FIRSTSCRIPT,x
                sty zpDestLo
                asl
                tay
                lda (zpDestLo),y
                sta zpSrcLo
                iny
                lda (zpDestLo),y
                sta zpSrcHi
                lda #$00
                sta fileAge+C_FIRSTSCRIPT,x     ;Remember to reset age
ES_Param:       ldx #$00
                jmp (zpSrcLo)
ES_NotInMemory: jsr GetScriptResource
                jmp ES_Param

AC_NoScript:    sta AC_Jump+2
                dey
                lda (actLo),y
                sta AC_Jump+1
AC_Jump:        jmp $1000

        ; Move actor in X-direction
        ;
        ; Parameters: X actor index, A speed
        ; Returns: -
        ; Modifies: A

MoveActorXNegOrPos:
                bpl MoveActorX
MoveActorXNeg:  clc
                eor #$ff
                adc #$01
MoveActorX:     cmp #$80
                bcc MAX_Pos
MAX_Neg:        clc
                adc actXL,x
                bpl MAX_Done
                dec actXH,x
MAX_Over:       and #$7f
MAX_Done:       sta actXL,x
                rts
MAX_Pos:        adc actXL,x
                bpl MAX_Done
                inc actXH,x
                bcc MAX_Over                    ;C cannot possibly be 1 here

        ; Move actor in Y-direction
        ;
        ; Parameters: X actor index, A speed
        ; Returns: -
        ; Modifies: A

MoveActorYNegOrPos:
                bpl MoveActorY
MoveActorYNeg:  clc
                eor #$ff
                adc #$01
MoveActorY:     cmp #$80
                bcc MAY_Pos
MAY_Neg:        clc
                adc actYL,x
                bpl MAY_Done
                dec actYH,x
MAY_Over:       and #$7f
MAY_Done:       sta actYL,x
                rts
MAY_Pos:        adc actYL,x
                bpl MAY_Done
                inc actYH,x
                bcc MAY_Over

        ; Apply impulse from last damage to actor
        ;
        ; Parameters: X actor index, A damage flags + impulse
        ; Returns: -
        ; Modifies: A,Y,zpSrcLo

ApplyDamageImpulse:
                cmp #$80                        ;Dir bit to carry
                and #DF_IMPULSEBITS
                ldy #MAX_IMPULSESPEED

        ; Accelerate actor in X-direction with either positive or negative acceleration
        ;
        ; Parameters: X actor index, A absolute acceleration, Y absolute speed limit, C direction (0 = right, 1 = left)
        ; Returns:
        ; Modifies: A,Y,zpSrcLo

AccActorXNegOrPos:
                bcc AccActorXNoClc

        ; Accelerate actor in negative X-direction
        ;
        ; Parameters: X actor index, A absolute acceleration, Y absolute speed limit
        ; Returns:
        ; Modifies: A,Y,zpSrcLo

AccActorXNeg:   sec
AccActorXNegNoSec:
                sty zpSrcLo
                sbc actSX,x
                bmi AAX_NegDone
                cmp zpSrcLo
                bcc AAX_NegDone2
                tya
AAX_NegDone:    clc
AAX_NegDone2:   eor #$ff
                adc #$01
AAX_Done:       sta actSX,x
AAX_Done2:      rts

        ; Accelerate actor in positive X-direction
        ;
        ; Parameters: X actor index, A acceleration, Y speed limit
        ; Returns: -
        ; Modifies: A,zpSrcLo

AccActorX:      clc
AccActorXNoClc: sty zpSrcLo
                adc actSX,x
                bmi AAX_Done                    ;If speed negative, can not have reached limit yet
                cmp zpSrcLo
                bcc AAX_Done
                tya
                bcs AAX_Done

        ; Brake X-speed of an actor towards zero
        ;
        ; Parameters: X Actor index, A deceleration (always positive)
        ; Returns: -
        ; Modifies: A, zpSrcLo

BrakeActorX:    sta zpSrcLo
                lda actSX,x
                beq AAX_Done2
                bmi BAct_XNeg
BAct_XPos:      sec
                sbc zpSrcLo
                bpl AAX_Done
BAct_XZero:     lda #$00
                beq AAX_Done
BAct_XNeg:      clc
                adc zpSrcLo
                bpl BAct_XZero
                bmi AAX_Done

        ; Accelerate actor in Y-direction with either positive or negative acceleration
        ;
        ; Parameters: X actor index, A absolute acceleration, Y absolute speed limit, C direction (0 = down, 1 = up)
        ; Returns:
        ; Modifies: A,Y,zpSrcLo

AccActorYNegOrPos:
                bcc AccActorYNoClc

        ; Accelerate actor in negative Y-direction
        ;
        ; Parameters: X actor index, A absolute acceleration, Y absolute speed limit
        ; Returns:
        ; Modifies: A,Y,zpSrcLo

AccActorYNeg:   sec
AccActorYNegNoSec:
                sty zpSrcLo
                sbc actSY,x
                bmi AAY_NegDone
                cmp zpSrcLo
                bcc AAY_NegDone2
                tya
AAY_NegDone:    clc
AAY_NegDone2:   eor #$ff
                adc #$01
AAY_Done:       sta actSY,x
AAY_Done2:      rts

        ; Accelerate actor in positive Y-direction
        ;
        ; Parameters: X actor index, A acceleration, Y speed limit
        ; Returns: -
        ; Modifies: A,zpSrcLo

ApplyGravity:   ldy #AD_GRAVITY
                lda (actLo),y
                ldy #COMMON_MAX_YSPEED          ;Gravity acceleration
AccActorY:      clc
AccActorYNoClc: sty zpSrcLo
                adc actSY,x
                bmi AAY_Done                    ;If speed negative, can not have reached limit yet
                cmp zpSrcLo
                bcc AAY_Done
                tya
                bcs AAY_Done

        ; Brake Y-speed of an actor towards zero
        ;
        ; Parameters: X actor index, A deceleration (always positive)
        ; Returns: -
        ; Modifies: A, zpSrcLo

BrakeActorY:    sta zpSrcLo
                lda actSY,x
                beq AAY_Done2
                bmi BAct_YNeg
BAct_YPos:      sec
                sbc zpSrcLo
                bpl AAY_Done
BAct_YZero:     lda #$00
                beq AAY_Done
BAct_YNeg:      clc
                adc zpSrcLo
                bpl BAct_YZero
                bmi AAY_Done
                
        ; Process animation delay
        ;
        ; Parameters: X actor index, A animation speed-1 (in frames)
        ; Returns: C=1 delay exceeded, animationdelay reset
        ; Modifies: A, zpSrcLo

AnimationDelay: sta zpSrcLo
                lda actFd,x
                cmp zpSrcLo
                bcs AD_Over
                inc actFd,x
                rts

        ; Perform one-shot animation with delay
        ;
        ; Parameters: Y end frame, A animation speed-1 (in frames)
        ; Returns: C=1 end reached
        ; Modifies: A, zpSrcLo-Hi

OneShotAnimation:
                sta zpSrcLo
                sty zpSrcHi
                lda actFd,x
                cmp zpSrcLo
                bcs OSA_NextFrame
                inc actFd,x
                rts
OSA_NextFrame:  lda actF1,x
                cmp zpSrcHi
                bcs OSA_Over
                inc actF1,x
ResetAnimDelay:
AD_Over:        lda #$00
                sta actFd,x
OSA_Over:       rts

        ; Transform actor & reset animation
        ;
        ; Parameters: X actor index, A new type
        ; Returns: A=0
        ; Modifies: A

TransformActor: sta actT,x
                jsr ResetAnimDelay              ;Returns with A=0
                sta actF1,x
                rts

        ; Reset actor speeds, also set actor as grounded
        ;
        ; Parameters: X actor index
        ; Returns: A=0, C=0 if actor is complex
        ; Modifies: A

ResetSpeed:     lda #MB_GROUNDED
                sta actMB,x
                lda #$00
                sta actSX,x
                sta actSY,x
                rts

        ; Disable movement interpolation for the current frame. To be called during actor's own update.
        ;
        ; Parameters: X actor index
        ; Returns: Z=0
        ; Modifies: A

NoInterpolation:lda currFlags
                ora #AF_NOINTERPOLATION
                sta currFlags
                rts

        ; Add actor from leveldata
        ;
        ; Parameters: X leveldata index, must also be in zpDestLo
        ;             newActType new actor type
        ; Returns: -
        ; Modifies: A,X,Y,zpSrcLo-Hi,zpDestHi,actLo-Hi

AddLevelActor:  lda lvlActT,x
                pha
                bmi ALA_IsItem
ALA_IsNPC:      jsr GetFreeNPC
                bcs ALA_Fail
                pla
                sta actT,y
                lda lvlActWpn,x
                sta loadTempReg
                and #$7f
                sta actWpn,y
                lda loadTempReg
                and #$80
                jmp InitLevelActor              ;NPC facing direction
ALA_IsItem:     jsr GetFreeNonNPC
                bcs ALA_Fail
                lda #ACT_ITEM
                sta actT,y
                lda #$00
                jsr InitLevelActor
                jsr GetBlockInfo                ;Check for ground / locker shelf, start item falling if not grounded
                and #BI_GROUND|BI_DROP
                bne ALA_ItemGrounded
                sta actMB,x
ALA_ItemGrounded:
                pla
                and #$7f
                sta actF1,x
                ldy zpDestLo
                lda lvlActWpn,y
                sta actHp,x
                rts
ALA_Fail:       pla
                rts

        ; Remove all actors except player
        ;
        ; Parameters: X actor index
        ; Returns: -
        ; Modifies: A,Y,zpSrcLo

RemoveLevelActors:
                ldx #MAX_ACT-1
RLA_Loop:       lda actT,x
                beq RLA_Next
                jsr RemoveLevelActor
RLA_Next:       dex
                bne RLA_Loop
                rts

        ; Remove actor and return to leveldata if applicable
        ;
        ; Parameters: X actor index
        ; Returns: -
        ; Modifies: A,Y,zpSrcLo

RemoveLevelActor:
                lda actLvlDataOrg,x
                cmp #ORG_NONPERSISTENT
                beq RemoveActor
                pha
                jsr GetLevelActorIndex
                pla
                sta lvlActOrg,y                 ;Store levelnumber / persistence mode
                lda actXH,x                     ;Store block coordinates
                sta lvlActX,y
                lda actYH,x
                sta lvlActY,y
                lda zoneNum
                sta lvlActZ,y
                lda actT,x                      ;Store actor type differently if
                cmp #ACT_ITEM                   ;item or NPC
                bne RA_StoreNPC
RA_StoreItem:   lda actF1,x
                ora #$80
                sta lvlActT,y
                lda actHp,x
                bcs RA_StoreCommon              ;C=1 here
RA_StoreNPC:    sta lvlActT,y
                lda actD,x
                ora actWpn,x
RA_StoreCommon: sta lvlActWpn,y

        ; Remove actor and zero HP
        ;
        ; Parameters: X actor index
        ; Returns: A=0
        ; Modifies: A

RemoveActor:    lda #$00
                sta actT,x
                sta actHp,x
ACD_Skip:       rts

        ; Add (lethal) damage to self
        ;
        ; Parameters: A damage amount, X actor index
        ; Returns: -
        ; Modifies: A

AddSelfDamage:  ldy #DF_LETHAL                  ;Lethal damage, but no impulse
                pha
                tya
                sta actDmgFlags,x
                txa
                tay
                pla
                bpl AddDamage

        ; Add (bullet) damage to target actor
        ;
        ; Parameters: X source actor index, Y target actor index, A damage amount
        ; Returns: -
        ; Modifies: A,zpSrcLo-Hi,zpDestLo-Hi,xLo-yHi,loadTempReg

AddBulletDamage:lda actHp,x
AddDamage:      sta xLo
                stx saveActIndex
                lda actDmgFlags,x
                sta yLo
                stx xHi
                jsr GetActorYOffset
                sta yHi
                tya
                tax                             ;Target actor to X
                stx actIndex
                jsr GetActorData
                ldy #AD_DAMAGEMOD
                lda (actLo),y
                tay
                lda xLo
                jsr ModifyDamage                ;Apply damage mod
                sta xLo
                lda actHp,x                     ;Subtract hitpoints
                sec
                sbc xLo
                bcs AD_NoZeroHp
                lda #$00
AD_NoZeroHp:    sta actHp,x
                lda #DF_HITFLASH
                sta actDmgFlags,x
                ldy #AD_TAKEDAMAGE+1
                jsr ActorCall                   ;Call damage response for effects, destruction etc.
                ldx saveActIndex                ;Restore original actorindex
                stx actIndex
ABD_ZeroDamage: rts

        ; Check if two actors have collided.
        ; Only compares against the first bounding box of actor X, so it would be typically
        ; an item actor or other that only has one. Should not be called when actor X's
        ; current sprite doesn't have bounds
        ;
        ; Parameters: X,Y actor indices. Actor X must be also in actIndex.
        ; Returns: C=0 if collided
        ; Modifies: A,Y

CheckActorCollision:
                sty CAC_ActCmp+1
                lda actBounds,x                 ;Actor X not on screen
                bmi CAC_NoCollision
                tax
                lda actBounds,y
                bmi CAC_NoCollision             ;Actor Y not on screen
                tay
                bpl CAC_Loop
CAC_Next:       iny
CAC_Loop:       lda boundsAct,y                 ;Different actor or endmark? All actor's bounds checked then
CAC_ActCmp:     cmp #$00
                bne CAC_NoCollision
                lda boundsL,y
                cmp boundsR,x
                bcs CAC_Next
                lda boundsL,x
                cmp boundsR,y
                bcs CAC_Next
                lda boundsU,y
                cmp boundsD,x
                bcs CAC_Next
                lda boundsU,x
                cmp boundsD,y
                bcs CAC_Next
                ldx actIndex                    ;Has collision
                rts
SB_Success:
CBC_NoCollision:
CAC_NoCollision:ldx actIndex
CBC_NoCollision2:
                sec
                rts

        ; Check bullet's collision against all eligible actors, return first collision
        ; Should not be called when bullet's current sprite doesn't have bounds
        ;
        ; Parameters: X actor number, must also be in actIndex
        ; Returns: C=0 collision, actor index in Y, C=1 no collision
        ; Modifies: A,Y,zpBitsLo-Hi

CheckBulletCollision:
                lda actBounds,x
                bmi CBC_NoCollision2            ;Skip if bullet is outside screen
                sta CBC_BulletBoundsIndex+1
                tay
CBC_InitDone:   ldy #$00
CBC_Loop:       ldx boundsAct,y
CBC_Back:       cpx #MAX_COMPLEXACT             ;Endmark or non-complex actors reached?
                bcs CBC_NoCollision
                stx zpBitsLo
                lda actFlags,x
                eor currFlags
                and #AF_GROUPFLAGS
                beq CBC_NextAct                 ;Prevent friendly fire (same group)
                lda actHp,x                     ;Eligible to be damaged?
                beq CBC_NextAct
CBC_BulletBoundsIndex:
                ldx #$00
CBC_BoundsLoop: lda boundsL,y
                cmp boundsR,x
                bcs CBC_NextBounds
                lda boundsL,x
                cmp boundsR,y
                bcs CBC_NextBounds
                lda boundsU,y
                cmp boundsD,x
                bcs CBC_NextBounds
                lda boundsU,x
                cmp boundsD,y
                bcc CBC_HasCollision
CBC_NextBounds: iny
                lda boundsAct,y                 ;More bounds of same actor?
                cmp zpBitsLo
                beq CBC_BoundsLoop
                tax
                jmp CBC_Back

        ; Check next bullet collision for area effects and such. Only to be called
        ; when CheckBulletCollision returned a positive result!
        ;
        ; Parameters: -
        ; Returns: C=0 collision, actor index in Y and bounds index in zpSrcHi, C=1 no collision
        ; Modifies: A,Y,zpBitsLo-Hi

CheckNextBulletCollision:
                ldy zpBitsHi
CBC_NextAct:    iny
CBC_NextActLoop:ldx boundsAct,y                 ;Skip the rest of the same actor's bounds
                cpx zpBitsLo
                beq CBC_NextAct
                bne CBC_Back
CBC_HasCollision:
                sty zpBitsHi
                ldy zpBitsLo
SB_Fail:        ldx actIndex                    ;Collision found, actor index in Y
                clc
                rts

        ; Adjust actor's collision bounds according to movement speed, then recheck collision
        ;
        ; Parameters: X actor number
        ; Returns: -
        ; Modifies: A,Y,zpSrcLo,zpBitsLo-Hi

RecollideBullet:ldy actBounds,x
                bmi RB_NoBounds
                lda actSX,x
                lsr
                lsr
                lsr
                lsr
                cmp #$08
                bcc RB_NotLeft
                sbc #$10                        ;Sign expand (same as OR with $f0), C=0 afterward
RB_NotLeft:     pha
                adc boundsL,y
                sta boundsL,y
                pla
                clc
                adc boundsR,y
                sta boundsR,y
                lda actSY,x
                lsr
                lsr
                lsr
                lsr
                cmp #$08
                bcc RB_NotUp
                sbc #$10                        ;Sign expand (same as OR with $f0), C=0 afterward
RB_NotUp:       pha
                adc boundsU,y
                sta boundsU,y
                pla
                clc
                adc boundsD,y
                sta boundsD,y
RB_NoBounds:    jmp CBC_InitDone

        ; Give area damage
        ;
        ; Parameters: X source actor index, Y actor flags bitmask ($ff = damage all combatants)
        ; Returns: C=0 if damaged at least one enemy, C=1 if none
        ; Modifies: A,Y,loader temp vars

AreaDamageStrobedAll:
                ldy #$ff
AreaDamageStrobed:
                lda frameNumber
                lsr
                bcs AD_Done
                skip2
AreaDamageAll:  ldy #$ff
AreaDamage:     sty AD_FlagsAnd+1
                jsr CheckBulletCollision
                bcs AD_Done
AD_DamageLoop:  lda actFlags,y
AD_FlagsAnd:    and #$00
                beq AD_Skip
                asl actDmgFlags,x               ;Set damage impulse dir based on location
                lda actXL,y                     ;TODO: some explosive weapons sometimes go past enemy, resulting in "wrong" dir
                cmp actXL,x
                lda actXH,y
                sbc actXH,x
                asl
                ror actDmgFlags,x
                jsr AddBulletDamage
AD_Skip:        jsr CheckNextBulletCollision
                bcc AD_DamageLoop
IA_NotComplex:
GFA_Found:      clc
AD_Done:        rts

        ; Get a free actor
        ;
        ; Parameters: Y first actor index to check (do not pass 0 here), A first actor index to not check
        ; Returns: C=0 free actor found (returned in Y and in newActIndex), C=1 no free actor
        ; Modifies: A,Y

GetFreeEffectActor:
                txa
                tay
                skip2
GetFreeNonNPC:  ldy #ACTI_FIRSTNONNPC
                lda #MAX_ACT
                bne GetFreeActor
GetFreeNPC:     ldy #ACTI_FIRSTNPC
                lda #ACTI_FIRSTNONNPC
GetFreeActor:   sta GFA_EndCmp+1
GFA_Loop:       lda actT,y
                beq GFA_Found
                iny
GFA_EndCmp:     cpy #$00
                bcc GFA_Loop
                rts

        ; Initialize actor added to screen from the level.
        ;
        ; Parameters: A direction, X leveldata index, Y actor index
        ; Returns: C=0
        ; Modifies: A,Y,actLo-Hi

InitLevelActor: sta actD,y
                lda lvlActX,x
                sta actXH,y
                lda lvlActY,x
                sta actYH,y
                lda lvlActOrg,x                 ;Store the persistence mode (leveldata/global/temp)
                sta actLvlDataOrg,y
                lda #$00                        ;Remove from leveldata
                sta actYL,y
                sta actTime,y                   ;Used for AI timing, so needs to be reset
                sta lvlActT,x
                sta lvlActOrg,x
                lda #$40
                sta actXL,y
InitSpawnedActor:
                tya
                tax

        ; Initialize most actor variables, excluding position / direction / time counter.
        ;
        ; Parameters: X actor index
        ; Returns: -
        ; Modifies: A,Y,actLo-Hi

InitActor:      jsr GetActorData
                lda #NO_BOUNDS
                sta actBounds,x                 ;Cannot collide until drawn for the first time
                ldy #AD_FLAGS
                lda (actLo),y
                sta actFlags,x
                iny
                lda (actLo),y
                sta actHp,x
                jsr ResetSpeed                  ;C=1 on return if not complex
                sta actF1,x
                sta actFd,x
                cpx #MAX_COMPLEXACT
                bcs IA_NotComplex
                sta actAttackD,x                ;"Complex" actors (players / enemies) have more variables
                sta actCtrl,x
                sta actPrevCtrl,x
                sta actTarget,x
                sta actNavArea,x
                sta actDmgFlags,x
                sta actState,x
                lda #$ff
                sta actTargetNavArea,x
                rts

        ; Spawn an actor without offset
        ;
        ; Parameters: A actor type, X creating actor, Y destination actor index
        ; Returns: -
        ; Modifies: A,xLo-Hi,yLo-Hi

SpawnActor:     sta actT,y
                lda #$00
                sta xLo
                sta xHi
                sta yLo
                sta yHi
                beq SWO_SetCoords

        ; Spawn an actor with X & Y offset
        ;
        ; Parameters: A actor type, X creating actor, Y destination actor index, xLo-xHi X offset,
        ;             yLo-yHi Y offset
        ; Returns: -
        ; Modifies: A

SpawnWithOffset:sta actT,y
SWO_SetCoords:  lda actXL,x
                clc
                adc xLo
                cmp #$80
                and #$7f
SWO_XNotOver:   sta actXL,y
                lda actXH,x
                adc xHi
                sta actXH,y
                lda actYL,x
                clc
                adc yLo
                cmp #$80
                and #$7f
SWO_YNotOver:   sta actYL,y
                lda actYH,x
                adc yHi
                sta actYH,y
                lda UA_ScrollXAdjust+1          ;In case the old actor still exists as sprites, apply only scroll adjust to it
                sta actPrevXL,y
                lda UA_ScrollYAdjust+1
                sta actPrevYL,y
                lda #ORG_NONPERSISTENT
                sta actLvlDataOrg,y             ;Spawned actors are by default not persisted
                txa
                sta actOrg,y                    ;Store spawning actor index
                rts

        ; Calculate half-block accurate Y offset between actors
        ;
        ; Parameters: X source actor index, Y target actor index
        ; Returns: -
        ; Modifies: A,zpSrcLo

GetActorYOffset:lda actYL,x
                sec
                sbc actYL,y
                sta zpSrcLo
                lda actYH,x
                sbc actYH,y
GAO_Common:     asl zpSrcLo
                asl zpSrcLo
                rol
                rts

        ; Calculate half-block accurate X offset between actors
        ;
        ; Parameters: X source actor index, Y target actor index
        ; Returns: -
        ; Modifies: A,zpSrcLo

GetActorXOffset:lda actXL,x
                sec
                sbc actXL,y
                sta zpSrcLo
                lda actXH,x
                sbc actXH,y
                jmp GAO_Common

        ; Get actor data according to type
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,Y,actLo-Hi

GetActorData:   ldy actT,x
                lda actDataTblLo-1,y
                sta actLo
                lda actDataTblHi-1,y
                sta actHi
                rts

        ; Find NPC actor from screen by type
        ;
        ; Parameters: A actor type
        ; Returns: C=1 actor found, index in X, C=0 not found
        ; Modifies: A,X

FindActor:      ldx #ACTI_LAST
FA_Loop:        cmp actT,x
                beq FA_Found
                dex
                bne FA_Loop
FA_NotFound:    clc
FA_Found:       rts

        ; Find NPC actor from leveldata for state editing. If on screen, will be removed first
        ;
        ; Parameters: A actor type
        ; Returns: C=1 actor found, index in Y, C=0 not found
        ; Modifies: A,X,Y,zpSrcLo

FindLevelActor: sta zpSrcLo
                jsr FindActor
                bcc FLA_NotOnScreen
                jsr RemoveLevelActor
FLA_NotOnScreen:ldy #MAX_LVLACT-1
FLA_Loop:       lda lvlActT,y
FLA_Cmp:        cmp zpSrcLo
                beq FA_Found
                dey
                bpl FLA_Loop
                bmi FA_NotFound

        ; Get a free index from levelactortable. May overwrite a temp-actor.
        ; If no room (fatal error, possibly would make game unfinishable) will loop infinitely
        ;
        ; Parameters: -
        ; Returns: Y free index
        ; Modifies: A,Y

GetLevelActorIndex:
                ldy nextLvlActIndex
GLAI_Loop1:     lda lvlActT,y                   ;First try to find an empty position without overwrite
                beq GLAI_Found
                dey
                bpl GLAI_EndCmp
                ldy #MAX_LVLACT-1
GLAI_EndCmp:    cpy nextLvlActIndex             ;Wrapped to start?
                bne GLAI_Loop1
GLAI_Loop2:     lda lvlActOrg,y                 ;Second loop: overwrite any temp actors
                cmp #ORG_GLOBAL
                bcc GLAI_Found
                dey
                bpl GLAI_Loop2
                ldy #MAX_LVLACT-1
                bne GLAI_Loop2
GLAI_Found:     sty nextLvlActIndex             ;Store pos for next search
                rts

        ; Set flicker color for actor, to be called during actor render
        ;
        ; Parameters: X actor index
        ; Returns: Flicker color OR value stored in actColorOr
        ; Modifies: A

SetFlickerColor:txa
                lsr
                lda #COLOR_INVISIBLE
                ror
                sta actColorOr
                rts
                
        ; Get connect point for bullet spawn. Should only be called during actor update,
        ; as it does a fake actor render, and during the update producing actual sprites is patched out
        ;
        ; Parameters: X attacking actor
        ; Returns: xLo-yHi connect offset
        ; Modifies: A,Y,loader temp vars

GetConnectPoint:
                lda #$00
                sta xLo
                sta yLo
                ldy #AD_DRAW+1
                jsr ActorCall                   ;Perform a fake draw call without producing sprites
                ldx actIndex                    ;Restore actor index after draw
                lda yLo
                lsr
                lsr
                lsr
                lsr
                cmp #$08
                bcc GCP_YPos
                ora #$f0
GCP_YPos:       sta yHi
                lda yLo
                asl
                asl
                asl
                and #$7f
                sta yLo
                lda xLo
                lsr
                lsr
                lsr
                cmp #$10
                bcc GCP_XPos
                ora #$e0
GCP_XPos:       sta xHi
                lda xLo
                asl
                asl
                asl
                asl
                and #$7f
                sta xLo
                rts

