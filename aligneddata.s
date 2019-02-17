alignedDataStart:

                org (* + $ff) & $ff00

        ; Sprite cache / depacking tables

        ; Next slice lowbyte table for sprite depacking. Interleaved with data to not waste memory,
        ; each empty space is 15 bytes.

nextSliceTbl:   dc.b 1,2,21
flipNextSliceTbl:dc.b 24,1,2

sprIrqAdvanceTbl:
                dc.b -2,-3,-4,-5,-7,-8,-10,-11

dsStartTbl:     dc.b 1,2
                dc.b 41,42

dsEndTbl:       dc.b 37,77

                org nextSliceTbl+21
                dc.b 22,23,42
                dc.b 45,22,23

nextChnTbl:     dc.b 7
upperHalfJumpTblLo:
                dc.b <DSRow0,<DSTopRow
upperHalfJumpTblHi:
                dc.b >DSRow0,>DSTopRow
lowerHalfJumpTblLo:
                dc.b <DSBottomRow, <DSRow6

                dc.b 14
lowerHalfJumpTblHi:
                dc.b >DSBottomRow, >DSRow6
dsEdgeTbl:      dc.b 38,0
                dc.b 78,40

                dc.b 0
                
                org nextSliceTbl+42
                dc.b 43,44,0
                dc.b 0,43,44

sprIrqJumpTblLo:dc.b <Irq2_Spr0,<Irq2_Spr1,<Irq2_Spr2,<Irq2_Spr3,<Irq2_Spr4,<Irq2_Spr5,<Irq2_Spr6,<Irq2_Spr7
sprIrqJumpTblHi:dc.b >Irq2_Spr0,>Irq2_Spr1,>Irq2_Spr2,>Irq2_Spr3,>Irq2_Spr4,>Irq2_Spr5,>Irq2_Spr6,>Irq2_Spr7

                org nextSliceTbl+$40
                dc.b $40+1,$40+2,$40+21
                dc.b $40+24,$40+1,$40+2

lvlObjCenterLoTbl:
                dc.b $40,$00,$40,$00
lvlObjCenterHiTbl:
                dc.b 0,1,1,2

stairXLTbl:     dc.b $00,$40
stairCtrlTbl:   dc.b JOY_LEFT,JOY_RIGHT

                org nextSliceTbl+$40+21
                dc.b $40+22,$40+23,$40+42
                dc.b $40+45,$40+22,$40+23

bitTbl:         dc.b $01,$02,$04,$08,$10,$20,$40,$80
fixupSubTbl:    dc.b $00,$01,$81

                org nextSliceTbl+$40+42
                dc.b $40+43,$40+44,0
                dc.b 0,$40+43,$40+44

irq4DelayTbl:   dc.b 8,8,8,8,8,5,0,8
reverseBitTbl:  dc.b $ff-$01,$ff-$02,$ff-$04,$ff-$08,$ff-$10,$ff-$20,$ff-$40,$ff-$80

                org nextSliceTbl+$80
                dc.b $80+1,$80+2,$80+21
                dc.b $80+24,$80+1,$80+2

                org nextSliceTbl+$80+21
                dc.b $80+22,$80+23,$80+42
                dc.b $80+45,$80+22,$80+23

                org nextSliceTbl+$80+42
                dc.b $80+43,$80+44,0
                dc.b 0,$80+43,$80+44

                org irq4DelayTbl+$47
                dc.b 5 ;Delay value for blanked screen (Y-scroll $57)

                org nextSliceTbl+$c0
                dc.b $c0+1,$c0+2,$c0+21
                dc.b $c0+24,$c0+1,$c0+2

d015Tbl:        dc.b $00,$80,$c0,$e0,$f0,$f8,$fc,$fe,$ff

                org nextSliceTbl+$c0+21
                dc.b $c0+22,$c0+23,$c0+42
                dc.b $c0+45,$c0+22,$c0+23

                org nextSliceTbl+$c0+42
                dc.b $c0+43,$c0+44,0
                dc.b 0,$c0+43,$c0+44

                org nextSliceTbl+$100

        ; Sprite flipping table

flipTbl:        dc.b %00000000,%01000000,%10000000,%11000000,%00010000,%01010000,%10010000,%11010000,%00100000,%01100000,%10100000,%11100000,%00110000,%01110000,%10110000,%11110000
                dc.b %00000100,%01000100,%10000100,%11000100,%00010100,%01010100,%10010100,%11010100,%00100100,%01100100,%10100100,%11100100,%00110100,%01110100,%10110100,%11110100
                dc.b %00001000,%01001000,%10001000,%11001000,%00011000,%01011000,%10011000,%11011000,%00101000,%01101000,%10101000,%11101000,%00111000,%01111000,%10111000,%11111000
                dc.b %00001100,%01001100,%10001100,%11001100,%00011100,%01011100,%10011100,%11011100,%00101100,%01101100,%10101100,%11101100,%00111100,%01111100,%10111100,%11111100
                dc.b %00000001,%01000001,%10000001,%11000001,%00010001,%01010001,%10010001,%11010001,%00100001,%01100001,%10100001,%11100001,%00110001,%01110001,%10110001,%11110001
                dc.b %00000101,%01000101,%10000101,%11000101,%00010101,%01010101,%10010101,%11010101,%00100101,%01100101,%10100101,%11100101,%00110101,%01110101,%10110101,%11110101
                dc.b %00001001,%01001001,%10001001,%11001001,%00011001,%01011001,%10011001,%11011001,%00101001,%01101001,%10101001,%11101001,%00111001,%01111001,%10111001,%11111001
                dc.b %00001101,%01001101,%10001101,%11001101,%00011101,%01011101,%10011101,%11011101,%00101101,%01101101,%10101101,%11101101,%00111101,%01111101,%10111101,%11111101
                dc.b %00000010,%01000010,%10000010,%11000010,%00010010,%01010010,%10010010,%11010010,%00100010,%01100010,%10100010,%11100010,%00110010,%01110010,%10110010,%11110010
                dc.b %00000110,%01000110,%10000110,%11000110,%00010110,%01010110,%10010110,%11010110,%00100110,%01100110,%10100110,%11100110,%00110110,%01110110,%10110110,%11110110
                dc.b %00001010,%01001010,%10001010,%11001010,%00011010,%01011010,%10011010,%11011010,%00101010,%01101010,%10101010,%11101010,%00111010,%01111010,%10111010,%11111010
                dc.b %00001110,%01001110,%10001110,%11001110,%00011110,%01011110,%10011110,%11011110,%00101110,%01101110,%10101110,%11101110,%00111110,%01111110,%10111110,%11111110
                dc.b %00000011,%01000011,%10000011,%11000011,%00010011,%01010011,%10010011,%11010011,%00100011,%01100011,%10100011,%11100011,%00110011,%01110011,%10110011,%11110011
                dc.b %00000111,%01000111,%10000111,%11000111,%00010111,%01010111,%10010111,%11010111,%00100111,%01100111,%10100111,%11100111,%00110111,%01110111,%10110111,%11110111
                dc.b %00001011,%01001011,%10001011,%11001011,%00011011,%01011011,%10011011,%11011011,%00101011,%01101011,%10101011,%11101011,%00111011,%01111011,%10111011,%11111011
                dc.b %00001111,%01001111,%10001111,%11001111,%00011111,%01011111,%10011111,%11011111,%00101111,%01101111,%10101111,%11101111,%00111111,%01111111,%10111111,%11111111

        ; Slope table

slopeTbl:       dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
                dc.b $78,$70,$68,$60,$58,$50,$48,$40,$38,$30,$28,$20,$18,$10,$08,$00
                dc.b $38,$38,$30,$30,$28,$28,$20,$20,$18,$18,$10,$10,$08,$08,$00,$00
                dc.b $78,$78,$70,$70,$68,$68,$60,$60,$58,$58,$50,$50,$48,$48,$40,$40
                dc.b $40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40
                dc.b $00,$08,$10,$18,$20,$28,$30,$38,$40,$48,$50,$58,$60,$68,$70,$78
                dc.b $00,$00,$08,$08,$10,$10,$18,$18,$20,$20,$28,$28,$30,$30,$38,$38
                dc.b $40,$40,$48,$48,$50,$50,$58,$58,$60,$60,$68,$68,$70,$70,$78,$78

        ; Instruction length table for relocation, 4 instructions packed into one byte
        ; Instructions x4-x7 and xc-xf have always same length, so they are omitted

instrLenTbl:    instrlen 1,2,1,2
                instrlen 1,2,1,2
                instrlen 2,2,1,2 ;1
                instrlen 1,3,1,3
                instrlen 3,2,1,2 ;2
                instrlen 1,2,1,2
                instrlen 2,2,1,2 ;3
                instrlen 1,3,1,3
                instrlen 1,2,1,2 ;4
                instrlen 1,2,1,2
                instrlen 2,2,1,2 ;5
                instrlen 1,3,1,3
                instrlen 1,2,1,2 ;6
                instrlen 1,2,1,2
                instrlen 2,2,1,2 ;7
                instrlen 1,3,1,3
                instrlen 2,2,2,2 ;8
                instrlen 1,2,1,2
                instrlen 2,2,1,3 ;9
                instrlen 1,3,1,3
                instrlen 2,2,2,2 ;a
                instrlen 1,2,1,2
                instrlen 2,2,1,2 ;b
                instrlen 1,3,1,3
                instrlen 2,2,2,2 ;c
                instrlen 1,2,1,2
                instrlen 2,2,1,2 ;d
                instrlen 1,3,1,3
                instrlen 2,2,2,2 ;e
                instrlen 1,2,1,2
                instrlen 2,2,1,2 ;f
                instrlen 1,3,1,3

        ; Sorted sprites (cannot be under Kernal ROM)

