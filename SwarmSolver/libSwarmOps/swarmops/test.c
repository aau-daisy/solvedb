#include <stdio.h>



#include "OptimizeBenchmark.h"			/* Convenient function for optimizing benchmark problems. */
#include "RandomOps/Random.h"					/* Pseudo-random number generator, for seeding. */

#include "Methods/Methods.h"			/* Optimization method ID-handles. */
#include "Problems/Benchmarks.h"		/* Benchmark problem ID-handles. */

#include <stdlib.h>
#include <time.h>

/* ---------------------------------------------------------------- */

const size_t	kMethodId = SO_kMethodDE;		/* Optimization method. */
const size_t	kNumRuns = 50;					/* Number of optimization runs. */
const size_t	kDimFactor = 200;				/* Iterations per run = dim * kDimFactor */
const int		kDisplaceOptimum = 0;			/* Displace global optimum. */
const int		kInitFullRange = 0;				/* Initialize in full search-space (easier to optimize). */

/* ---------------------------------------------------------------- */

/* Helper function for actually doing optimization on a problem.
 * Prints the results to std.out. */
void DoBenchmark(const size_t kMethodId, const size_t kProblemId, SO_TDim kDim)
{
	const size_t kNumIterations = kDimFactor*kDim;

	const char* fitnessTraceName = 0; /* "FitnessTrace-Sphere100-LUS.txt"; */

	struct SO_Statistics stat = SO_OptimizeBenchmark(kMethodId, kNumRuns, kNumIterations, 0, kProblemId, kDim, kDisplaceOptimum, kInitFullRange, fitnessTraceName);

	printf("%g (%g)", stat.fitnessAvg, stat.fitnessStdDev);
}

/* ---------------------------------------------------------------- */

/* Helper function for doing optimization on a problem with different
 * dimensionalities. */
void Benchmark(const size_t kMethodId, const size_t kProblemId)
{
	printf("%s & ", SO_kBenchmarkName[kProblemId]);

	DoBenchmark(kMethodId, kProblemId, 20);

	printf(" & ");

	DoBenchmark(kMethodId, kProblemId, 50);

	printf(" & ");

	DoBenchmark(kMethodId, kProblemId, 100);

	printf(" \\\\\n");
}

int main ()
{
	/* Timing variables. */
	clock_t t1, t2;

	/* Display optimization settings to std.out. */
	printf("Benchmark-tests in various dimensions.\n");
	printf("Method: %s\n", SO_kMethodName[kMethodId]);
	printf("Using following parameters:\n");
	SO_PrintParameters(kMethodId, SO_kMethodDefaultParameters[kMethodId]);
	printf("Number of runs per problem: %i\n", kNumRuns);
	printf("Dim-factor: %i\n", kDimFactor);
	printf("Displace global optimum: %s\n", (kDisplaceOptimum) ? ("Yes") : ("No"));
	printf("Init. in full search-space: %s\n", (kInitFullRange) ? ("Yes") : ("No"));
	printf("\n");
	printf("Problem & 20 dim. & 50 dim. & 100 dim. \\\\\n");

	/* Seed the pseudo-random number generator. */
	RO_RandSeedClock(9385839);

	/* Timer start. */
	t1 = clock();

	/* Perform optimizations on different benchmark problems.
	 * Display the results during optimization. */
	Benchmark(kMethodId, SO_kBenchmarkSphere);
	Benchmark(kMethodId, SO_kBenchmarkGriewank);
	Benchmark(kMethodId, SO_kBenchmarkRastrigin);
	Benchmark(kMethodId, SO_kBenchmarkAckley);
	Benchmark(kMethodId, SO_kBenchmarkRosenbrock);

	/* Timing end. */
	t2 = clock();

	/* Display time-usage to std.out. */
	printf("\nTime usage: %g seconds\n", (double)(t2 - t1) / CLOCKS_PER_SEC);

	return 0;
}