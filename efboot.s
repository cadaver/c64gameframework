                include memory.s
                include loadsym.s
                include mainsymcart.s

EXOMIZER_ERRORHANDLING = 0                      ;Not needed, speed up loading

EASYFLASH_LED   = $80
EASYFLASH_16K   = $07
EASYFLASH_KILL  = $04

FIRSTSAVEFILE   = $78
MAXSAVEFILES    = 8
MAXSAVEPAGES    = 8                             ;How much the savefiles can take RAM in total (during preserve & erase)

Startup         = $0200
EasyAPI         = $c000
SaveCode        = $c300
EasyAPIInit     = $c014

fileStartLo     = $8000
fileStartHi     = $8080
fileSizeLo      = $8100
fileSizeHi      = $8180
fileSaveStart   = $81ff

saveSrcLo       = xLo
saveSrcHi       = yLo
saveSizeLo      = actLo
saveSizeHi      = actHi

saveRamStart    = $c000-MAXSAVEPAGES*$100

                processor 6502
                org $e200                       ;First 512 bytes of first bank is the non-writable file directory

ColdStart:      sei
                ldx #$ff
                txs
                cld

        ; Enable VIC (e.g. RAM refresh)

                lda #8
                sta $d016

        ; Write to RAM to make sure it starts up correctly (=> RAM datasheets)

WaitRAM:        sta $0100,x
                dex
                bne WaitRAM

        ; Copy the rest of the startup & loader code to ram

CopyStartup:    lda startupCode,x
                sta Startup,x
                lda startupCode+$100,x
                sta Startup+$100,x
                lda startupCode+$200,x
                sta Startup+$200,x
                inx
                bne CopyStartup
                jmp Startup

startupCode:

                rorg Startup

                lda #EASYFLASH_16K + EASYFLASH_LED
                sta $de02

        ; Prepare the CIA to scan the keyboard

                lda #$7f
                sta $dc00   ; pull down row 7 (DPA)

                ldx #$ff
                stx $dc02   ; DDRA $ff = output
                inx
                stx $dc03   ; DDRB $00 = input

        ; Read the keys pressed on this row

                lda $dc01   ; read coloumns (DPB)

        ; Restore CIA registers to the state after (hard) reset

                stx $dc02   ; DDRA input again
                stx $dc00   ; Now row pulled down

        ; Check if one of the magic kill keys was pressed

                and #$e0    ; only leave "Run/Stop", "Q" and "C="
                cmp #$e0
                beq NoKill    ; branch if one of these keys is pressed

Kill:           lda #EASYFLASH_KILL
                sta $de02
                jmp ($fffc) ; reset

NoKill:         ldx #$00
                stx $d016
                jsr $ff84   ; Initialise I/O
                ldx #$00
                stx ntscFlag
                stx fileNumber
                stx $d015
                stx $d020
                stx $d021
                stx $d07f                       ;Disable SCPU hardware regs
                stx $d07a                       ;SCPU to slow mode
                stx fileOpen                    ;Clear loader ZP vars
                lda #$18
                sta $d016
                lda #LOAD_FAKEFAST              ;Loader needs no mods
                sta fastLoadMode
                lda #$7f
                sta $dc0d                       ;Disable & acknowledge IRQ sources (Y=$7f)
                lda $dc0d
                lda #$0b
                sta $d011                       ;Blank screen
DetectNtsc1:    lda $d012                       ;Detect PAL/NTSC
DetectNtsc2:    cmp $d012
                beq DetectNtsc2
                bmi DetectNtsc1
                cmp #$20
                bcs IsPal
                inc ntscFlag
IsPal:          lda #<NMI                       ;Set NMI vector
                sta $0318
                sta $fffa
                sta $fffe
                lda #>NMI
                sta $0319
                sta $fffb
                sta $ffff
                lda #$81                        ;Run Timer A once to disable NMI from Restore keypress
                sta $dd0d                       ;Timer A interrupt source
                lda #$01                        ;Timer A count ($0001)
                sta $dd04
                stx $dd05
                lda #%00011001                  ;Run Timer A in one-shot mode
                sta $dd0e
                lda #$00
                sta $de00
                lda fileSaveStart
                sta firstSaveBank
                lda #$35                        ;ROMs off
                sta $01
                lda #>(loaderCodeEnd-1)         ;Store intro picture entrypoint to stack
                pha
                tax
                lda #<(loaderCodeEnd-1)
                pha
                lda #<loaderCodeEnd
                jmp LoadFile                    ;Load intro picture part (overwrites loader init)

