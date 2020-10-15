                include memory.s
                include loadsym.s
                include ldepacksym.s

KILLKEY         = 1                         ;Left arrow

FIRSTSAVEFILE   = $f0
SAVEDIRSIZE     = $20

saveDirectory   = depackBuffer
CrtHelper       = $0200
irqVectors      = $0314
CrtRuntime      = exomizerCodeStart
fileStartLo     = $9c00
fileStartHi     = $9d00
fileSizeLo      = $9e00
fileSizeHi      = $9f00

eepromPosLo     = xHi
eepromPosHi     = yHi

                org $8000
                processor 6502

                dc.w CrtStart
                dc.w CrtStart
                dc.b $c3 ;c
                dc.b $c2 ;b
                dc.b $cd ;m
                dc.b $38 ;8
                dc.b $30 ;0

CrtStart:       sei
                ldx #$ff
                txs
                cld
                inx                             ;X=0
                stx $d016

                if KILLKEY > 0
                lda #$ff                        ;Check if left-arrow key is pressed
                sta $dc02
                lda #$00
                sta $dc03
                lda #$7f
                sta $dc00
                lda $dc01
                cmp #$fd
                bne NoKill
                jsr $fda3                       ;Prepare irq
                jsr $fd50                       ;Init memory
                jsr $fd15                       ;Init i/o
                jsr $ff5b                       ;Init video
                cli
                jmp ($a000)                     ;Start Basic
                endif
NoKill:         jsr CopyLoader
                jmp Startup

CopyLoader:     copycrtcode crtHelperCodeStart,crtHelperCodeEnd,CrtHelper
                copycrtcode crtRuntimeCodeStart,crtRuntimeCodeEnd,CrtRuntime
                rts

crtHelperCodeStart:

                rorg CrtHelper

;============================================================
; GMOD2 EEPROM Runtime
; Version 1.0.0
; (C) 2016 by Chester Kollschen (original code)
;             Tobias Korbmacher (cleanup and comments)
;------------------------------------------------------------

GMOD2REG        = $de00

GMOD2_FLASHMODE = $c0
GMOD2_ROMDISABLE = $40

EEPROM_DATAOUT  = $80
EEPROM_SELECT   = $40
EEPROM_CLOCK    = $20
EEPROM_DATAIN   = $10

; copy of the value stored into the cartridge register
gmod2ShadowReg  = zpLenLo              ;This and rest of the ZP loader vars are not to be modified during savefile access
eepromDataTemp  = loadBufferPos

;------------------------------------------------------------
eeprom_reset:
                lda #$00
                beq eeprom_set_reg_and_shadow

;------------------------------------------------------------
; set chip select = low
eeprom_write_end:
                jsr eeprom_wait_ready
eeprom_cs_lo:
                lda gmod2ShadowReg
                and #255-(EEPROM_SELECT)
eeprom_set_reg_and_shadow:
                sta gmod2ShadowReg
                sta GMOD2REG
                rts

;------------------------------------------------------------
; set chip select = high
eeprom_cs_high:
                lda gmod2ShadowReg
                ora #(EEPROM_SELECT)
                bne eeprom_set_reg_and_shadow

;------------------------------------------------------------
; set clock = low and decrement X. X must not become negative
eeprom_clk_lo_decx:
                lda gmod2ShadowReg
                and #255-(EEPROM_CLOCK)
                dex
                bpl eeprom_set_reg_and_shadow

;------------------------------------------------------------
; set clock = high
eeprom_clk_high:
                lda gmod2ShadowReg
                ora #(EEPROM_CLOCK)
                bne eeprom_set_reg_and_shadow

;------------------------------------------------------------
eeprom_wait_ready:
                jsr eeprom_cs_lo
                jsr eeprom_cs_high
                lda #(EEPROM_DATAOUT)
eeprom_wait_ready_loop:
                bit GMOD2REG
                beq eeprom_wait_ready_loop
                rts

;------------------------------------------------------------
; a typical write sequence looks like this:
;
; eeprom_reset
; eeprom_write_enable
;                      <----+
; eeprom_write_begin        |
; eeprom_write_byte         |
; eeprom_write_byte         |
; eeprom_write_end          |
;              -------------+
; eeprom_write_disable
;------------------------------------------------------------

