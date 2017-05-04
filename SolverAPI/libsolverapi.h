/*
 * libsolverapi.h
 *
 *  Created on: Nov 14, 2012
 *      Author: laurynas
 */

#ifndef _PG_LIB_SOLVER_API_H_
#define _PG_LIB_SOLVER_API_H_

#include "postgres.h"
#include "nodes/pg_list.h"
#include "catalog/pg_type.h"
#include "low_level_utils.h"
#include "utils/portal.h"
#include "executor/spi.h"
#include "funcapi.h"
/* ******************** SolverAPI main types ******************* */

#define SL_API_VERSION 110	/* The release 1.10 */
#define SL_VERSION_MAJOR(X) (X / 100)
#define SL_VERSION_MINOR(X) (X % 100)

/* A C correspondence of the "sl_attribute_kind" */
#define SL_PGNAME_Sl_Attribute_Kind "sl_attribute_kind"
typedef enum  { SL_AttKind_Undefined = 0,  /* An attribute kind is not yet specified */
			    SL_AttKind_Id,			/* An attribute is for unique ID */
			    SL_AttKind_Unknown, 	/* An attribute is for unknown variables */
			    SL_AttKind_Known, 		/* An attribute is for known variables */
			  } SL_Attribute_Kind;

#define SL_ATTKIND_TO_PG_ENUMVALUE(K)  	  	  	(K == SL_AttKind_Id        ? "id" : \
		                          	  	  	     K == SL_AttKind_Unknown   ? "unknown" : \
		                          	  	  	     K == SL_AttKind_Known     ? "known" : \
		  										  		     	 	 	 	  "undefined")
#define SL_ATTKIND_FROM_PG_ENUMVALUE(V)		    ((strcmp(V, "id")==0)	    ? SL_AttKind_Id : \
											     (strcmp(V, "unknown")==0)  ? SL_AttKind_Unknown : \
											     (strcmp(V, "known")==0)    ? SL_AttKind_Known : \
			  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  SL_AttKind_Undefined)
#define DatumGetSLAttributeKind(D)				(SL_ATTKIND_FROM_PG_ENUMVALUE(sl_get_enumLabelFromOid(DatumGetObjectId(D))))
#define SLAttributeKindGetDatum(A)				(ObjectIdGetDatum(sl_get_enumOidFromLabel(SL_PGNAME_Sl_Attribute_Kind, \
			  	  	  	  	  	  	  	  	  	  	  	  	  	  SL_ATTKIND_TO_PG_ENUMVALUE(A))))


/* A C correspondence of the "sl_attribute_desc" */
#define SL_PGNAME_Sl_Attribute_Desc "sl_attribute_desc"
typedef struct SL_Attribute_Desc
{
	char				*att_name;		/* A name of an attribute */
	char				*att_type;		/* A name of an attribute type */
	SL_Attribute_Kind 	 att_kind;
} SL_Attribute_Desc;

/* A C correspondence of the "sl_obj_dir" */
#define SL_PGNAME_Sl_Obj_Dir "sl_obj_dir"
typedef enum {
	SOL_ObjDir_Undefined = 0,
	SOL_ObjDir_Maximize,
	SOL_ObjDir_Minimize
} SL_Obj_Dir;
#define SL_OBJDIR_TO_PG_ENUMVALUE(K)  	  	  	(K == SOL_ObjDir_Maximize   ? "maximize" : \
		                          	  	  	     K == SOL_ObjDir_Minimize   ? "minimize" : \
		  										  		     	 	 	 	  "undefined")

#define SL_OBJDIR_FROM_PG_ENUMVALUE(V)		    ((strcmp(V, "maximize")==0) ? SOL_ObjDir_Maximize : \
											     (strcmp(V, "minimize")==0) ? SOL_ObjDir_Minimize : \
																			  SOL_ObjDir_Undefined)

#define DatumGetSLObjDir(D)						(SL_OBJDIR_FROM_PG_ENUMVALUE(sl_get_enumLabelFromOid(DatumGetObjectId(D))))
#define SLObjDirGetDatum(O)						(ObjectIdGetDatum(sl_get_enumOidFromLabel(SL_PGNAME_Sl_Obj_Dir, \
																  SL_OBJDIR_TO_PG_ENUMVALUE(O))))


/* A C correspondence of the "sl_problem" */
#define SL_PGNAME_Sl_Problem "sl_problem"
typedef struct SL_Problem
{
	char		 *input_sql;		/* An SQL query defining a relation with unknown variables (input) */
	char		 *input_alias;		/* An alias for SQL query to be used in objective and constraints SQLs */
	List		 *cols_unknown;		/* Columns defining unknowns in the table, a list of "char *" */
	SL_Obj_Dir 	  obj_dir;			/* The direction of objective function */
	char 		 *obj_sql;			/* An SQL defining objective */
	List 		 *ctr_sql;			/* A list of SQL statements defining inequalities, a list of "char *" */
} SL_Problem;

/* A C correspondence of the "sl_parameter_value"  */
#define SL_PGNAME_Sl_Parameter_Value "sl_parameter_value"
typedef struct SL_Parameter_Value
{
	char 	*param;
	int	   	 value_i;
	double	 value_f;
	char	*value_t;
} SL_Parameter_Value;

/* A C correspondence of the "sl_solver_arg" */
#define SL_PGNAME_Sl_Solver_Arg "sl_solver_arg"
typedef struct SL_Solver_Arg
{
	int						api_version;			/* A version number of API that calls a solver */
	char					*solver_name;			/* A name of a solver */
	char					*method_name;			/* An (auto detected) name of solver method */
	List					*params;				/* A list of "SL_Parameter_Value". A postprocessed array of solver and method parameter-value pairs */
	SL_Problem				*problem; 				/* An initial query */
	int						prb_colcount;			/* A number of columns with unknown variables */
	long					prb_rowcount;			/* A number of rows in an input relation */
	long					prb_varcount;			/* A number of unknown variables count */
	char					*tmp_name;				/* A name of a temporal table storing an input */
	char					*tmp_id;				/* A name of an primary column of a temporal table */
	List					*tmp_attrs;				/* A list of "SL_Attribute_Desc". An array of all attributes in temporal table. */
} SL_Solver_Arg;

extern SL_Attribute_Desc * DatumGetSLAttributeDesc(Datum);
extern SL_Parameter_Value * DatumGetSLParameterValue(Datum);
extern SL_Problem * DatumGetSLProblem(Datum);
extern SL_Solver_Arg * DatumGetSLSolverArg(Datum);
#define PG_GETARG_SLSOLVERARGDATUM(x)	((Datum) PG_GETARG_HEAPTUPLEHEADER(x))
#define PG_GETARG_SLSOLVERARG(x)		DatumGetSLSolverArg(PG_GETARG_SLSOLVERARGDATUM(x))

/* Methods to retrieve solver/method parameter values */
extern bool 				sl_param_isset(SL_Solver_Arg *arg, const char *parname);
extern SL_Parameter_Value * sl_param_get(SL_Solver_Arg *arg, const char *parname);
#define sl_param_get_as_int(ARG, PARNAME) 	(sl_param_get(ARG, PARNAME)->value_i)
#define sl_param_get_as_float(ARG, PARNAME) (sl_param_get(ARG, PARNAME)->value_f)
#define sl_param_get_as_text(ARG, PARNAME) 	(sl_param_get(ARG, PARNAME)->value_t)

/* Types and methods for a 2 level view system on top of the input relation */

/* A C correspondence of the "sl_viewsql_out" */
#define SL_PGNAME_Sl_Viewsql_Out "sl_viewsql_out"
typedef char * Sl_Viewsql_Out;
extern Sl_Viewsql_Out DatumGetSLViewSQLOut(Datum);
extern Datum SLViewSQLOutGetDatum(Sl_Viewsql_Out);

/* Information about the datatype used as primary key in source views */
#define SL_OUTTMPID				int64
#define SL_OUTTMPID_OID			INT8OID
#define SL_OUTTMPID_GetDatum(x)	Int64GetDatum(x)
#define DatumGetSLOUTTMPID(x)	DatumGetInt64(x)

/* Source level view SQL generators */
Sl_Viewsql_Out sl_build_out(Datum sa_datum);
Sl_Viewsql_Out sl_build_out_userdefined(Datum sa_datum, const char * user_sql);
Sl_Viewsql_Out sl_build_out_vars(Datum sa_datum);
Sl_Viewsql_Out sl_build_out_funcNmap(Datum sa_datum, Sl_Viewsql_Out base, const char ** funcs, const int numFuncs);
Sl_Viewsql_Out sl_build_out_funcNsubst(Datum sa_datum, const char ** funcs, const int numFuncs);
Sl_Viewsql_Out sl_build_out_func1subst(Datum sa_datum, const char * func);
Sl_Viewsql_Out sl_build_out_arrayNsubst(Datum sa_datum, const int * par_pos, const int numPars);
Sl_Viewsql_Out sl_build_out_array1subst(Datum sa_datum, const int  par_nr);

/* A C correspondence of the "sl_viewsql_dst" */
#define SL_PGNAME_Sl_Viewsql_Dst "sl_viewsql_dst"
typedef char * Sl_Viewsql_Dst;
extern Sl_Viewsql_Dst DatumGetSLViewSQLDst(Datum);
extern Datum SLViewSQLDstGetDatum(Sl_Viewsql_Dst);

/* Destination level view SQL generators */
Sl_Viewsql_Dst sl_build_dst_values(Datum sa_datum, Sl_Viewsql_Out vsout, char * cast_to);
Sl_Viewsql_Dst sl_build_dst_obj(Datum sa_datum, Sl_Viewsql_Out vsout);
Sl_Viewsql_Dst sl_build_dst_ctr(Datum sa_datum, Sl_Viewsql_Out vsout, int ctr_nr);

/* The main solver output routine */
char * sl_return(Datum sa_datum, Sl_Viewsql_Out vsout);

/* Types and macros used when building customs solvers in C. It's recommended to use them when returning tuples from a solver.
 * A solver implementaion must follow the following template:
 *
 * PG_FUNCTION_INFO_V1(<SOLVER_NAME>);
 * Datum <SOLVER_NAME>(PG_FUNCTION_ARGS) {
 *	SL_SOLVER_BEGIN
 *
 *  < SOLVER DEFINITIONS AND ROUTINES >
 *
 *	SL_SOLVER_RETURN(<Sl_Viewsql_Out>, <number of parameters>, <parameter types>, <parameter values>)
 *	SL_SOLVER_END
 * }
 *
 * */
typedef struct SL_SolverCallContext
{
   Portal          portal;	  /* Used as cursor when iterating result sets */
   SPIPlanPtr      plan;      /* A prepared plan*/
   SPITupleTable   *tupletable;/* A tuple table to read a result from*/
   uint32		   tuplecount;/* Tuple count in a tuple table */
   uint32		   tuplenr;	  /* A number of a tuple to be read next */
} SL_SolverCallContext;

#define SL_SOLVER_BEGIN \
		FuncCallContext *funcctx; \
		if (SRF_IS_FIRSTCALL()) { \
			MemoryContext oldcontext; \
			funcctx = SRF_FIRSTCALL_INIT(); \
			oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);\
			funcctx->user_fctx = NULL; \
			do { // this prevents subsequent commands

#define SL_SOLVER_RETURN(OUT, NUMPARAMS, PARAMTYPES, PARAMVALUES) \
				do { \
					char *					outsql = sl_return(PG_GETARG_SLSOLVERARGDATUM(0), (Sl_Viewsql_Out)OUT);\
					SL_SolverCallContext 	*sctx  = palloc(sizeof(SL_SolverCallContext)); \
			        if (SPI_connect() < 0)\
				         elog(ERROR, "SolverAPI: SPI_connect failed"); \
					if ((sctx->plan = SPI_prepare(outsql, (int)NUMPARAMS, (Oid *)PARAMTYPES)) == NULL) \
						elog(ERROR, "SolverAPI: SPI_prepare(\"%s\") failed. Returned %d", outsql, SPI_result); \
					if ((sctx->portal = SPI_cursor_open(NULL, sctx->plan, (Datum*)PARAMVALUES, NULL, true)) == NULL) \
						elog(ERROR, "SolverAPI: SPI_cursor_open(\"%s\") failed. Returned %d", outsql, SPI_result); \
					SPI_cursor_fetch(sctx->portal, true, 50);\
					if (SPI_tuptable == NULL)\
						elog(ERROR, "SolverAPI: SPI_cursor_fetch(\"%s\") failed. Returned %d", outsql, SPI_result);\
					sctx->tupletable = SPI_tuptable;\
					sctx->tuplecount = SPI_processed;\
					sctx->tuplenr = 0;\
					funcctx->user_fctx = sctx;\
					funcctx->tuple_desc = BlessTupleDesc(CreateTupleDescCopy(sctx->tupletable->tupdesc));\
					pfree(outsql);\
				} while (0)

#define SL_SOLVER_END \
			} while (0);\
			MemoryContextSwitchTo(oldcontext);\
		}\
		funcctx = SRF_PERCALL_SETUP();\
		do {\
			SL_SolverCallContext * sctx = (SL_SolverCallContext *) funcctx->user_fctx;\
			if (sctx == NULL)\
				SRF_RETURN_DONE(funcctx);\
			if (sctx->tuplenr >= sctx->tuplecount) {\
				MemoryContext oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);\
				SPI_freetuptable(sctx->tupletable);\
				SPI_cursor_fetch(sctx->portal, true, 50);\
				if (SPI_processed <= 0) {\
					SPI_cursor_close(sctx->portal);\
					SPI_finish();\
					MemoryContextSwitchTo(oldcontext);\
					SRF_RETURN_DONE(funcctx);\
				}\
				sctx->tupletable = SPI_tuptable;\
				sctx->tuplecount = SPI_processed;\
				sctx->tuplenr = 0;\
				MemoryContextSwitchTo(oldcontext);\
			}\
			do { /* Build a copy of a heap tuple */\
				Datum      *values = (Datum *) palloc(funcctx->tuple_desc->natts * sizeof(Datum));\
				bool       *nulls = (bool *) palloc(funcctx->tuple_desc->natts * sizeof(bool));\
				HeapTuple	tuple;\
				heap_deform_tuple(sctx->tupletable->vals[sctx->tuplenr++], funcctx->tuple_desc, values, nulls);\
				tuple = heap_form_tuple(funcctx->tuple_desc, values, nulls);\
				pfree(values); pfree(nulls);\
				SRF_RETURN_NEXT(funcctx, HeapTupleGetDatum(tuple));\
			} while (0);\
		} while (0);\
		PG_RETURN_NULL();  /* To make a compiler quiet*/ // this prevents subsequent commands

/* Types and functions for constraint handling */

/* A C correspondence of the "sl_unkvar" */
#define SL_PGNAME_Sl_Unkvar "sl_unkvar"
/* A PG name of the "sl_unkvar_make" function */
#define SL_PGNAME_Sl_Unkvar_Make "sl_unkvar_make"
typedef int64 Sl_Unkvar;
extern Sl_Unkvar DatumGetSLUnkvar(Datum);
extern Datum SLUnkvarGetDatum(Sl_Unkvar);


/* A C correspondence of the "sl_ctr_type" */
#define SL_PGNAME_Sl_Ctr_Type "sl_ctr_type"
typedef enum  { SL_CtrType_EQ = 0,
				SL_CtrType_NE,
				SL_CtrType_LT,
				SL_CtrType_LE,
				SL_CtrType_GE,
				SL_CtrType_GT,
			  } SL_Ctr_Type;

#define SL_CTRTYPE_TO_PG_ENUMVALUE(K)  	  	  	(K == SL_CtrType_EQ        ? "eq" : \
												 K == SL_CtrType_NE   	   ? "ne" : \
		                          	  	  	     K == SL_CtrType_LT   	   ? "lt" : \
		                          	  	  	     K == SL_CtrType_LE        ? "le" : \
		                          	  	  	     K == SL_CtrType_GE        ? "ge" : \
		                          	  	  	     K == SL_CtrType_GT        ? "gt" : "")
#define SL_CTRTYPE_FROM_PG_ENUMVALUE(V)		    ((strcmp(V, "eq")==0)	    ? SL_CtrType_EQ : \
	     	 	 	 	 	 	 	 	 	     (strcmp(V, "ne")==0)       ? SL_CtrType_NE : \
											     (strcmp(V, "lt")==0)       ? SL_CtrType_LT : \
											     (strcmp(V, "le")==0)       ? SL_CtrType_LE : \
			  	  	  	  	  	  	  	  	     (strcmp(V, "ge")==0)       ? SL_CtrType_GE : \
			  	  	  	  	  	  	  	  	     (strcmp(V, "gt")==0)       ? SL_CtrType_GT : SL_CtrType_EQ)
#define DatumGetSLCtrType(D)				    (SL_CTRTYPE_FROM_PG_ENUMVALUE(sl_get_enumLabelFromOid(DatumGetObjectId(D))))
#define Sl_CtrTypeGetDatum(A)					(ObjectIdGetDatum(sl_get_enumOidFromLabel(SL_PGNAME_Sl_Ctr_Type, \
																  SL_CTRTYPE_TO_PG_ENUMVALUE(A))))
#define PG_GETARG_SLCtrType(x)					DatumGetSLCtrType(PG_GETARG_DATUM(x))

/* A C correspondence/implementation of the "sl_ctr" */
#define SL_PGNAME_Sl_Ctr "sl_ctr"
typedef struct Sl_Ctr {
	int32			vl_len_;       /* varlena header (do not touch directly!) */
	float8			c_val;		   /* A numerical constant */
	SL_Ctr_Type		op;		   	   /* Operator, aka., constraint type */
	Oid				x_type;		   /* A OID of the type of x_val */
	/* Datum x_val, the  serialized value of a polymorphic type, is over the SL_Ctr boundaries.
	 * It's not included in the structure as it is aligned using MAXALIGN. */
} Sl_Ctr;

#define SL_CTR_XVAL_DATA_OFFSET		 	MAXALIGN(sizeof(Sl_Ctr))
#define SL_CTR_XVAL_DATA_PTR(ctr) 		(((char *) ctr) + SL_CTR_XVAL_DATA_OFFSET)
#define SL_CTR_XVAL_DATA_SIZE(ctr) 		(VARSIZE(ctr) - SL_CTR_XVAL_DATA_OFFSET)

#define DatumGetSLCtr(x)				((Sl_Ctr*)DatumGetPointer(x))
#define DatumGetSLCtrCopy(x)			((Sl_Ctr*)PG_DETOAST_DATUM_COPY(x))
#define PG_GETARG_SLCtr(x)				DatumGetSLCtr(PG_DETOAST_DATUM(PG_GETARG_DATUM(x)))
#define PG_RETURN_SLCtr(x)				PG_RETURN_POINTER(x)

/* Extract x_val as datum from sl_ctr */
extern Datum	sl_ctr_get_x_val(Sl_Ctr*);
/* Represents SL_Ctr as C string */
extern char* 	sl_ctr_to_cstring(Sl_Ctr*);
extern Sl_Ctr* 	sl_ctr_from_datum(float8, SL_Ctr_Type, Oid, Datum);

#endif /* _PG_LIB_SOLVER_API_H_ */
