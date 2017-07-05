/*
 * solverapi_utils.c
 *
 *  Created on: Nov 27, 2012
 *      Author: laurynas
 */

#include "solverapi_utils.h"
#include "utils/memutils.h"
#include "nodes/parsenodes.h"
#include "tcop/tcopprot.h"
#include "nodes/nodeFuncs.h"
#include "utils/builtins.h"
#include "nodes/nodes.h"
#include "utils/syscache.h"
#include "catalog/namespace.h"

void scanQueryForRelations(Query *, List **);
static bool scanQueryForRelations_walker(Node *, void *);

/*
 * We call the parsing and analysis directly. Alternative less efficient implementation is to
 * to SPI_Execute and then analyze the HEAPTUPLE.
 * */
extern SL_Attribute_Desc * sl_get_query_attributes(char * sql, unsigned int * numAttrs)
{
	SL_Attribute_Desc	*result=NULL;
	MemoryContext 		 oldcontext;
	MemoryContext 		 parsecontext;
	List	   			*raw_parsetree_list;
	List       			*stmt_list;
	Query 				*query;
	ListCell   			*c;
	int					 i;

	 /* Use a new memory context to prevent leak of memory used to parse and analyze a query  */
	parsecontext = AllocSetContextCreate(CurrentMemoryContext,
	                                                                    "SolverAPI query parse context",
	                                                                    ALLOCSET_DEFAULT_MINSIZE,
	                                                                    ALLOCSET_DEFAULT_INITSIZE,
	                                                                    ALLOCSET_DEFAULT_MAXSIZE);
	oldcontext = MemoryContextSwitchTo(parsecontext);

	raw_parsetree_list = pg_parse_query(sql);

	if (raw_parsetree_list->length != 1)
		elog(ERROR, "SolverAPI: unexpected parse analysis result");

	stmt_list = pg_analyze_and_rewrite(linitial(raw_parsetree_list), sql, NULL, 0);

	if (stmt_list->length != 1)
		elog(ERROR, "SolverAPI: unexpected parse analysis result");

	query = (Query *) linitial(stmt_list);

	/* The grammar allows SELECT INTO, but we don't support that */
	if (query->utilityStmt != NULL &&
	        IsA(query->utilityStmt, CreateTableAsStmt))
	        ereport(ERROR,
	                        (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
	                         errmsg("SolverAPI: COPY (SELECT INTO) is not supported")));

	Assert(query->commandType == CMD_SELECT);
	Assert(query->utilityStmt == NULL);
	/* Prepare a target list */
	MemoryContextSwitchTo(oldcontext);
	// Count non-junk attributes
	*numAttrs = 0;
	foreach(c, query->targetList)
		if (!((TargetEntry *) lfirst(c))->resjunk) (*numAttrs)++;

	result = palloc(sizeof(SL_Attribute_Desc) * (*numAttrs));

	// When the parsing is done, build a respective column description
	i = 0;
	foreach(c, query->targetList)
	{
		TargetEntry 		* te = (TargetEntry *) lfirst(c);
		SL_Attribute_Desc   desc;

		if (te->resjunk) continue;

		desc.att_name = pstrdup(te->resname);
		desc.att_type = format_type_with_typemod(exprType((Node *) te->expr), exprTypmod((Node *) te->expr));
		desc.att_kind = SL_AttKind_Undefined;
		result[i++] = desc;
	}

	pfree(query);
	MemoryContextDelete(parsecontext);

	return result;
}


/*
 * We call the parsing and analysis directly, and retrieve all range tables
 * */
extern List * sl_get_query_rangeTables(char * sql)
{
	List			 	*result = NIL;
	MemoryContext 		 oldcontext;
	MemoryContext 		 parsecontext;
	List	   			*raw_parsetree_list;
	List       			*stmt_list;
	Query 				*query;

	 /* Use a new memory context to prevent leak of memory used to parse and analyze a query  */
	parsecontext = AllocSetContextCreate(CurrentMemoryContext,
	                                                                    "SolverAPI query parse context",
	                                                                    ALLOCSET_DEFAULT_MINSIZE,
	                                                                    ALLOCSET_DEFAULT_INITSIZE,
	                                                                    ALLOCSET_DEFAULT_MAXSIZE);
	oldcontext = MemoryContextSwitchTo(parsecontext);

	raw_parsetree_list = pg_parse_query(sql);

	if (raw_parsetree_list->length != 1)
		elog(ERROR, "SolverAPI: unexpected parse analysis result");

	stmt_list = pg_analyze_and_rewrite(linitial(raw_parsetree_list), sql, NULL, 0);

	if (stmt_list->length != 1)
		elog(ERROR, "SolverAPI: unexpected parse analysis result");

	query = (Query *) linitial(stmt_list);

	/* The grammar allows SELECT INTO, but we don't support that */
	if (query->utilityStmt != NULL &&
	        IsA(query->utilityStmt, CreateTableAsStmt))
	        ereport(ERROR,
	                        (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
	                         errmsg("SolverAPI: COPY (SELECT INTO) is not supported")));

	Assert(query->commandType == CMD_SELECT);
	Assert(query->utilityStmt == NULL);
	/* Prepare a target list */
	MemoryContextSwitchTo(oldcontext);

	/* Recursivelly analyze the query */
	scanQueryForRelations(query, &result);

	pfree(query);
	MemoryContextDelete(parsecontext);

	return result;
}


/*
 * Examine a fully-parsed query, and return all its relations).
 */
void scanQueryForRelations(Query *query, List ** relNameList)
{
	scanQueryForRelations_walker((Node *) query, (void *) relNameList);
}

static bool scanQueryForRelations_walker(Node *node, void *context)
{
	List **	relNameList = (context);

    if (node == NULL)
            return false;
    if (IsA(node, RangeTblEntry))
    {
            RangeTblEntry *rte = (RangeTblEntry *) node;

            /* As above, we need only save relation RTEs */
            if (rte->eref) {
            	*relNameList=lappend(*relNameList, rte->eref->aliasname);
            }
            return false;
    }
    if (IsA(node, Query))
    {
            /* Recurse into subselects */
            return query_tree_walker((Query *) node,
            						  scanQueryForRelations_walker,
									  context,
                                      QTW_EXAMINE_RTES);
    }
    return expression_tree_walker(node, scanQueryForRelations_walker,
                                        context);
}

