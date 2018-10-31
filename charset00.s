                processor 6502

                include memory.s
                include mainsym.s

                org blkTL
                incbin bg/world00.blk

                org chars
                incbin bg/world00.chr

                org blkInfo
                incbin bg/world00.bli

                org blkColors
                incbin bg/world00.blc

                org charAnimCode
                rts

                org lvlObjAnimFrames
                incbin bg/world00.oba

