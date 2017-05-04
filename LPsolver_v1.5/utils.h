/*
 * utils.h
 *
 *  Created on: Nov 1, 2012
 *      Author: laurynas
 */

#ifndef UTILS_H_
#define UTILS_H_

#include "postgres.h"
#include "utils/acl.h"
#include "storage/lock.h"
#include "utils/relcache.h"
#include "solverlp.h"

/* A configuration parameter-value pair */
typedef struct Pair_text
{
	char * val1;
	char * val2;
} Pair_text;

extern int compareInts (const void * a, const void * b);
extern Relation get_rel_from_relname(char *relname_text, LOCKMODE lockmode, AclMode aclmode);
extern List * get_text_array_contents(ArrayType *array);
extern List *get_pair_text_array_contents(ArrayType *array);

/* Returns a list of "LPcolumn_definition" for a given relation */
extern List * get_relation_col_names(Relation r);

#endif /* UTILS_H_ */
