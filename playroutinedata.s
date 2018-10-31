freqTbl:        dc.w $022d,$024e,$0271,$0296,$02be,$02e8,$0314,$0343,$0374,$03a9,$03e1,$041c
                dc.w $045a,$049c,$04e2,$052d,$057c,$05cf,$0628,$0685,$06e8,$0752,$07c1,$0837
                dc.w $08b4,$0939,$09c5,$0a5a,$0af7,$0b9e,$0c4f,$0d0a,$0dd1,$0ea3,$0f82,$106e
                dc.w $1168,$1271,$138a,$14b3,$15ee,$173c,$189e,$1a15,$1ba2,$1d46,$1f04,$20dc
                dc.w $22d0,$24e2,$2714,$2967,$2bdd,$2e79,$313c,$3429,$3744,$3a8d,$3e08,$41b8
                dc.w $45a1,$49c5,$4e28,$52cd,$57ba,$5cf1,$6278,$6853,$6e87,$751a,$7c10,$8371
                dc.w $8b42,$9389,$9c4f,$a59b,$af74,$b9e2,$c4f0,$d0a6,$dd0e,$ea33,$f820,$ffff

fixupDestLoTbl: dc.b <Play_FiltNextTblM81Access
                dc.b <Play_FiltNextTblM1Access
                dc.b <Play_FiltSpdTblM81Access
                dc.b <Play_FiltSpdTblM1Access
                dc.b <Play_FiltLimitTblM81Access
                dc.b <Play_FiltLimitTblM1Access
                dc.b <Play_PulseNextTblM81Access
                dc.b <Play_PulseNextTblM1Access
                dc.b <Play_PulseSpdTblM1Access
                dc.b <Play_PulseLimitTblM81Access
                dc.b <Play_PulseLimitTblM1Access
                dc.b <Play_WaveNextTblM1Access4
                dc.b <Play_WaveNextTblM1Access3
                dc.b <Play_WaveNextTblM1Access2
                dc.b <Play_WaveNextTblM1Access1
                dc.b <Play_NoteTblM1Access3
                dc.b <Play_NoteTblM1Access2
                dc.b <Play_NoteTblM1Access1
                dc.b <Play_WaveTblM1Access
                dc.b <Play_InsFiltPosM1Access
                dc.b <Play_InsPulsePosM1Access
                dc.b <Play_InsWavePosM1Access
                dc.b <Play_InsFirstWaveM1Access
                dc.b <Play_InsSRM1Access
                dc.b <Play_InsADM1Access
                dc.b <Play_PattTblHiM1Access
                dc.b <Play_PattTblLoM1Access
                dc.b <Play_SongTblAccess3
                dc.b <Play_SongTblAccess2
                dc.b <Play_SongTblAccess1

fixupDestHiTbl: dc.b >Play_FiltNextTblM81Access
                dc.b >Play_FiltNextTblM1Access
                dc.b >Play_FiltSpdTblM81Access
                dc.b >Play_FiltSpdTblM1Access
                dc.b >Play_FiltLimitTblM81Access
                dc.b >Play_FiltLimitTblM1Access
                dc.b >Play_PulseNextTblM81Access
                dc.b >Play_PulseNextTblM1Access
                dc.b >Play_PulseSpdTblM1Access
                dc.b >Play_PulseLimitTblM81Access
                dc.b >Play_PulseLimitTblM1Access
                dc.b >Play_WaveNextTblM1Access4
                dc.b >Play_WaveNextTblM1Access3
                dc.b >Play_WaveNextTblM1Access2
                dc.b >Play_WaveNextTblM1Access1
                dc.b >Play_NoteTblM1Access3
                dc.b >Play_NoteTblM1Access2
                dc.b >Play_NoteTblM1Access1
                dc.b >Play_WaveTblM1Access
                dc.b >Play_InsFiltPosM1Access
                dc.b >Play_InsPulsePosM1Access
                dc.b >Play_InsWavePosM1Access
                dc.b >Play_InsFirstWaveM1Access
                dc.b >Play_InsSRM1Access
                dc.b >Play_InsADM1Access
                dc.b >Play_PattTblHiM1Access
                dc.b >Play_PattTblLoM1Access
                dc.b >Play_SongTblAccess3
                dc.b >Play_SongTblAccess2
                dc.b >Play_SongTblAccess1

fixupTypeTbl:   dc.b FIXUP_NOSIZE+FIXUP_MINUS81
                dc.b FIXUP_FILTSIZE+FIXUP_MINUS1
                dc.b FIXUP_NOSIZE+FIXUP_MINUS81
                dc.b FIXUP_FILTSIZE+FIXUP_MINUS1
                dc.b FIXUP_NOSIZE+FIXUP_MINUS81
                dc.b FIXUP_PULSESIZE+FIXUP_MINUS1
                dc.b FIXUP_NOSIZE+FIXUP_MINUS81
                dc.b FIXUP_PULSESIZE+FIXUP_MINUS1
                dc.b FIXUP_PULSESIZE+FIXUP_MINUS1
                dc.b FIXUP_NOSIZE+FIXUP_MINUS81
                dc.b FIXUP_WAVESIZE+FIXUP_MINUS1
                dc.b FIXUP_NOSIZE+FIXUP_MINUS1
                dc.b FIXUP_NOSIZE+FIXUP_MINUS1
                dc.b FIXUP_NOSIZE+FIXUP_MINUS1
                dc.b FIXUP_WAVESIZE+FIXUP_MINUS1
                dc.b FIXUP_NOSIZE+FIXUP_MINUS1
                dc.b FIXUP_NOSIZE+FIXUP_MINUS1
                dc.b FIXUP_WAVESIZE+FIXUP_MINUS1
                dc.b FIXUP_INSSIZE+FIXUP_MINUS1
                dc.b FIXUP_INSSIZE+FIXUP_MINUS1
                dc.b FIXUP_INSSIZE+FIXUP_MINUS1
                dc.b FIXUP_INSSIZE+FIXUP_MINUS1
                dc.b FIXUP_INSSIZE+FIXUP_MINUS1
                dc.b FIXUP_INSSIZE+FIXUP_MINUS1
                dc.b FIXUP_PATTSIZE+FIXUP_MINUS1
                dc.b FIXUP_PATTSIZE+FIXUP_MINUS1
                dc.b FIXUP_SONGSIZE+FIXUP_MINUS1
                dc.b FIXUP_NOSIZE
                dc.b FIXUP_NOSIZE
                dc.b FIXUP_NOSIZE

        ; In settable music data mode, include dummy music data labels so that the player
        ; will not complain when assembled

musicHeader:
songTbl:
pattTblLo:
pattTblHi:
insAD:
insSR:
insFirstWave:
insWavePos:
insPulsePos:
insFiltPos:
waveTbl:
noteTbl:
waveNextTbl:
pulseLimitTbl:
pulseSpdTbl:
pulseNextTbl:
filtLimitTbl:
filtSpdTbl:
filtNextTbl: