IRQ1_LINE       = MIN_SPRY-12
IRQ3_LINE       = SCROLLROWS*8-39
IRQ4_LINE       = SCROLLROWS*8+45
IRQ5_LINE       = 237

TURBO_LINE      = 247

IRQLATE_SAFETY_MARGIN = 3

        ; Raster interrupt 1. Top of gamescreen

Irq1_NoSprites: jmp Irq2_AllDone
Irq1:           sta irqSaveA
                stx irqSaveX
                sty irqSaveY
                inc $01
                if SHOW_SKIPPED_FRAME > 0
                lda newFrameFlag                ;If newframeflag was zero at this point, frame was skipped
                bne Irq1_NoSkippedFrame
                inc $d020
Irq1_NoSkippedFrame:
                endif
                lda #$00
                sta newFrameFlag
                if USETURBOMODE > 0
                sta $d07a                       ;SCPU back to slow mode
                sta $d030                       ;C128 back to 1MHz
                endif                
Irq1_TimerCountLo:
                lda #<((IRQ3_LINE-IRQ1_LINE)*63)
                sta $dc04
Irq1_TimerCountHi:
                lda #>((IRQ3_LINE-IRQ1_LINE)*63)
                sta $dc05
                lda #%00011001
                sta $dc0e                       ;Run CIA1 Timer A once to trigger Irq3
Irq1_ScrollX:   lda #$17
                sta $d016
Irq1_ScrollY:   lda #$57
                sta $d011
Irq1_D018:      lda #GAMESCR_D018
                sta $d018
Irq1_Bg1:       lda #$06
                sta $d021
Irq1_Bg2:       lda #$00
                sta $d022
Irq1_Bg3:       lda #$00
                sta $d023
Irq1_D015:      lda #$00
                sta $d015
                beq Irq1_NoSprites
                lda #<Irq2                      ;Set up the sprite display IRQ
                ldx #>Irq2
                sta $fffe
                stx $ffff
Irq1_FirstSortSpr:
                ldx #$00                        ;Go through the first sprite IRQ immediately
                if SHOW_SPRITEIRQ_TIME > 0
                dec $d020
                endif

        ;Raster interrupt 2. Sprite multiplexer

Irq2_Spr0:      lda sortSprY,x
                sta $d00f
                lda sortSprF,x
                ldy sortSprXExpand,x
                sta screen+$03ff
                sty $d01d
                lda sortSprX,x
                ldy sortSprXMSB,x
                sta $d00e
                sty $d010
                lda sortSprC,x
                sta $d02e
                bmi Irq2_SprIrqDone2
                inx

Irq2_Spr1:      lda sortSprY,x
                sta $d00d
                lda sortSprF,x
                ldy sortSprXExpand,x
                sta screen+$03fe
                sty $d01d
                lda sortSprX,x
                ldy sortSprXMSB,x
                sta $d00c
                sty $d010
                lda sortSprC,x
                sta $d02d
                bmi Irq2_SprIrqDone2
                inx

Irq2_Spr2:      lda sortSprY,x
                sta $d00b
                lda sortSprF,x
                ldy sortSprXExpand,x
                sta screen+$03fd
                sty $d01d
                lda sortSprX,x
                ldy sortSprXMSB,x
                sta $d00a
                sty $d010
                lda sortSprC,x
                sta $d02c
                bmi Irq2_SprIrqDone2
                inx

Irq2_Spr3:      lda sortSprY,x
                sta $d009
                lda sortSprF,x
                ldy sortSprXExpand,x
                sta screen+$03fc
                sty $d01d
                lda sortSprX,x
                ldy sortSprXMSB,x
                sta $d008
                sty $d010
                lda sortSprC,x
                sta $d02b
                bpl Irq2_ToSpr4
Irq2_SprIrqDone2:
                jmp Irq2_SprIrqDone
Irq2_ToSpr4:    inx

Irq2_Spr4:      lda sortSprY,x
                sta $d007
                lda sortSprF,x
                ldy sortSprXExpand,x
                sta screen+$03fb
                sty $d01d
                lda sortSprX,x
                ldy sortSprXMSB,x
                sta $d006
                sty $d010
                lda sortSprC,x
                sta $d02a
                bmi Irq2_SprIrqDone
                inx

Irq2_Spr5:      lda sortSprY,x
                sta $d005
                lda sortSprF,x
                ldy sortSprXExpand,x
                sta screen+$03fa
                sty $d01d
                lda sortSprX,x
                ldy sortSprXMSB,x
                sta $d004
                sty $d010
                lda sortSprC,x
                sta $d029
                bmi Irq2_SprIrqDone
                inx

Irq2_Spr6:      lda sortSprY,x
                sta $d003
                lda sortSprF,x
                ldy sortSprXExpand,x
                sta screen+$03f9
                sty $d01d
                lda sortSprX,x
                ldy sortSprXMSB,x
                sta $d002
                sty $d010
                lda sortSprC,x
                sta $d028
                bmi Irq2_SprIrqDone
                inx

Irq2_Spr7:      lda sortSprY,x
                sta $d001
                lda sortSprF,x
                ldy sortSprXExpand,x
                sta screen+$03f8
                sty $d01d
                lda sortSprX,x
                ldy sortSprXMSB,x
                sta $d000
                sty $d010
                lda sortSprC,x
                sta $d027
                bmi Irq2_SprIrqDone
                inx
Irq2_ToSpr0:    jmp Irq2_Spr0

Irq2_SprIrqDone:
                if SHOW_SPRITEIRQ_TIME > 0
                inc $d020
                endif
                cld
                ldy sprIrqLine,x                ;Get startline of next IRQ
                beq Irq2_AllDone                ;(0 if was last)
                inx
                stx Irq2_SprIndex+1             ;Store next IRQ sprite start-index
                txa
                and #$07
                tax
                lda sprIrqJumpTblLo,x           ;Get the correct jump address
                sta Irq2_SprJump+1
                lda sprIrqJumpTblHi,x
                sta Irq2_SprJump+2
                lda fileOpen
                beq Irq2_SprIrqDoneNoLoad
                dey                             ;If loading, execute sprite IRQ one line earlier
Irq2_SprIrqDoneNoLoad:
                tya
                sec
                sbc #IRQLATE_SAFETY_MARGIN      ;Already late?
                cmp $d012
                bcs SetNextIrqNoAddress
                bcc Irq2_Direct                 ;If yes, execute directly

Irq2:           inc $01                         ;Ensure access to IO memory
                bit $dc0d                       ;Update-IRQ?
                bmi Irq3
                sta irqSaveA
                stx irqSaveX
                sty irqSaveY
Irq2_Direct:
                if SHOW_SPRITEIRQ_TIME > 0
                dec $d020
                endif
Irq2_SprIndex:  ldx #$00
Irq2_SprJump:   jmp Irq2_Spr0

Irq2_AllDone:
Irq2_Irq4Line:  ldy #IRQ4_LINE
                lda fileOpen
                beq Irq2_AllDoneNoLoad          ;If loading, execute panelsplit IRQ one line earlier
                dey
Irq2_AllDoneNoLoad:
                lda $d012
Irq2_Irq4LineSafety:
                cmp #IRQ4_LINE-IRQLATE_SAFETY_MARGIN
                bcs Irq4_Direct                 ;Late from the panelsplit IRQ?
                lda #<Irq4
                ldx #>Irq4
SetNextIrq:     sta $fffe
                stx $ffff
SetNextIrqNoAddress:
                sty $d012
                dec $d019                       ;Acknowledge raster IRQ
                dec $01                         ;Restore $01 value
                lda irqSaveA
                ldx irqSaveX
                ldy irqSaveY
                rti

        ; Interrupt 3, run from CIA1 timer A, screen redraw

Irq3:           pha                             ;This may be re-entered, even on successive frames, so must use stack
                txa
                pha
                tya
                pha
                lda $01                         ;Store $01 value to stack, and reset to $35 so that we can read from under the Kernal, and
                pha                             ;further IRQs on top of this can use inc $01 again
                lda #$35
                sta $01
                cli                             ;Allow re-entry
                lda drawScreenFlag              ;Redraw screen requested?
                beq Irq3_NoDrawScreen
Irq3_DrawScreen:if SHOW_FREE_TIME > 0
                lda $d020
                sta Irq3_RestD020+1
                lda #$00
                sta $d020
                endif
                inc drawScreenFlag
                dec newFrameFlag                ;Trigger frameupdate now from here
Irq3_D015:      lda #$00
                sta Irq1_D015+1
Irq3_FirstSortSpr:
                lda #$00
                sta Irq1_FirstSortSpr+1
Irq3_ScrollX:   lda #$00
                sta Irq1_ScrollX+1
Irq3_ScrollY:   lda #$00
                sta Irq1_ScrollY+1
                if SHOW_SCROLLWORK_TIME > 0
                dec $d020
                endif
                jsr DrawScreen                  ;Note: decimal flag is irrelevant for redraw code
                if SHOW_SCROLLWORK_TIME > 0
                inc $d020
                endif
                if SHOW_FREE_TIME > 0
Irq3_RestD020:  lda #$00
                sta $d020
                endif
Irq3_NoDrawScreen:
                pla
                tax
                dex                             ;Restore & decrement $01 value
                stx $01
                pla
                tay
                pla
                tax
                pla
                rti

        ; Raster interrupt 4. Gamescreen / scorepanel split

