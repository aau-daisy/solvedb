/*
 * libPgCbc.h
 *
 *  Created on: Sep 3, 2014
 *      Author: laurynas
 */

#ifndef LIBPGCBC_H_
#define LIBPGCBC_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "solverlp.h"

/* Solve the LP problem with CBC solver */
extern LPsolverResult * solve_problem_cbc(LPproblem * prob, char * args, int pgLogLevel);

#ifdef __cplusplus
}
#endif


#endif /* LIBPGCBC_H_ */
