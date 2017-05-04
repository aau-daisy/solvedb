# libglpk dependencies 
subdir = glpk
include $(subdir)/Makefile

# libPgCbc dependencies
include pgCbc/libPgCbc.mk

PG_CPPFLAGS := -I$(glpkdir)/src -I../SolverAPI/  -I$(cbcDIR)

MODULE_big = solverlp
OBJS = solverlp.o lp_function.o prb_partition.o utils.o libglpk.a
SHLIB_LINK = ../SolverAPI/libsolverapi.a -L. -lPgCbc
SHLIB_PREREQS = libPgCbc.so

MODULES = libPgCbc
EXTENSION = solverlp
DATA = solverlp--1.5.sql

REGRESS = lpsolver

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

.DEFAULT_GOAL := all
#EXTRA_CLEAN=$(glpkOBJs) $(cbcOBJS)
EXTRA_CLEAN=$(cbcOBJS)
