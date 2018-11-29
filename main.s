                ; Rasterline debug

SHOW_PLAYROUTINE_TIME   = 0
SHOW_CHARSETANIM_TIME   = 0
SHOW_SPRITEIRQ_TIME     = 0
SHOW_SCROLLWORK_TIME    = 0
SHOW_SKIPPED_FRAME      = 0
SHOW_FREE_TIME          = 0
SHOW_DEBUG_VARS         = 0

                ; Filename and resource chunk defines

F_MUSIC         = $01
F_CHARSET       = $02
F_LEVEL         = $03
F_CHUNK         = $04-1

C_COMMON        = 1                             ;Common sprites
C_PLAYER        = 2                             ;Player sprites
C_SCRIPT0       = 3                             ;First script (loadable code) file, with player movement / render code

C_FIRSTPURGEABLE = C_PLAYER                     ;First chunk that can be removed from memory. Put e.g. always resident spritefiles to lower indices
C_FIRSTSCRIPT   = C_SCRIPT0                     ;Remember to update this, otherwise sprite etc. resources will be relocated as code!

                include memory.s
                include loadsym.s

                org loaderCodeEnd

EntryPoint:     ldx #$ff                        ;Init stack pointer to top
                txs
                jsr InitAll                     ;Call to disposable init code
                ldy #C_COMMON
                jsr LoadResourceFile            ;Preload the common sprites
                lda #1
                jsr PlaySong
                lda #0
                jsr ChangeLevel
                lda #0
                jsr ChangeZone

                ldx #ACTI_PLAYER                ;Create player actor. Player movement code is in script00.s
                lda #ACT_PLAYER                 ;to demonstrate runtime code loading / relocation
                sta actT,x
                lda #28
                sta actXH,x
                lda #$40
                sta actXL,x
                lda #15
                sta actYH,x
                jsr InitActor                   ;Init health & actor flags
                jsr CenterPlayer                ;Center scrolling on player & redraw

                lda #4                          ;Adjust text margin for the health display
                sta textLeftMargin

MainLoop:       jsr ScrollLogic
                jsr DrawActors
                jsr UpdateFrame
                jsr GetControls
                jsr ScrollLogic
                jsr UpdateActors
                jsr UpdateFrame
                jsr UpdateLevelObjects
                jsr RedrawHealth
                jmp MainLoop

RedrawHealth:   lda actHp+ACTI_PLAYER           ;Redraw health to left side of scorepanel if changed
                cmp displayedHealth
                beq RH_SameValue
                sta displayedHealth
                jsr ConvertToBCD8
                ldx #0
                lda zpDestHi
                jsr PrintBCDDigit
                lda zpDestLo
                jmp PrintBCDDigits
RH_SameValue:   rts

displayedHealth:dc.b $ff

randomAreaStart:
                include raster.s
                include sound.s
                include input.s
                include screen.s
                include sprite.s
                include math.s
                include file.s
                include panel.s
                include actor.s
                include physics.s
                include ai.s
                include level.s
randomAreaEnd:

                include playroutinedata.s
                include sounddata.s
                include actordata.s
                include miscdata.s
                include aligneddata.s
                
        ; Dynamic allocation area begin

fileAreaStart:
                include init.s