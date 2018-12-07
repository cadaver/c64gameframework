PANEL_BG1       = $0c
PANEL_BG2       = $0b
GAMESCR_D018    = $ea
TEXTSCR_D018    = $e8
PANEL_D018      = $88

MIN_SPRX        = 9
MAX_SPRX        = 337
MAX_SPRX_EXPANDED = $1e8
MIN_SPRY        = 34
MAX_SPRY        = IRQ4_LINE+1

SPR_TOP_SAFETY  = 4
SPR_BOTTOM_SAFETY = 21

        ; Wait for bottom of screen
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A

WaitBottom:     lda $d011                       ;Wait until bottom of screen
                bmi WaitBottom
WB_Loop2:       lda $d011
                bpl WB_Loop2
                rts

        ; Redraw game map
        ;
        ; Parameters: -
        ; Returns: A=0
        ; Modifies: A

RedrawScreen:   jsr BlankScreen
                lda #$00
                ldx #blockY-scrollX
RS_ClearScrollVars:
                sta scrollX,x
                dex
                bpl RS_ClearScrollVars
                jsr RS_ToggleOptimize
                jsr GetZoneObject
                ldy #ZONEH_BG1
                lda (zpSrcLo),y                 ;Set zone colors
                sta Irq1_Bg1+1
                iny
                lda (zpSrcLo),y
                sta Irq1_Bg2+1
                iny
                lda (zpSrcLo),y
                sta Irq1_Bg3+1
                lda #GAMESCR_D018
                sta Irq1_D018+1
                jsr PrepareDrawScreen
                jsr DrawScreen
RS_ToggleOptimize:
                ldx #$00                        ;During redraw, draw colors to all blocks
RS_ToggleOptimizeLoop:
                lda blkColors,x                 ;Then re-enable optimizing mode for scrolling
                asl                             ;Check bit 6
                bpl RS_ToggleOptimizeSkip
                ror
                eor #$80
                sta blkColors,x
RS_ToggleOptimizeSkip:
                inx
                bpl RS_ToggleOptimizeLoop
                rts

        ; Set sprite Y-range for fastload. Called before the load operation.
        ; Note: must not be called with IRQs off
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y

SetSpriteRange: lda newFrameFlag
                bne SetSpriteRange
                lda Irq1_D015+1
                beq SSR_NoSprites
                ldx Irq1_FirstSortSpr+1
                lda sortSprY,x
                sec
                sbc #SPR_TOP_SAFETY
                sta FL_MinSprY+1
SSR_LastSortSpr:ldx #$00
                lda sortSprY-1,x
                adc #SPR_BOTTOM_SAFETY          ;C=1, add one more
SSR_NoSprites:  sta FL_MaxSprY+1
                rts

        ; Blank screen & turn off sprites
        ;
        ; Parameters: -
        ; Returns: A=0
        ; Modifies: A

BlankScreen:    jsr WaitBottom
                lda #$57                        ;Blank screen & remove sprites
                sta Irq1_ScrollX+1
                sta Irq1_ScrollY+1
                lda #$00
                sta Irq1_D015+1
                sta drawScreenFlag              ;Cancel drawscreen in case it's still pending
                sta Irq5_CharAnimFlag+1         ;Disable charset animation if we're going to load
                rts

        ; Perform scrolling logic
        ;
        ; Parameters: -
        ; Returns: X,Y subtract lowbyte for X & Y actor render
        ; Modifies: A,X,Y

ScrollLogic:    ldy scrCounter
                bne SL_SecondFrame
SL_FirstFrame:  lda scrollSX                    ;Check if already at right edge
                bmi SL_NoLimitXPre
                lda mapX
SL_MapXLimit:   cmp #$00
                bcs SL_LimitXPre
SL_NoLimitXPre: lda scrollX
                clc
                adc scrollSX
                bpl SL_LimitXOK1
SL_LimitXPre:   lda #$00
SL_LimitXOK1:   cmp #$40
                bcc SL_LimitXOK2
                lda #$3f
SL_LimitXOK2:   sta scrollX
                lda scrollSY
                bmi SL_NoLimitYPre              ;Check if already at bottom edge
                lda mapY
