        ; Autostarting bootpart

                include memory.s
                include kernal.s
                include loadsym.s
                include ldepacksym.s

                org $032a

                dc.b $0b,$08                    ;GETIN vector or BASIC next line address
                dc.w EntryPoint                 ;CLALL vector or BASIC line number
                dc.b $9e,$32,$30,$35,$39        ;Sys instruction
                dc.b $00

bootStart:

BootAutoStart:

                rorg $080b

BootBasicStart: ldx #$00
BootWaitBottom: lda $d011                       ;Wait for bottom to smooth the transition
                bpl BootWaitBottom
                stx $d015
                stx $d020
                stx $d021
                ldy #$84
                sty $d018
                lda #$20
ClearScreen:    sta $2000,x
                inx
                bne ClearScreen
                inc ClearScreen+2
                dey
                bmi ClearScreen
                sty $dc0d                       ;Disable & acknowledge IRQ sources (Y=$7f)
                lda $dc0d
                stx $d07f                       ;Disable SCPU hardware regs
                stx $d07a                       ;SCPU to slow mode
                stx fileOpen                    ;Clear loader ZP vars
                lda #<BootNMI                   ;Set NMI vector
                sta $0318
                lda #>BootNMI
                sta $0319
                lda #$81                        ;Run CIA2 Timer A once to disable NMI from Restore keypress
                sta $dd0d                       ;Timer A interrupt source
                lda #$01                        ;Timer A count ($0001)
                sta $dd04
                stx $dd05
                lda #%00011001                  ;Run Timer A in one-shot mode
                sta $dd0e
                lda #$02
                ldx #<loaderFileName
                ldy #>loaderFileName
                jsr SetNam
                ldx $ba                         ;Use last used device
                ldy #$00                        ;A is still $02 (file number)
                jsr SetLFS
                jsr Open
                ldx #$02                        ;Open file $02 for input
                jsr ChkIn
                ldy #36
ShowMessage:    lda #$0f
                sta colors+12*40+1,y
                lda message-1,y
                and #$3f
                sta $2000+12*40+1,y
                dey
                bne ShowMessage
LoadExomizer:   jsr ChrIn                       ;Load Exomizer (unpacked)
                sta exomizerCodeStart,y
                iny
                cpy #(packedLoaderStart-exomizerCodeStart)
                bne LoadExomizer
                lda #>(InitLoader-1)            ;Load loader (packed), then run it
                pha
                lda #<(InitLoader-1)
                pha
                lda #<loaderCodeStart
                ldx #>loaderCodeStart
                jmp LoadFile
BootNMI:        rti

message:        dc.b "HOLD SPACE/FIRE FOR SAFE MODE "
loaderFileName: dc.b "LOADER"
messageEnd:

                rend

bootEnd:

EntryPoint:     ldx #bootEnd-bootStart
CopyBootCode:   lda BootAutoStart-1,x
                sta BootBasicStart-1,x
                dex
                bne CopyBootCode
                jmp BootBasicStart
