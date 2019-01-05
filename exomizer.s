tablBi          = depackBuffer
tablLo          = depackBuffer + 52
tablHi          = depackBuffer + 104

FORWARD_DECRUNCHING = 1
LITERAL_SEQUENCES_NOT_USED = 1
MAX_SEQUENCE_LENGTH_256 = 1

; -------------------------------------------------------------------
; This source code is altered and is not the original version found on
; the Exomizer homepage.
; -------------------------------------------------------------------
;
; Copyright (c) 2002 - 2018 Magnus Lind.
;
; This software is provided 'as-is', without any express or implied warranty.
; In no event will the authors be held liable for any damages arising from
; the use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
;
;   1. The origin of this software must not be misrepresented; you must not
;   claim that you wrote the original software. If you use this software in a
;   product, an acknowledgment in the product documentation would be
;   appreciated but is not required.
;
;   2. Altered source versions must be plainly marked as such, and must not
;   be misrepresented as being the original software.
;
;   3. This notice may not be removed or altered from any distribution.
;
;   4. The names of this software and/or it's copyright holders may not be
;   used to endorse or promote products derived from this software without
;   specific prior written permission.
;
; -------------------------------------------------------------------
; no code below this comment has to be modified in order to generate
; a working decruncher of this source file.
; However, you may want to relocate the tables last in the file to a
; more suitable address.
; -------------------------------------------------------------------

get_bits:
        adc #$80                ; needs c=0, affects v
        asl
        bpl gb_skip
gb_next:
        asl zpBitBuf
        bne gb_ok
        pha
        php
        jsr GetByte
        plp
        rol
        sta zpBitBuf
        pla
gb_ok:
        rol
        bmi gb_next
gb_skip:
        bvs gb_get_hi
        rts
gb_get_hi:
        sta zpBitsHi
        jsr GetByte
        sec
DepackError:
        rts

        ; Load file packed with Exomizer 2 forward mode
        ;
        ; Parameters: A,X load address, fileNumber
        ; Returns: C=0 if loaded OK, or C=1 and error code in A (see GetByte)
        ; Modifies: A,X,Y

LoadFile:       sta zpDestLo
                stx zpDestHi
                jsr OpenFile
Depack:

; -------------------------------------------------------------------
; jsr this label to decrunch, it will in turn init the tables and
; call the decruncher
; no constraints on register content, however the
; decimal flag has to be #0 (it almost always is, otherwise do a cld)
; init zeropage, x and y regs. (12 bytes)
;
        jsr GetByte
        bcs DepackError
        sta zpBitBuf
        ldy #0
; -------------------------------------------------------------------
; calculate tables (62 bytes) + get_bits macro
; x and y must be #0 when entering
;
        clc
table_gen:
        tax
        tya
        and #$0f
        sta tablLo,y
        beq shortcut            ; start a new sequence
; -------------------------------------------------------------------
        txa
        adc tablLo - 1,y
        sta tablLo,y
        lda zpLenHi
        adc tablHi - 1,y
shortcut:
        sta tablHi,y
; -------------------------------------------------------------------
        lda #$01
        sta zpLenHi
        lda #$78                ; %01111000
        jsr get_bits
; -------------------------------------------------------------------
        lsr
        tax
        beq rolled
        php
rolle:
        asl zpLenHi
        sec
        ror
        dex
        bne rolle
        plp
rolled:
        ror
        sta tablBi,y
        bmi no_fixup_lohi
        lda zpLenHi
        stx zpLenHi
        dc.b $24
no_fixup_lohi:
        txa
; -------------------------------------------------------------------
        iny
        cpy #52
        bne table_gen
; -------------------------------------------------------------------
; prepare for main decruncher
        ldy zpDestLo
        stx zpDestLo
        stx zpBitsHi
; -------------------------------------------------------------------
; copy one literal byte to destination (11 bytes)
;
literal_start1:
    if FORWARD_DECRUNCHING = 0
        tya
        bne no_hi_decr
        dec zpDestHi
no_hi_decr:
        dey
    endif
        jsr GetByte
        sta (zpDestLo),y
    if FORWARD_DECRUNCHING > 0
        iny
        bne no_hi_incr
        inc zpDestHi
no_hi_incr:
    endif
; -------------------------------------------------------------------
; fetch sequence length index (15 bytes)
; x must be #0 when entering and contains the length index + 1
; when exiting or 0 for literal byte
next_round:
        dex
        lda zpBitBuf
