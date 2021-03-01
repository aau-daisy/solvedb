// RandomOpsTest2.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include <RandomOps/Random.h>
#include <RandomOps/RandomSet.h>
#include <assert.h>

const RO_Int kSeed = 73758895;

const size_t kNumIterations = 10;

const double kGaussMean = 0;
const double kGaussDerivation = 1;

const size_t kBoolIterations = 100000;
size_t boolCount[2];

const size_t kIndexIterations = 100000;
const size_t kMaxIndex = 8;
size_t indexCount[kMaxIndex];

const size_t kRandSetSize = 8;
const size_t kSetIterations = 8;
const size_t kRandSetExclude = kRandSetSize/2;
size_t setCount[kRandSetSize];
const size_t kSetIterations2 = 10000;

void ZeroCounts(size_t *counts, size_t numCounts)
{
	size_t i;

	for (i=0; i<numCounts; i++)
	{
		counts[i] = 0;
	}
}

void ZeroIndexCounts()
{
	ZeroCounts(indexCount, kMaxIndex);
}

void ZeroBoolCounts()
{
	ZeroCounts(boolCount, 2);
}

void ZeroSetCounts()
{
	ZeroCounts(setCount, kRandSetSize);
}

void PrintCounts(size_t *counts, size_t numCounts)
{
	size_t i;

	for (i=0; i<numCounts; i++)
	{
		printf("Index: %i Count: %i\n", i, counts[i]);
	}
}

void PrintIndexCounts()
{
	PrintCounts(indexCount, kMaxIndex);
}

void PrintBoolCounts()
{
	PrintCounts(boolCount, 2);
}

void PrintSetCounts()
{
	PrintCounts(setCount, kRandSetSize);
}

int _tmain(int argc, _TCHAR* argv[])
{
	size_t i;

	// RO_Rand(); // Will cause an assertion to fail.

	RO_RandSeedClock(kSeed);

	printf("RO_RandMax()\n%i\n", RO_RandMax());

	printf("\nRO_Rand()\n");
	for (i=0; i<kNumIterations; i++)
	{
		printf("%i\n", RO_Rand());
	}

	printf("\nRO_RandUni()\n");
	for (i=0; i<kNumIterations; i++)
	{
		printf("%g\n", RO_RandUni());
	}

	printf("\nRO_RandBi()\n");
	for (i=0; i<kNumIterations; i++)
	{
		printf("%g\n", RO_RandBi());
	}

	printf("\nRO_RandBetween(-3, -1)\n");
	for (i=0; i<kNumIterations; i++)
	{
		printf("%g\n", RO_RandBetween(-3, -1));
	}

	printf("\nRO_RandBetween(-2, 2)\n");
	for (i=0; i<kNumIterations; i++)
	{
		printf("%g\n", RO_RandBetween(-2, 2));
	}

	printf("\nRO_RandBetween(3, 5)\n");
	for (i=0; i<kNumIterations; i++)
	{
		printf("%g\n", RO_RandBetween(3, 5));
	}

	printf("\nRO_RandGauss(%g, %g)\n", kGaussMean, kGaussDerivation);
	for (i=0; i<kNumIterations; i++)
	{
		printf("%g\n", RO_RandGauss(kGaussMean, kGaussDerivation));
	}

	printf("\nRO_RandBool()\n");
	ZeroBoolCounts();
	for (i=0; i<kBoolIterations; i++)
	{
		boolCount[RO_RandBool()] += 1;
	}
	PrintBoolCounts();

	printf("\nRO_RandIndex(%i)\n", kMaxIndex);
	ZeroIndexCounts();
	for (i=0; i<kIndexIterations; i++)
	{
		size_t idx = RO_RandIndex(kMaxIndex);

		indexCount[idx] += 1;
	}
	PrintIndexCounts();

	ZeroIndexCounts();
	printf("\nRO_RandIndex2(%i, ...)\n", kMaxIndex);
	for (i=0; i<kIndexIterations; i++)
	{
		size_t idx1, idx2;

		RO_RandIndex2(kMaxIndex, &idx1, &idx2);

		assert(idx1 != idx2);

		indexCount[idx1] += 1;
		indexCount[idx2] += 1;
	}
	PrintIndexCounts();

	{
		struct RO_RandSet randSet = RO_RandSetInit(kRandSetSize);

		printf("\nRO_RandSetReset()");
		printf("\nRO_RandSetDraw() with set of size %i and %i iterations\n", kRandSetSize, kSetIterations/2);
		RO_RandSetReset(&randSet);
		for (i=0; i<kSetIterations/2; i++)
		{
			printf("%i\n", RO_RandSetDraw(&randSet, &RO_RandIndex));
		}

		printf("\nRO_RandSetReset()");
		printf("\nRO_RandSetDraw() with set of size %i\n", kRandSetSize);
		RO_RandSetReset(&randSet);
		for (i=0; i<kSetIterations; i++)
		{
			printf("%i\n", RO_RandSetDraw(&randSet, &RO_RandIndex));
		}

		//RO_RandSetDraw(&randSet, &RO_RandIndex); // Assertion fails.

		printf("\nRO_RandSetResetExclude(%i)", kRandSetExclude);
		printf("\nRO_RandSetDraw() with set of size %i\n", kRandSetSize);
		RO_RandSetResetExclude(&randSet, kRandSetExclude);
		for (i=0; i<kSetIterations-1; i++)
		{
			printf("%i\n", RO_RandSetDraw(&randSet, &RO_RandIndex));
		}

		//RO_RandSetDraw(&randSet, &RO_RandIndex); // Assertion fails.

		ZeroSetCounts();
		printf("\nRO_RandSetDraw() with set of size %i\n", kRandSetSize);
		for (i=0; i<kSetIterations2; i++)
		{
			size_t j;

			RO_RandSetReset(&randSet);

			for (j=0; j<kRandSetSize; j++)
			{
				size_t idx = RO_RandSetDraw(&randSet, &RO_RandIndex);

				setCount[idx] += 1;
			}
		}
		PrintSetCounts();

		RO_RandSetFree(&randSet);
	}

	return 0;
}

