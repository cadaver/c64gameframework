# C64gameframework

Framework for multidirectionally scrolling games on the Commodore 64. Used in the upcoming MW ULTRA game.

Technical details:

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
- EasyFlash & GMOD2 mastering and save support
- Exomizer2 compression

Documentation and use example will be improved as an ongoing project.

See also [CovertBitops homepage](http://cadaver.github.io).

## Example

The use example implements a simplified sidescrolling platformer / shooter based on Steel Ranger assets. There's a player character and one type of enemy,
collectable health and ammo, transitions from one area to other, and checkpoint save / restore to memory.

## World editor (worlded3) controls

### General

F1 Load shapes
F2 Save shapes
F3 Import 4x4 blocks to shapes
F5 Shape editor
F6 Map editor
F7 Zone (area) aditor
F8 Object / actor placement editor
F9 Load world
F10 Save world
F11 Export world as .png image
F12 Erase charset
ESC Quit

### Shape editor

LMB Draw with current color
RMB Erase
MMB Select char / block within shape
Space Select part of shape
Tab Select charset (shift + Tab to select backward)
Arrows Scroll shape zoomed view
Ctrl + arrows Edit shape size
Shift + arrows Scroll char
, . or Z X Select shape
P Put char / partial shape to copybuffer
T Take char / partial shape from copybuffer
Q W Select current zone (to check multicolors)
L Locked edit mode, all similar chars within all shapes will be affected
G Pick color
R Reverse char
C Clear char
F Fill char with current color
V B N Char color swaps (press with Shift for different swaps)
I Show collision info
S Cycle through slope types
1-8 Edit collision info (per 2x2 block within shape)
Ctrl + 0-8 Change char color
Shift + 1-4 Select color to draw with
Shift + P Put whole shape to copybuffer
Shift + T Take whole shape from copybuffer
Shift + F Fill shape with current color
Shift + Ctrl + 0-8 Change whole shape char color
Shift + Backspace Reset shape
Shift + Ins Insert shape
Shift + Del Delete shape

### Map editor

LMB Place current shape
RMB or Space Mark areas
Shift+LMB Erase shapes
Tab Select charset (shift + Tab to select backward)
Arrows Scroll map (faster with Shift)
B Shape selection screen
I Show collision info
O Show block optimization types (color per char, color per block, optimize colorwrite away)
N Show navareas
V Zoom out / in
G Pick shape
P Put area to copybuffer
T Take area from copybuffer
F Select zone fill shape (Shift + F to select backward)
Shift+C Erase all shapes from current zone
Shift+D Erase all instances of shape from current zone

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
