/*
 * solve-api.h
 *
 *  Created on: Nov 14, 2012
 *      Author: laurynas
 */

#ifndef _PG_SOLVE_API_H_
#define _PG_SOLVE_API_H_

#include "postgres.h"
#include "libsolverapi.h"

Datum sl_get_attributes_from_sql(PG_FUNCTION_ARGS);
Datum sl_get_tables_from_sql(PG_FUNCTION_ARGS);

Datum sl_dummy_solve(PG_FUNCTION_ARGS);
/* The function is used to create TMP table in security-restricted environment in PostgreSQL 9.3.1.
 * Hope this will not be needed in later DBMS editions */
Datum sl_createtmptable_unrestricted(PG_FUNCTION_ARGS);

/* Constraint handling functions */
extern Datum sl_ctr_in(PG_FUNCTION_ARGS);
extern Datum sl_ctr_out(PG_FUNCTION_ARGS);
extern Datum sl_ctr_make(PG_FUNCTION_ARGS);
extern Datum sl_ctr_makefrom(PG_FUNCTION_ARGS);
extern Datum sl_ctr_get_c(PG_FUNCTION_ARGS);
extern Datum sl_ctr_get_op(PG_FUNCTION_ARGS);
extern Datum sl_ctr_get_x(PG_FUNCTION_ARGS);

#endif /* _PG_SOLVE_API_H_ */
