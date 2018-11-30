MAX_LINE_STEPS  = 19

TF_HASTARGET    = $01                           ;Has current combat target
TF_HASNAVLINE   = $02                           ;Has navigation line of sight to combat target
TF_HASLINE      = $40                           ;Has firing line of sight to combat target
TF_LINECHECK    = $80                           ;Request line of sight check

NAVAREA_ENDMARK = 0
NAVAREA_PLATFORM = 1
NAVAREA_LADDER = 2
NAVAREA_SLOPEUPRIGHT = 3
NAVAREA_SLOPEUPLEFT = 4

NO_NAVAREA      = $ff

MAX_LINEDIST    = 19

        ; Pathfinding
        ;
        ; Parameters: X actor index, currFlags actor flags
        ; Returns: A move controls, or 0 (stop) if no route or too close
        ; Modifies: A,Y,various

Pathfind:       ldy actTarget,x
                lda actNavArea,x
                sta srcNavArea                  ;Own nav area
                cmp actDestNavArea,x            ;If reached destination, invalidate it
                bne PF_NotReachedDest
                lda #NO_NAVAREA
                sta actTargetNavArea,x
PF_NotReachedDest:
                jsr GetCombinedDistance         ;Check abs. combined distance for stopping, set targetX & targetY
                cmp #$03
                bcc PF_Stop
PF_FarEnough:   lda actNavArea,y
                cmp srcNavArea
                beq PF_GoToTarget               ;Follow target if in same area
                cmp actTargetNavArea,x
                beq PF_GoToDestArea             ;Get new dest if target has changed area / was invalidated
                jsr PF_FindDestNavArea
PF_OldCtrl:     lda actCtrl,x                   ;Return old move controls to save CPU
                rts

PF_GoToTarget:  lda actState,x
                cmp #STATE_CLIMB
                bne PF_GoToTargetLeftOrRight
PF_GoToTargetClimbing:
                lda targetX
                cmp actXH,x
                bne PF_ClimbExit
PF_GoToTargetClimbingUpOrDown:
                lda targetY
PF_GoToTargetClimbingUpOrDown2:
                cmp actYH,x
                bcc PF_MoveUp
                bne PF_MoveDown
PF_Stop:        lda #$00
                rts

PF_GoToDestArea:ldy actDestNavArea,x            ;Stop if no route
                bmi PF_Stop
                lda actState,x
                cmp #STATE_CLIMB
                bne PF_Upright
PF_Climbing:    lda actXH,x                     ;If target area is to the side when climbing, exit
                cmp navAreaL,y
                bcc PF_ClimbExit
                cmp navAreaR,y
                bcs PF_ClimbExit
                lda actYH,x
                cmp navAreaD,y
                bcc PF_MoveDown                 ;If target is below, climb down
                cmp navAreaU,y
                bcs PF_MoveUp
PF_ClimbExit:   lda actYL,x                     ;When exiting ladder, make sure to be at the upper half of block
                asl
                bpl PF_GoToTargetLeftOrRight
PF_MoveUp:      lda #JOY_UP
                rts
PF_MoveDown:    lda #JOY_DOWN
                rts

PF_UprightGoToLadder:
                lda actXH,x
                cmp navAreaL,y
                bne PF_UprightLeftOrRight
                lda navAreaU,y
                bcs PF_GoToTargetClimbingUpOrDown2

PF_GoToTargetLeftOrRight:
                lda actBlockInfo,x              ;Stop if at a large drop
                and #BI_DROP
                bne PF_Stop
                lda targetX
                cmp actXH,x
                beq PF_Stop
                bcc PF_GoToTargetLeft
PF_GoToTargetRight:
PF_MoveRight:   lda #JOY_RIGHT
                rts
PF_GoToTargetLeft:
PF_MoveLeft:    lda #JOY_LEFT
                rts

PF_Upright:     lda navAreaType,y
                cmp #NAVAREA_LADDER
                beq PF_UprightGoToLadder
                bcs PF_UprightGoToStairs
PF_UprightGoToPlatform:
                lda actXH,x                     ;If inside the dest. platform's X range, must be on stairs currently
                cmp navAreaL,y                  ;and need to move to their end
                bcc PF_UprightOutsidePlatform
                cmp navAreaR,y
                bcs PF_UprightOutsidePlatform
PF_UprightGoToStairsEnd:
                lda actYH,x
                cmp navAreaU,y
                ldy srcNavArea
                lda navAreaType,y
                bcc PF_UprightGoToStairsEndNoReverse
                eor #$01
PF_UprightGoToStairsEndNoReverse:
                lsr
PF_UprightGoForward:
                bcs PF_MoveLeft                 ;Upright stairs - move left to get down
                bcc PF_MoveRight                ;Or vice versa
PF_UprightOutsidePlatform:
                lda actMB,x                     ;If wallhit, jump / mantle
                lsr
                bcc PF_UprightLeftOrRight
                lda navAreaU,y
                cmp actYH,x
                bcs PF_UprightLeftOrRight
                lda actCtrl,x
                and #JOY_LEFT|JOY_RIGHT
                beq PF_UprightLeftOrRight       ;Must have sideways controls decided before jumping
                ora #JOY_JUMP
                rts
PF_UprightLeftOrRight:
                lda actXH,x
PF_UprightLeftOrRight2:
                cmp navAreaR,y
                bcs PF_MoveLeft
                cmp navAreaL,y
                bcc PF_MoveRight
PF_Stop2:       lda #$00
                rts
PF_MoveUp2:     lda #JOY_UP
                rts

PF_UprightGoToStairs:
                lda actYH,x
                cmp navAreaD,y
                bne PF_UprightGoToPlatform
                lda navAreaType,y
                lsr
                lda navAreaL,y
                bcs PF_UprightStairsRight
PF_UprightStairsLeft:
                lda navAreaR,y
                sbc #$00                        ;C=0, subtract one more
PF_UprightStairsRight:
                cmp actXH,x                     ;First go to the startpoint coarsely
                bcc PF_MoveLeft
                bne PF_MoveRight
                lda navAreaType,y
                tay
                lda actXL,x                     ;Then within the block
                and #$40
                cmp stairXLTbl-NAVAREA_SLOPEUPRIGHT,y
                beq PF_MoveUp2
                lda stairCtrlTbl-NAVAREA_SLOPEUPRIGHT,y
                rts

        ; Subroutine to find best next target navarea

PF_FindDestNavArea:
                sta actTargetNavArea,x
                tay
                lda navAreaType,y           ;Target on not connected area = no navigation
                bmi PF_FCADone3
                ldx srcNavArea
                ldy #NO_NAVAREA             ;Reset best distance / area so far
                sty bestArea                ;(assume none found)
                sty bestDist
                ldy lastNavArea
PF_FindConnectedArea:
                cpy srcNavArea              ;Skip own area
                beq PF_FCANext
                lda navAreaL,y
                cmp navAreaR,x              ;Connected to the right?
                beq PF_FCACheckHorizontal
                lda navAreaR,y
                cmp navAreaL,x              ;Connected to the left?
                beq PF_FCACheckHorizontal
                lda navAreaD,y              ;Connected above?
                cmp navAreaU,x
                beq PF_FCACheckVertical
                lda navAreaU,y              ;Connected below?
                cmp navAreaD,x
                beq PF_FCACheckVertical
PF_FCANext:     dey
                bpl PF_FindConnectedArea
PF_FCADone:     ldy bestArea
PF_FCADone2:    tya
PF_FCADone3:    ldx actIndex
                sta actDestNavArea,x        ;Best found area, may be negative (none)
                rts
PF_FCACheckHorizontal:
                lda navAreaD,y              ;Check if areas connected vertically
                adc #0                      ;Expand the area vertical bounds to allow mantle / jump / drop (C=1 here)
                cmp navAreaU,x
                bcc PF_FCANext
                lda navAreaU,y
                sbc #2
                cmp navAreaD,x
                bcs PF_FCANext
                bcc PF_FCAAreaOK
PF_FCACheckVertical:
                lda navAreaL,x
                cmp navAreaR,y
                bcs PF_FCANext              ;Check if areas connected horizontally
                lda navAreaL,y
                cmp navAreaR,x
                bcs PF_FCANext
PF_FCAAreaOK:   lda targetX                 ;Check target's distance to candidate area
                cmp navAreaL,y              ;(zero if inside)
                bcc PF_FCATargetLeft
                adc #$01                    ;Add one more - subtract one more
                sbc navAreaR,y
                bcc PF_FCATargetInside
                bcs PF_FCATargetRight
PF_FCATargetLeft:
                sbc navAreaL,y
                eor #$ff
                skip2
PF_FCATargetInside:
                lda #$00
PF_FCATargetRight:
                sta currentDist
                lda targetY
                cmp navAreaU,y
                bcc PF_FCATargetAbove
                adc #$01
                sbc navAreaD,y
                bcc PF_FCATargetInside2
                bcs PF_FCATargetBelow
PF_FCATargetAbove:
                sbc navAreaU,y
                eor #$ff
                skip2
PF_FCATargetInside2:
                lda #$00
PF_FCATargetBelow:
                clc
                adc currentDist
                beq PF_FCADone2             ;Connected area where target is inside is automatically the best
                cmp bestDist
                bcs PF_FCANext              ;Not new best
                sta bestDist
                sty bestArea
                bcc PF_FCANext

        ; Perform line-of-sight check from actor to target
        ;
        ; Parameters: X Actor index, A current target flags
        ; Returns: AI flags updated
        ; Modifies: A,X,Y,temp vars

