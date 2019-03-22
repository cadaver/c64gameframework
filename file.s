C_LEVEL         = 0                             ;Level chunk is fixed, and will be loaded from different filenames

        ; Set file number, add file type
        ;
        ; Parameters: A file number, X file type add
        ; Returns: fileNumber (also in A), C=0
        ; Modifies: A,X,zpSrcLo

MakeFileNumber: stx zpSrcLo
                clc
                adc zpSrcLo
                sta fileNumber
OFWR_OK:        rts

        ; Allocate & load a resource file, and return address of object from inside.
        ; If no memory, purge unused files.
        ;
        ; Parameters: A object number, Y chunk file number (or X script number for GetScriptResource)
        ; Returns: loadRes chunk file number, zpDestLo-Hi file address, zpSrcLo-Hi object address (hi also in A)
        ; Modifies: A,X,Y,loader temp vars,resource load vars

GetLevelResourceObject:
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
LoadResource:   sta LR_ObjNum+1
                sty loadRes
LR_WasLoaded:   lda fileHi,y
                beq LR_NotInMemory
                sta zpDestHi
                lda fileLo,y
                sta zpDestLo                    ;Reset file age whenever accessed
                lda #$00
                sta fileAge,y
LR_ObjNum:      lda #$00
                asl
                tay
LR_GetObjectAddress:
                lda (zpDestLo),y
                sta zpSrcLo
                iny
                lda (zpDestLo),y
                sta zpSrcHi
                rts
LR_NotInMemory: tya
                ldx #F_CHUNK
                jsr MakeFileNumber
LoadResourceCustomFileName:
                ldx #C_FIRSTPURGEABLE           ;When loading, age all other chunkfiles
LR_AgeLoop:     ldy fileHi,x
                beq LR_AgeSkip
                lda fileAge,x                   ;Needless to age past $80
                bmi LR_AgeSkip
                inc fileAge,x
LR_AgeSkip:     inx
                cpx #MAX_CHUNKFILES
                bcc LR_AgeLoop
                lda fileNumber
                jsr OpenFile
                jsr GetByte                     ;Get datasize lowbyte
                sta dataSizeLo
                jsr GetByte                     ;Get datasize highbyte
                sta dataSizeHi
                jsr GetByte                     ;Get object count
                ldy loadRes
                sta fileNumObjects,y
                jsr PurgeUntilFree
                lda freeMemLo
                ldx freeMemHi
                jsr Depack

        ; Finish loading, relocate chunk object pointers

                ldy loadRes
                lda freeMemLo                   ;Increment free mem pointer
                sta zpBitsLo
                sta zpDestLo
                sta fileLo,y
                clc
                adc dataSizeLo
                sta freeMemLo
                lda freeMemHi
                sta zpBitsHi
                sta zpDestHi
                sta fileHi,y
                adc dataSizeHi
                sta freeMemHi
                cpy #C_FIRSTSCRIPT              ;Is script that requires code relocation?
                bcc LR_NotScript
                lda zpBitsHi                    ;Scripts are initially relocated at $8000
                sbc #>scriptCodeRelocStart      ;to distinguish between resident & loadable code
                sta zpBitsHi
LR_NotScript:   jsr LR_Relocate
                ldy loadRes
                jmp LR_WasLoaded                ;Retry getting the object address now

LR_Relocate:    ldx fileNumObjects,y
                sty zpBitBuf
                ;txa                            ;There are no objectless files
                ;beq LR_RelocDone
                ldy #$00
LR_RelocateLoop:jsr LR_RelocAddDelta
                iny
                dex
                bne LR_RelocateLoop
LR_RelocDone:   lda zpBitBuf
                cmp #C_FIRSTSCRIPT
                bcc LR_NoCodeReloc
                tya                             ;Go past the object pointers to get into code
LR_CodeRelocLoop:
                ldx #<zpDestLo
                jsr Add8
                ldy #$00
                lda (zpDestLo),y                ;Read instruction
                beq LR_CodeRelocDone            ;BRK - done
                lsr
                lsr
                lsr
                bcc LR_LookupLength
                and #$01                        ;Instructions xc - xf are always 3 bytes
                ora #$02                        ;Instructions x4 - x7 are always 2 bytes
                bne LR_HasLength
LR_LookupLength:tax
                lda (zpDestLo),y
                and #$03
                tay
                lda instrLenTbl,x               ;4 lengths packed into one byte
LR_DecodeLength:dey
                bmi LR_DecodeLengthDone
                lsr                             ;Shift until we have the one we want
                lsr
                bpl LR_DecodeLength
LR_DecodeLengthDone:
                and #$03
LR_HasLength:   cmp #$03                        ;3 byte long instructions need relocation
                bne LR_CodeRelocLoop
                ldy #$02
                lda (zpDestLo),y                ;Read absolute address highbyte
                cmp #>(fileAreaStart+$100)      ;Is it a reference to self or to resident code/data?
                bcc LR_NoRelocation             ;(filearea start may not be page-aligned, but the common sprites
                cmp #>fileAreaEnd               ;will always be first)
                bcs LR_NoRelocation
                dey
                jsr LR_RelocAddDelta
LR_NoRelocation:lda #$03
                bne LR_CodeRelocLoop

LR_RelocAddDelta:
                lda (zpDestLo),y
                clc
                adc zpBitsLo
                sta (zpDestLo),y
                iny
                lda (zpDestLo),y
                adc zpBitsHi
                sta (zpDestLo),y
LR_CodeRelocDone:
LR_NoCodeReloc:
PF_Done:        rts

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
                jsr LR_Relocate                 ;Relocate the object pointers
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
                clc
                adc dataSizeLo
                sta zpBitsLo
                tax
                lda freeMemHi
                adc dataSizeHi
                cpx zoneBufferLo
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
CopySaveState:  lda #<playerStateStart
                sta $00,x
                lda #>playerStateStart
                sta $01,x
                lda #<savePlayerState
                sta $00,y
                lda #>savePlayerState
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
