                processor 6502

                mac varbase
NEXT_VAR        set {1}
                endm

                mac var
{1}             = NEXT_VAR
NEXT_VAR        set NEXT_VAR + 1
                endm

                mac varrange
{1}             = NEXT_VAR
NEXT_VAR        set NEXT_VAR + {2}
                endm

                mac checkvarbase
                if NEXT_VAR > {1}
                    err
                endif
                endm

                mac definescript
NEXT_EP         set {1}*$100
                endm
                
                mac defineep
EP_{1}          = NEXT_EP
NEXT_EP         set NEXT_EP + 1
                endm

        ; Text jump. Game texts need to be located between $0000-$7fff to use

                mac textjump
                dc.b >{1} | $80
                dc.b <{1}
                endm
                
        ; BIT instruction for skipping the next 1- or 2-byte instruction

                mac skip1
                dc.b $24
                endm

                mac skip2
                dc.b $2c
                endm

        ; Encode 4 instruction lengths into one byte
        
                mac instrlen
                dc.b {1} | ({2} * 4) | ({3} * 16) | ({4} * 64)
                endm

        ; Screen redraw macros

                mac drawbottomedge
                subroutine dbe
                ldy $1000,x
                lda blkColors,y
                bne .1
                lda (dsBottomPtrLo),y
                sta colors+{1},x
                bcc .3
.1:             sta colors+{1},x
.2:             lda (dsBottomPtrLo),y
.3:             sta screen+{1},x
                subroutine dbeend
                endm

                mac drawbottom
                subroutine db
                ldy $1000,x
                lda blkColors,y
                bmi .1
                bne .2
                lda blkBL,y
                sta colors+{1},x
                sta screen+{1},x
                lda blkBR,y
                sta colors+{1}+1,x
                bcc .3
.1:             sta colors+{1},x
                sta colors+{1}+1,x
.2:             lda blkBL,y
                sta screen+{1},x
                lda blkBR,y
.3:             sta screen+{1}+1,x
                subroutine dbend
                endm

                mac drawtopedge
                subroutine dte
                ldy $1000,x
                lda blkColors,y
                bne .1
                lda (dsTopPtrLo),y
                sta colors+{1},x
                bcc .3
.1:             sta colors+{1},x
.2:             lda (dsTopPtrLo),y
.3:             sta screen+{1},x
                subroutine dteend
                endm

                mac drawtop
                subroutine dt
                ldy $1000,x
                lda blkColors,y
                bmi .1
                bne .2
                lda blkTL,y
                sta colors+{1},x
                sta screen+{1},x
                lda blkTR,y
                sta colors+{1}+1,x
                bcc .3
.1:             sta colors+{1},x
                sta colors+{1}+1,x
.2:             lda blkTL,y
                sta screen+{1},x
                lda blkTR,y
.3:             sta screen+{1}+1,x
                subroutine dtend
                endm

                mac drawedge
                subroutine de
                ldy $1000,x
                lda blkColors,y
                bmi .1
                bne .2
                lda (dsTopPtrLo),y
                sta colors+{1},x
                sta screen+{1},x
                lda (dsBottomPtrLo),y
                sta colors+{1}+40,x
                bcc .3
.1:             sta colors+{1},x
                sta colors+{1}+40,x
.2:             lda (dsTopPtrLo),y
                sta screen+{1},x
                lda (dsBottomPtrLo),y
.3:             sta screen+{1}+40,x
                subroutine deend
                endm

                mac drawfullblock
                subroutine dfb
                ldy $1000,x
                lda blkColors,y
                bmi .1
                bne .2
                lda blkTL,y
                sta colors+{1},x
                sta screen+{1},x
                lda blkTR,y
                sta colors+{1}+1,x
                sta screen+{1}+1,x
                lda blkBL,y
                sta colors+{1}+40,x
                sta screen+{1}+40,x
                lda blkBR,y
                sta colors+{1}+41,x
                bcc .3
.1:             sta colors+{1},x
                sta colors+{1}+1,x
                sta colors+{1}+40,x
                sta colors+{1}+41,x
.2:             lda blkTL,y
                sta screen+{1},x
                lda blkTR,y
                sta screen+{1}+1,x
                lda blkBL,y
                sta screen+{1}+40,x
                lda blkBR,y
.3:             sta screen+{1}+41,x
                subroutine dfbend
                endm

                mac drawfullblockexit
                subroutine dfbe
                ldy $1000,x
                lda blkColors,y
                bmi .1
                bne .2
                lda blkTL,y
                sta colors+{1},x
                sta screen+{1},x
                lda blkTR,y
                sta colors+{1}+1,x
                sta screen+{1}+1,x
                lda blkBL,y
                sta colors+{1}+40,x
                sta screen+{1}+40,x
                lda blkBR,y
                sta colors+{1}+41,x
                sta screen+{1}+41,x
                bcc {2}
.1:             sta colors+{1},x
                sta colors+{1}+1,x
                sta colors+{1}+40,x
                sta colors+{1}+41,x
.2:             lda blkTL,y
                sta screen+{1},x
                lda blkTR,y
                sta screen+{1}+1,x
                lda blkBL,y
                sta screen+{1}+40,x
                lda blkBR,y
                sta screen+{1}+41,x
                bcc {2}
                subroutine dfbeend
                endm

                mac loadrow
                txa
                adc mapTblLo+{3},y
                sta {1}+1
                sta {2}+1
                lda zpSrcHi
                adc mapTblHi+{3},y
                sta {1}+2
                sta {2}+2
                endm
                
                mac adjustedge
                subroutine ae
                inc {1}+1
                bne .1
                inc {1}+2
.1:
                subroutine aeend
                endm
