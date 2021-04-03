//
// BME (Blasphemous Multimedia Engine) raw samples module
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

SAMPLE *snd_loadrawsample(char *name, int repeat, int end, unsigned char voicemode)
{
    int length;
    int handle;
    SAMPLE *smp;

    bme_error = BME_OPEN_ERROR;
    handle = io_open(name);
    if (handle == -1) return NULL;
    length = io_lseek(handle, 0, SEEK_END);
    if (length == -1)
    {
        io_close(handle);
        return NULL;
    }
    io_lseek(handle, 0, SEEK_SET);
    smp = snd_allocsample(length);
    if (!smp)
    {
        io_close(handle);
        return NULL;
    }
    if (end == 0) end = length;
    if (end > length) end = length;
    if (repeat > length - 1) repeat = length - 1;
    bme_error = BME_READ_ERROR;
    if (io_read(handle, smp->start, length) != length)
    {
        snd_freesample(smp);
        io_close(handle);
        return NULL;
    }
    io_close(handle);
    smp->repeat = smp->start + repeat;
    smp->end = smp->start + end;
    smp->voicemode = voicemode | VM_ON;
    snd_ipcorrect(smp);
    bme_error = BME_OK;
    return smp;
}
