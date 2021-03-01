/*
 * libsolverapi.c
 *
 *  Created on: Nov 14, 2012
 *      Author: laurynas
 */

#include "libsolverapi.h"
#include "catalog/pg_type.h"
#include "utils/array.h"
#include "utils/lsyscache.h"
#include "utils/builtins.h"
#include "executor/spi.h"
#include "funcapi.h"
#include "low_level_utils.h"
#include "parser/parse_func.h"
#include "catalog/pg_type.h"
#include "solverapi_utils.h"
#include "utils/datum.h"
#include "access/htup_details.h"
#include "lib/stringinfo.h"
#include "access/tupmacs.h"

/* Function prototypes */
static Datum sl_exec_sql(const char *sql, int arg_count, Oid *arg_types, Datum * arg_values);

extern SL_Attribute_Desc * DatumGetSLAttributeDesc(Datum ad_datum)
{
	SL_Attribute_Desc * a = palloc0(sizeof(SL_Attribute_Desc));
	HeapTupleHeader t = (HeapTupleHeader) PG_DETOAST_DATUM(ad_datum);
	Datum d;
	bool isnull;

	d = GetAttributeByName(t, "att_name", &isnull);
	Assert(d); Assert(!isnull);
	a->att_name = NameStr(*DatumGetName(d));

	d = GetAttributeByName(t, "att_type", &isnull);
	Assert(d); Assert(!isnull);
	a->att_type = NameStr(*DatumGetName(d));

	d = GetAttributeByName(t, "att_kind", &isnull);
	Assert(d); Assert(!isnull);
	a->att_kind = DatumGetSLAttributeKind(d);

	return a;
}

extern SL_Parameter_Value * DatumGetSLParameterValue(Datum pv_datum)
{
	SL_Parameter_Value * pv = palloc0(sizeof(SL_Parameter_Value));
	HeapTupleHeader t = (HeapTupleHeader) PG_DETOAST_DATUM(pv_datum);
	Datum d;
	bool isnull;

	d = GetAttributeByName(t, "param", &isnull);
	Assert(d); Assert(!isnull);
	pv->param = NameStr(*DatumGetName(d));

	d = GetAttributeByName(t, "value_i", &isnull);
	if (!isnull) {
		pv->value_i = DatumGetInt32(d);
	}

	d = GetAttributeByName(t, "value_f", &isnull);
	if (!isnull) {
		Assert(d);
		pv->value_f = DatumGetFloat8(d);
	}

	d = GetAttributeByName(t, "value_t", &isnull);
	if (!isnull) {
		Assert(d);
		pv->value_t = text_to_cstring(DatumGetTextP(d) );
	}

	return pv;
}

extern SL_Problem * DatumGetSLProblem(Datum p_datum)
{
	SL_Problem * p = palloc(sizeof(SL_Problem));
	HeapTupleHeader t = (HeapTupleHeader) PG_DETOAST_DATUM(p_datum);
	Datum d;
	bool isnull;
	List * list;
	ListCell *c;

	d = GetAttributeByName(t, "input_sql", &isnull);
	Assert(d); Assert(!isnull);
	p->input_sql = text_to_cstring(DatumGetTextP(d));

	d = GetAttributeByName(t, "input_alias", &isnull);
	Assert(d); Assert(!isnull);
	p->input_alias = NameStr(*DatumGetName(d));

	d = GetAttributeByName(t, "cols_unknown", &isnull);
	Assert(d); Assert(!isnull);
	list = get_datum_array_contents(DatumGetArrayTypeP(d));
	p->cols_unknown = NIL;
	foreach(c,list)
	{
		p->cols_unknown = lappend(p->cols_unknown, NameStr(*DatumGetName((Datum)lfirst(c))));
	}

	d = GetAttributeByName(t, "obj_dir", &isnull);
	Assert(d); Assert(!isnull);
	p->obj_dir = DatumGetSLObjDir(d);

	d = GetAttributeByName(t, "obj_sql", &isnull);
	p->obj_sql = isnull ? NULL : text_to_cstring(DatumGetTextP(d));

	p->ctr_sql = NIL;
	d = GetAttributeByName(t, "ctr_sql", &isnull);
	Assert(d);
	if (!isnull)
	{
		list = get_datum_array_contents(DatumGetArrayTypeP(d));
		p->ctr_sql = NIL;
		foreach(c,list)
		{
			p->ctr_sql = lappend(p->ctr_sql, text_to_cstring(DatumGetTextP((Datum)lfirst(c))));
		}
	}

	return p;
}

extern SL_Solver_Arg * DatumGetSLSolverArg(Datum sa_datum)
{
	SL_Solver_Arg * sa = palloc0(sizeof(SL_Solver_Arg));
	HeapTupleHeader t = (HeapTupleHeader) PG_DETOAST_DATUM(sa_datum);
	Datum d;
	bool isnull;
	List * list;
	ListCell *c;

	d = GetAttributeByName(t, "api_version", &isnull);
	Assert(d); 	Assert(!isnull);
	sa->api_version = DatumGetInt32(d);

	if (SL_VERSION_MAJOR(sa->api_version) != SL_VERSION_MAJOR(SL_API_VERSION))
        ereport(ERROR,
                        (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                         errmsg("Solver argument of version %d.%d cannot be processed with the Solver API of version %d.%d",
                        		 SL_VERSION_MAJOR(sa->api_version), SL_VERSION_MINOR(sa->api_version),
                        		 SL_VERSION_MAJOR(SL_API_VERSION),  SL_VERSION_MINOR(SL_API_VERSION))));

	d = GetAttributeByName(t, "solver_name", &isnull);
	Assert(d); 	Assert(!isnull);
	sa->solver_name = NameStr(*DatumGetName(d));

	d = GetAttributeByName(t, "method_name", &isnull);
	Assert(d); 	Assert(!isnull);
	sa->method_name = NameStr(*DatumGetName(d));

	d = GetAttributeByName(t, "params", &isnull);
	Assert(d); 	Assert(!isnull);
	list = get_datum_array_contents(DatumGetArrayTypeP(d));
	sa->params = NIL; //palloc0(sizeof(SL_Parameter_Value) * list_length(list));
	foreach(c,list)
	{
		sa->params = lappend(sa->params, DatumGetSLParameterValue((Datum) lfirst(c)));
	}

	d = GetAttributeByName(t, "problem", &isnull);
	Assert(d); 	Assert(!isnull);
	sa->problem = DatumGetSLProblem(d);

	d = GetAttributeByName(t, "prb_colcount", &isnull);
	Assert(d); 	Assert(!isnull);
	sa->prb_colcount = DatumGetInt32(d);

	d = GetAttributeByName(t, "prb_rowcount", &isnull);
	Assert(d); 	Assert(!isnull);
	sa->prb_rowcount = DatumGetInt64(d);

	d = GetAttributeByName(t, "prb_varcount", &isnull);
	Assert(d); 	Assert(!isnull);
	sa->prb_varcount = DatumGetInt64(d);

	d = GetAttributeByName(t, "tmp_name", &isnull);
	Assert(d); 	Assert(!isnull);
	sa->tmp_name = NameStr(*DatumGetName(d));

	d = GetAttributeByName(t, "tmp_id", &isnull);
	Assert(d); 	Assert(!isnull);
	sa->tmp_id = NameStr(*DatumGetName(d));

	sa->tmp_attrs = NIL;
	d = GetAttributeByName(t, "tmp_attrs", &isnull);
	Assert(d); 	Assert(!isnull);
	list = get_datum_array_contents(DatumGetArrayTypeP(d));
	foreach(c,list)
	{
		sa->tmp_attrs = lappend(sa->tmp_attrs, DatumGetSLAttributeDesc((Datum) lfirst(c)));
	}

	return sa;
}

/* Methods to retrieve solver/method parameter values */
extern bool sl_param_isset(SL_Solver_Arg *arg, const char *parname)
{
	ListCell 			 *c;

	foreach(c, arg->params)
	{
		SL_Parameter_Value  *pv = lfirst(c);
		if (strcasecmp(pv->param, parname) == 0)
			return true;
	}
	return false;
}

/* Methods to retrieve solver/method parameter values */
extern SL_Parameter_Value * sl_param_get(SL_Solver_Arg *arg, const char *parname)
{
	ListCell 			 *c;

	foreach(c, arg->params)
	{
		SL_Parameter_Value  *pv = lfirst(c);
		if (strcasecmp(pv->param, parname) == 0)
			return pv;
	}
	elog(ERROR, "SolverAPI: Parameter %s is not set", parname);
	return NULL;
}



extern Sl_Viewsql_Out DatumGetSLViewSQLOut(Datum arg_datum)
{
	HeapTupleHeader t = (HeapTupleHeader) PG_DETOAST_DATUM(arg_datum);
	Sl_Viewsql_Out vs;
	Datum d;
	bool isnull;

	d = GetAttributeByName(t, "sql", &isnull);
	Assert(d); 	Assert(!isnull);
	vs = text_to_cstring(DatumGetTextP(d));

	return vs;
}

extern Datum SLViewSQLOutGetDatum(Sl_Viewsql_Out out)
{
	TupleDesc       tupdesc;
	HeapTuple 		tuple;
	Datum			datums[1];
	bool			isnull[1];

	tupdesc = TypeGetTupleDesc(TypenameGetTypid(SL_PGNAME_Sl_Viewsql_Out), NIL);
	Assert(tupdesc);
	datums[0] = CStringGetTextDatum(out);
	isnull[0] = false;
	tuple = heap_form_tuple(tupdesc, datums, isnull);

	return HeapTupleGetDatum(tuple);
}

extern Sl_Viewsql_Dst DatumGetSLViewSQLDst(Datum arg_datum)
{
	HeapTupleHeader t = (HeapTupleHeader) PG_DETOAST_DATUM(arg_datum);
	Sl_Viewsql_Dst vs;
	Datum d;
	bool isnull;

	d = GetAttributeByName(t, "sql", &isnull);
	Assert(d); 	Assert(!isnull);
	vs = text_to_cstring(DatumGetTextP(d));
	return vs;
}

extern Datum SLViewSQLDstGetDatum(Sl_Viewsql_Dst dst)
{
	TupleDesc       tupdesc;
	HeapTuple 		tuple;
	Datum			datums[1];

	tupdesc = TypeGetTupleDesc(TypenameGetTypid(SL_PGNAME_Sl_Viewsql_Dst), NIL);
	Assert(tupdesc);
	datums[0] = CStringGetTextDatum(dst);
	tuple = heap_form_tuple(tupdesc, datums, false);

	return HeapTupleGetDatum(tuple);
}

static Datum sl_exec_sql(const char *sql, int arg_count, Oid *arg_types, Datum * arg_values)
{
	int				ret;
	SPIPlanPtr		plan;
	uint32			proc;
	SPITupleTable 	* spi_tuptable;
	HeapTuple       spi_tuple;
	bool 			is_null;
	Datum 			result;

    /* Now build query */
	SPI_push_conditional();
    if ((ret = SPI_connect()) < 0)
            elog(ERROR, "SolverAPI: SPI_connect returned %d", ret);

    plan = SPI_prepare(sql, arg_count, arg_types);
    if (plan == NULL)
            elog(ERROR, "SolverAPI: SPI execution failed for query %s", sql);

    /* Execute the plan */
    ret = SPI_execp(plan, arg_values, NULL, 1);
    if (ret < 0)
            elog(ERROR, "SolverAPI: SPI_execp returned %d", ret);

    spi_tuptable = SPI_tuptable;

    if ((proc = SPI_processed) != 1 || (spi_tuptable->tupdesc->natts != 1))
        ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                                        errmsg("SolverAPI: Query returned unexpected number of rows or columns."),
                                        errdetail("Expected a single row and a single column in SPI result, got %d and %d.",
                                        		proc,
                                        		spi_tuptable->tupdesc->natts)));
    spi_tuple = spi_tuptable->vals[0];
    Assert(spi_tuple!=NULL);

    result = SPI_getbinval(SPI_copytuple(spi_tuple), spi_tuptable->tupdesc, 1, &is_null);
    if (is_null)
    	result = 0;

    SPI_finish();
    SPI_pop_conditional(pushed);

    return result;
}

/* Source level view SQL generators */
Sl_Viewsql_Out sl_build_out(Datum sa_datum)
{
	Oid            arg_types[1];
	Datum		   arg_values[1];

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_values[0] =  sa_datum;

	return DatumGetSLViewSQLOut(sl_exec_sql("SELECT sl_build_out($1)", 1, arg_types, arg_values));
}

Sl_Viewsql_Out sl_build_out_userdefined(Datum sa_datum, const char * user_sql)
{
	Oid            arg_types[2];
	Datum		   arg_values[2];

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_types [1] = TEXTOID;
	arg_values[0] = sa_datum;
	arg_values[1] = CStringGetTextDatum(user_sql);

	return DatumGetSLViewSQLOut(sl_exec_sql("SELECT sl_build_out_userdefined($1, $2)", 2, arg_types, arg_values));
}

Sl_Viewsql_Out sl_build_out_vars(Datum sa_datum)
{
	Oid            arg_types[1];
	Datum		   arg_values[1];

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_values[0] = sa_datum;

	return DatumGetSLViewSQLOut(sl_exec_sql("SELECT sl_build_out_vars($1)", 1, arg_types, arg_values));
}

Sl_Viewsql_Out sl_build_out_funcNmap(Datum sa_datum, Sl_Viewsql_Out base, const char ** funcs, const int numFuncs)
{
	Oid            arg_types[3];
	Datum		   arg_values[3];
	Datum		   *r_datums;
	int i;

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_types [1] = TypenameGetTypid(SL_PGNAME_Sl_Viewsql_Out);
	arg_types [2] = TEXTARRAYOID;
	arg_values[0] = sa_datum;
	arg_values[1] = SLViewSQLOutGetDatum(base);

	r_datums = palloc(sizeof(Datum) * numFuncs);
	for(i=0; i < numFuncs; i++)
		r_datums[i] = CStringGetTextDatum(funcs[i]);

	arg_values[2] =  (Datum) construct_array(r_datums, numFuncs, TEXTOID, -1, false, 'i');

	return DatumGetSLViewSQLOut(sl_exec_sql("SELECT sl_build_out_funcNmap($1, $2, $3)", 3, arg_types, arg_values));
}

Sl_Viewsql_Out sl_build_out_funcNsubst(Datum sa_datum, const char ** funcs, const int numFuncs)
{
	Oid            arg_types[2];
	Datum		   arg_values[2];
	Datum		   *r_datums;
	int i;

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_types [1] = TEXTARRAYOID;
	arg_values[0] = sa_datum;

	r_datums = palloc(sizeof(Datum) * numFuncs);
	for(i=0; i < numFuncs; i++)
		r_datums[i] = CStringGetTextDatum(funcs[i]);

	arg_values[1] = (Datum) construct_array(r_datums, numFuncs, TEXTOID, -1, false, 'i');;

	return DatumGetSLViewSQLOut(sl_exec_sql("SELECT sl_build_out_funcNsubst($1, $2)", 2, arg_types, arg_values));
}

Sl_Viewsql_Out sl_build_out_func1subst(Datum sa_datum, const char * func)
{
	Oid            arg_types[2];
	Datum		   arg_values[2];

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_types [1] = TEXTOID;
	arg_values[0] = sa_datum;
	arg_values[1] = CStringGetTextDatum(func);

	return DatumGetSLViewSQLOut(sl_exec_sql("SELECT sl_build_out_func1subst($1, $2)", 2, arg_types, arg_values));
}

Sl_Viewsql_Out sl_build_out_arrayNsubst(Datum sa_datum, const int * par_pos, const int numPars)
{
	Oid            arg_types[2];
	Datum		   arg_values[2];
	Datum		   *r_datums;
	int i;

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_types [1] = INT4ARRAYOID;
	arg_values[0] = sa_datum;

	r_datums = palloc(sizeof(Datum) * numPars);
	for(i=0; i < numPars; i++)
		r_datums[i] = Int32GetDatum(par_pos[i]);

	arg_values[1] = (Datum) construct_array(r_datums, numPars, INT4OID, sizeof(int32), true, 'i');;

	return DatumGetSLViewSQLOut(sl_exec_sql("SELECT sl_build_out_arrayNsubst($1, $2)", 2, arg_types, arg_values));
}

Sl_Viewsql_Out sl_build_out_array1subst(Datum sa_datum, const int  par_nr)
{
	Oid            arg_types[2];
	Datum		   arg_values[2];

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_types [1] = INT4OID;
	arg_values[0] = sa_datum;
	arg_values[1] = Int32GetDatum(par_nr);

	return DatumGetSLViewSQLOut(sl_exec_sql("SELECT sl_build_out_array1subst($1, $2)", 2, arg_types, arg_values));
}

Sl_Viewsql_Dst sl_build_dst_values(Datum sa_datum, Sl_Viewsql_Out out, char * cast_to)
{
	Oid            arg_types[3];
	Datum		   arg_values[3];

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_types [1] = TypenameGetTypid(SL_PGNAME_Sl_Viewsql_Out);
	arg_types [2] = TEXTOID;
	arg_values[0] = sa_datum;
	arg_values[1] = SLViewSQLOutGetDatum(out);
	arg_values[2] = CStringGetTextDatum(cast_to);

	return DatumGetSLViewSQLOut(sl_exec_sql("SELECT sl_build_dst_values($1, $2, $3)", 3, arg_types, arg_values));
}

Sl_Viewsql_Dst sl_build_dst_obj(Datum sa_datum, Sl_Viewsql_Out out)
{
	Oid            arg_types[2];
	Datum		   arg_values[2];

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_types [1] = TypenameGetTypid(SL_PGNAME_Sl_Viewsql_Out);
	arg_values[0] = sa_datum;
	arg_values[1] = SLViewSQLOutGetDatum(out);

	return DatumGetSLViewSQLOut(sl_exec_sql("SELECT sl_build_dst_obj($1, $2)", 2, arg_types, arg_values));
}

Sl_Viewsql_Dst sl_build_dst_ctr(Datum sa_datum, Sl_Viewsql_Out out, int ctr_nr)
{
	Oid            arg_types[3];
	Datum		   arg_values[3];

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_types [1] = TypenameGetTypid(SL_PGNAME_Sl_Viewsql_Out);
	arg_types [2] = INT4OID;
	arg_values[0] = sa_datum;
	arg_values[1] = SLViewSQLOutGetDatum(out);
	arg_values[2] = Int32GetDatum(ctr_nr);

	return DatumGetSLViewSQLOut(sl_exec_sql("SELECT sl_build_dst_ctr($1, $2, $3)", 3, arg_types, arg_values));
}

char * sl_return(Datum sa_datum, Sl_Viewsql_Out vsout)
{
	Oid            arg_types[2];
	Datum		   arg_values[2];

	arg_types [0] = TypenameGetTypid(SL_PGNAME_Sl_Solver_Arg);
	arg_types [1] = TypenameGetTypid(SL_PGNAME_Sl_Viewsql_Out);
	arg_values[0] = sa_datum;
	arg_values[1] = SLViewSQLOutGetDatum(vsout);

	return text_to_cstring(DatumGetTextP(sl_exec_sql("SELECT sl_return($1, $2)", 2, arg_types, arg_values)));
}

/* Constraint processing functions */
extern Sl_Unkvar DatumGetSLUnkvar(Datum unkvar_datum)
{
	HeapTupleHeader t = (HeapTupleHeader) PG_DETOAST_DATUM(unkvar_datum);
	Datum d;
	bool isnull;

	d = GetAttributeByName(t, "nr", &isnull);
	Assert(d); 	Assert(!isnull);
	return DatumGetInt64(d);
}

extern Datum SLUnkvarGetDatum(Sl_Unkvar unkvar)
{
	TupleDesc       tupdesc;
	HeapTuple 		tuple;
	Datum			datums[1];

	tupdesc = TypeGetTupleDesc(TypenameGetTypid(SL_PGNAME_Sl_Unkvar), NIL);
	Assert(tupdesc);
	datums[0] = Int64GetDatum(unkvar);
	tuple = heap_form_tuple(tupdesc, datums, false);

	return HeapTupleGetDatum(tuple);
}

extern Datum sl_ctr_get_x_val(Sl_Ctr* ctr) {
	if (!OidIsValid(ctr->x_type))
		elog(ERROR, "Cannot get the polymorphic value X from Sl_Ctr. OID of X is invalid.");

	/* Check if the value must be returned as value or a reference */
	if (get_typbyval(ctr->x_type))
		return *((Datum *)SL_CTR_XVAL_DATA_PTR(ctr));
	else
		return PointerGetDatum(SL_CTR_XVAL_DATA_PTR(ctr));
}

/* Constraint handling functions */
extern char * sl_ctr_to_cstring(Sl_Ctr * ctr)
{
	StringInfoData buf;
	initStringInfo(&buf);
	appendStringInfo(&buf, "%g", ctr->c_val);
	switch (ctr->op) {
	case SL_CtrType_EQ:
		appendStringInfo(&buf, "==");
		break;
	case SL_CtrType_NE:
		appendStringInfo(&buf, "!=");
		break;
	case SL_CtrType_LT:
		appendStringInfo(&buf, "<");
		break;
	case SL_CtrType_LE:
		appendStringInfo(&buf, "<=");
		break;
	case SL_CtrType_GE:
		appendStringInfo(&buf, ">=");
		break;
	case SL_CtrType_GT:
		appendStringInfo(&buf, ">");
		break;
	default:
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("Unexpected constraint type")));
		break;
	}
	/* Print the inner polymorphic element X*/
	if (SL_CTR_XVAL_DATA_SIZE(ctr)<=0 || !OidIsValid(ctr->x_type))
		appendStringInfo(&buf, "<INVALID ELEMENT X>");
	else
	{
		Oid 		typOutput;
		bool 		typIsVarlena;
		Datum		val;
		char		*result;

		val = sl_ctr_get_x_val(ctr);

		getTypeOutputInfo(ctr->x_type, &typOutput, &typIsVarlena);

		result = OidOutputFunctionCall(typOutput, val);
		appendStringInfo(&buf, "%s", result);
		pfree(result);
	}
	return buf.data;
}

extern Sl_Ctr* sl_ctr_from_datum(float8 val, SL_Ctr_Type c_type, Oid x_type, Datum x_val)
{
	Sl_Ctr 		*result;
    int16       typlen;
    bool        typbyval;
    char        typalign;
    Size		realSize;
    int			size;

	/* Get info about the X element */
	if (!OidIsValid(x_type))
	 	 elog(ERROR, "Could not determine data type of the polymorphic element X");

    /* get required info about the element type */
    get_typlenbyvalalign(x_type, &typlen, &typbyval, &typalign);

    if (!typbyval && DatumGetPointer(x_val) == NULL)
		elog(ERROR, "Cannot produce Sl_Ctr object when the polymorphic element X is NULL");

    /* make sure varlena is not toasted */
    if (typlen == -1)
    	x_val = PointerGetDatum(PG_DETOAST_DATUM(x_val));

    /* Measure the size of datum */
    realSize = datumGetSize(x_val, typbyval, typlen);

    /* Now start building the Sl_Ctr */
    size = SL_CTR_XVAL_DATA_OFFSET + realSize;
    result = (Sl_Ctr *) palloc(size);
    result->c_val = val;
    result->op = c_type;
    result->x_type = x_type;
	if (typbyval)
		*((Datum *)SL_CTR_XVAL_DATA_PTR(result)) = x_val;
	else
		 memcpy(SL_CTR_XVAL_DATA_PTR(result), DatumGetPointer(x_val), realSize);
	SET_VARSIZE(result, size);

	return result;
}

//static List *get_paramvalue_pairs(ArrayType *array);
//static List *buildConfParamList(SolveQuery * sq);
//
//extern SolveQuery * sol_datum_get_solvequery(Datum d)
//{
//	SolveQuery * query = (SolveQuery *) palloc0(sizeof(SolveQuery));
//
//	List * kv_pairs;
//	ListCell * c;
//
//	kv_pairs = get_paramvalue_pairs(DatumGetArrayTypeP(d));
//	query->colUnique= NULL;
//	query->obj_dir = SOL_ObjDir_Undefined;
//	query->colsUnknown = NIL;
//	query->sqlConstraints = NIL;
//	query->sqlObjective = NULL;
//	query->tableName = NULL;
//	query->solverParams = NIL;
//
//	foreach(c, kv_pairs)
//	{
//		SOL_ParamValue_Pair * p = (SOL_ParamValue_Pair *) lfirst(c);
//
//		if (strcmp(p->val1, "tbl_name") == 0)
//			query->tableName = pstrdup(p->val2);
//		else if (strcmp(p->val1, "col_unique") == 0)
//			query->colUnique = pstrdup(p->val2);
//		else if (strcmp(p->val1, "col_unknown") == 0)
//			query->colsUnknown = lappend(query->colsUnknown, pstrdup(p->val2));
//		else if (strcmp(p->val1, "obj_dir") == 0)
//		{
//			query->obj_dir = strcmp(p->val2, "maximize") == 0 ? SOL_ObjDir_Maximize:
//							 strcmp(p->val2, "minimize") == 0 ? SOL_ObjDir_Minimize:
//									 	 	 	 	 	 	 	SOL_ObjDir_Undefined;
//			if (query->obj_dir == SOL_ObjDir_Undefined)
//				ereport(ERROR,
//						(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("Specified objective direction is invalid")));
//		}
//		else if (strcmp(p->val1, "obj_sql") == 0)
//			query->sqlObjective = pstrdup(p->val2);
//		else if (strcmp(p->val1, "ctr_sql") == 0)
//			query->sqlConstraints = lappend(query->sqlConstraints, pstrdup(p->val2));
//		else if (strncmp(p->val1, "p_",2) == 0)
//		{
//			SOL_ParamValue_Pair * p = palloc(sizeof(SOL_ParamValue_Pair));
//			p->val1 = pstrdup((p->val1+2));		/* Skips the first two symbols  */
//			p->val2 = pstrdup(p->val2);
//			query->solverParams = lappend(query->solverParams, p);
//		}
//		else
//			return NULL;		/* Cannot build the query definition corectly */
//
//	}
//	list_free(kv_pairs);
//	return query;
//}
//
//extern Datum sol_solvequery_getdatum(SolveQuery * sq)
//{
//	List * plist;
//	Datum * r_datums;
//	ArrayType * result;
//	ListCell *c;
//	int dims[2];
//	int lbs[2];
//	int i;
//
//	plist = buildConfParamList(sq);
//	r_datums = palloc(sizeof(Datum) * list_length(plist));
//
//	// Convert a list to array
//	i = 0;
//	foreach(c, plist)
//	{
//		r_datums[i]= CStringGetTextDatum((char *) lfirst(c));
//		i++;
//	}
//
//	dims[0] = (int) list_length(plist) / 2;
//	dims[1] = 2;
//	lbs[0] = lbs[1] = 0;
//
//	result = construct_md_array(r_datums, NULL, 2, dims, lbs, TEXTOID, -1, false, 'i' );
//
//	PG_RETURN_POINTER(result);
//}
//
///* Checks if a solver's argument is set */
//extern bool sol_solarg_isset(SolveQuery * sq, char * arg);
///* Get the solver's argument */
//extern char * sol_solarg_get(SolveQuery * sq, char * arg);
//
//static List *buildConfParamList(SolveQuery * sq) {
//	ListCell *c;
//	List * params = NIL;
//	#define ADD_CONF_PAIR(p,v) if ((v) != NULL) params = lappend(lappend(params, p), v)
//
//	ADD_CONF_PAIR("tbl_name", sq->tableName);
//
//	ADD_CONF_PAIR("col_unique", sq->colUnique);
//
//	foreach(c, sq->colsUnknown)
//	{
//		char * col = lfirst(c);
//
//		ADD_CONF_PAIR("col_unknown", col);
//	}
//
//	ADD_CONF_PAIR("obj_dir", sq->obj_dir == SOL_ObjDir_Maximize ? "maximize" :
//						     sq->obj_dir == SOL_ObjDir_Minimize ? "minimize" : NULL);
//
//	ADD_CONF_PAIR("obj_sql", sq->sqlObjective);
//
//	foreach(c, sq->sqlConstraints)
//	{
//		char * col = lfirst(c);
//
//		ADD_CONF_PAIR("ctr_sql", col);
//	}
//
//	foreach(c, sq->solverParams)
//	{
//		SOL_ParamValue_Pair * p = (SOL_ParamValue_Pair *) lfirst(c);
//		char *pname = (char *) malloc(strlen(p->val1)+3);
//		strncpy(pname, "p_", 2);
//		strcpy((pname+2), p->val1);
//
//		ADD_CONF_PAIR(pname, p->val2);
//	}
//
//	return params;
//}
//
///*
// * Deconstructs a text[][] into a pairs of C-strings of type "SOL_ParamValue_Pair"
// * (note any NULL elements will be returned as NULL pointers)
// */
//static List *get_paramvalue_pairs(ArrayType *array)
//{
//	int			ndim = ARR_NDIM(array);
//	int		   *dims = ARR_DIMS(array);
//	int			nitems;
//	int16		typlen;
//	bool		typbyval;
//	char		typalign;
//	SOL_ParamValue_Pair  *pair;
//	List 	   *values;
//	char	   *ptr;
//	bits8	   *bitmap;
//	int			bitmask;
//	int			i;
//
//	Assert(ARR_ELEMTYPE(array) == TEXTOID);
//	if (ndim != 2)
//		ereport(ERROR,
//				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
//				 errmsg("A text array of two dimensions is expected.")));
//
//	nitems = ArrayGetNItems(ndim, dims);
//
//	get_typlenbyvalalign(ARR_ELEMTYPE(array),
//						 &typlen, &typbyval, &typalign);
//
//
//	values = NIL;
//
//	ptr = ARR_DATA_PTR(array);
//	bitmap = ARR_NULLBITMAP(array);
//	bitmask = 1;
//
//	for (i = 0; i < nitems; i++)
//	{
//		char * val;
//
//		if ((i % ndim) == 0)		// Add new pair element
//		{
//			pair = (SOL_ParamValue_Pair *)palloc(sizeof(SOL_ParamValue_Pair));
//			values = lappend(values, pair);
//		}
//
//		if (bitmap && (*bitmap & bitmask) == 0)
//		{
//			val = NULL;
//		}
//		else
//		{
//			val = (char *) TextDatumGetCString(PointerGetDatum(ptr));
//			ptr = att_addlength_pointer(ptr, typlen, ptr);
//			ptr = (char *) att_align_nominal(ptr, typalign);
//		}
//
//		/* advance bitmap pointer if any */
//		if (bitmap)
//		{
//			bitmask <<= 1;
//			if (bitmask == 0x100)
//			{
//				bitmap++;
//				bitmask = 1;
//			}
//		}
//
//		// Put the value to a pair
//		if ((i % ndim) == 0)
//			pair->val1 = val;
//		else
//			pair->val2 = val;
//	}
//
//	return values;
//}
