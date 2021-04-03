//
// BME (Blasphemous Multimedia Engine) S3M player module
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

#define S3M_MAXCHANNELS 32
#define S3M_MAXPATTERNS 100
#define S3M_MAXINSTRUMENTS 100
#define S3M_MAXORDER 256
#define HIGHPERIOD 1
#define LOWPERIOD 29015
#define S3M_LEFT 64
#define S3M_RIGHT 191

typedef struct
{
    Uint8 songname[28];
    Uint8 byte1a;
    Uint8 filetype;
    Uint16 unused1;
    Uint16 ordernum;
    Uint16 instnum;
    Uint16 pattnum;
    Uint16 flags;
    Uint16 createdwith;
    Uint16 fileversion;
    Uint8 id[4];
    Uint8 globalvol;
    Uint8 initialspeed;
    Uint8 initialtempo;
    Uint8 mastermult;
    Uint8 ultraclicks;
    Uint8 panningmagic;
    Uint8 unused[8];
    Uint16 special;
    Uint8 chsettings[S3M_MAXCHANNELS];
} S3M_HEADER;

typedef struct
{
    Uint8 type;
    Uint8 dosname[12];
    Uint8 paraptrhigh;
    Uint16 paraptr;
    Uint32 length;
    Uint32 loopstart;
    Uint32 loopend;
    Sint8 vol;
    Uint8 disknum;
    Uint8 pack;
    Uint8 flags;
    Uint32 c2rate;
    Uint32 unused;
    Uint16 guspos;
    Uint16 int512;
    Uint32 lastused;
    Uint8 name[28];
    Uint8 id[4];
} S3M_INSTRUMENT;

typedef struct
{
    Uint8 note;
    Uint8 instrument;
    Uint8 voleffect;
    Uint8 effect;
    Uint8 effectdata;
} NOTE;

typedef struct
{
    SAMPLE *sp;
    Sint8 vol;
    unsigned c2rate;
} INSTRUMENT;

typedef struct
{
    INSTRUMENT *ip;
    SAMPLE *sp;
    Uint8 newnote;
    Uint8 note;
    Uint8 instrument;
    Uint8 newinstrument;
    Uint8 voleffect;
    Uint8 effect;
    Uint8 effectdata;
    Uint8 nybble1;
    Uint8 nybble2;
    Sint8 notevol;
    Sint8 vol;
    Uint16 c2rate;
    Sint16 baseperiod;
    Sint16 period;
    Sint16 targetperiod;
    Uint8 tp;
    Uint8 tpspeed;
    Uint8 volspeedup;
    Uint8 volspeeddown;
    Uint8 portaspeed;
    Uint8 vibratotype;
    Uint8 vibratospeed;
    Uint8 vibratodepth;
    Uint8 vibratophase;
    Uint8 sampleoffset;
    Uint8 usesampleoffset;
    Uint8 tremolotype;
    Uint8 tremolospeed;
    Uint8 tremolodepth;
    Uint8 tremolophase;
    Uint8 retrigcount;
    Uint8 retriginterval;
    Uint8 retrigvolchange;
    Uint8 tremorcount;
    Uint8 tremorontime;
    Uint8 tremorofftime;
    Uint8 tremorstatus;
    Uint8 arpeggiointerval;
} TRACK;

// Prototypes

static int init_s3mplayer(void);
static void s3mplayer(void);
static void startnewnote(TRACK *tptr, CHANNEL *chptr);
static void extendedcommand(TRACK *tptr, CHANNEL *chptr);
static void volslide(TRACK *tptr);

// Period table for S3Ms

static Uint16 s3mperiodtable[] =
{
    1712, 1616, 1524, 1440, 1356, 1280, 1208, 1140, 1076, 1016, 960, 907
};

// S3M Set Finetune values

static Uint16 s3mfinetunetable[] =
{
    7895, 7941, 7985, 8046, 8107, 8169, 8232, 8280, 8363, 8413, 8463, 8529,
    8581, 8651, 8723, 8757
};

static S3M_HEADER header;
static char s3m_loaded = 0;
static char s3mplayer_firsttime = 1;
static unsigned s3m_channels;
static Uint8 s3m_chpanning[S3M_MAXCHANNELS];
static Uint8 s3m_order[S3M_MAXORDER];
static Uint16 instparapointers[S3M_MAXINSTRUMENTS];
static Uint16 pattparapointers[S3M_MAXINSTRUMENTS];
static Uint8 defaultchannelpanpos[S3M_MAXCHANNELS];
static INSTRUMENT s3m_instrument[S3M_MAXINSTRUMENTS];
static TRACK s3m_track[S3M_MAXCHANNELS];
static unsigned s3m_pattlength;
static Uint8 *s3m_pattptr = NULL;
static Uint16 loadpattlen;
static Uint16 s3m_pos;
static Uint16 s3m_line;
static Uint16 s3m_ticktempo;
static Uint16 s3m_tickcount;
static Uint8 s3m_globalvol;
static Uint8 s3m_patternbreak;
static Uint8 s3m_patterndelay;
static Uint8 s3m_patternloopline;
static Uint8 s3m_patternloopcount;

int snd_loads3m(char *name)
{
    int handle;
    int count;
    Uint8 chconverttable[S3M_MAXCHANNELS];
    INSTRUMENT *ip;
    S3M_INSTRUMENT *instbuffer;

    bme_error = BME_OUT_OF_MEMORY;
    if (s3mplayer_firsttime)
    {
        if (!init_s3mplayer()) return 0;
    }

    snd_frees3m();

    // Try to open the file

    bme_error = BME_OPEN_ERROR;
    handle = io_open(name);
    if (handle == -1)
    {
        return 0;
    }

    // Read in the header
    memset(&header, 0, sizeof header);

    io_read(handle, &header.songname, 28);
    header.byte1a = io_read8(handle);
    header.filetype = io_read8(handle);
    header.unused1 = io_readle16(handle);
    header.ordernum = io_readle16(handle);
    header.instnum = io_readle16(handle);
    header.pattnum = io_readle16(handle);
    header.flags = io_readle16(handle);
    header.createdwith = io_readle16(handle);
    header.fileversion = io_readle16(handle);
    io_read(handle, &header.id, 4);
    header.globalvol = io_read8(handle);
    header.initialspeed = io_read8(handle);
    header.initialtempo = io_read8(handle);
    header.mastermult = io_read8(handle);
    header.ultraclicks = io_read8(handle);
    header.panningmagic = io_read8(handle);
    io_read(handle, &header.unused, 8);
    header.special = io_readle16(handle);
    io_read(handle, &header.chsettings, S3M_MAXCHANNELS);

    // Check it is a S3M

    bme_error = BME_WRONG_FORMAT;
    if ((header.byte1a != 0x1a && header.byte1a != 0) || (header.filetype != 0x10) || (memcmp("SCRM", header.id, 4)))
    {
        io_close(handle);
        return 0;
    }
    header.byte1a = 0x0; /* Serves as the songname endzero from now on */
    s3m_channels = 0;
    for (count = 0; count < S3M_MAXCHANNELS; count++)
    {
        chconverttable[count] = 0xff;
        if (header.chsettings[count] < 16)
        {
            chconverttable[count] = s3m_channels;
            /* Stereo may be disabled */
            if (header.mastermult & 128) {
                if (header.chsettings[count] & 8) s3m_chpanning[s3m_channels] = S3M_RIGHT;
                else s3m_chpanning[s3m_channels] = S3M_LEFT;
            } else s3m_chpanning[s3m_channels] = MIDDLE;
            s3m_channels++;
        }
    }

    // Read in the orderlist

    memset(&s3m_order, 255, sizeof s3m_order);
    bme_error = BME_READ_ERROR;
    if (io_read(handle, &s3m_order, header.ordernum) != header.ordernum)
    {
        io_close(handle);
        return 0;
    }

    // Read in the instrument & pattern parapointers

    if (io_read(handle, &instparapointers, header.instnum * sizeof(Sint16)) != (int)(header.instnum * sizeof(Sint16)))
    {
        io_close(handle);
        return 0;
    }
    if (io_read(handle, &pattparapointers, header.pattnum * sizeof(Sint16)) != (int)(header.pattnum * sizeof(Sint16)))
    {
        io_close(handle);
        return 0;
    }

    // Reserve intermediate buffer for S3M format instruments (to prevent
    // backwards seeks patterns & samples are loaded later)

    bme_error = BME_OUT_OF_MEMORY;
    instbuffer = malloc(header.instnum * sizeof(S3M_INSTRUMENT));
    if (!instbuffer)
    {
        io_close(handle);
        return 0;
    }

    // Read in and use default channel pan positions (panning magic) if enabled

    if (header.panningmagic == 252)
    {
      if (io_read(handle, &defaultchannelpanpos, s3m_channels * sizeof(char)) != (int)(s3m_channels * sizeof(char)))
      {
        io_close(handle);
        return 0;
      }
      for (count = 0; count < s3m_channels; count++)
      {
        if (defaultchannelpanpos[count] & 32) {
          /* Channel panning pos defined */
          s3m_chpanning[count] = ((defaultchannelpanpos[count] & 15) << 4) |
          (defaultchannelpanpos[count] & 15);
        } else {
          /* Panning pos for this channel not defined. Use default */
          switch (s3m_chpanning[count])
          {
          case MIDDLE:
        s3m_chpanning[count] = 0x77; /* 128 would be faster though */
        break;
          case S3M_LEFT:
        s3m_chpanning[count] = 0x33;
        break;
          case S3M_RIGHT:
        s3m_chpanning[count] = 0xBB;
        break;
          }
        }
      }
    }

    // Read instruments

    for (count = 0; count < header.instnum; count++)
    {
        S3M_INSTRUMENT *s3mip = instbuffer + count;

        // Seek to correct pos to find instrument

        bme_error = BME_READ_ERROR;
        if (io_lseek(handle, instparapointers[count] << 4, SEEK_SET) == -1)
        {
            free(instbuffer);
            io_close(handle);
            return 0;
        }

        // Read the instrument

        s3mip->type = io_read8(handle);
        io_read(handle, &s3mip->dosname, 12);
        s3mip->paraptrhigh = io_read8(handle);
        s3mip->paraptr = io_readle16(handle);
        s3mip->length = io_readle32(handle);
        s3mip->loopstart = io_readle32(handle);
        s3mip->loopend = io_readle32(handle);
        s3mip->vol = io_read8(handle);
        s3mip->disknum = io_read8(handle);
        s3mip->pack = io_read8(handle);
        s3mip->flags = io_read8(handle);
        s3mip->c2rate = io_readle32(handle);
        s3mip->unused = io_readle32(handle);
        s3mip->guspos = io_readle16(handle);
        s3mip->int512 = io_readle16(handle);
        s3mip->lastused = io_readle32(handle);
        io_read(handle, &s3mip->name, 28);
        io_read(handle, &s3mip->id, 4);

        if (s3mip->flags & 4)
        {
            s3mip->length <<= 1;
            s3mip->loopstart <<= 1;
            s3mip->loopend <<= 1;
        }
    }

    // Reserve memory for patterns

    bme_error = BME_OUT_OF_MEMORY;
    s3m_pattlength = 64 * 5 * s3m_channels;
    s3m_pattptr = malloc(s3m_pattlength * header.pattnum);
    if (!s3m_pattptr)
    {
        free(instbuffer);
        io_close(handle);
        return 0;
    }

    // Empty all the patterns

    {
        NOTE *noteptr = (NOTE *)s3m_pattptr;
        for (count = header.pattnum * s3m_channels * 64; count; count--)
        {
            noteptr->note = 0xff;
            noteptr->voleffect = 0xff;
            noteptr->instrument = 0x0;
            noteptr->effect = 0xff;
            noteptr++;
        }
    }

    // Read in & unpack patterns

    for (count = 0; count < header.pattnum; count++)
    {
        int rowcount;
        Uint8 *packbuffer;
        NOTE *destptr;
        Uint8 *srcptr;

        if (pattparapointers[count])
        {
            // Seek to correct pos to find pattern

            bme_error = BME_READ_ERROR;
            if (io_lseek(handle, pattparapointers[count] << 4, SEEK_SET) == -1)
            {
                free(instbuffer);
                snd_frees3m();
                io_close(handle);
                return 0;
            }
            if (io_read(handle, &loadpattlen, sizeof loadpattlen) != sizeof loadpattlen)
            {
                free(instbuffer);
                snd_frees3m();
                io_close(handle);
                return 0;
            }

            if (loadpattlen > 2)
            {
                // Weird, packed data length has the length indicator
                // word included (I really checked this out!)

                loadpattlen -= 2;
                bme_error = BME_OUT_OF_MEMORY;
                packbuffer = malloc(loadpattlen);
                memset(packbuffer, 0, loadpattlen);
                if (!packbuffer)
                {
                    free(instbuffer);
                    snd_frees3m();
                    io_close(handle);
                    return 0;
                }

                bme_error = BME_READ_ERROR;
                if (io_read(handle, packbuffer, loadpattlen) != loadpattlen)
                {
                    free(instbuffer);
                    free(packbuffer);
                    snd_frees3m();
                    io_close(handle);
                    return 0;
                }

                srcptr = packbuffer;
                destptr = (NOTE *)(&s3m_pattptr[count * s3m_pattlength]);
                for (rowcount = 0; rowcount < 64; rowcount++)
                {
                    Uint8 control;

                    for(;;)
                    {
                        control = *srcptr++;
                        if (control)
                        {
                            Uint8 channel = chconverttable[control & 31];
                            if (control & 32)
                            {
                                if (channel < s3m_channels)
                                {
                                    if (*srcptr < 254)
                                    {
                                        destptr[channel].note = (*srcptr & 15) + (*srcptr >> 4) * 12;
                                    }
                                    else destptr[channel].note = *srcptr;
                                    srcptr++;
                                    destptr[channel].instrument = *srcptr++;
                                }
                                else srcptr += 2;
                            }
                            if (control & 64)
                            {
                                if (channel < s3m_channels)
                                {
                                    destptr[channel].voleffect = *srcptr++;
                                }
                                else srcptr++;
                            }
                            if (control & 128)
                            {
                                if (channel < s3m_channels)
                                {
                                    destptr[channel].effect = *srcptr++;
                                    destptr[channel].effectdata = *srcptr++;
                                }
                                else srcptr += 2;
                            }
                        }
                        else break;
                    }
                    destptr += s3m_channels;
                }
                free(packbuffer);
            }
        }
    }

    // Now read samples

    ip = &s3m_instrument[0];
    for (count = 0; count < header.instnum; count++)
    {
        S3M_INSTRUMENT *s3mip = instbuffer + count;
        ip->vol = s3mip->vol;
        ip->c2rate = s3mip->c2rate;

        // Alloc & read sample (if there is one)

        if ((s3mip->type == 1) && (s3mip->length))
        {
            bme_error = BME_OUT_OF_MEMORY;
            ip->sp = snd_allocsample(s3mip->length);
            if (!ip->sp)
            {
                free(instbuffer);
                snd_frees3m();
                io_close(handle);
                return 0;
            }
            // Seek & read sample

            io_lseek(handle, (s3mip->paraptr | (s3mip->paraptrhigh << 16)) << 4, SEEK_SET);
            io_read(handle, ip->sp->start, s3mip->length);

            // Looped or non-looped?

            if ((s3mip->flags & 1) && (s3mip->loopstart != s3mip->loopend))
            {
                ip->sp->voicemode = VM_LOOP | VM_ON;
                ip->sp->repeat = ip->sp->start + s3mip->loopstart;
                ip->sp->end = ip->sp->start + s3mip->loopend;
            }
            else
            {
                ip->sp->voicemode = VM_ONESHOT | VM_ON;
                ip->sp->repeat = ip->sp->start;
                ip->sp->end = ip->sp->start + s3mip->length;
            }

            // Sixteenbit?

            if (s3mip->flags & 4)
            {
                ip->sp->voicemode |= VM_16BIT;
            }

            // Convert to signed if necessary

            if (header.fileversion == 2)
            {
                if (s3mip->flags & 4)
                {
                    Uint16 *cptr = (Uint16 *)ip->sp->start;
                    unsigned ccount = s3mip->length >> 1;
                    while (ccount)
                    {
                        *cptr += 0x8000;
                        cptr++;
                        ccount--;
                    }
                }
                else
                {
                    Sint8 *cptr = ip->sp->start;
                    unsigned ccount = s3mip->length;
                    while (ccount)
                    {
                        *cptr += 0x80;
                        cptr++;
                        ccount--;
                    }
                }
            }

            // All done, just correct interpolation

            snd_ipcorrect(ip->sp);
        }
        ip++;
    }
    free(instbuffer);
    bme_error = BME_OK;
    io_close(handle);
    s3m_loaded = 1;
    return 1;
}

void snd_frees3m(void)
{
    int count;
    INSTRUMENT *ip = &s3m_instrument[0];

    if (s3mplayer_firsttime)
    {
        if (!init_s3mplayer()) return;
    }
    snd_stops3m();
    s3m_loaded = 0;
    if (s3m_pattptr)
    {
        free(s3m_pattptr);
        s3m_pattptr = NULL;
    }
    for (count = 0; count < S3M_MAXINSTRUMENTS; count++)
    {
        if (ip->sp)
        {
            snd_freesample(ip->sp);
            ip->sp = NULL;
        }
        ip++;
    }
}

void snd_plays3m(int pos)
{
    int count;
    TRACK *tptr = &s3m_track[0];
    CHANNEL *chptr = &snd_channel[0];

    if (!s3m_loaded) return;
    if (s3m_channels > snd_channels) return;

    snd_player = NULL;
    s3m_pos = pos;
    s3m_line = 0;
    s3m_tickcount = 0;
    s3m_ticktempo = header.initialspeed;
    s3m_globalvol = header.globalvol;
    s3m_patterndelay = 0;
    snd_bpmcount = 0;
    snd_bpmtempo = header.initialtempo;
    for (count = 0; count < s3m_channels; count++)
    {
        chptr->smp = NULL;
        chptr->voicemode = VM_OFF;
        chptr->panning = s3m_chpanning[count];
        tptr->ip = &s3m_instrument[0];
        tptr->sp = NULL;
        tptr->c2rate = 8363;
        tptr->newnote = 0;
        tptr->instrument = 0;
        tptr->note = 0;
        tptr->notevol = 0;
        tptr->vol = 0;
        tptr->effect = 0;
        tptr->effectdata = 0;
        tptr->nybble1 = 0;
        tptr->nybble2 = 0;
        tptr->voleffect = 0;
        tptr->tp = 0;
        tptr->tpspeed = 0;
        tptr->volspeedup = 0;
        tptr->volspeeddown = 0;
        tptr->retriginterval = 0;
        tptr->arpeggiointerval = 0;
        tptr->retrigvolchange = 0;
        tptr->sampleoffset = 0;
        tptr->usesampleoffset = 0;
        tptr->vibratotype = 0;
        tptr->tremolotype = 0;
        chptr++;
        tptr++;
    }
    snd_player = &s3mplayer;
}

void snd_stops3m(void)
{
    int count;
    CHANNEL *chptr = &snd_channel[0];

    if (s3m_channels > snd_channels) s3m_channels = snd_channels;
    if (!s3m_loaded) return;
    snd_player = NULL;
    for (count = s3m_channels; count > 0; count--)
    {
        chptr->smp = NULL;
        chptr->voicemode = VM_OFF;
        chptr++;
    }
}

Uint8 snd_gets3mpos(void)
{
    return s3m_pos;
}

Uint8 snd_gets3mline(void)
{
    return s3m_line;
}

Uint8 snd_gets3mtick(void)
{
    return s3m_tickcount;
}

Uint8 snd_gets3mchannels(void)
{
    return s3m_channels;
}

char *snd_gets3mname(void)
{
    if (s3m_loaded) return (char *)header.songname;
    else return NULL;
}

static int init_s3mplayer(void)
{
    int count;
    INSTRUMENT *ip = &s3m_instrument[0];

    s3m_channels = 0;
    for (count = 0; count < S3M_MAXINSTRUMENTS; count++)
    {
        ip->sp = NULL;
        ip++;
    }
    s3mplayer_firsttime = 0;
    return 1;
}

static void s3mplayer(void)
{
    TRACK *tptr = &s3m_track[0];
    CHANNEL *chptr = &snd_channel[0];
    int count;

    // Set new notes or do something else?

    if ((!s3m_tickcount) && (!s3m_patterndelay))
    {
        NOTE *noteptr;

        while (s3m_order[s3m_pos] == 254)
        {
            s3m_pos++;
            if (s3m_pos == 0) return;
        }
        if (s3m_order[s3m_pos] == 255)
        {
            s3m_pos = 0;
            if (s3m_order[0] == 255) return;
        }

        noteptr = (NOTE *)&s3m_pattptr[s3m_pattlength * s3m_order[s3m_pos] + 5 * s3m_line * s3m_channels];

        s3m_patternbreak = 0;
        for (count = s3m_channels; count > 0; count--)
        {
            tptr->newnote = 0;

            // Get note (if any)

            if (noteptr->note != 255)
            {
                tptr->note = noteptr->note;
                tptr->newnote = 1;
            }

            // Get effect, effect data etc.

            tptr->voleffect = noteptr->voleffect;
            tptr->effect = noteptr->effect;
            tptr->effectdata = noteptr->effectdata;
            tptr->nybble1 = noteptr->effectdata >> 4;
            tptr->nybble2 = noteptr->effectdata & 0xf;
            tptr->newinstrument = noteptr->instrument;

            // Set sampleoffset here (unlike claimed in the
            // previous version, offset 00 uses the old value! :))

            if (tptr->newinstrument) tptr->usesampleoffset = 0;
            if (tptr->effect == 15)
            {
                if (tptr->effectdata) tptr->sampleoffset = tptr->effectdata;
                tptr->usesampleoffset = 1;
            }

            // Start new note if there is one; but check there
            // isn't notedelay

            if ((tptr->effect != 19) || (tptr->nybble1 != 0xd) || (tptr->nybble2 == 0))
            {
                if (tptr->newnote) startnewnote(tptr, chptr);

                // If an instrument number, reload
                // volume. Instrument number IS taken into
                // account!

                if (tptr->newinstrument)
                {
                    tptr->instrument = tptr->newinstrument - 1;
                    tptr->notevol = s3m_instrument[tptr->instrument].vol;
                    tptr->vol = tptr->notevol;
                }
            }

            // Reset period if not vibrato

            if ((tptr->effect != 8) && (tptr->effect != 11))
            {
                tptr->period = tptr->baseperiod;
            }

            // Reset volume if not tremolo / tremor

            if ((tptr->effect != 9) && (tptr->effect != 18))
            {
                tptr->vol = tptr->notevol;
            }

            // Now check volume column (it's much simpler than in
            // XMs!)

            if (tptr->voleffect != 255)
            {
                /* Applies only if there isn't notedelay */
                if ((tptr->effect != 19) || (tptr->nybble1 != 0xd) || (tptr->nybble2 == 0))
                {
                    tptr->notevol = tptr->voleffect;
                    if (tptr->notevol > 64) tptr->notevol = 64;
                    if (tptr->notevol < 0) tptr->notevol = 64;
                    tptr->vol = tptr->notevol;
                }
            }

            // Then the regular effects

            switch (tptr->effect)
            {
                case 0xff:
                break;

                /* Portamento up */
                case 6:
                if (tptr->effectdata) tptr->portaspeed = tptr->effectdata;
                /* Fine & extrafine done here */
                switch(tptr->portaspeed >> 4)
                {
                    case 0xe:
                    tptr->baseperiod -= (tptr->portaspeed & 15);
                    break;

                    case 0xf:
                    tptr->baseperiod -= (tptr->portaspeed & 15) * 4;
                    break;
                }
                if (tptr->baseperiod < HIGHPERIOD) chptr->voicemode = VM_OFF;
                tptr->period = tptr->baseperiod;
                break;

                /* Portamento down */
                case 5:
                if (tptr->effectdata) tptr->portaspeed = tptr->effectdata;
                /* Fine & extrafine done here */
                switch(tptr->portaspeed >> 4)
                {
                    case 0xe:
                    tptr->baseperiod += (tptr->portaspeed & 15);
                    break;

                    case 0xf:
                    tptr->baseperiod += (tptr->portaspeed & 15) * 4;
                    break;
                }
                if (tptr->baseperiod > LOWPERIOD) tptr->baseperiod = LOWPERIOD;
                tptr->period = tptr->baseperiod;
                break;

                /* Set TP. speed */
                case 7:
                if (tptr->effectdata) tptr->tpspeed = tptr->effectdata;
                break;

                /* Set vibrato */
                case 8:
                if (tptr->effectdata)
                {
                    if (tptr->nybble1) tptr->vibratospeed = tptr->nybble1;
                    tptr->vibratodepth = tptr->nybble2;
                }
                break;

                /* Arpeggio */
                case 10:
                if (tptr->effectdata)
                {
                    tptr->arpeggiointerval = tptr->effectdata;
                }
                break;

                /* Set tremolo */
                case 18:
                if (tptr->effectdata)
                {
                    tptr->tremolospeed = tptr->nybble1;
                    tptr->tremolodepth = tptr->nybble2;
                }
                break;

                /* Volume slide speed set */
                case 4:
                case 11:
                case 12:
                if (tptr->effectdata)
                {
                    tptr->volspeedup = tptr->nybble1;
                    tptr->volspeeddown = tptr->nybble2;
                }
                volslide(tptr);
                break;

                /* Pos. jump */
                case 2:
                s3m_line = 63;
                s3m_pos = tptr->effectdata - 1;
                break;

                /* Pattern break */
                case 3:
                if (!s3m_patternbreak)
                {
                    s3m_patternbreak = 1;
                    s3m_line = tptr->nybble1 * 10 + tptr->nybble2 - 1;
                    s3m_pos++;
                }
                break;

                /* Extended command */
                case 19:
                extendedcommand(tptr, chptr);
                break;

                /* Set BPM tempo */
                case 20:
                if (tptr->effectdata > 0x20)
                {
                    snd_bpmtempo = tptr->effectdata;
                }
                break;

                /* Set ticktempo */
                case 1:
                if (tptr->effectdata)
                {
                    s3m_ticktempo = tptr->effectdata;
                }
                break;

                /* Global volume */
                case 22:
                s3m_globalvol = tptr->effectdata;
                if (s3m_globalvol > 64) s3m_globalvol = 64;
                break;

                /* Surround panning (Undocumented) */
                case 24:
                {
                  int temp = tptr->effectdata;
                  temp <<= 1;
                  if (temp == 256) temp = 255;
                  if (temp > 255) {
                    /* From behind */
                    temp = 255-(temp-255);
                  }
                  chptr->panning = temp;
                }
                break;

                /* Multi retrig */
                case 17:
                if (tptr->effectdata)
                {
                    tptr->retrigvolchange = tptr->nybble1;
                    tptr->retriginterval = tptr->nybble2;
                }
                if (tptr->retrigcount >= tptr->retriginterval)
                {
                    startnewnote(tptr, chptr);
                    /* Now modify volume */
                    if (!retrigmultable[tptr->retrigvolchange])
                    {
                        tptr->notevol += retrigaddtable[tptr->retrigvolchange];
                        if (tptr->notevol < 0) tptr->notevol = 0;
                        if (tptr->notevol > 64) tptr->notevol = 64;
                        tptr->vol = tptr->notevol;
                    }
                    else
                    {
                        tptr->notevol = (tptr->notevol * retrigmultable[tptr->retrigvolchange]) >> 4;
                        if (tptr->notevol > 64) tptr->notevol = 64;
                        tptr->vol = tptr->notevol;
                    }
                }
                tptr->retrigcount++;
                break;

                /* Tremor */
                case 9:
                if (tptr->effectdata)
                {
                    tptr->tremorontime = tptr->nybble1;
                    tptr->tremorofftime = tptr->nybble2;
                }
                break;
            }
            if (tptr->period)
            {
                chptr->freq = 14317056 / tptr->period;
            }
            chptr->vol = (tptr->vol * s3m_globalvol) >> 6;
            noteptr++;
            chptr++;
            tptr++;
        }
    }
    if (s3m_tickcount)
    {
        // If tick isn't 0, update "continuous" effects

        for (count = s3m_channels; count > 0; count--)
        {
            switch (tptr->effect)
            {
                case 0xff:
                break;

                /* Arpeggio */
                case 10:
                {
                    char phase = s3m_tickcount % 3;
                    switch (phase)
                    {
                        Uint8 arpnote;

                        case 0:
                        tptr->period = tptr->baseperiod;
                        break;

                        case 1:
                        arpnote = tptr->note + (tptr->arpeggiointerval >> 4);
                        if (arpnote > 95) arpnote = 95;
                        tptr->period = ((8363 * 16 * s3mperiodtable[arpnote % 12]) >> (arpnote / 12)) / tptr->c2rate;
                        break;

                        case 2:
                        arpnote = tptr->note + (tptr->arpeggiointerval & 15);
                        if (arpnote > 95) arpnote = 95;
                        tptr->period = ((8363 * 16 * s3mperiodtable[arpnote % 12]) >> (arpnote / 12)) / tptr->c2rate;
                        break;
                    }
                }
                break;

                /* Portamento up */
                case 6:
                if (tptr->portaspeed < 0xe0)
                {
                    tptr->baseperiod -= tptr->portaspeed * 4;
                }
                if (tptr->baseperiod < HIGHPERIOD) chptr->voicemode = VM_OFF;
                tptr->period = tptr->baseperiod;
                break;

                /* Portamento down */
                case 5:
                if (tptr->portaspeed < 0xe0)
                {
                    tptr->baseperiod += tptr->portaspeed * 4;
                }
                if (tptr->baseperiod > LOWPERIOD) tptr->baseperiod = LOWPERIOD;
                tptr->period = tptr->baseperiod;
                break;

                /* Toneportamento */
                case 7:
                if (tptr->tp)
                {
                    if (tptr->baseperiod < tptr->targetperiod)
                    {
                        tptr->baseperiod += tptr->tpspeed * 4;
                        if (tptr->baseperiod >= tptr->targetperiod)
                        {
                            tptr->baseperiod = tptr->targetperiod;
                            tptr->tp = 0;
                        }
                    }
                    if (tptr->baseperiod > tptr->targetperiod)
                    {
                        tptr->baseperiod -= tptr->tpspeed * 4;
                        if (tptr->baseperiod <= tptr->targetperiod)
                        {
                            tptr->baseperiod = tptr->targetperiod;
                            tptr->tp = 0;
                        }
                    }
                    tptr->period = tptr->baseperiod;
                }
                break;

                /* Vibrato */
                case 8:
                tptr->vibratophase += tptr->vibratospeed * 4;
                tptr->period = tptr->baseperiod + ((vibratotable[tptr->vibratotype & 3][tptr->vibratophase] * tptr->vibratodepth) >> 3);
                if (tptr->period < HIGHPERIOD) tptr->period = HIGHPERIOD;
                if (tptr->period > LOWPERIOD) tptr->period = LOWPERIOD;
                break;

                /* Toneportamento + volslide */
                case 12:
                if (tptr->tp)
                {
                    if (tptr->baseperiod < tptr->targetperiod)
                    {
                        tptr->baseperiod += tptr->tpspeed * 4;
                        if (tptr->baseperiod >= tptr->targetperiod)
                        {
                            tptr->baseperiod = tptr->targetperiod;
                            tptr->tp = 0;
                        }
                    }
                    if (tptr->baseperiod > tptr->targetperiod)
                    {
                        tptr->baseperiod -= tptr->tpspeed * 4;
                        if (tptr->baseperiod <= tptr->targetperiod)
                        {
                            tptr->baseperiod = tptr->targetperiod;
                            tptr->tp = 0;
                        }
                    }
                    tptr->period = tptr->baseperiod;
                }
                volslide(tptr);
                break;

                /* Vibrato + volslide */
                case 11:
                tptr->vibratophase += tptr->vibratospeed * 4;
                tptr->period = tptr->baseperiod + ((vibratotable[tptr->vibratotype & 3][tptr->vibratophase] * tptr->vibratodepth) >> 3);
                if (tptr->period < HIGHPERIOD) tptr->period = HIGHPERIOD;
                if (tptr->period > LOWPERIOD) tptr->period = LOWPERIOD;
                volslide(tptr);
                break;

                /* Tremolo */
                case 18:
                tptr->tremolophase += tptr->tremolospeed * 4;
                tptr->vol = tptr->notevol + ((vibratotable[tptr->tremolotype & 3][tptr->tremolophase] * tptr->tremolodepth) >> 4);
                if (tptr->vol < 0) tptr->vol = 0;
                if (tptr->vol > 64) tptr->vol = 64;
                break;

                /* Volume Slide */
                case 4:
                volslide(tptr);
                break;

                /* Extended command */
                case 19:
                extendedcommand(tptr, chptr);
                break;

                /* Multi retrig */
                case 17:
                if (tptr->retrigcount >= tptr->retriginterval)
                {
                    startnewnote(tptr, chptr);
                    /* Now modify volume */
                    if (!retrigmultable[tptr->retrigvolchange])
                    {
                        tptr->notevol += retrigaddtable[tptr->retrigvolchange];
                        if (tptr->notevol < 0) tptr->notevol = 0;
                        if (tptr->notevol > 64) tptr->notevol = 64;
                        tptr->vol = tptr->notevol;
                    }
                    else
                    {
                        tptr->notevol = (tptr->notevol * retrigmultable[tptr->retrigvolchange]) >> 4;
                        if (tptr->notevol > 64) tptr->notevol = 64;
                        tptr->vol = tptr->notevol;
                    }
                }
                tptr->retrigcount++;
                break;

                /* Tremor */
                case 9:
                if (!tptr->tremorcount)
                {
                    tptr->tremorstatus ^= 1;
                    if (tptr->tremorstatus) tptr->tremorcount = tptr->tremorontime + 1;
                    else tptr->tremorcount = tptr->tremorofftime + 1;
                }
                if (tptr->tremorstatus) tptr->vol = tptr->notevol;
                else tptr->vol = 0;
                tptr->tremorcount--;
                break;
            }
            if (tptr->period)
            {
                chptr->freq = 14317056 / tptr->period;
            }
            chptr->vol = (tptr->vol * s3m_globalvol) >> 6;
            chptr++;
            tptr++;
        }
    }

    // Advance song

    s3m_tickcount++;
    if (s3m_tickcount >= s3m_ticktempo)
    {
        s3m_tickcount = 0;
        if (s3m_patterndelay)
        {
            s3m_patterndelay--;
        }
        if (!s3m_patterndelay)
        {
            s3m_line++;
            if (s3m_line >= 64)
            {
                s3m_line = 0;
                s3m_pos++;
            }
        }
    }
}

