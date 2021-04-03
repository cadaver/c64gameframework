//
// BME (Blasphemous Multimedia Engine) MOD player module
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <SDL/SDL.h>

#include "bme_io.h"
#include "bme_err.h"
#include "bme_main.h"
#include "bme_snd.h"
#include "bme_cfg.h"
#include "bme_tbl.h"

#define AMIGA_CLOCK         3579545
#define MOD_INSTRUMENTS     31
#define MOD_MAXLENGTH       128
#define MOD_MAXCHANNELS     32
#define MOD_INFOBLOCK       1084
#define MOD_NAMEOFFSET      0
#define MOD_INSTROFFSET     20
#define MOD_LENGTHOFFSET    950
#define MOD_ORDEROFFSET     952
#define MOD_IDENTOFFSET     1080

// MOD identification entry

typedef struct
{
    char *string;
    int channels;
} MOD_IDENT;

// Converted note structure

typedef struct
{
  Uint8 note;
  Uint8 instrument;
  Uint8 command;
  Uint8 data;
} NOTE;

// Our instrument structure

typedef struct
{
    SAMPLE *smp;
    Sint8 vol;
    Uint8 finetune;
} INSTRUMENT;

// Track structure for mod playing

typedef struct
{
    INSTRUMENT *ip;
    Uint8 newnote;
    Uint8 note;
    Uint8 instrument;
    Uint8 newinstrument;
    Uint8 effect;
    Uint8 effectdata;
    Uint8 nybble1;
    Uint8 nybble2;
    Uint8 smp;
    signed char finetune;
    signed char vol;
    unsigned short baseperiod;
    unsigned short period;
    unsigned short targetperiod;
    Uint8 tp;
    Uint8 tpspeed;
    Uint8 volspeedup;
    Uint8 volspeeddown;
    Uint8 portaspeedup;
    Uint8 portaspeeddown;
    Uint8 vibratotype;
    Uint8 vibratospeed;
    Uint8 vibratodepth;
    Uint8 vibratophase;
    Uint8 sampleoffset;
    Uint8 usesampleoffset;
    Uint8 glissando;
    Uint8 tremolotype;
    Uint8 tremolospeed;
    Uint8 tremolodepth;
    Uint8 tremolophase;
    Uint8 patternloopline;
    Uint8 patternloopcount;
    Uint8 retrigcount;
} TRACK;

// Prototypes

static void modplayer(void);
static int init_modplayer(void);
static void startnewnote(TRACK *tptr, CHANNEL *chptr);
static void extendedcommand(TRACK *tptr, CHANNEL *chptr);

// Mod indentification entries, don't know if anyone writes mods with
// for example 2 channels, but they can be created with FT2!

static MOD_IDENT ident[] =
{
    {"2CHN", 2},
    {"M.K.", 4},
    {"M!K!", 4},
    {"4CHN", 4},
    {"6CHN", 6},
    {"8CHN", 8},
    {"10CH", 10},
    {"12CH", 12},
    {"14CH", 14},
    {"16CH", 16},
    {"18CH", 18},
    {"20CH", 20},
    {"22CH", 22},
    {"24CH", 24},
    {"26CH", 26},
    {"28CH", 28},
    {"30CH", 30},
    {"32CH", 32}
};

// Panning table (AMIGA hardware emulation!)

static int panningtable[] =
{
    64, 191, 191, 64
};

// Period table for MODs, lowest octave (0) with all finetunes

static unsigned short periodtable[16][12] =
{
    {6848, 6464, 6096, 5760, 5424, 5120, 4832, 4560, 4304, 4064, 3840, 3624},
    {6800, 6416, 6056, 5720, 5392, 5096, 4808, 4536, 4280, 4040, 3816, 3600},
    {6752, 6368, 6016, 5672, 5360, 5056, 4776, 4504, 4256, 4016, 3792, 3576},
    {6704, 6328, 5968, 5632, 5320, 5024, 4736, 4472, 4224, 3984, 3760, 3552},
    {6656, 6280, 5928, 5592, 5280, 4984, 4704, 4440, 4192, 3960, 3736, 3528},
    {6608, 6232, 5888, 5552, 5240, 4952, 4672, 4408, 4160, 3928, 3704, 3496},
    {6560, 6192, 5840, 5512, 5208, 4912, 4640, 4376, 4128, 3896, 3680, 3472},
    {6512, 6144, 5800, 5472, 5168, 4880, 4600, 4344, 4104, 3872, 3656, 3448},
    {7256, 6848, 6464, 6096, 5760, 5424, 5120, 4832, 4560, 4304, 4032, 3840},
    {7200, 6800, 6416, 6056, 5720, 5400, 5088, 4808, 4536, 4280, 4040, 3816},
    {7152, 6752, 6368, 6016, 5672, 5360, 5056, 4776, 4504, 4256, 4016, 3792},
    {7096, 6704, 6328, 5968, 5632, 5320, 5024, 4736, 4472, 4224, 3984, 3760},
    {7048, 6656, 6280, 5928, 5592, 5280, 4984, 4704, 4440, 4192, 3952, 3736},
    {7000, 6608, 6232, 5888, 5552, 5240, 4952, 4672, 4408, 4160, 3928, 3704},
    {6944, 6560, 6192, 5840, 5512, 5208, 4912, 4640, 4376, 4128, 3896, 3680},
    {6896, 6512, 6144, 5800, 5472, 5168, 4880, 4600, 4344, 4104, 3872, 3656}
};

static Uint8 *mod_info = NULL;
static Uint8 *mod_patterns = NULL;
static Uint8 mt_pos;
static Uint8 mt_line;
static Uint8 mt_length;
static Uint8 mt_channels;
static Uint8 mt_ticktempo;
static Uint8 mt_tickcount;
static Uint8 mt_patternbreak;
static Uint8 mt_patterndelay;
static int mt_patterns;
static int mt_patternlength;
static Uint8 *mt_order;
static INSTRUMENT instrument[MOD_INSTRUMENTS];
static TRACK track[MOD_MAXCHANNELS];
static char modplayer_firsttime = 1;

int snd_loadmod(char *name)
{
    int count;
    int handle;
    NOTE *destptr;
    Uint8 *srcptr;

    bme_error = BME_OUT_OF_MEMORY;
    if (modplayer_firsttime)
    {
        if (!init_modplayer()) return BME_ERROR;
    }

    // Unload previous mod

    snd_freemod();

    bme_error = BME_OPEN_ERROR;
    handle = io_open(name);
    if (handle == -1) return BME_ERROR;

    bme_error = BME_OUT_OF_MEMORY;

    // Get memory for the mod infoblock

    mod_info = malloc(MOD_INFOBLOCK);
    if (!mod_info)
    {
        io_close(handle);
        return BME_ERROR;
    }

    bme_error = BME_WRONG_FORMAT;

    // Read the infoblock

    if (io_read(handle, mod_info, MOD_INFOBLOCK) != MOD_INFOBLOCK)
    {
        snd_freemod();
        io_close(handle);
        return BME_ERROR;
    }

    // Clear byte 20 of header to make sure modulename "ends" and doesn't
    // lead into other memory areas :-)

    mod_info[20] = 0;

    // Determine number of channels

    mt_channels = 0;
    for (count = 0; count < 18; count++)
    {
        if (!memcmp(ident[count].string, &mod_info[MOD_IDENTOFFSET], 4))
        mt_channels = ident[count].channels;
    }

    // If none of these then it's a format we can't handle!!!

    if (!mt_channels)
    {
        snd_freemod();
        io_close(handle);
        return BME_ERROR;
    }

    // Calculate patternlength

    mt_patternlength = mt_channels * 256;

    // Now search thru orderlist to find out amount of patterns

    mt_length = mod_info[MOD_LENGTHOFFSET];
    mt_order = &mod_info[MOD_ORDEROFFSET];
    mt_patterns = 0;
    for (count = 0; count < MOD_MAXLENGTH; count++)
    {
        if (mt_order[count] > mt_patterns) mt_patterns = mt_order[count];
    }
    mt_patterns++;

    bme_error = BME_OUT_OF_MEMORY;

    // Reserve memory for patterns and load them

    mod_patterns = malloc(mt_patternlength * mt_patterns);
    if (!mod_patterns)
    {
        snd_freemod();
        io_close(handle);
        return BME_ERROR;
    }
    bme_error = BME_READ_ERROR;
    if (io_read(handle, mod_patterns, mt_patternlength * mt_patterns) != mt_patternlength * mt_patterns)
    {
        snd_freemod();
        io_close(handle);
        return BME_ERROR;
    }

    // Convert patterns into easier-to-read format

    destptr = (NOTE *)mod_patterns;
    srcptr = mod_patterns;
    for (count = 0; count < mt_patternlength * mt_patterns / 4; count++)
    {
        // Note: FT2 saves the 13th bit of period into 5th bit of
        // samplenumber, and when loading it ofcourse cannot read
        // the period back correctly! We don't use the 13th bit!

        unsigned short period = ((srcptr[0] & 0x0f) << 8) | srcptr[1];
        Uint8 note = 0, instrument, command;
        if (period)
        {
            int findnote;
            int offset = 0x7fffffff;

            for (findnote = 0; findnote < 96; findnote++)
            {
                if (abs(period - (periodtable[0][findnote % 12] >> (findnote / 12))) < offset)
                {
                    note = findnote + 1;
                    offset = abs(period - (periodtable[0][findnote % 12] >> (findnote / 12)));
                }
            }
        }
        instrument = (srcptr[0] & 0xf0) | ((srcptr[2] & 0xf0) >> 4);
        command = srcptr[2] & 0x0f;
        destptr->note = note;
        destptr->instrument = instrument;
        destptr->command = command;
        srcptr += 4;
        destptr++;
    }

    // Now load instruments

    {
        INSTRUMENT *i_ptr = &instrument[0];
        Uint8 *mod_instr_ptr = &mod_info[MOD_INSTROFFSET];

        for (count = 0; count < MOD_INSTRUMENTS; count++)
        {
            int length, repeat, end;
            Uint8 voicemode;

            length = ((mod_instr_ptr[22] << 8) | (mod_instr_ptr[23])) << 1;
            repeat = ((mod_instr_ptr[26] << 8) | (mod_instr_ptr[27])) << 1;
            end = ((mod_instr_ptr[28] << 8) | (mod_instr_ptr[29])) << 1;
            i_ptr->finetune = mod_instr_ptr[24];
            i_ptr->vol = mod_instr_ptr[25];
            if (length)
            {
                if (end > 2)
                {
                    voicemode = VM_LOOP | VM_ON;
                    end += repeat;
                    if (end > length) end = length;
                }
                else
                {
                    voicemode = VM_ONESHOT | VM_ON;
                    end = length;
                }
                bme_error = BME_OUT_OF_MEMORY;
                i_ptr->smp = snd_allocsample(length);
                if (!i_ptr->smp)
                {
                    snd_freemod();
                    io_close(handle);
                    return BME_ERROR;
                }
                io_read(handle, i_ptr->smp->start, length);
                i_ptr->smp->repeat = i_ptr->smp->start + repeat;
                i_ptr->smp->end = i_ptr->smp->start + end;
                i_ptr->smp->voicemode = voicemode;
                snd_ipcorrect(i_ptr->smp);
            }
            else
            {
                i_ptr->smp = NULL;
            }
            i_ptr++;
            mod_instr_ptr += 30;
        }
    }

    // Loading done successfully!

    bme_error = BME_OK;
    io_close(handle);
    return BME_OK;
}

void snd_freemod(void)
{
    int count;

    if (modplayer_firsttime)
    {
        if (!init_modplayer()) return;
    }
    snd_stopmod();

    // Free infoblock & patterns

    if (mod_info)
    {
        free(mod_info);
        mod_info = NULL;
    }
    if (mod_patterns)
    {
        free(mod_patterns);
        mod_patterns = NULL;
    }

    // Remove all samples used by song

    for (count = 0; count < MOD_INSTRUMENTS; count++)
    {
        snd_freesample(instrument[count].smp);
        instrument[count].smp = NULL;
    }
}

void snd_playmod(int pos)
{
    int count;
    TRACK *tptr = &track[0];
    CHANNEL *chptr = &snd_channel[0];

    if (!mod_info) return;
    if (mt_channels > snd_channels) return;
    snd_player = NULL;
    mt_pos = pos;
    mt_line = 0;
    mt_tickcount = 0;
    mt_ticktempo = 6;
    mt_patterndelay = 0;
    snd_bpmcount = 0;
    snd_bpmtempo = 125;
    for (count = 0; count < mt_channels; count++)
    {
        chptr->smp = NULL;
        chptr->voicemode = VM_OFF;
        chptr->vol = 0;
        chptr->panning = panningtable[count % 4];
        tptr->ip = &instrument[0];
        tptr->instrument = 0;
        tptr->effect = 0;
        tptr->effectdata = 0;
        tptr->nybble1 = 0;
        tptr->nybble2 = 0;
        tptr->tp = 0;
        tptr->tpspeed = 0;
        tptr->volspeedup = 0;
        tptr->volspeeddown = 0;
        tptr->glissando = 0;
        tptr->patternloopline = 0;
        tptr->patternloopcount = 0;
        tptr->retrigcount = 0;
        tptr->sampleoffset = 0;
        tptr->usesampleoffset = 0;
        tptr->tremolotype = 0;
        tptr->vibratotype = 0;
        chptr++;
        tptr++;
    }
    snd_player = &modplayer;
}

void snd_stopmod(void)
{
    CHANNEL *chptr = &snd_channel[0];
    int count;

    if (mt_channels > snd_channels) mt_channels = snd_channels;
    if (!mod_info) return;
    snd_player = NULL;
    for (count = 0; count < mt_channels; count++)
    {
        chptr->voicemode = VM_OFF;
        chptr->smp = NULL;
        chptr++;
    }
}

Uint8 snd_getmodpos(void)
{
    return mt_pos;
}

Uint8 snd_getmodline(void)
{
    return mt_line;
}

Uint8 snd_getmodtick(void)
{
    return mt_tickcount;
}

Uint8 snd_getmodchannels(void)
{
    return mt_channels;
}

char *snd_getmodname(void)
{
    if (mod_info) return (char *)(&mod_info[MOD_NAMEOFFSET]);
    else return NULL;
}

// This is called the first time when loading or unloading a mod. It clears
// all sample pointers.

static int init_modplayer(void)
{
    int count;

    mt_channels = 0;
    for (count = 0; count < MOD_INSTRUMENTS; count++)
    {
        instrument[count].smp = NULL;
    }
    modplayer_firsttime = 0;
    return BME_OK;
}

static void modplayer(void)
{
    TRACK *tptr = &track[0];
    CHANNEL *chptr = &snd_channel[0];
    int count;

    // Set new notes or do something else?

    if ((!mt_tickcount) && (!mt_patterndelay))
    {
        NOTE *noteptr;

        // Beware of illegal patternnumbers

        if (mt_order[mt_pos] >= mt_patterns) return;
        noteptr = (NOTE *)(mod_patterns + mt_order[mt_pos] * mt_patternlength + mt_line * mt_channels * sizeof(NOTE));
        mt_patternbreak = 0;
        for (count = mt_channels; count > 0; count--)
        {
            tptr->newnote = 0;
            tptr->retrigcount = 0;

            // Get note (if any)

            if (noteptr->note)
            {
                tptr->note = noteptr->note - 1;
                tptr->newnote = 1;
            }

            // Get effect, effect data etc.

            tptr->effect = noteptr->command;
            tptr->effectdata = noteptr->data;
            tptr->nybble1 = noteptr->data >> 4;
            tptr->nybble2 = noteptr->data & 0xf;
            tptr->newinstrument = noteptr->instrument;

            // Set sampleoffset here

            if (tptr->newinstrument) tptr->usesampleoffset = 0;
            if (tptr->effect == 0x9)
            {
                if (tptr->effectdata) tptr->sampleoffset = tptr->effectdata;
                tptr->usesampleoffset = 1;
            }

            // Start new note if there is one; but check there
            // isn't notedelay (toneportamento is handled by
            // startnewnote()!)

            if ((tptr->effect != 0xe) || (tptr->nybble1 != 0xd) || (tptr->nybble2 == 0))
            {
                if (tptr->newnote) startnewnote(tptr, chptr);
                if (tptr->newinstrument)
                {
                    tptr->instrument = tptr->newinstrument - 1;
                    tptr->ip = &instrument[tptr->instrument];
                    tptr->vol = tptr->ip->vol;
                    chptr->vol = tptr->vol;
                }
            }

            // Reset period if not vibrato or toneportamento

            if ((tptr->effect < 0x3) || (tptr->effect > 0x6))
            {
                tptr->period = tptr->baseperiod;
            }

            // Reset volume if not tremolo

            if (tptr->effect != 0x7)
            {
                chptr->vol = tptr->vol;
            }
            switch (tptr->effect)
            {
                case 0x0:
                break;

                // Set portamento speed up 
                case 0x1:
                if (tptr->effectdata) tptr->portaspeedup = tptr->effectdata;
                break;

                // Set portamento speed down 
                case 0x2:
                if (tptr->effectdata) tptr->portaspeeddown = tptr->effectdata;
                break;

                // Set TP. speed 
                case 0x3:
                if (tptr->effectdata) tptr->tpspeed = tptr->effectdata;
                break;

                // Set vibrato 
                case 0x4:
                if (tptr->nybble1) tptr->vibratospeed = tptr->nybble1;
                if (tptr->nybble2) tptr->vibratodepth = tptr->nybble2;
                break;

                // Set tremolo 
                case 0x7:
                if (tptr->nybble1) tptr->tremolospeed = tptr->nybble1;
                if (tptr->nybble2) tptr->tremolodepth = tptr->nybble2;
                break;

                // Set Panning 
                case 0x8:
                chptr->panning = tptr->effectdata;
                break;

                // Volume slide speed set 
                case 0x5:
                case 0x6:
                case 0xa:
                if (tptr->effectdata)
                {
                    tptr->volspeedup = tptr->nybble1;
                    tptr->volspeeddown = tptr->nybble2;
                }
                break;

                // Pos. jump 
                case 0xb:
                mt_line = 63;
                mt_pos = tptr->effectdata - 1;
                break;

                // Set volume 
                case 0xc:
                chptr->vol = tptr->effectdata;
                if (chptr->vol < 0) chptr->vol = 0;
                if (chptr->vol > 64) chptr->vol = 64;
                tptr->vol = chptr->vol;
                break;

                // Pattern break 
                case 0xd:
                if (!mt_patternbreak)
                {
                    mt_patternbreak = 1;
                    mt_line = tptr->nybble1 * 10 + tptr->nybble2 - 1;
                    mt_pos++;
                }
                break;

                // Extended command 
                case 0xe:
                extendedcommand(tptr, chptr);
                break;

                // Set tempo 
                case 0xf:
                if (!tptr->effectdata)
                {
                    snd_player = NULL;
                    break;
                }
                if (tptr->effectdata < 32) mt_ticktempo = tptr->effectdata;
                else snd_bpmtempo = tptr->effectdata;
                break;
            }
            if (tptr->period) chptr->freq = AMIGA_CLOCK / tptr->period;

            noteptr++;
            chptr++;
            tptr++;
        }
    }


    if (mt_tickcount)
    {
        // If tick isn't 0, update effects like portamento & arpeggio

        for (count = mt_channels; count > 0; count--)
        {
            switch (tptr->effect)
            {
                // Arpeggio 
                case 0x0:
                {
                    if (tptr->effectdata)
                    {
                        char phase = mt_tickcount % 3;
                        switch (phase)
                        {
                            Uint8 arpnote;

                            case 0:
                            tptr->period = tptr->baseperiod;
                            break;

                            case 1:
                            arpnote = tptr->note + tptr->nybble1;
                            if (arpnote > 95) arpnote = 95;
                            tptr->period = periodtable[tptr->finetune][arpnote % 12] >> (arpnote / 12);
                            break;

                            case 2:
                            arpnote = tptr->note + tptr->nybble2;
                            if (arpnote > 95) arpnote = 95;
                            tptr->period = periodtable[tptr->finetune][arpnote % 12] >> (arpnote / 12);
                            break;
                        }
                    }
                }
                break;

                // Portamento up 
                case 0x1:
                tptr->baseperiod -= tptr->portaspeedup;
                if (tptr->baseperiod < 27) tptr->baseperiod = 27;
                tptr->period = tptr->baseperiod;
                break;

                // Portamento down 
                case 0x2:
                tptr->baseperiod += tptr->portaspeeddown;
                if (tptr->baseperiod > 7256) tptr->baseperiod = 7256;
                tptr->period = tptr->baseperiod;
                break;

                // Toneportamento 
                case 0x3:
                if (tptr->tp)
                {
                    if (tptr->baseperiod < tptr->targetperiod)
                    {
                        tptr->baseperiod += tptr->tpspeed;
                        if (tptr->baseperiod >= tptr->targetperiod)
                        {
                            tptr->baseperiod = tptr->targetperiod;
                            tptr->tp = 0;
                        }
                    }
                    if (tptr->baseperiod > tptr->targetperiod)
                    {
                        tptr->baseperiod -= tptr->tpspeed;
                        if (tptr->baseperiod <= tptr->targetperiod)
                        {
                            tptr->baseperiod = tptr->targetperiod;
                            tptr->tp = 0;
                        }
                    }
                    tptr->period = tptr->baseperiod;
                    if (tptr->glissando)
                    {
                        int offset = 0x7fffffff;
                        int sc;
                        short bestperiod = 0;

                        for (sc = 0; sc < 96; sc++)
                        {
                            int newoffset = abs(tptr->period - (periodtable[tptr->finetune][sc % 12] >> (sc / 12)));

                            if (newoffset < offset)
                            {
                                bestperiod = periodtable[tptr->finetune][sc % 12] >> (sc / 12);
                                offset = newoffset;
                            }
                        }
                        tptr->period = bestperiod;
                    }
                }
                break;

                // Vibrato 
                case 0x4:
                tptr->vibratophase += tptr->vibratospeed * 4;
                tptr->period = tptr->baseperiod + ((vibratotable[tptr->vibratotype & 3][tptr->vibratophase] * tptr->vibratodepth) >> 5);
                if (tptr->period < 27) tptr->period = 27;
                if (tptr->period > 7256) tptr->period = 7256;
                break;

                // Toneportamento + volslide 
                case 0x5:
                if (tptr->tp)
                {
                    if (tptr->baseperiod < tptr->targetperiod)
                    {
                        tptr->baseperiod += tptr->tpspeed;
                        if (tptr->baseperiod >= tptr->targetperiod)
                        {
                            tptr->baseperiod = tptr->targetperiod;
                            tptr->tp = 0;
                        }
                    }
                    if (tptr->baseperiod > tptr->targetperiod)
                    {
                        tptr->baseperiod -= tptr->tpspeed;
                        if (tptr->baseperiod <= tptr->targetperiod)
                        {
                            tptr->baseperiod = tptr->targetperiod;
                            tptr->tp = 0;
                        }
                    }
                    tptr->period = tptr->baseperiod;
                    if (tptr->glissando)
                    {
                        int offset = 0x7fffffff;
                        int sc;
                        short bestperiod = 0;

                        for (sc = 0; sc < 96; sc++)
                        {
                            int newoffset = abs(tptr->period - (periodtable[tptr->finetune][sc % 12] >> (sc / 12)));

                            if (newoffset < offset)
                            {
                                bestperiod = periodtable[tptr->finetune][sc % 12] >> (sc / 12);
                                offset = newoffset;
                            }
                        }
                        tptr->period = bestperiod;
                    }
                }
                if (tptr->volspeedup)
                {
                    chptr->vol += tptr->volspeedup;
                    if (chptr->vol > 64) chptr->vol = 64;
                }
                else
                {
                    chptr->vol -= tptr->volspeeddown;
                    if (chptr->vol < 0) chptr->vol = 0;
                }
                tptr->vol = chptr->vol;
                break;

                // Vibrato + volslide 
                case 0x6:
                tptr->vibratophase += tptr->vibratospeed * 4;
                tptr->period = tptr->baseperiod + ((vibratotable[tptr->vibratotype & 3][tptr->vibratophase] * tptr->vibratodepth) >> 5);
                if (tptr->period < 27) tptr->period = 27;
                if (tptr->period > 7256) tptr->period = 7256;
                if (tptr->volspeedup)
                {
                    chptr->vol += tptr->volspeedup;
                    if (chptr->vol > 64) chptr->vol = 64;
                }
                else
                {
                    chptr->vol -= tptr->volspeeddown;
                    if (chptr->vol < 0) chptr->vol = 0;
                }
                tptr->vol = chptr->vol;
                break;

                // Tremolo 
                case 0x7:
                tptr->tremolophase += tptr->tremolospeed * 4;
                chptr->vol = tptr->vol + ((vibratotable[tptr->tremolotype & 3][tptr->tremolophase] * tptr->tremolodepth) >> 4);
                if (chptr->vol < 0) chptr->vol = 0;
                if (chptr->vol > 64) chptr->vol = 64;
                break;

                // Volume Slide 
                case 0xa:
                if (tptr->volspeedup)
                {
                    chptr->vol += tptr->volspeedup;
                    if (chptr->vol > 64) chptr->vol = 64;
                }
                else
                {
                    chptr->vol -= tptr->volspeeddown;
                    if (chptr->vol < 0) chptr->vol = 0;
                }
                tptr->vol = chptr->vol;
                break;

                // Extended command 
                case 0xe:
                extendedcommand(tptr, chptr);
                break;
            }
            if (tptr->period) chptr->freq = AMIGA_CLOCK / tptr->period;
            chptr++;
            tptr++;
        }
    }

    // Advance song

    mt_tickcount++;
    if (mt_tickcount >= mt_ticktempo)
    {
        mt_tickcount = 0;
        if (mt_patterndelay)
        {
            mt_patterndelay--;
        }
        if (!mt_patterndelay)
        {
            mt_line++;
            if (mt_line >= 64)
            {
                mt_line = 0;
                mt_pos++;
            }
            if (mt_pos >= mt_length) mt_pos = 0;
        }
    }
}

static void startnewnote(TRACK *tptr, CHANNEL *chptr)
{
    // Change instrument if necessary

    if (tptr->newinstrument)
    {
        tptr->instrument = tptr->newinstrument - 1;
        tptr->ip = &instrument[tptr->instrument];
    }

    // Now we set the note on

    tptr->finetune = tptr->ip->finetune;
    if (!(tptr->vibratotype & 4)) tptr->vibratophase = 0;
    if (!(tptr->tremolotype & 4)) tptr->tremolophase = 0;
    if ((tptr->effect == 0x3) || (tptr->effect == 0x5))
    {
        // Toneportamento

        tptr->targetperiod = periodtable[tptr->finetune][tptr->note % 12] >> (tptr->note / 12);
        tptr->tp = 1;
    }
    else
    {
        // Normal note start

        tptr->baseperiod = periodtable[tptr->finetune][tptr->note % 12] >> (tptr->note / 12);

        tptr->period = tptr->baseperiod;
        tptr->tp = 0;
        if (tptr->ip->smp)
        {
            chptr->fractpos = 0;
            chptr->repeat = tptr->ip->smp->repeat;
            chptr->end = tptr->ip->smp->end;
            chptr->voicemode = tptr->ip->smp->voicemode;
            if (tptr->usesampleoffset)
            {
                chptr->pos = tptr->ip->smp->start + (tptr->sampleoffset << 8);
                if (chptr->pos >= tptr->ip->smp->end)
                {
                    if (chptr->voicemode & VM_LOOP)
                    {
                        chptr->pos = tptr->ip->smp->repeat;
                    }
                    else
                    {
                        chptr->voicemode = VM_OFF;
                    }
                }
            }
            else
            {
                chptr->pos = tptr->ip->smp->start;
            }
        }

    }
}