;------------------------------------------------------------
; x = lower 2 bits contain the 2 highest bits of the address
; y = lower 8 bits of the address
eeprom_write_begin:
                jsr eeprom_cs_high
                tya
                pha
                txa
                and #$03
                asl
                asl
                asl
                ora #%10100000          ; 101xx = startbit, read, 2 bits addr
                ldx #$05
                jsr eeprom_send_bits
                pla                     ; 8 bits addr
                ;ldx #$08
                ;jmp eeprom_send_bits
                ; fall through

;------------------------------------------------------------
; A: contains the bits to send, msb first
; X: number of bits to send
eeprom_write_byte:
eeprom_send_byte:
                ldx #$08
eeprom_send_bits:
                sta eepromDataTemp
eeprom_send_bits_loop:
                asl eepromDataTemp
                lda gmod2ShadowReg
                and #255-(EEPROM_DATAIN)
                bcc eeprom_send_bits_low
                ora #(EEPROM_DATAIN)
eeprom_send_bits_low:
                sta gmod2ShadowReg
                sta GMOD2REG
                bit $00                         ;Hole in memory for Kernal
                jsr eeprom_clk_high
                jsr eeprom_clk_lo_decx
                bne eeprom_send_bits_loop
                rts
                dc.b $00                        ;Hole in memory for Kernal

;------------------------------------------------------------
; returns: A: the byte the was read
eeprom_receive_byte:
                ldx #$08
eeprom_receive_byte_loop:
                jsr eeprom_clk_high
                jsr eeprom_clk_lo_decx
                bit $00                         ;Hole in memory for Kernal
                lda GMOD2REG
                asl
                rol eepromDataTemp
                txa
                bne eeprom_receive_byte_loop
                lda eepromDataTemp
                rts

;------------------------------------------------------------
eeprom_reset_and_write_enable:
                jsr eeprom_reset
                jsr eeprom_cs_high
                lda #%10011000          ; 10011 = startbit, write enable
eeprom_send_5bits_then_dummy_byte:
                ldx #$05
                jsr eeprom_send_bits
                lda #%00000000          ; dummy
                jsr eeprom_send_byte
                jmp eeprom_cs_lo

;------------------------------------------------------------
eeprom_write_disable:
                jsr eeprom_cs_high
                lda #%10000000          ; 10000 = startbit, write diable
                bne eeprom_send_5bits_then_dummy_byte

;------------------------------------------------------------
; a typical read sequence looks like this:
;
; eeprom_reset
; eeprom_read_begin
;                      <----+
; eeprom_read_byte          |
;              -------------+
; eeprom_read_end
;------------------------------------------------------------

;------------------------------------------------------------
; x = lower 2 bits contain the 2 highest bits of the address
; y = lower 8 bits of the address
eeprom_reset_and_read_begin:
                jsr eeprom_reset
                jsr eeprom_cs_high
                tya
                pha
                txa
                asl
                bit $00                 ; Hole in the memory for Kernal
                and #$06
                asl
                asl
                ora #%11000000          ; 110xx = startbit, read, 2 bits addr
                ldx #$05
                jsr eeprom_send_bits
                pla                     ; 8 bits addr
                jmp eeprom_send_byte

eeprom_read_byte = eeprom_receive_byte
eeprom_read_end = eeprom_cs_lo

InitSaveRead:   ldx #saveReadHelperCodeEnd-saveReadHelperCodeStart
InitSaveReadLoop:
                lda saveReadHelperCodeStart-1,x
                sta saveDirectory+SAVEDIRSIZE-1,x
                dex
                bne InitSaveReadLoop
                jmp ReadSaveDirectory

InitSaveWrite:  jsr InitSaveRead ;First read dir & find savefile
                ldx #saveWriteHelperCodeEnd-saveWriteHelperCodeStart
InitSaveWriteLoop:
                lda saveWriteHelperCodeStart-1,x
                sta saveDirectory+SAVEDIRSIZE-1,x
                dex
                bne InitSaveWriteLoop
                rts

CloseSaveFile:  lda #$ad                        ;Restore original GetByte operation
                sta GetByte+4
                jsr eeprom_read_end
                dec fileOpen
                pla
                jmp Restore01

FileOpenSub:    ldx $d011                       ;Wait until bottom so that panelsplit IRQ will know to take advance
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

                if * > $300
                    err
                endif

saveImplCodeEnd:ds.b irqVectors-saveImplCodeEnd,$ff

irqVectors:     dc.w NMI
                dc.w NMI
                dc.w NMI

ChecksumSaveDirectory:
                ldx #SAVEDIRSIZE-1
                txa
CSD_Loop:       eor.wx saveDirectory-1,x        ;Force absolute address to not pagecross incorrectly
                dex
                bne CSD_Loop                    ;Returns with X=0
                rts

                if * > CrtRuntime
                    err
                endif

                rend

crtHelperCodeEnd:

crtRuntimeCodeStart:

                rorg CrtRuntime

                include exomizer.s

OpenFile:       jmp OpenFileGMOD2
SaveFile:       jmp SaveFileGMOD2

GetByte:        lda #$37
                sta $01
GB_SectorLda:   lda $8000
                inc GB_SectorLda+1
                dec loadBufferPos
                beq GB_FillBuffer
Restore01:      dec $01
                dec $01
                rts

OpenFileGMOD2:  jsr FileOpenSub
                tax
                cpx #FIRSTSAVEFILE
                bcs OF_SaveFile                 ;Save files handled differently
                lda fileStartHi,x
                sta GB_BankNum+1
                lda fileStartLo,x
                sbc #$00                        ;C=0
                sta GB_SectorLda+2
                lda fileSizeLo,x
                ldy fileSizeHi,x
OF_StoreSectorCount:
                sta GB_LastSector+1
                sty GB_Sectors+1

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

SF_CloseFile:
OF_SaveNotFound:dec fileOpen
                beq Restore01

OF_SaveFile:    stx loadTempReg                 ;File number
                jsr InitSaveRead                ;Copy save-read helper code + read the EEPROM savefile directory + find & open savefile
                bcc OF_SaveNotFound
                lda saveDirectory+2,y           ;File found, get number of bytes to read
                sta zpBitsLo
                lda saveDirectory+3,y
                sta zpBitsHi
                lda #$4c                        ;Replace GetByte with jump to implementation
                sta GetByte+4
                lda #<SaveGetByteImpl
                sta GetByte+5
                lda #>SaveGetByteImpl
                sta GetByte+6
                ldy eepromPosLo
                ldx eepromPosHi
                jsr eeprom_reset_and_read_begin
                jmp Restore01

SaveFileGMOD2:  sta loadTempReg                 ;File number
                jsr FileOpenSub                 ;Cart ROM active
                jsr InitSaveWrite               ;Get save position (either old or new file)
                bcs SF_Old
                jsr StoreNewSaveFile
SF_Old:         jsr eeprom_reset_and_write_enable
SF_BytePairLoop:jsr SaveBytePair
SF_NoMSB:       lda zpBitsLo
                sec
                sbc #$02
                sta zpBitsLo
                bcs SF_NoMSB2
                dec zpBitsHi
                bmi SF_SaveEnd                  ;Overshot?
SF_NoMSB2:      lda zpBitsLo                    ;Or out of bytes to save?
                ora zpBitsHi
                bne SF_BytePairLoop
SF_SaveEnd:     jsr WriteSaveDirectory          ;Write in-memory directory last & disable EEPROM saving
                jmp SF_CloseFile

crtResidentLoaderEnd:

                if crtResidentLoaderEnd > loaderCodeEnd
                    err
                endif

Startup:        jsr $ff84                       ;Initialise I/O
                sei
                lda #$7f
                sta $dc0d                       ;Disable & acknowledge IRQ sources
                lda $dc0d
                ldx #$00
                stx $d015
                stx $d020
                stx $d021
                stx $d07f                       ;Disable SCPU hardware regs
                stx $d07a                       ;SCPU to slow mode
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
                lda #$0b
                sta $d011                       ;Blank screen
                lda #$35                        ;ROMs off
                sta $01
                lda #LOAD_GMOD2                 ;Loader needs no mods
                sta loaderMode
                lda #$00                        ;Open & load mainpart
                jsr OpenFile
                lda #>(loaderCodeEnd-1)
                pha
                lda #<(loaderCodeEnd-1)
                pha
                lda #<loaderCodeEnd
                ldx #>loaderCodeEnd
                jmp Depack

                rend

