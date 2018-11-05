ACT_NONE        = 0
ACT_PLAYER      = 1
ACT_ITEM        = 2

actDataTblLo:   dc.b <actPlayer

actDataTblHi:   dc.b >actPlayer

actBottomAdjustTbl:
                dc.b -2

actPlayer:      dc.b GRP_HEROES|AF_NOREMOVECHECK    ;Flags
                dc.b 100                            ;Initial health
                dc.w $0000+USESCRIPT                ;Update routine, script entrypoint or address in inbuilt engine code (< $8000)
                dc.w $0001+USESCRIPT                ;Draw routine, script entrypoint or address in inbuilt engine code (< $8000)
                dc.b 7                              ;Gravity acceleration
                dc.b $40                            ;Side collision offset
                dc.b -2                             ;Top collision offset
