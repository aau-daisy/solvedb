/* ================================================================
 *
 *	RandomOps - Pseudo-Random Number Generator For C.
 *	Copyright (C) 2003-2008 Magnus Erik Hvass Pedersen.
 *	Published under the GNU Lesser General Public License.
 *	Please see the file license.txt for license details.
 *	RandomOps on the internet: http://www.Hvass-Labs.org/
 *
 *	Derivations Implementation
 *
 *	Please see header-file for description.
 *
 * ================================================================ */

#include <RandomOps/Random.h>
#include <math.h>
#include <assert.h>

/* ---------------------------------------------------------------- */

#define true 1
#define false 0

/* ---------------------------------------------------------------- */

double			RO_gGaussian;					/* Next Gaussian random number. */
char			RO_gGaussReady = false;			/* Does RO_gGaussian hold a value? */

/* ---------------------------------------------------------------- */

/* We MUST use division! Do NOT use bit-manipulation because
 * low-order bits of Rand() are not that random!
 * Furthermore assumes that RO_Rand() is in {1, .., RO_RandMax()},
 * if this is not the case, e.g. if RO_Rand() can return zero, then
 * RO_Rand() must be altered, e.g. by adding one to its return value.
 * Also note that as RO_Rand() may return RO_RandMax() and the
 * output of this function is expected to be less than 1, then
 * RO_Rand() must be divided by RO_RandMax()+1. */

double RO_RandUni()
{
	const double kMaxPlusOne = (double) RO_RandMax() + 1;
	double value = (double) RO_Rand() / kMaxPlusOne;

	assert( ((double) RO_RandMax() / kMaxPlusOne) < 1);

	assert(value>0 && value<1);

	return value;
}

/* ---------------------------------------------------------------- */

/* Assume RandUni cannot generate an exact value of one,
 * otherwise this must have been taken into account to ensure
 * uniform probability of choosing the different indices. 
 * Furthermore it is assumed that casting from double to
 * integer rounds down. */

size_t RO_RandIndex(size_t n)
{
	double r = RO_RandUni();
	size_t value = (size_t) (r * n);

	assert(n>=1);
	assert(r>0 && r<1);
	assert(value>=0 && value<=n-1);

	return value;
}

/* ---------------------------------------------------------------- */

/* Sacrifice a little precision and reuse RandUni(). */

double RO_RandBi()
{
	double value = 2*RO_RandUni() - 1;

	assert(value>-1 && value<1);

	return value;
}

/* ---------------------------------------------------------------- */

double RO_RandBetween(const double lower, const double upper)
{
	double value;

	assert(upper >= lower);
	
	value = RO_RandUni()*(upper-lower) + lower;

	/* Range must be inclusive due to rounding errors.
	 * If you experience errors you may wish to remove
	 * this assertion, or possibly bound the values. */
	assert(value>=lower && value<=upper);

	return value;
}

/* ---------------------------------------------------------------- */

double RO_RandGauss(double mean, double deviation)
{
	double value;

	if (RO_gGaussReady)
	{
		value = RO_gGaussian;
		RO_gGaussReady = false;
	}
	else
	{
		double v1, v2, rsq, fac;

		/* Pick two uniform numbers in the square (-1,1) x (-1,1). See if the
		 * numbers are inside the unit circle, and if they are not, try again.
		 * Probability of the loop succeeding in a single iteration is pi/4, or
		 * about 0.7854, since we sample uniformly from a square of size 4, and
		 * succesful points occupy the inside of the unit circle, whose area is pi,
		 * or about 3.14.
		 * Probability of success in two iterations is therefore 0.954, in three
		 * iterations it is about 0.990, and the probability of success in
		 * four successive iterations is approximately 0.998, etc. -- provided there
		 * is no correlation between calls to RO_RandBi(). */
		do
		{
			v1 = RO_RandBi();
			v2 = RO_RandBi();
			rsq = v1*v1 + v2*v2;
		}
		while (rsq >= 1.0 || rsq == 0.0);

		fac = sqrt(-2.0 * log(rsq)/rsq);

		/* Now make the Box-Muller transformation to get two normal deviates.
		 * Return one and save the other for next time. */
		RO_gGaussian = v1*fac;
		RO_gGaussReady = true;

		value = v2 * fac;
	}

	return deviation*value + mean;
}

/* ---------------------------------------------------------------- */

int RO_RandBool()
{
	return (RO_Rand() < (RO_RandMax()/2));
}

/* ---------------------------------------------------------------- */

void RO_RandIndex2(size_t n, size_t *i1, size_t *i2)
{
	size_t R1, R2;

	assert(n>=2);

	R1 = RO_RandIndex(n);
	R2 = RO_RandIndex(n-1);

	*i1 = R1;
	*i2 = (R1+R2+1) % n;

	assert(*i1 != *i2);
}

/* ---------------------------------------------------------------- */
