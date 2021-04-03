//
// BME (Blasphemous Multimedia Engine) WAV samples module
//

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <SDL/SDL.h>
#include "bme_io.h"
#include "bme_main.h"
#include "bme_snd.h"
#include "bme_cfg.h"
#include "bme_err.h"

typedef struct
{
    Uint8 rifftext[4];
    Uint32 totallength;
    Uint8 wavetext[4];
    Uint8 formattext[4];
    Uint32 formatlength;
    Uint16 format;
    Uint16 channels;
    Uint32 freq;
    Uint32 avgbytes;
    Uint16 blockalign;
    Uint16 bits;
    Uint8 datatext[4];
    Uint32 datalength;
} WAV_HEADER;

SAMPLE *snd_loadwav(char *name)
{
    int length;
    int reallength;
    int handle;
    SAMPLE *smp;
    WAV_HEADER header;

    // Try to open

    bme_error = BME_OPEN_ERROR;
    handle = io_open(name);
    if (handle == -1) return NULL;

    // Read identification

    memset(&header, 0, sizeof header);
    io_read(handle, &header.rifftext, 4);
    header.totallength = io_readle32(handle);
    io_read(handle, &header.wavetext, 4);

    bme_error = BME_WRONG_FORMAT;
    if (memcmp("RIFF", header.rifftext, 4))
    {
        io_close(handle);
        return NULL;
    }
    if (memcmp("WAVE", header.wavetext, 4))
    {
        io_close(handle);
        return NULL;
    }

    // Search for the FORMAT chunk

    for (;;)
    {
        bme_error = BME_READ_ERROR;
        io_read(handle, &header.formattext, 4);
        header.formatlength = io_readle32(handle);
        if (!memcmp("fmt ", &header.formattext, 4)) break;
        if (io_lseek(handle, header.formatlength, SEEK_CUR) == -1)
        {
            io_close(handle);
            return NULL;
        }
    }
    // Read in the FORMAT chunk

    header.format = io_readle16(handle);
    header.channels = io_readle16(handle);
    header.freq = io_readle32(handle);
    header.avgbytes = io_readle32(handle);
    header.blockalign = io_readle16(handle);
    header.bits = io_readle16(handle);

    // Skip data if the format chunk was bigger than what we use

    if (io_lseek(handle, header.formatlength - 16, SEEK_CUR) == -1)
    {
        io_close(handle);
        return NULL;
    }

    // Check for correct format

    bme_error = BME_WRONG_FORMAT;
    if (header.format != 1)
    {
        io_close(handle);
        return NULL;
    }

    // Search for the DATA chunk

    for (;;)
    {
        bme_error = BME_READ_ERROR;
        io_read(handle, &header.datatext, 4);
        header.datalength = io_readle32(handle);
        if (!memcmp("data", &header.datatext, 4)) break;
        if (io_lseek(handle, header.datalength, SEEK_CUR) == -1)
        {
            io_close(handle);
            return NULL;
        }
    }
    // Allocate sample, load audio data, do processing (unsigned->signed,
    // stereo->mono)

    length = header.datalength;
    reallength = length;
    if (header.channels == 2) reallength >>= 1;
    smp = snd_allocsample(reallength);
    if (!smp)
    {
        io_close(handle);
        return NULL;
    }
    if (header.channels == 2)
    {
        if (header.bits == 16)
        {
            unsigned count;
            Sint16 *buffer;
            Sint16 *src;
            Sint16 *dest;

            bme_error = BME_OUT_OF_MEMORY;
            buffer = malloc(length);
            if (!buffer)
            {
                snd_freesample(smp);
                io_close(handle);
                return NULL;
            }
            count = 0;
            while (count < (length >> 2))
            {
                buffer[count] = io_readle16(handle);
                count++;
            }
            src = buffer;
            dest = (Sint16 *)smp->start;
            count = length >> 2;
            while (count--)
            {
                int average = (src[0] + src[1]) / 2;
                *dest = average;
                src += 2;
                dest++;
            }
            free(buffer);
            smp->repeat = smp->start;
            smp->end = smp->start + reallength;
            smp->voicemode = VM_ON | VM_16BIT;
        }
        else
        {
            unsigned count;
            Uint8 *buffer;
            Uint8 *src;
            Sint8 *dest;

            bme_error = BME_OUT_OF_MEMORY;
            buffer = malloc(length);
            if (!buffer)
            {
                snd_freesample(smp);
                io_close(handle);
                return NULL;
            }
            count = 0;
            while (count < (length >> 1))
            {
                buffer[count] = io_readle16(handle);
                count++;
            }
            src = buffer;
            dest = smp->start;
            count = length >> 1;
            while (count--)
            {
                int average = (src[0] + src[1] - 0x100) / 2;
                *dest = average;
                src += 2;
                dest++;
            }
            free(buffer);
            smp->repeat = smp->start;
            smp->end = smp->start + reallength;
            smp->voicemode = VM_ON;
        }
    }
    else
    {
        if (header.bits == 16)
        {
            unsigned count = 0;
            Sint16 *buffer = (Sint16 *)smp->start;

            while (count < (length >> 1))
            {
                buffer[count] = io_readle16(handle);
            }
            smp->repeat = smp->start;
            smp->end = smp->start + length;
            smp->voicemode = VM_ON | VM_16BIT;
        }
        else
        {
            unsigned count = length;
            Sint8 *src = smp->start;

            bme_error = BME_READ_ERROR;
            if (io_read(handle, smp->start, length) != length)
            {
                snd_freesample(smp);
                io_close(handle);
                return NULL;
            }
            while (count--)
            {
                *src += 0x80;
                src++;
            }
            smp->repeat = smp->start;
            smp->end = smp->start + length;
            smp->voicemode = VM_ON;
        }
    }
    bme_error = BME_OK;
    io_close(handle);
    return smp;
}
