C_LEVEL         = 0                             ;Level chunk is fixed, and will be loaded from different filenames

        ; Create a number-based file name
        ;
        ; Parameters: A file number, X file number add
        ; Returns: fileName,C=0
        ; Modifies: A,X,zpSrcLo

MakeFileName:   stx zpSrcLo
                clc
                adc zpSrcLo
MakeFileName_Direct:
                sta fileNumber
LF_NoError:     rts

        ; Retry prompt for load error
        ;
        ; Parameters: -
        ; Returns: C=1
        ; Modifies: A,X,Y

RetryPrompt:    lda #<txtIOError
                ldx #>txtIOError
                jsr PrintPanelTextIndefinite
RP_WaitFire:    jsr GetControls
                bcc RP_WaitFire
                jmp ClearPanelText

        ; Allocate & load a resource file, and return address of object from inside.
        ; If no memory, purge unused files. Will retry on error
        ;
        ; Parameters: A object number, Y chunk file number (or X script number for GetScriptResource)
        ; Returns: loadRes chunk file number, zpDestLo-Hi file address, zpSrcLo-Hi object address (hi also in A)
        ; Modifies: A,X,Y,loader temp vars,resource load vars

GetZoneObject:  lda zoneNum
                ldy #C_LEVEL
                bpl GetResourceObject

GetScriptResource:
                pha
                txa
                clc
                adc #C_FIRSTSCRIPT
                tay
                pla

GetResourceObject:
LoadResourceFile:
                sta LF_ObjNum+1
                sty loadRes
LF_WasLoaded:   lda fileHi,y
                beq LF_NotInMemory
                sta zpDestHi
                lda fileLo,y
                sta zpDestLo                    ;Reset file age whenever accessed
                lda #$00
                sta fileAge,y
LF_ObjNum:      lda #$00
                asl
                tay
LF_GetObjectAddress:
                lda (zpDestLo),y
                sta zpSrcLo
                iny
                lda (zpDestLo),y
                sta zpSrcHi
                rts
LF_NotInMemory: tya
                ldx #F_CHUNK
                jsr MakeFileName
LF_CustomFileName:
                ldx #C_FIRSTPURGEABLE           ;When loading, age all other chunkfiles
LF_AgeLoop:     ldy fileHi,x
                beq LF_AgeSkip
                lda fileAge,x                   ;Needless to age past $80
                bmi LF_AgeSkip
                inc fileAge,x
LF_AgeSkip:     inx
                cpx #MAX_CHUNKFILES
                bcc LF_AgeLoop
LF_Retry:       jsr OpenFile
                jsr GetByte                     ;Get datasize lowbyte, check error
                bcs LF_Error
                sta dataSizeLo
                jsr GetByte                     ;Get datasize highbyte
                sta dataSizeHi
                jsr GetByte                     ;Get object count
                ldy loadRes
                sta fileNumObjects,y
                jsr PurgeUntilFree
                lda freeMemLo
                ldx freeMemHi
                ldy loadRes                     ;Level chunk is an exception: uncompressed data
                bne LF_IsCompressed

LF_Uncompressed:sta zpDestLo
                stx zpDestHi
                lda dataSizeHi
                sta zpBitsHi
                lda dataSizeLo
                sta zpBitsLo
                beq LF_UncompressedPredecrement
LF_UncompressedLoop:
                jsr GetByte
                bcs LF_Error
LF_UncompressedStore:
                sta (zpDestLo),y
                iny
                bne LF_UncompressedNoDestHi
                inc zpDestHi
LF_UncompressedNoDestHi:
                dec zpBitsLo
                bne LF_UncompressedLoop
LF_UncompressedPredecrement:
                dec zpBitsHi
                bpl LF_UncompressedLoop
                bmi LF_UncompressedDone

LF_IsCompressed:jsr LoadFile
                bcc LF_UncompressedDone
LF_Error:       jsr RetryPrompt
                bcs LF_Retry

        ; Finish loading, relocate chunk object pointers

LF_UncompressedDone:
                ldy loadRes
                lda freeMemLo                   ;Increment free mem pointer
                sta zpBitsLo
                sta zpDestLo
                sta fileLo,y
                adc dataSizeLo                  ;C=0 here
                sta freeMemLo
                lda freeMemHi
                sta zpBitsHi
                sta zpDestHi
                sta fileHi,y
                adc dataSizeHi
                sta freeMemHi
                cpy #C_FIRSTSCRIPT              ;Is script that requires code relocation?
                bcc LF_NotScript
                lda zpBitsHi                    ;Scripts are initially relocated at $8000
                sbc #>scriptCodeRelocStart      ;to distinguish between resident & loadable code
                sta zpBitsHi
LF_NotScript:   jsr LF_Relocate
                ldy loadRes
                jmp LF_WasLoaded                ;Retry getting the object address now

LF_Relocate:    ldx fileNumObjects,y
                sty zpBitBuf
                ;txa                            ;There are no objectless files
                ;beq LF_RelocDone
                ldy #$00
