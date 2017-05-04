/*-------------------------------------------------------------------------
 *
 * solversw.c
 *	  Integration of the SwarmOPS to PostreSQL 9.2 (by Laurynas Siksnys)
 *
 *
 * Copyright (c) 2012, Aalborg University
 *
 * IDENTIFICATION
 *	  solversw.c
 *
 *-------------------------------------------------------------------------
 */
#include "solversw.h"
#include "fmgr.h"
#include "libSwarmOps.h" /* The library compiled with C++ */
#include "libsolverapi.h"
#include "catalog/pg_type.h"
#include "utils/memutils.h"
#include "catalog/namespace.h"
#include "access/htup_details.h"

PG_MODULE_MAGIC;

/* A list of parameters used by the solver (every method) */
#define SPAR_COUNT 3
#define SPAR_NAMES ((const char * [SPAR_COUNT]) {"n", "rndseed", "runs"})
#define SPAR_pIterationCount 0
#define SPAR_pRndSeed 1
#define SPAR_pRuns 2

/* The solver's context. It carries all information needed to evaluate the prepared query for the fitness function*/
typedef struct SolverContext {
	SwarmOpsProblem		*prob;			/* A pointer to a problem object */
	ArrayType 			*x_arr;			/* A PG array wrapper on top of the solution array "x_ptr" */
	SPIPlanPtr			plan;			/* A prepared query plan to evaluate the fitness function */
} SolverContext;

static SwarmOpsParameter * getMethodParameters(SL_Solver_Arg *arg, int * numParameters);
static void setupInits(SL_Solver_Arg * arg, Datum arg_d, SwarmOpsProblem * prob);
static void setupBounds(SL_Solver_Arg * arg, Datum arg_d, SwarmOpsProblem *	prob);
static bool callTheSolver(SL_Solver_Arg * arg, Datum arg_d, SwarmOpsProblem * prob, double * sol_result);
static SolverContext * setupContext(SL_Solver_Arg * arg, Datum arg_d, SwarmOpsProblem *	prob);
static bool datum_get_double(Oid type_oid, Datum bin_val, double * outval);
static double fitness_function(const double *x, void *context, const double fitnessLimit);


//PG_FUNCTION_INFO_V1(swarmops_solve2);
//Datum swarmops_solve2(PG_FUNCTION_ARGS) {
//	SL_SOLVER_BEGIN
//
//	Sl_Viewsql_Src src;
//	Datum arg_d = PG_GETARG_SLSOLVERARGDATUM(0);
//	src = sl_build_dst_return(arg_d, sl_build_src(arg_d));
//
//	SL_SOLVER_RETURN(src, 0, NULL, NULL);
//	SL_SOLVER_END
//}

PG_FUNCTION_INFO_V1(swarmops_solve);
Datum swarmops_solve(PG_FUNCTION_ARGS)
{
	SL_SOLVER_BEGIN
	Datum 				arg_d = PG_GETARG_SLSOLVERARGDATUM(0);  /* Get solver argument as DATUM */
	SL_Solver_Arg 		*arg  = PG_GETARG_SLSOLVERARG(0);		/* Get solver argument as SL_Solver_Arg */
	SwarmOpsProblem		prob;	/* A definition of black-box problem */
	double				*solresult;
	bool				solfound;
	int					ret;

	/* Check if the problem is solvable */
	if (arg->problem->obj_dir != SOL_ObjDir_Minimize)
        ereport(ERROR,
            (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
             errmsg   ("SwarmOPS: Unsupported objective direction"),
             errdetail("SwarmOPS: The solver can only solve the minimization problem. To maximize the objective, please change the sign of the objective function.")));
	/* Sets a method's name */
	prob.methodName = arg->method_name;
	/* Sets parameters to override */
	prob.methodParams = getMethodParameters(arg, &(prob.numMethodParams));
	/* Set the number of iterations. SolverAPI promises to always set it */
	prob.numIterations = sl_param_get_as_int(arg, SPAR_NAMES[SPAR_pIterationCount]);

	/* Set the random seed parameter. SolverAPI will not push the default value if a user does not specify */
	prob.rndSeedSet = sl_param_isset(arg, SPAR_NAMES[SPAR_pRndSeed]);
	if (prob.rndSeedSet)
		prob.rndSeed = sl_param_get_as_int(arg, SPAR_NAMES[SPAR_pRndSeed]);

	if (sl_param_isset(arg, SPAR_NAMES[SPAR_pRuns]))
		prob.numRuns = sl_param_get_as_int(arg, SPAR_NAMES[SPAR_pRuns]);
	else
		prob.numRuns = 1;	/* By default, run once (1) */

	/* Initialize the problem */
	prob.numUknowns = arg->prb_varcount;
	/* Setup inits and bounds */
	setupBounds(arg, arg_d, &prob);
	setupInits (arg, arg_d, &prob);
	/* Setup the fitness function */
	prob.fitnessFn = &fitness_function;
	/* Initialize the solution vector in the current memory context as SPI_finish() kills allocations */
	solresult = palloc0(sizeof(double) * prob.numUknowns);

	/* Initialize the context and run the solver SPI*/
	if ((ret = SPI_connect()) < 0)
		elog(ERROR, "SwarmOPS: SPI_connect returned %d", ret);
	/* Setup problem's context */
	prob.context = setupContext(arg, arg_d, &prob);
	/* Solve the problem*/
	solfound = callTheSolver(arg, arg_d, &prob, solresult);
	/* Finalize the SPI */
	if ((ret = SPI_finish()) < 0)
		elog(ERROR, "SwarmOPS: SPI_finish returned %d", ret);

	if (!solfound)
		/* If a error occurred, output the unchanged input table */
		SL_SOLVER_RETURN(sl_build_out(arg_d), 0,  NULL, NULL);
	else
	{
		Oid 	param_types[1];
		Datum	param_values[1];
		Datum   *v_datums = palloc(sizeof(Datum) * prob.numUknowns);
		int i;

		for(i=0; i < prob.numUknowns; i++)
			v_datums[i] = Float8GetDatum(solresult[i]);

		param_types[0] = FLOAT8ARRAYOID;
		param_values[0] = PointerGetDatum(construct_array(v_datums, prob.numUknowns, FLOAT8OID, sizeof(float8), FLOAT8PASSBYVAL, 'd'));

		pfree(v_datums);

		SL_SOLVER_RETURN(sl_build_out_array1subst(arg_d, 1), 1, param_types, param_values);
	}
	SL_SOLVER_END
}

static SwarmOpsParameter * getMethodParameters(SL_Solver_Arg *arg, int * numParameters)
{
	SwarmOpsParameter * result;
	ListCell 	*c;
	int 	 	i;
	bool 		mtdParam;

	result = palloc(sizeof(SwarmOpsParameter) * list_length(arg->params));
	*numParameters = 0;
	foreach(c, arg->params)
	{
		SL_Parameter_Value * pv = lfirst(c);

		/* Skip solver parameters, leave only method parameters*/
		mtdParam = true;
		for (i = 0; i < SPAR_COUNT; i++)
			if (strcasecmp(pv->param, SPAR_NAMES [i]) == 0) {
				mtdParam = false;
				break;
			}
		if (mtdParam) {
			result[*numParameters].param = pv->param;
			result[*numParameters].value = pv->value_f;
			(*numParameters)++;
		}
	}
	return result;
}

/* The function initializes the bounds for unknown variables */
static void setupBounds(SL_Solver_Arg * arg, Datum arg_d, SwarmOpsProblem * prob)
{
	int 			i;
	Sl_Viewsql_Out  out;

	prob->lowerBound = palloc(sizeof(double) * arg->prb_varcount);
	prob->upperBound = palloc(sizeof(double) * arg->prb_varcount);

	/* Initialize the default bounds */
	for(i=0; i < arg->prb_varcount; i++)
	{
		prob->lowerBound[i] = SwarmOpsBoundLower;
		prob->upperBound[i] = SwarmOpsBoundUpper;
	}

	/* Do for every user-specified constraint query */
	out = sl_build_out_func1subst(arg_d, SL_PGNAME_Sl_Unkvar_Make);
	for(i=1; i <= list_length(arg->problem->ctr_sql); i++)
	{
		int				j,k;
		int 			ret;
		uint32			proc;
		Sl_Viewsql_Dst 	dst;
		Oid				slctr_oid;

		/* Build a viewsql for [Constraint] destination view */
		dst = sl_build_dst_ctr(arg_d, out, i);
		/* Run the constraint query */
		/* Initialize the SPI*/
		if ((ret = SPI_connect()) < 0)
			elog(ERROR, "SwarmOPS: SPI_connect returned %d", ret);

		/* Execute the query */
		ret = SPI_execute(dst, true, 0);
		if (ret < 0)
			elog(ERROR, "SwarmOPS: SPI_exec returned %d", ret);

		proc = SPI_processed;

		/* Check the schema of the constraint relation */
		slctr_oid = TypenameGetTypid(SL_PGNAME_Sl_Ctr);
		Assert(OidIsValid(slctr_oid));
		for(j=1; j <= SPI_tuptable->tupdesc->natts; j++)
			if (SPI_gettypeid(SPI_tuptable->tupdesc, j) != slctr_oid)
		        ereport(ERROR,
		            (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
		             errmsg   ("SwarmOPS: Constraint query %d is invalid", i),
		             errdetail("SwarmOPS: Constraint query must return tuples with attributes of type \"Sl_Ctr\"")));

		/* Process the constraints */
		for(j=0; j < proc; j++)
			for(k=1; k <= SPI_tuptable->tupdesc->natts; k++)
			{
				bool 		is_null;
				Sl_Ctr 		*ctr;
				int			uvarnr;

				ctr = DatumGetSLCtr(SPI_getbinval(SPI_tuptable->vals[j], SPI_tuptable->tupdesc, k, &is_null));
				if (is_null)
			        ereport(ERROR,
			            (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
			             errmsg   ("SwarmOPS: Constraint query is invalid"),
			             errdetail("SwarmOPS: Constraint query must not produce NULL values.")));
				/* Extract the unknown variable number */
				uvarnr = (int) DatumGetSLUnkvar(sl_ctr_get_x_val(ctr));
				if ((uvarnr < 1) || (uvarnr > arg->prb_varcount))
					elog(ERROR, "SwarmOPS: Unexpected variable number was returned during the constraint %d processing", i);
				/* Apply the constraint. Note, repeating constraints might show up due to the returned sets of sl_ctr
				 * in returned tuples */
				switch (ctr->op) {
				 case SL_CtrType_EQ:
					 prob->lowerBound[uvarnr-1] = prob->upperBound[uvarnr-1] = ctr->c_val;
				 	 break;
				 case SL_CtrType_GE:
					 prob->upperBound[uvarnr-1] = ctr->c_val;
					 break;
				 case SL_CtrType_LE:
					 prob->lowerBound[uvarnr-1] = ctr->c_val;
					 break;
				 default:
					 ereport(ERROR,
								            (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
								             errmsg   ("SwarmOPS: Invalid constraint specified in the constraint query %d", i),
								             errdetail("SwarmOPS: The solver only accepts  =, >=, <= constraints")));
					 break;
				}
			}
		/* Finalize the SPI */
		if ((ret = SPI_finish()) < 0)
			elog(ERROR, "SwarmOPS: SPI_finish returned %d", ret);
		pfree(dst);
	}
	pfree(out);
}

/* The function initializes the bounds for initial values for unknown variables */
static void setupInits(SL_Solver_Arg * arg, Datum arg_d, SwarmOpsProblem * prob) {
	int 			ret;
	Sl_Viewsql_Dst 	dst;
	uint32			proc;
	int 			i;

	prob->lowerInit = palloc(sizeof(double) * arg->prb_varcount);
	prob->upperInit = palloc(sizeof(double) * arg->prb_varcount);

	/* Initialize the default inits */
	for(i=0; i < arg->prb_varcount; i++)
	{
		prob->lowerInit[i] = prob->lowerBound[i];
		prob->upperInit[i] = prob->upperBound[i];
	}

	/* Build a destination view to fetch initial values from the input relation */
	dst = sl_build_dst_values(arg_d, sl_build_out(arg_d), "float8");

	/* Initialize the SPI*/
	if ((ret = SPI_connect()) < 0)
		elog(ERROR, "SwarmOPS: SPI_connect returned %d", ret);

	/* Execute the query */
	ret = SPI_execute(dst, true, 0);
	if (ret < 0)
		elog(ERROR, "SwarmOPS: SPI_exec returned %d", ret);

	proc = SPI_processed;

	if (SPI_tuptable->tupdesc->natts != 2)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("SwarmOPS: Query returned unexpected number of columns."),
				 errdetail("Destination view [Value] with 2 columns was expected")));

	if (proc != arg->prb_varcount)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("SwarmOPS: Query returned unexpected number of rows."),
				 errdetail("Destination view [Value] with %d rows was expected", (int) arg->prb_varcount)));

	if (SPI_gettypeid(SPI_tuptable->tupdesc, 1) != SL_OUTTMPID_OID)
	        ereport(ERROR,
	            (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
	             errmsg("SwarmOPS: Unexpected attribute 1 type in the destination view [Value]")));

	if (SPI_gettypeid(SPI_tuptable->tupdesc, 2) != FLOAT8OID)
	        ereport(ERROR,
	            (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
	             errmsg("SwarmOPS: Unexpected attribute 2 type in the destination view [Value]")));

	for(i = 0; i < proc; i++)
	{
		bool 	is_null;
		int 	var_nr;
		Datum	value_d;
		double 	value;

		var_nr = (int)DatumGetSLOUTTMPID(SPI_getbinval(SPI_tuptable->vals[i], SPI_tuptable->tupdesc, 1, &is_null));
		Assert(!is_null);

		if ((var_nr<1) || (var_nr > arg->prb_varcount))
	        ereport(ERROR,
	            (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
	             errmsg("SwarmOPS: Variable number out of range in the destination view [Value]")));

		value_d = SPI_getbinval(SPI_tuptable->vals[i], SPI_tuptable->tupdesc, 2, &is_null);
		if (!is_null)
		{
			/* Copy the value from the input table preventing the bound violation */
			if (!datum_get_double(SPI_gettypeid(SPI_tuptable->tupdesc, 2), value_d, &value))
				 ereport(ERROR,(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
					            errmsg("SwarmOPS: Initial value of a variable has an unsupported type")));

			prob->lowerInit[var_nr-1] = fmax(value, prob->lowerBound[var_nr-1]);
			prob->upperInit[var_nr-1] = fmin(prob->lowerInit[var_nr-1], prob->upperBound[var_nr-1]);
		}
		else
		{	/* By default, match the bounds */
			prob->lowerInit[var_nr-1] = prob->lowerBound[var_nr-1];
			prob->upperInit[var_nr-1] = prob->upperBound[var_nr-1];
		}
	}

	/* Finalize the SPI */
	if ((ret = SPI_finish()) < 0)
		elog(ERROR, "SwarmOPS: SPI_finish returned %d", ret);

	pfree(dst);	// Though, we still keep src in memory
}

static bool callTheSolver(SL_Solver_Arg * arg, Datum arg_d, SwarmOpsProblem * prob, double * sol_result)
{
	MemoryContext 		old_context;
	MemoryContext 		solver_context;
	SwarmOpsOutput		solResult;

	/* Initiaize a new memory context to prevent leak of memory when solving a problem */
	solver_context = AllocSetContextCreate(CurrentMemoryContext,
									   "SwarmOPS temporary context",
									   ALLOCSET_DEFAULT_MINSIZE,
									   ALLOCSET_DEFAULT_INITSIZE,
									   ALLOCSET_DEFAULT_MAXSIZE);
	old_context = MemoryContextSwitchTo(solver_context);

	/* Run the solver by calling C++ code */
	solResult = SwarmOpsSolve(prob);

	if (solResult.errordata != NULL)
		ReThrowError(solResult.errordata);

	MemoryContextSwitchTo(old_context);
	/* Copy the result, if found */
	if (solResult.result != NULL )
		memcpy(sol_result, solResult.result, sizeof(double) * prob->numUknowns);

	MemoryContextDelete(solver_context);

	return solResult.result != NULL;
}

static SolverContext * setupContext(SL_Solver_Arg * arg, Datum arg_d, SwarmOpsProblem *	prob)
{
	SolverContext 	*ctx = (SolverContext *) palloc(sizeof(SolverContext));
	Sl_Viewsql_Dst 	dst;
	Oid				argtypes[1];
   	Datum          	*v_datums;
   	int 			 	i;

	ctx->prob = prob;

  	v_datums = palloc(sizeof(Datum) * ctx->prob->numUknowns);
   	for(i=0; i < ctx->prob->numUknowns; i++)
   		v_datums[i] = Float8GetDatum(0);		/* Initialize zeros */

   	ctx->x_arr = construct_array(v_datums, ctx->prob->numUknowns, FLOAT8OID, sizeof(double), FLOAT8PASSBYVAL, 'd');
   	pfree(v_datums);

	/* Generates a destination view "[Objective]" for the objective function. We use "[Array Substitution]" as the source view */
	dst = sl_build_dst_obj(arg_d, sl_build_out_array1subst(arg_d,1));
	/* Prepares the query for the fitness function */

	argtypes[0] = FLOAT8ARRAYOID;
	ctx->plan = SPI_prepare(dst, 1, argtypes);
	if (ctx->plan == NULL)
	            elog(ERROR, "SwarmOPS: SPI_prepare(%s) failed for the destination view \"[Objective]\". SPI result %d", dst, SPI_result);

	return ctx;
}

static bool datum_get_double(Oid type_oid, Datum bin_val, double * outval)
{
	switch (type_oid) {
		case INT2OID:
			*outval = (double) DatumGetInt16(bin_val);
			return true;
		case INT4OID:
			*outval = (double) DatumGetInt32(bin_val);
			return true;
		case INT8OID:
			*outval = (double) DatumGetInt64(bin_val);
			return true;
		case FLOAT4OID:
			*outval = (double) DatumGetFloat4(bin_val);
			return true;
		case FLOAT8OID:
			*outval = (double) DatumGetFloat8(bin_val);
			return true;
		default:
			return false;
		}
}

static double fitness_function(const double *x, void *context, const double fitnessLimit)
{
	SolverContext 		*ctx = (SolverContext *)context;
	int 				ret;
	Datum				fitness_datum;
	double				fitness_val;
	bool				is_null;

	/* Copy a new solution to existing array */
    memcpy(ARR_DATA_PTR(ctx->x_arr), x, sizeof(double)*ctx->prob->numUknowns);

    /* Run the prepared query */
    if ((ret = SPI_execute_plan(ctx->plan, (Datum *) &(ctx->x_arr), NULL, true, 0)) < 0)
            elog(ERROR, "SwarmOPS: SPI_execp returned %d", ret);

    if (SPI_processed != 1 || (SPI_tuptable->tupdesc->natts != 1))
        ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                                           errmsg("SolverAPI: An objective function returned unexpected result."),
                                           errdetail("An objective function is expected to return a single row and a single column of the numeric type.")));


    fitness_datum = SPI_getbinval(SPI_tuptable->vals[0], SPI_tuptable->tupdesc, 1, &is_null);

    if (is_null)
    	ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
	                    errmsg("SwarmOPS: The objective function returned NULL value")));

	if (!datum_get_double(SPI_gettypeid(SPI_tuptable->tupdesc, 1), fitness_datum, &fitness_val))
		ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				        errmsg("SwarmOPS: The objective function returned a value of an unsupported type.")));

    SPI_freetuptable(SPI_tuptable);

    return fitness_val;
}


