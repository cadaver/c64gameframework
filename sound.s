MODULE_MASK         = $fc
SUBTUNE_MASK        = $03

MUSIC_SILENCE       = $00

MUSICHEADERSIZE = 6

FIXUP_SONGSIZE  = 0
FIXUP_PATTSIZE  = 4
FIXUP_INSSIZE   = 8
FIXUP_WAVESIZE  = 12
FIXUP_PULSESIZE = 16
FIXUP_FILTSIZE  = 20
FIXUP_NOSIZE    = $80

FIXUP_ZERO      = 0
FIXUP_MINUS1    = 1
FIXUP_MINUS81   = 2

NUMFIXUPS       = 30

TRANS           = $80
SONGJUMP        = 0

ENDPATT         = 0
INS             = -1
DUR             = $101
WAVEPTR         = $7c
KEYOFF          = $7e
REST            = $7f

SFXEND          = $00
SFXINIT         = $01
SFXPULSE        = $02
SFXWAVE         = $04
SFXFREQ         = $08
SFXFREQMOD      = $10
SFXDELAY        = $100

FADESPEED       = $30

chnWave         = playRoutineVars+0
chnWavePos      = playRoutineVars+1
chnPulsePos     = playRoutineVars+2
chnPattPos      = playRoutineVars+3
chnNote         = playRoutineVars+4
chnCounter      = playRoutineVars+5
chnDuration     = playRoutineVars+6

chnIns          = playRoutineVars+21
chnTrans        = playRoutineVars+22
chnSongPos      = playRoutineVars+23
chnWaveTime     = playRoutineVars+24
chnPulse        = playRoutineVars+25
chnFreqLo       = playRoutineVars+26
chnFreqHi       = playRoutineVars+27

chnSfxNum       = playRoutineVars+42
chnSfxPos       = playRoutineVars+43
chnSfxTime      = playRoutineVars+44
chnSfxFreqMod   = playRoutineVars+45

        ; Request playback of sound effect, to be played only when music is off (e.g. footsteps)
        ;
        ; Parameters: A sound effect number
        ; Returns: -
        ; Modifies: A

QueueSfxNoMusic:sta QSNM_SoundNum+1
                lda nextChnTbl              ;If nextChnTbl points to just first channel, music is being played
                beq QSfx_Done
QSNM_SoundNum:  lda #$00

        ; Request playback of sound effect. Will actually be played during next update IRQ
        ;
        ; Parameters: A sound effect number
        ; Returns: -
        ; Modifies: A

QueueSfx:       cmp Irq5_SfxNum+1               ;Since only one sound can be started per frame, check priority
                bcc QSfx_Done
QSfx_Store:     sta Irq5_SfxNum+1
QSfx_Done:      rts

        ; Fade out current song. Note: sounds will not play before a new song (at least silence tune)
        ; is initialized
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A

FadeSongIfDifferent:
                cmp RestartSong+1
                beq FS_Skip
FadeSong:       lda nextChnTbl                  ;When silence subtune is active, do not fade,
                bne FS_Silence                  ;as it causes SID master volume noises
                sta PS_CurrentSong+1            ;Current song must be reset in case the same song will be played again
                lda #FADESPEED
                sta Play_FadeSpd+1
FS_Skip:
FS_Silence:     rts

        ; Restart last played song
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,loader/file temp vars

RestartSong:    lda #$00

        ; Play a song. Load if necessary. Does not reinit if already playing
        ;
        ; Parameters: A song number, $00-$03 in first music module, $04-$07 in second etc.
        ; Returns: -
        ; Modifies: A,X,Y,loader/file temp vars

PlaySong:       sta RestartSong+1
                ldx musicMode                   ;If music off, always select silence tune
                bne PS_MusicOn
                and #MODULE_MASK                ;Silence tune is the first in each module
PS_MusicOn:
PS_CurrentSong: cmp #$ff
                beq PS_Done
                sta PS_CurrentSong+1
                jsr PrepareSong
                lda PS_CurrentSong+1
                and #SUBTUNE_MASK
                tax
                beq PS_SilenceSubTune           ;Manipulate the "next soundFX channel" table according to
                lda #$00                        ;whether playing silence or an actual tune
                tay
                beq PS_StoreNextChn
PS_SilenceSubTune:
                lda #7
                ldy #14
PS_StoreNextChn:sta Irq5_ChnStart+1             ;When switching to an actual tune, make sure the first sound played
                sta nextChnTbl                  ;isn't on channel 2 or 3
                sty nextChnTbl+7
                inx
                stx PlayRoutine+1
PrS_Done:
PS_Done:        rts

        ; Prepare song by loading its module, but do not start playback yet
        ;
        ; Parameters: A song number
        ; Returns: -
        ; Modifies: A,X,Y,loader/file temp vars

PrepareSong:    lsr                             ;Get music module number
                lsr
PrS_LoadedMusic:cmp #$ff                        ;Check if module already loaded
                beq PrS_Done
                sta PrS_LoadedMusic+1
                ldx #F_MUSIC
                jsr MakeFileName
                lda Play_FadeSpd+1
                beq PrS_NoFadeWait
                lda $d01a                       ;Wait for fade to complete if we're already fading
                lsr                             ;IRQs must be on so that we don't hang
                bcc PrS_NoFadeWait
PrS_FadeWait:   lda masterVol
                bne PrS_FadeWait
PrS_NoFadeWait: lda #$ff
                sta PlayRoutine+1               ;Silence during loading
                bne PrS_Retry
PrS_Error:      jsr RetryPrompt
PrS_Retry:      jsr OpenFile                    ;Music files are raw Exomizer2 output,
                jsr GetByte                     ;meaning they start with startaddress hi/lo
                bcs PrS_Error
PrS_NoError:    sta musicDataHi                 ;Reset zonebuffer ptr. now
                sta zoneBufferHi
                jsr GetByte
                sta musicDataLo
                sta zoneBufferLo
                jsr PurgeUntilFreeNoNew         ;Purge files if necessary to fit the music
                lda musicDataLo
                ldx musicDataHi
                jsr LoadFile
                bcs PrS_Error                   ;Fall through to SetMusicData if no error

        ; Set music data address. C must be 0

SetMusicData:   lda musicDataLo
                adc #MUSICHEADERSIZE
                sta trackPtrLo
                lda musicDataHi
                adc #$00
                sta trackPtrHi
                ldx #NUMFIXUPS-1
SetMusicData_FixupLoop:
                lda fixupDestLoTbl,x
                sta pattPtrLo
                lda fixupDestHiTbl,x
                sta pattPtrHi
                lda fixupTypeTbl,x
                pha
                bmi SetMusicData_AddDone
                lsr
                lsr
                tay
                lda (musicDataLo),y
                clc
                adc trackPtrLo
                sta trackPtrLo
                bcc SetMusicData_AddDone
                inc trackPtrHi
SetMusicData_AddDone:
                pla
                and #$03
                tay
                lda trackPtrLo
                sec
                sbc fixupSubTbl,y
                ldy #$01
                sta (pattPtrLo),y
                iny
                lda trackPtrHi
                sbc #$00
                sta (pattPtrLo),y
                dex
                bpl SetMusicData_FixupLoop
                rts

        ; Silence SID by zeroing mastervolume

SilenceSID:     lda #$00
                sta $d418
                rts

        ; Playroutine entrypoint.
        ;
        ; Write subtune number+1 to PlayRoutine+1 to initialize

PlayRoutine:    ldx #$ff
                bmi SilenceSID
                beq Play_FadeSpd
Play_DoInit:    dex
                txa
                sta pattPtrLo
                asl
                asl
                adc pattPtrLo
                tay
Play_SongTblAccess1:
                lda songTbl,y
                sta trackPtrLo
                iny
Play_SongTblAccess2:
                lda songTbl,y
                sta trackPtrHi
                iny
                ldx #21
                lda #$00
Play_ClearVars: sta chnWave-1,x
                dex
                bne Play_ClearVars
                stx Play_FadeSpd+1
                stx Play_FiltPos+1
                stx Play_FiltType+1
                stx $d417
                stx PlayRoutine+1
                jsr Play_ChnInit
                ldx #$07
                jsr Play_ChnInit
                ldx #$0f
                stx masterVol
                dex
