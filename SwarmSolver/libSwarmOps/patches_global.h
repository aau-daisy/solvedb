#ifndef _PATCHES_GLOBAL_H
#define _PATCHES_GLOBAL_H

// Makes it compatible with C compiler
#ifdef __cplusplus
extern "C" {
#endif

#include "postgres.h"

#define free(ptr)		if (ptr != NULL) pfree(ptr)
#define malloc(size)		palloc(size)
#define realloc(ptr,size)	realloc(ptr,size)

// Undefines
#undef true
#undef false
#undef DEBUG1
#undef DEBUG2
#undef DEBUG3
#undef DEBUG4
#undef Assert
#undef assert

// Override the function in <assert.h> so that all asstertation will be redirected to the PG
extern void so_assert_redirect(__const char *__assertion, __const char *__file, unsigned int __line, __const char *__function) __THROW;
#define __assert_fail so_assert_redirect

#ifdef __cplusplus
}
#endif

#endif
