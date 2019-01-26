                org fileAreaStart

NUM_PANELROW_LOCATIONS = 2

        ; Initialize registers/variables at startup. This code is called only once and can be
        ; disposed after that.
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,temp vars

InitAll:        sei

        ; Setup preparations for loading

                lda loaderMode
                beq IA_UseSafeMode
                bpl InitZeroPage
IA_UseFastLoad: lda #<SetSpriteRange                        ;Fastload: setup safe Y-coordinate range for 2bit transfer
                sta FL_SetSpriteRangeJsr+1
                lda #>SetSpriteRange
                sta FL_SetSpriteRangeJsr+2
                bne InitZeroPage
IA_UseSafeMode: ldx #stopIrqCodeEnd-stopIrqCode-1           ;Safe mode: setup screen blanking on load begin
IA_CopyStopIrqCode:
                lda stopIrqCode,x
                sta StopIrq,x
                dex
                bpl IA_CopyStopIrqCode

        ; Initialize other zeropage values

InitZeroPage:   lda #<fileAreaStart
                sta freeMemLo
                lda #>fileAreaStart
                sta freeMemHi
                lda #>fileAreaEnd
                sta musicDataHi
                sta zoneBufferHi
                lda #38
                sta textRightMargin
                lda #1
                sta cacheFrame
                lda #NO_LEVEL
                sta levelNum
                sta autoDeactObj
                lda #$00
                sta textLeftMargin
                sta musicDataLo
                sta zoneBufferLo
                sta newFrameFlag
                sta drawScreenFlag
                sta firstSortSpr
                sta numSpr
                sta nextLvlActIndex
                sta textTime
                sta frameNumber

                jsr WaitBottom
                lda #$0b                        ;Blank screen now
                sta $d011

        ; Initialize sprite multiplexing order

InitSprites:    ldx #MAX_SPR
ISpr_Loop:      txa
                sta sprOrder,x
                lda #$ff
                sta sprY,x
                dex
                bpl ISpr_Loop

        ; Initialize sprite cache variables + the empty sprite

                ldx #$3f
ISprC_Loop:     lda #$ff
                sta cacheSprFile,x
                lda #$00
                sta cacheSprAge,x
                sta emptySprite,x
                dex
                bpl ISprC_Loop

        ; Initialize video + SID registers

InitVideo:      sta $d01b                       ;Sprites on top of BG
                sta $d01d                       ;Sprite X-expand off
                sta $d017                       ;Sprite Y-expand off
                sta $d020
                sta $d026                       ;Set sprite multicolor 2
                sta $d415                       ;Filter lowbyte for all subsequent music
                lda $dd00                       ;Only videobank 0 supported due to the disk fastloader
                and #$fc
                sta $dd00
                lda #$ff-$40                    ;Init reading joystick + select reading port 2 paddles for 2nd firebutton
                sta $dc00
                lda #$01
                sta $d025                       ;Set sprite multicolor 1
                lda #$ff                        ;Set all sprites multicolor
                sta $d01c
                ldx #$10
