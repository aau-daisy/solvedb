#ifndef PG_PATCHES_GLPK_H
#define PG_PATCHES_GLPK_H

#include "patches_global.h"

#include "glpenv.h"
#include "glpk_log.h"

#undef xerror
#define xerror(...) ereport(ERROR,(errcode(ERRCODE_RAISE_EXCEPTION), errmsg(__VA_ARGS__)))

#undef xassert
#define xassert(expr) ((void)((expr)))


#undef xvprintf
#define xvprintf(fmt, arg) glpk_log_vprintf(fmt, arg)

#undef xprintf
#define xprintf(...) glpk_log_printf(__VA_ARGS__)


// #include "colamd/colamd.h"

// #undef colamd_printf
// #define colamd_printf (...) xprintf(__VA_ARGS__)

// (elog(NOTICE, __VA_ARGS__))

// #define colamd_printf xprintf

// extern void pg_printf(const char *fmt,...)
// __attribute__((format(PG_PRINTF_ATTRIBUTE, 1, 2)));

#endif
