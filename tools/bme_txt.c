//
// BME (Blasphemous Multimedia Engine) text printing module
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <SDL/SDL.h>
#include "bme_main.h"
#include "bme_gfx.h"
#include "bme_err.h"
#include "bme_cfg.h"

int txt_lastx, txt_lasty;
int txt_spacing = -1;

// Prototypes

void txt_print(int x, int y, unsigned spritefile, char *string);
void txt_printcenter(int y, unsigned spritefile, char *string);
void txt_printx(int x, int y, unsigned spritefile, char *string, unsigned char *xlattable);
void txt_printcenterx(int y, unsigned spritefile, char *string, unsigned char *xlattable);

void txt_print(int x, int y, unsigned spritefile, char *string)
{
    spritefile <<= 16;
    while (*string)
    {
        unsigned num = *string;
        if (num >= 96) num -= 96; // Lowercase ASCII
        if (num >= 64) num -= 64; // Uppercase ASCII

        gfx_drawsprite(x, y, spritefile + num + 1);
        x += spr_xsize + txt_spacing;
        string++;
    }
    txt_lastx = x;
    txt_lasty = y;
}

void txt_printcenter(int y, unsigned spritefile, char *string)
{
    int x = 0;
    char *cstring = string;
    spritefile <<= 16;

    while (*cstring)
    {
        unsigned num = *cstring;
        if (num >= 96) num -= 96; // Lowercase ASCII
        if (num >= 64) num -= 64; // Uppercase ASCII

        gfx_getspriteinfo(spritefile + num + 1);
        x += spr_xsize + txt_spacing;
        cstring++;
    }
    x = 160 - x / 2;

    while (*string)
    {
        unsigned num = *string;
        if (num >= 96) num -= 96; // Lowercase ASCII
        if (num >= 64) num -= 64; // Uppercase ASCII

        gfx_drawsprite(x, y, spritefile + num + 1);
        x += spr_xsize + txt_spacing;
        string++;
    }
    txt_lastx = x;
    txt_lasty = y;
}

void txt_printx(int x, int y, unsigned spritefile, char *string, unsigned char *xlattable)
{
    spritefile <<= 16;
    while (*string)
    {
        unsigned num = *string;
        if (num >= 96) num -= 96; // Lowercase ASCII
        if (num >= 64) num -= 64; // Uppercase ASCII

        gfx_drawspritex(x, y, spritefile + num + 1, xlattable);
        x += spr_xsize + txt_spacing;
        string++;
    }
    txt_lastx = x;
    txt_lasty = y;
}

void txt_printcenterx(int y, unsigned spritefile, char *string, unsigned char *xlattable)
{
    int x = 0;
    char *cstring = string;
    spritefile <<= 16;

    while (*cstring)
    {
        unsigned num = *cstring;
        if (num >= 96) num -= 96; // Lowercase ASCII
        if (num >= 64) num -= 64; // Uppercase ASCII

        gfx_getspriteinfo(spritefile + num + 1);
        x += spr_xsize + txt_spacing;
        cstring++;
    }
    x = 160 - x / 2;

    while (*string)
    {
        unsigned num = *string;
        if (num >= 96) num -= 96; // Lowercase ASCII
        if (num >= 64) num -= 64; // Uppercase ASCII

        gfx_drawspritex(x, y, spritefile + num + 1, xlattable);
        x += spr_xsize + txt_spacing;
        string++;
    }
    txt_lastx = x;
    txt_lasty = y;
}
