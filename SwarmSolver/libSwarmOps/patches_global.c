#include "patches_global.h"

extern void so_assert_redirect(__const char *__assertion, __const char *__file, unsigned int __line, __const char *__function) __THROW
{
	elog(ERROR, "SwarmOPS assertion has failed: %s", __assertion);
};