initCodeEnd:    ds.b $300-initCodeEnd,$ff

FileOpenSub:    inc fileOpen
                ldx #$00
                stx $d07a                       ;SCPU to slow mode
                stx $d030                       ;C128 back to 1MHz mode
                stx $de00                       ;Directory bank
                lda #$37
                sta $01                         ;Cart ROM accessible
                rts

NMI:            rti

firstSaveBank:  dc.b 0

                ds.b 6,$ff                      ;Interrupt vectors when Kernal is on

CopySaveCode:   lda $01
                sta loadTempReg                 ;Preserve $01
                jsr FileOpenSub                 ;Make sure no turbo mode during save
CopySaveCodeLoop:
                lda $b600,x                     ;Copy rest of save routine to RAM
                sta SaveCode,x
                lda $b700,x
                sta SaveCode+$100,x
                inx
                bne CopySaveCodeLoop
                jmp SaveCode                    ;Jump into the rest of the save code

helperCodeEnd:  ds.b exomizerCodeStart-helperCodeEnd,$ff

                include exomizer.s

exomizerCodeEnd:ds.b OpenFile-exomizerCodeEnd,$ff

                jmp OpenFileEF
                jmp SaveFileEF
GetByte:        ldx loadBufferPos
                lda loadBuffer,x
GB_EndCmp:      cpx #$00
                bcs GB_FillBuffer
                inc loadBufferPos
                rts

GB_FillBuffer:  ldx fileOpen
                beq GB_EOF
                ldx GB_Sectors+1
                cpx #$ff
                bne GB_FillBufferOK
GB_CloseFile:   dec fileOpen                    ;Last byte was read, mark file closed
                clc
                rts
GB_FillBufferOK:pha
                lda $01
                pha
                lda #$37                        ;Enable cart ROM to get file data
                sta $01
GB_BankNum:     lda #$00
                sta $de00
                ldx #$00                        ;Reset sector read pointer
                stx loadBufferPos
GB_SectorLda:   lda $8000,x
                sta loadBuffer,x
                inx
                bne GB_SectorLda
                dex                             ;End compare value for full sectors
GB_Sectors:     lda #$00                        ;Full sectors remaining
                bne GB_MoreSectors
GB_LastSector:  ldx #$00
GB_MoreSectors: stx GB_EndCmp+1
                dec GB_Sectors+1
                ldx GB_SectorLda+2
                inx
GB_BankEndCmp:  cpx #$c0
                bcc GB_NoNextBank
                ldx #$80
                inc GB_BankNum+1
GB_NoNextBank:  stx GB_SectorLda+2
GB_Restore01:   pla
                sta $01
                pla
                clc
                rts
GB_EOF:         txa                             ;File ended successfully, C=1 & A=0
OpenFileSkip:   rts

OpenFileEF:     lda fileOpen                    ;Skip if already open
                bne OpenFileSkip
                pha                             ;Push one extra for FillBuffer
                lda $01
                pha
                jsr FileOpenSub
                ldx fileNumber
                cpx #FIRSTSAVEFILE
                bcs OF_SaveFile                 ;Save files handled differently
                lda fileStartHi,x
                sta GB_BankNum+1
                lda fileStartLo,x
                sta GB_SectorLda+2
                lda fileSizeLo,x
                ldy fileSizeHi,x
                ldx #$c0                        ;Static files use both low & high chip
OF_StoreSectorCount:
                sta GB_LastSector+1
                stx GB_BankEndCmp+1
                sty GB_Sectors+1
                jmp GB_BankNum                  ;Transfer first sector

OF_SaveFile:    lda firstSaveBank               ;Get save directory bank
                sta $de00
                txa
                ldx #$02
OF_SaveLoop:    cmp $8000,x
                beq OF_SaveFound
                inx
                bne OF_SaveLoop
                stx loadBufferPos               ;Savefile doesn't exist, close file & restore 01 value
                dec fileOpen
                beq GB_MoreSectors
