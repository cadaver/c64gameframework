INDEFINITE_TEXT_DURATION = $7f

        ; Redraw requested scorepanel items + advance text printing as necessary
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,loader temp vars

UpdatePanel:    lda textTime
                beq UP_TextDone
                cmp #INDEFINITE_TEXT_DURATION*2
                bcs UP_TextDone
                dec textTime
                beq UpdateText
UP_TextDone:    rts

        ; Print continued panel text. Should be called immediately after printing the beginning part.
        ;
        ; Parameters: A,X text address
        ; Returns: -
        ; Modifies: A,X,Y,zpSrcLo,zpSrcHi,text variables

ContinuePanelText:
                sta textLo
                stx textHi
                ldx textCursor
                bpl UT_ContinueText

        ; Clear the panel text
        ;
        ; Parameters: -
        ; Returns: C=1
        ; Modifies: A,X,Y,zpSrcLo,zpSrcHi,text variables

ClearPanelText: ldx #$00
                ldy #$00
                skip2

        ; Print text to panel, possibly multi-line
        ;
        ; Parameters: A,X text address, Y delay in game logic frames (25 = 1 sec)
        ; Returns: -
        ; Modifies: A,X,Y,zpSrcLo,zpSrcHi,text variables

PrintPanelTextIndefinite:
                ldy #INDEFINITE_TEXT_DURATION
PrintPanelText: sty UT_TextDelay+1
                sta textLo
                stx textHi
UpdateText:     ldx textLeftMargin
UT_ContinueText:ldy #$00
                lda textHi
                beq UT_NoLine
                lda (textLo),y
                bne UT_BeginLine
UT_NoLine:      sta textTime
                sta textHi
                ldx textLeftMargin
                bpl UT_ClearEndOfLine
UT_BeginLine:
UT_TextDelay:   lda #$00
                asl
                sta textTime
UT_PrintTextLoop:
                sty zpSrcHi
                stx zpSrcLo
UT_ScanWordLoop:lda (textLo),y
                beq UT_ScanWordDone
                bmi UT_ScanWordDone
                cmp #$20
                beq UT_ScanWordDone
                cmp #"-"
                beq UT_ScanWordDone2
                inc zpSrcLo
                iny
                bne UT_ScanWordLoop
UT_ScanWordDone2:
                inc zpSrcLo
UT_ScanWordDone:ldy zpSrcHi
                lda textRightMargin
                cmp zpSrcLo
                bcs UT_WordCmp
UT_EndLine:     stx textCursor
                tya
                ldx #textLo
                jsr Add8
                ldx textCursor
UT_ClearEndOfLine:
                jmp PrintSpaceUntilRightMargin
UT_WordLoop:    lda (textLo),y
                jsr PrintPanelChar
                iny
UT_WordCmp:     cpx zpSrcLo
                bcc UT_WordLoop
UT_SpaceLoop:   lda (textLo),y
                beq UT_EndLine
                bmi UT_TextJump
                cmp #$20
                bne UT_SpaceLoopDone
                cpx textRightMargin
                bcs UT_SpaceSkip
                jsr PrintPanelChar
UT_SpaceSkip:   iny
                bne UT_SpaceLoop
UT_SpaceLoopDone:
                cpx textRightMargin
                bcc UT_PrintTextLoop
                bcs UT_EndLine
UT_TextJump:    pha
                iny
                lda (textLo),y
                sta textLo
                pla
                and #$7f
                sta textHi
                ldy #$00
                beq UT_PrintTextLoop

        ; Print a BCD value to panel
        ;
        ; Parameters: A value, X position
        ; Returns: X position incremented
        ; Modifies: A,X

Print3BCDDigitsLeftAlign:
                lda zpDestHi
                beq P3BDLA_SkipFirst
                jsr PrintBCDDigit
PrintBCDDigits: lda zpDestLo
                pha
                lsr
                lsr
                lsr
                lsr
                bpl PBDLA_NoSkip
P3BDLA_SkipFirst:
                lda zpDestLo
PrintBCDDigitsLeftAlign:
                pha
                lsr
                lsr
                lsr
                lsr
                beq PBDLA_Skip
PBDLA_NoSkip:   ora #$30
PBD_Common:     jsr PrintPanelChar
PBDLA_Skip:     pla
                and #$0f

PrintBCDDigit:  ora #$30
                skip2
PrintSpace:     lda #$20
PrintPanelChar: sta panelScreen+SCROLLROWS*40,x
                lda #$01
                sta colors+SCROLLROWS*40,x
                inx
                rts

PrintBCDDigitsRightAlign:
                pha
                lsr
                lsr
                lsr
                lsr
                bne PBDLA_NoSkip
                lda #$20
                bne PBD_Common

        ; Print spaces until a specific X-position
        ;
        ; Parameters: A end position+1
        ; Returns: X position incremented,C=1
        ; Modifies: A,X

PrintSpaceUntilRightMargin:
                lda textRightMargin
PrintSpaceUntil:sta PSU_Loop+1
PSU_Loop:       cpx #$00
                bcs PSU_Done
                jsr PrintSpace
                bne PSU_Loop
PSU_Done:       rts

        ; Convert a 8-bit value to BCD
        ;
        ; Parameters: A value
        ; Returns: zpDestLo-Hi BCD value
        ; Modifies: A,Y,zpSrcLo-Hi,zpDestLo-Hi

ConvertToBCD8:  sta zpSrcHi
                ldy #$08
CTB_Common:     lda #$00
                sta zpDestLo
                sta zpDestHi
                sed
CTB_Loop:       asl zpSrcLo
                rol zpSrcHi
                lda zpDestLo
                adc zpDestLo
                sta zpDestLo
                lda zpDestHi
                adc zpDestHi
                sta zpDestHi
                dey
                bne CTB_Loop
                cld
                rts

        ; Convert a 16-bit value to BCD
        ;
        ; Parameters: A,X value
        ; Returns: zpDestLo-Hi BCD value
        ; Modifies: A,Y,zpSrcLo-Hi,zpDestLo-Hi

ConvertToBCD16: sta zpSrcLo
                stx zpSrcHi
                ldy #$10
                bne CTB_Common

                if SHOW_DEBUG_VARS > 0

PrintHexByte:   pha
                lsr
                lsr
                lsr
                lsr
                jsr PrintHexDigit
                pla
                and #$0f
PrintHexDigit:  cmp #$0a
                bcc PrintHexDigit_IsNumber
                adc #$06
PrintHexDigit_IsNumber:
                adc #$30
                jmp PrintPanelChar

                endif

        ; Begin a fullscreen text display
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y
        
InitTextScreen: jsr BlankScreen
                ldx #$00
                stx Irq1_Bg1+1
ITS_Loop:       lda #$20
                sta screen,x
                sta screen+$100,x
                sta screen+$200,x
                sta screen+SCROLLROWS*40-$100,x
                inx
                bne ITS_Loop
                jsr WaitBottom
                lda #TEXTSCR_D018
                sta Irq1_D018+1
                rts

        ; Find offset of text row on the screen
        ;
        ; Parameters: X column, Y row
        ; Returns: xLo-yLo row offset, zpDestLo-zpDestHi screen pointer, zpBitsLo-zpBitsHi color pointer
        ; Modifies: A,X,Y

GetRowAddress:  txa
                pha
                lda #40
                ldx #<xLo
                jsr MulU
                pla
                jsr Add8

        ; Form text & color addresses from row offset
        ;
        ; Parameters: xLo-yLo row offset
        ; Returns: zpDestLo-zpDestHi screen pointer, zpBitsLo-zpBitsHi color pointer, Y=0
        ; Modifies: A,X,Y

GetRowAddressFromOffset:
                lda xLo
                sta zpDestLo
                sta zpBitsLo
                lda yLo
                ora #>colors
                sta zpBitsHi
                ora #>screen
                sta zpDestHi
                ldy #$00
                rts

        ; Print text script resource to screen
        ;
        ; Parameters: A,X Script entrypoint & file, xLo-yLo Row offset, PT_Color Text color
        ; Returns: Text pointer & row offset incremented
        ; Modifies: A,X,Y

PrintTextResource:
                jsr GetScriptResource

        ; Print nullterminated text to screen
        ;
        ; Parameters: zpSrcLo-zpSrcHi text pointer, xLo-yLo Row offset, PT_Color+1 Text color
        ; Returns: Text pointer & row offset incremented
        ; Modifies: A,X,Y

PrintText:      jsr GetRowAddressFromOffset
PT_Loop:        lda (zpSrcLo),y
                beq PT_Done
                jsr PrintChar
                bne PT_Loop
PT_Done:        tya
                ldx #<xLo
                jsr Add8
                iny
                tya
                ldx #<zpSrcLo
                jmp Add8

        ; Print char to screen at arbitrary position
        ;
        ; Parameters: A char to print, Y row index, zpDestLo-zpDestHi screen pointer, zpBitsLo-zpBitsHi color pointer, PT_Color+1 Text color
        ; Returns: Row index incremented
        ; Modifies: A,Y

PrintChar:      sta (zpDestLo),y
PT_Color:       lda #$00
                sta (zpBitsLo),y
                iny
                rts