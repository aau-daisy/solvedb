/* ================================================================
 *
 *	RandomOps - Pseudo-Random Number Generator For C.
 *	Copyright (C) 2003-2008 Magnus Erik Hvass Pedersen.
 *	Published under the GNU Lesser General Public License.
 *	Please see the file license.txt for license details.
 *	RandomOps on the internet: http://www.Hvass-Labs.org/
 *
 *	Random Header
 *
 *	These are the basic functions used for the PRNG.
 *	A user first has to call one of the seed-functions
 *	before starting to draw random numbers. A user
 *	will then use the functions in Derivations.h to
 *	draw the actual random numbers.
 *
 * ================================================================ */

#ifndef RO_RANDOM_H
#define RO_RANDOM_H

#include <RandomOps/Derivations.h>

#ifdef  __cplusplus
extern "C" {
#endif

	/* ---------------------------------------------------------------- */

	/* The datatype for the output of the PRNG.
	 * It is 'long' for the Rand2 generator. */
	typedef long RO_Int;

	/* ---------------------------------------------------------------- */

	/* Set the seed for the random generator. Must be called first. */
	void RO_RandSeed(RO_Int seed);

	/* Set the seed from the system clock, if unavailable use supplied seed. */
	void RO_RandSeedClock(RO_Int seed);

	/* ---------------------------------------------------------------- */

	/* Return the maximum random integer. */
	RO_Int RO_RandMax(void);

	/* Draw a number from {1, .., RO_RandMax()} with uniform probability.
	 * Notice that a value of zero can NOT be returned. */
	RO_Int RO_Rand(void);

	/*----------------------------------------------------------------*/

#ifdef  __cplusplus
} /* extern "C" end */
#endif

#endif /* #ifndef RO_RANDOM_H */

/* ================================================================ */
