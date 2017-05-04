/*-------------------------------------------------------------------------
 *
 * lp_function.h
 *	  Header file for the "lp_function" ADT.
 *
 * Copyright (c) 2012, Laurynas Siksnys
 *
 *-------------------------------------------------------------------------
 */
#ifndef ADTLP_FUNCTION_H
#define ADTLP_FUNCTION_H

#include "lib/stringinfo.h"
#include "fmgr.h"
#include "nodes/pg_list.h"
#include "utils/hsearch.h"


/*
 * The result of parsing a timezone configuration file is an array of
 * these structs, in order by abbrev.  We export this because datetime.c
 * needs it.
 */

typedef struct
{
	int 		varNr; // Variable number
	double 		factor; // Factor
} lpTerm;

// A structure that will be visible to postgresql
typedef struct pg_LPfunction
{
	int32		vl_len_;		/* varlena header (do not touch directly!) */
	double		factor0;		/* A factor of x^0 */
	int 		numTerms;		// Number of terms
	lpTerm 		term[1];		// Unaligned!
								// 2014-08-25, Elements do not have to be sorted according to varNr.
} pg_LPfunction;

#define LPfunction_SIZE(numTerms) 		(offsetof(pg_LPfunction, term[0]) + sizeof(lpTerm) * (numTerms))

#define DatumGetLPfunction(x)		((pg_LPfunction*)PG_DETOAST_DATUM(x))
#define DatumGetLPfunctionCopy(x)	((pg_LPfunction*)PG_DETOAST_DATUM_COPY(x))
#define PG_GETARG_LPfunction(x)		DatumGetLPfunction(PG_DETOAST_DATUM(PG_GETARG_DATUM(x)))
#define PG_RETURN_LPfunction(x)		PG_RETURN_POINTER(x)

// Internal constants
extern const struct pg_LPfunction LPfunction_EMPTY ;

extern void lp_function_to_stringinfo(pg_LPfunction * terms, StringInfoData * buf);
extern Datum lp_function_in(PG_FUNCTION_ARGS);
extern Datum lp_function_out(PG_FUNCTION_ARGS);
extern Datum lp_function_make(PG_FUNCTION_ARGS);
extern Datum lp_function_makeCnum(PG_FUNCTION_ARGS);
extern Datum lp_function_makeCint4(PG_FUNCTION_ARGS);
extern Datum lp_function_makeCbool(PG_FUNCTION_ARGS);
extern Datum lp_function_makeCfloat8(PG_FUNCTION_ARGS);
extern Datum lp_function_fmul(PG_FUNCTION_ARGS);
extern Datum lp_function_fmulC(PG_FUNCTION_ARGS);
extern Datum lp_function_fdiv(PG_FUNCTION_ARGS);
extern Datum lp_function_plus(PG_FUNCTION_ARGS);
extern Datum lp_function_minus(PG_FUNCTION_ARGS);
extern Datum lp_function_minus1(PG_FUNCTION_ARGS);

// Utility funtions
// Split lp_function expression to individual terms
extern Datum lp_function_unnest(PG_FUNCTION_ARGS);

// Internal functions
// A general function for adding two pg_LPfunction instances
extern pg_LPfunction * internal_lp_function_mul(pg_LPfunction * t, double factor);
extern pg_LPfunction * internal_lp_function_plus(pg_LPfunction * p1, pg_LPfunction * p2);

/* Optimized aggregation functions and all-related structures */
typedef struct lpAggstate
{
	int32			vl_len_;		/* varlena header (do not touch directly!) */
	double			factor0;
	HTAB 			*hashVnr;		/* A pointer to hash mapping VarNr --> lpTerm if a variable exist in "allTerms"  */
	MemoryContext   htMemCtx;  /* A memory context internally used by a hash table */
} lpAggstate;

/* These are the state/final function, used to implement the aggregation of large pg_LPfunction */

extern Datum lp_function_sum_trans(PG_FUNCTION_ARGS);
extern Datum lp_function_sum_final(PG_FUNCTION_ARGS);

/* ***********************  For experimental purposes  ****************************** */

// Functions for adding two pg_LPfunction instances where variables are sorted ascendingly
extern Datum lp_function_plus_sorted(PG_FUNCTION_ARGS);
extern pg_LPfunction * internal_lp_function_plus_sorted(pg_LPfunction * p1, pg_LPfunction * p2);

// Functions for adding/aggregating pg_LPfunction instances based on ARRAYS
extern Datum lp_function_sum_array_trans(PG_FUNCTION_ARGS);
extern Datum lp_function_sum_array_final(PG_FUNCTION_ARGS);

/* The structure of the state variable of the array-based aggregation */
typedef struct lpAggArrayState
{
	int32		vl_len_;		/* varlena header (do not touch directly!) */
	double		factor0;
	int			fillFrom;		/* Indicate a range FROM where the array is filled */
	int			fillTo;			/* Indicate a range TO where the array is filled */
	double		* factarray;
} lpAggArrayState;


#endif   /* ADTLP_FUNCTION_H */
