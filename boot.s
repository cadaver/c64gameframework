        ; Autostarting bootpart
                

                processor 6502

                include memory.s
                include kernal.s
                include loadsym.s
                include ldepacksym.s

                org $032a

                dc.b $0b,$08                    ;GETIN vector or BASIC next line address
                dc.w AutoStart                  ;CLALL vector or BASIC line number
                dc.b $9e,$32,$30,$36,$31        ;Sys instruction
                dc.b $00,$00,$00

                rorg $080d

BasicStart:     lda #<(BootStart-AutoStart+BasicEnd-1)
                sta BasicEnd+3
                lda #>(BootStart-AutoStart+BasicEnd-1)
                sta BasicEnd+4
BasicEnd:
                rend

AutoStart:      ldx #BootEnd-BootStart
CopyBoot:       lda BootStart-1,x
                sta.wx $0100-1,x
                dex
                bne CopyBoot
                jmp $0100

BootStart:
                rorg $0100

BootWaitBottom: lda $d011                       ;Wait for bottom to smooth the transition
                bpl BootWaitBottom
                lda #$00
                sta $d015
                sta $d020
                sta $d021
                tax
                ldy #$84
                sty $d018
                dey
ClearScreen:    sta $d800,x
                inx
                bne ClearScreen
                inc ClearScreen+2
                dey
                bmi ClearScreen
                sei
                sty $dc0d                       ;Disable & acknowledge IRQ sources (Y=$7f)
                lda $dc0d
                lda #<NMI
                sta $0318
                lda #>NMI
                sta $0319
                lda #$81                        ;Run CIA2 Timer A once to disable NMI from Restore keypress
                sta $dd0d                       ;Timer A interrupt source
                lda #$01                        ;Timer A count ($0001)
                sta $dd04
                stx $dd05
                lda #%00011001                  ;Run Timer A in one-shot mode
                sta $dd0e
                lda #$06
                ldx #<loaderFileName
                ldy #>loaderFileName
                jsr SetNam
                lda #$02
                ldx $ba                         ;Use last used device
                ldy #$00
                jsr SetLFS
                jsr Open
                ldx #$02                        ;Open file $02 for input
                jsr ChkIn
                ldx #36
ShowMessage:    lda #$0f
                sta colors+12*40+1,x
                lda message-1,x
                and #$3f
                sta $2000+12*40+1,x
                dex
                bne ShowMessage
LoadExomizer:   jsr ChrIn                       ;Load Exomizer (unpacked)
                sta exomizerCodeStart,x
                inx
                cpx #(ldepackCodeEnd-exomizerCodeStart)
                bne LoadExomizer
                lda #>(InitLoader-1)            ;Have to push entrypoint to stack as this code will be overwritten
                pha
                lda #<(InitLoader-1)
                pha
                lda #<ldepackCodeEnd
                ldx #>ldepackCodeEnd
                jmp Depack
NMI:            rti

message:        dc.b "HOLD SPACE/FIRE FOR SAFE MODE "
loaderFileName: dc.b "LOADER"
messageEnd:

                rend
BootEnd: