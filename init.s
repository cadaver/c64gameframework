                org fileAreaStart

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
                sta dsTopPtrLo
                sta dsBottomPtrLo

                jsr WaitBottom
                lda #$0b                        ;Blank screen now
                sta $d011

        ; Initialize video + SID registers

InitVideo:      lda #$00
                sta $d01b                       ;Sprites on top of BG
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

        ; Initialize sprite cache variables + the empty sprite

                ldx #$3f
ISprC_Loop:     lda #$ff
                sta cacheSprFile,x
                lda #$00
                sta cacheSprAge,x
                sta emptySprite,x
                dex
                bpl ISprC_Loop

        ; Initialize resources

                ldx #MAX_CHUNKFILES
IR_Loop:        sta fileHi,x
                sta fileAge,x
                dex
                bpl IR_Loop

        ; Initialize sprite multiplexing order & sprite Y coords

InitSprites:    ldx #MAX_SPR
ISpr_Loop:      txa
                sta sprOrder,x
                lda #$ff
                sta sprY,x
                dex
                bpl ISpr_Loop

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
                endif
IA_NoTurbo:

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

        ; Data

panelCharData:  incbin bg\scorescr.chr

