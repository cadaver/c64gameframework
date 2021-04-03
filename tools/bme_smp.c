//
// BME (Blasphemous Multimedia Engine) sample support main module
//

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <SDL/SDL.h>
#include "bme_err.h"
#include "bme_main.h"
#include "bme_snd.h"
#include "bme_cfg.h"

SAMPLE *snd_allocsample(int length)
{
    SAMPLE *smp;

    bme_error = BME_OUT_OF_MEMORY;
    smp = (SAMPLE *)malloc(sizeof (SAMPLE));
    if (!smp) return NULL;
    smp->start = malloc(length);
    if (!smp->start)
    {
        snd_freesample(smp);
        return NULL;
    }
    smp->repeat = NULL;
    smp->end = NULL;
    bme_error = BME_OK;
    return smp;
}

void snd_freesample(SAMPLE *smp)
{
    int c;
    CHANNEL *chptr;

    if (!smp) return;

    // Go thru all channels; if that sample is playing then stop the
    // channel; we don't want a crash or noise!

    chptr = &snd_channel[0];
    for (c = snd_channels; c > 0; c--)
    {
        if (chptr->smp == smp)
        {
            chptr->smp = NULL;
            chptr->voicemode = VM_OFF;
        }
        chptr++;
    }

    // Free the sample data and then the sample structure itself

    if (smp->start) free(smp->start);
    free(smp);
}

void snd_ipcorrect(SAMPLE *smp)
{
}

void snd_playsample(SAMPLE *smp, unsigned chnum, unsigned frequency, unsigned char volume, unsigned char panning)
{
    CHANNEL *chptr;

    if (!smp) return;
    if (!snd_sndinitted) return;
    if (chnum >= (unsigned)snd_channels) return;
    chptr = &snd_channel[chnum];
    chptr->voicemode = VM_OFF;
    chptr->pos = smp->start;
    chptr->repeat = smp->repeat;
    chptr->end = smp->end;
    chptr->smp = smp;
    chptr->fractpos = 0;
    chptr->freq = frequency;
    chptr->vol = volume;
    chptr->panning = panning;
    chptr->voicemode = smp->voicemode;
}

void snd_stopsample(unsigned chnum)
{
    CHANNEL *chptr;

    if (!snd_sndinitted) return;
    if (chnum >= (unsigned)snd_channels) return;
    chptr = &snd_channel[chnum];
    chptr->voicemode = VM_OFF;
    chptr->smp = NULL;
}

void snd_preventdistortion(unsigned active_channels)
{
    int count;
    unsigned char mastervol;

    if (!snd_sndinitted) return;
    if (active_channels < 2) mastervol = 255;
    else mastervol = 256 / active_channels;
    for (count = 0; count < snd_channels; count++)
    {
        snd_setmastervolume(count, mastervol);
    }
}

void snd_setmastervolume(unsigned chnum, unsigned char mastervol)
{
    CHANNEL *chptr;

    if (!snd_sndinitted) return;
    if (chnum >= (unsigned)snd_channels) return;
    chptr = &snd_channel[chnum];
    chptr->mastervol = mastervol;
}

void snd_setmusicmastervolume(unsigned musicchannels, unsigned char mastervol)
{
    CHANNEL *chptr = &snd_channel[0];
    int count;

    if (!snd_sndinitted) return;
    if (musicchannels > (unsigned)snd_channels) musicchannels = snd_channels;
    for (count = 0; (unsigned)count < musicchannels; count++)
    {
        chptr->mastervol = mastervol;
        chptr++;
    }
}

void snd_setsfxmastervolume(unsigned musicchannels, unsigned char mastervol)
{
    CHANNEL *chptr;
    int count;

    if (!snd_sndinitted) return;
    if (musicchannels >= (unsigned)snd_channels) return;
    chptr = &snd_channel[musicchannels];
    for (count = musicchannels; count < snd_channels; count++)
    {
        chptr->mastervol = mastervol;
        chptr++;
    }
}
