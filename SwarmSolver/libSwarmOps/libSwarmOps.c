#include "libSwarmOps.h"
#include "postgres.h"
#include "Optimize.h"
#include "Methods/Methods.h"
#include "Statistics/Results.h"
#include "RandomOps/Random.h"

extern size_t getMethodId(char * methodName);
extern SO_TElm const* getMethodParameters(size_t methodId, SwarmOpsParameter * methodParams, int numMethodParams);

extern SwarmOpsOutput SwarmOpsSolve(SwarmOpsProblem * problem) {
	MemoryContext oldcontext;
	size_t methodId;
	SO_TElm const *methodParValues;
	struct SO_Results methodResults;
	SwarmOpsOutput res;

	// Initialize the result
	res.errordata = NULL;
	res.result = NULL;

	/* We use the PG's LONGJUMP approach to handle errors in SwarmOPS as the library does not use exceptions */
	oldcontext = CurrentMemoryContext;
	PG_TRY();
	{
		// Detect the method name
		methodId = getMethodId(problem->methodName);
		// Set default and apply user defined parameters from methodParams
		methodParValues = getMethodParameters(methodId, problem->methodParams,
				problem->numMethodParams);

		/* Seed the pseudo-random number generator. */
		if (problem->rndSeedSet)
			RO_RandSeed(problem->rndSeed);
		else
			RO_RandSeedClock(rand());

		methodResults = SO_OptimizePar(methodParValues, methodId, problem->numRuns,
				problem->numIterations, NULL, (SO_FProblem) problem->fitnessFn,
				NULL, problem->context, problem->numUknowns, problem->lowerInit,
				problem->upperInit, problem->lowerBound, problem->upperBound,
				NULL );

		if ((methodResults.best.x != NULL )&& (methodResults.best.dim == problem->numUknowns)){
			double *results;
			int i;
			results = (double *) palloc(sizeof(double) * methodResults.best.dim);
			for(i=0; i<methodResults.best.dim; i++)
			results[i] = methodResults.best.x[i];
			res.result = results;
		}
	}
	PG_CATCH();
	{
		/* Must reset elog.c's state */
		MemoryContextSwitchTo(oldcontext);
		res.errordata = CopyErrorData();
		FlushErrorState();
	}
	PG_END_TRY();

	return res;
}


extern size_t getMethodId(char * methodName)
{
	size_t 			methodId;
	int 			i;
	char  			diffName[64]; /* As some method names have " (Basic)" concatenated, we correct the name */

	snprintf(diffName, sizeof(diffName), "%s (Basic)", methodName);

	for (i=0; i< SO_kNumMethods; i++)
	{
		if (strcasecmp(methodName, SO_kMethodName[i]) == 0)
			return i;
		if (strcasecmp(diffName, SO_kMethodName[i]) == 0)
			return i;
	}

	ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
	                errmsg("The method \"%s\" is not supported by the solver", methodName)));
	return -1;
}

extern SO_TElm const* getMethodParameters(size_t methodId, SwarmOpsParameter * methodParams, int numMethodParams)
{
	SO_TElm 	*parValues;
	int i,j;
	bool found;

	// Allocate size for parameters
	parValues = (SO_TElm *) palloc0(sizeof(SO_TElm) * SO_kMethodNumParameters[methodId]);
	// Set default optimization parameters
	memcpy(parValues, SO_kMethodDefaultParameters[methodId], sizeof(SO_TElm) * SO_kMethodNumParameters[methodId]);
	// Apply user defined parameters from methodParams
	for (i=0; i < numMethodParams; i++)
	{
		found = FALSE;
		for (j=0; j < SO_kMethodNumParameters[methodId]; j++)
			if (strcasecmp(methodParams[i].param, SO_kMethodParameterName[methodId][j]) == 0)
			{
				parValues[j] = methodParams[i].value;
				found = TRUE;
			};
		if (!found)
			ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				                errmsg("The method \"%s\" does not support a parameter \"%s\"",
				                		SO_kMethodName[methodId],
				                		methodParams[i].param)));
	}
	return parValues;
}