Play_ChnInit:
Play_SongTblAccess3:
                lda songTbl,y
                sta chnSongPos,x
                iny
                dec chnDuration,x
                lda chnSfxNum,x                 ;If a sound effect is not playing, reset wave + SR to ensure starting from zero volume
                bne Play_ChnInitSkip
                sta $d404,x
                sta $d406,x
Play_ChnInitSkip:
                rts

Play_FiltInit:
Play_FiltSpdTblM81Access:
                lda filtSpdTbl-$81,y
                sta $d417
                and #$70
                sta Play_FiltType+1
Play_FiltNextTblM81Access:
                lda filtNextTbl-$81,y
                sta Play_FiltPos+1
Play_FiltLimitTblM81Access:
                lda filtLimitTbl-$81,y
                jmp Play_StoreCutoff
Play_FiltNext:
Play_FiltNextTblM1Access:
                lda filtNextTbl-1,y
                sta Play_FiltPos+1
                jmp Play_FiltDone

Play_FadeSpd:   lda #$00
                beq Play_FiltPos
Play_FadeDelay: adc #$00
                sta Play_FadeDelay+1
                bcc Play_FiltPos
                dec masterVol
                bpl Play_FiltPos
                stx masterVol
Play_FiltPos:   ldy #$00
                beq Play_FiltDone
                bmi Play_FiltInit
Play_FiltCutoff:lda #$00
Play_FiltLimitTblM1Access:
                cmp filtLimitTbl-1,y
                beq Play_FiltNext
                clc
Play_FiltSpdTblM1Access:
                adc filtSpdTbl-1,y
Play_StoreCutoff:
                sta Play_FiltCutoff+1
Play_ModifyCutoff8580:
                sbc #$16
                sta pattPtrLo
                lsr
                lsr
                cmp #$10
                bcc Play_CutoffOK
                ora #$c0
                adc pattPtrLo
Play_CutoffOK:  sta $d416
Play_FiltDone:
Play_FiltType:  lda #$00
Play_MasterVol: ora masterVol
                sta $d418
                jsr Play_ChnExec
                ldx #$07
                jsr Play_ChnExec
                ldx #$0e
                jmp Play_ChnExec

Play_NoNewIns:  clc
                adc chnTrans,x
                ora #$80
                sta chnNote,x
                lda chnIns,x
                bpl Play_HardRestart
                bmi Play_Rest
Play_Commands:  sbc #KEYOFF
                bcc Play_WavePtr
                ora chnSfxNum,x
                beq Play_Keyoff
                bne Play_Rest
Play_WavePtr:   iny
                lda (pattPtrLo),y
                jsr Play_SetWavePos
                beq Play_Rest                   ;Returns with A=0

Play_ChnExec:   inc chnCounter,x
                bmi Play_PulseExec
                bne Play_Reload
                ldy chnSongPos,x
Play_NewNotes:  lda (trackPtrLo),y
                tay
Play_PattTblLoM1Access:
                lda pattTblLo-1,y
                sta pattPtrLo
Play_PattTblHiM1Access:
                lda pattTblHi-1,y
                sta pattPtrHi
                ldy chnPattPos,x
                lda (pattPtrLo),y
                cmp #WAVEPTR
                bcs Play_Commands
                lsr
                bcs Play_NoNewIns
                adc chnTrans,x
                ora #$80
                sta chnNote,x
                iny
                lda (pattPtrLo),y
                sta chnIns,x
                bmi Play_Rest                   ;Instruments $81-$ff are $01-$7f as legato
Play_HardRestart:
                lda chnSfxNum,x
                bne Play_Rest
                lda #$0f
                sta $d406,x
Play_Keyoff:    lda chnWave,x
                and #$fe
                sta $d404,x
Play_Rest:      iny
                lda (pattPtrLo),y
                beq Play_PattEnd
                bpl Play_NoPattEnd
                sta chnDuration,x
                iny
                lda (pattPtrLo),y
                bne Play_NoPattEnd
Play_PattEnd:   inc chnSongPos,x
                dc.b $24                        ;Skip next instruction
Play_NoPattEnd: tya
                sta chnPattPos,x
                ldy chnSfxNum,x
                bne Play_JumpToSfx
                rts

Play_Reload:    lda chnDuration,x
                sta chnCounter,x
                lda chnPattPos,x
                beq Play_Sequencer
