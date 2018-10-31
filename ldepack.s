        ; Exomizer + loader stored as packed data

EXOMIZER_ERRORHANDLING = 1                      ;Error handling needed when loading from disk

                include kernal.s
                include memory.s

                org exomizerCodeStart

                include exomizer.s

OpenFile:       rts                             ;Initial OpenFile routine: do nothing
SaveFile        = OpenFile+3                    ;Initial SaveFile routine doesn't exist / isn't used
GetByte         = OpenFile+6

                jsr ChrIn
                clc
                rts

                org GetByte
                jmp OpenFile+1                  ;Initial GetByte routine: jump to implementation above

packedLoaderStart:
                incbin loader.pak               ;Packed loader data
                