LOGSPR_CONNECT  = 0 ;Complex logical sprite only
LOGSPR_FLAGS    = 3 ;Both simple and complex logical sprites
LOGSPR_DATA     = 4 ;Bounds and physsprites in complex logical sprite

PHYSSPR_CACHEFRAME = 0
PHYSSPR_CACHEFRAMEFLIP = 1
PHYSSPR_COLOR   = 2
PHYSSPR_SLICEMASK = 3
PHYSSPR_DATA    = 5

COLOR_XEXPAND   = $10
COLOR_OVERLAY   = $20                           ;No scrolling / interpolation (portrait sprites)
COLOR_FLICKER   = $40
COLOR_INVISIBLE = $80

FIRSTCACHEFRAME = (spriteCache-$c000)/$40

        ; Draw a logical sprite, which can consist of one (simple) or multiple (complex) physical sprites
        ; The simple case is optimized; sprite data is contained in the same resource object
        ;
        ; Parameters: A frame number, Y file number, actIndex actor index, actColorOr/And
        ;             xLo,yLo actor X/Y coordinates
        ; Returns: X actIndex
        ; Modifies: A,X,Y,xLo,yLo,loader ZP vars

DLS_Complex:    lsr
                bcs DLS_ComplexNoConnect
                tay                             ;A=0
                lda (zpSrcLo),y
                adc yLo
                sta yLo                         ;Add connect-spot to Y coords
                iny
                clc
                bit sprFrameNum
                bpl DLS_ComplexConnectNotFlipped
DLS_ComplexConnectFlipped:
                iny
                lda (zpSrcLo),y
                bcc DLS_ComplexConnectCommon
DLS_ComplexConnectNotFlipped:
                lda (zpSrcLo),y
                iny                             ;Skip over the flipped X connect spot
DLS_ComplexConnectCommon:
                adc xLo
                sta xLo                         ;Add connect-spot to X coords
DLS_ComplexNoConnect:
                jmp DLS_ComplexBounds           ;DO NOT CHANGE THIS, modified in code

DLS_LoadSprFile:jsr LoadResource
                jmp DLS_SprFileLoaded

DrawLogicalSpriteDir:
                eor actD,x
DrawLogicalSprite:
                sta sprFrameNum                 ;Store spritenumber
                ldx fileHi,y
                beq DLS_LoadSprFile
DLS_InMemory:   stx zpDestHi
                ldx fileLo,y
                stx zpDestLo
                sty loadRes                     ;Store filenumber (similar to LoadChunkFile)
                asl
                tay
                lda (zpDestLo),y                ;Get logical sprite header address
                sta zpSrcLo
                iny
                lda (zpDestLo),y
                sta zpSrcHi
DLS_SprFileLoaded:
                ldy #LOGSPR_FLAGS
                lda (zpSrcLo),y
                bpl DLS_Complex
DLS_Simple:     iny
                asl
                asl
                sta zpBitBuf
                bcs DLS_SimpleNoConnect
                lda (zpSrcLo),y
                adc yLo
                sta yLo                         ;Add connect-spot to Y coords
                iny
                clc
                bit sprFrameNum
                bpl DLS_SimpleConnectNotFlipped
                iny
                lda (zpSrcLo),y
                bcc DLS_SimpleConnectCommon
DLS_SimpleNoConnect:
                lda xLo
                bcs DLS_SimpleConnectDone
DLS_SimpleConnectNotFlipped:
                lda (zpSrcLo),y
                iny                             ;Skip over the flipped X connect spot
DLS_SimpleConnectCommon:
                adc xLo
                sta xLo                         ;Add connect-spot to X coords
                iny
DLS_SimpleConnectDone:
                asl zpBitBuf                    ;DO NOT CHANGE THIS, modified in code
                bcs DLS_SimpleNoBounds
                ldx numBounds                   ;NOTE: bounds are not tested for running out
                bit sprFrameNum
                bmi DLS_SimpleBoundsFlipped
DLS_SimpleBoundsNotFlipped:
                adc (zpSrcLo),y
                sta boundsR,x                   ;If sprite uses connect, bounds are relative to connectspot, otherwise not
                iny
                adc (zpSrcLo),y
                sta boundsL,x
                jmp DLS_SimpleBoundsCommon
