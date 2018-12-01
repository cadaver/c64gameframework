ACT_NONE        = 0
ACT_PLAYER      = 1
ACT_ITEM        = 2
ACT_BULLET      = 3
ACT_SMOKECLOUD  = 4

actDataTblLo:   dc.b <actPlayer
                dc.b <actItem
                dc.b <actBullet
                dc.b <actSmokeCloud

actDataTblHi:   dc.b >actPlayer
                dc.b >actItem
                dc.b >actBullet
                dc.b >actSmokeCloud

actBottomAdjustTbl:
                dc.b -2
                dc.b -1
                dc.b -1
                dc.b -1

actPlayer:      dc.b GRP_HEROES|AF_NOREMOVECHECK    ;Flags
                dc.b 100                            ;Initial health
                dc.w $0000+USESCRIPT                ;Update routine, script entrypoint or address in inbuilt engine code (< $8000)
                dc.w $0001+USESCRIPT                ;Draw routine, script entrypoint or address in inbuilt engine code (< $8000)
                dc.b 7                              ;Gravity acceleration
                dc.b $40                            ;Side collision offset
                dc.b -2                             ;Top collision offset

actItem:        dc.b 0                              ;Flags
                dc.b 0                              ;Health (= default pickup)
                dc.w $0002+USESCRIPT                ;Update routine, script entrypoint or address in inbuilt engine code (< $8000)
                dc.w $0003+USESCRIPT                ;Draw routine, script entrypoint or address in inbuilt engine code (< $8000)
                dc.b 7                              ;Gravity
                dc.b $10                            ;Side collision offset
                dc.b 0                              ;Top collision offset

actBullet:      dc.b 0                              ;Flags
                dc.b 1                              ;Initial health (damage for bullets)
                dc.w $0004+USESCRIPT                ;Update routine, script entrypoint or address in inbuilt engine code (< $8000)
                dc.w $0005+USESCRIPT                ;Draw routine, script entrypoint or address in inbuilt engine code (< $8000)

actSmokeCloud:  dc.b 0                              ;Flags
                dc.b 0                              ;Initial health
                dc.w $0006+USESCRIPT                ;Update routine, script entrypoint or address in inbuilt engine code (< $8000)
                dc.w $0007+USESCRIPT                ;Draw routine, script entrypoint or address in inbuilt engine code (< $8000)