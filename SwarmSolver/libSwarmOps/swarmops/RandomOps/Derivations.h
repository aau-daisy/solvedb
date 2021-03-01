/* ================================================================
 *
 *	RandomOps - Pseudo-Random Number Generator For C.
 *	Copyright (C) 2003-2008 Magnus Erik Hvass Pedersen.
 *	Published under the GNU Lesser General Public License.
 *	Please see the file license.txt for license details.
 *	RandomOps on the internet: http://www.Hvass-Labs.org/
 *
 *	Derivations Header
 *
 *	These are functions the user will typically want to call.
 *	They use the actual PRNG implementation in Random.h
 *
 * ================================================================ */

#ifndef RO_DERIVATIONS_H
#define RO_DERIVATIONS_H

#include <stddef.h>

#ifdef  __cplusplus
extern "C" {
#endif

	/* ---------------------------------------------------------------- */

	/* Return a uniform random number in the exclusive range (0,1) */
	double RO_RandUni();

	/* Return a uniform random number in the exclusive range (-1,1) */
	double RO_RandBi();

	/* Return a uniform random number in the range (lower, upper)
	 * Due to rounding errors, the endpoints may be returned. */
	double RO_RandBetween(const double lower, const double upper);

	/* Return a Gaussian (or normal) distributed random number. */
	double RO_RandGauss(double mean, double deviation);

	/* Return a random number from {0, .., n-1} with uniform probability. */
	size_t RO_RandIndex(size_t n);

	/* Return two distinct numbers from {0, .., n-1} with equal probability. */
	void RO_RandIndex2(size_t n, size_t *i1, size_t *i2);

	/* Return a random boolean with equal probability of being true or false. */
	int RO_RandBool();

	/*----------------------------------------------------------------*/

	/* Function-pointer-type matching RO_RandIndex() above. */
	typedef size_t (*RO_FRandIndex) (size_t n);

	/* ---------------------------------------------------------------- */

#ifdef  __cplusplus
} /* extern "C" end */
#endif

#endif /* #ifndef RO_DERIVATIONS_H */

/* ================================================================ */
