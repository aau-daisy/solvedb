/*
 * solverapi_utils.h
 *
 *  Created on: Nov 27, 2012
 *      Author: laurynas
 */

#ifndef SOLVERAPI_UTILS_H_
#define SOLVERAPI_UTILS_H_

#include "solverapi.h"

extern SL_Attribute_Desc * sl_get_query_attributes(char * sql, unsigned int * numAttrs);
extern List * sl_get_query_rangeTables(char * sql);

#endif /* SOLVERAPI_UTILS_H_ */
