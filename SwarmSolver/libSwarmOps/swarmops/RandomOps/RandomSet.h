/* ================================================================
 *
 *	RandomOps - Pseudo-Random Number Generator For C.
 *	Copyright (C) 2003-2008 Magnus Erik Hvass Pedersen.
 *	Published under the GNU Lesser General Public License.
 *	Please see the file license.txt for license details.
 *	RandomOps on the internet: http://www.Hvass-Labs.org/
 *
 *	RandomSet Header
 *
 *	Create a set of numbers {0, .., size-1} which can be
 *	drawn at random. It can be used to draw a number of
 *	mutually exclusive indices to be used in further
 *	lookup in another data-structure. Note that this
 *	does not require the PRNG from Random.h but you
 *	can use your own PRNG as long as you provide a
 *	function similar to RO_RandIndex().
 *
 * ================================================================ */

#ifndef RO_RANDOMSET_H
#define RO_RANDOMSET_H

#include <RandomOps/Random.h>

#ifdef  __cplusplus
extern "C" {
#endif

	/*----------------------------------------------------------------*/

	/* The internal data-structure used for storing the set of numbers. */
	struct RO_RandSet
	{
		size_t* elms;
		size_t  numUsed;
		size_t  size;
	};

	/*----------------------------------------------------------------*/

	/* Call this to create a new set of numbers of the given size.
	 * Note that one of the Reset-functions must be called before
	 * RO_RandSetDraw() can be called. */
	struct RO_RandSet RO_RandSetInit(size_t size);

	/* Free the data-structure. */
	void RO_RandSetFree(struct RO_RandSet *s);

	/* Draw a number at random from the set of remaining numbers.
	 * The second parameter is typically a pointer to the function
	 * RO_RandIndex() from Derivations.h but may also be another
	 * similar function of your own choice.
	 * One of the Reset-functions must be called before this. */
	size_t RO_RandSetDraw(struct RO_RandSet *s, RO_FRandIndex fRandIndex);

	/* Reset the set of numbers. */
	void RO_RandSetReset(struct RO_RandSet *s);

	/* Reset the set of numbers, and exclude a certain number. */
	void RO_RandSetResetExclude(struct RO_RandSet *s, size_t index);

	/*----------------------------------------------------------------*/

#ifdef  __cplusplus
} /* extern "C" end */
#endif

#endif /* #ifndef RO_RANDOMSET_H */

/* ================================================================ */
