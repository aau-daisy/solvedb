/*
 * solversw.h
 *
 *  Created on: Nov 14, 2012
 *      Author: laurynas
 */

#ifndef LIB_SWARM_OPS_H_
#define LIB_SWARM_OPS_H_

// Makes it compatible with C compiler
#ifdef __cplusplus
extern "C" {
#endif

#include <float.h>

/* A type to define a parameter of a solver */
typedef struct SwarmOpsParameter {
	char 	*param;
	double	value;
} SwarmOpsParameter;

/* An objective function */
typedef double (* SwarpOpsFitnessFn)(const double *x, void *context, const double fitnessLimit);

/* A type to define a swarm ops problem */
typedef struct SwarmOpsProblem {
	char 				*methodName;
	SwarmOpsParameter 	*methodParams;
	int 				numMethodParams;
	int 				numIterations;
	int 				numRuns;
	SwarpOpsFitnessFn	fitnessFn;
	void				*context;
	int					numUknowns;
	double				*lowerInit;
	double				*upperInit;
	double				*lowerBound;
	double				*upperBound;
	bool				rndSeedSet;
	int					rndSeed; /* A number to seed the random number generator. */
} SwarmOpsProblem;

/* A type to define an output of the solver */
typedef struct SwarmOpsOutput {
	ErrorData			*errordata;	/* An error message, NULL is no errors */
	double				*result;	/* A result vector, NULL if no solution*/
} SwarmOpsOutput;

/* Default minimum bound value */
#define SwarmOpsBoundLower (-1E9)
/* Default maximum bound value */
#define SwarmOpsBoundUpper (1E9)

extern SwarmOpsOutput SwarmOpsSolve(SwarmOpsProblem * problem);

#ifdef __cplusplus
}
#endif

#endif /* LIB_SWARM_OPS_H_ */
