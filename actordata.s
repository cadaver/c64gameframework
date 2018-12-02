ACT_NONE        = 0
ACT_PLAYER      = 1
ACT_ITEM        = 2
ACT_BULLET      = 3
ACT_SMOKECLOUD  = 4
ACT_EXPLOSION   = 5
ACT_ENEMY       = 6

actDataTblLo:   dc.b <actPlayer
                dc.b <actItem
                dc.b <actBullet
                dc.b <actSmokeCloud
                dc.b <actExplosion
                dc.b <actEnemy

actDataTblHi:   dc.b >actPlayer
                dc.b >actItem
                dc.b >actBullet
                dc.b >actSmokeCloud
                dc.b >actExplosion
                dc.b >actEnemy

actBottomAdjustTbl:
                dc.b -2
                dc.b -1
                dc.b -1
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
                dc.b NO_MODIFY                      ;Received damage mod
                dc.w $0002+USESCRIPT                ;Damage response routine, script entrypoint or address in inbuilt engine code (< $8000)

actItem:        dc.b 0                              ;Flags
                dc.b 0                              ;Health (= default pickup)
                dc.w $0003+USESCRIPT                ;Update routine
                dc.w $0004+USESCRIPT                ;Draw routine
                dc.b 7                              ;Gravity
                dc.b $10                            ;Side collision offset
                dc.b 0                              ;Top collision offset

actBullet:      dc.b 0                              ;Flags
                dc.b 5                              ;Initial health (damage for bullets)
                dc.w $0005+USESCRIPT                ;Update routine
                dc.w $0006+USESCRIPT                ;Draw routine

actSmokeCloud:  dc.b 0                              ;Flags
                dc.b 0                              ;Initial health
                dc.w $0007+USESCRIPT                ;Update routine
                dc.w $0008+USESCRIPT                ;Draw routine

actExplosion:   dc.b 0                              ;Flags
                dc.b 0                              ;Initial health
                dc.w $0009+USESCRIPT                ;Update routine
                dc.w $000a+USESCRIPT                ;Draw routine

actEnemy:       dc.b GRP_ENEMIES|AF_NOREMOVECHECK   ;Flags
                dc.b 15                             ;Initial health
                dc.w $000b+USESCRIPT                ;Update routine, script entrypoint or address in inbuilt engine code (< $8000)
                dc.w $000c+USESCRIPT                ;Draw routine, script entrypoint or address in inbuilt engine code (< $8000)
                dc.b 5                              ;Gravity acceleration (reduced compared to player)
                dc.b $60                            ;Side collision offset
                dc.b -1                             ;Top collision offset
                dc.b NO_MODIFY                      ;Received damage mod
                dc.w $000d+USESCRIPT                ;Damage response routine