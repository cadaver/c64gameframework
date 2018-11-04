        ; Defines that affect the memory map

MAX_SPR         = 24
MAX_CACHESPRITES = 64
MAX_CHUNKFILES  = 64
MAX_MAPROWS     = 64
MAX_LVLACT      = 96
MAX_LVLOBJ      = 96
MAX_SAVEACT     = 32
MAX_ZONEOBJ     = 15
MAX_ACT         = 20
MAX_COMPLEXACT  = 6
MAX_BOUNDS      = 32
MAX_NAVAREAS    = 48
MAX_ACTX        = 26
MAX_ACTY        = 19

ACTI_PLAYER     = 0
ACTI_FIRSTNPC   = 1
ACTI_LASTNPC    = MAX_COMPLEXACT-1
ACTI_FIRSTNONNPC = MAX_COMPLEXACT
ACTI_LAST       = MAX_ACT-1

SCROLLROWS      = 23
USETURBOMODE    = 1                             ;Use C128 & SuperCPU turbo mode
NTSCSIZEREDUCE  = 1                             ;Reduce scrolling area by 1 row on unaccelerated NTSC machines
RIGHTCLIPPING   = 0                             ;Use dedicated routines for drawing to screen right edge for less rastertime use