DoLineCheck:    and #$ff-TF_LINECHECK-TF_HASLINE-TF_HASNAVLINE
                sta actTargetFlags,x
                stx actIndex
                lda #MAX_LINEDIST
                sta lineCount
                lda actYH,x
                sec
                sbc actAimHeight,x
                sta lineY
                sta lineYCopy
                lda actYH,y                     ;Take target height into account
                sbc actHeight,y
                cmp lineY
                beq DLC_NoSwapY
                bcc DLC_NoSwapY                 ;Always go up to not be bothered by shallow slopes
                sta lineY
                txa
                sty loadTempReg
                ldx loadTempReg
                tay
                lda lineYCopy
DLC_NoSwapY:    sta DLC_CmpY+1
                sta DLC_CmpY2+1
                lda actXH,x
                asl
                sta lineX
                lda actXH,y
                asl
                sta DLC_CmpX+1
                sec
                sbc lineX
                bpl DLC_XDistPos
                eor #$ff
                adc #$01
DLC_XDistPos:   lsr                             ;Check if X-dist is more than Y-dist, use a slope in that case
                sta zpSrcLo
                lda lineY
                sec
                sbc DLC_CmpY+1
                ldy #$aa
                cmp zpSrcLo
                bcc DLC_HasSlope
                ldy #$ff
DLC_HasSlope:   sty lineSlope
                ldy lineX
                ldx lineY                       ;Take initial maprow
                lda mapTblLo,x
                sta zpSrcLo
                lda mapTblHi,x
                sta zpSrcHi
DLC_Loop:       lda (zpSrcLo),y
                sta DLC_GetInfo+1
DLC_GetInfo:    lda blkInfo
                and #BI_GROUND|BI_WALL
DLC_InfoCmp:    cmp #BI_WALL
                bcs DLC_HasWall
DLC_CmpX:       cpy #$00
                bcc DLC_MoveRight
                bne DLC_MoveLeft
DLC_CmpY:       cpx #$00
                bne DLC_MoveUp
                beq DLC_HasLine
DLC_MoveRight:  iny
                iny
                bcc DLC_MoveXDone
DLC_MoveLeft:   dey
                dey
DLC_MoveXDone:
DLC_CmpY2:      cpx #$00
                beq DLC_MoveYDone
                asl lineSlope
                bcc DLC_MoveYDone
                inc lineSlope
DLC_MoveUp:     dex
                lda mapTblLo,x
                sta zpSrcLo
                lda mapTblHi,x
                sta zpSrcHi
DLC_MoveYDone:  dec lineCount                   ;Maximum steps reached?
                bne DLC_Loop
DLC_NoLine:     rts
DLC_HasWall:    lsr
                bcc DLC_NoLine
                cpx DLC_CmpY+1
                bne DLC_NoLine                  ;If line is horizontal, and only a groundwall separates the actors,
DLC_HasNavLine: lda #TF_HASNAVLINE              ;has navigation line of sight, though can't fire
                skip2
DLC_HasLine:    lda #TF_HASLINE
                ldx actIndex
SetTargetFlags: ora actTargetFlags,x
                sta actTargetFlags,x
                rts

        ; Update actor's nav area
        ;
        ; Parameters: X actor index
        ; Returns: -
        ; Modifies: A,Y

UpdateNavArea:  lda actMB,x                     ;Skip if not grounded
                bpl UNA_Skip                    ;(also climbing is considered grounded)
                ldy actNavArea,x
                sty UNA_NoWrap+1                ;Store current navarea for wrap check + search startpoint
UNA_Loop:       lda actXH,x
                cmp navAreaL,y
                bcc UNA_Next
                cmp navAreaR,y
                bcs UNA_Next
                lda actYH,x
                cmp navAreaU,y
                bcc UNA_Next
                cmp navAreaD,y
                bcc UNA_Found
UNA_Next:       dey
                bpl UNA_NoWrap
                ldy lastNavArea
UNA_NoWrap:     cpy #$00                        ;Check if search wrapped (no valid area)
                bne UNA_Loop
UNA_Found:      tya
                sta actNavArea,x
UNA_Skip:       rts

        ; Get combined X+Y absolute distance for noise, conversation triggers etc.
        ; Also store target (Y) actor position to targetX & targetY
        ;
        ; Parameters: X & Y actor indices
        ; Returns: A combined distance, loadBufferPos X-distance, targetX & targetY
        ; Modifies: A,loadBufferPos
        
GetCombinedDistance:
                lda actXH,y
                sta targetX
                sec
                sbc actXH,x
                bpl GCD_XDistPos
                eor #$ff
                adc #$01
GCD_XDistPos:   sta loadBufferPos
                lda actYH,y
                sta targetY
                sec
                sbc actYH,x
                bpl GCD_YDistPos
                eor #$ff
                adc #$01
GCD_YDistPos:   clc
                adc loadBufferPos
                rts
