# C64gameframework

Framework for multidirectionally scrolling games on the Commodore 64. Used in the upcoming MW ULTRA game.

Technical details:

- 50Hz screen update, with actor update each second frame and interpolation of sprite movement
- 22 visible scrolling rows (21 on unaccelerated NTSC), based on flexible screen redraw (color per char / color per block / skip color update)
- 24 sprite multiplexer
- Realtime sprite depacking, using a sprite cache
- Logical sprites which can consist of several physical sprites, and which can be X-expanded
- Graphical editing of sprite collision bounds
- Dynamic memory allocation for sprites & level data & loadable code
- [Miniplayer](https://github.com/cadaver/miniplayer) music & sound playback
- Filter cutoff compensation on 8580 SID to make it sound more like 6581
- Accelerated CPU mode on C128 & SuperCPU, activated in the vertical border
- Loader based on the CovertBitops Loader V2.24 (1541/1581/FD/HD/IDE64)
- EasyFlash & GMOD2 mastering and save support
- Exomizer2 compression

Documentation and use example will be improved as an ongoing project.

See also [CovertBitops homepage](http://cadaver.github.io).

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
