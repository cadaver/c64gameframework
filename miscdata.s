saveMiscVarLo:  dc.b <actT
                dc.b <actXH
                dc.b <actYH
                dc.b <actD
                dc.b <actHp
                dc.b <levelNum
                dc.b <zoneNum

saveMiscVarHi:  dc.b >actT
                dc.b >actXH
                dc.b >actYH
                dc.b >actD
                dc.b >actHp
                dc.b >levelNum
                dc.b >zoneNum

NUM_SAVEMISCVARS = saveMiscVarHi - saveMiscVarLo