SL_MapYLimit:   cmp #$00
                bcs SL_LimitYPre
SL_NoLimitYPre: lda scrollY                     ;Add scrolling speed, limit inside char for this frame
                clc
                adc scrollSY
                bpl SL_LimitYOK1
SL_LimitYPre:   lda #$00
SL_LimitYOK1:   cmp #$40
                bcc SL_LimitYOK2
                lda #$3f
SL_LimitYOK2:   sta scrollY
SL_CalcSprSub:  lda blockX
                lsr                             ;Bit 1 to carry
                ror                             ;$80 or $00
                ror                             ;$40 or $00
                ora scrollX
                and #$70
                sbc #$78-1                      ;C=0
                and #$78
                tax
                lda mapX
                sbc #$02
                sta DA_SprSubXH+1
                lda blockY
                lsr
                ror
                ror
                ora scrollY
                sbc #$30-1                      ;C=0
                and #$78
                tay
                lda mapY
                sbc #$03
                sta DA_SprSubYH+1
                rts

SL_SecondFrame:
SL_PrecalcX:    lda #$00
                sta scrollX
SL_PrecalcY:    lda #$00
                sta scrollY
                bpl SL_CalcSprSub

        ; Update frame. Followed by scorepanel update.
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y

UpdateFrame:    lda scrollX
                lsr
                lsr
                lsr
                eor #$07
                ora #$10
                pha
                and #$01
                sta UF_SprXLSB1+1
                sta UF_SprXLSB2+1
                lda scrollY
                lsr
                lsr
                lsr
                eor #$07
                ora #$10
                pha
                ldx #$00
                stx zpDestLo                    ;D010 bits for first IRQ
                stx zpDestHi                    ;X-expand bits for first IRQ
                ldy numSpr
                bne UF_SprCountOK
                iny                             ;Cannot have zero sprites, as the loop would overflow / crash
UF_SprCountOK:  tya
UF_LastNumSpr:  cpy #$ff                        ;If sprite amount changes, sort all, otherwise just the current amount of sprites
                beq UF_SameSprAmount
                ldy #MAX_SPR
UF_SameSprAmount:
                sty UF_SortEndCmp+1
                sta UF_LastNumSpr+1
                txa
UF_SortLoop:    ldy sprOrder,x                  ;Check for coordinates being in order
                cmp sprY,y
                beq UF_SortNoSwap2
                bcc UF_SortNoSwap1
                stx zpSrcLo                       ;If not in order, begin insertion loop
                sty zpSrcHi
                lda sprY,y
                ldy sprOrder-1,x
                sty sprOrder,x
                dex
                beq UF_SortSwapDone1
UF_SortSwap1:   ldy sprOrder-1,x
                sty sprOrder,x
                cmp sprY,y
                bcs UF_SortSwapDone1
                dex
                bne UF_SortSwap1
UF_SortSwapDone1:
                ldy zpSrcHi
                sty sprOrder,x
                ldx zpSrcLo
                ldy sprOrder,x
UF_SortNoSwap1: lda sprY,y
UF_SortNoSwap2: inx
UF_SortEndCmp:  cpx #MAX_SPR
                bne UF_SortLoop

UF_SortDone:    lda #$01                        ;Make sure IRQs are on to prevent getting stuck in the wait below
                sta $d01a
                if SHOW_FREE_TIME > 0
                dec $d020
                endif
UF_WaitSprites: lda newFrameFlag                ;Wait for previous sprite update & screen redraw to complete
                ora drawScreenFlag
                bmi UF_WaitSprites
                if SHOW_FREE_TIME > 0
                inc $d020
                endif
                lda firstSortSpr                ;Switch sprite doublebuffer side
                eor #MAX_SPR
                sta firstSortSpr
                tay
                lda #<sprOrder
                sec
                sbc firstSortSpr
                sta UF_CopyLoop1+1
                tya
                adc #8-1                        ;C=1
                sta UF_CopyLoop1EndCmp+1        ;Set endpoint for first copyloop
                lda #$80
                sta zpBitBuf                    ;OR-bit for $d010 and x-expand
                bmi UF_CopyLoop1
UF_CopyLoop1Skip:
                inc UF_CopyLoop1+1
UF_CopyLoop1:   ldx sprOrder,y
                lda sprY,x                      ;If reach the maximum Y-coord endmark, all done
                cmp #MAX_SPRY
                bcs UF_CopyLoop1Done
                sta sortSprY,y
                lda sprC,x
                bmi UF_CopyLoop1Skip            ;Flickering sprite?
                sta sortSprC,y
                and #COLOR_XEXPAND
                beq UF_CopyLoop1NoXExpand
                lda zpDestHi
                ora zpBitBuf
                sta zpDestHi
                lda sprX,x
                cmp #MAX_SPRX_EXPANDED/2       ;Do X-coord edge adjust for expanded sprite
                bcc UF_CopyLoop1EdgeAdjustDone
                sbc #$04
                bcs UF_CopyLoop1EdgeAdjustDone
UF_CopyLoop1NoXExpand:
                lda sprX,x
UF_CopyLoop1EdgeAdjustDone:
                asl
UF_SprXLSB1:    ora #$00
                sta sortSprX,y
                bcc UF_CopyLoop1MsbLow
                lda zpDestLo
                ora zpBitBuf
                sta zpDestLo
UF_CopyLoop1MsbLow:
                lda sprF,x
                sta sortSprF,y
                lsr zpBitBuf
                iny
UF_CopyLoop1EndCmp:
                cpy #$00
                bcc UF_CopyLoop1
UF_CopyLoop1Done:
                lda zpDestLo
                sta sortSprXMSB-1,y
                lda zpDestHi
                sta sortSprXExpand-1,y
                lda #$7f                        ;Sprite AND-bit (needing OR is rarer)
                sta zpBitBuf
                lda UF_CopyLoop1+1              ;Copy sortindex from first copyloop
                sta UF_CopyLoop2+1              ;to second
                sta UF_CopyLoop2B+1
                cpy firstSortSpr                ;Any sprites at all?
                beq UF_NoSprites                ;Make first (and final) IRQ endmask
                jmp UF_EndMark
UF_NoSprites:   jmp UF_AllDone                  ;C=1 if jumping to AllDone
UF_CopyLoop2SkipB:
                inc UF_CopyLoop2+1
                inc UF_CopyLoop2B+1
                bne UF_CopyLoop2B
UF_CopyLoop2Next:
                lda sprC,x                      ;TODO: check if can be made to combine IRQs more eagerly
                bmi UF_CopyLoop2SkipB           ;Flickering sprite?
UF_CopyLoop2Begin:
                sta sortSprC,y
                and #COLOR_XEXPAND
                beq UF_CopyLoop2NoXExpand
                lda zpBitBuf
                eor #$ff
                ora sortSprXExpand-1,y
                sta sortSprXExpand,y
                lda sprX,x
                cmp #MAX_SPRX_EXPANDED/2        ;Do X-coord edge adjust for expanded sprite
                bcc UF_CopyLoop2EdgeAdjustDone
                sbc #$04
                bcs UF_CopyLoop2EdgeAdjustDone
UF_CopyLoop2NoXExpand:
                lda sortSprXExpand-1,y
                and zpBitBuf
                sta sortSprXExpand,y
                lda sprX,x
UF_CopyLoop2EdgeAdjustDone:
                asl
UF_SprXLSB2:    ora #$00
                sta sortSprX,y
                bcc UF_CopyLoop2MsbLow
                lda zpBitBuf
                eor #$ff
                ora sortSprXMSB-1,y
                bne UF_CopyLoop2MsbDone
UF_CopyLoop2MsbLow:
                lda sortSprXMSB-1,y
                and zpBitBuf
UF_CopyLoop2MsbDone:
                sta sortSprXMSB,y
                lda sprF,x
                sta sortSprF,y
                iny
                sec
                ror zpBitBuf
                bcs UF_CopyLoop2B
                ror zpBitBuf                    ;Start the AND bit over from $7f
