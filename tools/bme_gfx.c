//
// BME (Blasphemous Multimedia Engine) graphics main module
//

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <SDL/SDL.h>

#include "bme_main.h"
#include "bme_cfg.h"
#include "bme_win.h"
#include "bme_io.h"
#include "bme_err.h"

// Prototypes

int gfx_init(unsigned xsize, unsigned ysize, unsigned framerate, unsigned flags);
int gfx_reinit(void);
void gfx_uninit(void);
void gfx_updatepage(void);
void gfx_blitwindow(void);
void gfx_wipepages(void);
void gfx_setclipregion(unsigned left, unsigned top, unsigned right, unsigned bottom);
void gfx_setmaxspritefiles(int num);
void gfx_setmaxcolors(int num);
int gfx_loadpalette(char *name);
void gfx_calcpalette(int fade, int radd, int gadd, int badd);
void gfx_setpalette(void);
int gfx_loadblocks(char *name);
int gfx_loadsprites(int num, char *name);
void gfx_freesprites(int num);

static void gfx_copyscreen8(Uint8  *destaddress, Uint8  *srcaddress, unsigned pitch);
void gfx_drawblock(int x, int y, unsigned num);
void gfx_drawsprite(int x, int y, unsigned num);
void gfx_drawspritec(int x, int y, unsigned num, int color);
void gfx_drawspritex(int x, int y, unsigned num, Uint8  *xlattable);
void gfx_getspriteinfo(unsigned num);
void gfx_fillscreen(int color);
void gfx_plot(int x, int y, int color);
void gfx_line(int x1, int y1, int x2, int y2, int color);

int gfx_initted = 0;
int gfx_fullscreen = 0;
int gfx_scanlinemode = 0;
int gfx_preventswitch = 0;
int gfx_virtualxsize;
int gfx_virtualysize;
int gfx_windowxsize;
int gfx_windowysize;
int gfx_blockxsize = 16;
int gfx_blockysize = 16;
int spr_xsize = 0;
int spr_ysize = 0;
int spr_xhotspot = 0;
int spr_yhotspot = 0;
unsigned gfx_nblocks = 0;
Uint8 *gfx_vscreen = NULL;
Uint8 gfx_palette[MAX_COLORS * 3] = {0};
Uint8 *gfx_blocks = NULL;
BLOCKHEADER *gfx_blockheaders = NULL;

// Static variables

static int gfx_initexec = 0;
static unsigned gfx_last_xsize;
static unsigned gfx_last_ysize;
static unsigned gfx_last_framerate;
static unsigned gfx_last_flags;
static int gfx_cliptop;
static int gfx_clipbottom;
static int gfx_clipleft;
static int gfx_clipright;
static int gfx_maxcolors = MAX_COLORS;
static int gfx_maxspritefiles = 0;
static SPRITEHEADER **gfx_spriteheaders = NULL;
static Uint8 **gfx_spritedata = NULL;
static unsigned *gfx_spriteamount = NULL;
static SDL_Surface *gfx_screen = NULL;
static SDL_Color gfx_sdlpalette[MAX_COLORS];

int gfx_init(unsigned xsize, unsigned ysize, unsigned framerate, unsigned flags)
{
    int sdlflags = SDL_HWSURFACE;

    // Prevent re-entry (by window procedure)
    if (gfx_initexec) return BME_OK;
    gfx_initexec = 1;

    gfx_last_xsize = xsize;
    gfx_last_ysize = ysize;
    gfx_last_framerate = framerate;
    gfx_last_flags = flags & ~(GFX_FULLSCREEN | GFX_WINDOW);

    // Store the options contained in the flags

    gfx_scanlinemode = flags & (GFX_SCANLINES | GFX_DOUBLESIZE);

    if (flags & GFX_NOSWITCHING) gfx_preventswitch = 1;
        else gfx_preventswitch = 0;
    if (win_fullscreen) sdlflags |= SDL_FULLSCREEN;
    if (flags & GFX_FULLSCREEN) sdlflags |= SDL_FULLSCREEN;
    if (flags & GFX_WINDOW) sdlflags &= ~SDL_FULLSCREEN;
    if (sdlflags & SDL_FULLSCREEN)
    {
        sdlflags |= SDL_DOUBLEBUF;
        gfx_fullscreen = 1;
    }
    else gfx_fullscreen = 0;

    // Calculate virtual window size

    gfx_virtualxsize = xsize;
    gfx_virtualxsize /= 16;
    gfx_virtualxsize *= 16;
    gfx_virtualysize = ysize;
    gfx_vscreen = NULL;

    if ((!gfx_virtualxsize) || (!gfx_virtualysize))
    {
        gfx_initexec = 0;
        gfx_uninit();
        bme_error = BME_ILLEGAL_CONFIG;
        return BME_ERROR;
    }

    // Calculate actual window size (for scanline mode & doublesize mode
    // this is double the virtual)

    gfx_windowxsize = gfx_virtualxsize;
    gfx_windowysize = gfx_virtualysize;
    if (gfx_scanlinemode)
    {
        gfx_windowxsize <<= 1;
        gfx_windowysize <<= 1;
    }

    gfx_vscreen = malloc(gfx_virtualysize*gfx_virtualxsize);
    if (!gfx_vscreen)
    {
        gfx_initexec = 0;
        gfx_uninit();
        bme_error = BME_OUT_OF_MEMORY;
        return BME_ERROR;
    }
    gfx_setclipregion(0, 0, gfx_virtualxsize, gfx_virtualysize);

    // Colors 0 & 255 are always black & white
    gfx_sdlpalette[0].r = 0;
    gfx_sdlpalette[0].g = 0;
    gfx_sdlpalette[0].b = 0;
    gfx_sdlpalette[255].r = 255;
    gfx_sdlpalette[255].g = 255;
    gfx_sdlpalette[255].b = 255;

    gfx_screen = SDL_SetVideoMode(gfx_windowxsize, gfx_windowysize, 8, sdlflags);
    gfx_initexec = 0;
    if (gfx_screen)
    {
        gfx_initted = 1;
        gfx_setpalette();
        win_setmousemode(win_mousemode);
        return BME_OK;
    }
    else return BME_ERROR;
}

int gfx_reinit(void)
{
    return gfx_init(gfx_last_xsize, gfx_last_ysize, gfx_last_framerate,
        gfx_last_flags);
}

void gfx_uninit(void)
{
    if (gfx_initted)
    {
        free(gfx_vscreen);
        gfx_vscreen = NULL;
    }
    gfx_initted = 0;
    return;
}

void gfx_wipepages(void)
{
    return;
}

void gfx_updatepage(void)
{
    if (gfx_initted)
    {
        if (!SDL_LockSurface(gfx_screen))
        {
            Uint8  *destaddress = gfx_screen->pixels;
            gfx_copyscreen8(destaddress, gfx_vscreen, gfx_screen->pitch);
            SDL_UnlockSurface(gfx_screen);
            SDL_Flip(gfx_screen);
        }
    }
}

void gfx_blitwindow(void)
{
    return;
}

void gfx_setmaxcolors(int num)
{
    gfx_maxcolors = num;
}

int gfx_loadpalette(char *name)
{
    int handle;

    handle = io_open(name);
    if (handle == -1)
    {
        bme_error = BME_OPEN_ERROR;
        return BME_ERROR;
    }
    if (io_read(handle, gfx_palette, sizeof gfx_palette) != sizeof gfx_palette)
    {
        bme_error = BME_READ_ERROR;
        io_close(handle);
        return BME_ERROR;
    }

    io_close(handle);
    gfx_calcpalette(64, 0, 0, 0);
    bme_error = BME_OK;
    return BME_OK;
}

void gfx_calcpalette(int fade, int radd, int gadd, int badd)
{
    Uint8  *sptr = &gfx_palette[3];
    int c, cl;
    if (radd < 0) radd = 0;
    if (gadd < 0) gadd = 0;
    if (badd < 0) badd = 0;

    for (c = 1; c < 255; c++)
    {
        cl = *sptr;
        cl *= fade;
        cl >>= 6;
        cl += radd;
        if (cl > 63) cl = 63;
        if (cl < 0) cl = 0;
        gfx_sdlpalette[c].r = (cl << 2) | (cl & 3);
        sptr++;

        cl = *sptr;
        cl *= fade;
        cl >>= 6;
        cl += gadd;
        if (cl > 63) cl = 63;
        if (cl < 0) cl = 0;
        gfx_sdlpalette[c].g = (cl << 2) | (cl & 3);
        sptr++;

        cl = *sptr;
        cl *= fade;
        cl >>= 6;
        cl += badd;
        if (cl > 63) cl = 63;
        if (cl < 0) cl = 0;
        gfx_sdlpalette[c].b = (cl << 2) | (cl & 3);
        sptr++;
    }
}

void gfx_setpalette(void)
{
    if (!gfx_initted) return;

    SDL_SetColors(gfx_screen, &gfx_sdlpalette[0], 0, gfx_maxcolors);
}

void gfx_setclipregion(unsigned left, unsigned top, unsigned right, unsigned bottom)
{
    if (left >= right) return;
    if (top >= bottom) return;
    if (left >= gfx_virtualxsize) return;
    if (top >= gfx_virtualysize) return;
    if (right > gfx_virtualxsize) return;
    if (bottom > gfx_virtualysize) return;

    gfx_clipleft = left;
    gfx_clipright = right;
    gfx_cliptop = top;
    gfx_clipbottom = bottom;
}

int gfx_loadblocks(char *name)
{
    int handle, size, datastart, c;
    BLOCKHEADER *hptr;

    handle = io_open(name);
    if (handle == -1)
    {
        bme_error = BME_OPEN_ERROR;
        return 0;
    }

    if (gfx_blocks)
    {
        free(gfx_blocks);
        gfx_blocks = NULL;
    }
    if (gfx_blockheaders)
    {
        free(gfx_blockheaders);
        gfx_blockheaders = NULL;
    }
    gfx_nblocks = 0;
    
    size = io_lseek(handle, 0, SEEK_END);
    io_lseek(handle, 0, SEEK_SET);

    gfx_nblocks = io_readle32(handle);
    gfx_blockxsize = io_readle32(handle);
    gfx_blockysize = io_readle32(handle);

    gfx_blockheaders = malloc(sizeof(BLOCKHEADER) * gfx_nblocks);
    if (!gfx_blockheaders)
    {
        bme_error = BME_OUT_OF_MEMORY;
        gfx_nblocks = 0;
        io_close(handle);
        return BME_ERROR;
    }

    for (c = 0; c < gfx_nblocks; c++)
    {
        hptr = gfx_blockheaders + c;
        hptr->type = io_readle32(handle);
        hptr->offset = io_readle32(handle);
    }

    datastart = io_lseek(handle, 0, SEEK_CUR);
    gfx_blocks = malloc(size - datastart);
    if (!gfx_blocks)
    { 
        free(gfx_blockheaders);
        gfx_blockheaders = NULL;
        bme_error = BME_OUT_OF_MEMORY;
        gfx_nblocks = 0;
        io_close(handle);
        return BME_ERROR;
    }
    io_read(handle, gfx_blocks, size - datastart);
    io_close(handle);
    bme_error = BME_OK;
    return BME_OK;
}

void gfx_setmaxspritefiles(int num)
{
    if (num <= 0) return;

    if (gfx_spriteheaders) return;

    gfx_spriteheaders = malloc(num * sizeof(Uint8 *));
    gfx_spritedata = malloc(num * sizeof(Uint8 *));
    gfx_spriteamount = malloc(num * sizeof(unsigned));
    if ((gfx_spriteheaders) && (gfx_spritedata) && (gfx_spriteamount))
    {
        int c;

        gfx_maxspritefiles = num;
        for (c = 0; c < num; c++)
        {
            gfx_spriteamount[c] = 0;
            gfx_spritedata[c] = NULL;
            gfx_spriteheaders[c] = NULL;
        }
    }
    else gfx_maxspritefiles = 0;
}

int gfx_loadsprites(int num, char *name)
{
    int handle, size, c;
    int datastart;

    if (!gfx_spriteheaders)
    {
        gfx_setmaxspritefiles(DEFAULT_MAX_SPRFILES);
    }

    bme_error = BME_OPEN_ERROR;
    if (num >= gfx_maxspritefiles) return BME_ERROR;

    gfx_freesprites(num);

    handle = io_open(name);
    if (handle == -1) return BME_ERROR;

    size = io_lseek(handle, 0, SEEK_END);
    io_lseek(handle, 0, SEEK_SET);

    gfx_spriteamount[num] = io_readle32(handle);

    gfx_spriteheaders[num] = malloc(gfx_spriteamount[num] * sizeof(SPRITEHEADER));

    if (!gfx_spriteheaders[num])
    {
        bme_error = BME_OUT_OF_MEMORY;    
        io_close(handle);
        return BME_ERROR;
    }

    for (c = 0; c < gfx_spriteamount[num]; c++)
    {
        SPRITEHEADER *hptr = gfx_spriteheaders[num] + c;

        hptr->xsize = io_readle16(handle);
        hptr->ysize = io_readle16(handle);
        hptr->xhot = io_readle16(handle);
        hptr->yhot = io_readle16(handle);
        hptr->offset = io_readle32(handle);
    }

    datastart = io_lseek(handle, 0, SEEK_CUR);
    gfx_spritedata[num] = malloc(size - datastart);
    if (!gfx_spritedata[num])
    {
        bme_error = BME_OUT_OF_MEMORY;    
        io_close(handle);
        return BME_ERROR;
    }
    io_read(handle, gfx_spritedata[num], size - datastart);
    io_close(handle);
    bme_error = BME_OK;
    return BME_OK;
}

void gfx_freesprites(int num)
{
    if (num >= gfx_maxspritefiles) return;

    if (gfx_spritedata[num])
    {
        free(gfx_spritedata[num]);
        gfx_spritedata[num] = NULL;
    }
    if (gfx_spriteheaders[num])
    {
        free(gfx_spriteheaders[num]);
        gfx_spriteheaders[num] = NULL;
    }
}

void gfx_copyscreen8(Uint8  *destaddress, Uint8  *srcaddress, unsigned pitch)
{
    int c, d;

    switch(gfx_scanlinemode)
    {
        default:
        for (c = 0; c < gfx_virtualysize; c++)
        {
            memcpy(destaddress, srcaddress, gfx_virtualxsize);
            destaddress += pitch;
            srcaddress += gfx_virtualxsize;
        }
        break;

        case GFX_SCANLINES:
        for (c = 0; c < gfx_virtualysize; c++)
        {
            d = gfx_virtualxsize;
            while (d--)
            {
                *destaddress = *srcaddress;
                destaddress++;
                *destaddress = *srcaddress;
                destaddress++;
                srcaddress++;
            }
            destaddress += pitch*2 - (gfx_virtualxsize << 1);
        }
        break;

        case GFX_DOUBLESIZE:
        for (c = 0; c < gfx_virtualysize; c++)
        {
            d = gfx_virtualxsize;
            while (d--)
            {
                *destaddress = *srcaddress;
                destaddress++;
                *destaddress = *srcaddress;
                destaddress++;
                srcaddress++;
            }
            destaddress += pitch - (gfx_virtualxsize << 1);
            srcaddress -= gfx_virtualxsize;
            d = gfx_virtualxsize;
            while (d--)
            {
                *destaddress = *srcaddress;
                destaddress++;
                *destaddress = *srcaddress;
                destaddress++;
                srcaddress++;
            }
            destaddress += pitch - (gfx_virtualxsize << 1);
        }
        break;
    }
}

void gfx_plot(int x, int y, int color)
{
    if (!gfx_initted) return;
    if ((x < gfx_clipleft) || (x >= gfx_clipright)) return;
    if ((y < gfx_cliptop) || (y >= gfx_clipbottom)) return;

    gfx_vscreen[y * gfx_virtualxsize + x] = color;
}

void gfx_fillscreen(int color)
{
    if (!gfx_initted) return;
    memset(gfx_vscreen, color, gfx_virtualxsize*gfx_virtualysize);
}

void gfx_line(int x1, int y1, int x2, int y2, int color)
{
    int xslope = x2 - x1;
    int yslope = y2 - y1;
    int absxslope = abs(xslope);
    int absyslope = abs(yslope);
    int x, y;
    int c;

    if (!gfx_initted) return;
    if ((!absxslope) && (!absyslope))
    {
        gfx_plot(x1,y1,color);
        return;
    }

    if (absxslope > absyslope)
    {
        if (x1 < x2)
        {
            if (x1 < gfx_clipleft) x1 = gfx_clipleft;
            if (x2 >= gfx_clipright) x2 = gfx_clipright;
            if (x1 >= gfx_clipright) return;
            if (x2 < gfx_clipleft) return;

            if (yslope >= 0) c = absxslope / 2;
              else c = -absxslope / 2;

            for (x = x1; x <= x2; x++)
            {
                gfx_plot(x, y1 + c / absxslope, color);
                c += yslope;
            }
        }
        else
        {
            if (x2 < gfx_clipleft) x2 = gfx_clipleft;
            if (x1 >= gfx_clipright) x1 = gfx_clipright;
            if (x2 >= gfx_clipright) return;
            if (x1 < gfx_clipleft) return;

            if (yslope >= 0) c = absxslope / 2;
              else c = -absxslope / 2;

            for (x = x1; x >= x2; x--)
            {
                gfx_plot(x, y1 + c / absxslope, color);
                c += yslope;
            }
        }
    }
    else
    {
        if (y1 < y2)
        {
            if (y1 < gfx_cliptop) y1 = gfx_cliptop;
            if (y2 >= gfx_clipbottom) y2 = gfx_clipbottom;
            if (y1 >= gfx_clipbottom) return;
            if (y2 < gfx_cliptop) return;

            if (xslope >= 0) c = absyslope / 2;
              else c = -absyslope / 2;

            for (y = y1; y <= y2; y++)
            {
                gfx_plot(x1 + c / absyslope, y, color);
                c += xslope;
            }
        }
        else
        {
            if (y2 < gfx_cliptop) y2 = gfx_cliptop;
            if (y1 >= gfx_clipbottom) y1 = gfx_clipbottom;
            if (y2 >= gfx_clipbottom) return;
            if (y1 < gfx_cliptop) return;

            if (xslope >= 0) c = absyslope / 2;
              else c = -absyslope / 2;

            for (y = y1; y >= y2; y--)
            {
                gfx_plot(x1 + c / absyslope, y, color);
                c += xslope;
            }
        }
    }
}

void gfx_getspriteinfo(unsigned num)
{
    unsigned sprf = num >> 16;
    unsigned spr = (num & 0xffff) - 1;
    SPRITEHEADER *hptr;

    if ((sprf >= gfx_maxspritefiles) || (!gfx_spriteheaders[sprf]) ||
        (spr >= gfx_spriteamount[sprf])) hptr = NULL;
    else hptr = gfx_spriteheaders[sprf] + spr;

    if (!hptr)
    {
        spr_xsize = 0;
        spr_ysize = 0;
        spr_xhotspot = 0;
        spr_yhotspot = 0;
        return;
    }

    spr_xsize = hptr->xsize;
    spr_ysize = hptr->ysize;
    spr_xhotspot = hptr->xhot;
    spr_yhotspot = hptr->yhot;
}

void gfx_drawsprite(int x, int y, unsigned num)
{
    unsigned sprf = num >> 16;
    unsigned spr = (num & 0xffff) - 1;
    SPRITEHEADER *hptr;

    Uint8 *sptr;
    Uint8 *dptr;
    int cx;

    if ((sprf >= gfx_maxspritefiles) || (!gfx_spriteheaders[sprf]) ||
        (spr >= gfx_spriteamount[sprf]))
    {
        spr_xsize = 0;
        spr_ysize = 0;
        spr_xhotspot = 0;
        spr_yhotspot = 0;
        return;
    }
    else hptr = gfx_spriteheaders[sprf] + spr;

    sptr = gfx_spritedata[sprf] + hptr->offset;
    spr_xsize = hptr->xsize;
    spr_ysize = hptr->ysize;
    spr_xhotspot = hptr->xhot;
    spr_yhotspot = hptr->yhot;

    x -= spr_xhotspot;
    y -= spr_yhotspot;

    if (x >= gfx_clipright) return;
    if (y >= gfx_clipbottom) return;
    if (x + spr_xsize <= gfx_clipleft) return;
    if (y + spr_ysize <= gfx_cliptop) return;

    while (y < gfx_cliptop)
    {
        int dec = *sptr++;
        if (dec == 255)
        {
            if (!(*sptr)) return;
            y++;
        }
        else
        {
            if (dec < 128)
            {
                sptr += dec;
            }
        }
    }
    while (y < gfx_clipbottom)
    {
        int dec;
        cx = x;
        dptr = &gfx_vscreen[y * gfx_virtualxsize + x];

        for (;;)
        {
            dec = *sptr++;

            if (dec == 255)
            {
                if (!(*sptr)) return;
                y++;
                break;
            }
            if (dec < 128)
            {
                if ((cx + dec <= gfx_clipleft) || (cx >= gfx_clipright))
                {
                    goto SKIP;
                }
                if (cx < gfx_clipleft)
                {
                    dec -= (gfx_clipleft - cx);
                    sptr += (gfx_clipleft - cx);
                    dptr += (gfx_clipleft - cx);
                    cx = gfx_clipleft;
                }
                while ((cx < gfx_clipright) && (dec))
                {
                    *dptr = *sptr;
                    cx++;
                    sptr++;
                    dptr++;
                    dec--;
                }
                SKIP:
                cx += dec;
                sptr += dec;
                dptr += dec;
            }
            else
            {
                cx += (dec & 0x7f);
                dptr += (dec & 0x7f);
            }
        }
    }
}

void gfx_drawspritec(int x, int y, unsigned num, int color)
{
    unsigned sprf = num >> 16;
    unsigned spr = (num & 0xffff) - 1;
    SPRITEHEADER *hptr;

    Uint8 *sptr;
    Uint8 *dptr;
    int cx;

    if ((sprf >= gfx_maxspritefiles) || (!gfx_spriteheaders[sprf]) || 
        (spr >= gfx_spriteamount[sprf]))
    {
        spr_xsize = 0;
        spr_ysize = 0;
        spr_xhotspot = 0;
        spr_yhotspot = 0;
        return;
    }
    else hptr = gfx_spriteheaders[sprf] + spr;

    sptr = gfx_spritedata[sprf] + hptr->offset;
    spr_xsize = hptr->xsize;
    spr_ysize = hptr->ysize;
    spr_xhotspot = hptr->xhot;
    spr_yhotspot = hptr->yhot;

    x -= spr_xhotspot;
    y -= spr_yhotspot;

    if (x >= gfx_clipright) return;
    if (y >= gfx_clipbottom) return;
    if (x + spr_xsize <= gfx_clipleft) return;
    if (y + spr_ysize <= gfx_cliptop) return;

    while (y < gfx_cliptop)
    {
        int dec = *sptr++;
        if (dec == 255)
        {
            if (!(*sptr)) return;
            y++;
        }
        else
        {
            if (dec < 128)
            {
                sptr += dec;
            }
        }
    }
    while (y < gfx_clipbottom)
    {
        int dec;
        cx = x;
        dptr = &gfx_vscreen[y * gfx_virtualxsize + x];

        for (;;)
        {
            dec = *sptr++;

            if (dec == 255)
            {
                if (!(*sptr)) return;
                y++;
                break;
            }
            if (dec < 128)
            {
                if ((cx + dec <= gfx_clipleft) || (cx >= gfx_clipright))
                {
                    goto SKIP;
                }
                if (cx < gfx_clipleft)
                {
                    dec -= (gfx_clipleft - cx);
                    sptr += (gfx_clipleft - cx);
                    dptr += (gfx_clipleft - cx);
                    cx = gfx_clipleft;
                }
                while ((cx < gfx_clipright) && (dec))
                {
                    *dptr = color;
                    cx++;
                    sptr++;
                    dptr++;
                    dec--;
                }
                SKIP:
                cx += dec;
                sptr += dec;
                dptr += dec;
            }
            else
            {
                cx += (dec & 0x7f);
                dptr += (dec & 0x7f);
            }
        }
    }
}


void gfx_drawspritex(int x, int y, unsigned num, Uint8  *xlattable)
{
    unsigned sprf = num >> 16;
    unsigned spr = (num & 0xffff) - 1;
    SPRITEHEADER *hptr;

    Uint8 *sptr;
    Uint8 *dptr;
    int cx;

    if ((sprf >= gfx_maxspritefiles) || (!gfx_spriteheaders[sprf]) || 
        (spr >= gfx_spriteamount[sprf]))
    {
        spr_xsize = 0;
        spr_ysize = 0;
        spr_xhotspot = 0;
        spr_yhotspot = 0;
        return;
    }
    else hptr = gfx_spriteheaders[sprf] + spr;

    sptr = gfx_spritedata[sprf] + hptr->offset;
    spr_xsize = hptr->xsize;
    spr_ysize = hptr->ysize;
    spr_xhotspot = hptr->xhot;
    spr_yhotspot = hptr->yhot;

    x -= spr_xhotspot;
    y -= spr_yhotspot;

    if (x >= gfx_clipright) return;
    if (y >= gfx_clipbottom) return;
    if (x + spr_xsize <= gfx_clipleft) return;
    if (y + spr_ysize <= gfx_cliptop) return;

    while (y < gfx_cliptop)
    {
        int dec = *sptr++;
        if (dec == 255)
        {
            if (!(*sptr)) return;
            y++;
        }
        else
        {
            if (dec < 128)
            {
                sptr += dec;
            }
        }
    }
    while (y < gfx_clipbottom)
    {
        int dec;
        cx = x;
        dptr = &gfx_vscreen[y * gfx_virtualxsize + x];

        for (;;)
        {
            dec = *sptr++;

            if (dec == 255)
            {
                if (!(*sptr)) return;
                y++;
                break;
            }
            if (dec < 128)
            {
                if ((cx + dec <= gfx_clipleft) || (cx >= gfx_clipright))
                {
                    goto SKIP;
                }
                if (cx < gfx_clipleft)
                {
                    dec -= (gfx_clipleft - cx);
                    sptr += (gfx_clipleft - cx);
                    dptr += (gfx_clipleft - cx);
                    cx = gfx_clipleft;
                }
                while ((cx < gfx_clipright) && (dec))
                {
                    *dptr = xlattable[*sptr];
                    cx++;
                    sptr++;
                    dptr++;
                    dec--;
                }
                SKIP:
                cx += dec;
                sptr += dec;
                dptr += dec;
            }
            else
            {
                cx += (dec & 0x7f);
                dptr += (dec & 0x7f);
            }
        }
    }
}

void gfx_drawblock(int x, int y, unsigned num)
{
    BLOCKHEADER *hptr = gfx_blockheaders;
    Uint8 *sptr;
    Uint8 *dptr;
    int cx;

    if (!gfx_initted) return;
    if (!num) return;
    num--;
    if (num >= gfx_nblocks) return;
    hptr += num;
    sptr = gfx_blocks + hptr->offset;

    if (x >= gfx_clipright) return;
    if (y >= gfx_clipbottom) return;
    if (x + gfx_blockxsize <= gfx_clipleft) return;
    if (y + gfx_blockysize <= gfx_cliptop) return;

    if (hptr->type) /* We're Solid */
    {
        int modulo;
        int length = gfx_blockxsize;
        int endy = y + gfx_blockysize;

        if (x < gfx_clipleft)
        {
            sptr += gfx_clipleft - x;
            length -= gfx_clipleft - x;
            x = gfx_clipleft;
        }
        if (y < gfx_cliptop)
        {
            sptr += (gfx_cliptop - y) * gfx_blockxsize;
            y = gfx_cliptop;
        }
        if (x + length > gfx_clipright)
        {
            length -= (x + length - gfx_clipright);
        }
        if (endy > gfx_clipbottom) endy = gfx_clipbottom;
        modulo = gfx_blockxsize - length;

        while (y < endy)
        {
            cx = length;
            dptr = &gfx_vscreen[y * gfx_virtualxsize + x];
            while (cx--)
            {
                *dptr++ = *sptr++;
            }
            sptr += modulo;
            y++;
        }
    }
    else
    {
        while (y < gfx_cliptop)
        {
            int dec = *sptr++;
            if (dec == 255)
            {
                if (!(*sptr)) return;
                y++;
            }
            else
            {
                if (dec < 128) sptr += dec;
            }
        }
        while (y < gfx_clipbottom)
        {
            int dec;
            cx = x;
            dptr = &gfx_vscreen[y * gfx_virtualxsize + x];

            for (;;)
            {
                dec = *sptr++;

                if (dec == 255)
                {
                    if (!(*sptr)) return;
                    y++;
                    break;
                }
                if (dec < 128)
                {
                    if ((cx + dec <= gfx_clipleft) || (cx >= gfx_clipright))
                    {
                        goto SKIP;
                    }
                    if (cx < gfx_clipleft)
                    {
                        dec -= (gfx_clipleft - cx);
                        sptr += (gfx_clipleft - cx);
                        dptr += (gfx_clipleft - cx);
                        cx = gfx_clipleft;
                    }
                    while ((cx < gfx_clipright) && (dec))
                    {
                        *dptr++ = *sptr++;
                        cx++;
                        dec--;
                    }
                    SKIP:
                    cx += dec;
                    sptr += dec;
                    dptr += dec;
                }
                else
                {
                    cx += (dec & 0x7f);
                    dptr += (dec & 0x7f);
                }
            }
        }
    }
}




