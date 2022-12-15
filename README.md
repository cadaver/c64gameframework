# C64gameframework

Framework for multidirectionally scrolling games on the Commodore 64. A modified version (practically this means optimized to be unusable except for the project in question) is used in the MW ULTRA game.

Features:

- 50Hz screen update, with actor update each second frame and interpolation of sprite movement
- 22 visible scrolling rows, based on flexible screen redraw (color per char / color per block / skip color update)
- 24 sprite multiplexer
- Realtime sprite depacking, using a sprite cache
- Logical sprites which can consist of several physical sprites, and which can be X-expanded
- Graphical editing of sprite collision bounds
- Dynamic memory allocation for sprites & level data & loadable code
- [Miniplayer](https://github.com/cadaver/miniplayer) music & sound playback
- Filter cutoff compensation on 8580 SID to make it sound more like 6581
- Accelerated CPU mode on C128 & SuperCPU, activated in the vertical border
- Loader based on the Covert Bitops Loadersystem V2.2x, but with added fastloader support for the SD2IEC by utilizing the ELoad protocol.
- EasyFlash & GMod2 mastering and save support
- Exomizer3 compression

Documentation and use example will be improved as an ongoing project.

The example game implements a simplified sidescrolling platformer / shooter based on Steel Ranger assets. There's a player character and one type of enemy,
collectable health and ammo, transitions from one area to other, and checkpoint save / restore to memory.

See also [CovertBitops homepage](http://cadaver.github.io).

## Building

- The Makefile builds the example game as a .d64 image and EF / GMod2 .crt images.
- Utilities contained in the "tools" subdirectory must be in the path.
- For rebuilding the utilities on Windows, the MinGW compiler suite is required.

## Getting started with the code

- boot.s is the disk version boot code. It will first load the Exomizer decompression code and then the compressed disk loader (loader.s), which will detect the drive loaded from, and enable one of the three sets of IO routines: regular fastloader, Kernal fallback, or ELoad (SD2IEC) fastloader. Then it proceeds to load the mainpart.
- efboot.s & gmod2boot.s are the same for EasyFlash & GMod2 cartridges. For the most part, the main code can be agnostic of the device used for loading.
- main.s is the mainpart, which includes the rest of the framework, and contains the game initialization and main loop. Modify to your own needs!
- script00.s contains all the loadable code used by the example game's actors (player / items / enemies / bullets / explosions.) Common actor code can just as well be contained statically in the mainpart, this is just to demonstrate dynamic code loading.
- Note that the Makefile assembles the boot part multiple times, as there are circular dependencies between it and the loader. This ensures the boot code has correct addresses to proceed.

## Memory map

- $0200-$02ff Fastloader sector buffer
- $0334-$04fx Loader resident code
- $04fx-$4xxx Engine resident code and variables (grows as necessary)
- $4xxx-$cxxx Dynamic memory allocation area
- $cxxx-$cxxx Zone depack buffer
- $cxxx-$cfff Music allocation area
- $d000-$dfff Sprite depacking cache
- $e000-$e3ff Scorepanel charset and screen
- $e400-$e7ff Charset's block data
- $e800-$efff Charset's char data
- $f000-$f2bf Rest of the per-charset data
- $f2c0-$f7ff Misc var area 1
- $f800-$fc00 Game screen
- $fc00-$fc3f Empty sprite
- $fc40-$fff9 Misc var area 2

## Loading special considerations

- Due to optimized 2-bit fastloader transfer routine, the videobank must be at $c000-$ffff at all times.
- The loader will retry infinitely on sector read error, so any file access code does not have to account for that. However loading can fail if a file is not found.
- To optimize for size, the engine's internal loading routines (e.g. level or music change) do not check for file not found. Therefore, if you have a multi-diskside game, make sure to check for the correct side (by checking existence of a file) as needed, before using those functions.

## Screen redraw & world graphics

- The screen redraw for scrolling is based on writing both the screen data and color data at once, during a single frame, without doublebuffering.
- The world editor can edit arbitrarily sized shapes, but these are reduced to 2x2 blocks in the C64 side world data, similar to Steel Ranger. An error is shown if the shapes don't fit to 256 chars & 256 2x2 blocks.
- Color-per-char blocks must have the char color and the low 4 bits of the char screen code the same (inspired by QUOD INIT EXIT 2 by Retream.) Arranging the charset this way is handled automatically by the world editor. An error is also displayed if arranging the charset fails due to color-per-char blocks using too many unique chars (more than 16) with the same color. Multicolor chars that actually don't use the char color are allocated under the "wrong" char color if necessary.
- In addition, if there are free blocks, the editor will create "optimized" blocks which skip the color write when possible, for example empty sky. These are automatically inserted into the C64 side world data.
- A level can consist of multiple scrolling zones or areas (the example game contains 2.) All the zone map datas of the current level are stored compressed within the dynamic allocation area, and when a zone is entered, the map data is depacked at the end of the dynamic memory area, just before music, for actually displaying.
- Each zone can contain "objects" (such as doorways to other areas) and "actors" (typically items and enemies.)

## Sprite graphics

- Each actor type has its own draw routine, which calls into the framework code (DrawLogicalSprite) to insert logical sprites for rendering. For example the player character is 2 logical sprites: lower and upper body.
- Logical sprites are created in the sprite editor, and can consist of multiple C64 hardware (physical) sprites.
- In addition a logical sprite has hotspot coordinates, 0 - n collision bounds (edited graphically) and optionally a connect-spot coordinate.
- Connect-spot coordinates are used in the actor draw routine to join logical sprites together, for example the player character's body halves. 
- A logical sprite without a connect-spot will use a slightly faster draw path, so clear the connect-spot (Shift+J) when not needed, for example items and bullets.
- The sprite editor will save both in editor's own format (for further editing) and C64 resource format (.res files). In projects, it is recommended to put both under version control.

## World editor (worlded3) controls

### General

- F1 Load shapes
- F2 Save shapes
- F3 Import 4x4 blocks to shapes
- F5 Shape editor
- F6 Map editor
- F7 Zone (area) aditor
- F8 Object / actor placement editor
- F9 Load world
- F10 Save world
- F11 Export world as .png image
- F12 Erase charset
- ESC Quit

### Shape editor

- LMB Draw with current color
- RMB Erase pixels
- MMB Select char / block within shape
- Space Select rectangular area
- Tab Select charset (Shift+Tab to select backward)
- Arrows Scroll shape zoomed view
- Ctrl+arrows Edit shape size
- Shift+arrows Scroll char
- , . or Z X Select shape
- P Put char / partial shape to copybuffer
- T Take char / partial shape from copybuffer
- Q W Select current zone (to check multicolors)
- L Toggle locked edit mode, all similar chars within all shapes will be affected
- G Pick color
- R Reverse char
- C Clear char
- F Fill char with current color
- V B N Swap char color (with Shift for different swaps)
- I Show collision info
- O Show block optimization types (color per char, color per block, optimize colorwrite away)
- S Cycle through slope types
- 1-8 Edit collision info (per 2x2 block within shape)
- Ctrl+0-8 Change char color
- Shift+1-4 Select color to draw with
- Shift+P Put whole shape to copybuffer
- Shift+T Take whole shape from copybuffer
- Shift+F Fill shape with current color
- Shift+Ctrl+0-8 Change whole shape char color
- Shift+Backspace Reset shape
- Shift+Ins Insert shape
- Shift+Del Delete shape
- Ctrl+Shift+T Insert-move last copied shape at current shape
- Ctrl+Shift+P (at palette editor, when mouse is over color) Swap colors globally in charset
- Ctrl+Shift+I Charset insert
- Ctrl+Shift+U Remove unused shapes from charset

### Map editor

- LMB Place current shape
- RMB or Space Mark areas
- Shift+LMB Erase shapes
- Tab Select zone charset (Shift+Tab to select backward)
- Arrows Scroll map (faster with Shift)
- B Shape selection screen
- I Show collision info
- O Show block optimization types (color per char, color per block, optimize colorwrite away)
- N Show navareas
- V Zoom out / in
- G Pick shape
- P Put area to copybuffer
- T Take area from copybuffer
- F Select zone fill shape (Shift+F to select backward)
- Shift+C Erase all shapes from current zone
- Shift+D Erase all instances of shape from current zone

### Zone editor

- LMB Select zone
- RMB Create or expand zone
- Shift+RMB (at zone edge) Shrink zone
- , . or Z X Select zone
- U Select next unused zone
- Tab Select zone charset (Shift+Tab to select backward)
- L Select level in which zone belongs (Shift+L to select backward)
- F Select zone fill shape (Shift+F to select backward)
- G Go to current zone's location
- Shift+Del Erase zone
- Shift+R Relocate zone
- Ctrl+Shift+R Relocate whole world
- Ctrl+Ins Change level of all zones forward past current
- Ctrl+Del Change level of all zones backward past current

### Object / actor editor

- LMB Place object / set data to point to this (if in object data edit mode)
- RMB Place actor
- , . or Z X Select actor type (faster with Shift)
- I Switch between actors & items
- 0-9 A-F Object data hex edit
- Enter Go to / leave object data edit mode (when cursor over object)
- 1 2 Edit actor databyte (weapon / item count)
- 3 4 Edit actor databyte fast
- 5 6 Edit actor type
- D Toggle actor dir left/right / toggle object autodeactivation
- G Toggle actor global flag. Global actors are not stored in leveldata but in the source file worldglobal.s (max. 32 currently)
- H Toggle actor hidden flag
- F Edit object animation frame count
- M Edit object activation mode
- T Edit object type
- X Edit object X-size (Shift+X to edit backward)
- Y Edit object Y-size (Shift+Y to edit backward)
- Del Erase actor or object

## Sprite editor (spred3) controls

- F1 Load sprites
- F2 Save sprites
- F3 Import Steel Ranger sprites
- F4 Import Hessian / Metal Warrior 4 sprites
- ESC Quit
- LMB Draw with current color
- RMB Erase pixels
- Space Mark areas
- , . Select sprite
- A Add collision axis-aligned box. Hold to adjust size for new box, or press on existing box to edit properties (Shift+A to remove)
- S Add physical sprite. Press on existing box to edit color (Shift+S to remove)
- X Flip sprite horizontally
- Y Flip sprite vertically
- W Toggle X-expand of physical sprite
- U Undo
- V B N Swap sprite colors
- F Floodfill
- L Draw line
- H Place sprite hotspot
- J Place sprite connect-spot
- P Put marked area to copybuffer as brush
- T Draw with brush
- Ctrl+T Erase brush
- 1-8 Edit test sprites (select, position, frame)
- Del Erase sprite
- Ins Insert sprite
- Arrows Scroll view
- Shift+1-4 Select color to draw with
- Shift+arrows Scroll sprite
- Shift+C Clear sprite
- Shift+J Clear connect-spot
- Shift+P Put sprite to copybuffer
- Shift+T Take sprite from copybuffer
- Shift+X Toggle sprite's "store flipped" mode. If a sprite is stored flipped, depacking it facing left for display is faster.

## License

Copyright (c) 2018-2022 Lasse Öörni

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