UF_CopyLoop2B:  ldx sprOrder,y
                lda sprY,x
                cmp #MAX_SPRY
                bcs UF_CopyLoop2EndIrq          ;Reached end - no further IRQs
                sta sortSprY,y
                sbc #21-1
                cmp sortSprY-8,y                ;Check for physical sprite overlap
                bcc UF_CopyLoop2SkipB
UF_CopyLoop2YCmp:
                cmp #$00                        ;Include in the same IRQ?
                bcc UF_CopyLoop2Next
UF_CopyLoop2EndIrq:
                tya
                sbc zpSrcLo
                tax
                lda sprIrqAdvanceTbl-1,x
                ldx zpSrcLo
                adc sortSprY,x
                sta sprIrqLine-1,x              ;Store IRQ start line (with advance based on sprite count)
UF_EndMark:     lda sortSprC-1,y                ;Make IRQ endmark
                ora #$80
                sta sortSprC-1,y
UF_CopyLoop2:   ldx sprOrder,y
                lda sprY,x
                cmp #MAX_SPRY
                bcs UF_FinalEndMark             ;Reached end - no further IRQs
                sta sortSprY,y
                sbc #21-1
                cmp sortSprY-8,y                ;Check for physical sprite overlap
                bcc UF_CopyLoop2Skip
                sty zpSrcLo                     ;Store IRQ startindex
                adc #5-1                        ;Store end Y compare for further sprites
                sta UF_CopyLoop2YCmp+1
                lda sprC,x
                bmi UF_CopyLoop2Skip
                jmp UF_CopyLoop2Begin
UF_CopyLoop2Skip:
                inc UF_CopyLoop2+1
                inc UF_CopyLoop2B+1
                bne UF_CopyLoop2
UF_FinalEndMark:lda #$00                        ;Make final endmark, C=1 here
                sta sprIrqLine-1,y
UF_AllDone:     sty SSR_LastSortSpr+1           ;C=1 if jumping here from earlier
                tya                             ;Check which sprites are on
                sbc firstSortSpr
                cmp #$09
                bcc UF_NotMoreThan8
                lda #$08
UF_NotMoreThan8:tax
UF_RemoveLSBLoop:
                dey                             ;Check for overlay sprites
                bmi UF_SpritesDone
                lda sortSprC,y
                and #COLOR_OVERLAY
                beq UF_RemoveLSBNext
                lda sortSprX,y
                ora #$01
                sta sortSprX,y
UF_RemoveLSBNext:
                cpy firstSortSpr
                bne UF_RemoveLSBLoop
UF_SpritesDone: lda d015Tbl,x
                pha
                lda scrCounter                  ;Is it the screen shift? Needs strict timing, so in that case trigger
                beq UF_NoScreenShift            ;whole frameupdate from the IRQ, *but* we can calculate already ahead
UF_ScreenShift: lda firstSortSpr
                sta Irq3_FirstSortSpr+1
                pla
                sta Irq3_D015+1
                pla
                sta Irq3_ScrollY+1
                pla
                sta Irq3_ScrollX+1
                jsr PrepareDrawScreen
                dec drawScreenFlag
                jmp UpdatePanel
UF_NoScreenShift:
UF_BlockUpdateFlag:                             ;Check whether to shift screen next frame + precalculate scrolling
                ldx #$00                        ;Assume no shifting, unless there are blockupdates
                lda scrollX
                clc
                adc scrollSX
                tay
                bmi UF_HasXShift
                cpy #$40
                bcc UF_XDone
UF_HasXShift:   lda blockX                      ;Update block & map-coords
                eor #$01
                sta blockX
                bcc UF_XNeg
UF_XPos:        bne UF_XShiftOK
                inc mapX
                lsr                             ;A=0, set zero flag for the branch below
UF_XNeg:        beq UF_XShiftOK
                lda mapX
                beq UF_XLimit
                dec mapX
UF_XShiftOK:    inx
UF_XDone:       lda scrollSX                    ;Are we on the edge of the
                bmi UF_XDone2                   ;map (right) and going right?
                lda mapX
UF_MapXLimit:   cmp #$00
                bcc UF_XDone2
UF_XLimit:      ldy #$00                        ;Limit scroll before storing
                sty blockX
UF_XDone2:      tya
                and #$3f
                sta SL_PrecalcX+1
                lda scrollY
                clc
                adc scrollSY
                tay
                bmi UF_HasYShift
                cpy #$40
                bcc UF_YDone
UF_HasYShift:   lda blockY
                eor #$01
                sta blockY
                bcc UF_YNeg
UF_YPos:        bne UF_YShiftOK
                inc mapY
                lsr
UF_YNeg:        beq UF_YShiftOK
                lda mapY
                beq UF_YLimit
                dec mapY
UF_YShiftOK:    inx
UF_YDone:       lda scrollSY                    ;Are we on the edge of the map
                bmi UF_YDone2                   ;(bottom) and going down?
                lda mapY
UF_MapYLimit:   cmp #$00
                bcc UF_YDone2
UF_YLimit:      ldy #$00                        ;Limit scroll before storing
                sty blockY
UF_YDone2:      tya
                and #$3f
                sta SL_PrecalcY+1
                txa                             ;Any screen shifting?
                beq UF_NoRedraw
                inc scrCounter                  ;Move forward to screen redraw frame
UF_NoRedraw:    if SHOW_FREE_TIME > 0
                dec $d020
                endif
UF_WaitNormal:  lda newFrameFlag                ;Wait until previous frameupdate is completely finished
                bne UF_WaitNormal
                lda $d011                       ;If no colorshift, just need to make sure we
                bmi UF_WaitDone                 ;are not late from the frameupdate
                lda $d012
                cmp #IRQ1_LINE+$02
                bcs UF_WaitDone
                cmp #IRQ1_LINE-$05
                bcs UF_WaitNormal
UF_WaitDone:    if SHOW_FREE_TIME > 0
                inc $d020
                endif
                lda firstSortSpr
                sta Irq1_FirstSortSpr+1
                pla
                sta Irq1_D015+1
                pla
                sta Irq1_ScrollY+1
                pla
                sta Irq1_ScrollX+1
                dec newFrameFlag                ;$ff = process new frame
UF_NoScrollWork:jmp UpdatePanel



        ; Prepare full redraw of screen.
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y

PrepareDrawScreen:
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
                sta DSLowerHalfEndCmp+1
                lda upperHalfJumpTblLo,y
                sta DSUpperHalfJump+1
                lda upperHalfJumpTblHi,y
                sta DSUpperHalfJump+2
                lda lowerHalfJumpTblLo,y
                sta DSLowerHalfJump+1
                lda lowerHalfJumpTblHi,y
                sta DSLowerHalfJump+2
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
                beq PDS_BlockY0
                iny
PDS_BlockY0:    if RIGHTCLIPPING = 0
                loadrow DSRow0,DSLeft0,0
                loadrow DSRow1,DSLeft1,1
                loadrow DSRow2,DSLeft2,2
                loadrow DSRow3,DSLeft3,3
                loadrow DSRow4,DSLeft4,4
                loadrow DSRow5,DSLeft5,5
                loadrow DSRow6,DSLeft6,6
                loadrow DSRow7,DSLeft7,7
                loadrow DSRow8,DSLeft8,8
                loadrow DSRow9,DSLeft9,9
                loadrow DSRow10,DSLeft10,10
                lda blockY
                beq PDS_SkipLoadTop
                loadrow DSTopRow,DSTopLeft,-1
                rts
PDS_SkipLoadTop:loadrow DSBottomRow,DSBottomLeft,11
                rts
                else
                loadrow DSRow0,DSRight0,DSLeft0,0
                loadrow DSRow1,DSRight1,DSLeft1,1
                loadrow DSRow2,DSRight2,DSLeft2,2
                loadrow DSRow3,DSRight3,DSLeft3,3
                loadrow DSRow4,DSRight4,DSLeft4,4
                loadrow DSRow5,DSRight5,DSLeft5,5
                loadrow DSRow6,DSRight6,DSLeft6,6
                loadrow DSRow7,DSRight7,DSLeft7,7
                loadrow DSRow8,DSRight8,DSLeft8,8
                loadrow DSRow9,DSRight9,DSLeft9,9
                loadrow DSRow10,DSRight10,DSLeft10,10
                lda blockY
                beq PDS_SkipLoadTop
                loadrow DSTopRow,DSTopRight,DSTopLeft,-1
                rts
