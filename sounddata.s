SFX_NONE        = 0
SFX_GUN         = 1

        ; Sound effect table

sfxTblLo:       dc.b <sfxGun

sfxTblHi:       dc.b >sfxGun

sfxGun:         dc.b SFXINIT+SFXPULSE,$00,$c8,$08   ;ADSR $00c8, pulsewidth $80
                dc.b SFXWAVE+SFXFREQ,$81,$c0
                dc.b SFXWAVE+SFXFREQ,$41,$0c
                dc.b SFXFREQMOD,$ff                 ;Decrease freq high with 1 per frame
                dc.b SFXWAVE,$40
                dc.b SFXDELAY-$0a                   ;Delay for 10 frames (let freqmod run)
                dc.b SFXEND