/*
 * utils.c
 *
 *  Created on: Nov 1, 2012
 *      Author: laurynas
 */
#include "utils.h"
#include "catalog/namespace.h"
#include "catalog/pg_type.h"
#include "utils/rel.h"
#include "executor/spi.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "miscadmin.h"
#include "access/tupmacs.h"

/* Compares two integer values for the use in qsort */
extern int compareInts (const void * a, const void * b)
{
  return ( *(int*)a - *(int*)b );
}
/*
 * Open the relation named by relname_text, acquire specified type of lock,
 * verify we have specified permissions.
 * Caller must close rel when done with it.
 */
extern Relation
get_rel_from_relname(char *relname_text, LOCKMODE lockmode, AclMode aclmode)
{
	RangeVar   *relvar;
	Relation	rel;
	AclResult	aclresult;

	relvar = makeRangeVarFromNameList(textToQualifiedNameList(cstring_to_text(relname_text)));
	rel = heap_openrv(relvar, lockmode);

	aclresult = pg_class_aclcheck(RelationGetRelid(rel), GetUserId(),
								  aclmode);
	if (aclresult != ACLCHECK_OK)
		aclcheck_error(aclresult, ACL_KIND_CLASS, relname_text);

	return rel;
}

/*
 * Deconstruct a text[] into C-strings (note any NULL elements will be
 * returned as NULL pointers)
 */
extern List *
get_text_array_contents(ArrayType *array)
{
	int			ndim = ARR_NDIM(array);
	int		   *dims = ARR_DIMS(array);
	int			nitems;
	int16		typlen;
	bool		typbyval;
	char		typalign;
	List 	   *values;
	char	   *ptr;
	bits8	   *bitmap;
	int			bitmask;
	int			i;

	Assert(ARR_ELEMTYPE(array) == TEXTOID);

	nitems = ArrayGetNItems(ndim, dims);

	get_typlenbyvalalign(ARR_ELEMTYPE(array),
						 &typlen, &typbyval, &typalign);

	values = NIL;

	ptr = ARR_DATA_PTR(array);
	bitmap = ARR_NULLBITMAP(array);
	bitmask = 1;

	for (i = 0; i < nitems; i++)
	{
		if (bitmap && (*bitmap & bitmask) == 0)
		{
			values = lappend(values, NULL);
		}
		else
		{
			values = lappend(values, (char *) TextDatumGetCString(PointerGetDatum(ptr)));
			ptr = att_addlength_pointer(ptr, typlen, ptr);
			ptr = (char *) att_align_nominal(ptr, typalign);
		}

		/* advance bitmap pointer if any */
		if (bitmap)
		{
			bitmask <<= 1;
			if (bitmask == 0x100)
			{
				bitmap++;
				bitmask = 1;
			}
		}
	}

	return values;
}

/*
 * Deconstruct a text[][] into a pairs of C-strings of type "pair_text"
 * (note any NULL elements will be returned as NULL pointers)
 */
extern List *get_pair_text_array_contents(ArrayType *array)
{
	int			ndim = ARR_NDIM(array);
	int		   *dims = ARR_DIMS(array);
	int			nitems;
	int16		typlen;
	bool		typbyval;
	char		typalign;
	Pair_text  *pair;
	List 	   *values;
	char	   *ptr;
	bits8	   *bitmap;
	int			bitmask;
	int			i;

	Assert(ARR_ELEMTYPE(array) == TEXTOID);
	if (ndim != 2)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("A text array of two dimensions is expected.")));

	nitems = ArrayGetNItems(ndim, dims);

	get_typlenbyvalalign(ARR_ELEMTYPE(array),
						 &typlen, &typbyval, &typalign);


	values = NIL;

	pair = NULL;
	ptr = ARR_DATA_PTR(array);
	bitmap = ARR_NULLBITMAP(array);
	bitmask = 1;

	for (i = 0; i < nitems; i++)
	{
		char * val;

		if ((i % ndim) == 0)		// Add new pair element
		{
			pair = (Pair_text *)palloc(sizeof(Pair_text));
			values = lappend(values, pair);
		}

		if (bitmap && (*bitmap & bitmask) == 0)
		{
			val = NULL;
		}
		else
		{
			val = (char *) TextDatumGetCString(PointerGetDatum(ptr));
			ptr = att_addlength_pointer(ptr, typlen, ptr);
			ptr = (char *) att_align_nominal(ptr, typalign);
		}

		/* advance bitmap pointer if any */
		if (bitmap)
		{
			bitmask <<= 1;
			if (bitmask == 0x100)
			{
				bitmap++;
				bitmask = 1;
			}
		}

		// Put the value to a pair
		if ((i % ndim) == 0)
			pair->val1 = val;
		else
			pair->val2 = val;
	}

	return values;
}
