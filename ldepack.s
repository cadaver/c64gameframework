        ; Exomizer + loader stored as packed data

                include memory.s
                include kernal.s

                org exomizerCodeStart

                include exomizer.s

exomizerCodeEnd:

OpenFile        = exomizerCodeEnd
SaveFile        = exomizerCodeEnd+3
GetByte         = exomizerCodeEnd+6

                php
                jsr ChrIn
                plp
                rts
                jmp OpenFile

ldepackCodeEnd:
                incbin loader.pak

