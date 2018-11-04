SCROLLCENTER_X  = 91
SCROLLCENTER_Y  = 165

FR_STAND        = 0
FR_WALK         = 1
FR_JUMP         = 9

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
                and #JOY_LEFT|JOY_RIGHT         ;Check acceleration / turning
                beq MP_DoBrake
                and #JOY_LEFT
                beq MP_DoAccelRight
                lda #$80
MP_DoAccelRight:sta actD,x                      ;Turn
                asl                             ;Dir to carry for acceleration
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
MP_AccelDone:   lda currCtrl
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
                lda #-48                        ;Init jump speed and lift slightly off ground
                sta actSY,x
                lda #-1*8
                jsr MoveActorY
                lda #$ff-MB_GROUNDED
                jsr ClearMovementBits           ;Clear grounded flag
MP_JumpDone:    jsr MoveWithGravity             ;Perform the actual move
                lda actMB,x
                bpl MP_InAirAnim                ;Check animation after move, either on ground or in air
MP_GroundAnim:  lda actSX,x
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

upperFrameTbl:  dc.b 1,  0,1,1,2,2,1,1,0,         0,0,0
lowerFrameTbl:  dc.b 18, 19,20,21,22,23,24,25,26, 29,30,31

                rend

scriptEnd: