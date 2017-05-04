# Build GLPK for MMIX with GCC cross-compiler

ifndef subdir
subdir = .
endif

swdir = $(subdir)/SwarmOps

swOBJs = \
$(swdir)/Tools/Random.o \
$(swdir)/Problems/Ackley.o \
$(swdir)/Contexts/BenchmarkContext.o \
$(swdir)/Problems/Benchmarks.o \
$(swdir)/Tools/Bound.o \
$(swdir)/Methods/DE.o \
$(swdir)/Methods/DEEngine.o \
$(swdir)/Tools/Denormal.o \
$(swdir)/Methods/DESuite.o \
$(swdir)/Methods/DETP.o \
$(swdir)/Tools/Displace.o \
$(swdir)/Methods/ELG.o \
$(swdir)/Tools/Error.o \
$(swdir)/Methods/FAE.o \
$(swdir)/Statistics/FitnessTrace.o \
$(swdir)/Methods/GD.o \
$(swdir)/Methods/GED.o \
$(swdir)/Problems/Griewank.o \
$(swdir)/Methods/HC.o \
$(swdir)/Tools/Init.o \
$(swdir)/Methods/JDE.o \
$(swdir)/Methods/LICE.o \
$(swdir)/Methods/Helpers/Looper.o \
$(swdir)/Methods/Helpers/LooperLog.o \
$(swdir)/Methods/LUS.o \
$(swdir)/Tools/Matrix.o \
$(swdir)/Tools/Memory.o \
$(swdir)/Methods/MESH.o \
$(swdir)/Meta2OptimizeBenchmarks.o \
$(swdir)/Meta2OptimizeMulti.o \
$(swdir)/MetaOptimize.o \
$(swdir)/MetaOptimizeBenchmarks.o \
$(swdir)/MetaOptimizeMulti.o \
$(swdir)/Statistics/MetaSolution.o \
$(swdir)/Contexts/MethodContext.o \
$(swdir)/Methods/Methods.o \
$(swdir)/Methods/MOL.o \
$(swdir)/Methods/Helpers/Multi.o \
$(swdir)/Methods/MYG.o \
$(swdir)/Optimize.o \
$(swdir)/OptimizeBenchmark.o \
$(swdir)/Problems/Penalized1.o \
$(swdir)/Problems/Penalized2.o \
$(swdir)/Methods/Helpers/Printer.o \
$(swdir)/Methods/PS.o \
$(swdir)/Methods/PSO.o \
$(swdir)/Problems/QuarticNoise.o \
$(swdir)/Problems/Rastrigin.o \
$(swdir)/Statistics/Results.o \
$(swdir)/Methods/RND.o \
$(swdir)/Problems/Rosenbrock.o \
$(swdir)/Methods/SA.o \
$(swdir)/Tools/Sample.o \
$(swdir)/Problems/Schwefel12.o \
$(swdir)/Problems/Schwefel221.o \
$(swdir)/Problems/Schwefel222.o \
$(swdir)/Statistics/Solution.o \
$(swdir)/Problems/Sphere.o \
$(swdir)/Statistics/Statistics.o \
$(swdir)/Problems/Step.o \
$(swdir)/Tools/String.o \
$(swdir)/Tools/Vector.o 

rodir = $(swdir)/RandomOps
roOBJs = \
$(rodir)/Derivations.o \
$(rodir)/Random.o \
$(rodir)/RandomSet.o

allswObjs = $(swOBJs) \
	    $(roOBJs) \
	    $(subdir)/patches_global.o \
	    $(subdir)/sw_log.o \
    	    $(subdir)/libSwarmOps.o

SW_COMPILE = g++ $(CPPFLAGS) -I$(swdir)/ -I$(swdir)/Tools -I$(swdir)/Methods -I$(swdir)/Methods/Helpers -I$(swdir)/Statistics -I$(swdir)/RandomOps -fexceptions

libSwarmOps.so: $(allswObjs)
	$(SW_COMPILE) -shared -o $@ $^
	
$(allswObjs): 
	$(SW_COMPILE) -fPIC -O2 -include $(subdir)/patches_global.h -c $(@:.o=.c) -o $@
# -g -O0 -fPIC -O2 
#-Wl,-soname,libSwarmOps.1

#libsw.a: $(swOBJs)
#	ar  rcs $@ $^

clean_sw:
	rm -f libSwarmOps.so
	rm -f $(swOBJs)

EXTRA_CLEAN=$(allswObjs)
.DEFAULT_GOAL := libsw.a