static void startnewnote(TRACK *tptr, CHANNEL *chptr)
{
    // Change instrument if necessary

    if (tptr->newinstrument)
    {
        tptr->instrument = tptr->newinstrument - 1;
        tptr->ip = &s3m_instrument[tptr->instrument];
    }

    // Handle keyoff

    if (tptr->note == 254)
    {
        chptr->voicemode = VM_OFF;
        return;
    }

    // Now get samplepointer

    tptr->sp = tptr->ip->sp;

    // Don't go further if sample doesn't exist

    if (tptr->sp)
    {
        tptr->c2rate = tptr->ip->c2rate;
        tptr->retrigcount = 0;
        if (!(tptr->vibratotype & 4)) tptr->vibratophase = 0;
        if (!(tptr->tremolotype & 4)) tptr->tremolophase = 0;
        tptr->tremorcount = 0;
        tptr->tremorstatus = 0;

        // Toneportamento mustn't be used if there's no note on that
        // channel (to make the bassline in HERRA.S3M audible)

        if (((tptr->effect == 7) || (tptr->effect == 12)) && (chptr->voicemode != VM_OFF))
        {
            // Toneportamento

            tptr->targetperiod = ((8363 * 16 * s3mperiodtable[tptr->note % 12]) >> (tptr->note / 12)) / tptr->c2rate;
            tptr->tp = 1;
        }
        else
        {
            // Normal note start

            tptr->tp = 0;
            tptr->baseperiod = ((8363 * 16 * s3mperiodtable[tptr->note % 12]) >> (tptr->note / 12)) / tptr->c2rate;
            tptr->period = tptr->baseperiod;
            chptr->fractpos = 0;
            chptr->repeat = tptr->sp->repeat;
            chptr->end = tptr->sp->end;
            chptr->voicemode = tptr->sp->voicemode;
            if (tptr->usesampleoffset)
            {
                if (tptr->sp->voicemode & VM_16BIT) chptr->pos = tptr->sp->start + (tptr->sampleoffset << 9);
                    else chptr->pos = tptr->sp->start + (tptr->sampleoffset << 8);
                if (chptr->pos >= tptr->sp->end)
                {
                    if (chptr->voicemode & VM_LOOP)
                    {
                        chptr->pos = tptr->sp->repeat;
                    }
                    else
                    {
                        chptr->voicemode = VM_OFF;
                    }
                }
            }
            else
            {
                chptr->pos = tptr->sp->start;
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
        /* Set finetune */
        case 0x2:
        if ((!s3m_tickcount) && (tptr->newnote))
        {
            tptr->c2rate = s3mfinetunetable[tptr->nybble2];
            tptr->baseperiod = ((8363 * 16 * s3mperiodtable[tptr->note % 12]) >> (tptr->note / 12)) / tptr->c2rate;
            tptr->period = tptr->baseperiod;
        }
        break;

        /* Set vibrato waveform */
        case 0x3:
        if (!s3m_tickcount)
        {
            tptr->vibratotype = vibratotypetable[tptr->nybble2 & 3];
            tptr->vibratotype |= tptr->nybble2 & 4;
        }
        break;

        /* Set tremolo waveform */
        case 0x4:
        if (!s3m_tickcount)
        {
            tptr->tremolotype = vibratotypetable[tptr->nybble2 & 3];
            tptr->tremolotype |= tptr->nybble2 & 4;
        }
        break;

        /* Set panning */
        case 0x8:
        if (!s3m_tickcount)
        {
            chptr->panning = (tptr->nybble2 << 4) | tptr->nybble2;
        }
        break;

        /* Patternloop */
        case 0xb:
        if (!s3m_tickcount)
        {
            if (!tptr->nybble2) s3m_patternloopline = s3m_line;
            else
            {
                if (!s3m_patternloopcount)
                {
                    s3m_patternloopcount = tptr->nybble2;
                    s3m_line = s3m_patternloopline - 1;
                }
                else
                {
                    s3m_patternloopcount--;
                    if (s3m_patternloopcount) s3m_line = s3m_patternloopline - 1;
                }
            }
        }
        break;

        /* Notedelay */
        case 0xd:
        /* Don't start on tick 0 */
        if (!s3m_tickcount) break;
        if (s3m_tickcount == tptr->nybble2)
        {
            /* If no new note, just reload volume */
            if (tptr->newnote) startnewnote(tptr, chptr);
            if (tptr->newinstrument)
            {
                /* Store new instrument number */
                tptr->instrument = tptr->newinstrument - 1;
                tptr->notevol = s3m_instrument[tptr->instrument].vol;
                tptr->vol = tptr->notevol;
            }
            if (tptr->voleffect != 255)
            {
                tptr->notevol = tptr->voleffect;
                if (tptr->notevol < 0) tptr->notevol = 64;
                if (tptr->notevol > 64) tptr->notevol = 64;
                tptr->vol = tptr->notevol;
            }
        }
        break;

        /* Cut note */
        case 0xc:
        if (s3m_tickcount == tptr->nybble2) tptr->notevol = 0;
        break;

        /* Patterndelay */
        case 0xe:
        if (!s3m_tickcount)
        {
            s3m_patterndelay = tptr->nybble2 + 1;
        }
        break;
    }
}

static void volslide(TRACK *tptr)
{
    if (s3m_tickcount)
    {
        if (tptr->volspeeddown == 0)
        {
            tptr->notevol += tptr->volspeedup;
            if (tptr->notevol > 64) tptr->notevol = 64;
            tptr->vol = tptr->notevol;
            return;
        }
        if (tptr->volspeedup == 0)
        {
            tptr->notevol -= tptr->volspeeddown;
            if (tptr->notevol < 0) tptr->notevol = 0;
            tptr->vol = tptr->notevol;
            return;
        }
    }
    else
    {
        if (tptr->volspeeddown == 15)
        {
            tptr->notevol += tptr->volspeedup;
            if (tptr->notevol > 64) tptr->notevol = 64;
            tptr->vol = tptr->notevol;
            return;
        }
        if (tptr->volspeedup == 15)
        {
            tptr->notevol -= tptr->volspeeddown;
            if (tptr->notevol < 0) tptr->notevol = 0;
            tptr->vol = tptr->notevol;
            return;
        }
    }
}

