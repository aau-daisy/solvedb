/*
 * low_level_utils.c
 *
 *  Created on: Nov 19, 2012
 *      Author: laurynas
 */
#include "low_level_utils.h"
#include "utils/memutils.h"
#include "nodes/parsenodes.h"
#include "tcop/tcopprot.h"
#include "nodes/nodeFuncs.h"
#include "utils/builtins.h"
#include "nodes/nodes.h"
#include "utils/syscache.h"
#include "catalog/namespace.h"
#include "utils/lsyscache.h"
#include "access/tupmacs.h"


extern Oid sl_get_enumOidFromLabel(const char *typname, const char *label)
{
	Oid         enumtypoid;

	enumtypoid = TypenameGetTypid(typname);
	Assert(OidIsValid(enumtypoid));

	return DirectFunctionCall2(enum_in, CStringGetDatum(label), DatumGetObjectId(enumtypoid));
}

extern char * sl_get_enumLabelFromOid(const Oid oid)
{
	return DatumGetCString(DirectFunctionCall1(enum_out, ObjectIdGetDatum(oid)));
}

/* TODO: replace this with the "deconstruct_array". */
extern List *
get_datum_array_contents(ArrayType *array)
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

	// Assert(ARR_ELEMTYPE(array) == RECORDOID);

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
			values = lappend(values, (void *)PointerGetDatum(ptr));
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
