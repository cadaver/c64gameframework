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

                lda #ACT_PLAYER                 ;Create player actor & redraw screen
                sta actT+ACTI_PLAYER
                lda #9
                sta actXH+ACTI_PLAYER
                lda #$40
                sta actXL+ACTI_PLAYER
                lda #9
                sta actYH+ACTI_PLAYER
                jsr CenterPlayer

                lda #<txtWelcome
                ldx #>txtWelcome
                jsr PrintPanelTextIndefinite

MainLoop:       jsr ScrollLogic
                jsr DrawActors
                jsr UpdateFrame
                jsr GetControls
                jsr ScrollLogic
                jsr UpdateActors
                jsr UpdateFrame
                jsr UpdateLevelObjects
                jmp MainLoop

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

txtWelcome:     dc.b "C64GAMEFRAMEWORK EXAMPLE",0

                include playroutinedata.s
                include sounddata.s
                include actordata.s
                include miscdata.s
                include aligneddata.s
                
        ; Dynamic allocation area begin

fileAreaStart:
                include init.s