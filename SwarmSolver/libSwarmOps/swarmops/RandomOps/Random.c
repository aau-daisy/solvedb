/* ================================================================
 *
 *	RandomOps - Pseudo-Random Number Generator For C.
 *	Copyright (C) 2003-2008 Magnus Erik Hvass Pedersen.
 *	Published under the GNU Lesser General Public License.
 *	Please see the file license.txt for license details.
 *	RandomOps on the internet: http://www.Hvass-Labs.org/
 *
 *	Random Implementation
 *
 *	This implements the actual PRNG.
 *	It is based on the Rand2 generator from the book:
 *	'Numerical Recipes in C' chapter 7.1 and is originally
 *	due to L'Ecuyer with Bays-Durham shuffle and added safeguards.
 *	It has a long period, greater than 2 * 10^18.
 *
 * ================================================================ */

#include <RandomOps/Random.h>
#include <time.h>
#include <assert.h>

/* ---------------------------------------------------------------- */

#define IM0		2147483563
#define IM1		2147483399
#define IA0		40014
#define IA1		40692
#define IQ0		53668
#define IQ1		52774
#define IR0		12211
#define IR1		3791
#define NTAB	32
#define IMM		(IM0-1)
#define NDIV	(1 + IMM/NTAB)
#define WARMUP	(1024+8)
#define WARMUP2	(200)

/* ---------------------------------------------------------------- */

const RO_Int IM[2] = {IM0, IM1};
const RO_Int IA[2] = {IA0, IA1};
const RO_Int IQ[2] = {IQ0, IQ1};
const RO_Int IR[2] = {IR0, IR1};

/* ---------------------------------------------------------------- */

RO_Int idum[2] = {0, 0};
RO_Int iy = 0;
RO_Int iv[NTAB];

int isReady = 0;			/* Is PRNG ready for use? */

/* ---------------------------------------------------------------- */

/* Compute idum=(IA*idum) % IM without over-flows by Schrage's method. */
RO_Int RO_DoRand(int i)
{
	RO_Int k;

	assert(i==0 || i == 1);

	k = idum[i]/IQ[i];

	idum[i] = IA[i] * (idum[i] - k * IQ[i]) - IR[i]*k;

	if (idum[i] < 0)
	{
		idum[i] += IM[i];
	}

	return idum[i];
}

/* ---------------------------------------------------------------- */

RO_Int RO_CorrectSeed(RO_Int seed)
{
	/* Ensure seed>0 */
	if (seed == 0)
	{
		seed = 1;
	}
	else if (seed < 0)
	{
		seed = -seed;
	}

	return seed;
}

/* ---------------------------------------------------------------- */

void RO_RandSeedClock(RO_Int seed)
{
	time_t t = time(0);

	seed = RO_CorrectSeed(seed);

	if (t != -1)
	{
		RO_RandSeed( (RO_Int) (t % RO_RandMax()) );
	}
	else
	{
		RO_RandSeed(seed);
	}
}

/* ---------------------------------------------------------------- */

void RO_RandSeed(RO_Int seed)
{
	int j;

	seed = RO_CorrectSeed(seed);

	idum[0] = idum[1] = seed;

	/* Perform initial warm-ups. */
	for (j=0; j<WARMUP; j++)
	{
		RO_DoRand(0);
	}

	for (j=NTAB-1;j>=0;j--)
	{
		iv[j] = RO_DoRand(0);
	}

	iy = iv[0];

	/* PRNG is now ready for use. */
	isReady = 1;

	/* Perform additional warm-ups */
	for (j=0; j<WARMUP2; j++)
	{
		RO_Rand();
	}
}

/* ---------------------------------------------------------------- */

RO_Int RO_Rand(void)
{
	assert(isReady);

	RO_DoRand(0);
	RO_DoRand(1);

	{
		int j=iy/NDIV;								/* Will be in the range 0..NTAB-1. */

		assert(j>=0 && j<NTAB);

		iy = iv[j]-idum[1];							/* Idum is shuffled, idum and idum2 are */
		iv[j] = idum[0];							/* combined to generate output. */

		if (iy < 1)
		{
			iy += IMM;
		}
	}

	assert(iy>0 && iy<=RO_RandMax());

	return iy;
}

/* ---------------------------------------------------------------- */

RO_Int RO_RandMax(void)
{
	return IM0-1;
}

/* ---------------------------------------------------------------- */
