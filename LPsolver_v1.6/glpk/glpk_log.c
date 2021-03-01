#include "glpk_log.h"
#include "miscadmin.h"
#include "utils/elog.h"

// /* A buffer to store the output from the GLPK solver */
static int glpk_logLevel;

/* Initializes the GLPK logger buffer */
extern void glpk_log_setLevel(int logLevel)
{
	glpk_logLevel = logLevel;
}

/* Prints a formatted line on the GLPK logger buffer */
extern void glpk_log_printf(const char *fmt, ...) {
	va_list arg;

	if (glpk_logLevel > LOG) return;

	va_start(arg, fmt);

	glpk_log_vprintf(fmt, arg);

	va_end(arg);

	// Check if someone has interrupted the operation
	CHECK_FOR_INTERRUPTS();
}

/* Prints a formatted line on the GLPK logger buffer (variable argument list version) */
extern void glpk_log_vprintf(const char *fmt, va_list argp) {
	ErrorContextCallback * old_error_context;
	StringInfoData 		 buf;
	int					 len;

	if (glpk_logLevel > LOG) return;

	initStringInfo(&buf);

	for (;;) {
		int 		needed;
		va_list 	ap2;

		va_copy(ap2, argp);

		needed = appendStringInfoVA(&buf, fmt, ap2);

		va_end(ap2);

		if (needed == 0)
			break;

		/* Double the buffer size and try again. */
		enlargeStringInfo(&buf, needed);
	}

	/* Output to the client */
	old_error_context = error_context_stack;
	error_context_stack = NULL;
	/* Replace new line symbols */
	len=strlen(buf.data);
	if (len>0 && buf.data[len-1] == '\n')
		buf.data[len-1] = '\0';
	ereport(NOTICE, (errmsg("%s", buf.data)));
	error_context_stack = old_error_context;

		/* Release the memory */
	if (buf.data)
		pfree(buf.data);
}
