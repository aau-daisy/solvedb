/* ================================================================
 *
 *	RandomOps - Pseudo-Random Number Generator For C.
 *	Copyright (C) 2003-2008 Magnus Erik Hvass Pedersen.
 *	Published under the GNU Lesser General Public License.
 *	Please see the file license.txt for license details.
 *	RandomOps on the internet: http://www.Hvass-Labs.org/
 *
 *	RandomSet Implementation
 *
 *	The overall idea is to store an array of indices, and keep
 *	track of how many elements remain in the array so they
 *	can be drawn at random using the RO_RandIndex() function or
 *	or similar. Once an element has been removed from the array,
 *	the last element is swapped into its place and the arraysize
 *	is decreased by one. This causes the drawing to be an O(1)
 *	operation. The initialization though, does require O(n), where
 *	n is the number of elements in the set.
 *
 * ================================================================ */

#include <RandomOps/Random.h>
#include <RandomOps/RandomSet.h>
#include <stdlib.h>
#include <assert.h>

/* ---------------------------------------------------------------- */

struct RO_RandSet RO_RandSetInit(size_t size)
{
	struct RO_RandSet s;

	/* Allocate array and initialize struct. */
	s.elms = (size_t*) malloc(sizeof(size_t)*size);
	s.size = size;
	s.numUsed = 0;

	assert(s.elms);

	return s;
}

/* ---------------------------------------------------------------- */

void RO_RandSetFree(struct RO_RandSet *s)
{
	assert(s);
	free(s->elms);
}

/* ---------------------------------------------------------------- */

void RO_RandSetSwap(struct RO_RandSet *s, size_t i, size_t j)
{
	size_t temp = s->elms[i];
	s->elms[i] = s->elms[j];
	s->elms[j] = temp;
}

/* ---------------------------------------------------------------- */

void RO_RandSetRemove(struct RO_RandSet *s, size_t index)
{
	/* Various assumptions. */
	assert(s && s->elms);
	assert(s->numUsed>=1);
	assert(index>=0 && index<s->numUsed);

	/* Decrease the number of elements in the set. */
	s->numUsed--;

	/* Switch element to be removed with the back of the array. */
	RO_RandSetSwap(s, index, s->numUsed);
}

/* ---------------------------------------------------------------- */

size_t RO_RandSetDraw(struct RO_RandSet *s, RO_FRandIndex fRandIndex)
{
	/* Variables to be used. */
	size_t index;
	size_t retVal;

	/* Various assumptions. */
	assert(s && s->elms);
	assert(s->numUsed>0);

	/* Get random index from remainder of set. */
	index = fRandIndex(s->numUsed);

	/* Retrieve the element at that position. */
	retVal = s->elms[index];

	/* Remove that element from the set. */
	RO_RandSetRemove(s, index);

	return retVal;
}

/* ---------------------------------------------------------------- */

void RO_RandSetReset(struct RO_RandSet *s)
{
	size_t i;

	assert(s && s->elms);

	/* Reset index-variable. */
	s->numUsed = s->size;

	/* Initialize array. */
	for (i=0; i<s->size; i++)
	{
		s->elms[i] = i;
	}
}

/* ---------------------------------------------------------------- */

void RO_RandSetResetExclude(struct RO_RandSet *s, size_t index)
{
	assert(s && s->elms);
	assert(index>=0 && index<s->size);

	RO_RandSetReset(s);
	RO_RandSetRemove(s, index);
}

/* ---------------------------------------------------------------- */
