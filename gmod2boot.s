                include memory.s
                include loadsym.s
                include mainsymcart.s

EXOMIZER_ERRORHANDLING = 0
KILLKEY         = 1                         ;Left arrow

FIRSTSAVEFILE   = $78
SAVEDIRSIZE     = $20

saveDirectory   = $0100
CrtLoader       = $0200
irqVectors      = $0314
Startup         = $0500
fileStartLo     = $9e00
fileStartHi     = $9e80
fileSizeLo      = $9f00
fileSizeHi      = $9f80

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
NoKill:
CopyLoader:     lda crtLoaderCodeStart,x
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

crtLoaderCodeStart:

                rorg CrtLoader

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
GMOD2REG_SHADOW         = zpLenLo              ;This and rest of the ZP loader vars are not to be modified during savefile access
eeprom_data_temp        = loadTempReg

;------------------------------------------------------------
eeprom_reset:
                lda #$00
eeprom_set_reg_and_shadow:
                sta GMOD2REG_SHADOW
                sta GMOD2REG
                rts

;------------------------------------------------------------
; set chip select = low
eeprom_write_end:
                jsr eeprom_wait_ready
eeprom_cs_lo:
                lda GMOD2REG_SHADOW
                and #255-(EEPROM_SELECT)
                jmp eeprom_set_reg_and_shadow

;------------------------------------------------------------
; set chip select = high
eeprom_cs_high:
                lda GMOD2REG_SHADOW
                ora #(EEPROM_SELECT)
                bne eeprom_set_reg_and_shadow

;------------------------------------------------------------
; set clock = low
eeprom_clk_lo:
                lda GMOD2REG_SHADOW
                and #255-(EEPROM_CLOCK)
                jmp eeprom_set_reg_and_shadow

;------------------------------------------------------------
; set clock = high
eeprom_clk_high:
                lda GMOD2REG_SHADOW
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
; A: contains the bits to send, msb first
; X: number of bits to send
eeprom_write_byte:
eeprom_send_byte:
                ldx #$08
eeprom_send_bits:
                sta eeprom_data_temp
eeprom_send_bits_loop:
                asl eeprom_data_temp
                lda GMOD2REG_SHADOW
                and #255-(EEPROM_DATAIN)
                bcc eeprom_send_bits_low
                ora #(EEPROM_DATAIN)
eeprom_send_bits_low:
                sta GMOD2REG_SHADOW
                sta GMOD2REG
                jsr eeprom_clk_high
                jsr eeprom_clk_lo
                dex
                bne eeprom_send_bits_loop
                rts

;------------------------------------------------------------
; returns: A: the byte the was read
eeprom_receive_byte:
                ldx #$08
eeprom_receive_byte_loop:
                jsr eeprom_clk_high
                jsr eeprom_clk_lo
                lda GMOD2REG
                asl
                rol eeprom_data_temp
                dex
                bne eeprom_receive_byte_loop
                lda eeprom_data_temp
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
                and #$03
                asl
                asl
                asl
                ora #%11000000          ; 110xx = startbit, read, 2 bits addr
                ldx #$05
                jsr eeprom_send_bits
                pla                     ; 8 bits addr
                jmp eeprom_send_byte

eeprom_read_byte = eeprom_receive_byte
eeprom_read_end = eeprom_cs_lo

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
                jmp eeprom_write_byte

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
                jmp FindSaveFile

WriteSaveDirectory:
                jsr ChecksumSaveDirectory
                sta saveDirectory+SAVEDIRSIZE-1
                lda #<saveDirectory
                sta eepromPosLo                 ;Write dir to beginning of EEPROM
                sta eepromPosHi
                sta zpSrcLo
                lda #>saveDirectory
                sta zpSrcHi
WSD_Loop:       jsr SaveBytePair
                lda eepromPosLo                 ;Loop until the whole directory written
                cmp #SAVEDIRSIZE/2
                bcc WSD_Loop
                jmp eeprom_write_disable        ;Writing the dir is always the last thing to do, disable save now

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

saveImplCodeEnd:ds.b irqVectors-saveImplCodeEnd,$ff

irqVectors:     dc.w NMI
                dc.w NMI
                dc.w NMI

InitSave:       ldx #saveHelperCodeEnd-saveHelperCodeStart
InitSaveLoop:   lda saveHelperCodeStart-1,x
                sta saveDirectory+SAVEDIRSIZE-1,x
                dex
                bne InitSaveLoop
                stx GB_EndCmp+1
                jmp ReadSaveDirectory

irqVectorsEnd:  ds.b LoadFile-irqVectorsEnd,$ff

                include exomizer.s

exomizerCodeEnd:ds.b OpenFile-exomizerCodeEnd,$ff

                jmp OpenFileGMOD2
                jmp SaveFileGMOD2

GetByte:        ldx #$37
                stx $01
GetByteFast:    ldx loadBufferPos
GB_SectorLda:   lda $8000,x
GB_EndCmp:      cpx #$00
                bcs GB_FillBuffer
                inc loadBufferPos
Restore01:      ldx #$35
                stx $01
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
GB_BankEndCmp:  cpx #$a0
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

OpenFileGMOD2:  lda fileOpen                    ;Skip if already open
                bne OpenFileSkip
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
OF_StoreSectorCount:
                sta GB_LastSector+1
                sty GB_Sectors+1
                jmp GB_BankNum                  ;Init transfer from first sector
OF_SaveFile:    jsr InitSave                    ;Copy EEPROM helper code + read the EEPROM savefile directory + find & open savefile
                bcc GB_CloseFile
                lda saveDirectory+2,y           ;File found, get number of bytes to read
                sta zpBitsLo
                lda saveDirectory+3,y
                sta zpBitsHi
                lda #$4c                        ;Replace GetByte with jump to implementation
                sta GetByte
                lda #<SaveGetByteImpl
                sta GetByte+1
                lda #>SaveGetByteImpl
                sta GetByte+2
                ldy eepromPosLo
                ldx eepromPosHi
                jsr eeprom_reset_and_read_begin
                jmp Restore01

SaveFileGMOD2:  sta zpSrcLo
                stx zpSrcHi
                jsr FileOpenSub                 ;Cart ROM active
                jsr InitSave                    ;Get save position (either old or new file)
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
                jmp GB_CloseFile

crtLoaderRuntimeEnd:

                if crtLoaderRuntimeEnd > ntscFlag
                    err
                endif

                ds.b Startup-crtLoaderRuntimeEnd,$ff

Startup:        jsr $ff84   ; Initialise I/O
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
                lda #LOAD_GMOD2                 ;Loader needs no mods
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
                lda #$35                        ;ROMs off
                sta $01
                lda #>(loaderCodeEnd-1)         ;Store mainpart entrypoint to stack
                pha
                tax
                lda #<(loaderCodeEnd-1)
                pha
                lda #<loaderCodeEnd
                jmp LoadFile                    ;Load mainpart (overwrites loader init)

                rend

saveHelperCodeStart:

                rorg saveDirectory+SAVEDIRSIZE

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
                cmp fileNumber
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

StoreNewSaveFile:
                lda fileNumber
                sta saveDirectory+1,y
                lda zpBitsLo
                sta saveDirectory+2,y
                lda zpBitsHi
                sta saveDirectory+3,y
                inc saveDirectory               ;Increment number of files
                rts

ChecksumSaveDirectory:
                ldx #SAVEDIRSIZE-1
                txa
CSD_Loop:       eor.wx saveDirectory-1,x        ;Force absolute address to not pagecross incorrectly
                dex
                bne CSD_Loop                    ;Returns with X=0
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

SaveGetByteImpl:jsr eeprom_read_byte
                pha
                lda zpBitsLo
                bne SGBI_NoMSB
                dec zpBitsHi
SGBI_NoMSB:     dec zpBitsLo
                lda zpBitsLo
                ora zpBitsHi
                bne SGBI_NoEOF
                lda #$a2                        ;Restore original GetByte operation
                sta GetByte
                lda #$37
                sta GetByte+1
                lda #$86
                sta GetByte+2
                jsr eeprom_read_end
                pla
                jmp GB_CloseFile
SGBI_NoEOF:     pla
                clc
                rts

                rend

saveHelperCodeEnd:

                if saveHelperCodeEnd - saveHelperCodeStart > $a8
                    err
                endif

crtLoaderCodeEnd: