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
C_ENEMY         = 3                             ;Enemy sprites
C_SCRIPT0       = 4                             ;First script (loadable code) file, with player + enemy movement / render code

C_FIRSTPURGEABLE = C_PLAYER                     ;First chunk that can be removed from memory. Put e.g. always resident spritefiles
                                                ;to lower indices
C_FIRSTSCRIPT   = C_SCRIPT0                     ;Remember to update this, otherwise sprite etc. resources will be relocated as code!

                include memory.s
                include loadsym.s
                include ldepacksym.s

                org loaderCodeEnd

EntryPoint:     ldx #$ff                        ;Init stack pointer to top
                txs
                jsr InitAll                     ;Call to disposable init code

                lda #5                          ;Adjust text margin for the health display
                sta textLeftMargin

                lda #1
                jsr PlaySong                    ;Play music. Note: some music (even a silence tune)
                                                ;needs to be initialized to get sound effect playback
                                                ;Also, loading music trashes the zone scrolling buffer,
                                                ;so must load music before changing the zone / beginning gameplay

                lda #0                          ;Setup level / zone we're in
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
                lda #$00
                sta actD,x
                jsr InitActor                   ;Init health & actor flags
                jsr CenterPlayer                ;Center scrolling on player & redraw
                jsr SavePlayerState             ;Make an "in-memory checkpoint" for restarting
                jsr UpdateFrame                 ;Show screen just to demonstrate loading while screen is on
                jsr RedrawHUD

                ldy #C_COMMON
                jsr LoadResource                ;Preload the common sprites

MainLoop:       jsr ScrollLogic
                jsr DrawActors
                jsr UpdateFrame
                jsr GetControls
                jsr ScrollLogic
                jsr UpdateActors
                jsr UpdateFrame
                jsr UpdateLevelObjects
                jsr RedrawHUD
                jsr CheckRestart
                jmp MainLoop

RedrawHUD:      lda actHp+ACTI_PLAYER           ;Redraw health to left side of scorepanel if changed
                cmp displayedHealth
                beq RH_SameHealth
                sta displayedHealth
                jsr ConvertToBCD8
                ldx #0
                lda #94                         ;Health symbol
                jsr PrintPanelChar
                jsr Print3BCDDigits             ;Health value
RH_SameHealth:  lda ammo                        ;Redraw ammo to right side of scorepanel if changed
                cmp displayedAmmo
                beq RH_SameAmmo
                sta displayedAmmo
                jsr ConvertToBCD8
                ldx #34
                lda #95                         ;Ammo symbol
                jsr PrintPanelChar
                jsr Print3BCDDigits             ;Ammo value
RH_SameAmmo:    rts

CheckRestart:   lda actT+ACTI_PLAYER            ;Check if player actor vanished (destroyed)
                bne CR_NoRestart
                sta scrollSX                    ;Stop scrolling
                sta scrollSY
                dec restartDelay                ;Two second delay (50 mainloops or 100 frames)
                bne CR_NoRestart
                lda #50
                sta restartDelay
                jsr RestoreCheckpoint           ;Restore player & world state from last entered area & start again
                lda actHp+ACTI_PLAYER
                cmp #50                         ;Ensure at least half health after restart
                bcs CR_HealthOK
                lda #50
                sta actHp+ACTI_PLAYER
CR_HealthOK:
CR_NoRestart:   rts

Print3BCDDigits:lda zpDestHi
                jsr PrintBCDDigit
                lda zpDestLo
                jmp PrintBCDDigits

displayedHealth:dc.b $ff
displayedAmmo:  dc.b $ff
restartDelay:   dc.b 50

randomAreaStart:

                include raster.s                ;Include rest of the engine code
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

                include playroutinedata.s       ;Include datas
                include sounddata.s
                include actordata.s
                include miscdata.s
                include aligneddata.s

        ; Dynamic allocation area begin

fileAreaStart:
                include init.s                  ;Disposable init code