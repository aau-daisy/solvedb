#ifndef _PATCHES_COLAMD_H
#define _PATCHES_COLAMD_H

#include "patches_global.h"
#include "glpk_log.h"

#include "colamd/colamd.h"

#undef colamd_printf
#define colamd_printf glpk_log_printf

#endif