PDS_SkipLoadTop:loadrow DSBottomRow,DSBottomRight,DSBottomLeft,11
                rts
                endif

PrepareDrawScreenEnd:

        ; Redraw screen. Called from main program at zone changes, or from the IRQ when scrolling
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y

DrawScreen:     clc
                ldx dsStartX
                lda dsBlockX
                bne DSUpperHalfLeft
                jmp DSUpperHalfNoLeft
DSUpperHalfLeft:lda dsBlockY
                beq DSLeft0
DSTopLeft:      drawbottomright 0*80
DSLeft0:        drawright 0*80-1
DSLeft1:        drawright 1*80-1
DSLeft2:        drawright 2*80-1
DSLeft3:        drawright 3*80-1
DSLeft4:        drawright 4*80-1
DSLeft5:        drawright 5*80-1
                inx
                inx
DSUpperHalfNoLeft:
                lda dsBlockY
                beq DSRow0
DSTopRow:       drawbottom -1*40-1
DSRow0:         drawfullblock 0*80-1
DSRow1:         drawfullblock 1*80-1
DSRow2:         drawfullblock 2*80-1
DSRow3:         drawfullblock 3*80-1
DSRow4:         drawfullblock 4*80-1
DSRow5:         drawfullblock 5*80-1
DSUpperHalfEndCmp:
                cpx #38
                bcs DSUpperHalfDone
                inx
                inx
DSUpperHalfJump:jmp DSRow0
DSUpperHalfDone:clc
                if RIGHTCLIPPING > 0
                lda dsBlockX
                beq DSUpperHalfRight
                jmp DSUpperHalfNoRight
DSUpperHalfRight:
                inx
                inx
                lda dsBlockY
                beq DSRight0
DSTopRight:     drawbottomleft 0*80+38
DSRight0:       drawleft 0*80-1
DSRight1:       drawleft 1*80-1
DSRight2:       drawleft 2*80-1
DSRight3:       drawleft 3*80-1
DSRight4:       drawleft 4*80-1
DSRight5:       drawleft 5*80-1
DSUpperHalfNoRight:
                endif
DrawScreenPatchStart:
                ldx dsStartX
                lda dsBlockX
                bne DSLowerHalfLeft
                jmp DSLowerHalfNoLeft
DSLowerHalfLeft:lda dsBlockY
                bne DSLeft6
DSBottomLeft:   drawtopright 11*80
DSLeft6:        drawright 6*80-1
DSLeft7:        drawright 7*80-1
DSLeft8:        drawright 8*80-1
DSLeft9:        drawright 9*80-1
DSLeft10:       drawright 10*80-1
                inx
                inx
DSLowerHalfNoLeft:
                lda dsBlockY
                bne DSRow6
DSBottomRow:    drawtop 11*80-1
DSRow6:         drawfullblock 6*80-1
DSRow7:         drawfullblock 7*80-1
DSRow8:         drawfullblock 8*80-1
DSRow9:         drawfullblock 9*80-1
DSRow10:        drawfullblock 10*80-1
DSLowerHalfEndCmp:
                cpx #38
                bcs DSLowerHalfDone
                inx
                inx
DSLowerHalfJump:jmp DSRow6
DSLowerHalfDone:if RIGHTCLIPPING > 0
                clc
                lda dsBlockX
                beq DSLowerHalfRight
                jmp DSLowerHalfNoRight
DSLowerHalfRight:
                inx
                inx
                lda dsBlockY
                bne DSRight6
DSBottomRight:  drawtopleft 11*80+38
DSRight6:       drawleft 6*80-1
DSRight7:       drawleft 7*80-1
DSRight8:       drawleft 8*80-1
DSRight9:       drawleft 9*80-1
DSRight10:      drawleft 10*80-1
DSLowerHalfNoRight:
                endif
                rts

                if NTSCSIZEREDUCE > 0

                if RIGHTCLIPPING > 0
                ds.b 9,$55          ;Padding; the patched NTSC drawscreen is longer
                else
                ds.b 7,$55
                endif

                endif
DrawScreenEnd: