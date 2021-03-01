#include "postgres.h"


#include "lp_function.h"
#include "utils/builtins.h"
#include "utils/memutils.h"
#include <limits.h>
#include <funcapi.h>


// TODO: Improvement: remove variables with zero factors

/*
** Input/Output routines
*/
PG_FUNCTION_INFO_V1(lp_function_in);
PG_FUNCTION_INFO_V1(lp_function_out);
PG_FUNCTION_INFO_V1(lp_function_make);
PG_FUNCTION_INFO_V1(lp_function_makeCnum);
PG_FUNCTION_INFO_V1(lp_function_makeCint4);
PG_FUNCTION_INFO_V1(lp_function_makeCbool);
PG_FUNCTION_INFO_V1(lp_function_makeCfloat8);
PG_FUNCTION_INFO_V1(lp_function_fmul);
PG_FUNCTION_INFO_V1(lp_function_fmulC);
PG_FUNCTION_INFO_V1(lp_function_fdiv);
PG_FUNCTION_INFO_V1(lp_function_plus);
PG_FUNCTION_INFO_V1(lp_function_minus);
PG_FUNCTION_INFO_V1(lp_function_minus1);
PG_FUNCTION_INFO_V1(lp_function_sum_trans);
PG_FUNCTION_INFO_V1(lp_function_sum_final);
PG_FUNCTION_INFO_V1(lp_function_unnest);
/******************* Experimental functions ****************** */
PG_FUNCTION_INFO_V1(lp_function_plus_sorted);
PG_FUNCTION_INFO_V1(lp_function_sum_array_trans);
PG_FUNCTION_INFO_V1(lp_function_sum_array_final);


// Internal declarations
const struct pg_LPfunction LPfunction_EMPTY = {sizeof(pg_LPfunction), 0, 0};

// Internal functions
void lp_function_to_stringinfo(pg_LPfunction * terms, StringInfoData * buf){
	if (terms)
	{
		int i;
		for(i=0; i< terms->numTerms; i++)
		{
			appendStringInfo(buf, "%gx%d+", terms->term[i].factor, terms->term[i].varNr);
		}
		appendStringInfo(buf, "%g", terms->factor0);
	}
}

//extern pg_LPfunction * internal_lp_function_copy(pg_LPfunction * t)
//{
//	pg_LPfunction * result;
//	result = (pg_LPfunction *) palloc(VARSIZE(t));
//	memcpy(result, t, VARSIZE(t));
//	return result;
//}

Datum lp_function_in(PG_FUNCTION_ARGS)
{
    ereport(ERROR, (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
                    errmsg("<datatype>lp_polygon_in() not implemented")));
    PG_RETURN_POINTER(NULL);
};

Datum lp_function_out(PG_FUNCTION_ARGS)
{
	pg_LPfunction * lppol = PG_GETARG_LPfunction(0);
	StringInfoData buf;
	initStringInfo(&buf);
	lp_function_to_stringinfo(lppol, &buf);
	PG_RETURN_CSTRING(buf.data);
}

// Build an pg_LPfunction for a single unknown variable
Datum lp_function_make(PG_FUNCTION_ARGS)
{
	long nr;
	pg_LPfunction * result;
	int size = LPfunction_SIZE(1);

	nr = PG_GETARG_INT64(0);

	result = (pg_LPfunction *) palloc0(size);
	SET_VARSIZE(result, size);

	result->numTerms=1;
	result->factor0 = 0;
	result->term[0].varNr = (int)nr;
	result->term[0].factor = 1;

	PG_RETURN_LPfunction(result);
}

// Build an pg_LPfunction from a single constant
Datum lp_function_makeCnum(PG_FUNCTION_ARGS)
{
	Datum      n = PG_GETARG_DATUM(0);  /* It has a type Numeric */
	pg_LPfunction * result;
	int size = LPfunction_SIZE(0);

	result = (pg_LPfunction *) palloc0(size);
	SET_VARSIZE(result, size);

	result->factor0 = (double) DatumGetFloat8(DirectFunctionCall1(numeric_float8_no_overflow, n));
	result->numTerms=0;

	PG_RETURN_LPfunction(result);
}

//// Build an pg_LPfunction from a single constant
Datum lp_function_makeCfloat8(PG_FUNCTION_ARGS)
{
	float8	   value = PG_GETARG_FLOAT8(0);

	pg_LPfunction * result;
	int size = LPfunction_SIZE(0);

	result = (pg_LPfunction *) palloc0(size);
	SET_VARSIZE(result, size);

	result->factor0 = (double) value;
	result->numTerms=0;

	PG_RETURN_LPfunction(result);
}

// Build an pg_LPfunction from a single constant
Datum lp_function_makeCint4(PG_FUNCTION_ARGS)
{
	int32	   value = PG_GETARG_INT32(0);

	pg_LPfunction * result;
	int size = LPfunction_SIZE(0);

	result = (pg_LPfunction *) palloc0(size);
	SET_VARSIZE(result, size);

	result->factor0 = (double) value;
	result->numTerms=0;

	PG_RETURN_LPfunction(result);
}

Datum lp_function_makeCbool(PG_FUNCTION_ARGS)
{
	bool value = PG_GETARG_BOOL(0);

	pg_LPfunction * result;
	int size = LPfunction_SIZE(0);

	result = (pg_LPfunction *) palloc0(size);
	SET_VARSIZE(result, size);

	result->factor0 = (double) ((int) value);
	result->numTerms=0;

	PG_RETURN_LPfunction(result);
}

extern pg_LPfunction * internal_lp_function_mul(pg_LPfunction * t, double factor)
{
	int i;
	pg_LPfunction * result;

	result = (pg_LPfunction *) palloc(VARSIZE(t));
	memcpy(result, t, VARSIZE(t));

	for (i=0; i< result->numTerms; i++)
		result-> term[i].factor *= factor;

	result->factor0 *= factor;

	return result;
}

Datum lp_function_fmul(PG_FUNCTION_ARGS)
{
	PG_RETURN_LPfunction(internal_lp_function_mul(PG_GETARG_LPfunction(0), PG_GETARG_FLOAT8(1)));
}

// A commutative version of the function
Datum lp_function_fmulC(PG_FUNCTION_ARGS)
{
	PG_RETURN_LPfunction(internal_lp_function_mul(PG_GETARG_LPfunction(1), PG_GETARG_FLOAT8(0)));
}

Datum lp_function_fdiv(PG_FUNCTION_ARGS)
{
	PG_RETURN_LPfunction(internal_lp_function_mul(PG_GETARG_LPfunction(0), 1.0/PG_GETARG_FLOAT8(1)));
}

/* Optimized aggregation functions routines based on HASH for large models
 * */
static inline lpAggstate * internal_lp_function_sum_trans(lpAggstate * state, pg_LPfunction * next)
{
	int 			i;
	bool            found;

	/* Create a state */
	if (state == NULL) {
		HASHCTL		   ctl;

		// Initialize the hash
		MemSet(&ctl, 0, sizeof(ctl));
		ctl.keysize = sizeof(int);
		ctl.entrysize = sizeof(lpTerm);		// Stores the pointers to double
		ctl.hash = tag_hash;
		ctl.hcxt = CurrentMemoryContext;

		state = palloc0(sizeof(lpAggstate));
		SET_VARSIZE(state, sizeof(lpAggstate));
		state-> factor0 = 0;

		state->hashVnr = hash_create("lp_function hash of variable numbers for efficient aggregation ",
										1024,  &ctl, HASH_ELEM | HASH_FUNCTION | HASH_CONTEXT );

		/* Take control over hash-tables memory context for performance optimization - see comments below.*/
		state->htMemCtx = CurrentMemoryContext->firstchild; /* We do this way, as HTAB is incomplete */
	}

	/* Add all terms from next */
	state->factor0 += next->factor0;
	for (i = 0; i < next->numTerms; i++) {
		lpTerm * term;

		term = (lpTerm *) hash_search(state->hashVnr, &(next->term[i].varNr), HASH_ENTER, &found);
		if (found)
			term->factor += next->term[i].factor;
		else
			term->factor = next->term[i].factor; /* Key is already inserted */
	}
	return state;
}

static inline pg_LPfunction * internal_lp_function_sum_final(lpAggstate * state, bool only_reset_hash_context) {
	pg_LPfunction * result = NULL;

	if (state != NULL && state->hashVnr != NULL) {
		int numEntries = hash_get_num_entries(state->hashVnr);
		HASH_SEQ_STATUS seqstatus;
		int i=0;
		lpTerm *term;

		result = (pg_LPfunction *) palloc(LPfunction_SIZE(numEntries));

		result->factor0 = state->factor0;
		result->numTerms = numEntries;

		/* Copy all entries (unsorted) */
		hash_seq_init(&seqstatus, state->hashVnr);

		while ((term = (lpTerm *) hash_seq_search(&seqstatus)) != NULL)
			if (i < numEntries)
				result->term[i++] = *term;

		Assert(i==numEntries);

		/* Sort the indices array */
		// 2014-08-25 No sorting is required
		// qsort(result->term, result->numTerms, sizeof(lpTerm), compareTerms);
		SET_VARSIZE(result, LPfunction_SIZE(result->numTerms));

		// ************ This is an optimization trick. *******
		// We do not destroy the table. Instead, only free the memory from the hash-table context.
		// Otherwise, MemoryContextDelete will cause overhead, when thousands of hash tables are created with ORDER BY
		// TODO: Use a non-PG HASH structure, which does not generate its own memory context
		if (only_reset_hash_context && state->htMemCtx)
			MemoryContextReset(state->htMemCtx);
		else
		    hash_destroy(state->hashVnr);
		pfree(state);
	}

	return result;
}


extern pg_LPfunction * internal_lp_function_plus(pg_LPfunction * p1, pg_LPfunction * p2)
{
	lpAggstate * state;
	pg_LPfunction * result;

	state = internal_lp_function_sum_trans(NULL, p1);
	state = internal_lp_function_sum_trans(state, p2);
	result = internal_lp_function_sum_final(state, false);

	return result;
}

Datum lp_function_plus(PG_FUNCTION_ARGS)
{
	pg_LPfunction * p1 = PG_ARGISNULL(0) ? (pg_LPfunction *)&LPfunction_EMPTY
									  : PG_GETARG_LPfunction(0);
	pg_LPfunction * p2 = PG_ARGISNULL(1) ? (pg_LPfunction *)&LPfunction_EMPTY
									  : PG_GETARG_LPfunction(1);

	PG_RETURN_LPfunction(internal_lp_function_plus(p1,p2));
}


extern Datum lp_function_minus(PG_FUNCTION_ARGS)
{
	pg_LPfunction * p1 = PG_ARGISNULL(0) ? (pg_LPfunction *)&LPfunction_EMPTY
										  : PG_GETARG_LPfunction(0);
	pg_LPfunction * p2 = PG_ARGISNULL(1) ? (pg_LPfunction *)&LPfunction_EMPTY
										  : PG_GETARG_LPfunction(1);

	PG_RETURN_LPfunction(internal_lp_function_plus(p1,internal_lp_function_mul(p2,-1)));
}

/* Unary version of minus */
extern Datum lp_function_minus1(PG_FUNCTION_ARGS)
{
	pg_LPfunction * p1 = PG_ARGISNULL(0) ? (pg_LPfunction *)&LPfunction_EMPTY
										  : PG_GETARG_LPfunction(0);

	PG_RETURN_LPfunction(internal_lp_function_mul(p1,-1));
}

extern Datum lp_function_sum_trans(PG_FUNCTION_ARGS)
{
	MemoryContext aggcontext;
	lpAggstate * state;

	if (!AggCheckCallContext(fcinfo, &aggcontext))
		ereport(ERROR, (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
								errmsg("lp_function_sum_trans() - must call from aggregate")));

	state = PG_ARGISNULL(0) ? NULL : (lpAggstate *) PG_GETARG_BYTEA_P(0);

	/* Discard NULL values of arg1 */
	if (!PG_ARGISNULL(1))
	{
		pg_LPfunction	* func = PG_GETARG_LPfunction(1);
		MemoryContext 	old_context;

		/* Create a hash in the aggcontext so that it persist between function calls */
		old_context = MemoryContextSwitchTo(aggcontext);
		state = internal_lp_function_sum_trans(state, func);
		MemoryContextSwitchTo(old_context);
	}

	if (state != NULL)
		PG_RETURN_BYTEA_P(state);

	PG_RETURN_NULL();
}

extern Datum lp_function_sum_final(PG_FUNCTION_ARGS)
{
	lpAggstate * state;

	if (!AggCheckCallContext(fcinfo, NULL))
		ereport(ERROR, (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
								errmsg("lp_function_sum_final() - must call from aggregate")));

	state = PG_ARGISNULL(0) ? NULL : (lpAggstate *) PG_GETARG_BYTEA_P(0);

	PG_RETURN_LPfunction (internal_lp_function_sum_final(state, true));
}

/* *************************** Experimental functions *********************** */

/*
 * Routines for adding two LPfunctions where variables sorted on variable numbers.
 * There are significantly slowed than HASH-based routines
 * */
extern pg_LPfunction * internal_lp_function_plus_sorted(pg_LPfunction * p1, pg_LPfunction * p2)
{
	// Pesimistic size of result
	pg_LPfunction * result = (pg_LPfunction *) palloc(LPfunction_SIZE(p1->numTerms + p2->numTerms));
	int i=0, j=0;

	// Check if concatenation of terms is sufficient
	if (p1->numTerms == 0)
		memcpy(result, p2, VARSIZE(p2));
	else if (p2->numTerms == 0)
		memcpy(result, p1, VARSIZE(p1));
	else if (p1->term[p1->numTerms-1].varNr < p2->term[0].varNr)
	{ /* We can concatenate p1 and p2 */
		result->numTerms = p1->numTerms + p2->numTerms;
		memcpy(result->term, p1->term, sizeof(lpTerm) * p1->numTerms);
		memcpy((result->term +p1->numTerms), p2->term, sizeof(lpTerm) * p2->numTerms);
	} else if (p2->term[p2->numTerms-1].varNr < p1->term[0].varNr)
	{ /* We can concatenate p2 and p1 */
		result->numTerms = p1->numTerms + p2->numTerms;
		memcpy(result->term, p2->term, sizeof(lpTerm) * p2->numTerms);
		memcpy((result->term + p2->numTerms), p1->term, sizeof(lpTerm) * p1->numTerms);
	} else { /*  Otherwise, let's merge terms */
		result->numTerms = 0;
		while ((i < p1->numTerms) || (j < p2->numTerms))
			if (i >= p1->numTerms
					|| ((j < p2->numTerms)
							&& (p1->term[i].varNr > p2->term[j].varNr))) {
				result->term[result->numTerms] = p2->term[j];
				result->numTerms++;
				j++;
			} else if (j >= p2->numTerms
					|| p1->term[i].varNr < p2->term[j].varNr) {
				result->term[result->numTerms] = p1->term[i];
				result->numTerms++;
				i++;
			} else		// When varNr's are equal
			{
				result->term[result->numTerms] = p1->term[i];
				result->term[result->numTerms].factor += p2->term[j].factor;
				result->numTerms++;
				i++;
				j++;
			}
		// Finally, release the unused memory
		result = repalloc(result, LPfunction_SIZE(result->numTerms));
	}

	/* Finally compute the sum of free residuals */
	result->factor0 = p1->factor0 + p2->factor0;
	SET_VARSIZE(result, LPfunction_SIZE(result->numTerms));

	return result;
}

Datum lp_function_plus_sorted(PG_FUNCTION_ARGS)
{
	pg_LPfunction * p1 = PG_ARGISNULL(0) ? (pg_LPfunction *)&LPfunction_EMPTY
									  : PG_GETARG_LPfunction(0);
	pg_LPfunction * p2 = PG_ARGISNULL(1) ? (pg_LPfunction *)&LPfunction_EMPTY
									  : PG_GETARG_LPfunction(1);

	PG_RETURN_LPfunction(internal_lp_function_plus_sorted(p1,p2));
}

/* ************** ARRAY-based aggregation **************************** */
extern Datum lp_function_sum_array_trans(PG_FUNCTION_ARGS)
{
	MemoryContext 			aggcontext;
	lpAggArrayState 		* state;

	if (!AggCheckCallContext(fcinfo, &aggcontext))
		ereport(ERROR, (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
								errmsg("lp_function_sum_array_trans() - must call from aggregate")));

	state = PG_ARGISNULL(0) ? NULL : (lpAggArrayState *) PG_GETARG_BYTEA_P(0);

	/* Discard NULL values of arg1 */
	if (!PG_ARGISNULL(1))
	{
		pg_LPfunction 		* fn = PG_GETARG_LPfunction(1);
		MemoryContext 		old_context;
		int 				i;

		/* Create a hash in the aggcontext so that it persist between function calls */
		old_context = MemoryContextSwitchTo(aggcontext);

		if (state == NULL)
		{
			state = palloc(sizeof(lpAggArrayState));
			SET_VARSIZE(state, sizeof(lpAggArrayState));
			state->factor0 = 0;
			state->fillFrom = INT_MAX;
			state->fillTo = INT_MIN;
			state->factarray = NULL;
		}

		/* Fill the factor array */
		state->factor0 += fn->factor0;

		for (i=0; i < fn->numTerms; i++)
		{
			int 	varNr  = fn->term[i].varNr;
			double  factor = fn->term[i].factor;

			if (state->fillFrom > state->fillTo)
			{
				/* The array has not been initializes yet, so let's do it*/
				state->fillFrom = state->fillTo = varNr;
				state->factarray = palloc(sizeof(double));
				state->factarray[0] = 0;
			} else if (varNr > state->fillTo)
			{
				/* An array has to grow upwards */
				int curSize = state->fillTo - state->fillFrom + 1;
				int newSize = curSize;

				while (state->fillFrom + newSize <= varNr)
						newSize = newSize < 1024 ? 1024 : newSize * 2;

				state->factarray = repalloc(state->factarray, newSize * sizeof(double));
				MemSet((state->factarray + curSize), 0, (newSize - curSize) * sizeof(double));

				state->fillTo = state->fillFrom + newSize - 1;
			} else if (varNr < state->fillFrom)
			{
				int 	curSize = state->fillTo - state->fillFrom + 1;
				int 	newSize = curSize;
				double  *newarray;

				while (state->fillTo - newSize >= varNr)
						newSize = newSize < 1024 ? 1024 : newSize * 2;

				newarray = palloc0(newSize * sizeof(double));
				memcpy(newarray + newSize - curSize, state->factarray, curSize * sizeof(double));

				pfree(state->factarray);
				state->factarray = newarray;
				state->fillFrom = state->fillTo - newSize + 1;
			} else
				Assert(false);

		    /* OK, so variable falls into the array range now */
			state->factarray[varNr - state->fillFrom] += factor;
		}

		MemoryContextSwitchTo(old_context);
	}

	if (state != NULL)
		PG_RETURN_BYTEA_P(state);

	PG_RETURN_NULL();
}