LF_RelocateLoop:lda (zpDestLo),y                ;Relocate object pointers
                clc
                adc zpBitsLo
                sta (zpDestLo),y
                iny
                lda (zpDestLo),y
                adc zpBitsHi
                sta (zpDestLo),y
                iny
                dex
                bne LF_RelocateLoop
LF_RelocDone:   ldy zpBitBuf
                cpy #C_FIRSTSCRIPT
                bcc LF_NoCodeReloc
                ldy #$00
                jsr LF_GetObjectAddress         ;Start relocation from the first entrypoint (must be first in file)
                ;lda fileNumObjects,y           ;Assume that code starts immediately past the object pointers
                ;asl
                ;adc zpDestLo
                ;sta zpSrcLo
                ;lda zpDestHi
                ;adc #$00
                ;sta zpSrcHi
LF_CodeRelocLoop:
                ldy #$00
                lda (zpSrcLo),y                 ;Read instruction
                beq LF_CodeRelocDone            ;BRK - done
                lsr
                lsr
                lsr
                bcc LF_LookupLength
                and #$01                        ;Instructions xc - xf are always 3 bytes
                ora #$02                        ;Instructions x4 - x7 are always 2 bytes
                bne LF_HasLength
LF_LookupLength:tax
                lda (zpSrcLo),y
                and #$03
                tay
                lda instrLenTbl,x               ;4 lengths packed into one byte
LF_DecodeLength:dey
                bmi LF_DecodeLengthDone
                lsr                             ;Shift until we have the one we want
                lsr
                bpl LF_DecodeLength
LF_DecodeLengthDone:
                and #$03
LF_HasLength:   cmp #$03                        ;3 byte long instructions need relocation
                bne LF_NotAbsolute
                ldy #$02
                lda (zpSrcLo),y                 ;Read absolute address highbyte
                cmp #>(fileAreaStart+$100)      ;Is it a reference to self or to resident code/data?
                bcc LF_NoRelocation             ;(filearea start may not be page-aligned, but the common sprites
                cmp #>fileAreaEnd               ;will always be first)
                bcs LF_NoRelocation
                dey
                lda (zpSrcLo),y                 ;Add relocation offset to the absolute address
                adc zpBitsLo
                sta (zpSrcLo),y
                iny
                lda (zpSrcLo),y
                adc zpBitsHi
                sta (zpSrcLo),y
LF_NoRelocation:lda #$03
LF_NotAbsolute: ldx #<zpSrcLo
                jsr Add8
                jmp LF_CodeRelocLoop
LF_CodeRelocDone:
PF_Done:
LF_NoCodeReloc: rts

        ; Remove a chunk-file from memory
        ;
        ; Parameters: Y file number
        ; Returns: -
        ; Modifies: A,X,loader temp vars

PurgeFile:      lda fileHi,y
                beq PF_Done
                sty zpLenLo
                lda fileLo,y
                sta zpDestLo
                lda fileHi,y
                sta zpDestHi
                lda freeMemLo
                sta zpSrcLo
                lda freeMemHi
                sta zpSrcHi
                ldx #MAX_CHUNKFILES-1
PF_FindSizeLoop:cpx zpLenLo
                beq PF_FindSizeSkip
                ldy fileLo,x
                cpy zpDestLo
                lda fileHi,x
                sbc zpDestHi
                bcc PF_FindSizeSkip
                cpy zpSrcLo
                lda fileHi,x
                sbc zpSrcHi
                bcs PF_FindSizeSkip
                sty zpSrcLo
                lda fileHi,x
                sta zpSrcHi
PF_FindSizeSkip:dex
                bpl PF_FindSizeLoop
                ldx #<freeMemLo
                jsr PF_Sub
                jsr CopyMemory
                ldx #<zpDestLo
                jsr PF_Sub
                ldx #<freeMemLo
                ldy #<zpBitsLo
                jsr Add16                       ;Shift the free memory pointer
                tsx
                inx
                ldy zpLenLo
PF_RelocateStack:                               ;If the stack contains references to the relocated file or files above it,
                lda fileLo,y                    ;move the reference (stack must only contain return addresses)
                cmp $0100,x
                lda fileHi,y
                sbc $0101,x
                bcs PF_RelocateStackSkip
                lda $0100,x
                adc zpBitsLo
                sta $0100,x
                lda $0101,x
                adc zpBitsHi
                sta $0101,x
PF_RelocateStackSkip:
                inx
                inx
                bne PF_RelocateStack
                lda textLo                      ;Relocate current text pointer if necessary
                cmp fileLo,y
                lda textHi
                beq PF_RelocateTextSkip
                sbc fileHi,y
                bcc PF_RelocateTextSkip
                ldx #<textLo
                ldy #<zpBitsLo
                jsr Add16
PF_RelocateTextSkip:
                ldy #MAX_CHUNKFILES-1
PF_RelocLoop:   ldx zpLenLo
                lda fileLo,x                    ;Need relocation? (higher in memory than purged file)
                cmp fileLo,y                    ;Unloaded files (ptr 0) are by definition lower so will be skipped,
                lda fileHi,x                    ;as well as when indices are the same
                sbc fileHi,y
                bcs PF_RelocNext
                lda fileLo,y                    ;Relocate the file pointer
                adc zpBitsLo
                sta fileLo,y
                sta zpDestLo
                lda fileHi,y
                adc zpBitsHi
                sta fileHi,y
                sta zpDestHi
                jsr LF_Relocate                 ;Relocate the object pointers
                ldy zpBitBuf
PF_RelocNext:   dey
                bpl PF_RelocLoop
                ldy zpLenLo
                lda #$00
                sta fileHi,y                    ;Mark chunk not in memory
                sta fileAge,y                   ;and reset age for eventual reload
PUF_HasFreeMemory:
                rts

PF_Sub:         lda $00,x
                sec
                sbc zpSrcLo
                sta zpBitsLo
                lda $01,x
                sbc zpSrcHi
                sta zpBitsHi
                rts

        ; Remove files until enough memory to load the new file
        ;
        ; Parameters: dataSizeLo-Hi new object size, zoneBufferLo-Hi zone buffer start (alloc area end)
        ; Returns: -
        ; Modifies: A,X,Y,loader temp vars

PurgeUntilFreeNoNew:
                lda #$00
                sta dataSizeLo
                sta dataSizeHi
PurgeUntilFree: lda freeMemLo
                sta zpBitsLo
                lda freeMemHi
                sta zpBitsHi
                ldx #<zpBitsLo
                ldy #<dataSizeLo
                jsr Add16
                lda zpBitsLo
                cmp zoneBufferLo
                lda zpBitsHi
                sbc zoneBufferHi
                bcc PUF_HasFreeMemory
PUF_Loop:       ldx #$01
                stx zpBitBuf
                txa                             ;The first chunk (level) is exempt from purge
PUF_FindOldestLoop:
                ldy fileAge,x
                cpy zpBitBuf
                bcc PUF_FindOldestSkip
                sty zpBitBuf
                txa
PUF_FindOldestSkip:
                inx
                cpx #MAX_CHUNKFILES
                bcc PUF_FindOldestLoop
                tay
                jsr PurgeFile
                jmp PurgeUntilFree

        ; Save player state to in-memory checkpoint
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,loader temp vars, temp vars

SavePlayerState:ldx #NUM_SAVEMISCVARS-1
SPS_Loop:       jsr GetSaveMiscVar
                lda (zpSrcLo),y
                sta saveMiscVars,x
                dex
                bpl SPS_Loop
                ldx #<zpSrcLo
                ldy #<zpDestLo
CopySaveStateComplete:
                lda #$00
CopySaveState:  pha
                clc
                adc #<playerStateStart
                sta $00,x
                lda #$00
                adc #>playerStateStart
                sta $01,x
                pla
                adc #<savePlayerState
                sta $00,y
                lda #$00
                adc #>savePlayerState
                sta $01,y
                lda #<(playerStateEnd-playerStateStart)
                sta zpBitsLo
                lda #>(playerStateEnd-playerStateStart)
                sta zpBitsHi

        ; Copy a block of memory
        ;
        ; Parameters: zpSrcLo,Hi source zpDestLo,Hi dest zpBitsLo,Hi amount of bytes
        ; Returns: N=1, X=0
        ; Modifies: A,X,Y,loader temp vars

CopyMemory:     ldy #$00
                ldx zpBitsLo                    ;Predecrement highbyte if lowbyte 0 at start
                beq CM_Predecrement
CM_Loop:        lda (zpSrcLo),y
                sta (zpDestLo),y
                iny
                bne CM_NotOver
                inc zpSrcHi
                inc zpDestHi
CM_NotOver:     dex
                bne CM_Loop
CM_Predecrement:dec zpBitsHi
                bpl CM_Loop
                rts

        ; Depack Exomizer packed data from memory
        ;
        ; Parameters: A,X destination, zpSrcLo,Hi source
        ; Returns: C=0
        ; Modifies: A,X,Y,loader temp vars

DepackFromMemory:
                ldy zpSrcLo
                sty DFM_GetByte+1
                ldy zpSrcHi
                sty DFM_GetByte+2
                sta zpDestLo
                stx zpDestHi
                jsr SwitchGetByte
                jsr Depack
SwitchGetByte:  ldx #$02
SWG_Loop:       lda GetByte,x
                eor getByteJump,x               ;Swap normal getbyte & from-memory getbyte
                sta GetByte,x
                dex
                bpl SWG_Loop
                rts

DFM_GetByte:    lda $1000
                inc DFM_GetByte+1
                bne DFM_GetByteNoHigh
                inc DFM_GetByte+2
DFM_GetByteNoHigh:
                clc
                rts
