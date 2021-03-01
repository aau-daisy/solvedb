/*-------------------------------------------------------------------------
 *
 * solverlp.c
 *	  Integration of the linear programmer solver to PostreSQL 9.2 (by Laurynas Siksnys)
 *
 *
 * Copyright (c) 2012, Aalborg University
 *
 * IDENTIFICATION
 *	  solverLP.c
 *
 *-------------------------------------------------------------------------
 */

#include "solverlp.h"
#include <assert.h>
#include "executor/spi.h"
#include "catalog/namespace.h"
#include "miscadmin.h"
#include "utils/memutils.h"
#include "utils/lsyscache.h"
#include "parser/parse_type.h"
#include "access/htup_details.h"

/* For GLPK solving*/
#include "glpk.h"
#include "glpk/glpk_log.h"

/* FOR CBC solving */
#include "libPgCbc.h"

#include "prb_partition.h" /* For problem partitioning */
#include <sys/time.h> /* For performance benchmarking */


/* All settings for the LP view solver */
typedef struct {
	/* Solving mode */
	LPsolvingMode		solvingMode;

	/* log_level:
	 *    Indicates the log-level of the solver. Use PostgreSQL values */
	int					log_level;
	/* use_nulls:
	 *    When "true", values of non-referenced variables will be set to NULL in the output relation */
	bool				use_nulls;
	/* partition_size:
	 *    The solver supports partitioning. This indicates a number of problems to be solved in
	 *    a single physical solver call */
	int					partition_size;

	/* Arguments to be passed to CBC solver */
	char				* cbcArguments;
} LPsolverSettings;

/* All parameters for building view-based solution */
typedef struct {
	/* General data */
	SL_Solver_Arg 			* arg;				// The solver argument
	LPvariableType			* colTypes;			// Unknown variable column types
	bool					use_nulls;	// When "true", values of non-referenced variables will be set to NULL

	/* Physical problem solution and meta data */
	LPvariableType		  	* varTypes;			/* Variable types */
	LPsolverResult 			* prob_sol;
} LPviewSolution;

/* Macros to check if a datatype is supported by the LP view solver */
#define TYPEISBOOL(oid)	   (oid == BOOLOID)
#define TYPEISINTEGER(oid) ((oid == INT2OID) || (oid == INT4OID) || (oid == INT8OID))
#define TYPEISFLOAT(oid)   ((oid == FLOAT4OID) || (oid == FLOAT8OID) || (oid == NUMERICOID))
#define TYPEISNUMERIC(oid) (TYPEISBOOL(oid) || TYPEISINTEGER(oid) || TYPEISFLOAT(oid))

#define FLOAT8ARRAYOID (TypenameGetTypid("_float8"))
#define BOOLARRAYOID   (TypenameGetTypid("_bool"))

#define SOLVE_PARTITION(prob, settings) settings->solvingMode == LPsolvingCBC ?\
									    solve_partition_cbc(prob, settings)   :\
									    solve_partition_glpk(prob, settings)


/* A type of function */
typedef enum {
	LPfunctionEmpty,			/* Function does not containt variables */
	LPfunctionFloat,			/* Function contains only float variables */
	LPfunctionInteger,		/* Function contains only integer variables */
	LPfunctionBool,			/* Function contains only boolean variables */
	LPfunctionMixed			/* Function contains variables of mixed types */
} LPfunctionType;

/* Forward declarations */
extern Datum lp_problem_solve_basic(PG_FUNCTION_ARGS);
extern Datum lp_problem_solve_mip(PG_FUNCTION_ARGS);
extern Datum lp_problem_solve_auto(PG_FUNCTION_ARGS);
extern Datum lp_problem_solve_cbc(PG_FUNCTION_ARGS);
// Static function list
static void lp_problem_solve(LPsolvingMode, Datum, int *, int **, Oid **, Datum **);
static LPvariableType * build_col_types(SL_Solver_Arg *);
static pg_LPfunction * build_obj_function(Datum, SL_Solver_Arg *);
static List * build_ctr_ineq(Datum, SL_Solver_Arg *);
static Oid get_lp_function_oid();
static Oid get_sl_ctr_oid();
static LPsolverResult * solve_main_lp_problem(LPproblem *, LPsolverSettings *);
static LPsolverResult * solve_partition_glpk(LPproblem * prob, LPsolverSettings * settings);
static LPsolverResult * solve_partition_cbc(LPproblem * prob, LPsolverSettings * settings);
static LPfunctionType get_function_type(LPproblem *, int *, pg_LPfunction *);
static void remap_LP_variables(LPproblem *, LPsolverResult *);
static void compactLPproblem(LPproblem * prob, int ** varIndices);

static void build_result(LPviewSolution * sol, int * ra_count, int ** ra_parids, Oid ** ra_types, Datum ** ra_values);
static double time_diff(struct timeval *tod1, struct timeval *tod2);

PG_MODULE_MAGIC;



/* Solves the basic LP problem */
PG_FUNCTION_INFO_V1(lp_problem_solve_basic);
Datum lp_problem_solve_basic(PG_FUNCTION_ARGS) {
	SL_SOLVER_BEGIN
	Datum 				arg_d = PG_GETARG_SLSOLVERARGDATUM(0);  /* Get solver argument as DATUM */
	int 				ra_count;
	int 				*ra_parids;
	Oid 				*ra_types;
	Datum				*ra_values;

	/* Solves the problem basic LP problem*/
	lp_problem_solve(LPsolvingBasic, arg_d, &ra_count, &ra_parids, &ra_types, &ra_values);
	/* Produce the output */
	SL_SOLVER_RETURN(sl_build_out_arrayNsubst(arg_d,
			                            	  ra_parids,
			                            	  ra_count),
				     ra_count,
				     ra_types,
				     ra_values);

	SL_SOLVER_END
}

/* Solves the MIP problem */
PG_FUNCTION_INFO_V1(lp_problem_solve_mip);
Datum lp_problem_solve_mip(PG_FUNCTION_ARGS) {
	SL_SOLVER_BEGIN
	Datum 				arg_d = PG_GETARG_SLSOLVERARGDATUM(0);  /* Get solver argument as DATUM */
	int 				ra_count;
	int 				*ra_parids;
	Oid 				*ra_types;
	Datum				*ra_values;

	/* Solves the problem MIP LP problem*/
	lp_problem_solve(LPsolvingMIP, arg_d, &ra_count, &ra_parids, &ra_types, &ra_values);
	/* Produce the output */
	SL_SOLVER_RETURN(sl_build_out_arrayNsubst(arg_d,
			          		  	  	  	      ra_parids,
			           		  	  	  	      ra_count),
				     ra_count,
				     ra_types,
				     ra_values);

	SL_SOLVER_END
}

/* Automatically detect the problem to solve by analyzing the types of unknown variable columns */
PG_FUNCTION_INFO_V1(lp_problem_solve_auto);
Datum lp_problem_solve_auto(PG_FUNCTION_ARGS) {
	SL_SOLVER_BEGIN
	Datum 				arg_d = PG_GETARG_SLSOLVERARGDATUM(0);  /* Get solver argument as DATUM */
	int 				ra_count;
	int 				*ra_parids;
	Oid 				*ra_types;
	Datum				*ra_values;

	/* Solves the problem in AUTO mode */
	lp_problem_solve(LPsolvingAuto, arg_d, &ra_count, &ra_parids, &ra_types, &ra_values);
	/* Produce the output */
	SL_SOLVER_RETURN(sl_build_out_arrayNsubst(arg_d,
			          		  	  	  	      ra_parids,
			           		  	  	  	      ra_count),
				     ra_count,
				     ra_types,
				     ra_values);

	SL_SOLVER_END
}

/* An entry point for Coins CBC solving */
PG_FUNCTION_INFO_V1(lp_problem_solve_cbc);
Datum lp_problem_solve_cbc(PG_FUNCTION_ARGS) {
	SL_SOLVER_BEGIN
	Datum 				arg_d = PG_GETARG_SLSOLVERARGDATUM(0);  /* Get solver argument as DATUM */
	int 				ra_count;
	int 				*ra_parids;
	Oid 				*ra_types;
	Datum				*ra_values;

	/* Solves the problem in AUTO mode */
	lp_problem_solve(LPsolvingCBC, arg_d, &ra_count, &ra_parids, &ra_types, &ra_values);
	/* Produce the output */
	SL_SOLVER_RETURN(sl_build_out_arrayNsubst(arg_d,
			          		  	  	  	      ra_parids,
			           		  	  	  	      ra_count),
				     ra_count,
				     ra_types,
				     ra_values);

	SL_SOLVER_END
}



/* Builds a LP problem definition, executes the solver, and provides result, required by the SolverAPI */
static void lp_problem_solve(LPsolvingMode solvingMode, Datum slarg, int * ra_count, int ** ra_parids, Oid ** ra_types, Datum ** ra_values)
{
    /* SolverAPI arguments */
	Datum					arg_d;				// The solver argument datum
	SL_Solver_Arg 			*arg;				// The solver argument
	/* Objects of an analyzed LP view problem */
	LPvariableType			* colTypes;			// Unknown variable column types
	LPvariableType		  	* varTypes;			/* Re-mapped variable types */
	/* Various settings */
	LPsolverSettings		settings;			// All settings of the solver
	/* Main problem and solution */
	LPproblem				* prob;				/* LP problem in the physical format */
	LPsolverResult  		* prob_sol;			/* A solution in the physical format */
	/* Transient variables */
	MemoryContext			solverctx, oldcontext;
	int						i;

	solverctx =  AllocSetContextCreate(CurrentMemoryContext,
			   "SolverLP memory context",
			   ALLOCSET_DEFAULT_MINSIZE,
			   ALLOCSET_DEFAULT_INITSIZE,
			   ALLOCSET_DEFAULT_MAXSIZE);

	oldcontext = MemoryContextSwitchTo(solverctx);

	PG_TRY();

	/* Analyze the problem and build a LP problem definition */
	arg_d = slarg;
	arg = DatumGetSLSolverArg(slarg);

	/* Set the parameters */
	settings.log_level        = sl_param_isset(arg, "log_level")      ? (int)  sl_param_get_as_int(arg, "log_level")      : WARNING;
	settings.use_nulls		  = sl_param_isset(arg, "use_nulls")      ? (bool) sl_param_get_as_int(arg, "use_nulls")      : true;
	settings.partition_size   = sl_param_isset(arg, "partition_size") ? (int)  sl_param_get_as_int(arg, "partition_size") : 1;
	settings.cbcArguments     = sl_param_isset(arg, "args")	&& solvingMode == LPsolvingCBC
																      ? (char*)sl_param_get_as_text(arg, "args")		  : NULL;

	if (settings.log_level < 0 || settings.log_level > ERROR)
		ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						        errmsg("SolverLP: Invalid logging level specified"),
						        errdetail("SolverLP: Invalid logging level specified. Allowed range is 0 to 20.")));

	if (settings.partition_size < 0)
		ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				        errmsg("SolverLP: Invalid partition size specified"),
				        errdetail("SolverLP: Invalid partition size specified. ")));

	/* Check if we can actually solve the problem and
	 * build the unknown-variable column types */
	colTypes = build_col_types(arg);

	/* Build the main LP problem  */
	prob = palloc(sizeof(LPproblem));

	/* Automatically detect the problem type by analyzing unknown columns */
	if (solvingMode == LPsolvingAuto) {
		/* Checks if there are integer/boolean unknown-variable columns */
		settings.solvingMode = LPsolvingBasic;
		for (i = 0; i < arg->prb_colcount; i++)
			if (colTypes[i] == LPtypeInteger || colTypes[i] == LPtypeBool) {
				settings.solvingMode = LPsolvingMIP;
				break;
			}
	} else
		settings.solvingMode = solvingMode;
	/* Setup variables */
	prob->numVariables = arg->prb_varcount + 1; 	 /* SolverAPI variables start at 1*/
	varTypes 	 	   = palloc(prob->numVariables * sizeof(LPvariableType));
	varTypes[0]  	   = LPtypeUndefined; 			 /* As variables start from 1, variable 0 is undefined */
	for (i=1; i<prob->numVariables; i++)
		varTypes[i] = colTypes[(i-1) / arg->prb_rowcount];
	prob->varTypes = varTypes;						 /* Assign to the problem */

	CHECK_FOR_INTERRUPTS();	// Check if someone has interrupted the operation

	/* Setup objective function */
	prob->objDirection = arg->problem->obj_dir == SOL_ObjDir_Maximize ?
												  LPobjMaximize : LPobjMinimize;
	prob->obj = build_obj_function(arg_d, arg);

	CHECK_FOR_INTERRUPTS();	// Check if someone has interrupted the operation

	/* Setup constraints */
	prob->ctrs = build_ctr_ineq(arg_d, arg);

	CHECK_FOR_INTERRUPTS();	// Check if someone has interrupted the operation

	/* The problem definition is built. Let's solve the problem */
	prob_sol = solve_main_lp_problem(prob, &settings);
	CHECK_FOR_INTERRUPTS();	// Check if someone has interrupted the operation

	MemoryContextSwitchTo(oldcontext);

	/* Build the arrays, required by SolverAPI */
	if (prob_sol != NULL)
	{
		LPviewSolution sol_data;
		sol_data.arg 	   			= arg;
		sol_data.colTypes  			= colTypes;
		sol_data.use_nulls 			= settings.use_nulls;
		sol_data.varTypes		 	= varTypes;
		sol_data.prob_sol		 	= prob_sol;

		build_result(&sol_data, ra_count, ra_parids, ra_types, ra_values);
	} else
		ereport(ERROR,
				 (errcode(ERRCODE_NO_DATA_FOUND),
				  errmsg("SolverLP: Solution not found."),
				  errdetail("SolverLP: Solution not found. Try a different solver or changing constraints.")));
	PG_CATCH();
	{
		MemoryContextSwitchTo(oldcontext);
		MemoryContextDelete(solverctx);
		PG_RE_THROW();
	}
	PG_END_TRY();

	MemoryContextDelete(solverctx);
}

/* Build unknown variable types from the column types */
static LPvariableType * build_col_types(SL_Solver_Arg * arg)
{
	LPvariableType	*coltypes;
	ListCell	*c;
	int			i;

	coltypes = palloc(sizeof(LPvariableType) * arg->prb_colcount);

	/* Build column types */
	i = 0;
	foreach(c, arg->tmp_attrs)
	{
		SL_Attribute_Desc	*cdes = (SL_Attribute_Desc *) lfirst(c);
		Oid					typeid;
		int32				typemod;

		if (cdes->att_kind != SL_AttKind_Unknown)
			continue;
		Assert(i < arg->prb_colcount);

		parseTypeString(cdes->att_type, &typeid, &typemod, true);
		// TypenameGetTypid - does not work for int4, float4, etc.
		// typeid = TypenameGetTypid(cdes->att_type);

		if (!OidIsValid(typeid) || !TYPEISNUMERIC(typeid))
			ereport(ERROR,
				   (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					errmsg("SolverLP: Unknown-variable column type (%s) is not supported.", cdes->att_type),
					errdetail("The solver supports only numerical (integer, float, boolean) column types")));

		/* Determines the types of columns */
		coltypes[i] = TYPEISINTEGER(typeid) ? LPtypeInteger :
			          TYPEISBOOL(typeid)    ? LPtypeBool	:
					      	 	  	   	   	  LPtypeFloat;
		i++;
	}

	return coltypes;
}


/*
 * Get OID of the "lp_function" type
 */
static Oid get_lp_function_oid()
{
	Oid oid;
	oid = TypenameGetTypid("lp_function");
	if (!OidIsValid(oid))
		elog(ERROR, "SolverLP: \"lp_function\" type cannot be found. Please check if SolverLP is properly installed.");
	return oid;
}

/*
 * Get OID of the "sl_ctr" type
 */
static Oid get_sl_ctr_oid()
{
	Oid oid;
	oid = TypenameGetTypid("sl_ctr");
	if (!OidIsValid(oid))
		elog(ERROR, "SolverLP: \"sl_ctr\" type cannot be found. Please check if SolverAPI is properly installed.");
	return oid;
}

/*
 * Build a function of the objective function
 */
static pg_LPfunction * build_obj_function(Datum arg_d, SL_Solver_Arg * arg)
{
	Sl_Viewsql_Out out;
	Sl_Viewsql_Dst dst;
	Oid	lppol_oid;
	int ret;
	uint32 proc;
	pg_LPfunction * result = NULL;
	MemoryContext solver_context;

	if (arg->problem->obj_dir != SOL_ObjDir_Maximize &&
		arg->problem->obj_dir != SOL_ObjDir_Minimize)
		return NULL;

	/* Build a source view to cast all unknown variables to "lp_function" type.
	 * It uses the "lp_function_make" constructor. */
	out = sl_build_out_func1subst(arg_d, "lp_function_make");
	/* Build a destination view SQL for objective function */
	dst = sl_build_dst_obj(arg_d, out);
	/* Get OID of the lp_function type */
	lppol_oid = get_lp_function_oid();
	/* Remember the current memory context */
	solver_context = CurrentMemoryContext;

	/* Initialize the SPI*/
	if ((ret = SPI_connect()) < 0)
		elog(ERROR, "SolverLP: SPI_connect returned %d", ret);

	/* Execute the query */
	ret = SPI_execute(dst, true, 0);
	if (ret < 0)
		elog(ERROR, "SolverLP: SPI_exec returned %d", ret);

	proc = SPI_processed;

	if (proc < 1)
		ereport(ERROR,
			   (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
			    errmsg("SolverLP: The objective query has returned no functionial to maximize or minimize."),
				errdetail("The objective query is expected to return exactly 1 row. Please check your query.")));
	else if (proc > 1)
		ereport(ERROR,
			   (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				errmsg("SolverLP: The objective query has returned more than one functionial to maximize or minimize."),
				errdetail("The objective query is expected to return single row with single column. Please check your query.")));
	else
	{
		SPITupleTable *tuptable = SPI_tuptable;
		TupleDesc     tupdesc = tuptable->tupdesc;
		Oid type_oid;
		Datum value;
		bool isnull;
		int	 i;

		if (tupdesc->natts != 1)
			ereport(ERROR,
				   (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				    errmsg("SolverLP: The objective query has returned a tuple with different than one attribute."),
					errdetail("The objective query is expected to return single row with single column. Please check your query.")));
		/* Check if type of the returned value is valid */
		type_oid = SPI_gettypeid(tupdesc, 1);
		if (!OidIsValid(type_oid) || (type_oid != lppol_oid))
			ereport(ERROR,
				   (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					errmsg("SolverLP: The objective query has returned values of unexpected type."),
					errdetail("The objective query must return a value of \"lp_function\" type. Please check your query.")));

		value = SPI_getbinval(tuptable->vals[0], tupdesc, 1, &isnull);

		if (isnull)
			ereport(ERROR,
							   (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
								errmsg("SolverLP: The objective query has returned the NULL value. "),
								errdetail("Please check your query.")));

		/* As SPI_free releases all allocations, we create the copy
		  of the function in the previous memory context */
		MemoryContextSwitchTo(solver_context);
		result = DatumGetLPfunctionCopy(value);
		/* Check the correctes of the lp_function */
		for (i = 0; i < result->numTerms; i++)
			if ((result->term[i].varNr < 1) || (result->term[i].varNr > arg->prb_varcount))
				elog(ERROR,	"SolverLP: Variable number in \"lp_function\" is out of the range.");
	}

	/* Finalize the SPI */
	if ((ret = SPI_finish()) < 0)
		elog(ERROR, "SolverLP: SPI_finish returned %d", ret);
	pfree(dst);
	pfree(out);

	return result;
}

static List * build_ctr_ineq(Datum arg_d, SL_Solver_Arg * arg)
{
	Sl_Viewsql_Out 	out;
	int 			c;
	Oid				lppol_oid;
	Oid				slctr_oid;
	MemoryContext 	solver_context;
	List			*result;

	/* Build a source view to cast all unknown variables to "lp_function" type.
	   It uses the "lp_function_make" constructor. */
	out = sl_build_out_func1subst(arg_d, "lp_function_make");
	/* Get the OID of "lp_function" type. This type is a part of SolverLP. */
	lppol_oid = get_lp_function_oid();
	/* Get the OID of "sl_ctr" type. This type is a part of SolverAPI. */
	slctr_oid = get_sl_ctr_oid();
	/* Remember the current memory context */
	solver_context = CurrentMemoryContext;
	/* Initially, there are no constraints */
	result = NIL;

	for(c=1; c <= list_length(arg->problem->ctr_sql); c++)
	{
		Sl_Viewsql_Dst 	dst;
		int 			ret;
		uint32			proc;
		int				i,j;

		/* Build a viewsql for [Constraint] destination view */
		dst = sl_build_dst_ctr(arg_d, out, c);

		/* Initialize the SPI*/
		if ((ret = SPI_connect()) < 0)
			elog(ERROR, "SolverLP: SPI_connect returned %d", ret);

		/* Execute the query */
		ret = SPI_execute(dst, true, 0);
		if (ret < 0)
			elog(ERROR, "SolverLP: SPI_exec returned %d", ret);

		proc = SPI_processed;

		/* Check the schema of the constraint relation */
		for(i=1; i <= SPI_tuptable->tupdesc->natts; i++)
			if (SPI_gettypeid(SPI_tuptable->tupdesc, i) != slctr_oid)
		        ereport(ERROR,
		            (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
		             errmsg   ("SolverLP: Constraint query %d is invalid", c),
		             errdetail("SolverLP: Constraint query must return values of type \"Sl_Ctr\"")));

		/* Process the constraints */
		for(i=0; i < proc; i++)
			for(j=1; j <= SPI_tuptable->tupdesc->natts; j++)
			{
				Sl_Ctr 			*ctr;
				bool 			is_null;
				pg_LPfunction 	*p;
				int				k;

				ctr = DatumGetSLCtr(SPI_getbinval(SPI_tuptable->vals[i], SPI_tuptable->tupdesc, j, &is_null));
				if (is_null)
			        ereport(ERROR,
			            (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
			             errmsg   ("SolverLP: Constraint query %d produced NULL values.", c),
			             errdetail("SolverLP: Constraint query must not produce NULL values. Please check your query.")));
				/* Check the polymorphic object inside the sl_ctr  */
				if (!OidIsValid(ctr->x_type) || (ctr->x_type != lppol_oid))
						 ereport(ERROR,
								(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
								 errmsg   ("SolverLP: Constraint query %d produced unexpected values.", c),
								 errdetail("SolverLP: Constraint query produce \"sl_ctr\" values containing \"lp_function\" as subelement. Please check your query.")));
				/* Check variable numbers in the lp_function*/
				p = DatumGetLPfunction(sl_ctr_get_x_val(ctr));
				for (k=0; k< p->numTerms; k++)
					if ((p->term[k].varNr < 1) || (p->term[k].varNr > arg->prb_varcount))
					   elog(ERROR, "SolverLP: Variable number in \"sl_ctr\" is out of the range.");

				/* As SPI_free releases all allocations, we create the copy of the
				 * constraint in the previous memory context */
				MemoryContextSwitchTo(solver_context);
				result = lappend(result, DatumGetSLCtrCopy(ctr));
			}
		/* Finalize the SPI */
		if ((ret = SPI_finish()) < 0)
			elog(ERROR, "SolverLP: SPI_finish returned %d", ret);
		pfree(dst);
	}
	pfree(out);

	return result;
}

/* Build index of relevant variables and remap variables in objective function and constraints */
static void remap_LP_variables(LPproblem * prob, LPsolverResult * r)
{
	typedef struct {
			int 		key;	   /* An original variable number from SolveAPI */
			int 		newVarNr;   /* A new variable number */
	} Hash_entry;

	Hash_entry 		* hash_entry;
	HASHCTL		    ctl;
	HTAB 		    * hash; /* A hash for variable ids */
	int			    i;
	ListCell	    * c;
	bool		    found;
	HASH_SEQ_STATUS seqstatus;

	// Initialize the variable indices
	r->numVariables = 0;
	r->varIndices = NULL;

	// Initialize the hash
	MemSet(&ctl, 0, sizeof(ctl));
	ctl.keysize = sizeof(int);
	ctl.entrysize = sizeof(Hash_entry);
	ctl.hash = tag_hash;
	ctl.hcxt = CurrentMemoryContext;
	hash = hash_create("LP variable lookup cache", 1024,  &ctl, HASH_ELEM | HASH_FUNCTION | HASH_CONTEXT);

	// Add all variables from the objective function into the hash
	if (prob->obj != NULL )
		for (i = 0; i < prob->obj->numTerms; i++) {
			hash_entry = hash_search(hash, &(prob->obj->term[i].varNr), HASH_ENTER, &found);
			if (!found)
				hash_entry->newVarNr = r->numVariables++;	/* Key is already inserted */

			/* Reindex the variable */
			prob->obj->term[i].varNr = hash_entry->newVarNr;
		}

    // Add all variables from the constraints into the hash
    foreach(c, prob->ctrs)
    {
    	Sl_Ctr * ne = lfirst(c);
    	pg_LPfunction * p = DatumGetLPfunction(sl_ctr_get_x_val(ne));	/* Extract the polymorphic element */

    	Assert(p != NULL);
    	for(i=0; i < p->numTerms; i++)
    	{
    		hash_entry = hash_search(hash, &(p->term[i].varNr), HASH_ENTER, &found);
    	    if (!found)
    			hash_entry->newVarNr = r->numVariables++; /* Key is already inserted */

    	    /* Reindex the variable */
    	    p->term[i].varNr = hash_entry->newVarNr;
    	}
    }

    // Convert hash entries into an array
    r->varIndices = (int *) palloc(sizeof(int) * r->numVariables);
    hash_seq_init(&seqstatus, hash);
    i=0;
	while ((hash_entry = hash_seq_search(&seqstatus)) != NULL)
		if (i++ < r->numVariables)
			r->varIndices[hash_entry->newVarNr] = hash_entry->key;

	Assert(i==r->numVariables);

	hash_destroy(hash);
}

/* Reduces the size of a problem by keeping just the relevant variables.
 * Returns the template for the result. */
static void compactLPproblem(LPproblem * prob, int ** varIndices)
{
	LPsolverResult 	res;
	int				i;
	LPvariableType	* nvt;

	if (prob == NULL || prob->numVariables <= 0 || varIndices == NULL) return;

	// Initialize the result in the caller's context
	res.numVariables = 0;
	res.varIndices = NULL;
	res.varValues = NULL;
	res.solvingTime =  0;

	// Build unknown indices and re-map variable numbers
	remap_LP_variables(prob, &res);

	/* Update the base problem */
	prob->numVariables = res.numVariables;

	/* Rebuild new varTypes */
	nvt = palloc(sizeof(LPvariableType) * res.numVariables);
	for (i=0; i < res.numVariables; i++)
		nvt[i] = prob->varTypes[res.varIndices[i]];
	/* Assign new variable types */
	prob->varTypes = nvt;

	/* Return variable indices */
	*varIndices = res.varIndices;
}


/* Solve a single LP problem partition using GLPK */
static LPsolverResult * solve_partition_glpk(LPproblem * prob, LPsolverSettings * settings)
{
	LPsolverResult	* result;
	glp_prob 		* lp;
	ListCell 		* c;
	int		 		i,j;
	int		 		* inds;
	double 	 		* vals;
	MemoryContext 	old_context;
	MemoryContext 	glp_context;
	struct timeval 	start_time, end_time; /* For performance benchmarking */

	// Initialize the result in the caller's context
	result=palloc(sizeof(LPsolverResult));
	result->numVariables = 0;
	result->varIndices = NULL;
	result->varValues = NULL;

	// Build unknown indices
	remap_LP_variables(prob, result);

	if (result->numVariables < 1)
	{
		ereport(INFO, (errmsg("SolverLP: Empty LP problem specified. No solver is called."),
					   errdetail("No unknown variables are involved in the objective or constraint functions.")));
		return NULL;
	}
	/* Allocate the space for solution variables in the persistent context */
	result->varValues = palloc(sizeof(double) * result->numVariables);

	/*
	 * Use per-tuple memory context to prevent leak of memory used to read
	 * rows from the file with Copy routines.
	 */
	glp_context = AllocSetContextCreate(CurrentMemoryContext,
									   "GLPK temporary context",
									   ALLOCSET_DEFAULT_MINSIZE,
									   ALLOCSET_DEFAULT_INITSIZE,
									   ALLOCSET_DEFAULT_MAXSIZE);
	old_context = MemoryContextSwitchTo(glp_context);

	PG_TRY();

	glpk_log_setLevel(settings->log_level);

	glp_init_env();	// Initialize the GLPK environment

	lp = glp_create_prob();

	glp_set_obj_dir(lp, prob->objDirection == LPobjMaximize ? GLP_MAX : GLP_MIN);

	// Setup cols
	glp_add_cols(lp, result->numVariables);

	// Setup variable bounds
	for(i=0; i < result->numVariables; i++)
		glp_set_col_bnds(lp, i+1, GLP_FR, 0, 0);

    // Setup objective coefficients
	if (prob->obj)
		for(i=0; i < prob->obj->numTerms; i++)
		{
			lpTerm * term = &prob->obj->term[i];

			// Setup non-zero constant
			glp_set_obj_coef(lp, (term->varNr)+1, term->factor);
		}

	// Setup column types (for MIP problem only)
	if (settings->solvingMode == LPsolvingMIP)
		/* Sets the column types */
		for(i=0; i < result->numVariables; i++)
		{
			int glp_type = prob->varTypes[result->varIndices[i]];

			glp_set_col_stat(lp, i+1, GLP_BS);
			glp_set_col_kind(lp, i+1,  glp_type == LPtypeInteger ? GLP_IV :
									   glp_type == LPtypeBool	 ? GLP_BV :
											   	   	   	   	   	   GLP_CV);
		}

	// Setup rows
	glp_add_rows(lp, list_length(prob->ctrs));  /* Add initial rows */
	inds = palloc(sizeof(int) * (result->numVariables + 1));
	vals = palloc(sizeof(double) * (result->numVariables + 1));
	inds[0] = vals[0] = 0; // These are not used
	i=0; 		// constraint iterator

	foreach(c, prob->ctrs)
	{
		Sl_Ctr 			*ne = lfirst(c);
		pg_LPfunction 	*poly = DatumGetLPfunction(sl_ctr_get_x_val(ne));
		LPfunctionType	poly_type;
		double 			value;

		Assert(poly != NULL);
		/* Moves the factor0 to the value side */
		value = ne->c_val - poly->factor0;

		/* We treat constraints differently depending on the function type */
		/* Detect the constraint type */
		poly_type = get_function_type(prob, result->varIndices, poly);

		if (poly_type == LPfunctionEmpty)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					 errmsg ("SolverLP: Cannot handle constraints involving no unknown variables in constraint query %d", i),
					 errdetail("Please check your query.")));

		if ((poly_type == LPfunctionBool) && (ne->op == SL_CtrType_NE))
			/* We can handle negation for booleans */
			glp_set_row_bnds(lp, i + 1, GLP_FX, 1 - value, 1 - value); /* Inverse the value*/
		else if ((poly_type == LPfunctionInteger)	&& (ne->op == SL_CtrType_LT))
			/* We can handle LT AND GT for integers */
			glp_set_row_bnds(lp, i + 1, GLP_LO, value + 1, 0);
		else if ((poly_type == LPfunctionInteger)	&& (ne->op == SL_CtrType_GT))
			glp_set_row_bnds(lp, i + 1, GLP_UP, 0, value - 1);  // Fix from "value + 1, 0"
		else
			switch (ne->op) {
			case SL_CtrType_EQ:
				glp_set_row_bnds(lp, i + 1, GLP_FX, value, value);
				break;
			case SL_CtrType_GE:
				glp_set_row_bnds(lp, i + 1, GLP_UP, 0, value);
				break;
			case SL_CtrType_LE:
				glp_set_row_bnds(lp, i + 1, GLP_LO, value, 0);
				break;
			default:
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg ("SolverLP: Invalid constraint specified in the constraint query %d", i),
						 errdetail("The solver only supports  =, >=, <= for float and mixed constraints, > and < for integer constraints, and != for boolean constraints")));
				break;
			}

		// Setup indices and bound coefficients
		for(j=0; j < poly->numTerms; j++)
		{
			lpTerm 	* term = &poly->term[j];
			inds[j+1] = term->varNr + 1;
			vals[j+1] = term->factor;
		}

		glp_set_mat_row(lp, i+1, j, inds, vals);

		i++;
	}

	/* Setup the basis */
	glp_adv_basis(lp, 0);

	/* Measure the solving time */
	glpk_log_printf("Measuring of time started\n");
	gettimeofday(&start_time, NULL);

	switch (settings->solvingMode) {
	case LPsolvingBasic: { /* Solve the basic LP problem */
		    glp_smcp params_lp;
			int glp_result;

			/* Initialize the parameters */
			glp_init_smcp(&params_lp);
			params_lp.presolve = GLP_ON;
			params_lp.msg_lev = GLP_MSG_ALL;

			glp_result = glp_simplex(lp, &params_lp);

			if ((glp_result != 0) || !((glp_get_status(lp) == GLP_OPT) || (glp_get_status(lp) == GLP_FEAS)))
				elog(
					ERROR, "SolverLP: No optimal solution is found or error occurred. Use log_level = %d (LOG) to see the solver's output.\n", LOG);
			break;
	}
	case LPsolvingMIP: { /* If requested, solve the MIP problem */
		    glp_iocp params_int;
			int intret;
			
			/* Initialize the parameters */
			glp_init_iocp(&params_int);
			params_int.presolve = GLP_ON;
			params_int.msg_lev = GLP_MSG_ALL;

			/* No need "glp_simplex" as presolver is enabled */
			intret = glp_intopt(lp, &params_int);

			if (intret != 0)					/* Fail the call ! */
				elog(
					ERROR, "SolverLP: GLPK Integer Optimizer has failed. Try solving the problem as a basic LP problem. Use log_level = %d (LOG) to see the solver's output.\n", LOG);
			break;
	}
	default:
		/* Fail the call ! */
		elog(ERROR, "SolverLP: Incorrect problem types specified. The supported types are LP and MIP.");
		break;
	}

	/* Compute and output the solving time*/
	gettimeofday(&end_time, NULL);
	result->solvingTime = time_diff(&end_time, &start_time);

	glpk_log_printf("Time used in GLPK solving: %.6f secs\n", result->solvingTime);

	/* Copy the solution to the persistent storage */
	for (i=0; i < result->numVariables; i++)
		result->varValues[i] = settings->solvingMode==LPsolvingMIP ? glp_mip_col_val(lp, i+1) : glp_get_col_prim(lp, i+1);

	/* Clean up, and switch to the old context to store the result */
	MemoryContextSwitchTo(old_context);

	PG_CATCH();
	{
//		 	 /* If there's any output from the solver, forward to Postgres */
//			if (glpk_log_getbuffer()!=NULL && strlen(glpk_log_getbuffer()) > 0)
//				ereport(INFO, (errmsg("%s", glpk_log_getbuffer())));

         	 glp_free_env();	// Must be called as it deals with static variables
         	 // glpk_log_free();   /* Redundant as the log buffer will be freed on the context switch */
		 	 MemoryContextSwitchTo(old_context);
		 	 MemoryContextDelete(glp_context);
	         PG_RE_THROW();
	}
	PG_END_TRY();

//	 /* If there's any output from the solver, forward to Postgres */
//	if (glpk_log_getbuffer()!=NULL && strlen(glpk_log_getbuffer()) > 0)
//			ereport(INFO, (errmsg("%s", glpk_log_getbuffer())));

	glp_free_env();    // Must be called as it deals with static variables
	// glpk_log_free();   /* Redundant as the log buffer will be freed on the context switch */

	MemoryContextSwitchTo(old_context);
	MemoryContextDelete(glp_context);

	return result;
}

/* Solve a single LP problem partition using CBC */
static LPsolverResult * solve_partition_cbc(LPproblem * prob, LPsolverSettings * settings)
{
	MemoryContext 	old_context, cbc_context;
	LPsolverResult 	* solres = NULL, * result = NULL;
	int				* varIndices = NULL;

	cbc_context = AllocSetContextCreate(CurrentMemoryContext,
			"CBC solving context",
			ALLOCSET_DEFAULT_MINSIZE,
			ALLOCSET_DEFAULT_INITSIZE,
			ALLOCSET_DEFAULT_MAXSIZE);

	old_context = MemoryContextSwitchTo(cbc_context);

	PG_TRY();

		/* Let's compact the LP problem for Cbc */
		compactLPproblem(prob, &varIndices);

		/* Forward to libPgCbc */
		solres = solve_problem_cbc(prob, settings->cbcArguments, settings->log_level);


	PG_CATCH();
	{
	 	MemoryContextSwitchTo(old_context);
	 	MemoryContextDelete(cbc_context);
        PG_RE_THROW();
	}
	PG_END_TRY();

 	MemoryContextSwitchTo(old_context);

 	/* Copy the solution to the current memory context */
 	if (solres != NULL && varIndices != NULL)
 	{
 		int 		i;
		result = palloc(sizeof(LPsolverResult));
		result->numVariables = solres->numVariables;
		result->varIndices   = palloc(sizeof(int) * solres->numVariables);
		result->varValues    = palloc(sizeof(double) * solres->numVariables);
		result->solvingTime  = solres->solvingTime;

		/* Setup indices */
		for (i=0; i < result->numVariables; i++)
			result->varIndices[i] = varIndices[solres->varIndices[i]];

		/* Copy solution values */
		memcpy(result->varValues,  solres->varValues,  sizeof(double) * solres->numVariables);
 	}

 	MemoryContextDelete(cbc_context);

 	return result;
}

static LPsolverResult * solve_main_lp_problem(LPproblem * prob,	LPsolverSettings * settings) {
	List * s_prbs = NIL; /* Subproblems */
	LPsolverResult * result;
	MemoryContext old_context, part_context;
	List * s_prbs_sol = NIL; /* Subproblem solutions */
	ListCell * c;
	int i, j;
	struct timeval slv_start, slv_end, part_start, part_end; /* For performance benchmarking */

	if (settings->partition_size > 0) /* If problem paritioning is requested */
	{
		if (settings->log_level <= NOTICE) gettimeofday(&part_start, NULL);

		/* Partitioning */
		s_prbs = partitionLPproblem(prob, settings->partition_size); /* Partition the main problem */

		if (settings->log_level <= NOTICE) gettimeofday(&part_end, NULL);
	}

	/* Start measuring solving time */
	if (settings->log_level <= NOTICE)	gettimeofday(&slv_start, NULL);

	if (s_prbs == NULL || list_length(s_prbs) == 1) /* The problem cannot be partitioned. */
		result = SOLVE_PARTITION(prob, settings);   /* Solve the main problem. */
	else {

		/* OK. The partitioning is possible. Let's solve each problem individually */
		part_context = AllocSetContextCreate(CurrentMemoryContext,
				"SolverLP partitioned problem solving context",
				ALLOCSET_DEFAULT_MINSIZE,
				ALLOCSET_DEFAULT_INITSIZE,
				ALLOCSET_DEFAULT_MAXSIZE);
		old_context = MemoryContextSwitchTo(part_context);

		/* Solve each problem */
		foreach(c, s_prbs)
		{
			LPproblem * sprob = (LPproblem *) lfirst(c);
			LPsolverResult * sprob_sol;
			struct timeval pstart, pend; /* For performance benchmarking */

			if (settings->log_level <= DEBUG1)
				gettimeofday(&pstart, NULL);

			/* Solve the partition */
			sprob_sol = SOLVE_PARTITION(sprob, settings);

			CHECK_FOR_INTERRUPTS();	// Check if someone has interrupted the operation

			if (settings->log_level <= DEBUG1)
			{
				gettimeofday(&pend, NULL);
				ereport(INFO, (errmsg("Solving the partition took %.6f secs.", time_diff(&pend, &pstart))));
			}


			if (sprob_sol != NULL)
				s_prbs_sol = lappend(s_prbs_sol, sprob_sol);
		}

		MemoryContextSwitchTo(old_context);

		/* Initialize the result for the main problem */
		result = palloc(sizeof(LPsolverResult));

		/* Compute the number of variables and set the solving time */
		result->numVariables = 0;
		result->solvingTime  = 0;
		foreach(c, s_prbs_sol)
		{
			LPsolverResult * sprob_sol = ((LPsolverResult *) lfirst(c));

			result->numVariables += sprob_sol->numVariables;
			/* Append solving time */
			result->solvingTime += sprob_sol->solvingTime;
		}

		/* Initialize the index and value arrays */
		result->varIndices = palloc(sizeof(int) * result->numVariables);
		result->varValues = palloc(sizeof(double) * result->numVariables);

		/* Copy the solution and indices */
		j = 0;
		foreach(c, s_prbs_sol)
		{
			LPsolverResult * ssol = (LPsolverResult *) lfirst(c);
			for (i = 0; i < ssol->numVariables; i++) {
				result->varIndices[j] = ssol->varIndices[i];
				result->varValues[j] = ssol->varValues[i];
				j++;
			}
		}
		/* OK. Let's free partitioner's data */
		MemoryContextDelete(part_context);
	}

	/* Report statistics */
	if (settings->log_level <= NOTICE)
	{
		StringInfoData buf;

		/* End measuring the time */
		gettimeofday(&slv_end, NULL);

		initStringInfo(&buf);

		appendStringInfo(&buf, "SolverLP: ");

		if (settings->partition_size > 0)
		{
			appendStringInfo(&buf, "Solved %d partitions. ", list_length(s_prbs));
			appendStringInfo(&buf, "The partitioning took %.6f secs. ", time_diff(&part_end, &part_start));
		}

		if (result != NULL)
			appendStringInfo(&buf, "Solving took %.6f secs. ", result->solvingTime);

		appendStringInfo(&buf, "Total solving time is %.6f secs.", time_diff(&slv_end, &slv_start));

		ereport(INFO, (errmsg("%s", buf.data)));
	}

	/* Return the solution */
	return result;
}


/*
 * Get the type of the function
 */
static LPfunctionType get_function_type(LPproblem * prob, int * varIndices, pg_LPfunction * poly)
{
	int 			i;
	LPfunctionType	type = LPfunctionEmpty;	/* */

	for(i = 0; i < poly->numTerms; i++)
	{
		LPvariableType	   	var_type;
		LPfunctionType 		var_typep;
		int			   		baseVarNr = varIndices[poly->term[i].varNr];

		Assert(baseVarNr>= 0 && baseVarNr < prob->numVariables);

		var_type = prob->varTypes[baseVarNr];
		var_typep =  var_type == LPtypeBool    ? LPfunctionBool :
					 var_type == LPtypeInteger ? LPfunctionInteger :
							 	 	 	 	     LPfunctionFloat;

		if (type == LPfunctionEmpty)
			type = var_typep;
		else if (type != var_typep)
		{
			 type = LPfunctionMixed;
			 break;
		}
	}

	return type;
}


/* Prepares all arrays required by SolverAPI */
static void build_result(LPviewSolution * sol, int * ra_count, int ** ra_parids, Oid ** ra_types, Datum ** ra_values)
{
  /* Result are put to 2 types of arrays: 1. int/float; 2. boolean */
  double	*fa     = NULL;
  /* Int/float array */
  ArrayType *fapg  	= NULL;		// Array of result for float variables
  /* Bool array */
  ArrayType	*bapg   = NULL;
  /* Null mask array*/
  bool		*nulls 	= NULL;			// A null array
  int 		i;
  bool		found;
  Datum		*datums;
  int		dims[1];
  int		lbs[1];
  /* Stores the result */
  // int			lind[2];
  static int  	*lra_parids;
  static Oid	*lra_types;
  static Datum  *lra_values;

  /* Searches for integer/float values */
  found = false;
  /* Initialize the float array */
  for (i=0; i < sol->arg->prb_colcount; i++)
	  if (sol->colTypes[i] == LPtypeFloat ||
	      sol->colTypes[i] == LPtypeInteger)
	  {
		  found = true;
		  break;
	  }
  /* Build the float/int array */
  if (found)
  {
	  fa	= palloc0(sizeof(double) * sol->arg->prb_varcount);
	  nulls = NULL;
	  /* Do we want to have NULLs at non-referenced variables positions? */
	  if (sol->use_nulls)
	  {
		  nulls = palloc(sizeof(bool) * sol->arg->prb_varcount);
		  /* Initially, all slots are NULL */
		  for(i=0; i< sol->arg->prb_varcount; i++)
			  nulls[i] = true;
	  }
	  /* Fill the arrays with result values */
	  for(i=0; i < sol->prob_sol->numVariables; i++)
		  if ((sol->varTypes[sol->prob_sol->varIndices[i]] == LPtypeInteger) ||
			  (sol->varTypes[sol->prob_sol->varIndices[i]] == LPtypeFloat))
			  {
			  	  fa   [sol->prob_sol->varIndices[i] - 1] = sol->prob_sol->varValues[i];
			  	  if (nulls)
			  		  nulls[sol->prob_sol->varIndices[i] - 1] = false;
			  }
	  /* Build an array datum */
	  dims[0] = sol->arg->prb_varcount;
	  lbs[0] = 1;
	  if (FLOAT8PASSBYVAL )
		  datums = (Datum *) fa;
	  else {
		  datums = (Datum *) palloc(sizeof(Datum) * sol->arg->prb_varcount);
		  for (i = 0; i < sol->arg->prb_varcount; i++)
			datums[i] = (Datum) &(fa[i]);
	  }

	  fapg = construct_md_array(datums, nulls, 1, dims, lbs, FLOAT8OID, sizeof(float8), FLOAT8PASSBYVAL, 'd');

	  if (!FLOAT8PASSBYVAL)
		  pfree(datums);

	  pfree(fa);
	  if (nulls)
		  pfree(nulls);
  }

  /* Initialize the boolean arrays */
  found = false;
  /* Initialize the float array */
  for (i=0; i < sol->arg->prb_colcount; i++)
	  if (sol->colTypes[i] == LPtypeBool)
	  {
		  found = true;
		  break;
	  }
  /* Build the boolean arrays */
  if (found)
  {
	  datums = palloc0(sizeof(Datum) * sol->arg->prb_varcount);
	  nulls  = NULL;
	  if (sol->use_nulls)
	  {
		  nulls  = palloc(sizeof(bool)  * sol->arg->prb_varcount);
		  /* Initially, all slots are NULL */
		  for(i=0; i< sol->arg->prb_varcount; i++)
			  nulls[i] = true;
	  }
	  /* Fill the arrays with result values */
	  for(i=0; i < sol->prob_sol->numVariables; i++)
		  if (sol->varTypes[sol->prob_sol->varIndices[i]] == LPtypeBool)
		  {
			/* Floating point conversion to boolean */
			datums  [sol->prob_sol->varIndices[i] - 1] = DatumGetBool((bool)(fabs(sol->prob_sol->varValues[i] - 1)<1E-5));
			if (nulls)
				nulls   [sol->prob_sol->varIndices[i] - 1] = false;
		  }
	  /* Build an array datum */
	  dims[0] = sol->arg->prb_varcount;
	  lbs[0] = 1;

	  bapg = construct_md_array((Datum *)datums, nulls, 1, dims, lbs, BOOLOID, 1, true, 'c');
	  pfree(datums);
	  if (nulls)
		  pfree(nulls);
  }
  /* Build a final result for SolverAPI */

  /* lind[0] 	= 0		  +	(fapg != NULL ? 1 : 0);
     lind[1]	= lind[0] + (bapg != NULL ? 1 : 0);*/

  lra_parids = palloc(sizeof(int)  *sol->arg->prb_colcount);
  lra_types  = palloc(sizeof(Oid)  *sol->arg->prb_colcount);
  lra_values = palloc(sizeof(Datum)*sol->arg->prb_colcount);

  for(i=0; i < sol->arg->prb_colcount; i++)
  {
	  /*(sol->colTypes[i] == LPtypeBool) ? lind[1] : lind[0]; */
	  lra_parids[i] = i + 1; /* 2015-05-13 fix */
	  lra_types [i] = (sol->colTypes[i] == LPtypeBool) ? BOOLARRAYOID :
			  	  	  	  	  	  	  	  	  	  	      FLOAT8ARRAYOID;
	  lra_values[i] = (sol->colTypes[i] == LPtypeBool) ? (Datum) bapg :
			  	  	  	  	  	  	  	  	  	  	  	  (Datum) fapg ;
  }

  *ra_count = sol->arg->prb_colcount;
  *ra_parids = lra_parids;
  *ra_types = lra_types;
  *ra_values = lra_values;
}

static inline double time_diff(struct timeval *tod1, struct timeval *tod2)
{
    long long t1, t2;
    t1 = tod1->tv_sec * 1E6 + tod1->tv_usec;
    t2 = tod2->tv_sec * 1E6 + tod2->tv_usec;
    return ((double)(t1 - t2)) / 1E6;
}