Play_NoSequencer:
                lda chnNote,x
                bpl Play_PulseExec
                jmp Play_NewNoteInit

Play_JumpToSfx: jmp Play_SfxExec

Play_PulseExec: ldy chnSfxNum,x
                bne Play_JumpToSfx
                ldy chnPulsePos,x
                beq Play_WaveExec
                bmi Play_PulseInit
                lda chnPulse,x
Play_PulseLimitTblM1Access:
                cmp pulseLimitTbl-1,y
                beq Play_PulseNext
                clc
Play_PulseSpdTblM1Access:
                adc pulseSpdTbl-1,y
                adc #$00
Play_StorePulse:
                sta chnPulse,x
                sta $d402,x
                sta $d403,x

Play_WaveExec:  ldy chnWavePos,x
                beq Play_WaveDone
Play_WaveTblM1Access:
                lda waveTbl-1,y
                beq Play_Vibrato
                cmp #$90
                bcs Play_SlideOrDelay
Play_SetWave:   sta chnWave,x
                sta $d404,x
Play_NoWaveChange:
Play_WaveNextTblM1Access1:
                lda waveNextTbl-1,y
                sta chnWavePos,x
Play_NoteTblM1Access1:
                lda noteTbl-1,y
                bmi Play_AbsNote
                adc chnNote,x
Play_AbsNote:   asl
                tay
                lda freqTbl-2,y
                sta chnFreqLo,x
                sta $d400,x
                lda freqTbl-1,y
Play_StoreFreqHi:
                sta chnFreqHi,x
                sta $d401,x
Play_WaveDone:  rts
Play_WaveDelayNotOver:
                inc chnWaveTime,x
                rts

Play_Sequencer: ldy chnSongPos,x
                lda (trackPtrLo),y
                bmi Play_SongTrans
                bne Play_SequencerDone
Play_SongJump:  iny
                lda (trackPtrLo),y
                tay
                lda (trackPtrLo),y
                bpl Play_NoSongJumpTrans
Play_SongTrans: sta chnTrans,x
                iny
Play_NoSongJumpTrans:
                tya
                sta chnSongPos,x
Play_SequencerDone:
                ldy chnSfxNum,x
                bne Play_JumpToSfx
                lda chnNote,x
                bpl Play_WaveExec
                bmi Play_NewNoteInit

Play_PulseInit: 
Play_PulseNextTblM81Access:
                lda pulseNextTbl-$81,y
                sta chnPulsePos,x
Play_PulseLimitTblM81Access:
                lda pulseLimitTbl-$81,y
                jmp Play_StorePulse
Play_PulseNext:
Play_PulseNextTblM1Access:
                lda pulseNextTbl-1,y
                sta chnPulsePos,x
                jmp Play_WaveExec

Play_SlideOrDelay:
                beq Play_Slide
Play_WaveDelay: adc chnWaveTime,x
                bne Play_WaveDelayNotOver
                clc
                sta chnWaveTime,x
                bcc Play_NoWaveChange

Play_Vibrato:   lda chnWaveTime,x
                bpl Play_VibNoDir
Play_NoteTblM1Access2:
                cmp noteTbl-1,y
                bcs Play_VibNoDir2
                eor #$ff
Play_VibNoDir:  sec
Play_VibNoDir2: sbc #$02
                sta chnWaveTime,x
                lsr
                lda chnFreqLo,x
                bcs Play_VibDown
Play_VibUp:
Play_WaveNextTblM1Access2:
                adc waveNextTbl-1,y
                sta chnFreqLo,x
                sta $d400,x
                bcc Play_VibDone
                lda chnFreqHi,x
                adc #$00
                jmp Play_StoreFreqHi
Play_VibDown:
Play_WaveNextTblM1Access3:
                sbc waveNextTbl-1,y
                sta chnFreqLo,x
                sta $d400,x
                bcs Play_VibDone
                lda chnFreqHi,x
                sbc #$00
                jmp Play_StoreFreqHi

Play_LegatoNoteInit:
                tya
                and #$7f
                tay
                bpl Play_FinishLegatoInit

Play_Slide:     lda chnFreqLo,x
Play_NoteTblM1Access3:
                adc noteTbl-1,y                 ;Note: speed must be stored as speed-1 due to C=1 here
                sta chnFreqLo,x
                sta $d400,x
