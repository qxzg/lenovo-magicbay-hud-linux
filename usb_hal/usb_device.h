#ifndef __MSDISP_MS9132_H__
#define __MSDISP_MS9132_H__

#include "hal_adaptor.h"

#define MSDISP_913X_VENDOR 0x345f
#define MSDISP_9132_PRODUCT 0x9132
#define MSDISP_9133_PRODUCT 0x9133
#define MSDISP_9135_PRODUCT 0x9135
#define MSDISP_LENOVO_VENDOR 0x17ef
#define MSDISP_LENOVO_HUD_PRODUCT 0x1117


extern const struct msdisp_hal_id ms9132_id;
extern const struct msdisp_hal_id ms9133_id;
extern const struct msdisp_hal_id ms9135_id;
extern const struct msdisp_hal_id lenovo_hud_id;
extern struct msdisp_hal_dev ms9132_dev;
extern struct msdisp_hal_dev ms9133_dev;
extern struct msdisp_hal_dev ms9135_dev;
extern struct msdisp_hal_dev lenovo_hud_dev;


#endif