Irq4:           inc $01                         ;Ensure access to IO memory
                bit $dc0d                       ;Update-IRQ?
                bmi Irq3
                sta irqSaveA
                stx irqSaveX
                sty irqSaveY
Irq4_Direct:    ldy $d011
Irq4_Irq4Line:  ldx #IRQ4_LINE
Irq4_Wait:      cpx $d012
                bcs Irq4_Wait
                ldx irq4DelayTbl-$10,y
Irq4_Delay:     dex
                bpl Irq4_Delay
                lda #$57
                sta $d011
                lda #PANEL_D018
                sta $d018
                lsr newFrameFlag                ;Can update sprite doublebuffer now
Irq4_Irq5Line:  ldy #IRQ5_LINE
                lda fileOpen
                beq Irq4_Irq5NoLoad             ;If file open, take one line advance
                dey
Irq4_Irq5NoLoad:lda #<Irq5
                ldx #>Irq5
                jmp SetNextIrq

        ; Raster interrupt 5. Show scorepanel, play music, animate charset

Irq5:           inc $01                         ;Ensure access to IO memory
                sta irqSaveA
                stx irqSaveX
                sty irqSaveY
                lda #$17
Irq5_Irq5Line:  ldx #IRQ5_LINE
Irq5_Wait:      cpx $d012
                bcs Irq5_Wait
                lda #$00
                sta $d015                       ;Make sure sprites are off for the panel / bottom of screen
                sta $d021
                lda #PANEL_BG1
                sta $d022
                lda #PANEL_BG2
                sta $d023
                lda #$17
                sta $d016                       ;Fixed X-scrolling
                pha
                pla                             ;Delay to adjust the "screen on" write into the border
                pha
                pla
                cld
                sta $d011                       ;Screen on
Irq5_SfxNum:    ldy #$00                        ;Play a new sound this frame?
                beq Irq5_SfxDone
                lda soundMode                   ;Check for sounds disabled
                beq Irq5_SfxDone
Irq5_ChnStart:  ldx #$00
Irq5_ChnLoop:   tya
                cmp chnSfxNum,x                 ;Check for same or lower priority
                bcs Irq5_ChnFound
Irq5_ChnNext:   lda nextChnTbl,x
                tax
                cmp Irq5_ChnStart+1             ;Terminate if reached search startpoint
                bne Irq5_ChnLoop
                beq Irq5_SfxDone
Irq5_ChnFound:  sta chnSfxNum,x
                lda nextChnTbl,x
                sta Irq5_ChnStart+1             ;Store next channel as startpoint for next search
                lda #$00
                sta chnSfxPos,x
Irq5_SfxDone:   ldx #$00                        ;Reset for next frame
                stx Irq5_SfxNum+1               ;Clear also soundflag in case next frame is late
                if SHOW_PLAYROUTINE_TIME > 0
                dec $d020
                endif
                jsr PlayRoutine
                if SHOW_PLAYROUTINE_TIME > 0
                inc $d020
                endif
Irq5_CharAnimFlag:
                lda #$00                        ;Animate charset if appropriate
                beq Irq5_NoCharAnim
                if SHOW_CHARSETANIM_TIME > 0
                dec $d020
                endif
                dec $01                         ;Restore original $01 value to be sure RAM access is available
                jsr charAnimCodeJump            ;(char anim code should only touch the charset)
                inc $01
                if SHOW_CHARSETANIM_TIME > 0
                inc $d020
                endif
Irq5_NoCharAnim:
                if USETURBOMODE > 0
Irq5_TurboCheck:ldx #$ff
                bne Irq5_End
Irq5_TurboWait: lda $d011                       ;Wait for bottom of screen to avoid glitching on C128
                bmi Irq5_TurboOK
                lda $d012
                cmp #TURBO_LINE
                bcc Irq5_TurboWait
Irq5_TurboOK:   inx
                stx $d07b                       ;SCPU turbo mode & C128 2MHz mode enable
                stx $d030                       ;if not loading
                endif
Irq5_End:       lda #<Irq1                      ;Back to first IRQ
                ldx #>Irq1
                ldy #IRQ1_LINE
                jmp SetNextIrq

        ; IRQ redirector when Kernal is on

RedirectIrq:    ldx $01                         ;On IDE64 we cannot assume what this value will be, so save/restore
                lda #$35                        ;Note: this will necessarily have overhead,
                sta $01                         ;which means that the sensitive IRQs like
                lda #>RI_Return                 ;the panel-split should take extra advance
                pha
                lda #<RI_Return
                pha
                php
                jmp ($fffe)
RI_Return:      stx $01
                jmp $ea81