crtRuntimeCodeEnd:

saveReadHelperCodeStart:

                rorg saveDirectory+SAVEDIRSIZE

ReadSaveDirectory:
                ldx #$00
                ldy #$00
                jsr eeprom_reset_and_read_begin
RSD_Loop:       jsr eeprom_read_byte
                sta saveDirectory,y
                iny
                cpy #SAVEDIRSIZE
                bne RSD_Loop
                jsr eeprom_read_end
                jsr ChecksumSaveDirectory       ;Checksum save dir, try to find the requested file
                cmp saveDirectory+SAVEDIRSIZE-1

FindSaveFile:   beq FSF_ChecksumOK
                stx saveDirectory               ;If checksum mismatch, zero number of files to start over
FSF_ChecksumOK: lda #SAVEDIRSIZE                ;Address in EEPROM in bytes
                sta eepromPosLo
                ldy #$00
                sty eepromPosHi
                ldx saveDirectory               ;Number of entries to go through
FSF_Loop:       dex
                bmi FSF_NotFound
                lda saveDirectory+1,y
                cmp loadTempReg                 ;Check file number
                beq FSF_Found                   ;C=1, found
                lda saveDirectory+2,y           ;Save file allocation size always even, do padding
                lsr                             ;when advancing to the next file
                lda eepromPosLo
                adc saveDirectory+2,y
                sta eepromPosLo
                lda eepromPosHi
                adc saveDirectory+3,y
                sta eepromPosHi
                iny                             ;Proceed to next entry
                iny
                iny
                bne FSF_Loop
FSF_NotFound:   clc
FSF_Found:      php
                lsr eepromPosHi                 ;Convert address to words for the EEPROM
                ror eepromPosLo
                plp
                rts

SaveGetByteImpl:stx loadTempReg
                jsr eeprom_read_byte
                ldx loadTempReg
                pha
                lda zpBitsLo
                bne SGBI_NoMSB
                dec zpBitsHi
SGBI_NoMSB:     dec zpBitsLo
                lda zpBitsLo
                ora zpBitsHi
                beq SGBI_EOF
                pla
                jmp Restore01
SGBI_EOF:       jmp CloseSaveFile

saveReadHelperStackEnd:

                rend

                if saveReadHelperStackEnd > $1c0
                    err
                endif

saveReadHelperCodeEnd:

saveWriteHelperCodeStart:

                rorg saveDirectory+SAVEDIRSIZE

WriteSaveDirectory:
                jsr ChecksumSaveDirectory
                sta saveDirectory+SAVEDIRSIZE-1
                lda #$00
                sta eepromPosLo                 ;Write dir to beginning of EEPROM
                sta eepromPosHi
                lda #<saveDirectory
                sta zpSrcLo
                lda #>saveDirectory
                sta zpSrcHi
WSD_Loop:       jsr SaveBytePair
                lda eepromPosLo                 ;Loop until the whole directory written
                cmp #SAVEDIRSIZE/2
                bcc WSD_Loop
                jmp eeprom_write_disable        ;Writing the dir is always the last thing to do, disable save now

StoreNewSaveFile:
                lda loadTempReg
                sta saveDirectory+1,y
                lda zpBitsLo
                sta saveDirectory+2,y
                lda zpBitsHi
                sta saveDirectory+3,y
                inc saveDirectory               ;Increment number of files
                rts

SaveBytePair:   ldy eepromPosLo                 ;EEPROM current save location
                ldx eepromPosHi
                jsr eeprom_write_begin
                jsr SaveByte
                jsr SaveByte
                jsr eeprom_write_end
                inc eepromPosLo                 ;Increment EEPROM address
                bne SBP_NoMSB
                inc eepromPosHi
SBP_NoMSB:      rts

SaveByte:       ldy #$00
                lda (zpSrcLo),y
                jsr eeprom_write_byte
                inc zpSrcLo
                bne SB_NoMSB
                inc zpSrcHi
SB_NoMSB:       rts

saveWriteHelperStackEnd:

                rend

                if saveWriteHelperStackEnd > $1c0
                    err
                endif

saveWriteHelperCodeEnd:
