                processor 6502

                include memory.s
                include mainsym.s

                org lvlObjX
                incbin bg/world00.lvo
                org lvlActX
                incbin bg/world00.lva