Play_WaveNextTblM1Access4:
                lda waveNextTbl-1,y
Play_SfxFreqMod:adc chnFreqHi,x
                jmp Play_StoreFreqHi

Play_NewNoteInit:
                and #$7f
                sta chnNote,x                   ;Reset newnote-flag
                ldy chnIns,x
                bmi Play_LegatoNoteInit
Play_HRNoteInit:
Play_InsADM1Access:
                lda insAD-1,y                   ;Instruments are 1-indexed just so that the converter can
                sta $d405,x                     ;differentiate between "no instrument change" and the first
Play_InsSRM1Access:                             ;instrument. Strictly speaking they wouldn't need to be
                lda insSR-1,y
                sta $d406,x
Play_InsFirstWaveM1Access:
                lda insFirstWave-1,y
                sta $d404,x
Play_FinishLegatoInit:
Play_InsPulsePosM1Access:
                lda insPulsePos-1,y
                beq Play_SkipPulseInit
                sta chnPulsePos,x
Play_SkipPulseInit:
Play_InsFiltPosM1Access:
                lda insFiltPos-1,y
                beq Play_SkipFiltInit
                sta Play_FiltPos+1
Play_SkipFiltInit:
Play_InsWavePosM1Access:
                lda insWavePos-1,y
Play_SetWavePos:sta chnWavePos,x
                lda #$00
                sta chnWaveTime,x
Play_SlideDelay:
Play_VibDone:   rts

        ; Sound effect support code

Play_SfxDelay:  sec
                adc chnSfxTime,x
                bne Play_SfxDelayOngoing
Play_SfxDelayDone:
                sta chnSfxTime,x
                inc chnSfxPos,x                 ;Delay ended, run still effects only this frame
                bne Play_SfxEffects
Play_SfxDelayOngoing:
                inc chnSfxTime,x
Play_SfxEffects:lda chnSfxFreqMod,x
                clc
                bne Play_SfxFreqMod
                rts
Play_SfxEnd:    sta chnSfxNum,x
                sta chnWavePos,x                ;Also reset wavepos when returning from sound FX to music
Play_SfxDone:   rts

Play_SfxHR:     lda #$0f
                sta $d406,x
                lda chnWave,x
                and #$fe
                sta $d404,x
                lda #$00
                sta chnSfxFreqMod,x
                sta chnSfxTime,x
                inc chnSfxPos,x
                rts

Play_SfxExec:   lda sfxTblLo-1,y
                sta pattPtrLo
                lda sfxTblHi-1,y
                sta pattPtrHi
                lda chnNote,x                   ;Prevent newnoteinit triggering during sound FX
                bpl Play_SfxNoNewNote
                and #$7f
                sta chnNote,x
Play_SfxNoNewNote:
                ldy chnSfxPos,x
                beq Play_SfxHR
                dey
                lda (pattPtrLo),y
                bmi Play_SfxDelay
                beq Play_SfxEnd

Play_SfxCommand:sta sfxTemp
                iny
                lsr sfxTemp
                bcc Play_NoSfxFirstFrame
                lda (pattPtrLo),y
                sta $d405,x
                iny
                lda (pattPtrLo),y
                sta $d406,x
                iny
                lda #$09
                sta $d404,x

Play_NoSfxFirstFrame:
                lsr sfxTemp
                bcc Play_NoSfxPulse
                lda (pattPtrLo),y
                sta $d402,x
                sta $d403,x
                iny

Play_NoSfxPulse:
                lsr sfxTemp
                bcc Play_NoSfxWave
                lda (pattPtrLo),y
                sta chnWave,x
                sta $d404,x
                iny

Play_NoSfxWave: lsr sfxTemp
                bcc Play_NoSfxFreq
                lda (pattPtrLo),y
                sta chnFreqHi,x
                sta $d400,x
                sta $d401,x
                iny

Play_NoSfxFreq: lsr sfxTemp
                bcc Play_NoSfxFreqMod
                lda (pattPtrLo),y
                sta chnSfxFreqMod,x
                iny

Play_NoSfxFreqMod:
                iny
                tya
                sta chnSfxPos,x
                jmp Play_SfxEffects
