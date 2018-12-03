# C64gameframework

Framework for multidirectionally scrolling games on the Commodore 64. Used in the upcoming MW ULTRA game.

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
- Optional reduction of scroll area to 21 rows on unaccelerated NTSC machines, due to less available CPU cycles per frame
- Loader based on the CovertBitops Loader V2.24 (1541/1581/FD/HD/IDE64)
- EasyFlash & GMod2 mastering and save support
- Exomizer2 compression

Documentation and use example will be improved as an ongoing project.

The example game implements a simplified sidescrolling platformer / shooter based on Steel Ranger assets. There's a player character and one type of enemy,
collectable health and ammo, transitions from one area to other, and checkpoint save / restore to memory.

See also [CovertBitops homepage](http://cadaver.github.io).

## Building

- The Makefile builds the example game as a .d64 image and EF / GMod2 .crt images. Utilities contained in the "tools" subdirectory must be in the path.
- For rebuilding the utilities on Windows, the MinGW compiler suite is required

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
- $f000-$f23f Rest of the per-charset data
- $f240-$f7ff Misc var area 1
- $f800-$fc00 Game screen
- $fc00-$fc3f Empty sprite
- $fc40-$fff9 Misc var area 2

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
- V B N Char color swaps (press with Shift for different swaps)
- I Show collision info
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
- RMB Expand zone
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

- LMB Place object
- RMB Place actor
- , . or Z X Select actor type (faster with Shift)
- I Switch between actors & items
- 0-9 A-F Object data hex edit
- Enter Go to / leave object data edit mode (when cursor over object)
- 1 2 Edit actor databyte (weapon / item count)
- 3 4 Edit actor databyte fast
- 5 6 Edit actor type
- D Toggle actor dir left/right / toggle object autodeactivation
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
- V B N Sprite color swaps
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

Note: sprites will be saved both in editor's own format (for further editing) and C64 resource format (.res files). In projects,
it is recommended to put both under version control.

## License

Copyright (c) 2018 Lasse Öörni

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
