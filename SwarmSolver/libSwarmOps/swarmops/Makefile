CC=g++
CPPFLAGS :=             -Wall -fPIC -I. -I../ -I./Tools -I./Methods -I./Methods/Helpers -I./Statistics -I./RandomOps

# determine all sources and from that all targets
sources :=              $(wildcard *.c) $(wildcard */*.c)
objects=$(sources:.c=.o)

# build all and strip programs afterwards 
all: 	$(objects) libSwarmOps.so

.c.o: 
	$(CC) $(CPPFLAGS) -c $^ -o $@

libSwarmOps.so: Tools/Random.o Problems/Ackley.o Contexts/BenchmarkContext.o Problems/Benchmarks.o Tools/Bound.o Methods/DE.o Methods/DEEngine.o Tools/Denormal.o Methods/DESuite.o Methods/DETP.o Tools/Displace.o Methods/ELG.o Tools/Error.o Methods/FAE.o Statistics/FitnessTrace.o Methods/GD.o Methods/GED.o Problems/Griewank.o Methods/HC.o Tools/Init.o Methods/JDE.o Methods/LICE.o Methods/Helpers/Looper.o Methods/Helpers/LooperLog.o Methods/LUS.o Tools/Matrix.o Tools/Memory.o Methods/MESH.o Meta2OptimizeBenchmarks.o Meta2OptimizeMulti.o MetaOptimize.o MetaOptimizeBenchmarks.o MetaOptimizeMulti.o Statistics/MetaSolution.o Contexts/MethodContext.o Methods/Methods.o Methods/MOL.o Methods/Helpers/Multi.o Methods/MYG.o Optimize.o OptimizeBenchmark.o Problems/Penalized1.o Problems/Penalized2.o Methods/Helpers/Printer.o Methods/PS.o Methods/PSO.o Problems/QuarticNoise.o Problems/Rastrigin.o Statistics/Results.o Methods/RND.o Problems/Rosenbrock.o Methods/SA.o Tools/Sample.o Problems/Schwefel12.o Problems/Schwefel221.o Problems/Schwefel222.o Statistics/Solution.o Problems/Sphere.o Statistics/Statistics.o Problems/Step.o Tools/String.o Tools/Vector.o 
	$(CC) -shared $(CPPFLAGS) -o $@ ./RandomOps/Derivations.o ./RandomOps/Random.o ./RandomOps/RandomSet.o $^

#test: test.c
#	$(CC) $(CPPFLAGS) -c $@ $^

clean:
	rm -f $(objects)