IV_SpriteY:     dex
                dex
                sta $d001,x
                bne IV_SpriteY
                sta $d015                       ;All sprites on and to the bottom
                jsr WaitBottom                  ;(some C64's need to "warm up" sprites
                                                ;to avoid one frame flash when they're
                stx $d015                       ;actually used for the first time)

        ; SID detection from http://codebase64.org/doku.php?id=base:detecting_sid_type_-_safe_method

                lda #$ff    ;Set frequency in voice 3 to $ffff
                sta $d412   ;...and set testbit (other bits doesn't matter) in $d412 to disable oscillator
                sta $d40e
                sta $d40f
                lda #$20    ;Sawtooth wave and gatebit OFF to start oscillator again.
                sta $d412
                lda $d41b   ;Accu now has different value depending on sid model (6581=3/8580=2)
                cmp #$02    ;If result out of bounds, it's fast emu or something; use 6581 code (skip filter modify)
                beq SIDDetect_8580
SIDDetect_6581: lda #$4c
                sta Play_ModifyCutoff8580
                lda #<Play_CutoffOK
                sta Play_ModifyCutoff8580+1
                lda #>Play_CutoffOK
                sta Play_ModifyCutoff8580+2
SIDDetect_8580:

        ; Init text charset + clear panel screen RAM

InitPanelChars: ldy #$04
IPC_Loop:       lda panelCharData,x
IPC_Sta:        sta panelChars,x
                inx
                bne IPC_Loop
                inc IPC_Loop+2
                inc IPC_Sta+2
                dey
                bne IPC_Loop
                ldx #79
IPC_PanelScreenLoop:
                lda #$20
                if NTSCSIZEREDUCE > 0
                sta panelScreen+21*40,x         ;Clear also the one row above if scrolling area may be reduced
                endif
                sta panelScreen+22*40,x
                lda #$00
                sta colors+22*40,x
                dex
                bpl IPC_PanelScreenLoop
                ldx #$07
IPC_PanelSpriteLoop:
                lda #(emptySprite-videoBank)/$40
                sta panelScreen+$3f8,x
                dex
                bpl IPC_PanelSpriteLoop
                lda #$60                        ;Prevent crash if charset animation attempted without charset
                sta charAnimCodeJump

        ; Initialize resources
        
                ldx #MAX_CHUNKFILES
                lda #$00
IR_Loop:        sta fileHi,x
                sta fileAge,x
                dex
                bpl IR_Loop

        ; Initialize PAL/NTSC differences

                ldx #<((IRQ3_LINE-IRQ1_LINE)*63)
                ldy #>((IRQ3_LINE-IRQ1_LINE)*63)
                lda ntscFlag
                beq IA_IsPAL
                ldx #<((IRQ3_LINE-IRQ1_LINE)*65)
                ldy #>((IRQ3_LINE-IRQ1_LINE)*65)
IA_IsPAL:       stx Irq1_TimerCountLo+1
                sty Irq1_TimerCountHi+1
                if USETURBOMODE > 0
                lda $d030                       ;Enable IRQ code for turbo switching for C128 & SCPU
                cmp #$ff
                bne IA_UseTurbo
                lda $d0bc
                bmi IA_NoTurbo
IA_UseTurbo:    lda #$a6
                sta Irq5_TurboCheck
                lda #<fileOpen
                sta Irq5_TurboCheck+1
                bne IA_NoNtscPatch              ;If can use turbo mode, do not reduce scrolling area
                endif
IA_NoTurbo:     if NTSCSIZEREDUCE > 0
                lda ntscFlag
                beq IA_NoNtscPatch
                jsr ApplyNtscPatch
                endif
IA_NoNtscPatch:

        ; Initialize IRQs

InitRaster:     lda #<RedirectIrq               ;Setup "Kernal on" IRQ redirector
                sta $0314
                lda #>RedirectIrq
                sta $0315
                lda #<Irq1                      ;Set initial IRQ vector
                sta $fffe
                lda #>Irq1
                sta $ffff
                lda #IRQ1_LINE                  ;Line where next IRQ happens
                sta $d012
                lda #$00
                sta $dc0e                       ;Stop CIA1 timer A
                lda #$81
                sta $dc0d                       ;But enable timer IRQ from it
                lda #$01                        ;Enable raster IRQs
                sta $d01a
                lda $dc0d                       ;Acknowledge any pending IRQs at this point
                dec $d019
                cli

        ; Initialization done, return to mainloop

                rts

        ; Silence SID, blank screen & and stop raster IRQs. Used when beginning fallback mode loading

stopIrqCode:
                jsr WaitBottom
                jsr SilenceSID
                sta $d01a                       ;Raster IRQs off
                sta $d011                       ;Blank screen completely
                rts
stopIrqCodeEnd:

                if NTSCSIZEREDUCE > 0

        ; NTSC patch for one less scrolling row

ApplyNtscPatch: lda #IRQ4_LINE-8
                sta Irq2_Irq4Line+1
                sta Irq4_Irq4Line+1
                lda #IRQ4_LINE-IRQLATE_SAFETY_MARGIN-8
                sta Irq2_Irq4LineSafety+1
                lda #IRQ5_LINE-8
                sta Irq4_Irq5Line+1
                sta Irq5_Irq5Line+1
                lda #MAX_SPRY-8
                sta DLS_MaxSprYCmp1+1
                sta DLS_MaxSprYCmp2+1
                ldx #NUM_PANELROW_LOCATIONS-1
ANP_PanelRowPatchLoop:
                lda panelRowTblLo,x             ;Patch scorepanel printing accesses
                sta zpDestLo
                lda panelRowTblHi,x
                sta zpDestHi
                ldy #1
                lda (zpDestLo),y
                sec
                sbc #40
                sta (zpDestLo),y
                iny
                lda (zpDestLo),y
                sbc #0
                sta (zpDestLo),y
                dex
                bpl ANP_PanelRowPatchLoop
                lda #<patchedPrepareDrawScreenCode
                sta zpSrcLo
                lda #>patchedPrepareDrawScreenCode
                sta zpSrcHi
                lda #<PrepareDrawScreen
                sta zpDestLo
                lda #>PrepareDrawScreen
                sta zpDestHi
                lda #<(PatchedPrepareDrawScreenEnd-PatchedPrepareDrawScreen)
                sta zpBitsLo
                lda #>(PatchedPrepareDrawScreenEnd-PatchedPrepareDrawScreen)
                sta zpBitsHi
                jsr CopyMemory
                lda #<patchedDrawScreenCode
                sta zpSrcLo
                lda #>patchedDrawScreenCode
                sta zpSrcHi
                lda #<DrawScreenPatchStart
                sta zpDestLo
                lda #>DrawScreenPatchStart
                sta zpDestHi
                lda #<(PatchedDrawScreenEnd-DrawScreenPatchStart)
                sta zpBitsLo
                lda #>(PatchedDrawScreenEnd-DrawScreenPatchStart)
                sta zpBitsHi
                jsr CopyMemory
                lda #<PDSRow10
                sta lowerHalfJumpTblLo
                lda #<PDSBottomRow
                sta lowerHalfJumpTblLo+1
                lda #>PDSRow10
                sta lowerHalfJumpTblHi
                lda #>PDSBottomRow
                sta lowerHalfJumpTblHi+1
                ldx #39                         ;In case we use the panel flashing, fill the row below with solid black chars
                lda #35
ANP_PanelRowLoop:
                sta panelScreen+23*40,x
                dex
                bpl ANP_PanelRowLoop

                rts

patchedPrepareDrawScreenCode:

                rorg PrepareDrawScreen
PatchedPrepareDrawScreen:
                lda blockY
                sta dsBlockY
                tay
                asl
                adc blockX
                tax
                lda dsStartTbl,x
                sta dsStartX
                lda dsEndTbl,y
                sta DSUpperHalfEndCmp+1
                sta PDSLowerHalfEndCmp+1
                lda upperHalfJumpTblLo,y
                sta DSUpperHalfJump+1
                lda upperHalfJumpTblHi,y
                sta DSUpperHalfJump+2
                lda lowerHalfJumpTblLo,y
                sta PDSLowerHalfJump+1
                lda lowerHalfJumpTblHi,y
                sta PDSLowerHalfJump+2
                lda blockX
                sta dsBlockX
                adc mapX
                asl
                tay
                lda #$00
                sta UF_BlockUpdateFlag+1        ;Clear blockupdates now
                sta scrCounter                  ;And reset scrollcounter
                rol
                pha
                tya
                sbc dsOffsetTbl,x               ;C=0 here
                tax
                pla
                sbc #$00
                sta zpSrcHi
                ldy mapY
                lda blockY
                beq PPDS_BlockY0
                iny
PPDS_BlockY0:   if RIGHTCLIPPING = 0
                loadrow DSRow0,DSLeft0,0
                loadrow DSRow1,DSLeft1,1
                loadrow DSRow2,DSLeft2,2
                loadrow DSRow3,DSLeft3,3
                loadrow DSRow4,DSLeft4,4
                loadrow DSRow5,DSLeft5,5
                loadrow PDSRow6,PDSLeft6,6
                loadrow PDSRow7,PDSLeft7,7
                loadrow PDSRow8,PDSLeft8,8
                loadrow PDSRow9,PDSLeft9,9
                lda blockY
                beq PPDS_SkipLoadTop
                loadrow DSTopRow,DSTopLeft,-1
                loadrow PDSBottomRow,PDSBottomLeft,10
                rts
PPDS_SkipLoadTop:
                loadrow PDSRow10,PDSLeft10,10
                rts
                else
                loadrow DSRow0,DSRight0,DSLeft0,0
                loadrow DSRow1,DSRight1,DSLeft1,1
                loadrow DSRow2,DSRight2,DSLeft2,2
                loadrow DSRow3,DSRight3,DSLeft3,3
                loadrow DSRow4,DSRight4,DSLeft4,4
                loadrow DSRow5,DSRight5,DSLeft5,5
                loadrow PDSRow6,PDSRight6,PDSLeft6,6
                loadrow PDSRow7,PDSRight7,PDSLeft7,7
                loadrow PDSRow8,PDSRight8,PDSLeft8,8
                loadrow PDSRow9,PDSRight9,PDSLeft9,9
                lda blockY
                beq PPDS_SkipLoadTop
                loadrow DSTopRow,DSTopRight,DSTopLeft,-1
                loadrow PDSBottomRow,PDSBottomRight,PDSBottomLeft,10
                rts
PPDS_SkipLoadTop:
                loadrow PDSRow10,PDSRight10,PDSLeft10,10
                rts
                endif
PatchedPrepareDrawScreenEnd:
                rend

patchedDrawScreenCode:

                rorg DrawScreenPatchStart
                ldx dsStartX
                lda dsBlockX
                bne PDSLowerHalfLeft
                jmp PDSLowerHalfNoLeft
PDSLowerHalfLeft:
                lda dsBlockY
                bne PDSBottomLeft
PDSLeft10:      drawright 10*80-1
                bcc PDSLeft6
PDSBottomLeft:  drawtopright 11*80-40
PDSLeft6:       drawright 6*80-1
PDSLeft7:       drawright 7*80-1
PDSLeft8:       drawright 8*80-1
PDSLeft9:       drawright 9*80-1
                inx
                inx
PDSLowerHalfNoLeft:
                lda dsBlockY
                bne PDSBottomRow
PDSRow10:       drawfullblockexit 10*80-1,PDSRow6
PDSBottomRow:   drawtop 10*80-1
PDSRow6:        drawfullblock 6*80-1
PDSRow7:        drawfullblock 7*80-1
PDSRow8:        drawfullblock 8*80-1
PDSRow9:        drawfullblock 9*80-1
PDSLowerHalfEndCmp:
                cpx #38
                bcs PDSLowerHalfDone
                inx
                inx
PDSLowerHalfJump:jmp PDSRow10
PDSLowerHalfDone:if RIGHTCLIPPING > 0
                clc
                lda dsBlockX
                beq PDSLowerHalfRight
                jmp PDSLowerHalfNoRight
PDSLowerHalfRight:
                inx
                inx
                lda dsBlockY
                bne PDSBottomRight
PDSRight10:     drawleft 10*80-1
                bcc PDSRight6
PDSBottomRight: drawtopleft 11*80+38-40
PDSRight6:      drawleft 6*80-1
PDSRight7:      drawleft 7*80-1
PDSRight8:      drawleft 8*80-1
PDSRight9:      drawleft 9*80-1
PDSLowerHalfNoRight:
                endif
                rts
PatchedDrawScreenEnd:
                rend

                if PatchedPrepareDrawScreenEnd > PrepareDrawScreenEnd
                    err
                endif
                if PatchedDrawScreenEnd > DrawScreenEnd
                    err
                endif

panelRowTblLo:  dc.b <PanelRowAccess1
                dc.b <PanelRowAccess2

panelRowTblHi:  dc.b >PanelRowAccess1
                dc.b >PanelRowAccess2
                
                endif

        ; Data

defaultConfig:  incbin config.bin

panelCharData:  incbin bg\scorescr.chr

