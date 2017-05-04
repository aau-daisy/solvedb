/*
 * low_level_utils.h
 *
 *  Created on: Nov 19, 2012
 *      Author: laurynas
 */

#ifndef LOW_LEVEL_UTILS_H_
#define LOW_LEVEL_UTILS_H_

#include "postgres.h"
#include "nodes/pg_list.h"
#include "utils/array.h"

/* Returns an OID of enum "typname" */
extern Oid sl_get_enumOidFromLabel(const char *typname, const char *label);
extern char * sl_get_enumLabelFromOid(const Oid oid);

/* Returns a Relation from relation type */
/* extern Relation sl_get_rel_from_relname(char *relname_text, LOCKMODE lockmode, AclMode aclmode);
extern char **  sl_get_rel_col_names(Relation r, unsigned int * numAttrs); */

/* This function results an array of attribute descriptions of a provided SQL query.
 * Returns an array of SL_Attribute_Desc.  */



/* This gets a list of heaptuples from the array datum */
extern List * get_datum_array_contents(ArrayType *array);

#endif /* LOW_LEVEL_UTILS_H_ */
