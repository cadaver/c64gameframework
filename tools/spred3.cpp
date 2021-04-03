/*
 * C64gameframework multisprite editor
 */

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <ctype.h>
#include <string.h>
#include <vector>

#include "fileio.h"

#include "bme.h"

#define LEFT_BUTTON 1
#define RIGHT_BUTTON 2
#define SINGLECOLOR 0
#define MULTICOLOR 1

#define SPR_C 0
#define SPR_FONTS 1

#define COL_WHITE 0
#define COL_HIGHLIGHT 1

#define COLOR_DELAY 10

#define TESTSPR_X 200
#define TESTSPR_Y 48
#define MAXSPR 128
#define MAXTESTSPR 32
#define MAXSIZEX 12*8
#define MAXSIZEY 21*6
#define VIEWSIZEX 12*3
#define VIEWSIZEY 21*3

#define FLAG_STOREFLIPPED 1
#define FLAG_NOCONNECT 2
#define COLOR_EXPANDX 0x10

#define MAX_UNDOSTEPS 128

#define BOUNDS_ADJUST 0x40

typedef struct
{
  unsigned char slicemask;
  unsigned char color;
  signed char hotspotx;
  signed char fliphotspotx;
  signed char connectspotx;
  signed char flipconnectspotx;
  signed char hotspoty;
  signed char connectspoty;
  unsigned char cacheframe;
  unsigned char flipcacheframe;
} SPRHEADER;

typedef struct
{
  unsigned char slicemask;
  unsigned char color;
  signed char hotspotx;
  signed char connectspotx;
  signed char hotspoty;
  signed char connectspoty;
  unsigned char cacheframe;
} OLDSPRHEADER;

typedef struct
{
  short slicemask;
  signed char hotspotx;
  signed char reversehotspotx;
  signed char hotspoty;
  signed char connectspotx;
  signed char reverseconnectspotx;
  signed char connectspoty;
} OLDSPRHEADER2;

struct BoundingBox
{
    int x;
    int y;
    int sx;
    int sy;
    int flags;
};

struct PhysicalSprite
{
    int x;
    int y;
    int color;
};

struct PhysicalSpriteData
{
    unsigned slicemask;
    int color;
    unsigned char pixels[12*21];
    std::vector<unsigned char> slicedata;
};

struct Sprite
{
    int sx;
    int sy;
    int color;
    int hotspotx;
    int hotspoty;
    int connectspotx;
    int connectspoty;
    int flags;
    std::vector<BoundingBox> bboxes;
    std::vector<PhysicalSprite> physsprites;
    unsigned char pixels[MAXSIZEX*MAXSIZEY];
    PhysicalSpriteData simpledata;

    bool iscomplex() const
    {
      bool usesexpand = false;
      for (int i = 0; i < physsprites.size(); ++i)
      {
        if (physsprites[i].color & COLOR_EXPANDX)
        {
          usesexpand = true;
          break;
        }
      }
      return usesexpand || bboxes.size() > 1 || physsprites.size() != 1;
    }

    int datasize() const
    {
      int ret = 0;
      if (!iscomplex())
      {
        ret += 3; // Cacheframes + color
        ret++; // Flags
        if (!(flags & FLAG_NOCONNECT))
          ret += 3; // Connect info
        if (bboxes.size() >= 1)
          ret += 4; // Bounds
        if (physsprites.size() >= 1)
        {
          ret += 3; // Hotspots
          ret += 2; // Slicemask
          ret += simpledata.slicedata.size();
        }
      }
      else
      {
        ret += 3; // Connect info, stored in any case
        ret++; //Flags
        ret += bboxes.size()*4+1; // Bounds data
        ret += physsprites.size()*4+1; // Physsprite data
      }

      return ret;
    }
};

struct TestSprite
{
    int x;
    int y;
    int f;
};

int sliceoffset[] = {0,1,2,21,22,23,42,43,44};

unsigned char cwhite[] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35};
unsigned char chl[] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,35,35};
unsigned char *colxlattable[] = {cwhite, chl};
char textbuffer[80];
char ib1[80];
int k,l;
unsigned char ascii;
int colordelay = 0;

unsigned mousex = 160;
unsigned mousey = 100;

int screensizex = VIEWSIZEX*10+8+9*24;
int screensizey = 384;

int colorx = 256;
int cbarx = 256+90;
int colory = VIEWSIZEY*5+8;

int mouseb;
int prevmouseb = 0;
unsigned char ccolor = 2;
int testspr = 0;
int sprnum = 0;
int hotspotflash = 0;
int shiftdown = 0;
int ctrldown = 0;
int viewx = 0;
int viewy = 0;
int markstate = 0;
int markx1, markx2, marky1, marky2;
int linex1, liney1;
int linemode = 0;
int newbbx1 = -1, newbbx2 = -1, newbby1 = -1, newbby2 = -1;
int bboxerased = 0;
int datasize = 0;
std::vector<PhysicalSpriteData> allphyssprites;
std::vector<PhysicalSpriteData> complexphyssprites;

Sprite sprites[MAXSPR];
TestSprite testsprites[MAXTESTSPR];
Sprite brush;

unsigned char bgcol = 0;
unsigned char multicol1 = 15;
unsigned char multicol2 = 11;

Sprite copysprite;
std::vector<Sprite> undostack[MAXSPR];

void handle_int(int a);
void mainloop();
void mouseupdate();
int initsprites();
void drawgrid();
void clearspr();
int confirmquit();
void loadspr();
void loadnewslicespr(void);
void loadoldslicespr(void);
void savespr();
void flipsprx();
void flipspry();
void editspr();
void scrollsprleft();
void scrollsprright();
void scrollsprup();
void scrollsprdown();
void swapsprcolors(int col1, int col2);
void changecol();
void initstuff();
void makeundo();
void applyundo();
void buildphyssprites(int firstframe, int frames);
void floodfill(int x, int y, int col);
void floodfillinternal(int x, int y, int col, int sc);
void drawbrush(int x, int y);
void erasebrush(int x, int y);
void validatespr(Sprite& spr);
void drawc64sprite(const Sprite& spr, int bx, int by);
bool isinside(const PhysicalSprite& pspr, int x, int y);
bool isinside(const BoundingBox& bbox, int x, int y);
int getexistingphysspr(const Sprite& spr, const PhysicalSprite& pspr);
int getspritecolor(const Sprite& spr, int x, int y);
void drawline(int x1, int y1, int x2, int y2, int col);
void drawcbar(int x, int y, unsigned char col);
void drawbox(int x, int y, int sx, int sy, unsigned char col);
void drawfilledbox(int x, int y, int sx, int sy, unsigned char col);
void drawboxcorners(int x1, int y1, int x2, int y2, unsigned char col);
unsigned getcharsprite(unsigned char ch);
void printtext_color(char *string, int x, int y, unsigned spritefile, int color);
void printtext_center_color(char *string, int y, unsigned spritefile, int color);
int inputtext(char *buffer, int maxlength);

extern unsigned char datafile[];

int main (int argc, char *argv[])
{
  FILE *handle;

  io_openlinkeddatafile(datafile);

  ib1[0] = 0; /* Initial filename=empty */
  if (!win_openwindow("Multi-sprite editor", NULL)) return 1;

  handle = fopen("spredit.cfg", "rb");
  if (handle)
  {
    bgcol = fread8(handle);
    multicol1 = fread8(handle);
    multicol2 = fread8(handle);
    fclose(handle);
  }

  initstuff();
  gfx_calcpalette(63,0,0,0);
  gfx_setpalette();
  mainloop();

  handle = fopen("spredit.cfg", "wb");
  if (handle)
  {
    fwrite8(handle, bgcol);
    fwrite8(handle, multicol1);
    fwrite8(handle, multicol2);
    fclose(handle);
  }
  return 0;
}