// Extended commands can occur both at tick 0 and on other ticks; make it a
// function to prevent having to write it twice in the code

static void extendedcommand(TRACK *tptr, CHANNEL *chptr)
{
    switch(tptr->nybble1)
    {
        // Fine porta up 
        case 0x1:
        if (!mt_tickcount)
        {
            if (tptr->nybble2) tptr->portaspeedup = tptr->nybble2;
            tptr->baseperiod -= tptr->portaspeedup;
            if (tptr->baseperiod < 27) tptr->baseperiod = 27;
        }
        break;

        // Fine porta down 
        case 0x2:
        if (!mt_tickcount)
        {
            if (tptr->nybble2) tptr->portaspeeddown = tptr->nybble2;
            tptr->baseperiod += tptr->portaspeeddown;
            if (tptr->baseperiod > 7256) tptr->baseperiod = 7256;
        }
        break;

        // Set glissando 
        case 0x3:
        if (!mt_tickcount) tptr->glissando = tptr->nybble2;
        break;

        // Set vibrato waveform 
        case 0x4:
        if (!mt_tickcount)
        {
            tptr->vibratotype = vibratotypetable[tptr->nybble2 & 3];
            tptr->vibratotype |= tptr->nybble2 & 4;
        }
        break;

        // Set finetune 
        case 0x5:
        if ((!mt_tickcount) && (tptr->newnote))
        {
            tptr->finetune = (tptr->nybble2 - 8) & 15;
            tptr->baseperiod = periodtable[tptr->finetune][tptr->note % 12] >> (tptr->note / 12);
            tptr->period = tptr->baseperiod;
        }
        break;

        // Patternloop 
        case 0x6:
        if (!mt_tickcount)
        {
            if (!tptr->nybble2) tptr->patternloopline = mt_line;
            else
            {
                if (!tptr->patternloopcount)
                {
                    tptr->patternloopcount = tptr->nybble2;
                    mt_line = tptr->patternloopline - 1;
                }
                else
                {
                    tptr->patternloopcount--;
                    if (tptr->patternloopcount) mt_line = tptr->patternloopline - 1;
                }
            }
        }
        break;

        // Set tremolo waveform 
        case 0x7:
        if (!mt_tickcount)
        {
            tptr->tremolotype = vibratotypetable[tptr->nybble2 & 3];
            tptr->tremolotype |= tptr->nybble2 & 4;
        }
        break;

        // Set panning (Undocumented) 
        case 0x8:
        {
          chptr->panning = (tptr->nybble2 << 4) | tptr->nybble2;
        }
        break;

        // Retrig 
        case 0x9:
        if (tptr->nybble2)
        {
            if ((!tptr->newnote) && (!mt_tickcount))
            {
                tptr->retrigcount = mt_ticktempo;
            }
            if (tptr->retrigcount >= tptr->nybble2)
            {
                tptr->retrigcount = 0;
                startnewnote(tptr, chptr);
            }
        }
        tptr->retrigcount++;
        break;

        // Notedelay 
        case 0xd:
        // Don't start on tick 0 or if there's no note 
        if ((!mt_tickcount) || (!tptr->newnote)) break;
        if (mt_tickcount == tptr->nybble2)
        {
            startnewnote(tptr, chptr);
            if (tptr->newinstrument)
            {
                tptr->vol = tptr->ip->vol;
                chptr->vol = tptr->vol;
            }
        }
        break;

        // Cut note 
        case 0xc:
        if (mt_tickcount == tptr->nybble2)
        {
            chptr->vol = 0;
            tptr->vol = 0;
        }
        break;

        // Fine volslide up 
        case 0xa:
        if (!mt_tickcount)
        {
            if (tptr->nybble2) tptr->volspeedup = tptr->nybble2;
            chptr->vol += tptr->volspeedup;
            if (chptr->vol > 64) chptr->vol = 64;
            tptr->vol = chptr->vol;
        }
        break;

        // Fine volslide down 
        case 0xb:
        if (!mt_tickcount)
        {
            if (tptr->nybble2) tptr->volspeeddown = tptr->nybble2;
            chptr->vol -= tptr->volspeeddown;
            if (chptr->vol < 0) chptr->vol = 0;
            tptr->vol = chptr->vol;
        }
        break;

        // Patterndelay 
        case 0xe:
        if (!mt_tickcount)
        {
            mt_patterndelay = tptr->nybble2 + 1;
        }
        break;
    }
}