no_literal1:
        asl
        bne nofetch8
        php
        jsr GetByte
        plp
        rol
nofetch8:
        inx
        bcc no_literal1
        sta zpBitBuf
; -------------------------------------------------------------------
; check for literal byte (2 bytes)
;
        beq literal_start1
; -------------------------------------------------------------------
; check for decrunch done and literal sequences (4 bytes)
;
        cpx #$11
        bcs exit_or_lit_seq

; -------------------------------------------------------------------
; calulate length of sequence (zp_len) (18(11) bytes) + get_bits macro
;
        lda.wx tablBi - 1,x
        jsr get_bits
        adc tablLo - 1,x       ; we have now calculated zpLenLo
        sta zpLenLo
    if MAX_SEQUENCE_LENGTH_256 = 0
        lda zpBitsHi
        adc tablHi - 1,x       ; c = 0 after this.
        sta zpLenHi
; -------------------------------------------------------------------
; here we decide what offset table to use (27(26) bytes) + get_bits_nc macro
; z-flag reflects zpLenHi here
;
        ldx zpLenLo
    else
        tax
    endif
        lda #$e1
        cpx #$03
        bcs gbnc2_next
        lda tablBit,x
gbnc2_next:
        asl zpBitBuf
        bne gbnc2_ok
        tax
        php
        jsr GetByte
        plp
        rol
        sta zpBitBuf
        txa
gbnc2_ok:
        rol
        bcs gbnc2_next
        tax
; -------------------------------------------------------------------
; calulate absolute offset (zp_src) (21 bytes) + get_bits macro
;
    if MAX_SEQUENCE_LENGTH_256 = 0
        lda #0
        sta zpBitsHi
    endif
    if FORWARD_DECRUNCHING = 0
        lda tablBi,x
        jsr get_bits
        adc tablLo,x
        sta zpSrcLo
        lda zpBitsHi
        adc tablHi,x
        adc zpDestHi
        sta zpSrcHi
    else
        lda tablBi,x
        jsr get_bits
        adc tablLo,x
        bcc skipcarry
        inc zpBitsHi
        clc
skipcarry:
        eor #$ff
        adc #$01
        sta zpSrcLo
        lda zpDestHi
        sbc zpBitsHi
        sbc tablHi,x
        sta zpSrcHi
    if LITERAL_SEQUENCES_NOT_USED = 0
        clc
    endif
    endif


; -------------------------------------------------------------------
; prepare for copy loop (2 bytes)
;
pre_copy:
        ldx zpLenLo
; -------------------------------------------------------------------
; main copy loop (30 bytes)
;
copy_next:
    if FORWARD_DECRUNCHING = 0
        tya
        bne copy_skip_hi
        dec zpDestHi
        dec zpSrcHi
copy_skip_hi:
        dey
    endif
    if LITERAL_SEQUENCES_NOT_USED = 0
        bcs get_literal_byte
    endif
        lda (zpSrcLo),y
literal_byte_gotten:
        sta (zpDestLo),y
    if FORWARD_DECRUNCHING > 0
        iny
        bne copy_skip_hi
        inc zpDestHi
        inc zpSrcHi
copy_skip_hi:
    endif
        dex
        bne copy_next
    if MAX_SEQUENCE_LENGTH_256 = 0
        lda zpLenHi
    endif
begin_stx:
        stx zpBitsHi
        beq next_round
    if MAX_SEQUENCE_LENGTH_256 = 0
copy_next_hi:
        dec zpLenHi
        jmp copy_next
    endif
    if LITERAL_SEQUENCES_NOT_USED = 0
get_literal_byte:
        jsr GetByte
        sec
        bcs literal_byte_gotten
    endif
; -------------------------------------------------------------------
; exit or literal sequence handling (16(12) bytes)
;
exit_or_lit_seq:
    if LITERAL_SEQUENCES_NOT_USED = 0
        beq decr_exit
        jsr GetByte
    if MAX_SEQUENCE_LENGTH_256 = 0
        sta zpLenHi
    endif
        jsr GetByte
        tax
        sec
        bcs copy_next
decr_exit:
    endif
        clc
        rts

; -------------------------------------------------------------------
; the static stable used for bits+offset for lengths 3, 1 and 2 (3 bytes)
; bits 4, 2, 4 and offsets 16, 48, 32
tablBit:
        dc.b %11100001, %10001100, %11100010

; -------------------------------------------------------------------
; end of decruncher
; -------------------------------------------------------------------