OF_SaveFound:   txa
                and #$1f
                ora #$80
                sta GB_SectorLda+2              ;Savefile sector within bank
                txa
                ldy #$05
OF_BankLoop:    lsr
                dey
                bne OF_BankLoop
                ora firstSaveBank               ;Savefile start bank
                sta GB_BankNum+1
OF_SaveLengthLoop:
                lda $8001,x                     ;Check how far the savefile continues
                cmp fileNumber
                bne OF_SaveEndFound
                inx
                iny
                bne OF_SaveLengthLoop
OF_SaveEndFound:lda $8100,x                     ;Length of last sector was stored when saving
                ldx #$a0                        ;Savefiles use only the low chip
                bne OF_StoreSectorCount

SaveFileEF:     sta saveSrcLo                   ;Preserve save address
                stx saveSrcHi
                jmp CopySaveCode

crtLoadCodeEnd:

                if crtLoadCodeEnd > ntscFlag
                    err
                endif

                rend

startupCodeEnd: ds.b $f600-startupCodeEnd,$ff

                org $f600
saveCodeStart:

                rorg SaveCode

                lda zpBitsLo                    ;Purge overwrites these, so copy elsewhere
                sta saveSizeLo
                lda zpBitsHi
                sta saveSizeHi
                lda loadTempReg
                sta $01                         ;Momentarily restore RAM so resource files will be moved correctly
                lda #<saveRamStart
                sta zoneBufferLo
                lda #>saveRamStart
                sta zoneBufferHi
                jsr PurgeUntilFreeNoNew         ;Make room for all save files in case we need to preserve+erase
                lda #$37
                sta $01
                ldx #$00
CopyEasyAPI:    lda $b800,x                     ;Copy EasyAPI to RAM
                sta EasyAPI,x
                lda $b900,x
                sta EasyAPI+$100,x
                lda $ba00,x
                sta EasyAPI+$200,x
                inx
                bne CopyEasyAPI
                jsr WaitBottom                  ;To avoid glitches, blank screen + disable IRQs like safe mode does
                jsr SilenceSID
                sta $d01a
                sta $d011
                jsr EasyAPIInit                 ;Init EasyAPI
                bcc SaveInitOK
                lda #$02
                sta $d020
                bne SaveExit                    ;Wrong flash driver, abort save
SaveInitOK:     jsr SaveFileSub
SaveExit:       lda #EASYFLASH_16K+EASYFLASH_LED ;Restore LED
                sta $de02
                lda loadTempReg
                sta $01                         ;Restore $01 value
                dec fileOpen
                rts                             ;Done!

SaveFileSub:    lda firstSaveBank
                sta $de00
                jsr $df86                       ;Set bank for manipulating directory
                ldx #$02                        ;First 2 pages used for the directory & last bytes
SaveSeekEmpty:  lda $8000,x                     ;Search for unused file slot
                cmp #$ff
                beq SaveEmptyFound
SaveSeekEmptyNext:
                inx
                bne SaveSeekEmpty
                jmp SavePreserveAndErase
SaveEmptyFound: stx saveStartPos
                ldx #$02
                ldy #$80
SaveEraseOld:   cpx saveStartPos
                bcs SaveEraseOldDone
                lda $8000,x
                cmp fileNumber
                bne SaveEraseOldSkip
                lda #$00
                jsr $df80                       ;Erase (zero) the old save directory entry
SaveEraseOldSkip:
                inx
                bne SaveEraseOld
SaveEraseOldDone:
                lda saveSizeLo                  ;Filesize-1
                sec
                sbc #$01
                sta zpBitsLo
                lda saveSizeHi
                sbc #$00
                sta zpBitsHi
SaveWriteFileEntry:
                lda fileNumber                  ;Write the file number
                jsr $df80
                inx
                dec zpBitsHi
                bpl SaveWriteFileEntry
                dex                             ;Back out one byte
                ldy #$81
                lda zpBitsLo
                jsr $df80                       ;Write the amount of bytes in last sector
                lda saveStartPos
                ldx #$05
SaveBankLoop:   lsr
                dex
                bne SaveBankLoop
                ora firstSaveBank
                jsr $df86                       ;Set bank for write
                lda saveStartPos
                and #$1f
                ora #$80
                tay
                lda #$b0
                jsr $df8c                       ;Set address within bank for write (X=0)
                ldy #$00
                lda saveSizeLo
                beq SavePreDecrement
SaveLoop:       ldx loadTempReg                 ;Switch to RAM to read
                stx $01
                lda (saveSrcLo),y
                ldx #$37
                stx $01                         ;Switch to ROM during EasyAPI use
                jsr $df95                       ;Save with incrementing address
                iny
                bne SaveNotOver
                inc saveSrcHi
SaveNotOver:    dec saveSizeLo
                bne SaveLoop
SavePreDecrement:
                dec saveSizeHi
                bpl SaveLoop
                rts

SavePreserveAndErase:
                lda fileNumber                  ;No space, must erase
                sta saveFileNumber
                lda #<saveRamStart
                sta zpDestLo
                lda #>saveRamStart
                sta zpDestHi
                ldx #FIRSTSAVEFILE
                stx fileNumber
SavePreserveFiles:
                cpx saveFileNumber
                beq SavePreserveSkip            ;Do not preserve the file we'll overwrite now
                jsr OpenFile
                ldy #$00
                sty zpBitsLo
                sty zpBitsHi                    ;Current file length
                lda zpDestLo
                sta saveFileAdrLo-FIRSTSAVEFILE,x
                lda zpDestHi
                sta saveFileAdrHi-FIRSTSAVEFILE,x
SavePreserveFileLoop:
                jsr GetByte
                bcs SavePreserveFileEnd
                sta (zpDestLo),y                ;Store file bytes to RAM
                inc zpDestLo
                bne SavePreserveNotOver
                inc zpDestHi
SavePreserveNotOver:
                inc zpBitsLo
                bne SavePreserveNotOver2
                inc zpBitsHi
SavePreserveNotOver2:
                bne SavePreserveFileLoop
SavePreserveFileEnd:
                ldx fileNumber
                lda zpBitsLo
                sta saveFileLenLo-FIRSTSAVEFILE,x
                lda zpBitsHi
                sta saveFileLenHi-FIRSTSAVEFILE,x
SavePreserveSkip:
                inc fileNumber
                ldx fileNumber
                cpx #FIRSTSAVEFILE+MAXSAVEFILES
                bne SavePreserveFiles
                lda firstSaveBank               ;Erase save sector now
                ldy #$80
                jsr $df83
                lda saveFileNumber
                sta fileNumber
                jsr SaveFileSub                 ;Proceed to save the current file first
                ldx #FIRSTSAVEFILE
                stx fileNumber                  ;Then save all preserved files
SavePreservedFiles:
                lda saveFileLenLo-FIRSTSAVEFILE,x
                ora saveFileLenHi-FIRSTSAVEFILE,x
                beq SavePreservedFileSkip
                lda saveFileAdrLo-FIRSTSAVEFILE,x
                sta saveSrcLo
                lda saveFileAdrHi-FIRSTSAVEFILE,x
                sta saveSrcHi
                lda saveFileLenLo-FIRSTSAVEFILE,x
                sta saveSizeLo
                lda saveFileLenHi-FIRSTSAVEFILE,x
                sta saveSizeHi
                jsr SaveFileSub
SavePreservedFileSkip:
                ldx fileNumber
                inx
                cpx #FIRSTSAVEFILE+MAXSAVEFILES
                bcc SavePreservedFiles
                rts

saveFileAdrLo:  ds.b MAXSAVEFILES,0
saveFileAdrHi:  ds.b MAXSAVEFILES,0
saveFileLenLo:  ds.b MAXSAVEFILES,0
saveFileLenHi:  ds.b MAXSAVEFILES,0
saveFileNumber: dc.b 0
saveStartPos:   dc.b 0

                rend

saveCodeEnd:    ds.b $f800-saveCodeEnd,$ff

                org $f800
                incbin eapi-am29f040-14.bin

                org $fb00

                dc.b $65,$66,$2d,$6e,$41,$4d,$45,$3a
                dc.b "mw ultra",0,0,0,0,0,0,0,0

cartNameEnd:    ds.b $fffa-cartNameEnd,$ff

                org $fffa
                dc.w NMI
                dc.w ColdStart
                dc.w NMI
