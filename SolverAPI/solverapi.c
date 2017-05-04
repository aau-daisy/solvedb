/*
 * solver-api.c
 *
 *  Created on: Nov 14, 2012
 *      Author: laurynas
 */

#include "solverapi.h"
#include "solverapi_utils.h"
#include "utils/builtins.h"
#include "access/htup_details.h"
// For PostgreSQL 9.3.1 security
#include "miscadmin.h"
#include "lib/stringinfo.h"
#include "utils/guc.h"


#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

/*
 * Function parses SQL statement passed as argument 0, and ouputs a setof SL_Attribute_Desc
 * to describe the target of the query.
 */
PG_FUNCTION_INFO_V1(sl_get_attributes_from_sql);
Datum sl_get_attributes_from_sql(PG_FUNCTION_ARGS) {
	FuncCallContext *funcctx;
	int call_cntr;
	int max_calls;
	TupleDesc tupdesc;
	AttInMetadata *attinmeta;

	/* stuff done only on the first call of the function */
	if (SRF_IS_FIRSTCALL()) {
		MemoryContext oldcontext;
		text * sql;

		/* create a function context for cross-call persistence */
		funcctx = SRF_FIRSTCALL_INIT();

		/* switch to memory context appropriate for multiple function calls */
		oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);

		/* Build a list of attributes */
		sql = PG_GETARG_TEXT_PP(0);
		funcctx->user_fctx = (void *) sl_get_query_attributes(text_to_cstring(sql), (unsigned int *) &(funcctx->max_calls));
		PG_FREE_IF_COPY(sql,0);

		/* Build a tuple descriptor for our result type */
		if (get_call_result_type(fcinfo, NULL, &tupdesc) != TYPEFUNC_COMPOSITE)
			ereport(ERROR,
					(errcode(ERRCODE_FEATURE_NOT_SUPPORTED), errmsg("function returning record called in context "
					"that cannot accept type record")));

		/*
		 * generate attribute metadata needed later to produce tuples from raw
		 * C strings
		 */
		attinmeta = TupleDescGetAttInMetadata(tupdesc);
		funcctx->attinmeta = attinmeta;

		MemoryContextSwitchTo(oldcontext);
	}

	/* stuff done on every call of the function */
	funcctx = SRF_PERCALL_SETUP();

	call_cntr = funcctx->call_cntr;
	max_calls = funcctx->max_calls;
	attinmeta = funcctx->attinmeta;

	if (call_cntr < max_calls) /* do when there is more left to send */
	{
		SL_Attribute_Desc * d = (SL_Attribute_Desc *) funcctx->user_fctx;
		char * values[3];
		HeapTuple tuple;
		Datum result;

		values[0] = d[call_cntr].att_name;
		values[1] = d[call_cntr].att_type;
		values[2] = SL_ATTKIND_TO_PG_ENUMVALUE(d[call_cntr].att_kind);

		/* build a tuple */
		tuple = BuildTupleFromCStrings(attinmeta, values);

		/* make the tuple into a datum */
		result = HeapTupleGetDatum(tuple);

		/* clean up (this is not really necessary) */
		pfree(values[0]);
		pfree(values[1]);

		SRF_RETURN_NEXT(funcctx, result);
	} else /* do when there is no more left */
	{
		pfree(funcctx->user_fctx);
		SRF_RETURN_DONE(funcctx);
	}
	return 0; /* To make a compiler quiet*/
}

/*
 * A solver method to test the solver API routines. It does not solve anything, just
 * outputs the unchanged input relation.
 */
PG_FUNCTION_INFO_V1(sl_dummy_solve);
Datum sl_dummy_solve(PG_FUNCTION_ARGS) {
	SL_SOLVER_BEGIN

	Sl_Viewsql_Out out;
	Datum arg_d = PG_GETARG_SLSOLVERARGDATUM(0);
	out = sl_build_out(arg_d);

	SL_SOLVER_RETURN(out, 0, NULL, NULL);
	SL_SOLVER_END;
}

/* The function is used to create TMP table in security-restricted environment in PostgreSQL 9.3.1.
 * Hope this will not be needed in later DBMS editions */
PG_FUNCTION_INFO_V1(sl_createtmptable_unrestricted);
Datum sl_createtmptable_unrestricted(PG_FUNCTION_ARGS)
{
	char 		   * tmptable_name = text_to_cstring(PG_GETARG_TEXT_PP(0));
	char 		   * sql 		   = text_to_cstring(PG_GETARG_TEXT_PP(1));
	StringInfoData query_buf;
	int 		   ret;
	int64		   num_rows;
	bool		   restr_operation;
	Oid            save_userid;
	int            save_sec_context;
	int            save_nestlevel;

    restr_operation = InSecurityRestrictedOperation();
	if (restr_operation) {
		/* PostgreSQL 9.3.1 patch the security */
		GetUserIdAndSecContext(&save_userid, &save_sec_context);
		/* Undo the restricted operation */
		SetUserIdAndSecContext(save_userid,
				(save_sec_context ^ SECURITY_RESTRICTED_OPERATION) & save_sec_context);
		save_nestlevel = NewGUCNestLevel();
	}

	/* Connect to SPI manager */
	if ((ret = SPI_connect()) < 0) {
		elog(ERROR, "SolveDB: SPI_connect returned %d", ret); 		/* internal error */
	}

	/* Build a create temporal table SQL */
	initStringInfo(&query_buf);

	/* Build an create temp table sql statement */
	appendStringInfo(&query_buf, "CREATE TEMP TABLE %s AS (%s)", tmptable_name, sql);

	if ((ret = SPI_exec(query_buf.data, 0)) != SPI_OK_UTILITY)
			elog(ERROR, "SolveDB: Cannot create a temporal table %s. SPI error code: %d", tmptable_name, ret);

	num_rows = SPI_processed;

	resetStringInfo(&query_buf);
	pfree(query_buf.data);

	/* release SPI related resources (and return to caller's context) */
	SPI_finish();

	if (restr_operation) {
		/* Roll back any GUC changes */
		AtEOXact_GUC(false, save_nestlevel);
		/* Restore userid and security context */
		SetUserIdAndSecContext(save_userid, save_sec_context);
	}
	/* Return the number of rows processed */
	PG_RETURN_INT64(num_rows);
}

PG_FUNCTION_INFO_V1(sl_ctr_in);
extern Datum sl_ctr_in(PG_FUNCTION_ARGS)
{
    ereport(ERROR, (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
                    errmsg("sl_ctr_in() not implemented")));
    PG_RETURN_POINTER(NULL);
}

PG_FUNCTION_INFO_V1(sl_ctr_out);
extern Datum sl_ctr_out(PG_FUNCTION_ARGS)
{
	Sl_Ctr * ctr = PG_GETARG_SLCtr(0);
	PG_RETURN_CSTRING(sl_ctr_to_cstring(ctr));
}

PG_FUNCTION_INFO_V1(sl_ctr_make);
extern Datum sl_ctr_make(PG_FUNCTION_ARGS)
{
	 /* get the provided element, being careful in case it's NULL */
	if (PG_ARGISNULL(2))
		elog(ERROR, "sl_ctr_make cannot accept NULL values");

	PG_RETURN_SLCtr(sl_ctr_from_datum(PG_GETARG_FLOAT8(0),
									  PG_GETARG_SLCtrType(1),
									  get_fn_expr_argtype(fcinfo->flinfo, 2),
									  PG_GETARG_DATUM(2)));
}

PG_FUNCTION_INFO_V1(sl_ctr_makefrom);
extern Datum sl_ctr_makefrom(PG_FUNCTION_ARGS)
{
	Sl_Ctr * ctr = PG_GETARG_SLCtr(2);

	PG_RETURN_SLCtr(sl_ctr_from_datum(PG_GETARG_FLOAT8(0),
									  PG_GETARG_SLCtrType(1),
									  ctr->x_type,
									  sl_ctr_get_x_val(ctr)));
}

PG_FUNCTION_INFO_V1(sl_ctr_get_c);
extern Datum sl_ctr_get_c(PG_FUNCTION_ARGS)
{
	Sl_Ctr * ctr = PG_GETARG_SLCtr(0);
	PG_RETURN_FLOAT8(ctr->c_val);
}

PG_FUNCTION_INFO_V1(sl_ctr_get_op);
extern Datum sl_ctr_get_op(PG_FUNCTION_ARGS)
{
	Sl_Ctr * ctr = PG_GETARG_SLCtr(0);
	PG_RETURN_DATUM(Sl_CtrTypeGetDatum(ctr->op));
}

PG_FUNCTION_INFO_V1(sl_ctr_get_x);
extern Datum sl_ctr_get_x(PG_FUNCTION_ARGS)
{
	Sl_Ctr * ctr = PG_GETARG_SLCtr(0);
	if (get_fn_expr_argtype(fcinfo->flinfo, 1) != ctr->x_type)
		elog(ERROR, "sl_ctr_get_x() failed because the provided template is of the different type than the element X");

	PG_RETURN_DATUM(sl_ctr_get_x_val(ctr));
}
