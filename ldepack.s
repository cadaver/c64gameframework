        ; Loader depacker

EXOMIZER_ERRORHANDLING = 1                      ;Error handling needed when loading from disk

                include kernal.s
                include memory.s

                org exomizerCodeStart

                include exomizer.s

OpenFile:       rts
SaveFile        = OpenFile+3
GetByte         = OpenFile+6

                jsr ChrIn
                clc
                rts

                org GetByte
                jmp OpenFile+1

                incbin loaderstack.bin

packedLoaderStart:
                incbin loader.pak