DLS_SimpleBoundsFlipped:
                adc #$81
                sec
                sbc (zpSrcLo),y                 ;If flipped, subtract bounds offset position from connectspot instead
                sta boundsL,x
                iny
                sbc (zpSrcLo),y
                sta boundsR,x
DLS_SimpleBoundsCommon:
                iny
                lda yLo                         ;Y to half res
                lsr
                ora actYMSB
                clc
                adc (zpSrcLo),y
                sta boundsD,x
                iny
                adc (zpSrcLo),y
                sta boundsU,x
                iny
                lda actIndex
                sta boundsAct,x
                inc numBounds
DLS_SimpleNoBounds:
                ldx numSpr                      ;Out of sprites?
                cpx #MAX_SPR
                bcs DLS_SimpleDone
                lda (zpSrcLo),y                 ;Y hotspot
                adc yLo
                iny
                cmp #MIN_SPRY                   ;Sprite outside Y?
                bcc DLS_SimpleDone
DLS_MaxSprYCmp1:cmp #MAX_SPRY
                bcs DLS_SimpleDone
                sta sprY,x
                lda sprFrameNum                 ;Use flipped or non-flipped X hotspot
                bpl DLS_SimpleNotFlipped
                iny                             ;Jump over non-flipped X hotspot
DLS_SimpleFlipped:
                lda (zpSrcLo),y
                bcc DLS_SimpleCommon            ;C=0 here
DLS_SimpleNotFlipped:
                lda (zpSrcLo),y
                iny
DLS_SimpleCommon:
                adc xLo
                cmp #MAX_SPRX/2                 ;Simple sprites are not X-expanded, so this check is enough
                bcs DLS_SimpleDone
                sta sprX,x
                iny
                sty zpLenLo                     ;Offset of slicemask & data in sprite
                ldy #PHYSSPR_COLOR
                lda (zpSrcLo),y
                and actColorAnd
                ora actColorOr
                sta sprC,x                      ;Store color
                ldy #PHYSSPR_CACHEFRAME
                lda zpBitBuf                    ;Flipped-flag in simple mode
                eor sprFrameNum
                sta sprFrameNum
                bpl DLS_SimpleNotFlippedSpr
                iny
DLS_SimpleNotFlippedSpr:
                lda (zpSrcLo),y                 ;Sprite frame already in cache?
                bne DLS_SimpleIsCached
                jsr DepackSprite
DLS_SimpleIsCached:
                sta sprF,x
                tay
                lda cacheFrame                  ;Mark cached sprite in use
                sta cacheSprAge-FIRSTCACHEFRAME,y
                lda actIndex                    ;Sprite was accepted: store actor index
                sta sprAct,x                    ;for interpolation
                inc numSpr                      ;Increment sprite count
DLS_SimpleDone: rts

DLS_ComplexBounds:
                ldy #LOGSPR_DATA
                lda (zpSrcLo),y
                beq DLS_ComplexNoBounds
                sta complexSprCount             ;Number of bounding boxes
                ldx numBounds                   ;NOTE: bounds are not tested for running out
DLS_ComplexBoundsLoop:
                iny
                lda xLo
                clc
                bit sprFrameNum
                bmi DLS_ComplexBoundsFlipped
DLS_ComplexBoundsNotFlipped:
                adc (zpSrcLo),y
                sta boundsR,x                   ;Note: if sprite uses connect, bounds are relative to connectspot, otherwise not
                iny
                adc (zpSrcLo),y
                sta boundsL,x
                jmp DLS_ComplexBoundsCommon
DLS_ComplexBoundsFlipped:
                adc #$81
                sec
                sbc (zpSrcLo),y
                sta boundsL,x
                iny
                sbc (zpSrcLo),y
                sta boundsR,x
DLS_ComplexBoundsCommon:
                iny
                lda yLo                         ;Y to half res
                lsr
                ora actYMSB
                clc
                adc (zpSrcLo),y
                sta boundsD,x
                iny
                adc (zpSrcLo),y
                sta boundsU,x
                lda actIndex
                sta boundsAct,x
                inx
                dec complexSprCount
                bne DLS_ComplexBoundsLoop
                stx numBounds