extern Datum lp_function_sum_array_final(PG_FUNCTION_ARGS)
{
	lpAggArrayState	* state;
	pg_LPfunction	* result;
	int				numVars;
	int				i;

	if (!AggCheckCallContext(fcinfo, NULL))
		ereport(ERROR, (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
								errmsg("lp_function_sum_array_final() - must call from aggregate")));

	state = PG_ARGISNULL(0) ? NULL : (lpAggArrayState *) PG_GETARG_BYTEA_P(0);

	if (state == NULL)
		PG_RETURN_NULL();

	/* Calculate a number of variables */
	numVars = 0;
	for (i=0; i < state->fillTo - state->fillFrom + 1; i++)
		if (state->factarray[i] != 0)
			numVars++;

	result = (pg_LPfunction *) palloc(LPfunction_SIZE(numVars));
	result->factor0 = state->factor0;
	result->numTerms = numVars;

	numVars = 0;
	for (i=0; i < state->fillTo - state->fillFrom + 1; i++)
		if (state->factarray[i] != 0)
		{
			result->term[numVars].varNr  = state->fillFrom + i;
			result->term[numVars].factor = state->factarray[i];
			numVars++;
		}

	SET_VARSIZE(result, LPfunction_SIZE(result->numTerms));

	/* Free the state */
	pfree(state->factarray);
	pfree(state);

	PG_RETURN_LPfunction (result);
}

// Split individual lp_function expression to individivle terms
extern Datum lp_function_unnest(PG_FUNCTION_ARGS){
    FuncCallContext     *funcctx;
    int                  call_cntr;
    int                  max_calls;
    pg_LPfunction 	*func;

    /* stuff done only on the first call of the function */
    if (SRF_IS_FIRSTCALL())
    {
        MemoryContext   oldcontext;

        /* create a function context for cross-call persistence */
        funcctx = SRF_FIRSTCALL_INIT();

        /* switch to memory context appropriate for multiple function calls */
        oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);

        /* gets the lp_function argument */
        funcctx->user_fctx = (void *) (PG_ARGISNULL(0) ? (pg_LPfunction *)&LPfunction_EMPTY : PG_GETARG_LPfunction(0));
	funcctx->max_calls = ((pg_LPfunction *)funcctx->user_fctx)->numTerms;
	
        MemoryContextSwitchTo(oldcontext);
    }

    /* stuff done on every call of the function */
    funcctx = SRF_PERCALL_SETUP();

    call_cntr            = funcctx->call_cntr;
    func		 = (pg_LPfunction *) funcctx->user_fctx;  
    max_calls            = funcctx->max_calls;

    if (call_cntr < max_calls)    /* do when there is more left to send */
    {
        pg_LPfunction *   	outfunc;
	Datum		  	result;

        /*
         * Prepare the return value, which is lp_function with 1 term
         */
	outfunc = (pg_LPfunction *) palloc(LPfunction_SIZE(1));
	outfunc->factor0 = 0;
	outfunc->numTerms = 1;
	outfunc->term[0].varNr  = func->term[call_cntr].varNr;
	outfunc->term[0].factor = func->term[call_cntr].factor;
	SET_VARSIZE(outfunc, LPfunction_SIZE(outfunc->numTerms));

	result = PointerGetDatum(outfunc);

        SRF_RETURN_NEXT(funcctx, result);
    }
    else    /* do when there is no more left */
    {
        SRF_RETURN_DONE(funcctx);
    }	
}
