#include "sw_log.h"

/* A buffer to store the output from the SW solver */
static StringInfoData sw_log_buffer;

/* Initializes the SW logger buffer */
extern void sw_log_init()
{
	initStringInfo(&sw_log_buffer);
}

/* Prints a formatted line on the GLPK logger buffer */
extern void sw_log_printf(const char *fmt,...)
{
	va_list arg;
	va_start(arg, fmt);

	sw_log_vprintf(fmt, arg);	

	va_end(arg);
}

/* Prints a formatted line on the SW logger buffer (variable argument list version) */
extern void sw_log_vprintf(const char *fmt, va_list argp)
{
         for (;;) {
	    int needed;

	    needed = appendStringInfoVA(&sw_log_buffer, fmt, argp);
            if (needed == 0)
            	 break;

     	      /* Double the buffer size and try again. */
             enlargeStringInfo(&sw_log_buffer, needed);
         }
}

/* Retrieve the buffer content */
extern char * sw_log_getbuffer()
{
	return sw_log_buffer.data;
}

/* Destoys the SW logger buffer */
extern void sw_log_free()
{
	pfree(sw_log_buffer.data);
}