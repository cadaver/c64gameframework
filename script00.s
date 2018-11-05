SCROLLCENTER_X  = 91
SCROLLCENTER_Y  = 165

FR_STAND        = 0
FR_WALK         = 1
FR_JUMP         = 9
FR_DUCK         = 12
FR_CLIMB        = 14


                include macros.s
                include memory.s
                include mainsym.s

                org $0000

        ; Note! Code must be unambiguous! Relocated code cannot have skip1/skip2 -macros!

                dc.w scriptEnd-scriptStart      ;Chunk data size
                dc.b 2                          ;Number of objects

scriptStart:
                rorg scriptCodeRelocStart       ;Initial relocation address when loaded

                dc.w MovePlayer                 ;$0000
                dc.w DrawPlayer                 ;$0001

        ; Player actor move routine
        ;
        ; Parameters: X Actor index
        ; Returns: -
        ; Modifies: A,Y,zeropage

MovePlayer:     lda actMoveCtrl,x               ;Copy last frame's controls to previous
                sta actPrevCtrl,x
                lda joystick                    ;Copy current frame's controls from joystick input
                sta actMoveCtrl,x
                sta currCtrl
                ldy actState,x                  ;Check state (walking or climbing)
                beq MP_UprightState
                jmp MP_ClimbingState

        ; Upright movement (walk / jump / duck)

MP_UprightState:and #JOY_LEFT|JOY_RIGHT         ;Check acceleration / turning
                beq MP_DoBrake
                and #JOY_LEFT
                beq MP_DoAccelRight
                lda #$80
MP_DoAccelRight:sta actD,x                      ;Turn
                asl                             ;Dir to carry for acceleration
                lda currCtrl
                and #JOY_DOWN                   ;If ducking, brake instead of accelerating
                bne MP_DoBrake
                lda #10
                ldy actMB,x                     ;Check if in air, slower acceleration in that case
                bmi MP_AccelGround
                lda #4
MP_AccelGround: ldy #4*8                        ;Max. speed 4 pixels per actor update (2 pixels per frame)
                jsr AccActorXNegOrPos
                jmp MP_AccelDone
MP_DoBrake:     lda actMB,x                     ;Do not brake if in air
                bpl MP_AccelDone
                lda #10
                jsr BrakeActorX
MP_AccelDone:   lda currCtrl                    ;Check for up (climb / grab)
                lsr
                bcc MP_NoInitClimbUp
                lda #-1
                jsr GetBlockInfoY               ;Check for ladder above feet
                and #BI_CLIMB
                beq MP_NoInitClimbUp
                lda actSY,x                     ;If in air and going up, check for Y-speed being low enough to prevent immediate re-grab after ladder jump exit
                bpl MP_InitClimb
                cmp #-3*8
                bcc MP_NoInitClimbUp
MP_InitClimb:   lda #FR_CLIMB                   ;Switch to climbing state
                sta actF1,x
                lda #STATE_CLIMB
                sta actState,x
                lda actYL,x                     ;Align Y on char boundary
                and #$40
                sta actYL,x
                lda #$40
                sta actXL,x                     ;Align to center of block
                asl
                sta actFd,x                     ;Initialize climb animation delay
                jmp ResetSpeed                  ;Reset X & Y speed
MP_NoInitClimbUp:
                lda currCtrl
                and #JOY_JUMP                   ;Check for jumping, either up dir or second joystick button
                beq MP_JumpDone
                lda actMB,x                     ;If on ground, can begin new jump
                bmi MP_CheckNewJump             ;If in air and going up, can prolong jump by holding joystick up
                lda actSY,x
                bpl MP_JumpDone
                sec
                sbc #3
                sta actSY,x
                jmp MP_JumpDone
MP_CheckNewJump:lda actPrevCtrl,x
                and #JOY_JUMP                   ;Must be rising edge (ie. not pressed last frame)
                bne MP_JumpDone
MP_InitJump:    lda #-48                        ;Init jump speed and lift slightly off ground
                sta actSY,x
                lda #-1*8
                jsr MoveActorY
                lda #$ff-MB_GROUNDED
                jsr ClearMovementBits           ;Clear grounded flag
MP_JumpDone:    jsr MoveWithGravity             ;Perform the actual move
                lda actMB,x
                bpl MP_InAirAnim                ;Check animation after move, either on ground or in air
MP_GroundAnim:  lda actF1,x
                cmp #FR_DUCK
                bcs MP_DuckAnim                 ;Check for ongoing duck animation
                lda currCtrl
                and #JOY_DOWN                   ;Check for initiating ducking or climbing down
                beq MP_NoInitDuck
                jsr GetBlockInfo
                and #BI_CLIMB
                beq MP_NoInitClimbDown
                jmp MP_InitClimb
MP_NoInitClimbDown:
                lda #0
                sta actFd,x
                lda #FR_DUCK
                bne MP_AnimDone
MP_NoInitDuck:  lda actSX,x
                beq MP_StandAnim                ;Speed 0 = stand frame
MP_WalkAnim:    asl
                asl
                bcc MP_WalkAnimSpeedPos
                eor #$ff
                adc #$00
MP_WalkAnimSpeedPos:
                adc actFd,x
                sta actFd,x
                bcc MP_AnimDone2
                lda actF1,x
                adc #$00
                cmp #FR_WALK+8
                bcc MP_AnimDone
                lda #FR_WALK
MP_StandAnim:
MP_AnimDone:    sta actF1,x
MP_AnimDone2:   rts
MP_InAirAnim:   ldy #FR_JUMP                    ;Choose jump animation frame based on absolute Y speed
                lda actSY,x
                bpl MP_InAirDown
                eor #$ff
                clc
                adc #$01
MP_InAirDown:   cmp #4*8
                bcs MP_JumpAnimDone
                iny
                cmp #2*8
                bcs MP_JumpAnimDone
                iny
                bne MP_JumpAnimDone
MP_JumpAnimDone:tya
                jmp MP_AnimDone
MP_DuckAnim:    lda currCtrl
                and #JOY_DOWN
                beq MP_DuckStandAnim
MP_DuckAnimFrameOK:
                lda #1
                ldy #FR_DUCK+1
                jmp OneShotAnimation
MP_DuckStandAnim:
                lda #FR_DUCK
                sta actF1,x
                lda #3                          ;Stand up from ducking
                jsr AnimationDelay
                bcc MP_AnimDone2
                lda #FR_STAND
                beq MP_AnimDone

        ; Climbing movement

MP_ClimbingState:
                sta xLo                         ;Store blockinfo at feet
                jsr ResetSpeed                  ;Reset speed so that any damage impulse doesn't accumulate
                lda currCtrl
                lsr
                bcs MP_ClimbUp                  ;Check up control
MP_NoClimbUp:   lsr
                php
                jsr GetBlockInfo                ;Get blockinfo at feet for down / exit
                sta xLo
                plp
                bcs MP_ClimbDown                ;Check down control
                lda currCtrl                    ;Exit ladder?
                and #JOY_LEFT|JOY_RIGHT
                beq MP_ClimbDone
                lda xLo                         ;Exit if at a platform
                lsr
                bcs MP_ClimbExit
                lda actYL,x                     ;Check also below if on block's lower half
                asl
                bpl MP_ClimbDone
                lda #1
                jsr GetBlockInfoY
                lsr
                bcc MP_ClimbDone
                inc actYH,x
MP_ClimbExit:   lda #$00
                sta actYL,x
                lda #MB_GROUNDED
                jsr SetMovementBits
                jsr NoInterpolation
MP_ExitToUpright:
                lda #STATE_UPRIGHT
                sta actState,x
                lda #FR_WALK
                jmp MP_AnimDone
MP_ClimbDown:   ldy #2*8
                lda xLo
                and #BI_CLIMB
                bne MP_ClimbCommon
MP_ClimbDone:   rts
MP_ClimbUp:     lda currCtrl                    ;Check for jump exit
                cmp actPrevCtrl,x
                beq MP_NoJumpExit               ;Must be a rising edge control
                and #JOY_LEFT|JOY_RIGHT
                beq MP_NoJumpExit
                ldy #2*8                        ;Set X-speed on jump exit to prevent regrabbing the same ladder
                and #JOY_RIGHT
                bne MP_JumpExitRight
                ldy #-2*8
MP_JumpExitRight:
                tya
                sta actSX,x
                jsr MP_ExitToUpright
                jmp MP_InitJump
MP_NoJumpExit:  lda actYL,x                     ;If will cross to block above, check whether ladder continues
                bne MP_ClimbUpOK
                lda #-1
                jsr GetBlockInfoY
                and #BI_CLIMB
                beq MP_ClimbDone
MP_ClimbUpOK:   ldy #-2*8                       ;If about to cross to the block above, check whether ladder continues above
MP_ClimbCommon: lda actFd,x
                clc
                adc #$c0
                sta actFd,x
                bcc MP_ClimbDone
                lda #$01                        ;Add 1 or 7 depending on climbing dir
                cpy #$80
                bcc MP_ClimbAnimDown
                lda #$06                        ;C=1, add one less
MP_ClimbAnimDown:
                adc actF1,x
                sbc #FR_CLIMB-1                 ;Keep within climb frame range
                and #$07
                adc #FR_CLIMB-1
                sta actF1,x
                tya
                jsr MoveActorY
                jmp NoInterpolation

        ; Player actor draw routine. Also do scrolling
        ;
        ; Parameters: X Actor index
        ; Returns: -
        ; Modifies: A,Y,zeropage

DrawPlayer:     lda yLo                         ;No scrolling during GetConnectPoint handling (fake actor draw)
                beq DP_SkipScroll
                lda #-SCROLLCENTER_X            ;Check horizontal scrolling from player sprite's render position
                clc
                adc xLo
                bmi DP_ScrollLeft
DP_ScrollRight: cmp #3*8
                bcc DP_ScrollHorizOK
                lda #3*8
                bne DP_ScrollHorizOK
DP_ScrollLeft:  cmp #-3*8
                bcs DP_ScrollHorizOK
                lda #-3*8
DP_ScrollHorizOK:
                sta scrollSX
                lda #-SCROLLCENTER_Y            ;And vertical scrolling
                clc
                adc yLo
                bmi DP_ScrollUp
DP_ScrollDown:  lsr
                cmp #4*8
                bcc DP_ScrollVertOK
                lda #4*8
                bne DP_ScrollVertOK
DP_ScrollUp:    lsr
                ora #$80
                cmp #-4*8
                bcs DP_ScrollVertOK
                lda #-4*8
DP_ScrollVertOK:sta scrollSY
DP_SkipScroll:  ldy actF1,x                     ;Draw lower part sprite, followed by upper. Take facing dir into account
                lda lowerFrameTbl,y
                ldy #C_PLAYER
                jsr DrawLogicalSpriteDir
                ldy actF1,x
                lda upperFrameTbl,y
                ldy #C_PLAYER
                jmp DrawLogicalSpriteDir

                brk                             ;End relocation

upperFrameTbl:  dc.b 1,  0,1,1,2,2,1,1,0,         0,0,0,    1,1,    15,14,13,14,15,16,17,16
lowerFrameTbl:  dc.b 18, 19,20,21,22,23,24,25,26, 29,30,31, 27,28,  36,35,34,35,36,37,38,37

                rend

scriptEnd: