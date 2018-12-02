SFX_NONE        = 0
SFX_GUN         = 1
SFX_PICKUP      = 2
SFX_EXPLOSION   = 3

        ; Sound effect table

sfxTblLo:       dc.b <sfxGun
                dc.b <sfxPickup
                dc.b <sfxExplosion

sfxTblHi:       dc.b >sfxGun
                dc.b >sfxPickup
                dc.b >sfxExplosion

sfxGun:         dc.b SFXINIT+SFXPULSE,$00,$c8,$08   ;ADSR $00c8, pulsewidth $80
                dc.b SFXWAVE+SFXFREQ,$81,$c0
                dc.b SFXWAVE+SFXFREQ,$41,$0c
                dc.b SFXFREQMOD,$ff                 ;Decrease freq high with 1 per frame
                dc.b SFXWAVE,$40
                dc.b SFXDELAY-$0a                   ;Delay for 10 frames (let freqmod run)
                dc.b SFXEND
                
sfxPickup:      dc.b SFXINIT+SFXPULSE,$00,$d6,$07   ;ADSR $00d6, pulsewidth $70
                dc.b SFXWAVE+SFXFREQ,$81,$d0
                dc.b SFXWAVE+SFXFREQ,$41,$0c
                dc.b SFXWAVE+SFXFREQ,$81,$c0
                dc.b SFXWAVE+SFXFREQ,$40,$16
                dc.b SFXDELAY-$01
                dc.b SFXFREQ,$1d
                dc.b SFXDELAY-$01
                dc.b SFXFREQ,$16
                dc.b SFXEND

sfxExplosion:   dc.b SFXINIT+SFXPULSE,$0b,$e9,$08            ;ADSR $0be9, pulsewidth $80
                dc.b SFXWAVE+SFXFREQ,$81,$50
                dc.b SFXWAVE+SFXFREQ,$41,$0c
                dc.b SFXFREQ,$09
                dc.b SFXFREQ,$06
                dc.b SFXFREQ,$03
                dc.b SFXWAVE+SFXFREQ+SFXFREQMOD,$81,$02,$01
                dc.b SFXDELAY-$03
                dc.b SFXFREQ,$01
                dc.b SFXDELAY-$02
                dc.b SFXWAVE+SFXFREQ,$80,$00
                dc.b SFXDELAY-$02
                dc.b SFXFREQ,$01
                dc.b SFXDELAY-$02
                dc.b SFXFREQ,$02
                dc.b SFXDELAY-$02
                dc.b SFXFREQ,$01
                dc.b SFXDELAY-$02
                dc.b SFXFREQ,$00
                dc.b SFXDELAY-$02
                dc.b SFXFREQ,$01
                dc.b SFXDELAY-$02
                dc.b SFXFREQ,$00
                dc.b SFXDELAY-$02
                dc.b SFXEND
