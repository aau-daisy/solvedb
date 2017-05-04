#ifndef _SW_LOG_H
#define _SW_LOG_H

// Makes it compatible with C compiler
#ifdef __cplusplus
extern "C" {
#endif

#include "postgres.h"
#include "lib/stringinfo.h"

/* Initializes the SW logger buffer */
extern void sw_log_init(void); 

/* Prints a formatted line on the end of the SW logger buffer */
extern void sw_log_printf(const char *fmt,...)
__attribute__((format(PG_PRINTF_ATTRIBUTE, 1, 2)));

/* Prints a formatted line on the SW logger buffer */
extern void sw_log_vprintf(const char *fmt, va_list argp)
__attribute__((format(PG_PRINTF_ATTRIBUTE, 1, 0)));

/* Retrieve the buffer content */
extern char * sw_log_getbuffer();

/* Frees the buffer content */
extern void sw_log_free(void); /* Destroys the GLPK logger buffer */

#ifdef __cplusplus
}
#endif

#endif
