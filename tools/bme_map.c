//
// BME (Blasphemous Multimedia Engine) blockmap module
//

#include <stdlib.h>
#include <string.h>
#include <SDL/SDL.h>

#include "bme_main.h"
#include "bme_gfx.h"
#include "bme_err.h"
#include "bme_cfg.h"
#include "bme_io.h"

#define MAX_LAYERS 4
#define MAX_STEP 64

MAPHEADER map_header;
LAYERHEADER map_layer[MAX_LAYERS];
Uint16 *map_layerdataptr[] = {NULL,NULL,NULL,NULL};
Uint8 *map_blkinfdata = NULL;

static BLOCKHEADER map_blkstorage[MAX_STEP];

void map_freemap(void);
int map_loadmap(char *name);
void map_drawalllayers(int xpos, int ypos, int xorigin, int yorigin, int xblocks, int yblocks);
void map_drawlayer(int l, int xpos, int ypos, int xorigin, int yorigin, int xblocks, int yblocks);
int map_loadblockinfo(char *name);
Uint8 map_getblockinfo(int l, int xpos, int ypos);
unsigned map_getblocknum(int l, int xpos, int ypos);
void map_setblocknum(int l, int xpos, int ypos, unsigned num);
void map_shiftblocksback(unsigned first, int amount, int step);
void map_shiftblocksforward(unsigned first, int amount, int step);

int map_loadblockinfo(char *name)
{
    int handle;

    if (map_blkinfdata)
    {
        free(map_blkinfdata);
        map_blkinfdata = NULL;
    }
    map_blkinfdata = malloc((gfx_nblocks+1)*16);
    if (!map_blkinfdata) return 0;
    memset(map_blkinfdata, 0, (gfx_nblocks+1)*16);

    handle = io_open(name);
    if (handle == -1) return 0;
    io_read(handle, &map_blkinfdata[0], (gfx_nblocks+1)*16);
    io_close(handle);
    return 1;
}

void map_freemap(void)
{
    int c;

    for (c = 0; c < MAX_LAYERS; c++)
    {
        if (map_layerdataptr[c])
        {
            free(map_layerdataptr[c]);
            map_layerdataptr[c] = NULL;
        }
    }
}

int map_loadmap(char *name)
{
    int handle, c;

    map_freemap();

    handle = io_open(name);
    if (handle == -1) return 0;
    /* Load map header */
    io_read(handle, &map_header, sizeof(MAPHEADER));
    /* Load each layer */
    for (c = 0; c < MAX_LAYERS; c++)
    {
        map_layer[c].xsize = io_readle32(handle);
        map_layer[c].ysize = io_readle32(handle);
        map_layer[c].xdivisor = io_read8(handle);
        map_layer[c].ydivisor = io_read8(handle);
        map_layer[c].xwrap = io_read8(handle);
        map_layer[c].ywrap = io_read8(handle);
        if ((map_layer[c].xsize) && (map_layer[c].ysize))
        {
            int d;
            map_layerdataptr[c] = malloc(map_layer[c].xsize*map_layer[c].ysize * sizeof(Uint16));
            if (!map_layerdataptr[c])
            {
                io_close(handle);
                map_freemap();
                return 0;
            }
            for (d = 0; d < map_layer[c].xsize * map_layer[c].ysize; d++)
            {
                map_layerdataptr[c][d] = io_readle16(handle);
            }
        }
    }
    io_close(handle);
    return 1;
}

void map_drawalllayers(int xpos, int ypos, int xorigin, int yorigin, int xblocks, int yblocks)
{
    int c;
    for (c = 0; c < MAX_LAYERS; c++)
    {
        map_drawlayer(c, xpos, ypos, xorigin, yorigin, xblocks, yblocks);
    }
}

void map_drawlayer(int l, int xpos, int ypos, int xorigin, int yorigin, int xblocks, int yblocks)
{
    int x,y;
    int realxpos = 0, realypos = 0;
    int blockxpos, finexpos;
    int blockypos, fineypos;
    Uint16 *mapptr;

    /* Check for inactive layer */
    if ((!map_layer[l].xsize) || (!map_layer[l].ysize)) return;

    if (map_layer[l].xdivisor) realxpos = xpos / map_layer[l].xdivisor;
    if (map_layer[l].ydivisor) realypos = ypos / map_layer[l].ydivisor;

    if (realxpos < 0) realxpos = 0;
    if (realypos < 0) realypos = 0;

    finexpos = realxpos % gfx_blockxsize;
    fineypos = realypos % gfx_blockysize;
    blockxpos = realxpos / gfx_blockxsize;
    blockypos = realypos / gfx_blockysize;

    if (!map_layer[l].xwrap)
    {
        if ((blockxpos + xblocks-1) > map_layer[l].xsize)
        {
            if (map_layer[l].xsize - (xblocks - 1) >= 0)
            {
                blockxpos = map_layer[l].xsize - (xblocks-1);
                finexpos = gfx_blockxsize - 1;
            }
        }
    }

    if (!map_layer[l].ywrap)
    {
        if ((blockypos + yblocks-1) > map_layer[l].ysize)
        {
            if (map_layer[l].ysize - (yblocks - 1) >= 0)
            {
                blockypos = map_layer[l].ysize - (yblocks-1);
                fineypos = gfx_blockysize - 1;
            }
        }
    }

    blockxpos %= map_layer[l].xsize;
    blockypos %= map_layer[l].ysize;

    for (y = 0; y < yblocks; y++)
    {
        if (blockypos >= map_layer[l].ysize) blockypos = 0;
        mapptr = &map_layerdataptr[l][map_layer[l].xsize*blockypos];
        for (x = 0; x < xblocks; x++)
        {
            int xpos = blockxpos + x;
            if (xpos >= map_layer[l].xsize) xpos %= map_layer[l].xsize;
            gfx_drawblock(xorigin+(x*gfx_blockxsize)-finexpos, yorigin+(y*gfx_blockysize)-fineypos, mapptr[xpos]);
        }
        blockypos++;
    }
}

Uint8 map_getblockinfo(int l, int xpos, int ypos)
{
    int xfine, yfine;
    unsigned blocknum;

    xfine = ((xpos % gfx_blockxsize)*4)/gfx_blockxsize;
    yfine = ((ypos % gfx_blockysize)*4)/gfx_blockysize;
    xpos /= gfx_blockxsize;
    ypos /= gfx_blockysize;

    if (xpos < 0) return 0;
    if (xpos >= map_layer[l].xsize) return 0;
    if (ypos < 0) return 0;
    if (ypos >= map_layer[l].ysize) return 0;

    blocknum = map_layerdataptr[l][map_layer[l].xsize*ypos+xpos];
    if (blocknum > gfx_nblocks) return 0;
    return map_blkinfdata[blocknum*16+yfine*4+xfine];
}

unsigned map_getblocknum(int l, int xpos, int ypos)
{
    xpos /= gfx_blockxsize;
    ypos /= gfx_blockysize;

    if (xpos < 0) return 0;
    if (xpos >= map_layer[l].xsize) return 0;
    if (ypos < 0) return 0;
    if (ypos >= map_layer[l].ysize) return 0;

    return map_layerdataptr[l][map_layer[l].xsize*ypos+xpos];
}

void map_setblocknum(int l, int xpos, int ypos, unsigned num)
{
    if (num > gfx_nblocks) return;

    xpos /= gfx_blockxsize;
    ypos /= gfx_blockysize;

    if (xpos < 0) return;
    if (xpos >= map_layer[l].xsize) return;
    if (ypos < 0) return;
    if (ypos >= map_layer[l].ysize) return;

    map_layerdataptr[l][map_layer[l].xsize*ypos+xpos] = num;
}

void map_shiftblocksback(unsigned first, int amount, int step)
{
    BLOCKHEADER *ptr = gfx_blockheaders;

    if (!ptr) return;

    first--;
    if (first >= gfx_nblocks) return;
    if ((first + amount) > gfx_nblocks) return;
    ptr += first;

    if (step > MAX_STEP) return;
    if (amount - step < 1) return;

    memmove(map_blkstorage, ptr, sizeof(BLOCKHEADER) * step);
    memmove(ptr, &ptr[step], sizeof(BLOCKHEADER) * (amount - step));
    memmove(&ptr[amount - step], map_blkstorage, sizeof(BLOCKHEADER) * step);
}

void map_shiftblocksforward(unsigned first, int amount, int step)
{
    BLOCKHEADER *ptr = gfx_blockheaders;

    if (!ptr) return;

    first--;
    if (first >= gfx_nblocks) return;
    if ((first + amount) > gfx_nblocks) return;
    ptr += first;

    if (step > MAX_STEP) return;
    if (amount - step < 1) return;

    memmove(map_blkstorage, &ptr[amount - step], sizeof(BLOCKHEADER) * step);
    memmove(&ptr[step], ptr, sizeof(BLOCKHEADER) * (amount - step));
    memmove(ptr, map_blkstorage, sizeof(BLOCKHEADER) * step);
}

