                include memory.s
                include loadsym.s
                include mainsymcart.s

EASYFLASH_LED   = $80
EASYFLASH_16K   = $07
EASYFLASH_KILL  = $04

FIRSTSAVEFILE   = $78
MAXSAVEFILES    = 8
MAXSAVEPAGES    = 8                             ;How much the savefiles can take RAM in total (during preserve & erase)

CrtLoader       = $0200
irqVectors      = $0314
fileStartLo     = $8000
fileStartHi     = $8080
fileSizeLo      = $8100
fileSizeHi      = $8180
fileSaveStart   = $81ff

EasyAPI         = $c000
EasyAPIInit     = $c014
SavePreserveErase = $c300

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
                lda #8                          ;Enable VIC (e.g. RAM refresh)
                sta $d016
WaitRAM:        sta $0100,x                     ;Write to RAM to make sure it starts up correctly (=> RAM datasheets)
                dex
                bne WaitRAM
CopyLoader:     lda crtLoaderCodeStart,x        ;Copy rest of the startup code to ram
                sta CrtLoader,x
                lda crtLoaderCodeStart+$100,x
                sta CrtLoader+$100,x
                lda crtLoaderCodeStart+$200,x
                sta CrtLoader+$200,x
                lda crtLoaderCodeStart+$300,x
                sta CrtLoader+$300,x
                inx
                bne CopyLoader
                jmp Startup

preserveEraseCode:

                rorg SavePreserveErase

                lda fileNumber                  ;No space, must erase
                sta saveFileNumber
                lda #<saveRamStart
                sta zpDestLo
                lda #>saveRamStart
                sta zpDestHi
                ldx #FIRSTSAVEFILE
SavePreserveFiles:
                stx fileNumber
                lda #$00
                sta zpBitsLo
                sta zpBitsHi                    ;Current file length
                cpx saveFileNumber
                beq SavePreserveFileEnd         ;Do not preserve the file we'll overwrite now
                lda zpDestLo
                sta saveFileAdrLo-FIRSTSAVEFILE,x
                lda zpDestHi
                sta saveFileAdrHi-FIRSTSAVEFILE,x
                jsr OpenFile
                ldy #$00
SavePreserveFileLoop:
                jsr GetByte
                bcs SavePreserveFileEnd
                sta (zpDestLo),y                ;Store file bytes to RAM
                inc zpDestLo
                bne SavePreserveNotOver
                inc zpDestHi
SavePreserveNotOver:
                inc zpBitsLo
                bne SavePreserveFileLoop
                inc zpBitsHi
                bne SavePreserveFileLoop
SavePreserveFileEnd:
                ldx #$37
                stx $01
                ldx fileNumber
                lda zpBitsLo
                sta saveFileLenLo-FIRSTSAVEFILE,x
                lda zpBitsHi
                sta saveFileLenHi-FIRSTSAVEFILE,x
                inx
                bpl SavePreserveFiles
                lda firstSaveBank               ;Erase save sector now
                jsr $df86
                ldy #$80
                jsr $df83
                lda saveFileNumber
                sta fileNumber
                jsr SaveFileSub                 ;Proceed to save the current file first
                ldx #FIRSTSAVEFILE
SavePreservedFiles:
                stx fileNumber                  ;Then save all preserved files with nonzero length
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
                bpl SavePreservedFiles
                rts

saveFileAdrLo:  ds.b MAXSAVEFILES,0
saveFileAdrHi:  ds.b MAXSAVEFILES,0
saveFileLenLo:  ds.b MAXSAVEFILES,0
saveFileLenHi:  ds.b MAXSAVEFILES,0

                rend

preserveEraseCodeEnd:

crtLoaderCodeStart:

                rorg CrtLoader

SaveFileEF:     sta saveSrcLo
                stx saveSrcHi
                lda zpBitsLo                    ;Purge overwrites these, so copy elsewhere
                sta saveSizeLo
                lda zpBitsHi
                sta saveSizeHi
                lda #<saveRamStart
                sta zoneBufferLo
                lda #>saveRamStart
                sta zoneBufferHi
                jsr PurgeUntilFreeNoNew         ;Make room for all save files in case we need to preserve+erase
                jsr FileOpenSub                 ;ROM on, turbo mode off
                ldx #$00
CopyEasyAPI:    lda preserveEraseCode-$4000,x
                sta SavePreserveErase,x
                lda $b800,x                     ;Copy EasyAPI to RAM
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
                sta fileOpen                    ;Preserve/erase needs to open further files, so clear fileopen flag (IRQs disabled, no risk of reentering turbo mode)
                jsr EasyAPIInit                 ;Init EasyAPI
                bcc SaveInitOK
                lda #$02
                sta $d020
                bne SaveExit                    ;Wrong flash driver, abort save
SaveInitOK:     jsr SaveFileSub
SaveExit:       lda #EASYFLASH_16K+EASYFLASH_LED ;Restore LED
                sta $de02
                jmp Restore01

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
                jmp SavePreserveErase
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
SaveLoop:       ldx #$35                        ;Switch to RAM to read
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

FileOpenSub:    lda $d011                       ;Wait until bottom so that panelsplit IRQ will know to take advance
                bpl FileOpenSub
                inc fileOpen
                ldx #$37
                stx $01                         ;Cart ROM accessible
                ldx #$00
                stx $d07a                       ;SCPU to slow mode
                stx $d030                       ;C128 back to 1MHz mode
                stx $de00                       ;Directory bank
                rts

NMI:            rti

firstSaveBank:  dc.b 0
saveFileNumber: dc.b 0
saveStartPos:   dc.b 0

saveImplCodeEnd:ds.b irqVectors-saveImplCodeEnd,$ff

irqVectors:     dc.w NMI
                dc.w NMI
                dc.w NMI

irqVectorsEnd:  ds.b exomizerCodeStart-irqVectorsEnd,$ff

                include exomizer.s

exomizerCodeEnd:ds.b OpenFile-exomizerCodeEnd,$ff

                jmp OpenFileEF
                jmp SaveFileEF
GetByte:        stx loadTempReg
                ldx #$37
                stx $01
                ldx loadBufferPos
GB_SectorLda:   lda $8000,x
GB_EndCmp:      cpx #$00
                bcs GB_FillBuffer
                inc loadBufferPos
Restore01:      ldx #$35
                stx $01
                ldx loadTempReg
OpenFileSkip:   rts

GB_FillBuffer:  ldx fileOpen
                beq GB_EOF
                ldx GB_Sectors+1
                cpx #$ff
                bne GB_FillBufferOK
GB_CloseFile:   dec fileOpen                    ;Last byte was read, mark file closed
                clc
                bcc Restore01
GB_FillBufferOK:ldx GB_SectorLda+2
                inx
GB_BankEndCmp:  cpx #$c0
                bcc GB_NoNextBank
                ldx #$80
                inc GB_BankNum+1
GB_NoNextBank:  stx GB_SectorLda+2
GB_BankNum:     ldx #$00
                stx $de00
                ldx #$00                        ;Reset sector read pointer
                stx loadBufferPos
GB_Sectors:     ldx #$00                        ;Full sectors remaining
                bne GB_MoreSectors
GB_LastSector:  ldx #$00
                skip2
GB_MoreSectors: ldx #$ff
                stx GB_EndCmp+1
                dec GB_Sectors+1
                clc
                bcc Restore01
GB_EOF:         txa                             ;File ended successfully, C=1 & A=0
OF_SaveNotFound:beq Restore01

OpenFileEF:     lda fileOpen                    ;Skip if already open
                bne OpenFileSkip
                jsr FileOpenSub
                lda fileSaveStart               ;Get the save bank from the directory
                sta firstSaveBank
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
                jmp GB_BankNum                  ;Init transfer from first sector

OF_SaveFile:    lda firstSaveBank               ;Get save directory bank
                sta $de00
                txa
                ldx #$02
OF_SaveLoop:    cmp $8000,x
                beq OF_SaveFound
                inx
                bne OF_SaveLoop
                dec fileOpen                    ;Savefile doesn't exist, close file
                stx GB_EndCmp+1
                beq OF_SaveNotFound
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

crtLoaderRuntimeEnd:

                if crtLoaderRuntimeEnd > ntscFlag
                    err
                endif

Startup:        lda #EASYFLASH_16K + EASYFLASH_LED
                sta $de02
                lda #$7f
                sta $dc00   ; pull down row 7 (DPA)
                ldx #$ff
                stx $dc02   ; DDRA $ff = output
                inx
                stx $dc03   ; DDRB $00 = input
                lda $dc01   ; read coloumns (DPB)
                stx $dc02   ; DDRA input again
                stx $dc00   ; Now row pulled down
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
                lda #LOAD_EASYFLASH             ;Loader needs no mods
                sta loaderMode
                lda #$7f
                sta $dc0d                       ;Disable & acknowledge IRQ sources (Y=$7f)
                lda $dc0d
                lda $d011
                and #$0f
                sta $d011                       ;Blank screen
DetectNtsc1:    lda $d012                       ;Detect PAL/NTSC
DetectNtsc2:    cmp $d012
                beq DetectNtsc2
                bmi DetectNtsc1
                cmp #$20
                bcs IsPal
                inc ntscFlag
IsPal:          lda #<NMI                       ;Set NMI vector
                sta $fffa
                sta $fffe
                lda #>NMI
                sta $fffb
                sta $ffff
                lda #$81                        ;Run Timer A once to disable NMI from Restore keypress
                sta $dd0d                       ;Timer A interrupt source
                lda #$01                        ;Timer A count ($0001)
                sta $dd04
                stx $dd05
                lda #%00011001                  ;Run Timer A in one-shot mode
                sta $dd0e
                ldx #$35                        ;ROMs off
                stx $01
                lda #>(loaderCodeEnd-1)         ;Store mainpart entrypoint to stack
                pha
                tax
                lda #<(loaderCodeEnd-1)
                pha
                lda #<loaderCodeEnd
                jmp LoadFile                    ;Load mainpart (overwrites loader init)

                rend

crtLoaderCodeEnd:
                ds.b $f800-crtLoaderCodeEnd,$ff

                org $f800
                incbin eapi-am29f040-14.bin

                org $fb00
                dc.b $65,$66,$2d,$6e,$41,$4d,$45,$3a
                dc.b "eXAMPLE gAME",0,0,0,0

cartNameEnd:    ds.b $fffa-cartNameEnd,$ff

                org $fffa
                dc.w NMI
                dc.w ColdStart
                dc.w NMI
