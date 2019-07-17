                include memory.s
                include mainsym.s

EASYFLASH_LED   = $80
EASYFLASH_16K   = $07
EASYFLASH_KILL  = $04

FIRSTSAVEFILE   = $f0
MAXSAVEFILES    = 15
MAXSAVEPAGES    = 8                             ;How much the savefiles can take RAM in total (during preserve & erase)

CrtHelper       = $0200
CrtRuntime      = exomizerCodeStart
irqVectors      = $0314
fileStartLo     = $8000
fileStartHi     = $8100
fileSizeLo      = $8200
fileSizeHi      = $8300
fileSaveStart   = $83ff

EasyAPI         = $c000
EasyAPIInit     = $c014
SavePreserveErase = $c300

saveSrcLo       = xLo
saveSrcHi       = yLo
saveFileNumber  = xHi
saveStartPos    = yHi
saveSizeLo      = actLo
saveSizeHi      = actHi
preserveFileNumber = zpLenLo

saveRamStart    = $c000-MAXSAVEPAGES*$100

                processor 6502
                org $e400                       ;First KB of first bank is the non-writable file directory

ColdStart:      sei
                ldx #$ff
                txs
                cld
                lda #8                          ;Enable VIC (e.g. RAM refresh)
                sta $d016
WaitRAM:        sta $0100,x                     ;Write to RAM to make sure it starts up correctly (=> RAM datasheets)
                dex
                bne WaitRAM
                copycrtcode crtHelperCodeStart,crtHelperCodeEnd,CrtHelper
                copycrtcode crtRuntimeCodeStart,crtRuntimeCodeEnd,CrtRuntime
                jmp Startup

preserveEraseCode:

                rorg SavePreserveErase

                lda loadTempReg                 ;No space, must erase
                sta saveFileNumber
                lda #<saveRamStart
                sta zpDestLo
                lda #>saveRamStart
                sta zpDestHi
                ldx #FIRSTSAVEFILE
SavePreserveFiles:
                stx preserveFileNumber
                lda #$00
                sta zpBitsLo
                sta zpBitsHi                    ;Current file length
                cpx saveFileNumber
                beq SavePreserveFileEnd         ;Do not preserve the file we'll overwrite now
                lda zpDestLo
                sta saveFileAdrLo-FIRSTSAVEFILE,x
                lda zpDestHi
                sta saveFileAdrHi-FIRSTSAVEFILE,x
                txa
                jsr OpenFile
                ldy #$00
SavePreserveFileLoop:
                lda fileOpen
                beq SavePreserveFileEnd
                jsr GetByte
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
                lda #$37
                sta $01
                ldx preserveFileNumber
                lda zpBitsLo
                sta saveFileLenLo-FIRSTSAVEFILE,x
                lda zpBitsHi
                sta saveFileLenHi-FIRSTSAVEFILE,x
                inx
                cpx #FIRSTSAVEFILE+MAXSAVEFILES
                bne SavePreserveFiles
                lda firstSaveBank               ;Erase save sector now
                jsr $df86
                ldy #$80
                jsr $df83
                lda saveFileNumber
                sta loadTempReg
                jsr SaveFileSub                 ;Proceed to save the current file first
                ldx #FIRSTSAVEFILE
SavePreservedFiles:
                stx loadTempReg                 ;Then save all preserved files with nonzero length
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
                ldx loadTempReg
                inx
                cpx #FIRSTSAVEFILE+MAXSAVEFILES
                bne SavePreservedFiles
                rts

saveFileAdrLo:  ds.b MAXSAVEFILES,0
saveFileAdrHi:  ds.b MAXSAVEFILES,0
saveFileLenLo:  ds.b MAXSAVEFILES,0
saveFileLenHi:  ds.b MAXSAVEFILES,0

                rend

preserveEraseCodeEnd:

crtHelperCodeStart:

                rorg CrtHelper

SaveFileEF:     sta loadTempReg
                lda zpSrcLo                     ;Purge overwrites these, so copy elsewhere
                sta saveSrcLo
                lda zpSrcHi
                sta saveSrcHi
                lda zpBitsLo
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
                jsr WaitBottom
                jsr SilenceSID
                sta $d01a                       ;Raster IRQs off
                sta $d011                       ;Blank screen completely                
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
                cmp loadTempReg
                bne SaveEraseOldSkip
                lda #$00
                jsr $df80                       ;Erase (zero) the old save directory entry
SaveEraseOldSkip:
                inx
                bne SaveEraseOld
SaveEraseOldDone:
                lda saveSizeLo                  ;Filesize-1 to know how many sectors to fill
                sbc #$01
                lda saveSizeHi
                sbc #$00
                sta zpBitsHi
SaveWriteFileEntry:
                lda loadTempReg                 ;Write the file number for all used sectors
                jsr $df80
                inx
                dec zpBitsHi
                bpl SaveWriteFileEntry
                dex                             ;Back out one byte
                iny
                lda saveSizeLo
                jsr $df80                       ;Write the amount of bytes in last sector ($00 = full sector)
                lda saveStartPos
                lsr
                lsr
                lsr
                lsr
                lsr
                ora firstSaveBank
                jsr $df86                       ;Set bank for write
                lda saveStartPos
                and #$1f
                ora #$80
                ldx #$00
                tay
                lda #$b0
                jsr $df8c                       ;Set address within bank for write
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

FileOpenSub:    ldx $d011                       ;Wait until bottom so that panelsplit IRQ will know to take advance
                bpl FileOpenSub
                inc fileOpen
                ldx #$37
                stx $01                         ;Cart ROM accessible
                jmp FileOpenSubFinish

firstSaveBank:  dc.b 0

                if * > $300
                    err
                endif

saveImplCodeEnd:ds.b irqVectors-saveImplCodeEnd,$ff

irqVectors:     dc.w NMI
                dc.w NMI
                dc.w NMI

FileOpenSubFinish:
                ldx #$00
                stx $d07a                       ;SCPU to slow mode
                stx $d030                       ;C128 back to 1MHz mode
                stx $de00                       ;Directory bank
                rts
NMI:            rti

                if NMI >= CrtRuntime
                    err
                endif

                rend

crtHelperCodeEnd:

crtRuntimeCodeStart:

                rorg CrtRuntime

                include exomizer.s

OpenFile:       jmp OpenFileEF
SaveFile:       jmp SaveFileEF
                
GetByte:        lda #$37
                sta $01
GB_SectorLda:   lda $8000
                inc GB_SectorLda+1
                dec loadBufferPos
                beq GB_FillBuffer
Restore01:      dec $01
                dec $01
                rts

OpenFileEF:     jsr FileOpenSub
                tax
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
                dec GB_SectorLda+2              ;Need to decrement, as it's incremented below in the first fillbuffer

GB_FillBuffer:  php
                pha
                stx loadTempReg
                ldx GB_SectorLda+2
                inx
GB_BankEndCmp:  cpx #$a0
                bcc GB_NoNextBank
                ldx #$80
                inc GB_BankNum+1
GB_NoNextBank:  stx GB_SectorLda+2
GB_BankNum:     ldx #$00
                stx $de00
GB_Sectors:     ldx #$00                        ;Full sectors remaining
                beq GB_LastSector
                cpx #$ff
                bne GB_MoreSectors
                dec fileOpen
                beq GB_FBDone
GB_LastSector:  lda #$00
                skip2
GB_MoreSectors: lda #$00
                sta loadBufferPos
                dec GB_Sectors+1
                lda #$00                        ;Reset sector read pointer
                sta GB_SectorLda+1
GB_FBDone:      ldx loadTempReg
                pla
                plp
                jmp Restore01

OF_SaveFile:    stx loadTempReg
                lda firstSaveBank               ;Get save directory bank
                sta $de00
                txa
                ldx #$02
OF_SaveLoop:    cmp $8000,x
                beq OF_SaveFound
                inx
                bne OF_SaveLoop
                dec fileOpen
                jmp Restore01                   ;Savefile was not found
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
                cmp loadTempReg
                bne OF_SaveEndFound
                inx
                iny
                bne OF_SaveLengthLoop
OF_SaveEndFound:lda $8100,x                     ;Length of last sector was stored when saving
                bne OF_NoLastFullSector         ;If it's full, increment number of sectors
                iny
OF_NoLastFullSector:
                ldx #$a0                        ;Savefiles use only the low chip
                jmp OF_StoreSectorCount

crtResidentLoaderEnd:

                if crtResidentLoaderEnd > loaderCodeEnd
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
                sei
                lda #$7f
                sta $dc0d                       ;Disable & acknowledge IRQ sources
                lda $dc0d
                ldx #$00
                stx $d011
                stx $d015
                stx $d020
                stx $d021
                stx $d07f                       ;Disable SCPU hardware regs
                stx $d07a                       ;SCPU to slow mode
                stx $dd00
                stx fileOpen                    ;Clear loader ZP vars
DetectNtsc1:    lda $d012                       ;Detect PAL/NTSC/Drean
DetectNtsc2:    cmp $d012
                beq DetectNtsc2
                bmi DetectNtsc1
                cmp #$20
                bcc IsNtsc
CountCycles:    inx
                lda $d012
                bpl CountCycles
                cpx #$8d
                bcc IsPal
IsDrean:        txa
IsNtsc:         sta ntscFlag
IsPal:
                lda #$18
                sta $d016
                lda #LOAD_EASYFLASH             ;Loader needs no mods
                sta loaderMode
                ldx #$00                        ;Directory bank
                stx $de00
                lda fileSaveStart               ;Get the save bank from the directory
                sta firstSaveBank
                lda #$35                        ;ROMs off
                sta $01
                lda #$00                        ;Open mainpart 
                jsr OpenFile
                lda #>(loaderCodeEnd-1)         ;Store mainpart entrypoint to stack
                pha
                tax
                lda #<(loaderCodeEnd-1)
                pha
                lda #<loaderCodeEnd
                jmp Depack                    ;Load mainpart (overwrites loader init)

                rend

crtRuntimeCodeEnd:
                ds.b $f800-crtRuntimeCodeEnd,$ff

                org $f800
                incbin eapi-am29f040-14

                org $fb00
                dc.b $65,$66,$2d,$6e,$41,$4d,$45,$3a
                dc.b "eXAMPLE gAME",0,0,0,0

cartNameEnd:    ds.b $fffa-cartNameEnd,$ff

                org $fffa
                dc.w NMI
                dc.w ColdStart
                dc.w NMI