void mainloop()
{
  for (;;)
  {
    win_getspeed(70);
    for (k = 0; k < MAX_KEYS; k++)
    {
      shiftdown = win_keystate[KEY_LEFTSHIFT] | win_keystate[KEY_RIGHTSHIFT];
      ctrldown = win_keystate[KEY_CTRL];

      if (win_keytable[k])
      {
        if ((k != KEY_LEFTSHIFT) && (k != KEY_RIGHTSHIFT))
        {
          win_keytable[k] = 0;
          break;
        }
      }
    }
    if (k == 256) k = 0;
    ascii = kbd_getascii();
    if (ascii == 27)
    {
        if (confirmquit()) break;
    }
    
    buildphyssprites(0,MAXSPR);

    Sprite& spr = sprites[sprnum];

    if (k == KEY_X && shiftdown)
        spr.flags ^= FLAG_STOREFLIPPED;
    if (k == KEY_J && shiftdown)
    {
      spr.flags ^= FLAG_NOCONNECT;
    }

    if (k == KEY_C && shiftdown)
        clearspr();
    if (k == KEY_V)
      swapsprcolors(1,2);
    if (k == KEY_B)
      swapsprcolors(1,3);
    if (k == KEY_N)
      swapsprcolors(2,3);

    if (k == KEY_DEL)
    {
      int c;
      for (c = sprnum+1; c < MAXSPR; c++)
      {
        sprites[c-1] = sprites[c];
      }
    }
    if (k == KEY_INS)
    {
      int c;
      for (c = MAXSPR-2; c >= sprnum; c--)
      {
        sprites[c+1] = sprites[c];
      }
    }

    if ((k == KEY_COMMA) && (sprnum > 0))
    {
        sprnum--;
        markstate = 0;
    }
    if ((k == KEY_COLON) && (sprnum < MAXSPR-1))
    {
        sprnum++;
        markstate = 0;
    }
    // Select current color by keys
    if (shiftdown && !ctrldown)
    {
      if (k == KEY_1)
        ccolor = 0;
      if (k == KEY_2)
        ccolor = 1;
      if (k == KEY_3)
        ccolor = 2;
      if (k == KEY_4)
        ccolor = 3;
    }

    if (shiftdown)
    {
      if (k == KEY_LEFT)
        scrollsprleft();
      if (k == KEY_RIGHT)
        scrollsprright();
      if (k == KEY_UP)
        scrollsprup();
      if (k == KEY_DOWN)
        scrollsprdown();
    }
    else if (ctrldown)
    {
      if (k == KEY_LEFT && spr.sx > 12)
      {
        spr.sx -= 12;
        validatespr(spr);
      }
      if (k == KEY_RIGHT && spr.sx < MAXSIZEX)
      {
        spr.sx += 12;
        validatespr(spr);
      }
      if (k == KEY_UP && spr.sy > 21)
      {
        spr.sy -= 21;
        validatespr(spr);
      }
      if (k == KEY_DOWN && spr.sy < MAXSIZEY)
      {
        spr.sy += 21;
        validatespr(spr);
      }
    }
    else
    {
      if (k == KEY_LEFT) viewx -= 4;
      if (k == KEY_RIGHT) viewx += 4;
      if (k == KEY_UP) viewy -= 7;
      if (k == KEY_DOWN) viewy += 7;
    }

    if (viewx+VIEWSIZEX > spr.sx) viewx = spr.sx-VIEWSIZEX;
    if (viewy+VIEWSIZEY > spr.sy) viewy = spr.sy-VIEWSIZEY;
    if (viewx < 0) viewx = 0;
    if (viewy < 0) viewy = 0;

    if (k == KEY_X && !shiftdown) flipsprx();
    if (k == KEY_Y && !shiftdown) flipspry();
    if (k == KEY_P && shiftdown)
    {
      copysprite = spr;
    }
    if (k == KEY_T && shiftdown)
    {
      if (copysprite.sx && copysprite.sy)
      {
        makeundo();
        spr = copysprite;
      }
    }
    if (k == KEY_U)
    {
      applyundo();
    }

    if (k == KEY_F1) loadspr();
    if (k == KEY_F2) savespr();
    if (k == KEY_F3) loadnewslicespr();
    if (k == KEY_F4) loadoldslicespr();
    if (!shiftdown)
    {
      if ((k == KEY_2) && (testspr < MAXTESTSPR-1))
        testspr++;
      if ((k == KEY_1) && (testspr > 0))
        testspr--;
    }
    TestSprite& tsp = testsprites[testspr];
    if (!shiftdown)
    {
      if (k == KEY_3) tsp.x -= 1;
      if (k == KEY_4) tsp.x += 1;
      if (k == KEY_5) tsp.y -= 1;
      if (k == KEY_6) tsp.y += 1;
      if (k == KEY_7)
      {
          tsp.f -= 1;
          tsp.f &= (MAXSPR-1);
      }
      if (k == KEY_8)
      {
          tsp.f += 1;
          tsp.f &= (MAXSPR-1);
      }
    }

    mouseupdate();
    gfx_fillscreen(254);
    drawgrid();
    editspr();
    changecol();

    {
      int cx = 0;
      int cy = 0;
      for (int l = 0; l < MAXTESTSPR; l++)
      {
        const TestSprite& dtsp = testsprites[l];
        cx += dtsp.x;
        cy += dtsp.y;
        if (dtsp.f != MAXSPR-1)
        {
          const Sprite& sp = sprites[dtsp.f];
          drawc64sprite(sp, cx-sp.hotspotx*2, cy-sp.hotspoty);
          cx += (sp.connectspotx-sp.hotspotx)*2;
          cy += (sp.connectspoty-sp.hotspoty);
        }
        else break;
      }
    }

    sprintf(textbuffer, "TESTSPR %03d", testspr);
    printtext_color(textbuffer, 0,VIEWSIZEY*5+8+20,SPR_FONTS,COL_WHITE);
    sprintf(textbuffer, "X-POS %03d", tsp.x);
    printtext_color(textbuffer, 0,VIEWSIZEY*5+8+30,SPR_FONTS,COL_WHITE);
    sprintf(textbuffer, "Y-POS %03d", tsp.y);
    printtext_color(textbuffer, 0,VIEWSIZEY*5+8+40,SPR_FONTS,COL_WHITE);
    sprintf(textbuffer, "FRAME %03d", tsp.f);
    printtext_color(textbuffer, 0,VIEWSIZEY*5+8+50,SPR_FONTS,COL_WHITE);

    sprintf(textbuffer, "SPRITE %03d %dx%d PHYS %d BBOX %d", sprnum, spr.sx/12, spr.sy/21, spr.physsprites.size(), spr.bboxes.size());
    printtext_color(textbuffer, 0,VIEWSIZEY*5+8,SPR_FONTS,COL_WHITE);
    sprintf(textbuffer, "%s%s", (spr.flags & FLAG_STOREFLIPPED) ? "FLIPPED " : "", (spr.flags & FLAG_NOCONNECT) ? "NOCONNECT " : "");
    printtext_color(textbuffer, 0,VIEWSIZEY*5+8+10,SPR_FONTS,COL_WHITE);

    int v = COL_WHITE;
    if (ccolor == 0) v = COL_HIGHLIGHT;
    printtext_color("BACKGROUND",colorx,colory,SPR_FONTS,v);
    v = COL_WHITE;
    if (ccolor == 1) v = COL_HIGHLIGHT;
    printtext_color("MULTICOL 1",colorx,colory+15,SPR_FONTS,v);
    v = COL_WHITE;
    if (ccolor == 2) v = COL_HIGHLIGHT;
    printtext_color("SPRITE COL",colorx,colory+30,SPR_FONTS,v&15);
    v = COL_WHITE;
    if (ccolor == 3) v = COL_HIGHLIGHT;
    printtext_color("MULTICOL 2",colorx,colory+45,SPR_FONTS,v);
    drawcbar(cbarx,colory,bgcol);
    drawcbar(cbarx,colory+15,multicol1);
    drawcbar(cbarx,colory+30,(spr.color&15));
    drawcbar(cbarx,colory+45,multicol2);

    sprintf(textbuffer, "UNIQ.PHYSSPR %d", allphyssprites.size());
    printtext_color(textbuffer,colorx+120,colory,SPR_FONTS,COL_WHITE);
    sprintf(textbuffer, "DATA SIZE %d", datasize);
    printtext_color(textbuffer,colorx+120,colory+15,SPR_FONTS,COL_WHITE);

    gfx_drawsprite(mousex, mousey, 0x00000021);
    gfx_updatepage();
  }
}

void clearspr()
{
  makeundo();
  Sprite& sp = sprites[sprnum];
  memset(sp.pixels, 0, sizeof sp.pixels);
  sp.bboxes.clear();
  sp.physsprites.clear();
}

int confirmquit()
{
    for (;;)
    {
        int k;
        win_getspeed(70);
        gfx_fillscreen(254);
        printtext_center_color("PRESS Y TO CONFIRM QUIT",screensizey/2-10,SPR_FONTS,COL_WHITE);
        printtext_center_color("UNSAVED DATA WILL BE LOST",screensizey/2,SPR_FONTS,COL_WHITE);
        gfx_updatepage();
        k = kbd_getascii();
        if (k)
        {
            if (k == 'y') return 1;
            else return 0;
        }
    }
}

void loadspr()
{
  char ib2[5];
  int phase = 1;
  ib2[0] = 0;

  for (;;)
  {
    win_getspeed(70);
    gfx_fillscreen(254);
    printtext_center_color("LOAD SPRITEFILE:",screensizey/2-30,SPR_FONTS,COL_WHITE);
    printtext_center_color(ib1,screensizey/2-20,SPR_FONTS,COL_HIGHLIGHT);
    if (phase > 1)
    {
      printtext_center_color("LOAD AT SPRITENUM:",screensizey/2-5,SPR_FONTS,COL_WHITE);
      printtext_center_color(ib2,screensizey/2+5,SPR_FONTS,COL_HIGHLIGHT);
    }
    gfx_updatepage();
    if (phase == 1)
    {
      int r = inputtext(ib1, 80);
      if (r == -1) return;
      if (r == 1) phase = 2;
    }
    if (phase == 2)
    {
      int r = inputtext(ib2, 5);
      if (r == -1) return;
      if (r == 1)
      {
        int frameindex = 0;
        int length;
        int frame;
        FILE *handle;
        sscanf(ib2, "%d", &frame);
        if (frame < 0) frame = 0;
        if (frame > MAXSPR-1) frame = MAXSPR-1;
        handle = fopen(ib1, "rb");
        if (!handle) return;
        fseek(handle, 0, SEEK_END);
        length = ftell(handle);
        fseek(handle, 0, SEEK_SET);
        int frames = freadle32(handle);
        int endframe = frame+frames;
        
        // Prevent crash from loading wrong format
        if (frames >= 256)
        {
            fclose(handle);
            return;
        }

        for (;;)
        {
            if (ftell(handle) >= length || frame >= MAXSPR || frame >= endframe)
                break;
            Sprite& spr = sprites[frame];
            undostack[frame].clear();
            spr.sx = freadle32(handle);
            spr.sy = freadle32(handle);
            spr.color = freadle32(handle);
            spr.hotspotx = freadle32(handle);
            spr.hotspoty = freadle32(handle);
            spr.connectspotx = freadle32(handle);
            spr.connectspoty = freadle32(handle);
            spr.flags = freadle32(handle);
            int numbbox = freadle32(handle);
            spr.bboxes.clear();
            for (int c = 0; c < numbbox; ++c)
            {
                BoundingBox bbox;
                bbox.x = freadle32(handle);
                bbox.y = freadle32(handle);
                bbox.sx = freadle32(handle);
                bbox.sy = freadle32(handle);
                bbox.flags = freadle32(handle);
                spr.bboxes.push_back(bbox);
            }
            int numphysspr = freadle32(handle);
            spr.physsprites.clear();
            for (int c = 0; c < numphysspr; ++c)
            {
                PhysicalSprite pspr;
                pspr.x = freadle32(handle);
                pspr.y = freadle32(handle);
                pspr.color = freadle32(handle);
                spr.physsprites.push_back(pspr);
            }
            memset(spr.pixels, 0, sizeof spr.pixels);
            for (int y = 0; y < spr.sy; ++y)
            {
                fread(&spr.pixels[y*MAXSIZEX], spr.sx, 1, handle);
            }
            ++frame;
        }

        fclose(handle);
        return;
      }
    }
  }
}

void savespr()
{
  char ib2[5];
  char ib3[5];
  char ib4[256];
  int phase = 1;
  ib2[0] = 0;
  ib3[0] = 0;

  for (;;)
  {
    win_getspeed(70);
    gfx_fillscreen(254);
    printtext_center_color("SAVE SPRITEFILE:",screensizey/2-40,SPR_FONTS,COL_WHITE);
    printtext_center_color(ib1,screensizey/2-30,SPR_FONTS,COL_HIGHLIGHT);
    if (phase > 1)
    {
      printtext_center_color("SAVE FROM SPRITENUM:",screensizey/2-15,SPR_FONTS,COL_WHITE);
      printtext_center_color(ib2,screensizey/2-5,SPR_FONTS,COL_HIGHLIGHT);
    }
    if (phase > 2)
    {
      printtext_center_color("SAVE HOW MANY:",screensizey/2+10,SPR_FONTS,COL_WHITE);
      printtext_center_color(ib3,screensizey/2+20,SPR_FONTS,COL_HIGHLIGHT);
    }
    gfx_updatepage();
    if (phase == 1)
    {
      int r = inputtext(ib1, 80);
      if (r == -1) return;
      if (r == 1) phase = 2;
    }
    if (phase == 2)
    {
      int r = inputtext(ib2, 5);
      if (r == -1) return;
      if (r == 1) phase = 3;
    }
    if (phase == 3)
    {
      int r = inputtext(ib3, 5);
      if (r == -1) return;
      if (r == 1)
      {
        int c;
        int datasize = 0;
        int frame, frames;
        FILE *handle;
        sscanf(ib2, "%d", &frame);
        sscanf(ib3, "%d", &frames);
        if (frame < 0) frame = 0;
        if (frame > MAXSPR-1) frame = MAXSPR-1;
        if (frames < 1) frames = 1;
        if (frame+frames > MAXSPR) frames = MAXSPR-frame;

        handle = fopen(ib1, "wb");
        if (!handle) return;
        
        sprintf(ib4, "%s.res", ib1);
        FILE* c64handle = fopen(ib4, "wb");

        fwritele32(handle, frames);
        int endframe = frame+frames;
        for (int f = frame; f < endframe; ++f)
        {
            Sprite& spr = sprites[f];
            fwritele32(handle, spr.sx);
            fwritele32(handle, spr.sy);
            fwritele32(handle, spr.color);
            fwritele32(handle, spr.hotspotx);
            fwritele32(handle, spr.hotspoty);
            fwritele32(handle, spr.connectspotx);
            fwritele32(handle, spr.connectspoty);
            fwritele32(handle, spr.flags);
            fwritele32(handle, spr.bboxes.size());
            for (int c = 0; c < spr.bboxes.size(); ++c)
            {
                fwritele32(handle, spr.bboxes[c].x);
                fwritele32(handle, spr.bboxes[c].y);
                fwritele32(handle, spr.bboxes[c].sx);
                fwritele32(handle, spr.bboxes[c].sy);
                fwritele32(handle, spr.bboxes[c].flags);
            }
            fwritele32(handle, spr.physsprites.size());
            for (int c = 0; c < spr.physsprites.size(); ++c)
            {
                fwritele32(handle, spr.physsprites[c].x);
                fwritele32(handle, spr.physsprites[c].y);
                fwritele32(handle, spr.physsprites[c].color);
            }
            for (int y = 0; y < spr.sy; ++y)
            {
                fwrite(&spr.pixels[y*MAXSIZEX], spr.sx, 1, handle);
            }
        }

        // Save C64 resource data
        if (c64handle)
        {
            buildphyssprites(frame, frames);

            std::vector<unsigned> offsets;
            unsigned datasize = frames*2 + complexphyssprites.size()*2;
            for (int i = frame; i < frame+frames; ++i)
            {
                const Sprite& spr = sprites[i];
                offsets.push_back(datasize);
                datasize += spr.datasize();
            }
            for (int i = 0; i < complexphyssprites.size(); ++i)
            {
                offsets.push_back(datasize);
                datasize += complexphyssprites[i].slicedata.size() + 5;
            }

            fwritele16(c64handle, datasize);
            fwrite8(c64handle, frames + complexphyssprites.size()); // Num objects
            for (int i = 0; i < offsets.size(); ++i)
                fwritele16(c64handle, offsets[i]);
                
            for (int i = frame; i < frame+frames; ++i)
            {
                const Sprite& spr = sprites[i];

                int cx = 0;
                int cy = 0;
                if (!(spr.flags & FLAG_NOCONNECT))
                {
                    cx = -(spr.connectspotx - spr.hotspotx);
                    cy = -(spr.connectspoty - spr.hotspoty);
                }
                
                if (!spr.iscomplex())
                {
                    fwrite8(c64handle, 0); // Cache frame nonflipped / flipped
                    fwrite8(c64handle, 0);
                    fwrite8(c64handle, spr.color);

                    int bits = 0x80;
                    if (spr.flags & FLAG_NOCONNECT) bits |= 0x40;
                    if (spr.bboxes.size() == 0) bits |= 0x20;
                    if (spr.flags & FLAG_STOREFLIPPED) bits |= 0x10;
                    fwrite8(c64handle, bits);

                    if (!(spr.flags & FLAG_NOCONNECT))
                    {
                        fwrite8(c64handle, spr.connectspoty - spr.hotspoty);
                        fwrite8(c64handle, spr.connectspotx - spr.hotspotx);
                        fwrite8(c64handle, -(spr.connectspotx - spr.hotspotx));
                    }

                    for (int j = 0; j < spr.bboxes.size(); ++j)
                    {
                        const BoundingBox& bbox = spr.bboxes[j];
                        fwrite8(c64handle, bbox.x+bbox.sx-spr.hotspotx+cx + BOUNDS_ADJUST);
                        fwrite8(c64handle, -bbox.sx);
                        fwrite8(c64handle, (bbox.y+bbox.sy-spr.hotspoty+cy)/2 + BOUNDS_ADJUST);
                        fwrite8(c64handle, -bbox.sy/2);
                    }

                    if (spr.physsprites.size() > 0)
                    {
                        int width = (spr.physsprites[0].color & COLOR_EXPANDX) ? 24 : 12;

                        fwrite8(c64handle, spr.physsprites[0].y - spr.hotspoty + cy);
                        fwrite8(c64handle, spr.physsprites[0].x - spr.hotspotx + cx);
                        fwrite8(c64handle, -(spr.physsprites[0].x - spr.hotspotx) - width + 1 - cx);

                        fwrite8(c64handle, (spr.simpledata.slicemask & 0x100) >> 1);
                        fwrite8(c64handle, spr.simpledata.slicemask & 0xff);
                        if (spr.simpledata.slicedata.size())
                            fwrite(&spr.simpledata.slicedata[0], spr.simpledata.slicedata.size(), 1, c64handle);
                    }
                }
                else
                {
                    fwrite8(c64handle, spr.connectspoty - spr.hotspoty);
                    fwrite8(c64handle, spr.connectspotx - spr.hotspotx);
                    fwrite8(c64handle, -(spr.connectspotx - spr.hotspotx));

                    int bits = 0x0;
                    if (spr.flags & FLAG_NOCONNECT) bits |= 0x1;
                    fwrite8(c64handle, bits);

                    fwrite8(c64handle, spr.bboxes.size());
                    for (int j = 0; j < spr.bboxes.size(); ++j)
                    {
                        const BoundingBox& bbox = spr.bboxes[j];
                        fwrite8(c64handle, bbox.x+bbox.sx-spr.hotspotx+cx + BOUNDS_ADJUST);
                        fwrite8(c64handle, -bbox.sx);
                        fwrite8(c64handle, (bbox.y+bbox.sy-spr.hotspoty+cy)/2 + BOUNDS_ADJUST);
                        fwrite8(c64handle, -bbox.sy/2);
                    }

                    fwrite8(c64handle, spr.physsprites.size());
                    for (int j = 0; j < spr.physsprites.size(); ++j)
                    {
                        const PhysicalSprite& pspr = spr.physsprites[j];
                        int width = (pspr.color & COLOR_EXPANDX) ? 24 : 12;

                        fwrite8(c64handle, pspr.y - spr.hotspoty + cy);
                        fwrite8(c64handle, pspr.x - spr.hotspotx + cx);
                        fwrite8(c64handle, -(pspr.x - spr.hotspotx) - width + 1 - cx);
                        fwrite8(c64handle, getexistingphysspr(spr, pspr) + frames);
                    }
                }
            }
            for (int i = 0; i < complexphyssprites.size(); ++i)
            {
                const PhysicalSpriteData& pspr = complexphyssprites[i];

                fwrite8(c64handle, 0); // Cache frame nonflipped / flipped
                fwrite8(c64handle, 0);
                fwrite8(c64handle, pspr.color);
                fwrite8(c64handle, (pspr.slicemask & 0x100) >> 1);
                fwrite8(c64handle, pspr.slicemask & 0xff);
                if (pspr.slicedata.size())
                    fwrite(&pspr.slicedata[0], pspr.slicedata.size(), 1, c64handle);
            }
            fclose(c64handle);
        }

        fclose(handle);
        return;
      }
    }
  }
}

void loadnewslicespr(void)
{
  char ib2[5];
  int phase = 1;
  ib2[0] = 0;

  for (;;)
  {
    win_getspeed(70);
    gfx_fillscreen(254);
    printtext_center_color("LOAD STEEL RANGER SPRITEFILE:",screensizey/2-30,SPR_FONTS,COL_WHITE);
    printtext_center_color(ib1,screensizey/2-20,SPR_FONTS,COL_HIGHLIGHT);
    if (phase > 1)
    {
      printtext_center_color("LOAD AT SPRITENUM:",screensizey/2-5,SPR_FONTS,COL_WHITE);
      printtext_center_color(ib2,screensizey/2+5,SPR_FONTS,COL_HIGHLIGHT);
    }
    gfx_updatepage();
    if (phase == 1)
    {
      int r = inputtext(ib1, 80);
      if (r == -1) return;
      if (r == 1) phase = 2;
    }
    if (phase == 2)
    {
      int r = inputtext(ib2, 5);
      if (r == -1) return;
      if (r == 1)
      {
        int frameindex = 0;
        int length;
        int frame;
        FILE *handle;
        sscanf(ib2, "%d", &frame);
        if (frame < 0) frame = 0;
        if (frame > 255) frame = 255;
        handle = fopen(ib1, "rb");
        if (!handle) return;
        fseek(handle, 0, SEEK_END);
        length = ftell(handle);

        for (;;)
        {
          SPRHEADER tempheader;
          int slice;
          int slicemask = 0;
          Uint16 offset;
  
          fseek(handle, frameindex*2+3, SEEK_SET);
          offset = freadle16(handle);
          offset += 3;
          fseek(handle, offset, SEEK_SET);

          tempheader.hotspotx = -fread8(handle)*2;
          tempheader.fliphotspotx = -fread8(handle)*2;
          tempheader.connectspotx = fread8(handle)*2;
          tempheader.flipconnectspotx = fread8(handle)*2;
          tempheader.hotspoty = -fread8(handle);
          tempheader.connectspoty = fread8(handle);
          tempheader.slicemask = fread8(handle);
          tempheader.color = fread8(handle);
          tempheader.cacheframe = fread8(handle);
          tempheader.flipcacheframe = fread8(handle);

          Sprite& spr = sprites[frame];
          memset(spr.pixels, 0, sizeof spr.pixels);
          spr.bboxes.clear();
          spr.physsprites.clear();
          spr.color = tempheader.color & 0xf;
          spr.hotspotx = tempheader.hotspotx/2;
          spr.hotspoty = tempheader.hotspoty;
          spr.connectspotx = tempheader.connectspotx/2;
          spr.connectspoty = tempheader.connectspoty;
          spr.sx = 12;
          spr.sy = 21;
          slicemask = ((int)tempheader.slicemask) | (((int)tempheader.color & 128) << 1);

          for (slice = 0; slice < 9; slice++)
          {
            if (slicemask & (1 << slice))
            {
              int slicey;
              for (slicey = 0; slicey < 7; slicey++)
              {
                unsigned char databyte = fread8(handle);
                spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4] = databyte >> 6;
                spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+1] = (databyte >> 4) & 3;
                spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+2] = (databyte >> 2) & 3;
                spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+3] = databyte & 3;
              }
            }
          }
          frameindex++;
          frame++;
          if (ftell(handle) >= length) break;
          if (frame > 255) break;
        }

        fclose(handle);
        return;
      }
    }
  }
}

void loadoldslicespr(void)
{
  char ib2[5];
  int phase = 1;
  ib2[0] = 0;

  for (;;)
  {
    win_getspeed(70);
    gfx_fillscreen(254);
    printtext_center_color("LOAD HESSIAN/MW4 SPRITEFILE:",screensizey/2-30,SPR_FONTS,COL_WHITE);
    printtext_center_color(ib1,screensizey/2-20,SPR_FONTS,COL_HIGHLIGHT);
    if (phase > 1)
    {
      printtext_center_color("LOAD AT SPRITENUM:",screensizey/2-5,SPR_FONTS,COL_WHITE);
      printtext_center_color(ib2,screensizey/2+5,SPR_FONTS,COL_HIGHLIGHT);
    }
    gfx_updatepage();
    if (phase == 1)
    {
      int r = inputtext(ib1, 80);
      if (r == -1) return;
      if (r == 1) phase = 2;
    }
    if (phase == 2)
    {
      int r = inputtext(ib2, 5);
      if (r == -1) return;
      if (r == 1)
      {
        int frameindex = 0;
        int format = 0;
        int length;
        int frame;
        FILE *handle;
        sscanf(ib2, "%d", &frame);
        if (frame < 0) frame = 0;
        if (frame > 255) frame = 255;
        handle = fopen(ib1, "rb");
        if (!handle) return;
        fseek(handle, 0, SEEK_END);
        length = ftell(handle);

        // Detect format from offset between the 2 first sprites
        {
          int offset1, offset2;
          fseek(handle, 3, SEEK_SET);
          offset1 = freadle16(handle);
          offset2 = freadle16(handle);
          while (offset2 - offset1 > 10)
            offset2 -= 7;
          if (offset2 - offset1 == 8)
            format = 2;
          if (offset2 - offset1 == 7)
            format = 1;
        }

        if (format == 0)
        {
          for (;;)
          {
            SPRHEADER tempheader;
            int slice;
            int slicemask = 0;
            Uint16 offset;

            fseek(handle, frameindex*2+3, SEEK_SET);
            offset = freadle16(handle);
            offset += 3;
            fseek(handle, offset, SEEK_SET);

            tempheader.slicemask = fread8(handle);
            tempheader.color = fread8(handle);
            tempheader.hotspotx = fread8(handle);
            tempheader.fliphotspotx = fread8(handle);
            tempheader.connectspotx = fread8(handle);
            tempheader.flipconnectspotx = fread8(handle);
            tempheader.hotspoty = fread8(handle);
            tempheader.connectspoty = fread8(handle);
            tempheader.cacheframe = fread8(handle);
            tempheader.flipcacheframe = fread8(handle);

            slicemask = ((int)tempheader.slicemask) | (((int)tempheader.color & 128) << 1);

            Sprite& spr = sprites[frame];
            memset(spr.pixels, 0, sizeof spr.pixels);
            spr.bboxes.clear();
            spr.physsprites.clear();
            spr.color = tempheader.color & 0xf;
            spr.hotspotx = tempheader.hotspotx/2;
            spr.hotspoty = tempheader.hotspoty;
            spr.connectspotx = tempheader.connectspotx/2;
            spr.connectspoty = tempheader.connectspoty;
            spr.sx = 12;
            spr.sy = 21;
            slicemask = ((int)tempheader.slicemask) | (((int)tempheader.color & 128) << 1);

            for (slice = 0; slice < 9; slice++)
            {
              if (slicemask & (1 << slice))
              {
                int slicey;
                for (slicey = 0; slicey < 7; slicey++)
                {
                  unsigned char databyte = fread8(handle);
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4] = databyte >> 6;
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+1] = (databyte >> 4) & 3;
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+2] = (databyte >> 2) & 3;
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+3] = databyte & 3;
                }
              }
            }
            frameindex++;
            frame++;
            if (ftell(handle) >= length) break;
            if (frame > 255) break;
          }
        }
        if (format == 1)
        {
          for (;;)
          {
            SPRHEADER tempheader;
            int slice;
            int slicemask = 0;
            Uint16 offset;

            fseek(handle, frameindex*2+3, SEEK_SET);
            offset = freadle16(handle);
            offset += 3;
            fseek(handle, offset, SEEK_SET);

            tempheader.slicemask = fread8(handle);
            tempheader.color = fread8(handle);
            tempheader.hotspotx = fread8(handle);
            tempheader.connectspotx = fread8(handle);
            tempheader.hotspoty = fread8(handle);
            tempheader.connectspoty = fread8(handle);
            tempheader.cacheframe = fread8(handle);

            slicemask = ((int)tempheader.slicemask) | (((int)tempheader.color & 128) << 1);

            Sprite& spr = sprites[frame];
            memset(spr.pixels, 0, sizeof spr.pixels);
            spr.bboxes.clear();
            spr.physsprites.clear();
            spr.color = tempheader.color & 0xf;
            spr.hotspotx = tempheader.hotspotx/2;
            spr.hotspoty = tempheader.hotspoty;
            spr.connectspotx = tempheader.connectspotx/2;
            spr.connectspoty = tempheader.connectspoty;
            spr.sx = 12;
            spr.sy = 21;
            slicemask = ((int)tempheader.slicemask) | (((int)tempheader.color & 128) << 1);

            for (slice = 0; slice < 9; slice++)
            {
              if (slicemask & (1 << slice))
              {
                int slicey;
                for (slicey = 0; slicey < 7; slicey++)
                {
                  unsigned char databyte = fread8(handle);
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4] = databyte >> 6;
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+1] = (databyte >> 4) & 3;
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+2] = (databyte >> 2) & 3;
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+3] = databyte & 3;
                }
              }
            }
            frameindex++;
            frame++;
            if (ftell(handle) >= length) break;
            if (frame > 255) break;
          }
        }
        if (format == 2)
        {
          for (;;)
          {
            OLDSPRHEADER2 tempheader;
            int slice;
            Uint16 offset;

            fseek(handle, frameindex*2+3, SEEK_SET);
            offset = freadle16(handle);
            offset += 3;
            fseek(handle, offset, SEEK_SET);

            tempheader.slicemask = freadle16(handle);
            tempheader.hotspotx = fread8(handle);
            tempheader.reversehotspotx = fread8(handle);
            tempheader.hotspoty = fread8(handle);
            tempheader.connectspotx = fread8(handle);
            tempheader.reverseconnectspotx = fread8(handle);
            tempheader.connectspoty = fread8(handle);

            Sprite& spr = sprites[frame];
            memset(spr.pixels, 0, sizeof spr.pixels);
            spr.bboxes.clear();
            spr.physsprites.clear();
            spr.hotspotx = tempheader.hotspotx/2;
            spr.hotspoty = tempheader.hotspoty;
            spr.connectspotx = tempheader.connectspotx/2;
            spr.connectspoty = tempheader.connectspoty;
            spr.sx = 12;
            spr.sy = 21;

            for (slice = 0; slice < 9; slice++)
            {
              if (tempheader.slicemask & (1 << slice))
              {
                int slicey;
                for (slicey = 0; slicey < 7; slicey++)
                {
                  unsigned char databyte = fread8(handle);
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4] = databyte >> 6;
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+1] = (databyte >> 4) & 3;
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+2] = (databyte >> 2) & 3;
                  spr.pixels[(slice/3*7+slicey)*MAXSIZEX+(slice%3)*4+3] = databyte & 3;
                }
              }
            }
            frameindex++;
            frame++;
            if (ftell(handle) >= length) break;
            if (frame > 255) break;
          }
        }

        fclose(handle);
        return;
      }
    }
  }
}

void changecol()
{
  Sprite& spr = sprites[sprnum];
  int y;
  if (colordelay < COLOR_DELAY) colordelay++;
  if (!mouseb) return;
  if ((mousex < colorx) || (mousex >= cbarx+15)) return;
  if ((mousey < colory) || (mousey >= colory+4*15)) return;
  y = mousey - colory;
  if ((y % 15) >= 9) return;
  if (mousex < cbarx)
  {
    ccolor = y / 15;
  }
  else
  {
    if ((!prevmouseb) || (colordelay >= COLOR_DELAY))
    {
      if (mouseb & LEFT_BUTTON)
      {
        switch(y/15)
        {
          case 0:
          bgcol++;
          bgcol &= 15;
          break;
          case 1:
          multicol1++;
          multicol1 &= 15;
          break;
          case 2:
          spr.color++;
          spr.color &= 15;
          for (int i = 0; i < spr.physsprites.size(); ++i)
          {
            int widthbit = spr.physsprites[i].color & COLOR_EXPANDX;
            spr.physsprites[i].color = spr.color | widthbit;
          }
          break;
          case 3:
          multicol2++;
          multicol2 &= 15;
          break;
        }
        colordelay = 0;
      }
      if (mouseb & RIGHT_BUTTON)
      {
        switch(y/15)
        {
          case 0:
          bgcol--;
          bgcol &= 15;
          break;
          case 1:
          multicol1--;
          multicol1 &= 15;
          break;
          case 2:
          spr.color--;
          spr.color &= 15;
          for (int i = 0; i < spr.physsprites.size(); ++i)
          {
            int widthbit = spr.physsprites[i].color & COLOR_EXPANDX;
            spr.physsprites[i].color = spr.color | widthbit;
          }
          break;
          case 3:
          multicol2--;
          multicol2 &= 15;
          break;
        }
        colordelay = 0;
      }
    }
  }
}

void editspr()
{
  Sprite& spr = sprites[sprnum];
  int x,y;

  y = mousey / 5 + viewy;
  x = mousex / 10 + viewx;

    int overlapbb = -1;
    for (int i = 0; i < spr.bboxes.size(); ++i)
    {
        if (isinside(spr.bboxes[i], x, y))
            overlapbb = i;
    }

    if (!bboxerased)
    {
        if (win_keystate[KEY_A] && !shiftdown)
        {
            if (newbbx1 < 0 && overlapbb < 0)
            {
                newbbx1 = newbbx2 = x;
                newbby1 = newbby2 = y;
            }
            else
            {
                newbbx2 = x;
                newbby2 = y;
            }
        }
        if (!win_keystate[KEY_A] && newbbx1 >= 0)
        {
            makeundo();
            BoundingBox newbb;
            if (newbbx2 < newbbx1)
                std::swap(newbbx1, newbbx2);
            if (newbby2 < newbby1)
                std::swap(newbby1, newbby2);
            newbb.x = newbbx1;
            newbb.y = newbby1;
            newbb.sx = newbbx2-newbbx1+1;
            newbb.sy = newbby2-newbby1+1;
            newbb.flags = 1;
            spr.bboxes.push_back(newbb);
            newbbx1 = -1;
        }
    }
    if (overlapbb >= 0 && k == KEY_A && newbbx1 < 0 && !shiftdown)
    {
        makeundo();
        BoundingBox& bbox = spr.bboxes[overlapbb];
        ++bbox.flags;
        bbox.flags &= 3;
        if (!bbox.flags)
            ++bbox.flags;
    }
    if (overlapbb >= 0 && k == KEY_A && shiftdown)
    {
        makeundo();
        spr.bboxes.erase(spr.bboxes.begin() + overlapbb);
        bboxerased = 1;
    }
    if (bboxerased && !win_keystate[KEY_A])
        bboxerased = 0;

    if (win_keystate[KEY_SPACE])
    {
        switch (markstate)
        {
        case 0:
        case 2:
            markx1 = markx2 = x;
            marky1 = marky2 = y;
            markstate = 1;
            break;
        case 1:
            markx2 = x;
            marky2 = y;
            break;
        }
    }
    if (markstate == 1 && !win_keystate[KEY_SPACE])
    {
      markstate = 2;
      if (markx2 < markx1)
        std::swap(markx1, markx2);
      if (marky2 < marky1)
        std::swap(marky1, marky2);
    }

  if ((mousex < 0) || (mousex >= VIEWSIZEX*10)) return;
  if ((mousey < 0) || (mousey >= VIEWSIZEY*5)) return;

  if (y >= 0 && x >= 0 && y < spr.sy && x < spr.sx)
  {
    if (prevmouseb == 0 && mouseb > 0)
      makeundo();
    if (mouseb & 1)
      spr.pixels[y*MAXSIZEX+x] = ccolor;
    if (mouseb & 2)
      spr.pixels[y*MAXSIZEX+x] = 0;

    int insidephys = -1;
    for (int i = 0; i < spr.physsprites.size(); ++i)
    {
        if (isinside(spr.physsprites[i], x, y))
        {
            insidephys = i;
            break;
        }
    }

    if (k == KEY_S)
    {
        if (!shiftdown)
        {
            int overlapphys = -1;

            for (int cy = y; cy < y+21; ++cy)
            {
                for (int cx = x; cx < x+12; ++cx)
                {
                    for (int i = 0; i < spr.physsprites.size(); ++i)
                    {
                        if (isinside(spr.physsprites[i], cx, cy))
                        {
                            overlapphys = i;
                            goto HASOVERLAP;
                        }
                    }
                }
            }
            HASOVERLAP:
            if (insidephys >= 0)
            {
                makeundo();
                PhysicalSprite& pspr = spr.physsprites[insidephys];
                int widthbit = pspr.color & COLOR_EXPANDX;
                ++pspr.color;
                pspr.color &= 0xf;
                pspr.color |= widthbit;
            }
            if (overlapphys < 0 && x <= spr.sx-12 && y <= spr.sy-21)
            {
                makeundo();
                PhysicalSprite newps;
                newps.x = x;
                newps.y = y;
                newps.color = spr.color;
                spr.physsprites.push_back(newps);
            }
        }
        else
        {
            for (int i = 0; i < spr.physsprites.size(); ++i)
            {
                if (isinside(spr.physsprites[i], x, y))
                {
                    spr.physsprites.erase(spr.physsprites.begin()+i);
                    break;
                }
            }
        }
    }
    
    if (k == KEY_W && insidephys >= 0)
        spr.physsprites[insidephys].color ^= COLOR_EXPANDX;

    if (k == KEY_D && shiftdown)
        spr.physsprites.clear();

    if (k == KEY_H)
    {
      makeundo();
      spr.hotspotx = x;
      spr.hotspoty = y;
    }
    if (k == KEY_J)
    {
      if (!shiftdown)
      {
        makeundo();
        spr.connectspotx = x;
        spr.connectspoty = y;
        spr.flags &= ~FLAG_NOCONNECT;
      }
    }
    if (k == KEY_F)
    {
        floodfill(x, y, ccolor);
    }
    if (win_keystate[KEY_L])
    {
        if (!linemode)
        {
            linemode = 1;
            linex1 = x;
            liney1 = y;
        }
        else
        {
            gfx_line((linex1-viewx)*10+5, (liney1-viewy)*5+2, (x-viewx)*10+5, (y-viewy)*5+2,1);
        }
    }
    else
    {
      if (linemode)
        drawline(linex1,liney1,x,y,ccolor);
    }

    if (k == KEY_T && !shiftdown)
    {
      if (!ctrldown)
        drawbrush(x, y);
      else
        erasebrush(x, y);
    }
  }
  else
  {
    if (!win_keystate[KEY_A] && newbbx1 >= 0)
    {
        makeundo();
        BoundingBox newbb;
        newbb.x = newbbx1;
        newbb.y = newbby1;
        newbb.sx = newbbx2-newbbx1+1;
        newbb.sy = newbby2-newbby1+1;
        newbb.flags = 1;
        spr.bboxes.push_back(newbb);
        newbbx1 = -1;
    }
  }


  if (k == KEY_P && markstate == 2 && !shiftdown)
  {
      brush.sx = markx2-markx1+1;
      brush.sy = marky2-marky1+1;
      for (int cy = marky1; cy <= marky2; ++cy)
      {
          for (int cx = markx1; cx <= markx2; ++cx)
          {
              brush.pixels[(cy-marky1)*MAXSIZEX+(cx-markx1)] = spr.pixels[cy*MAXSIZEX+cx];
          }
      }
      markstate = 0;
  }
  if (!win_keystate[KEY_L])
    linemode = 0;

}

void floodfill(int x, int y, int col)
{
  makeundo();
  Sprite& spr = sprites[sprnum];
  if (x < 0 || y < 0 || x >= spr.sx || y >= spr.sy) return;
  int sc = spr.pixels[y*MAXSIZEX+x];
  if (col == sc) return;
  floodfillinternal(x, y, col, sc);

}

void floodfillinternal(int x, int y, int col, int sc)
{
  Sprite& spr = sprites[sprnum];
  if (x < 0 || y < 0 || x >= spr.sx || y >= spr.sy) return;
  std::vector<std::pair<int, int> > openings;
  for (int cx = x; cx >= 0; --cx)
  {
      if (spr.pixels[y*MAXSIZEX+cx] == sc)
        spr.pixels[y*MAXSIZEX+cx] = col;
      else
        break;
      if (y > 0 && spr.pixels[(y-1)*MAXSIZEX+cx] == sc)
        openings.push_back(std::make_pair(cx, y-1));
      if (y < spr.sy-1 && spr.pixels[(y+1)*MAXSIZEX+cx] == sc)
        openings.push_back(std::make_pair(cx, y+1));
  }
  for (int cx = x+1; cx < spr.sx; ++cx)
  {
      if (spr.pixels[y*MAXSIZEX+cx] == sc)
        spr.pixels[y*MAXSIZEX+cx] = col;
      else
        break;
      if (y > 0 && spr.pixels[(y-1)*MAXSIZEX+cx] == sc)
        openings.push_back(std::make_pair(cx, y-1));
      if (y < spr.sy-1 && spr.pixels[(y+1)*MAXSIZEX+cx] == sc)
        openings.push_back(std::make_pair(cx, y+1));
  }
  for (int c = 0; c < openings.size(); ++c)
  {
      floodfillinternal(openings[c].first, openings[c].second, col, sc);
  }
}

void drawbrush(int x, int y)
{
    makeundo();
    Sprite& spr = sprites[sprnum];
    for (int by = 0; by < brush.sy; ++by)
    {
        for (int bx = 0; bx < brush.sx; ++bx)
        {
            if (bx+x >= 0 && by+y >= 0 && bx+x < spr.sx && by+y < spr.sy)
            {
                if (brush.pixels[by*MAXSIZEX+bx])
                    spr.pixels[(by+y)*MAXSIZEX + bx+x] = brush.pixels[by*MAXSIZEX+bx];
            }
        }
    }
}

void erasebrush(int x, int y)
{
    makeundo();
    Sprite& spr = sprites[sprnum];
    for (int by = 0; by < brush.sy; ++by)
    {
        for (int bx = 0; bx < brush.sx; ++bx)
        {
            if (bx+x >= 0 && by+y >= 0 && bx+x < spr.sx && by+y < spr.sy)
            {
                if (brush.pixels[by*MAXSIZEX+bx])
                    spr.pixels[(by+y)*MAXSIZEX + bx+x] = 0;
            }
        }
    }
}

void drawline(int x1, int y1, int x2, int y2, int col)
{
    makeundo();
    Sprite& spr = sprites[sprnum];
    int dx = x2-x1;
    int dy = y2-y1;
    int adx = abs(dx);
    int ady = abs(dy);
    int x = x1;
    int y = y1;
    if (adx == 0 && ady == 0)
    {
        spr.pixels[y1*MAXSIZEX+x1] = col;
        return;
    }

    if (adx > ady)
    {
        int d = 2*ady-adx;
        for (;;)
        {
            spr.pixels[y*MAXSIZEX+x] = col;
            if (d < 0)
              d += 2*ady;
            else
            {
              d += 2*(ady-adx);
              if (dy < 0)
                y--; 
              else 
                y++;
            }

            if (x == x2)
              break;

            if (dx < 0)
              x--;
            else
              x++;
        }
    }
    else
    {
        int d = 2*adx-ady;
        for (;;)
        {
            spr.pixels[y*MAXSIZEX+x] = col;
            if (d < 0)
              d += 2*adx;
            else
            {
              d += 2*(adx-ady);
              if (dx < 0)
                x--;
              else
                x++;
            }

            if (y == y2)
              break;

            if (dy < 0)
              y--;
            else
              y++;
        }
    }
}

void flipsprx()
{
  makeundo();
  Sprite& spr = sprites[sprnum];
  int y,x;

  spr.hotspotx = spr.sx - 1 - spr.hotspotx;
  spr.connectspotx = spr.sx - 1 - spr.connectspotx;

  for (int i = 0; i < spr.physsprites.size(); ++i)
  {
      int width = (spr.physsprites[i].color & COLOR_EXPANDX) ? 24 : 12;
      spr.physsprites[i].x = spr.sx - width - spr.physsprites[i].x;
  }
  for (int i = 0; i < spr.bboxes.size(); ++i)
  {
      spr.bboxes[i].x = spr.sx - spr.bboxes[i].sx - spr.bboxes[i].x;
  }

  for (y = 0; y < spr.sy; ++y)
  {
    for (x = 0; x < spr.sx/2; ++x)
    {
      unsigned char temp = spr.pixels[y*MAXSIZEX+x];
      spr.pixels[y*MAXSIZEX+x] = spr.pixels[y*MAXSIZEX+spr.sx-1-x];
      spr.pixels[y*MAXSIZEX+spr.sx-1-x] = temp;
    }
  }
}

void flipspry()
{
  makeundo();
  Sprite& spr = sprites[sprnum];
  int y,x;

  spr.hotspoty = spr.sy-1-spr.hotspoty;
  spr.connectspoty = spr.sy-1-spr.connectspoty;

  for (int i = 0; i < spr.physsprites.size(); ++i)
  {
      spr.physsprites[i].y = spr.sy - 21 - spr.physsprites[i].y;
  }
  for (int i = 0; i < spr.bboxes.size(); ++i)
  {
      spr.bboxes[i].y = spr.sy - spr.bboxes[i].sy - spr.bboxes[i].y;
  }

  for (int y = 0; y < spr.sy/2; ++y)
  {
    unsigned char temprow[MAXSIZEX];
    memcpy(temprow, &spr.pixels[y*MAXSIZEX], spr.sx);
    memcpy(&spr.pixels[y*MAXSIZEX], &spr.pixels[(spr.sy-1-y)*MAXSIZEX], spr.sx);
    memcpy(&spr.pixels[(spr.sy-1-y)*MAXSIZEX], temprow, spr.sx);
  }
}

void scrollsprleft()
{
  makeundo();
  Sprite& spr = sprites[sprnum];
  if (!ctrldown)
  {
    for (int y = 0; y < spr.sy; ++y)
    {
      unsigned char temp = spr.pixels[y*MAXSIZEX];
      memmove(&spr.pixels[y*MAXSIZEX], &spr.pixels[y*MAXSIZEX+1], spr.sx-1);
      spr.pixels[y*MAXSIZEX+spr.sx-1] = temp;
    }
    spr.hotspotx -= 1;
    for (int i = 0; i < spr.physsprites.size(); ++i)
        if (spr.sx > 12) spr.physsprites[i].x--;
    for (int i = 0; i < spr.bboxes.size(); ++i)
        spr.bboxes[i].x--;
    validatespr(spr);
  }
  spr.connectspotx -= 1;
}

void scrollsprright()
{
  makeundo();
  Sprite& spr = sprites[sprnum];
  if (!ctrldown)
  {
    for (int y = 0; y < spr.sy; ++y)
    {
      unsigned char temp = spr.pixels[y*MAXSIZEX+spr.sx-1];
      memmove(&spr.pixels[y*MAXSIZEX+1], &spr.pixels[y*MAXSIZEX], spr.sx-1);
      spr.pixels[y*MAXSIZEX] = temp;
    }
    spr.hotspotx += 1;
    for (int i = 0; i < spr.physsprites.size(); ++i)
        if (spr.sx > 12) spr.physsprites[i].x++;
    for (int i = 0; i < spr.bboxes.size(); ++i)
        spr.bboxes[i].x++;
    validatespr(spr);
  }
  spr.connectspotx += 1;
}

void scrollsprup()
{
  makeundo();
  Sprite& spr = sprites[sprnum];
  if (!ctrldown)
  {
    unsigned char temprow[MAXSIZEX];
    memcpy(temprow, &spr.pixels[0], spr.sx);
    for (int y = 0; y < spr.sy-1; ++y)
      memmove(&spr.pixels[y*MAXSIZEX], &spr.pixels[(y+1)*MAXSIZEX], spr.sx);
    memcpy(&spr.pixels[(spr.sy-1)*MAXSIZEX], temprow, spr.sx);
    spr.hotspoty -= 1;
    for (int i = 0; i < spr.physsprites.size(); ++i)
        if (spr.sy > 21) spr.physsprites[i].y--;
    for (int i = 0; i < spr.bboxes.size(); ++i)
        spr.bboxes[i].y--;
    validatespr(spr);
  }
  spr.connectspoty -= 1;
}

void scrollsprdown()
{
  makeundo();
  Sprite& spr = sprites[sprnum];
  if (!ctrldown)
  {
    unsigned char temprow[MAXSIZEX];
    memcpy(temprow, &spr.pixels[(spr.sy-1)*MAXSIZEX], spr.sx);
    for (int y = spr.sy-2; y >= 0; --y)
      memmove(&spr.pixels[(y+1)*MAXSIZEX], &spr.pixels[y*MAXSIZEX], spr.sx);
    memcpy(&spr.pixels[0], temprow, spr.sx);
    spr.hotspoty += 1;
    for (int i = 0; i < spr.physsprites.size(); ++i)
        if (spr.sy > 21) spr.physsprites[i].y++;
    for (int i = 0; i < spr.bboxes.size(); ++i)
        spr.bboxes[i].y++;
    validatespr(spr);
  }
  spr.connectspoty += 1;
}

void swapsprcolors(int col1, int col2)
{
  makeundo();
  Sprite& spr = sprites[sprnum];

  for (int y = 0; y < spr.sy; ++y)
  {
    for (int x = 0; x < spr.sx; ++x)
    {
      if (markstate != 2 || (x >= markx1 && x <= markx2 && y >= marky1 && y <= marky2))
      {
        if (spr.pixels[y*MAXSIZEX+x] == col1)
          spr.pixels[y*MAXSIZEX+x] = col2;
        else if (spr.pixels[y*MAXSIZEX+x] == col2)
          spr.pixels[y*MAXSIZEX+x] = col1;
      }
    }
  }
}

void makeundo()
{
    Sprite& spr = sprites[sprnum];
    if (undostack[sprnum].size() >= MAX_UNDOSTEPS)
      undostack[sprnum].erase(undostack[sprnum].begin());
    undostack[sprnum].push_back(spr);
}

void applyundo()
{
    Sprite& spr = sprites[sprnum];
    if (undostack[sprnum].size())
    {
        spr = undostack[sprnum].back();
        undostack[sprnum].pop_back();
    }
}

void buildphyssprites(int firstframe, int frames)
{
    datasize = 0;

    allphyssprites.clear();
    complexphyssprites.clear();

    for (int i = firstframe; i < firstframe+frames; ++i)
    {
        Sprite& spr = sprites[i];
        for (int j = 0; j < spr.physsprites.size(); ++j)
        {
            const PhysicalSprite& pspr = spr.physsprites[j];

            int res = getexistingphysspr(spr, pspr);

            if (res < 0)
            {
                PhysicalSpriteData newdata;
                newdata.slicemask = 0;
                newdata.color = pspr.color;

                int width = (pspr.color & COLOR_EXPANDX) ? 24 : 12;
                int mul = (pspr.color & COLOR_EXPANDX) ? 2 : 1;

                for (int py = 0; py < 21; ++py)
                {
                    for (int px = 0; px < 12; ++px)
                    {
                        if (spr.flags & FLAG_STOREFLIPPED)
                            newdata.pixels[py*12+px] = spr.pixels[(pspr.y+py)*MAXSIZEX+(pspr.x+(width-1-px*mul))];
                        else
                            newdata.pixels[py*12+px] = spr.pixels[(pspr.y+py)*MAXSIZEX+(pspr.x+px*mul)];
                        if (newdata.pixels[py*12+px] != 0)
                            newdata.slicemask |= 1 << (py/7*3 + px/4);
                    }
                }
                for (int l = 0; l < 9; ++l)
                {
                    if (newdata.slicemask & (1 << l))
                    {
                        datasize += 7;
                        for (int sy = 0; sy < 7; ++sy)
                        {
                            unsigned char databyte = 0;
                            databyte |= newdata.pixels[(l/3*7+sy)*12+(l%3)*4] << 6;
                            databyte |= newdata.pixels[(l/3*7+sy)*12+(l%3)*4+1] << 4;
                            databyte |= newdata.pixels[(l/3*7+sy)*12+(l%3)*4+2] << 2;
                            databyte |= newdata.pixels[(l/3*7+sy)*12+(l%3)*4+3];
                            newdata.slicedata.push_back(databyte);
                        }
                    }
                }

                if (spr.iscomplex())
                    complexphyssprites.push_back(newdata);
                else
                    spr.simpledata = newdata;

                allphyssprites.push_back(newdata);
            }
        }
    }
}

int getexistingphysspr(const Sprite& spr, const PhysicalSprite& pspr)
{
    // If sprite is simple, it always contains the physsprite data inline
    if (!spr.iscomplex())
        return -1;

    for (int i = 0; i < complexphyssprites.size(); ++i)
    {
        const PhysicalSpriteData& cmp = complexphyssprites[i];
        int matchpixels = 0;

        if (cmp.color != pspr.color)
            continue;

        int mul = (pspr.color & COLOR_EXPANDX) ? 2 : 1;

        for (int y = 0; y < 21; ++y)
        {
            for (int x = 0; x < 12; ++x)
            {
                if (cmp.pixels[y*12+x] == spr.pixels[(pspr.y+y)*MAXSIZEX+(pspr.x+x*mul)])
                    ++matchpixels;
                else
                    goto END_NONFLIPPED;
            }
        }
        END_NONFLIPPED:
        if (matchpixels == 21*12)
            return i;
        matchpixels = 0;
        for (int y = 0; y < 21; ++y)
        {
            for (int x = 0; x < 12; ++x)
            {
                if (cmp.pixels[y*12+(11-x)] == spr.pixels[(pspr.y+y)*MAXSIZEX+(pspr.x+x*mul)])
                    ++matchpixels;
                else
                    goto END_FLIPPED;
            }
        }
        END_FLIPPED:
        if (matchpixels == 21*12)
            return i+128;
    }
    
    return -1;
}

void validatespr(Sprite& spr)
{
    for (int i = 0; i < spr.physsprites.size(); )
    {
        int width = (spr.physsprites[i].color & COLOR_EXPANDX) ? 24 : 12;
        if (spr.physsprites[i].x+width > spr.sx || spr.physsprites[i].y+21 > spr.sy)
            spr.physsprites.erase(spr.physsprites.begin()+i);
        else
            ++i;
    }
}

void drawc64sprite(const Sprite& spr, int bx, int by)
{
  for (int y = 0; y < spr.sy; ++y)
  {
    for (int x = 0; x < spr.sx; ++x)
    {
      unsigned char p = spr.pixels[y*MAXSIZEX+x];
      unsigned char c = 0;
      if (p)
      {
        switch (p)
        {
        case 1:
            c = multicol1;
            break;
        case 2:
            c = getspritecolor(spr, x, y);
            break;
        case 3:
            c = multicol2;
            break;
        }
        gfx_plot(bx+x*2,by+y,c);
        gfx_plot(bx+1+x*2,by+y,c);
      }
    }
  }
}

bool isinside(const PhysicalSprite& pspr, int x, int y)
{
    int width = (pspr.color & COLOR_EXPANDX) ? 24 : 12;
    return x >= pspr.x && y >= pspr.y && x < (pspr.x+width) && y < (pspr.y+21);
}

bool isinside(const BoundingBox& bbox, int x, int y)
{
    return x >= bbox.x && y >= bbox.y && x < (bbox.x+bbox.sx) && y < (bbox.y+bbox.sy);
}

int getspritecolor(const Sprite& spr, int x, int y)
{
    int ret = spr.color;

    for (int i = 0; i < spr.physsprites.size(); ++i)
    {
        if (isinside(spr.physsprites[i], x, y))
            return spr.physsprites[i].color & 0xf;
    }
    
    return ret;
}

void drawgrid()
{
  Sprite& spr = sprites[sprnum];

  for (int y = 0; y < VIEWSIZEY; ++y)
  {
    for (int x = 0; x < VIEWSIZEX; ++x)
    {
      int sx = x+viewx;
      int sy = y+viewy;

      if (sx >= 0 && sy >= 0 && sx < spr.sx && sy < spr.sy)
      {
        int c = bgcol;

        switch (spr.pixels[sy*MAXSIZEX+sx])
        {
        case 1:
            c = multicol1;
            break;
        case 2:
            c = getspritecolor(spr, sx, sy);
            break;
        case 3:
            c = multicol2;
            break;
        }
        gfx_drawsprite(x*10,y*5,0x00000011+c);
      }

      if ((hotspotflash & 31) >= 16)
      {
        if (sx == spr.hotspotx && sy == spr.hotspoty)
            gfx_drawsprite(x*10,y*5,0x00000011+1);
        if ((spr.flags & FLAG_NOCONNECT) == 0)
        {
          if (sx == spr.connectspotx && sy == spr.connectspoty)
              gfx_drawsprite(x*10,y*5,0x00000011+13);
        }
      }
    }
  }
  for (int i = 0; i < spr.physsprites.size(); ++i)
  {
    const PhysicalSprite& pspr = spr.physsprites[i];
    int width = (pspr.color & COLOR_EXPANDX) ? 24 : 12;
    drawbox((pspr.x-viewx)*10, (pspr.y-viewy)*5, width*10, 21*5, 15);
    if ((pspr.color&0xf) != spr.color)
    {
        sprintf(textbuffer, "%d", pspr.color);
        printtext_color(textbuffer, (pspr.x-viewx)*10, (pspr.y-viewy)*5,SPR_FONTS,COL_WHITE);
    }
  }
  for (int i = 0; i < spr.bboxes.size(); ++i)
  {
    const BoundingBox& bbox = spr.bboxes[i];
    drawbox((bbox.x-viewx)*10, (bbox.y-viewy)*5, bbox.sx*10, bbox.sy*5, 1);
    sprintf(textbuffer, "%d", spr.bboxes[i].flags);
    printtext_color(textbuffer, (bbox.x-viewx)*10, (bbox.y-viewy)*5,SPR_FONTS,COL_WHITE);
  }
  drawfilledbox(VIEWSIZEX*10,0,screensizex-VIEWSIZEX*10,screensizey,254);
  drawfilledbox(0,VIEWSIZEY*5,screensizex,screensizey-VIEWSIZEY*5,254);

  if (markstate > 0)
    drawboxcorners((markx1-viewx)*10,(marky1-viewy)*5, (markx2-viewx)*10,(marky2-viewy)*5, 1);
  if (newbbx1 >= 0)
    drawboxcorners((newbbx1-viewx)*10, (newbby1-viewy)*5, (newbbx2-viewx)*10, (newbby2-viewy)*5, 7);

  drawfilledbox(VIEWSIZEX*10+8,0,spr.sx*2,spr.sy,bgcol);
  drawbox(VIEWSIZEX*10+8+viewx*2,0+viewy,VIEWSIZEX*2,VIEWSIZEY,15);
  drawc64sprite(spr, VIEWSIZEX*10+8,0);

  if ((hotspotflash & 31) >= 16)
  {
      gfx_plot(VIEWSIZEX*10+8+spr.hotspotx*2, spr.hotspoty,1);
      gfx_plot(VIEWSIZEX*10+8+spr.hotspotx*2+1, spr.hotspoty,1);
      if ((spr.flags & FLAG_NOCONNECT) == 0)
      {
        gfx_plot(VIEWSIZEX*10+8+spr.connectspotx*2, spr.connectspoty,13);
        gfx_plot(VIEWSIZEX*10+8+spr.connectspotx*2+1, spr.connectspoty,13);
      }
  }
  hotspotflash++;
}

void drawcbar(int x, int y, unsigned char col)
{
  int a;
  for (a = y; a < y+9; a++)
  {
    gfx_line(x, a, x+14, a, col);
  }
}

int initsprites()
{
  for (int c = 0; c < MAXSPR; ++c)
  {
    Sprite& spr = sprites[c];
    spr.sx = 12;
    spr.sy = 21;
    spr.color = 1;
    spr.hotspotx = 0;
    spr.hotspoty = 0;
    spr.connectspotx = 0;
    spr.connectspoty = 0;
    memset(spr.pixels, 0, sizeof spr.pixels);
  }
  for (int c = 0; c < MAXTESTSPR; ++c)
  {
    testsprites[c].f = MAXSPR-1;
  }
  testsprites[0].x = 384;
  testsprites[0].y = 256;
  brush.sx = 0;
  brush.sy = 0;
  return 1;
}

void mouseupdate()
{
  mou_getpos(&mousex, &mousey);
  prevmouseb = mouseb;
  mouseb = mou_getbuttons();
}

unsigned getcharsprite(unsigned char ch)
{
  unsigned num = ch-31;
  if (num >= 64) num -= 32;
  if (num > 59) num = 32;
  return num;
}

void printtext_color(char *string, int x, int y, unsigned spritefile, int color)
{
  unsigned char *xlat = colxlattable[color];

  spritefile <<= 16;
  while (*string)
  {
    unsigned num = getcharsprite(*string);
    gfx_drawspritex(x, y, spritefile + num, xlat);
    x += spr_xsize;
    string++;
  }
}

void printtext_center_color(char *string, int y, unsigned spritefile, int color)
{
  int x = 0;
  char *stuff = string;
  unsigned char *xlat = colxlattable[color];
  spritefile <<= 16;

  while (*stuff)
  {
    unsigned num = getcharsprite(*stuff);
    gfx_getspriteinfo(spritefile + num);
    x += spr_xsize;
    stuff++;
  }
  x = screensizex/2 - x / 2;

  while (*string)
  {
    unsigned num = getcharsprite(*string);
    gfx_drawspritex(x, y, spritefile + num, xlat);
    x += spr_xsize;
    string++;
  }
}

void initstuff()
{
  int c;
  if (!initsprites())
  {
    win_messagebox("Out of memory!");
    exit(1);
  }

  kbd_init();

  win_fullscreen = 0;
  if (!gfx_init(screensizex,screensizey,70,GFX_DOUBLESIZE))
  {
    win_messagebox("Graphics init error!");
    exit(1);
  }
  win_setmousemode(MOUSE_ALWAYS_HIDDEN);

  if ((!gfx_loadsprites(SPR_C, "editor.spr")) ||
      (!gfx_loadsprites(SPR_FONTS, "editfont.spr")))
  {
    win_messagebox("Error loading editor graphics!");
    exit(1);
  }
  if (!gfx_loadpalette("editor.pal"))
  {
    win_messagebox("Error loading editor palette!");
    exit(1);
  }
}

int inputtext(char *buffer, int maxlength)
{
  int len = strlen(buffer);

  ascii = kbd_getascii();
  k = ascii;

  if (!k) return 0;
  if (k == 27) return -1;
  if (k == 13) return 1;

  if (k >= 32)
  {
    if (len < maxlength-1)
    {
      buffer[len] = k;
      buffer[len+1] = 0;
    }
  }
  if ((k == 8) && (len > 0))
  {
    buffer[len-1] = 0;
  }
  return 0;
}

void drawbox(int x, int y, int sx, int sy, unsigned char col)
{
    gfx_line(x, y, x+sx-1, y, col);
    gfx_line(x, y+sy-1, x+sx-1, y+sy-1, col);
    gfx_line(x, y, x, y+sy-1, col);
    gfx_line(x+sx-1, y, x+sx-1, y+sy-1, col);
}

void drawboxcorners(int x1, int y1, int x2, int y2, unsigned char col)
{
    if (x2 < x1)
        std::swap(x1, x2);
    if (y2 < y1)
        std::swap(y1, y2);
    x2 += 9;
    y2 += 4;
    gfx_line(x1, y1, x2, y1, col);
    gfx_line(x2, y1, x2, y2, col);
    gfx_line(x2, y2, x1, y2, col);
    gfx_line(x1, y2, x1, y1, col);
}

void drawfilledbox(int x, int y, int sx, int sy, unsigned char col)
{
    for (int cy = y; cy < y+sy; ++cy)
        gfx_line(x, cy, x+sx-1, cy, col);
}

void handle_int(int a)
{
  exit(0); /* Atexit functions will be called! */
}


