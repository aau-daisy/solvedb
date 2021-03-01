#ifndef _PATCHES_GLOBAL_H
#define _PATCHES_GLOBAL_H

#include "postgres.h"
#include "lib/stringinfo.h"

#define free(ptr)		pfree(ptr)
#define malloc(size)		palloc0(size)
#define realloc(ptr,size)	realloc(ptr,size)

// Renaming of types/functions
#define bool pg_glpk_bool
#define connect pg_glpk_connect

#define abort abort_patched
extern void abort_patched(void);

// Undefines
#undef true
#undef false
#undef DEBUG1
#undef DEBUG2
#undef DEBUG3
#undef DEBUG4
#undef Assert

#endif
