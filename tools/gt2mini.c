// Converter tool from GoatTracker2 song format to minimal player
// Cadaver (loorni@gmail.com) 2/2018

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fileio.h"
#include "gcommon.h"

#define MST_NOFINEVIB 0
#define MST_FINEVIB 1
#define MST_FUNKTEMPO 2
#define MST_PORTAMENTO 3
#define MST_RAW 4

#define WTBL 0
#define PTBL 1
#define FTBL 2
#define STBL 3

#define MAX_MPSONGS 16
#define MAX_MPPATT 127
#define MAX_MPCMD 127
#define MAX_MPPATTLEN 256
#define MAX_MPSONGLEN 256
#define MAX_MPTBLLEN 255

#define MP_ENDPATT 0x00
#define MP_FIRSTNOTE 0x02
#define MP_LASTNOTE 0x7a
#define MP_WAVEPTR 0x7c
#define MP_KEYOFF 0x7e
#define MP_REST 0x7f
#define MP_NOCMD 0x1;
#define MP_MAXDUR 128

INSTR instr[MAX_INSTR];
unsigned char ltable[MAX_TABLES][MAX_TABLELEN];
unsigned char rtable[MAX_TABLES][MAX_TABLELEN];
unsigned char songorder[MAX_SONGS][MAX_CHN][MAX_SONGLEN+2];
unsigned char pattern[MAX_PATT][MAX_PATTROWS*4+4];
unsigned char patttempo[MAX_PATT][MAX_PATTROWS+1];
unsigned char pattinstr[MAX_PATT][MAX_PATTROWS+1];
unsigned char pattkeyon[MAX_PATT][MAX_PATTROWS+1];
unsigned char pattbasetrans[MAX_PATT];
unsigned char pattremaptempo[MAX_PATT];
unsigned char pattremapsrc[MAX_PATT];
unsigned char pattremapdest[MAX_PATT];

char songname[MAX_STR];
char authorname[MAX_STR];
char copyrightname[MAX_STR];
int pattlen[MAX_PATT];
int songlen[MAX_SONGS][MAX_CHN];
int tbllen[MAX_TABLES];
int highestusedpatt;
int highestusedinstr;
int highestusedsong;
int defaultpatternlength = 64;
int remappedpatterns = 0;
int maxdur = MP_MAXDUR;

unsigned char mpwavetbl[MAX_MPTBLLEN+1];
unsigned char mpnotetbl[MAX_MPTBLLEN+1];
unsigned char mpwavenexttbl[MAX_MPTBLLEN+1];
unsigned char mppulselimittbl[MAX_MPTBLLEN+1];
unsigned char mppulsespdtbl[MAX_MPTBLLEN+1];
unsigned char mppulsenexttbl[MAX_MPTBLLEN+1];
unsigned char mpfiltlimittbl[MAX_MPTBLLEN+1];
unsigned char mpfiltspdtbl[MAX_MPTBLLEN+1];
unsigned char mpfiltnexttbl[MAX_MPTBLLEN+1];

unsigned char mppatterns[MAX_MPPATT][MAX_MPPATTLEN];
unsigned char mppattlen[MAX_MPPATT];
unsigned char mppattnext[MAX_MPPATT];
unsigned char mppattprev[MAX_MPPATT];

unsigned char mptracks[MAX_MPSONGS][MAX_MPSONGLEN];
unsigned char mpsongstart[MAX_MPSONGS][3];
unsigned char mpsongtotallen[MAX_MPSONGS];

unsigned char mpinsad[MAX_MPCMD];
unsigned char mpinssr[MAX_MPCMD];
unsigned char mpinsfirstwave[MAX_MPCMD];
unsigned char mpinswavepos[MAX_MPCMD];
unsigned char mpinspulsepos[MAX_MPCMD];
unsigned char mpinsfiltpos[MAX_MPCMD];

unsigned char instrmap[256];
unsigned char instrpulseused[256];
unsigned char instrfirstwavepos[256];
unsigned char instrlastwavepos[256];
unsigned char legatoinstrmap[256];
unsigned char legatostepmap[256];
unsigned char waveposmap[256];
unsigned char pulseposmap[256];
unsigned char filtposmap[256];
unsigned char slidemap[65536];
unsigned char vibratomap[65536];

int mpinssize = 0;
int mpwavesize = 0;
int mppulsesize = 0;
int mpfiltsize = 0;

FILE* out = 0;
int baremode = 0;
int startaddress = -1;
int endaddress = -1;

unsigned short freqtbl[] = {
    0x022d,0x024e,0x0271,0x0296,0x02be,0x02e8,0x0314,0x0343,0x0374,0x03a9,0x03e1,0x041c,
    0x045a,0x049c,0x04e2,0x052d,0x057c,0x05cf,0x0628,0x0685,0x06e8,0x0752,0x07c1,0x0837,
    0x08b4,0x0939,0x09c5,0x0a5a,0x0af7,0x0b9e,0x0c4f,0x0d0a,0x0dd1,0x0ea3,0x0f82,0x106e,
    0x1168,0x1271,0x138a,0x14b3,0x15ee,0x173c,0x189e,0x1a15,0x1ba2,0x1d46,0x1f04,0x20dc,
    0x22d0,0x24e2,0x2714,0x2967,0x2bdd,0x2e79,0x313c,0x3429,0x3744,0x3a8d,0x3e08,0x41b8,
    0x45a1,0x49c5,0x4e28,0x52cd,0x57ba,0x5cf1,0x6278,0x6853,0x6e87,0x751a,0x7c10,0x8371,
    0x8b42,0x9389,0x9c4f,0xa59b,0xaf74,0xb9e2,0xc4f0,0xd0a6,0xdd0e,0xea33,0xf820,0xffff
};

void loadsong(const char* songfilename);
void clearsong(int cs, int cp, int ci, int cf, int cn);
void clearinstr(int num);
void clearpattern(int num);
void countpatternlengths(void);
int makespeedtable(unsigned data, int mode, int makenew);
void primpsonginfo(void);
void clearmpsong(void);
void convertsong(void);
void getpatttempos(void);
void getpattbasetrans(void);
unsigned char copywavetable(unsigned char instr);
unsigned char getlegatoinstr(unsigned char instr);
unsigned char getvibrato(unsigned char delay, unsigned char pos);
unsigned char getslide(unsigned short speed);
void savempsong(const char* songfilename);
void writeblock(FILE* out, const char* blockname, unsigned char* data, int len);

int main(int argc, const char** argv)
{
    int c;

    if (argc < 3)
    {
        printf("Converter from GT2 format to minimal player. Outputs source code.\n"
               "Usage: gt2mini <input> <output> [options]\n"
               "-b     Bare mode; do not add header for music module operation\n"
               "-sxxxx Include hexadecimal start address & Dasm processor statement\n"
               "-exxxx Calculate start address from specified hexadecimal end address\n");
        return 1;
    }

    for (c = 3; c < argc; ++c)
    {
        if (argv[c][0] == '-')
        {
            switch(argv[c][1])
            {
            case 'b':
                baremode = 1;
                break;
            case 's':
                startaddress = strtoul(&argv[c][2], 0, 16);
                break;
            case 'e':
                endaddress = strtoul(&argv[c][2], 0, 16);
                break;
            }
        }
    }

    loadsong(argv[1]);
    primpsonginfo();
    clearmpsong();
    convertsong();
    savempsong(argv[2]);
    return 0;
}

void loadsong(const char* songfilename)
{
    int c;
    int ok = 0;
    char ident[4];
    FILE *handle;

    handle = fopen(songfilename, "rb");

    if (!handle)
    {
        printf("Could not open input song %s\n", songfilename);
        exit(1);
    }

    fread(ident, 4, 1, handle);
    if ((!memcmp(ident, "GTS3", 4)) || (!memcmp(ident, "GTS4", 4)) || (!memcmp(ident, "GTS5", 4)))
    {
      int d;
      int length;
      int amount;
      int loadsize;
      clearsong(1,1,1,1,1);
      ok = 1;

      // Read infotexts
      fread(songname, sizeof songname, 1, handle);
      fread(authorname, sizeof authorname, 1, handle);
      fread(copyrightname, sizeof copyrightname, 1, handle);

      // Read songorderlists
      amount = fread8(handle);
      highestusedsong = amount - 1;
      for (d = 0; d < amount; d++)
      {
        for (c = 0; c < MAX_CHN; c++)
        {
          length = fread8(handle);
          loadsize = length;
          loadsize++;
          fread(songorder[d][c], loadsize, 1, handle);
        }
      }
      // Read instruments
      amount = fread8(handle);
      for (c = 1; c <= amount; c++)
      {
        instr[c].ad = fread8(handle);
        instr[c].sr = fread8(handle);
        instr[c].ptr[WTBL] = fread8(handle);
        instr[c].ptr[PTBL] = fread8(handle);
        instr[c].ptr[FTBL] = fread8(handle);
        instr[c].ptr[STBL] = fread8(handle);
        instr[c].vibdelay = fread8(handle);
        instr[c].gatetimer = fread8(handle);
        instr[c].firstwave = fread8(handle);
        fread(&instr[c].name, MAX_INSTRNAMELEN, 1, handle);
      }
      // Read tables
      for (c = 0; c < MAX_TABLES; c++)
      {
        loadsize = fread8(handle);
        tbllen[c] = loadsize;
        fread(ltable[c], loadsize, 1, handle);
        fread(rtable[c], loadsize, 1, handle);
      }
      // Read patterns
      amount = fread8(handle);
      for (c = 0; c < amount; c++)
      {
        length = fread8(handle) * 4;
        fread(pattern[c], length, 1, handle);
      }
      countpatternlengths();
    }

    // Goattracker v2.xx (3-table) import
    if (!memcmp(ident, "GTS2", 4))
    {
      int d;
      int length;
      int amount;
      int loadsize;
      clearsong(1,1,1,1,1);
      ok = 1;

      // Read infotexts
      fread(songname, sizeof songname, 1, handle);
      fread(authorname, sizeof authorname, 1, handle);
      fread(copyrightname, sizeof copyrightname, 1, handle);

      // Read songorderlists
      amount = fread8(handle);
      highestusedsong = amount - 1;
      for (d = 0; d < amount; d++)
      {
        for (c = 0; c < MAX_CHN; c++)
        {
          length = fread8(handle);
          loadsize = length;
          loadsize++;
          fread(songorder[d][c], loadsize, 1, handle);
        }
      }

      // Read instruments
      amount = fread8(handle);
      for (c = 1; c <= amount; c++)
      {
        instr[c].ad = fread8(handle);
        instr[c].sr = fread8(handle);
        instr[c].ptr[WTBL] = fread8(handle);
        instr[c].ptr[PTBL] = fread8(handle);
        instr[c].ptr[FTBL] = fread8(handle);
        instr[c].vibdelay = fread8(handle);
        instr[c].ptr[STBL] = makespeedtable(fread8(handle), MST_FINEVIB, 0) + 1;
        instr[c].gatetimer = fread8(handle);
        instr[c].firstwave = fread8(handle);
        fread(&instr[c].name, MAX_INSTRNAMELEN, 1, handle);
      }
      // Read tables
      for (c = 0; c < MAX_TABLES-1; c++)
      {
        loadsize = fread8(handle);
        tbllen[c] = loadsize;
        fread(ltable[c], loadsize, 1, handle);
        fread(rtable[c], loadsize, 1, handle);
      }
      // Read patterns
      amount = fread8(handle);
      for (c = 0; c < amount; c++)
      {
        int d;
        length = fread8(handle) * 4;
        fread(pattern[c], length, 1, handle);

        // Convert speedtable-requiring commands
        for (d = 0; d < length; d++)
        {
          switch (pattern[c][d*4+2])
          {
            case CMD_FUNKTEMPO:
            pattern[c][d*4+3] = makespeedtable(pattern[c][d*4+3], MST_FUNKTEMPO, 0) + 1;
            break;

            case CMD_PORTAUP:
            case CMD_PORTADOWN:
            case CMD_TONEPORTA:
            pattern[c][d*4+3] = makespeedtable(pattern[c][d*4+3], MST_PORTAMENTO, 0) + 1;
            break;

            case CMD_VIBRATO:
            pattern[c][d*4+3] = makespeedtable(pattern[c][d*4+3], MST_FINEVIB, 0) + 1;
            break;
          }
        }
      }
      countpatternlengths();
    }
    // Goattracker 1.xx
    if (!memcmp(ident, "GTS!", 4))
    {
      printf("GT1 songs are not supported. Please re-save the song in GT2.\n");
      exit(1);
    }

    // Convert pulsemodulation speed of < v2.4 songs
    if (ident[3] < '4')
    {
      for (c = 0; c < MAX_TABLELEN; c++)
      {
        if ((ltable[PTBL][c] < 0x80) && (rtable[PTBL][c]))
        {
          int speed = ((signed char)rtable[PTBL][c]);
          speed <<= 1;
          if (speed > 127) speed = 127;
          if (speed < -128) speed = -128;
          rtable[PTBL][c] = speed;
        }
      }
    }

    // Convert old legato/nohr parameters
    if (ident[3] < '5')
    {
        for (c = 1; c < MAX_INSTR; c++)
        {
            if (instr[c].firstwave >= 0x80)
            {
                instr[c].gatetimer |= 0x80;
                instr[c].firstwave &= 0x7f;
            }
            if (!instr[c].firstwave) instr[c].gatetimer |= 0x40;
        }
    }
}

void clearsong(int cs, int cp, int ci, int ct, int cn)
{
  int c;

  if (!(cs | cp | ci | ct | cn)) return;

  for (c = 0; c < MAX_CHN; c++)
  {
    int d;
    if (cs)
    {
      for (d = 0; d < MAX_SONGS; d++)
      {
        memset(&songorder[d][c][0], 0, MAX_SONGLEN+2);
        if (!d)
        {
          songorder[d][c][0] = c;
          songorder[d][c][1] = LOOPSONG;
        }
        else
        {
          songorder[d][c][0] = LOOPSONG;
        }
      }
    }
  }
  if (cn)
  {
    memset(songname, 0, sizeof songname);
    memset(authorname, 0, sizeof authorname);
    memset(copyrightname, 0, sizeof copyrightname);
  }
  if (cp)
  {
    for (c = 0; c < MAX_PATT; c++)
      clearpattern(c);
  }
  if (ci)
  {
    for (c = 0; c < MAX_INSTR; c++)
      clearinstr(c);
  }
  if (ct == 1)
  {
    for (c = MAX_TABLES-1; c >= 0; c--)
    {
      memset(ltable[c], 0, MAX_TABLELEN);
      memset(rtable[c], 0, MAX_TABLELEN);
    }
  }
  countpatternlengths();
}

void clearpattern(int p)
{
  int c;

  memset(pattern[p], 0, MAX_PATTROWS*4);
  for (c = 0; c < defaultpatternlength; c++) pattern[p][c*4] = REST;
  for (c = defaultpatternlength; c <= MAX_PATTROWS; c++) pattern[p][c*4] = ENDPATT;
}

void clearinstr(int num)
{
  memset(&instr[num], 0, sizeof(INSTR));
  if (num)
  {
    instr[num].gatetimer = 2;
    instr[num].firstwave = 0x9;
  }
}

void countpatternlengths(void)
{
  int c, d, e;

  highestusedpatt = 0;
  highestusedinstr = 0;
  for (c = 0; c < MAX_PATT; c++)
  {
    for (d = 0; d <= MAX_PATTROWS; d++)
    {
      if (pattern[c][d*4] == ENDPATT) break;
      if ((pattern[c][d*4] != REST) || (pattern[c][d*4+1]) || (pattern[c][d*4+2]) || (pattern[c][d*4+3]))
        highestusedpatt = c;
      if (pattern[c][d*4+1] > highestusedinstr) highestusedinstr = pattern[c][d*4+1];
    }
    pattlen[c] = d;
  }

  for (e = 0; e < MAX_SONGS; e++)
  {
    for (c = 0; c < MAX_CHN; c++)
    {
      for (d = 0; d < MAX_SONGLEN; d++)
      {
        if (songorder[e][c][d] >= LOOPSONG) break;
        if ((songorder[e][c][d] < REPEAT) && (songorder[e][c][d] > highestusedpatt))
          highestusedpatt = songorder[e][c][d];
      }
      songlen[e][c] = d;
    }
  }
}

int makespeedtable(unsigned data, int mode, int makenew)
{
  int c;
  unsigned char l = 0, r = 0;

  if (!data) return -1;

  switch (mode)
  {
    case MST_NOFINEVIB:
    l = (data & 0xf0) >> 4;
    r = (data & 0x0f) << 4;
    break;

    case MST_FINEVIB:
    l = (data & 0x70) >> 4;
    r = ((data & 0x0f) << 4) | ((data & 0x80) >> 4);
    break;

    case MST_FUNKTEMPO:
    l = (data & 0xf0) >> 4;
    r = data & 0x0f;
    break;

    case MST_PORTAMENTO:
    l = (data << 2) >> 8;
    r = (data << 2) & 0xff;
    break;
    
    case MST_RAW:
    r = data & 0xff;
    l = data >> 8;
    break;
  }

  if (makenew == 0)
  {
    for (c = 0; c < MAX_TABLELEN; c++)
    {
      if ((ltable[STBL][c] == l) && (rtable[STBL][c] == r))
        return c;
    }
  }

  for (c = 0; c < MAX_TABLELEN; c++)
  {
    if ((!ltable[STBL][c]) && (!rtable[STBL][c]))
    {
      ltable[STBL][c] = l;
      rtable[STBL][c] = r;
      return c;
    }
  }
  return -1;
}

void primpsonginfo(void)
{
    printf("Songs: %d Patterns: %d Instruments: %d\n", highestusedsong+1, highestusedpatt+1, highestusedinstr);
}

void clearmpsong(void)
{
    memset(mpwavetbl, 0, sizeof mpwavetbl);
    memset(mpnotetbl, 0, sizeof mpnotetbl);
    memset(mpwavenexttbl, 0, sizeof mpwavenexttbl);
    memset(mppulselimittbl, 0, sizeof mppulselimittbl);
    memset(mppulsespdtbl, 0, sizeof mppulsespdtbl);
    memset(mppulsenexttbl, 0, sizeof mppulsenexttbl);
    memset(mpfiltlimittbl, 0, sizeof mpfiltlimittbl);
    memset(mpfiltspdtbl, 0, sizeof mpfiltspdtbl);
    memset(mpfiltnexttbl, 0, sizeof mpfiltnexttbl);
    memset(mppatterns, 0, sizeof mppatterns);
    memset(mptracks, 0, sizeof mptracks);
    memset(mpinsad, 0, sizeof mpinsad);
    memset(mpinssr, 0, sizeof mpinssr);
    memset(mpinsfirstwave, 0, sizeof mpinsfirstwave);
    memset(mpinswavepos, 0, sizeof mpinswavepos);
    memset(mpinspulsepos, 0, sizeof mpinspulsepos);
    memset(mpinsfiltpos, 0, sizeof mpinsfiltpos);
    mpinssize = 0;
    mpwavesize = 0;
    mppulsesize = 0;
    mpfiltsize = 0;
}

void convertsong(void)
{
    int e,c,f;
    int mergepatt;

    memset(instrmap, 0, sizeof instrmap);
    memset(instrpulseused, 0, sizeof instrpulseused);
    memset(instrfirstwavepos, 0, sizeof instrfirstwavepos);
    memset(instrlastwavepos, 0, sizeof instrlastwavepos);
    memset(legatoinstrmap, 0, sizeof legatoinstrmap);
    memset(legatostepmap, 0, sizeof legatostepmap);
    memset(slidemap, 0, sizeof slidemap);
    memset(vibratomap, 0, sizeof vibratomap);
    memset(waveposmap, 0, sizeof waveposmap);
    memset(pulseposmap, 0, sizeof pulseposmap);
    memset(filtposmap, 0, sizeof filtposmap);

    if (highestusedsong > 15)
    {
        printf("More than 16 songs not supported\n");
        exit(1);
    }
    if (highestusedpatt > 126)
    {
        printf("More than 127 patterns not supported\n");
        exit(1);
    }

    getpatttempos();
    getpattbasetrans();

    // Convert trackdata
    for (e = 0; e <= highestusedsong; e++)
    {
        printf("Converting trackdata for song %d\n", e+1);

        int dest = 0;

        for (c = 0; c < MAX_CHN; c++)
        {
            int sp = 0;
            int len = 0;
            unsigned char positionmap[256];

            int trans = 0;
            int lasttrans = -1; // Make sure transpose resets on song loop, even if GT2 song doesn't include it

            mpsongstart[e][c] = dest;

            while (1)
            {
                int rep = 1;
                int patt = 0;

                if (songorder[e][c][sp] >= LOOPSONG)
                    break;
                while (songorder[e][c][sp] >= TRANSDOWN)
                {
                    positionmap[sp] = dest + 1;
                    trans = songorder[e][c][sp++] - TRANSUP;
                }
                while ((songorder[e][c][sp] >= REPEAT) && (songorder[e][c][sp] < TRANSDOWN))
                {
                    positionmap[sp] = dest + 1;
                    rep = songorder[e][c][sp++] - REPEAT + 1;
                }
                patt = songorder[e][c][sp];
                positionmap[sp] = dest + 1;

                if (trans + pattbasetrans[patt] != lasttrans)
                {
                    mptracks[e][dest++] = ((trans + pattbasetrans[patt]) & 0x7f) | 0x80;
                    lasttrans = trans + pattbasetrans[patt];
                }

                while (rep--)
                {
                    mptracks[e][dest++] = patt + 1;
                }
                sp++;
            }
            sp++;
            mptracks[e][dest++] = 0;
            mptracks[e][dest++] = positionmap[songorder[e][c][sp]];
        }
        if (dest > 255)
        {
            printf("Song %d's trackdata does not fit in 255 bytes\n", e+1);
            exit(1);
        }
        mpsongtotallen[e] = dest;
    }

    printf("Converting wavetable\n");

    {
        int sp = 0;

        while (sp < 256 && mpwavesize < 255)
        {
            unsigned char wave = ltable[WTBL][sp];
            unsigned char note = rtable[WTBL][sp];

            if (sp > 0 && wave == 0x00 && ltable[WTBL][sp-1] == 0xff)
                break;

            waveposmap[sp+1] = mpwavesize + 1;
            sp++;

            if (wave < 0xf0 && note == 0x80)
                printf("Warning: 'keep frequency unchanged' in wavetable is unsupported\n");
            if (wave < 0xf0 && note >= 0x81 && note < 0x8c)
            {
                printf("Wavetable has octave 0, can not be converted correctly\n");
                exit(1);
            }
            if (wave >= 0xf0 && wave < 0xff)
                printf("Warning: wavetable commands are unsupported\n");

            if (wave == 0xff)
            {
                waveposmap[sp] = mpwavesize;
                continue;
            }
            else if (wave >= 0x10 && wave <= 0x8f)
            {
                mpwavetbl[mpwavesize] = wave;
                mpnotetbl[mpwavesize] = note < 0x80 ? note : note-11;
                mpwavenexttbl[mpwavesize] = mpwavesize+1+1;
                mpwavesize++;
            }
            else if (wave >= 0xe1 && wave <= 0xef)
            {
                mpwavetbl[mpwavesize] = wave - 0xe0;
                mpnotetbl[mpwavesize] = note < 0x80 ? note : note-11;
                mpwavenexttbl[mpwavesize] = mpwavesize+1+1;
                mpwavesize++;
            }
            else if (wave < 0x10)
            {
                mpwavetbl[mpwavesize] = 0xff - wave;
                mpnotetbl[mpwavesize] = note < 0x80 ? note : note-11;
                mpwavenexttbl[mpwavesize] = mpwavesize+1+1;
                mpwavesize++;
            }
        }

        // Fix jumps
        sp = 0;
        while (sp < 256)
        {
            unsigned char wave = ltable[WTBL][sp];
            unsigned char note = rtable[WTBL][sp];

            if (sp > 0 && wave == 0x00 && ltable[WTBL][sp-1] == 0xff)
                break;
            if (wave == 0xff)
            {
                mpwavenexttbl[waveposmap[sp+1]-1] = note ? waveposmap[note] : 0;
            }
            ++sp;
        }
    }

    printf("Converting pulsetable\n");

    // Create the "stop pulse" optimization step
    mppulselimittbl[mppulsesize] = 0;
    mppulsespdtbl[mppulsesize] = 0;
    mppulsenexttbl[mppulsesize] = 0;
    mppulsesize++;

    {
        int sp = 0;
        int pulsevalue = 0;

        while (sp < 256 && mppulsesize < 127)
        {
            unsigned char time = ltable[PTBL][sp];
            unsigned char spd = rtable[PTBL][sp];

            if (sp > 0 && time == 0x00 && ltable[PTBL][sp-1] == 0xff)
                break;

            pulseposmap[sp+1] = (mppulsesize + 1) | (time & 0x80);
            sp++;

            if (time != 0xff && spd & 0xf)
            {
                printf("Warning: lowest 4 bits of pulse aren't supported\n");
            }

            if (time == 0xff)
            {
                pulseposmap[sp] = mppulsesize;
                continue;
            }
            else if (time & 0x80)
            {
                mppulselimittbl[mppulsesize] = (time & 0xf) | (spd & 0xf0);
                mppulsespdtbl[mppulsesize] = 0;
                mppulsenexttbl[mppulsesize] = mppulsesize+1+1;
                if (mppulsesize > 1 && mppulsenexttbl[mppulsesize-1] == mppulsesize+1)
                    mppulsenexttbl[mppulsesize-1] |= 0x80;
                pulsevalue = ((time & 0xf) << 8) | spd;
                ++mppulsesize;
            }
            else
            {
                if (spd < 0x80)
                    pulsevalue += time*spd;
                else
                    pulsevalue += time*((int)spd-0x100);
                mppulselimittbl[mppulsesize] = (pulsevalue >> 8) | (pulsevalue & 0xf0);
                if (spd < 0x80)
                    mppulsespdtbl[mppulsesize] = spd & 0xf0;
                else
                    mppulsespdtbl[mppulsesize] = (spd & 0xf0) - 1;
                mppulsenexttbl[mppulsesize] = mppulsesize+1+1;
                ++mppulsesize;
            }
        }

        // Fix jumps
        sp = 0;
        while (sp < 256)
        {
            unsigned char time = ltable[PTBL][sp];
            unsigned char spd = rtable[PTBL][sp];

            if (sp > 0 && time == 0x00 && ltable[PTBL][sp-1] == 0xff)
                break;
            if (time == 0xff)
            {
                mppulsenexttbl[(pulseposmap[sp+1]&0x7f)-1] = spd ? pulseposmap[spd] : 0;
            }
            ++sp;
        }
    }
    
    printf("Converting filtertable\n");

    {
        int sp = 0;
        unsigned char cutoffvalue = 0;

        while (sp < 256 && mpfiltsize < 127)
        {
            unsigned char time = ltable[FTBL][sp];
            unsigned char spd = rtable[FTBL][sp];

            if (sp > 0 && time == 0x00 && ltable[FTBL][sp-1] == 0xff)
                break;

            filtposmap[sp+1] = (mpfiltsize + 1) | (time & 0x80);
            sp++;

            if (time == 0xff)
            {
                filtposmap[sp] = mpfiltsize;
                continue;
            }
            else if (time & 0x80)
            {
                mpfiltspdtbl[mpfiltsize] = (time & 0x70) | (spd & 0x8f);
                mpfiltnexttbl[mpfiltsize] = mpfiltsize+1+1;
                if (ltable[FTBL][sp] != 0)
                    printf("Warning: filter init-step not followed by set cutoff-step\n");
                if (mpfiltsize > 1 && mpfiltnexttbl[mpfiltsize-1] == mpfiltsize+1)
                    mpfiltnexttbl[mpfiltsize-1] |= 0x80;
                ++mpfiltsize;
            }
            else if (time == 0 && mpfiltsize > 0)
            {
                // Fill in the initial cutoff value of the init step above
                mpfiltlimittbl[mpfiltsize-1] = spd;
                cutoffvalue = spd;
            }
            else
            {
                if (spd < 0x80)
                    cutoffvalue += time*spd;
                else
                    cutoffvalue += time*((int)spd-0x100);
                mpfiltlimittbl[mpfiltsize] = cutoffvalue;
                mpfiltspdtbl[mpfiltsize] = spd;
                mpfiltnexttbl[mpfiltsize] = mpfiltsize+1+1;
                ++mpfiltsize;
            }
        }

        // Fix jumps
        sp = 0;
        while (sp < 256)
        {
            unsigned char time = ltable[FTBL][sp];
            unsigned char spd = rtable[FTBL][sp];

            if (sp > 0 && time == 0x00 && ltable[FTBL][sp-1] == 0xff)
                break;
            if (time == 0xff)
            {
                mpfiltnexttbl[(filtposmap[sp+1]&0x7f)-1] = spd ? filtposmap[spd] : 0;
            }
            ++sp;
        }
    }

    printf("Converting instruments\n");

    for (e = 1; e <= highestusedinstr; e++)
    {
        int pulseused = 0;
        
        // If instrument has no wavetable pointer, assume it is not used
        if (!instr[e].ptr[WTBL])
            continue;
        mpinsad[mpinssize] = instr[e].ad;
        mpinssr[mpinssize] = instr[e].sr;
        mpinsfirstwave[mpinssize] = instr[e].firstwave;
        mpinswavepos[mpinssize] = instrfirstwavepos[e] = waveposmap[instr[e].ptr[WTBL]];

        // Find out last wavestep for legato, also find out if pulse is used
        {
            int wp = instrfirstwavepos[e];
            while (wp < 255)
            {
                if (mpwavetbl[wp-1] & 0x40)
                    pulseused = 1;
                if (mpwavenexttbl[wp-1] != wp+1)
                    break;
                ++wp;
            }
            instrlastwavepos[e] = wp;
        }

        if (!instr[e].ptr[PTBL])
        {
            if (pulseused)
                mpinspulsepos[mpinssize] = 0; // Keep existing pulse going
            else
                mpinspulsepos[mpinssize] = 1; // Stop pulse-step, for saving rastertime for triangle/sawtooth/noise only instruments
        }
        else
            mpinspulsepos[mpinssize] = pulseposmap[instr[e].ptr[PTBL]];

        if (!instr[e].ptr[FTBL])
            mpinsfiltpos[mpinssize] = 0;
        else
            mpinsfiltpos[mpinssize] = filtposmap[instr[e].ptr[FTBL]];

        instrmap[e] = mpinssize+1;
        mpinssize++;
    }

    for (e = 1; e <= highestusedinstr; e++)
    {
        // Add instrument vibratos
        if (instr[e].ptr[STBL] && instr[e].ptr[WTBL] && instr[e].vibdelay > 0)
        {
            int i = instrmap[e];
            int newvibwavepos = 0;
            int needcopy = 0;
            int waveends = 0;
            int wavejumppos = 0;
            int f;

            for (f = 1; f <= highestusedinstr; f++)
            {
                if (f != e && instr[f].ptr[WTBL] == instr[e].ptr[WTBL])
                {
                    needcopy = 1;
                    break;
                }
            }
            
            if (!needcopy)
                mpwavenexttbl[instrlastwavepos[e]-1] = getvibrato(instr[e].vibdelay, instr[e].ptr[STBL]);
            else
            {
                int jumppos = 0;
                int copystart = mpwavesize+1;
                mpinswavepos[instrmap[e]-1] = copystart;
                for (f = instrfirstwavepos[e]; f <= instrlastwavepos[e]; ++f)
                {
                    mpwavetbl[mpwavesize] = mpwavetbl[f-1];
                    mpnotetbl[mpwavesize] = mpnotetbl[f-1];
                    mpwavenexttbl[mpwavesize] = mpwavesize+1+1;
                    ++mpwavesize;
                }
                instrfirstwavepos[e] = copystart;
                instrlastwavepos[e] = mpwavesize;
                jumppos = mpwavesize-1;
                mpwavenexttbl[jumppos] = getvibrato(instr[e].vibdelay, instr[e].ptr[STBL]);
            }
        }
    }

    // Convert patterns
    printf("Converting patterns\n");

    for (e = 0; e <= highestusedpatt; e++)
    {
        // Reserve more space due to possible step splitting
        unsigned char notecolumn[MAX_PATTROWS*2];
        unsigned char cmdcolumn[MAX_PATTROWS*2];
        unsigned char durcolumn[MAX_PATTROWS*2];
        memset(cmdcolumn, 0, sizeof cmdcolumn);
        memset(durcolumn, 0, sizeof durcolumn);
        int pattlen = 0;
        int lastnoteins = -1;
        int lastnotempins = -1;
        int lastdur;
        int lastwaveptr = 0;
        int d = 0;
        unsigned short freq = 0;
        int targetfreq = 0;
        int tptargetnote = 0;
        int tpstepsleft = 0;

        for (c = 0; c < MAX_PATTROWS+1; c++)
        {
            int note = pattern[e][c*4];
            int gtcmd = pattern[e][c*4+2];
            int gtcmddata = pattern[e][c*4+3];
            if (note == ENDPATT)
            {
                notecolumn[d] = MP_ENDPATT;
                break;
            }
            int instr = pattinstr[e][c];
            int mpinstr = instrmap[instr];
            int dur = patttempo[e][c];
            int waveptr = 0;

            // If tempo not determined, use default 6
            if (!dur)
                dur = 6;

            // If is not a toneportamento with speed, reset frequency before processing effects
            if (note >= FIRSTNOTE+12 && note <= LASTNOTE)
            {
                if (gtcmd != 0x3 || gtcmddata == 0)
                {
                    freq = freqtbl[note-FIRSTNOTE-12];
                }
            }

            if (gtcmd != 0)
            {
                if (gtcmd == 0xf)
                {
                    // No-op, tempo already accounted for
                }
                else if (gtcmd == 0x3)
                {
                    if (gtcmddata == 0 && note >= FIRSTNOTE+12 && note <= LASTNOTE) // Legato note start
                    {
                        mpinstr = getlegatoinstr(instr);
                        tptargetnote = 0;
                        tpstepsleft = 0;
                    }
                    else if (gtcmddata > 0 && note >= FIRSTNOTE+12 && note <= LASTNOTE)
                    {
                        targetfreq = freqtbl[note-FIRSTNOTE-12];
                        unsigned short speed = 0;
                        if (gtcmddata != 0)
                            speed = (ltable[STBL][gtcmddata-1] << 8) | rtable[STBL][gtcmddata-1];
                        tpstepsleft = speed > 0 ? abs(freq-targetfreq) / speed : MAX_PATTROWS;
                        tpstepsleft += 1; // Assume 1 step gets lost

                        if (targetfreq > freq)
                        {
                            waveptr = getslide(speed);
                        }
                        else
                        {
                            speed = -speed;
                            waveptr = getslide(speed);
                        }
                        tptargetnote = note;
                        note = REST; // The actual toneportamento target note is just discarded, as there is no "stop at note" functionality in the player
                    }
                }
                else if (gtcmd == 0x1)
                {
                    unsigned short speed = 0;
                    if (gtcmddata != 0)
                        speed = (ltable[STBL][gtcmddata-1] << 8) | rtable[STBL][gtcmddata-1];

                    waveptr = getslide(speed);
                    freq += (dur-3) * speed; // Assume 3 steps get lost for toneportamento purposes
                }
                else if (gtcmd == 0x2)
                {
                    unsigned short speed = 0;
                    if (gtcmddata != 0)
                        speed = -((ltable[STBL][gtcmddata-1] << 8) | rtable[STBL][gtcmddata-1]);

                    waveptr = getslide(speed);
                    freq += (dur-3) * speed; // Assume 3 steps get lost for toneportamento purposes
                }
                else if (gtcmd == 0x4)
                {
                    waveptr = getvibrato(0, gtcmddata);
                }
                else
                {
                    printf("Warning: unsupported command %x in pattern %d step %d\n", gtcmd, e, c);
                }
            }

            durcolumn[d] = dur;

            // Check if toneportamento ends now
            if (tptargetnote)
            {
                if (tpstepsleft < dur)
                {
                    mpinstr = getlegatoinstr(lastnoteins);

                    if (tpstepsleft == 0)
                    {
                        notecolumn[d] = (tptargetnote-pattbasetrans[e]-FIRSTNOTE-12)*2+MP_FIRSTNOTE;
                        cmdcolumn[d] = mpinstr;
                    }
                    else
                    {
                        if (waveptr && waveptr != lastwaveptr)
                        {
                            notecolumn[d] = MP_WAVEPTR;
                            cmdcolumn[d] = waveptr;
                            durcolumn[d] = tpstepsleft;
                        }
                        else
                        {
                            notecolumn[d] = MP_REST;
                            cmdcolumn[d] = 0;
                            durcolumn[d] = tpstepsleft;
                        }
                        ++d;
                        notecolumn[d] = (tptargetnote-pattbasetrans[e]-FIRSTNOTE-12)*2+MP_FIRSTNOTE;
                        cmdcolumn[d] = mpinstr;
                        durcolumn[d] = dur-tpstepsleft;
                    }
                    ++d;
                    tptargetnote = 0;
                    lastwaveptr = 0; // TP ended, consider next waveptr command individually again
                    lastnotempins = mpinstr;
                    continue;
                }
                else
                {
                    tpstepsleft -= dur;
                }
            }

            if (note >= FIRSTNOTE+12 && note <= LASTNOTE)
            {
                lastwaveptr = 0; // If triggering a note, forget the last waveptr

                notecolumn[d] = (note-pattbasetrans[e]-FIRSTNOTE-12)*2+MP_FIRSTNOTE;
                if (mpinstr != lastnotempins)
                {
                    cmdcolumn[d] = mpinstr;
                    lastnoteins = instr;
                    lastnotempins = mpinstr;
                }
                // If waveptr in combination with note, must split step
                if (waveptr && waveptr != lastwaveptr)
                {
                    int requireddur = instrlastwavepos[instr]-instrfirstwavepos[instr] + 3;
                    if (dur > requireddur)
                    {
                        durcolumn[d] = requireddur;
                        ++d;
                        notecolumn[d] = MP_WAVEPTR;
                        cmdcolumn[d] = waveptr;
                        durcolumn[d] = dur-requireddur;
                    }
                }
            }
            else
            {
                notecolumn[d] = note == KEYOFF ? MP_KEYOFF : MP_REST;
                if (waveptr && waveptr != lastwaveptr)
                {
                    notecolumn[d] = MP_WAVEPTR;
                    cmdcolumn[d] = waveptr;
                }
            }

            ++d;
            lastwaveptr = waveptr;
        }

        for (c = 0; c < MAX_PATTROWS*2;)
        {
            int merge = 0;
            
            if (notecolumn[c] == MP_ENDPATT || notecolumn[c+1] == MP_ENDPATT)
                break;

            if ((durcolumn[c] + durcolumn[c+1]) <= maxdur && cmdcolumn[c+1] == 0)
            {
                if (notecolumn[c] == MP_KEYOFF && notecolumn[c+1] == MP_KEYOFF)
                    merge = 1;
                else if (notecolumn[c] == MP_REST && notecolumn[c+1] == MP_REST)
                    merge = 1;
                else if (notecolumn[c] == MP_KEYOFF && notecolumn[c+1] == MP_REST)
                    merge = 1;
                else if (notecolumn[c] == MP_WAVEPTR && notecolumn[c+1] == MP_REST)
                    merge = 1;
                else if (notecolumn[c] >= MP_FIRSTNOTE && notecolumn[c] <= MP_LASTNOTE && notecolumn[c+1] == MP_REST)
                    merge = 1;
            }

            if (merge)
            {
                int d;
                durcolumn[c] += durcolumn[c+1];
                for (d = c+1; d < MAX_PATTROWS*2-1; d++)
                {
                    notecolumn[d] = notecolumn[d+1];
                    cmdcolumn[d] = cmdcolumn[d+1];
                    durcolumn[d] = durcolumn[d+1];
                }
            }
            else
                c++;
        }

        // Check if two consecutive durations can be averaged
        for (c = 0; c < MAX_PATTROWS*2; c++)
        {
            int sum = durcolumn[c] + durcolumn[c+1];
            int average = 0;

            if (notecolumn[c] == MP_ENDPATT || notecolumn[c+1] == MP_ENDPATT)
                break;

            if (!(sum & 1) && durcolumn[c] != durcolumn[c+1] && cmdcolumn[c+1] == 0 && (notecolumn[c+2] == MP_ENDPATT || durcolumn[c+2] != durcolumn[c+1]))
            {
                if (notecolumn[c] == MP_KEYOFF && notecolumn[c+1] == MP_KEYOFF)
                    average = 1;
                else if (notecolumn[c] == MP_REST && notecolumn[c+1] == MP_REST)
                    average = 1;
                else if (notecolumn[c] == MP_KEYOFF && notecolumn[c+1] == MP_REST)
                    average = 1;
                else if (notecolumn[c] == MP_WAVEPTR && notecolumn[c+1] == MP_REST)
                    average = 1;
                else if (notecolumn[c] >= MP_FIRSTNOTE && notecolumn[c] <= MP_LASTNOTE && notecolumn[c+1] == MP_REST)
                    average = 1;
            }
            if (average == 1)
            {
                durcolumn[c] = durcolumn[c+1] = sum/2;
                c++;
            }
        }
        
        // Remove 1-2-1 duration changes if possible
        for (c = 1; c < MAX_PATTROWS*2; c++)
        {
            if (notecolumn[c] == MP_ENDPATT || notecolumn[c+1] == MP_ENDPATT)
                break;

            if (durcolumn[c+1] == durcolumn[c-1] && durcolumn[c] == 2*durcolumn[c-1] && notecolumn[c] >= MP_FIRSTNOTE && notecolumn[c] <= MP_LASTNOTE)
            {
                int d;
                for (d = MAX_PATTROWS - 1; d > c; d--)
                {
                    notecolumn[d+1] = notecolumn[d];
                    cmdcolumn[d+1] = cmdcolumn[d];
                    durcolumn[d+1]= durcolumn[d];
                }
                notecolumn[c+1] = MP_REST;
                cmdcolumn[c+1] = 0;
                durcolumn[c] = durcolumn[c+1] = durcolumn[c-1];
            }
        }

        // Fix if has too short durations
        for (c = 0; c < MAX_PATTROWS*2; c++)
        {
            if (notecolumn[c] == MP_ENDPATT)
                break;
            if (durcolumn[c] > 0 && durcolumn[c] < 3)
            {
                int orig = durcolumn[c];
                int inc = 3-durcolumn[c];
                durcolumn[c] += inc;
                durcolumn[c+1] -= inc;
                printf("Warning: adjusting too short duration in pattern %d step %d to %d (next step adjusted to %d)\n", e, c, durcolumn[c], durcolumn[c+1]);
            }
        }

        // Clear unneeded durations
        for (c = 0; c < MAX_PATTROWS*2; c++)
        {
            if (notecolumn[c] == MP_ENDPATT)
                break;
            if (c && durcolumn[c] == lastdur)
                durcolumn[c] = 0;
            if (durcolumn[c])
                lastdur = durcolumn[c];
        }

        // Build the final patterndata
        for (c = 0; c < MAX_PATTROWS*2; c++)
        {
            if (notecolumn[c] == MP_ENDPATT)
            {
                mppatterns[e][pattlen++] = MP_ENDPATT;
                break;
            }

            if (notecolumn[c] >= MP_FIRSTNOTE && notecolumn[c] <= MP_LASTNOTE)
            {
                if (cmdcolumn[c])
                {
                    mppatterns[e][pattlen++] = notecolumn[c];
                    mppatterns[e][pattlen++] = cmdcolumn[c];
                }
                else
                    mppatterns[e][pattlen++] = notecolumn[c] + MP_NOCMD;
            }
            else if (notecolumn[c] == MP_WAVEPTR)
            {
                mppatterns[e][pattlen++] = notecolumn[c];
                mppatterns[e][pattlen++] = cmdcolumn[c];
            }
            else
            {
                mppatterns[e][pattlen++] = notecolumn[c];
            }
            if (durcolumn[c])
            {
                mppatterns[e][pattlen++] = 0x101 - durcolumn[c];
            }
        }

        if (pattlen > MAX_MPPATTLEN)
        {
            printf("Pattern %d does not fit in 256 bytes when compressed\n", e);
            exit(1);
        }
        mppattlen[e] = pattlen;
    }

    // Check if some pattern is always followed by another, and combine
    do
    {
        memset(mppattnext, 0, sizeof mppattnext);
        memset(mppattprev, 0, sizeof mppattprev);
        mergepatt = 0;
        for (e = 0; e <= highestusedsong; e++)
        {
            int f;
            for (f = 0; f < mpsongtotallen[e]-1; ++f)
            {
                int patt = mptracks[e][f];
                if (patt >= 1 && patt < 128)
                {
                    int nextpatt = mptracks[e][f+1];
                    if (nextpatt >= 1 && nextpatt < 128)
                    {
                        if (mppattnext[patt] == 0)
                            mppattnext[patt] = nextpatt;
                        else if (mppattnext[patt] != nextpatt)
                            mppattnext[patt] = 0xff;
                    }
                    else
                        mppattnext[patt] = 0xff;
                }
                if (f > 0)
                {
                    int prevpatt = mptracks[e][f-1];
                    if (prevpatt >= 1 && prevpatt < 128)
                    {
                        if (mppattprev[patt] == 0)
                            mppattprev[patt] = prevpatt;
                        else if (mppattprev[patt] != prevpatt)
                            mppattprev[patt] = 0xff;
                    }
                    else
                        mppattprev[patt] = 0xff;
                }
            }
        }
        for (e = 1; e <= highestusedpatt+1; ++e)
        {
            if (mppattnext[e] > 0 && mppattnext[e] < 128 && mppattprev[mppattnext[e]] == e && mppattlen[e-1] + mppattlen[mppattnext[e]-1] <= 256)
            {
                int mergedest = e-1;
                int mergesrc = mppattnext[e]-1;
                int f,g;

                printf("Joining pattern %d into %d\n", mergesrc, mergedest);
                mergepatt = 1;

                memcpy(&mppatterns[mergedest][mppattlen[mergedest]-1], &mppatterns[mergesrc][0], mppattlen[mergesrc]);
                mppattlen[mergedest] = mppattlen[mergedest] + mppattlen[mergesrc] - 1;
                for (f = mergesrc; f < highestusedpatt; ++f)
                {
                    memcpy(&mppatterns[f][0], &mppatterns[f+1][0], MAX_MPPATTLEN);
                    mppattlen[f] = mppattlen[f+1];
                }
                --highestusedpatt;

                for (f = 0; f <= highestusedsong; ++f)
                {
                    for (g = 0; g < mpsongtotallen[f];)
                    {
                        if (mptracks[f][g] == mergesrc+1)
                        {
                            int h;
                            memmove(&mptracks[f][g], &mptracks[f][g+1], mpsongtotallen[f]-g-1);
                            --mpsongtotallen[f];
                            if (g < mpsongstart[f][1])
                                --mpsongstart[f][1];
                            if (g < mpsongstart[f][2])
                                --mpsongstart[f][2];
                            // Adjust jump points
                            for (h = 0; h < mpsongtotallen[f]-1; ++h)
                            {
                                if (mptracks[f][h] == 0 && mptracks[f][h+1] > g)
                                    --mptracks[f][h+1];
                            }
                        }
                        else if (mptracks[f][g] == 0)
                        {
                            // Jump over the jump point
                            g += 2;
                        }
                        else
                        {
                            if (mptracks[f][g] > mergesrc+1 && mptracks[f][g] < 128)
                                --mptracks[f][g];
                            ++g;
                        }
                    }
                }
                break;
            }
        }
    }
    while (mergepatt);
}

unsigned char getlegatoinstr(unsigned char instr)
{
    if (legatoinstrmap[instr])
        return legatoinstrmap[instr];

    if (!legatostepmap[instrlastwavepos[instr]])
    {
        if (mpwavetbl[instrlastwavepos[instr]-1] == 0x00 || mpwavetbl[instrlastwavepos[instr]-1] >= 0x90)
            legatostepmap[instrlastwavepos[instr]] = instrlastwavepos[instr];
        else
        {
            if (mpwavesize >= 255)
            {
                printf("Out of wavetable space while converting legato instrument\n");
                exit(1);
            }
            mpwavetbl[mpwavesize] = 0xff;
            mpnotetbl[mpwavesize] = mpnotetbl[instrlastwavepos[instr]-1];
            mpwavenexttbl[mpwavesize] = mpwavenexttbl[instrlastwavepos[instr]-1];
            legatostepmap[instrlastwavepos[instr]] = mpwavesize + 1;
            ++mpwavesize;
        }
    }

    mpinsad[mpinssize] = 0;
    mpinssr[mpinssize] = 0;
    mpinsfirstwave[mpinssize] = 0;
    mpinswavepos[mpinssize] = legatostepmap[instrlastwavepos[instr]];
    mpinspulsepos[mpinssize] = 0;
    mpinsfiltpos[mpinssize] = 0;
    legatoinstrmap[instr] = mpinssize+0x81;
    ++mpinssize;

    return legatoinstrmap[instr];
}

unsigned char getvibrato(unsigned char delay, unsigned char param)
{
    if (delay == 0)
        delay = 1;

    if (vibratomap[(delay<<8) + param])
        return vibratomap[(delay<<8) + param];

    vibratomap[(delay<<8) + param] = mpwavesize+1;

    if (delay > 1 && mpwavesize < 254)
    {
        mpwavetbl[mpwavesize] = 0x100 - delay;
        mpnotetbl[mpwavesize] = 0;
        mpwavenexttbl[mpwavesize] = mpwavesize+1+1;
        mpwavesize++;
    }

    if (mpwavesize < 255)
    {
        mpwavetbl[mpwavesize] = 0;
        mpnotetbl[mpwavesize] = 0xff - ltable[STBL][param-1];
        mpwavenexttbl[mpwavesize] = rtable[STBL][param-1];
        mpwavesize++;
    }

    return vibratomap[(delay<<8) + param];
}

unsigned char getslide(unsigned short speed)
{
    if (slidemap[speed])
        return slidemap[speed];

    mpwavetbl[mpwavesize] = 0x90;
    mpnotetbl[mpwavesize] = (speed-1) & 0xff;
    mpwavenexttbl[mpwavesize] = (speed-1) >> 8;
    slidemap[speed] = mpwavesize+1;
    ++mpwavesize;

    return slidemap[speed];
}

void getpattbasetrans(void)
{
    int c,e;
    memset(pattbasetrans, 0, sizeof pattbasetrans);

    for (e = 0; e <= highestusedpatt; e++)
    {
        int basetrans = 0;
        for (c = 0; c < MAX_PATTROWS+1; c++)
        {
            int note = pattern[e][c*4];
            if (note >= FIRSTNOTE && note < FIRSTNOTE+12)
            {
                printf("Pattern %d: octave 0 is not supported\n", e);
                exit(1);
            }
            if (note >= FIRSTNOTE && note <= LASTNOTE)
            {
                if (note >= FIRSTNOTE+6*12)
                {
                    while (note - basetrans >= FIRSTNOTE+6*12)
                        basetrans += 12;
                }
            }
        }
        for (c = 0; c < MAX_PATTROWS+1; c++)
        {
            int note = pattern[e][c*4];
            if (note >= FIRSTNOTE && note <= LASTNOTE)
            {
                if (note - basetrans < FIRSTNOTE+12)
                {
                    printf("Pattern %d has too wide note range\n", e);
                    exit(1);
                }
            }
        }
        if (basetrans > 0)
            printf("Pattern %d basetranspose %d\n", e, basetrans);
        pattbasetrans[e] = basetrans;
    }
}

void getpatttempos(void)
{
    int e,c;

    memset(patttempo, 0, sizeof patttempo);
    memset(pattinstr, 0, sizeof pattinstr);

    // Simulates playroutine going through the songs
    for (e = 0; e <= highestusedsong; e++)
    {
        printf("Determining tempo & instruments for song %d\n", e+1);
        int sp[3] = {-1,-1,-1};
        int pp[3] = {0xff,0xff,0xff};
        int pn[3] = {0,0,0};
        int rep[3] = {0,0,0};
        int stop[3] = {0,0,0};
        int instr[3] = {1,1,1};
        int tempo[3] = {6,6,6};
        int tick[3] = {0,0,0};
        int keyon[3] = {0,0,0};

        while (!stop[0] || !stop[1] || !stop[2])
        {
            for (c = 0; c < MAX_CHN; c++)
            {
                if (!stop[c] && !tick[c])
                {
                    if (pp[c] == 0xff || pattern[pn[c]][pp[c]*4] == ENDPATT)
                    {
                        if (!rep[c])
                        {
                            sp[c]++;
                            if (songorder[e][c][sp[c]] >= LOOPSONG)
                            {
                                stop[c] = 1;
                                break;
                            }
                            while (songorder[e][c][sp[c]] >= TRANSDOWN)
                                sp[c]++;
                            while ((songorder[e][c][sp[c]] >= REPEAT) && (songorder[e][c][sp[c]] < TRANSDOWN))
                            {
                                rep[c] = songorder[e][c][sp[c]] - REPEAT;
                                sp[c]++;
                            }
                        }
                        else
                            rep[c]--;

                        pn[c] = songorder[e][c][sp[c]];
                        pp[c] = 0;
                    }

                    if (!stop[c])
                    {
                        int note = pattern[pn[c]][pp[c]*4];
                        if (note >= FIRSTNOTE && note <= LASTNOTE && pattern[pn[c]][pp[c]*4+2] != CMD_TONEPORTA)
                            keyon[c] = 1;
                        if (note == KEYON)
                            keyon[c] = 1;
                        if (note == KEYOFF)
                            keyon[c] = 0;

                        instr[c] = pattern[pn[c]][pp[c]*4+1];

                        if (pattern[pn[c]][pp[c]*4+2] == 0xf)
                        {
                            int newtempo = pattern[pn[c]][pp[c]*4+3];
                            if (newtempo < 0x80)
                            {
                                tempo[0] = newtempo;
                                tempo[1] = newtempo;
                                tempo[2] = newtempo;
                            }
                            else
                                tempo[c] = newtempo & 0x7f;
                        }
                    }
                }
            }

            for (c = 0; c < MAX_CHN; c++)
            {
                if (!stop[c])
                {
                    if (pp[c] < MAX_PATTROWS)
                    {
                        if (patttempo[pn[c]][pp[c]] != 0 && patttempo[pn[c]][pp[c]] != tempo[c])
                        {
                            // We have detected pattern playback with multiple tempos
                            int f;
                            int pattfound = 0;
    
                            for (f = 0; f < remappedpatterns; f++)
                            {
                                if (pattremaptempo[f] == tempo[c] && pattremapsrc[f] == pn[c])
                                {
                                    pattfound = 1;
                                    pn[c] = pattremapdest[f];
                                    songorder[e][c][sp[c]] = pn[c];
                                    break;
                                }
                            }
    
                            if (!pattfound)
                            {
                                if (highestusedpatt >= MAX_PATT-1)
                                {
                                    printf("Not enough patterns free to perform tempo remapping");
                                    exit(1);
                                }
                                printf("Remapping pattern %d to %d as it's played at multiple tempos\n", pn[c], highestusedpatt+1);
                                memcpy(&pattern[highestusedpatt+1][0], &pattern[pn[c]][0], MAX_PATTROWS*4+4);
                                pattremaptempo[remappedpatterns] = tempo[c];
                                pattremapsrc[remappedpatterns] = pn[c];
                                pattremapdest[remappedpatterns] = highestusedpatt+1;
                                remappedpatterns++;
                                pn[c] = highestusedpatt+1;
                                songorder[e][c][sp[c]] = pn[c];
                                highestusedpatt++;
                            }
                        }
                        
                        if (!tick[c])
                        {
                            patttempo[pn[c]][pp[c]] = tempo[c];
                            pattinstr[pn[c]][pp[c]] = instr[c];
                            pattkeyon[pn[c]][pp[c]] = keyon[c];
                        }
                    }

                    tick[c]++;
                    if (tick[c] >= tempo[c])
                    {
                        tick[c] = 0;
                        pp[c]++;
                    }
                }
            }
        }
    }
}

void savempsong(const char* songfilename)
{
    int c;
    int totalsize = 0;

    if (!baremode)
        totalsize += 6;
    totalsize += (highestusedsong+1) * 5;
    totalsize += (highestusedpatt+1) * 2;
    totalsize += mpinssize * 6;
    totalsize += mpwavesize * 3;
    totalsize += mppulsesize * 3;
    totalsize += mpfiltsize * 3;
    for (c = 0; c <= highestusedsong; ++c)
        totalsize += mpsongtotallen[c];
    for (c = 0; c <= highestusedpatt; ++c)
        totalsize += mppattlen[c];

    out = fopen(songfilename, "wt");
    if (!out)
    {
        printf("Could not open destination file %s\n", songfilename);
        exit(1);
    }

    if (endaddress >= 0)
        startaddress = endaddress - totalsize;

    if (startaddress >= 0)
    {
        fprintf(out, "  org $%04x\n", startaddress);
        fprintf(out, "  processor 6502\n");
        fprintf(out, "\n");
    }

    if (!baremode)
    {
        fprintf(out, "musicHeader:\n");
        fprintf(out, "  dc.b %d\n", (highestusedsong+1)*5);
        fprintf(out, "  dc.b %d\n", highestusedpatt+1);
        fprintf(out, "  dc.b %d\n", mpinssize);
        fprintf(out, "  dc.b %d\n", mpwavesize);
        fprintf(out, "  dc.b %d\n", mppulsesize);
        fprintf(out, "  dc.b %d\n", mpfiltsize);
        fprintf(out, "\n");
    }

    fprintf(out, "songTbl:\n");
    for (c = 0; c <= highestusedsong; ++c)
    {
        fprintf(out, "  dc.w song%d-1\n", c);
        fprintf(out, "  dc.b $%02x\n", mpsongstart[c][0]+1);
        fprintf(out, "  dc.b $%02x\n", mpsongstart[c][1]+1);
        fprintf(out, "  dc.b $%02x\n", mpsongstart[c][2]+1);
    }
    fprintf(out, "\n");

    fprintf(out, "pattTblLo:\n");
    for (c = 0; c <= highestusedpatt; ++c)
        fprintf(out, "  dc.b <patt%d\n", c);
    fprintf(out, "\n");
    fprintf(out, "pattTblHi:\n");
    for (c = 0; c <= highestusedpatt; ++c)
        fprintf(out, "  dc.b >patt%d\n", c);
    fprintf(out, "\n");

    writeblock(out, "insAD", mpinsad, mpinssize);
    writeblock(out, "insSR", mpinssr, mpinssize);
    writeblock(out, "insFirstWave", mpinsfirstwave, mpinssize);
    writeblock(out, "insWavePos", mpinswavepos, mpinssize);
    writeblock(out, "insPulsePos", mpinspulsepos, mpinssize);
    writeblock(out, "insFiltPos", mpinsfiltpos, mpinssize);
    writeblock(out, "waveTbl", mpwavetbl, mpwavesize);
    writeblock(out, "noteTbl", mpnotetbl, mpwavesize);
    writeblock(out, "waveNextTbl", mpwavenexttbl, mpwavesize);
    writeblock(out, "pulseLimitTbl", mppulselimittbl, mppulsesize);
    writeblock(out, "pulseSpdTbl", mppulsespdtbl, mppulsesize);
    writeblock(out, "pulseNextTbl", mppulsenexttbl, mppulsesize);
    writeblock(out, "filtLimitTbl", mpfiltlimittbl, mpfiltsize);
    writeblock(out, "filtSpdTbl", mpfiltspdtbl, mpfiltsize);
    writeblock(out, "filtNextTbl", mpfiltnexttbl, mpfiltsize);

    for (c = 0; c <= highestusedsong; ++c)
    {
        char namebuf[80];
        sprintf(namebuf, "song%d", c);
        writeblock(out, namebuf, &mptracks[c][0], mpsongtotallen[c]);
    }

    for (c = 0; c <= highestusedpatt; ++c)
    {
        char namebuf[80];
        sprintf(namebuf, "patt%d", c);
        writeblock(out, namebuf, &mppatterns[c][0], mppattlen[c]);
    }
}

void writeblock(FILE* out, const char* name, unsigned char* data, int len)
{
    int c;
    fprintf(out, "%s:\n", name);
    for (c = 0; c < len; ++c)
    {
        if (c == 0)
            fprintf(out, "  dc.b $%02x", data[c]);
        else if ((c & 7) == 0)
            fprintf(out, "\n  dc.b $%02x", data[c]);
        else
            fprintf(out, ",$%02x", data[c]);
    }
    fprintf(out, "\n\n");
}