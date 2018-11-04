                include macros.s
                include memory.s
                include mainsym.s

                org $0000

        ; Note! Code must be unambiguous! Relocated code cannot have skip1/skip2 -macros!

                dc.w scriptEnd-scriptStart  ;Chunk data size
                dc.b 2                      ;Number of objects

scriptStart:
                rorg scriptCodeRelocStart   ;Initial relocation address when loaded

                dc.w MovePlayer             ;$0000
                dc.w DrawPlayer             ;$0001

MovePlayer:     rts

DrawPlayer:     lda #18
                ldy #C_PLAYER
                jsr DrawLogicalSprite
                lda #0
                ldy #C_PLAYER
                jmp DrawLogicalSprite

                brk                             ;End relocation

                rend

scriptEnd: