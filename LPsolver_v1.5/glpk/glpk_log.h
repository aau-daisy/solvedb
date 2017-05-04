#ifndef _GLPK_LOG_H
#define _GLPK_LOG_H

#include "postgres.h"
#include "lib/stringinfo.h"

/* Initializes the GLPK logger buffer */
extern void glpk_log_setLevel(int logLevel);

/* Prints a formatted line on the end of the GLPK logger buffer */
extern void glpk_log_printf(const char *,...)
__attribute__((format(PG_PRINTF_ATTRIBUTE, 1, 2)));

/* Prints a formatted line on the GLPK logger buffer */
extern void glpk_log_vprintf(const char *, va_list)
__attribute__((format(PG_PRINTF_ATTRIBUTE, 1, 0)));


#endif
