#include "patches_global.h"

extern void abort_patched()
{
	ereport(ERROR,
  		(errcode(ERRCODE_EXTERNAL_ROUTINE_EXCEPTION),
		 errmsg("Terminated by the GLPK library.")));
}

