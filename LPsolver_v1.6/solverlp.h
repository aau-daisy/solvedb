/*
 * solverlp.h
 *
 *  Created on: Oct 29, 2012
 *      Author: laurynas
 */

#ifndef SOLVERLP_H_
#define SOLVERLP_H_

#include "postgres.h"
#include "lp_function.h"
#include "libsolverapi.h"

/* A LP problem type to be solver */
typedef enum {
	LPsolvingAuto = 0,			/* The problem type must be automatically determined (default option) */
	LPsolvingBasic,				/* Basic LP problem */
	LPsolvingMIP,				/* Mixed integer programming problem */
	LPsolvingCBC				/* Solving with Coins CBC solver */
} LPsolvingMode;

/* Objetive function direction */
typedef enum {
	LPobjMaximize,
	LPobjMinimize
} LPobjDirection;

/* A type of unknown-variable */
typedef enum {
	LPtypeUndefined,
	LPtypeFloat,
	LPtypeInteger,
	LPtypeBool
} LPvariableType;

/* Structure that defines a LP problem*/
typedef struct {
//	LPsolvingMode		  probType;			/* A problem type to be solver */
	int					  numVariables; 	/* Number of variables */
	LPvariableType		  *varTypes;		/* Variable types */
	LPobjDirection		  objDirection;		/* Objective function direction */
	pg_LPfunction 	      *obj;				/* Objective linear function */
	List			      *ctrs;			/* Constraints */
} LPproblem;

/* Structure that defines a LP problem solution */
typedef struct {
	int 				  numVariables;	// Number of unknown variables, for which solution was found
	int 				  * varIndices;	// Mappings to original variable numbers.
	double 				  * varValues;	// Found values of the variables
	/* Performance measures */
	double				  solvingTime;	// Solving time (raw, not I/O).
} LPsolverResult;


#endif /* SOLVERLP_H_ */
