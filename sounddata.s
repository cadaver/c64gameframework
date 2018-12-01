SFX_NONE        = 0
SFX_GUN         = 1
SFX_PICKUP      = 2

        ; Sound effect table

sfxTblLo:       dc.b <sfxGun
                dc.b <sfxPickup

sfxTblHi:       dc.b >sfxGun
                dc.b >sfxPickup

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