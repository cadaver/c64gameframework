//
// BME (Blasphemous Multimedia Engine) joystick module
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <SDL/SDL.h>
#include "bme_main.h"
#include "bme_cfg.h"
#include "bme_win.h"
#include "bme_io.h"
#include "bme_err.h"

int joy_detect(unsigned id)
{
    if (id > MAX_JOYSTICKS) return BME_ERROR;
    if (SDL_NumJoysticks() > 0)
    {
        if (joy[id])
        {
            SDL_JoystickClose(joy[id]);
            joy[id] = NULL;
        }
        joy[id] = SDL_JoystickOpen(id);
        if (joy[id]) return BME_OK;
        else return BME_ERROR;
    }
    return BME_ERROR;
}

unsigned joy_getstatus(unsigned id, int threshold)
{
    unsigned control = 0;

    if (id > MAX_JOYSTICKS) return 0;
    if (!joy[id]) return 0;

    if (joyx[id] < -threshold) control |= JOY_LEFT;
    if (joyx[id] > threshold) control |= JOY_RIGHT;
    if (joyy[id] < -threshold) control |= JOY_UP;
    if (joyy[id] > threshold) control |= JOY_DOWN;
    control |= joybuttons[id] << 4;

    return control;
}