DLS_ComplexNoBounds:
                iny
                lda (zpSrcLo),y
                beq DLS_ComplexDone             ;Can have zero physical sprites
                iny
                sta complexSprCount             ;Number of physical sprites
                lda sprFrameNum                 ;Extract the flip flag
                and #$80
                sta zpBitBuf
                lda zpSrcLo                     ;zpSrcLo used for physical sprites, so access logical sprite from zpBitsLo from here on
                sta zpBitsLo
                lda zpSrcHi
                sta zpBitsHi
DLS_ComplexPhysSprLoop:
                ldx numSpr                       ;Out of sprites?
                cpx #MAX_SPR
                bcs DLS_ComplexDone
                lda (zpBitsLo),y                 ;Y hotspot
                adc yLo
                iny
                cmp #MIN_SPRY                    ;Sprite outside Y?
                bcc DLS_ComplexOutsideY
DLS_MaxSprYCmp2:cmp #MAX_SPRY
                bcs DLS_ComplexOutsideY
                sta sprY,x
                lda zpBitBuf                     ;Use flipped or non-flipped X hotspot
                bpl DLS_ComplexNotFlipped
                iny                              ;Jump over non-flipped X hotspot
DLS_ComplexFlipped:
                lda (zpBitsLo),y
                bcc DLS_ComplexCommon           ;C=0 here
DLS_ComplexOutsideY:
                iny
                iny
                iny
                bne DLS_ComplexNext
DLS_ComplexDone:rts
DLS_ComplexNotFlipped:
                lda (zpBitsLo),y
                iny
DLS_ComplexCommon:
                adc xLo
                iny
                sta sprX,x
                lda (zpBitsLo),y                ;Take physical sprite num, combine logical & physical flip
                eor zpBitBuf
                sta sprFrameNum
                iny
                sty complexSprTemp              ;Store data ptr for next physical sprite
                asl
                tay
                lda (zpDestLo),y
                sta zpSrcLo
                iny
                lda (zpDestLo),y
                sta zpSrcHi
                ldy #PHYSSPR_COLOR
                lda (zpSrcLo),y
                and actColorAnd
                ora actColorOr
                sta sprC,x                      ;Store color
                and #COLOR_XEXPAND
                bne DLS_ComplexXExpand          ;Different outside check for expanded sprites
DLS_ComplexXExpandDone:
                lda sprX,x                      ;X outside check for unexpanded sprites
                cmp #MAX_SPRX/2
                bcs DLS_ComplexOutsideX
DLS_ComplexXExpandEdgeDone:
                iny
                sty zpLenLo                     ;Offset of slicemask & data in sprite
                ldy #PHYSSPR_CACHEFRAME
                lda sprFrameNum
                bpl DLS_ComplexNotFlippedSpr
                iny
DLS_ComplexNotFlippedSpr:
                lda (zpSrcLo),y                 ;Sprite frame already in cache?
                bne DLS_ComplexIsCached
                jsr DepackSprite
DLS_ComplexIsCached:
                sta sprF,x
                tay
                lda cacheFrame                  ;Mark cached sprite in use
                sta cacheSprAge-FIRSTCACHEFRAME,y
                lda actIndex                    ;Sprite was accepted: store actor index
                sta sprAct,x                    ;for interpolation
                inc numSpr                      ;Increment sprite count
DLS_ComplexOutsideX:
                ldy complexSprTemp
DLS_ComplexNext:dec complexSprCount
                bne DLS_ComplexPhysSprLoop
                rts

DLS_ComplexXExpand:
                lda sprX,x
                cmp #MAX_SPRX_EXPANDED/2
                bcc DLS_ComplexXExpandDone
                bcs DLS_ComplexXExpandEdgeDone

        ; Depack sprite to cache

DepackSprite:
DSpr_CachePos:  ldx #FIRSTCACHEFRAME+$3f        ;Continue from where we left off last time
DSpr_CacheSearchLoop:
                inx
                bpl DSpr_CacheSearchNotOver
                ldx #FIRSTCACHEFRAME
DSpr_CacheSearchNotOver:
                lda cacheSprAge-FIRSTCACHEFRAME,x
                cmp cacheFrame                  ;Skip if sprite in use now or on last frame (being shown)
                beq DSpr_CacheSearchLoop
DSpr_LastCacheFrame:
                cmp #$01
                beq DSpr_CacheSearchLoop
DSpr_Found:     stx DSpr_CachePos+1             ;Store cache position (the frame we're using now) for next search
                txa
                sta (zpSrcLo),y                 ;Store cache frame into sprite header
                ldy cacheSprFile-FIRSTCACHEFRAME,x ;Clear the old cache mapping if the old file still in memory
                bmi DSpr_NoOldSprite
                lda fileHi,y
                beq DSpr_NoOldSprite
                sta oldSprHi
                lda fileLo,y
                sta oldSprLo
                lda cacheSprFrame-FIRSTCACHEFRAME,x
                asl
                tay
                lda (oldSprLo),y
                sta oldSprHeaderLo
                iny
                lda (oldSprLo),y
                sta oldSprHeaderHi
                lda #$00
                tay
                bcc DSpr_ClearNonFlipped
                iny
DSpr_ClearNonFlipped:
DSpr_ClearSta:  sta (oldSprHeaderLo),y
DSpr_NoOldSprite:
                lda loadRes                       ;Save new file & frame numbers so that this mapping
                sta cacheSprFile-FIRSTCACHEFRAME,x ;can be cleared in the future
                tay
                lda #$00
                sta fileAge,y                   ;Reset file age. TODO: should also reset when already in cache

                dec $01                         ;Need access to RAM under the I/O area
                lda sprFrameNum
                sta cacheSprFrame-FIRSTCACHEFRAME,x
                bmi DSpr_DepackFlipped
                jmp DSpr_DepackNonFlipped

DSpr_DepackFlipped:
                lda #$08
                sta cacheAdr
                txa                             ;Calculate sprite address
                lsr
                ror cacheAdr
                lsr
                ror cacheAdr
                ora #>videoBank
                cmp DSpr_FlipFullSlice1+2       ;Modify STA-instructions as necessary
                beq DSpr_FlipAddressOk
                sta DSpr_FlipFullSlice1+2
                sta DSpr_FlipFullSlice2+2
                sta DSpr_FlipFullSlice3+2
                sta DSpr_FlipFullSlice4+2
                sta DSpr_FlipFullSlice5+2
                sta DSpr_FlipFullSlice6+2
                sta DSpr_FlipFullSlice7+2
                sta DSpr_FlipEmptySlice1+2
                sta DSpr_FlipEmptySlice2+2
                sta DSpr_FlipEmptySlice3+2
                sta DSpr_FlipEmptySlice4+2
                sta DSpr_FlipEmptySlice5+2
                sta DSpr_FlipEmptySlice6+2
                sta DSpr_FlipEmptySlice7+2
DSpr_FlipAddressOk:
                ldy zpLenLo
                lda (zpSrcLo),y                ;Get slice bitmask high bit
                asl
                iny
                lda (zpSrcLo),y                ;Get rest of the bits
                ror
                sta sliceMask                  ;C=1 if first slice has data
                ldx cacheAdr
                iny
                bcc DSpr_FlipEmptySlice
DSpr_FlipFullSlice:
                lda (zpSrcLo),y
                sta DSpr_GetFlipped1+1
DSpr_GetFlipped1:lda flipTbl
DSpr_FlipFullSlice1:sta $1000,x
                iny
                lda (zpSrcLo),y
                sta DSpr_GetFlipped2+1
DSpr_GetFlipped2:lda flipTbl
DSpr_FlipFullSlice2:sta $1000+3,x
                iny
                lda (zpSrcLo),y
                sta DSpr_GetFlipped3+1
DSpr_GetFlipped3:lda flipTbl
DSpr_FlipFullSlice3:sta $1000+6,x
                iny
                lda (zpSrcLo),y
                sta DSpr_GetFlipped4+1
DSpr_GetFlipped4:lda flipTbl
DSpr_FlipFullSlice4:sta $1000+9,x
                iny
                lda (zpSrcLo),y
                sta DSpr_GetFlipped5+1
DSpr_GetFlipped5:lda flipTbl
DSpr_FlipFullSlice5:sta $1000+12,x
                iny
                lda (zpSrcLo),y
                sta DSpr_GetFlipped6+1
DSpr_GetFlipped6:lda flipTbl
DSpr_FlipFullSlice6:sta $1000+15,x
                iny
                lda (zpSrcLo),y
                sta DSpr_GetFlipped7+1
DSpr_GetFlipped7:lda flipTbl
DSpr_FlipFullSlice7:sta $1000+18,x
                iny
DSpr_FlipNextSlice:
                lda flipNextSliceTbl,x
                beq DSpr_DepackDone
                tax
                dex
                lsr sliceMask
                bcs DSpr_FlipFullSlice
DSpr_FlipEmptySlice:lda #$00
DSpr_FlipEmptySlice1:sta $1000,x
DSpr_FlipEmptySlice2:sta $1000+3,x
DSpr_FlipEmptySlice3:sta $1000+6,x
DSpr_FlipEmptySlice4:sta $1000+9,x
DSpr_FlipEmptySlice5:sta $1000+12,x
DSpr_FlipEmptySlice6:sta $1000+15,x
DSpr_FlipEmptySlice7:sta $1000+18,x
                beq DSpr_FlipNextSlice

DSpr_DepackDone:inc $01                         ;Restore I/O registers
                ldx numSpr
                lda DSpr_CachePos+1
                rts

DSpr_DepackNonFlipped:
                lda #$00
                sta cacheAdr
                txa                             ;Calculate sprite address
                lsr
                ror cacheAdr
                lsr
                ror cacheAdr
                ora #>videoBank
                cmp DSpr_FullSlice1+2           ;Modify STA-instructions as necessary
                beq DSpr_AddressOk
                sta DSpr_FullSlice1+2
                sta DSpr_FullSlice2+2
                sta DSpr_FullSlice3+2
                sta DSpr_FullSlice4+2
                sta DSpr_FullSlice5+2
                sta DSpr_FullSlice6+2
                sta DSpr_FullSlice7+2
                sta DSpr_EmptySlice1+2
                sta DSpr_EmptySlice2+2
                sta DSpr_EmptySlice3+2
                sta DSpr_EmptySlice4+2
                sta DSpr_EmptySlice5+2
                sta DSpr_EmptySlice6+2
                sta DSpr_EmptySlice7+2
DSpr_AddressOk: ldy zpLenLo
                lda (zpSrcLo),y                ;Get slice bitmask high bit
                asl
                iny
                lda (zpSrcLo),y                ;Get rest of the bits
                ror
                sta sliceMask                  ;C=1 if first slice has data
                ldx cacheAdr
                iny
                bcc DSpr_EmptySlice
DSpr_FullSlice: lda (zpSrcLo),y
DSpr_FullSlice1:sta $1000,x
                iny
                lda (zpSrcLo),y
DSpr_FullSlice2:sta $1000+3,x
                iny
                lda (zpSrcLo),y
DSpr_FullSlice3:sta $1000+6,x
                iny
                lda (zpSrcLo),y
DSpr_FullSlice4:sta $1000+9,x
                iny
                lda (zpSrcLo),y
DSpr_FullSlice5:sta $1000+12,x
                iny
                lda (zpSrcLo),y
DSpr_FullSlice6:sta $1000+15,x
                iny
                lda (zpSrcLo),y
DSpr_FullSlice7:sta $1000+18,x
                iny
DSpr_NextSlice: lda nextSliceTbl,x
                beq DSpr_DepackDone2
                tax
                lsr sliceMask
                bcs DSpr_FullSlice
DSpr_EmptySlice:lda #$00
DSpr_EmptySlice1:sta $1000,x
DSpr_EmptySlice2:sta $1000+3,x
DSpr_EmptySlice3:sta $1000+6,x
DSpr_EmptySlice4:sta $1000+9,x
DSpr_EmptySlice5:sta $1000+12,x
DSpr_EmptySlice6:sta $1000+15,x
DSpr_EmptySlice7:sta $1000+18,x
                beq DSpr_NextSlice

DSpr_DepackDone2:
                inc $01
                ldx numSpr
                lda DSpr_CachePos+1
                rts
