ACT_NONE        = 0
ACT_ITEM        = 1

xCoordTbl:
N               set -8
                repeat MAX_ACTX
                dc.b <N
N               set N+8
                repend

yCoordTbl:
N               set 0
                repeat MAX_ACTY
                dc.b <N
N               set N+16
                repend

actDataTblLo:

actDataTblHi:

actBottomAdjustTbl:
