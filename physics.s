MB_HITWALL      = $01
MB_LANDED       = $02
MB_GROUNDED     = $80

BI_GROUND       = $01
BI_WALL         = $02
BI_CLIMB        = $04
BI_DROP         = $08                           ;AKA navhint / turn marker
BI_SLOPEEND     = $10
BI_FIRSTSLOPE   = $20
BI_SLOPE        = $e0

GRAVITY_ACCEL   = 8
COMMON_MAX_YSPEED = 8*8

        ; Move actor with gravity
        ;
        ; Parameters: X actor index, actLo-Hi actor structure for parameters
        ; Returns: A updated movementbits
        ; Modifies: A,Y,various

MoveWithGravity:ldy #AD_SIDEOFFSET
                lda (actLo),y
MWG_CustomSideOffset:
                sta sideOffset
                ldy #AD_TOPOFFSET
                lda (actLo),y
                sta topOffset
                lda actMB,x
                and #MB_GROUNDED                ;Clear the one-shot flags from previous frame
                sta actMB,x
MWG_DoMoveX:    lda actSX,x                     ;If has speed, use it for X-obstacle check, else facing direction
                bne MWG_HasXSpeed
                lda actD,x
MWG_HasXSpeed:  asl
                lda actXL,x
                bcc MWG_MoveRight
MWG_MoveLeft:   sbc sideOffset
                bmi MWG_MoveLeftCheck
                adc actSX,x                     ;Adds one more, but should not have much effect
                bpl MWG_MoveXOK
MWG_MoveLeftCheck:
                lda sideOffset
                ldy #-1
                bmi MWG_MoveCheckCommon
MWG_MoveRight:  adc sideOffset
                bmi MWG_MoveRightCheck
                adc actSX,x
                bpl MWG_MoveXOK
MWG_MoveRightCheck:
                lda #$81                        ;C=0 here, subtracts one more
                sbc sideOffset
                ldy #1
MWG_MoveCheckCommon:
                sta zpLenLo
                sty loadTempReg
                lda actMB,x                     ;If grounded, use Y-offset -1 (check above), otherwise check at current Y
                ora #$7f
                bmi MWG_MoveCheckGrounded
                lda topOffset
                beq MWG_MoveCheckGrounded       ;If actor has top offset, check both ground and above
                jsr GetBlockInfoXY
                and #BI_WALL|BI_SLOPE|BI_SLOPEEND ;Sloped solid ground not treated as obstacles for character move
                cmp #BI_WALL
                beq MWG_HitWall
                ldy loadTempReg
                lda #$00
MWG_MoveCheckGrounded:
                jsr GetBlockInfoXY
                and #BI_WALL|BI_SLOPE|BI_SLOPEEND ;Sloped solid ground not treated as obstacles for character move
                cmp #BI_WALL
                bne MWG_MoveXOK
MWG_HitWall:    lda zpLenLo
                sta actXL,x
                lda #MB_HITWALL
                jsr SetMovementBits
                lda #$00
                sta actSX,x
                beq MWG_MoveXDone
MWG_MoveXOK:    lda actSX,x                     ;Actual move is not necessary with zero speed
                beq MWG_MoveXDone
                jsr MoveActorX
MWG_MoveXDone:  lda actXL,x                     ;Get current within-block pixel X for slope checks
                lsr
                lsr
                lsr
                sta slopeX
                lda actMB,x
                bpl MWG_InAir

MWG_Grounded:   jsr GetBlockInfo                ;Blockinfo after X-move  
                sta actBlockInfo,x
                lsr
                bcs MWG_HasGround
                lda actYL,x                     ;If no ground, check for block crossing for slopes
                ldy actYH,x
                asl
                bpl MWG_UpperHalf
MWG_LowerHalf:  iny
                jsr GBI_Common
                sta actBlockInfo,x
                lsr
                bcc MWG_StartFall
                inc actYH,x
                bne MWG_HasGround
MWG_UpperHalf:  dey
                jsr GBI_Common
                sta actBlockInfo,x
                lsr
                bcc MWG_StartFall
                cmp #$10
                bcc MWG_StartFall               ;If slope0, cannot move upward
                dec actYH,x
MWG_HasGround:  and #BI_SLOPE/2
                ora slopeX
                tay
                lda slopeTbl,y
                sta actYL,x
                lda actMB,x
                rts

MWG_StartFall:
SJ_Falling:     jsr ResetAnimDelay
                lda #$ff-MB_GROUNDED
ClearMovementBits:
                and actMB,x
                sta actMB,x
                rts

MWG_InAir:      jsr ApplyGravity
                ldy actSY,x
                bmi MWG_InAirUp

MWG_InAirDown:  jsr GetBlockInfo                ;Blockinfo after X-move
                sta loadTempReg
                lsr
                bcc MWG_NotAtGround
                and #BI_SLOPE/2                 ;At current block?
                ora slopeX
                tay
                lda slopeTbl,y                  ;If ground is above actor, cannot hit it
                cmp actYL,x
                bcs MWG_HasGroundLevel
                lda loadTempReg
                and #BI_WALL                    ;Exception: if already inside wall, land immediately
                bne MWG_LandedSameBlock
MWG_NotAtGround:ldy actYH,x                     ;If not at current, also check below
                iny
                jsr GBI_Common
                lsr
                bcc MWG_NoLanding
                and #BI_SLOPE/2
                ora slopeX
                tay
                lda slopeTbl,y
                ora #$80                        ;(add block height to compare value)
MWG_HasGroundLevel:
                sta topOffset
                lda #$00
                cpy #$10                        ;If level ground, no need to add X-speed (would cause premature landing)
                bcc MWG_IsLevel
                lda actSX,x
                clc
                bpl MWG_XSpeedPos
                eor #$ff
                sec
MWG_IsLevel:
MWG_XSpeedPos:  adc actSY,x                     ;Absolute X-speed + Y-speed to make sure we don't miss diagonal crossings
                adc actYL,x
                cmp topOffset
                bcc MWG_NoLanding
MWG_Landed:     lda topOffset                   ;If ground was below, adjust Y-pos 1 block down
                bpl MWG_GroundPosOK
                and #$7f
                inc actYH,x
MWG_GroundPosOK:sta actYL,x
                lda #$00
                sta actSY,x
                lda #MB_LANDED|MB_GROUNDED

        ; Set movement bits on
        ;
        ; Parameters: X actor index, A bit(s) to set
        ; Returns: -
        ; Modifies: A

SetMovementBits:ora actMB,x
                sta actMB,x
                rts

MWG_NoLanding:  lda actSY,x
                jsr MoveActorY
                lda actMB,x
                rts
                
MWG_LandedSameBlock:
                lda slopeTbl,y
                bpl MWG_GroundPosOK

MWG_InAirUp:    jsr GetBlockInfo                ;Blockinfo after X-move
                lsr
                bcs MWG_InAirUpHasGround
                and #BI_WALL/2                  ;If crossed inside a wall, must back out & retry
                beq MWG_InAirUpNoLanding
                lda actSX,x
                jsr MoveActorXNeg
                lda actXL,x
                lsr
                lsr
                lsr
                sta slopeX
                jsr GetBlockInfo
                lsr
                bcc MWG_InAirUpNoLanding
MWG_InAirUpHasGround:
                and #BI_SLOPE/2
                beq MWG_InAirUpNoLanding
                ora slopeX
                tay
                cmp #$40
                bcs MWG_InAirUpSlopeLeft
MWG_InAirUpSlopeRight:
                lda actSX,x                     ;When going up against a slope, check if combined speeds will cause going through it
                beq MWG_InAirUpNoLanding
                bpl MWG_InAirUpSlopeCommon
                bmi MWG_InAirUpNoLanding
MWG_InAirUpSlopeLeft:
                lda actSX,x
                bpl MWG_InAirUpNoLanding
                eor #$ff
                sec
MWG_InAirUpSlopeCommon:
                adc actSY,x
                adc actSY,x
                adc actYL,x
                bmi MWG_InAirUpNoLanding
                cmp slopeTbl,y
                bcs MWG_LandedSameBlock
MWG_InAirUpNoLanding:
                lda actSY,x
                jsr MoveActorY
                lda topOffset
                jsr GetBlockInfoY
                and #BI_WALL
                beq MWG_NoHitCeiling
MWG_HitCeiling: lda #$00
                sta actSY,x
                sta actYL,x
                inc actYH,x
MWG_NoHitCeiling:
                lda actMB,x
                rts

        ; Move projectile actor in a straight line, remove if goes outside
        ;
        ; Parameters: X actor index
        ; Returns: C=1 hit wall (A != 0) or was removed (A = 0)
        ;          C=0 no wall hit
        ; Modifies: A,Y,loader temp vars

MoveProjectile: lda actSX,x                     ;Replicate MoveActor / GetBlockInfo to avoid JSRs
                beq MProj_XMoveZero             ;Optimize for zero X / Y speed
                clc
                adc actXL,x
                bpl MProj_XMoveDone
                ldy actSX,x
                bmi MProj_XMoveLeft
                inc actXH,x
                bne MProj_XMoveMSBDone
MProj_XMoveLeft:dec actXH,x
MProj_XMoveMSBDone:
                and #$7f
MProj_XMoveDone:
                sta actXL,x
MProj_XMoveZero:lda actSY,x
                beq MProj_YMoveZero
                clc
                adc actYL,x
                bpl MProj_YMoveDone
                ldy actSY,x
                bmi MProj_YMoveUp
                inc actYH,x
                bne MProj_YMoveMSBDone
MProj_YMoveUp:  dec actYH,x
                bmi MProj_Remove
MProj_YMoveMSBDone:
                and #$7f
MProj_YMoveDone:
                sta actYL,x
MProj_YMoveZero:ldy actYH,x
                lda mapTblLo,y
                sta zpSrcLo
                lda mapTblHi,y
                sta zpSrcHi
                lda actXH,x
                cmp mapSizeX
                bcs MProj_Remove
                asl
                bcc MProj_NoRowOverflow
                inc zpSrcHi
MProj_NoRowOverflow:
                tay
                lda (zpSrcLo),y
                tay
                lda blkInfo,y
                and #BI_WALL
                beq MProj_NoWall
                lda blkInfo,y
                jsr CheckInsideSlope
                bcs MProj_HitWall
MProj_NoWall:   rts                             ;C=0
MProj_Remove:   sec
                jmp RemoveActor
MProj_HitWall:  lda #$ff
                rts

        ; Return blockinfo from actor's position with both X & Y offsets
        ;
        ; Parameters: X actor index, A signed Y offset, Y signed X offset
        ; Returns: A block info
        ; Modifies: Y, zpSrcLo-Hi,zpDestLo

GetBlockInfoXY: sty zpDestLo
                clc
                adc actYH,x
                tay
                cpy mapSizeY
                bcs GBI_YOutside
                lda mapTblLo,y
                sta zpSrcLo
                lda mapTblHi,y
                sta zpSrcHi
                lda actXH,x
                adc zpDestLo                    ;C always 0
                jmp GBI_Common2

        ; Return blockinfo from actor's position with offset
        ;
        ; Parameters: X actor index, A signed Y offset
        ; Returns: A block info
        ; Modifies: Y, zpSrcLo-Hi

GetBlockInfo1Above:
                lda #-1                         ;Often needed
GetBlockInfoY:  clc
                adc actYH,x
                tay
                jmp GBI_Common

        ; Return blockinfo from actor's position
        ;
        ; Parameters: X actor index
        ; Returns: A block info
        ; Modifies: Y, zpSrcLo-Hi

GetBlockInfo:   ldy actYH,x
GBI_Common:     cpy mapSizeY
                bcc GBI_YNotOutside             ;Continue top row above
GBI_YOutside:   ldy #$00
GBI_YNotOutside:lda mapTblLo,y
                sta zpSrcLo
                lda mapTblHi,y
                sta zpSrcHi
                lda actXH,x
GBI_Common2:    cmp mapSizeX
                bcs GBI_OutsideHoriz
                asl
                bcc GBI_NoRowOverflow
                inc zpSrcHi
GBI_NoRowOverflow:
                tay
GBI_OutsideHorizExpandDone:
                lda (zpSrcLo),y
                tay
                lda blkInfo,y
                rts
GBI_OutsideHoriz:
                cpx #MAX_COMPLEXACT             ;Bullets expand the edge column, NPCs get wall to not walk out of zone
                bcc GBI_OutsideHorizNPC
                ldy #$00
                cmp #$fe
                bcs GBI_OutsideHorizExpandDone  ;Left side
                ldy mapSizeX
                dey
                bne GBI_OutsideHorizExpandDone  ;Right side
GBI_OutsideHorizNPC:
                lda #BI_WALL
                rts
                
        ; Check whether actor is inside (below) slope
        ;
        ; Parameters: X actor index, A blockinfo from slope block
        ; Returns: C=1 if inside
        ; Modifies: Y,zpSrcLo

CheckInsideSlope:
                lsr
                sta zpSrcLo
                lda actXL,x
                lsr
                lsr
                lsr
                ora zpSrcLo
                tay
                lda actYL,x
                cmp slopeTbl,y
                rts
