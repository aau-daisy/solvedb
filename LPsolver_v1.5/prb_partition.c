/*
 * prb_partition.c
 *
 *  Created on: Aug 31, 2014
 *      Author: laurynas
 */

#include "prb_partition.h"
#include "utils/memutils.h"

/* Disjoint-set data structures  */

typedef struct par_node_t {
	 int				  varNr;
     struct par_node_t 	* parent;
     int 				  rank;
} par_node;

/* Partition hash entry */
typedef struct par_hash_entry {
	par_node		* key;
	LPproblem		* prob;
} par_hash_entry;

//  Create a new partition containing a single given element.
par_node*	par_makeSet(int varNr);
//  Merge two partitions into a single partition.
void 		par_union  (par_node* node1, par_node* node2);
//  Figure out which partition a given element is in.
par_node* 	par_find   (par_node* node);

/* Disjoint-set implementation */

// Create a new partition containing a single given element.
inline par_node* par_makeSet(int varNr) {
	par_node * node = palloc(sizeof(par_node));
	node->varNr = varNr;
	node->parent = NULL;
	node->rank = 0;
	return node;
}

//  Merge two partitions into a single partition.
inline void par_union(par_node* node1, par_node* node2) {
	if (node1->rank > node2->rank) {
		node2->parent = node1;
	} else if (node2->rank > node1->rank) {
		node1->parent = node2;
	} else { /* they are equal */
		node2->parent = node1;
		node1->rank++;
	}
}

// Figure out which partition a given element is in.
inline par_node * par_find(par_node * node) {
	par_node* temp;
	/* Find the root */
	par_node* root = node;
	while (root->parent != NULL) {
		root = root->parent;
	}
	/* Update the parent pointers */
	while (node->parent != NULL) {
		temp = node->parent;
		node->parent = root;
		node = temp;
	}
	return root;
}

/* LP problem partitioning. Results a list of LPproblem */
extern List * partitionLPproblem(LPproblem * main_prb, int partition_size)
{
	MemoryContext	old_context, part_context;
	HASHCTL		    ctl;
	HTAB 		    * hash; /* A hash mapping a partition to the LP problem */
	List			* result = NIL;
	par_node		** nodes;
	LPproblem		* last_prob;
	ListCell		*c;
	int				i;
	int				grp_size;

	part_context = AllocSetContextCreate(CurrentMemoryContext,
											   "Problem partitioning context",
											   ALLOCSET_DEFAULT_MINSIZE,
											   ALLOCSET_DEFAULT_INITSIZE,
											   ALLOCSET_DEFAULT_MAXSIZE);

	old_context = MemoryContextSwitchTo(part_context);

	/* Allocate nodes for each variable */
	nodes			= palloc0(main_prb->numVariables * sizeof(par_node *));

	/* Build disjoint sets of variable partitions */
	foreach(c, main_prb->ctrs)
	{
		Sl_Ctr		  * ctr = lfirst(c);
		pg_LPfunction * p = DatumGetLPfunction(sl_ctr_get_x_val(ctr));
		int			  vnr1, vnr2;
		par_node	  *p1, *p2;

		if (p->numTerms <= 0) continue;	/* Ignore empty expressions*/

		vnr1 = p->term[0].varNr;
		Assert(vnr1>=0 && vnr1 < main_prb->numVariables);

		/* Add the fist node and find the partition */
		if (nodes[vnr1] == NULL)
			nodes[vnr1] = par_makeSet(vnr1);

		/* Add and link the subsequent nodes */
		for (i=1; i < p->numTerms; i++)
		{
			vnr2 = p->term[i].varNr;

			if (nodes[vnr2] == NULL)
				nodes[vnr2] = par_makeSet(vnr2);

			p1 = par_find(nodes[vnr1]);
			p2 = par_find(nodes[vnr2]);

			/* Link the nodes, if variables belong to different partitions */
			if (p1 != p2)
				par_union(p1, p2);
		}
	}

	/* Assign partitions to variables, group problems, initializes sub-problems, and build a partition hash*/
	result = NIL;
	last_prob = NULL;
	grp_size = 0;
	MemSet(&ctl, 0, sizeof(HASHCTL));
	ctl.keysize = sizeof(par_node *);
	ctl.entrysize = sizeof(par_hash_entry);
	ctl.hash = tag_hash;
	ctl.hcxt = CurrentMemoryContext;
	hash = hash_create("LP problem partition lookup hash", 1024,  &ctl, HASH_ELEM | HASH_FUNCTION | HASH_CONTEXT);

	MemoryContextSwitchTo(old_context);

	for (i = 0; i < main_prb->numVariables; i++)
		if (nodes[i] != NULL) {
			par_hash_entry * hash_entry;
			bool found;

			/* Assign the partition number to each variable */
			nodes[i] = par_find(nodes[i]);

			/* Creates LPproblem for each partition */
			hash_entry = hash_search(hash, &(nodes[i]), HASH_ENTER, &found);
			if (!found)
			{
				/* Check if this should be assigned to the previous partition, for grouping */
				if (grp_size > 0 && grp_size < partition_size) {
					hash_entry->prob = last_prob; 	/* Assign to the previous problem */
					grp_size = (grp_size + 1) % partition_size;
				} else {
					/* Initialize the problem */
					hash_entry->prob = palloc(sizeof(LPproblem)); /* Key is already inserted */
					// hash_entry->prob->probType = main_prb->probType;
					hash_entry->prob->objDirection = main_prb->objDirection;
					hash_entry->prob->numVariables = 0; // Initially the variable count is 1
					hash_entry->prob->varTypes = NULL; /* To be assigned later */
					hash_entry->prob->ctrs = NIL; /* This to be built */
					hash_entry->prob->obj = NULL; /* This to be built */
					result = lappend(result, hash_entry->prob);
					/* Reset the group size and remember the last partition */
					grp_size = 1;
					last_prob = hash_entry->prob;
				}
			}

			/* Increment a variable count */
			hash_entry->prob->numVariables++;
		}

	if (list_length(result) == 1) /* When no partitioning is possible, just return the initial problem*/
		result = list_make1(main_prb);
	else
	{

		/* Build constraints */
		foreach(c, main_prb->ctrs)
		{
			Sl_Ctr          * ctr = lfirst(c);
			pg_LPfunction   * p = DatumGetLPfunction(sl_ctr_get_x_val(ctr));
			par_hash_entry  * hash_entry;
			bool found;

			if (p->numTerms <= 0)
				continue; /* Ignore empty expressions*/

			/* Searches for an associated problem */
			hash_entry = hash_search(hash, &(nodes[p->term[0].varNr]),
												HASH_FIND, &found);

			Assert(hash_entry != NULL && hash_entry->prob != NULL && found);

			/* Adding constraints */
			hash_entry->prob->ctrs = lappend(hash_entry->prob->ctrs, ctr);
		}

		/* Build objective functions */
		if (main_prb->obj != NULL)
			for (i=0; i < main_prb->obj->numTerms; i++)
			{
				par_hash_entry  * hash_entry;
				LPproblem 		* prob;
				bool			found;

				/* Searches for an associated problem */
				hash_entry = hash_search(hash, &(nodes[main_prb->obj->term[i].varNr]),
												HASH_FIND, &found);

				if (!found)
					ereport(ERROR,
						   (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
							errmsg ("SolverLP: Unbound variable found in an objective function. A solution is infeasible, found by the problem partitioner."),
							errdetail("Make sure the objective function has no unbound variables")));

				Assert(hash_entry!=NULL && hash_entry->prob != NULL);

				prob = hash_entry->prob;

				if (prob->obj == NULL)
				{
					/* Create empty objective function - allocate more memory than it might need */
					prob->obj = palloc0(LPfunction_SIZE(prob->numVariables));

					prob->obj->factor0 = 0;
					prob->obj->numTerms = 0;
				}

				prob->obj->term[prob->obj->numTerms] = main_prb->obj->term[i];
				prob->obj->numTerms++;
			}

		/* Make final corrections to sub-problems */
		foreach(c, result)
		{
			LPproblem * prob = lfirst(c);

			/* Fix a number of variables and variable types */
			prob->numVariables = main_prb->numVariables;
			prob->varTypes     = main_prb->varTypes;

			/* Fix the objective function allocations */
			if (prob->obj != NULL)
				prob->obj = repalloc(prob->obj, LPfunction_SIZE(prob->obj->numTerms));
		}
	}

	// Clean-up
	hash_destroy(hash);
	MemoryContextDelete(part_context);

	return result;
}