sortSprX:       ds.b MAX_SPR*2,0
sortSprY:       ds.b MAX_SPR*2,0
sortSprF:       ds.b MAX_SPR*2,0
sortSprC:       ds.b MAX_SPR*2,0
sortSprXMSB:    ds.b MAX_SPR*2,0
sortSprXExpand: ds.b MAX_SPR*2,0
sprIrqLine:     ds.b MAX_SPR*2,0

xCoordTbl:
N               set -8
                repeat MAX_ACTX
                dc.b <N
N               set N+8
                repend

yCoordTbl:
N               set 0
                repeat MAX_ACTY
                dc.b <N
N               set N+16
                repend

        ; Must be before save to know save size

                include bg/worldinfo.s
                include bg/worlddata.s

        ; Playroutine

playRoutineVars:

                org playRoutineVars+60

        ; Misc. vars

zoneLvlObjList: ds.b MAX_ZONEOBJ+1,0

                if (zoneLvlObjList & $ff00) != (actT & $ff00)
                    err                         ;Levelobject list must not pagecross
                endif

        ; Actors

actT:           ds.b MAX_ACT,0
actFlags:       ds.b MAX_ACT,0
actHp:          ds.b MAX_ACT,0
actD:           ds.b MAX_ACT,0
actFd:          ds.b MAX_ACT,0
actTime:        ds.b MAX_ACT,0
actXL:          ds.b MAX_ACT,0
actYL:          ds.b MAX_ACT,0
actPrevXL:      ds.b MAX_ACT,0
actPrevXH:      ds.b MAX_ACT,0
actPrevYL:      ds.b MAX_ACT,0
actPrevYH:      ds.b MAX_ACT,0
actMB:          ds.b MAX_ACT,0
actBounds:      ds.b MAX_ACT,0
actDmgFlags:    ds.b MAX_ACT,0
actBlockInfo:   ds.b MAX_ACT,0
actOrg:         ds.b MAX_ACT,0
actLvlDataOrg:  ds.b MAX_ACT,0
actAttackD:     ds.b MAX_COMPLEXACT,0
actCtrl:        ds.b MAX_COMPLEXACT,0
actMoveCtrl:    ds.b MAX_COMPLEXACT,0
actPrevCtrl:    ds.b MAX_COMPLEXACT,0
actWpn:         ds.b MAX_COMPLEXACT,0
actNavArea:     ds.b MAX_COMPLEXACT,0
actState:       ds.b MAX_COMPLEXACT,0
actTarget:      ds.b MAX_COMPLEXACT,0
actTargetFlags: ds.b MAX_COMPLEXACT,0
actTargetNavArea:
                ds.b MAX_COMPLEXACT,0
actDestNavArea: ds.b MAX_COMPLEXACT,0
actHeight:      ds.b MAX_COMPLEXACT,0
actAimHeight:   ds.b MAX_COMPLEXACT,0

        ; Player current state

playerStateStart:
ammo:           dc.b 0

playerStateEnd:

        ; Config

musicMode:      dc.b 1
soundMode:      dc.b 1
twoButtonJoystick:dc.b 0

                if SHOW_DEBUG_VARS > 0
debugVars:      ds.b 4,0
                endif

        ; Savestate

saveStateStart:
savePlayerState:ds.b playerStateEnd-playerStateStart,0
saveMiscVars:   ds.b NUM_SAVEMISCVARS,0

saveActT        = saveMiscVars+0
saveActXH       = saveMiscVars+1
saveActYH       = saveMiscVars+2
saveActD        = saveMiscVars+3
saveActHp       = saveMiscVars+4
saveLevelNum    = saveMiscVars+5
saveZoneNum     = saveMiscVars+6

saveLvlActX:    ds.b MAX_SAVEACT,0
saveLvlActY:    ds.b MAX_SAVEACT,0
saveLvlActZ:    ds.b MAX_SAVEACT,0
saveLvlActT:    ds.b MAX_SAVEACT+1,0            ;One extra for endmark
saveLvlActWpn:  ds.b MAX_SAVEACT,0
saveLvlActOrg:  ds.b MAX_SAVEACT,0
saveBits:       ds.b LEVELACTBITSIZE,$ff        ;All actors initially exist
                ds.b LEVELOBJBITSIZE,0          ;All objects initially inactive

saveStateEnd:
