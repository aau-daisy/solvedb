/*
 * solversw.h
 *
 *  Created on: Nov 14, 2012
 *      Author: laurynas
 */

#ifndef SOLVERSW_H_
#define SOLVERSW_H_

#include "postgres.h"
#include "solverapi.h"

/* We need an OID of float8 array. It is not present in PG headers, thus we compute it easily */
#define FLOAT8ARRAYOID (FLOAT4ARRAYOID + 1)

Datum swarmops_solve(PG_FUNCTION_ARGS);

#endif /* SOLVERSW_H_ */
