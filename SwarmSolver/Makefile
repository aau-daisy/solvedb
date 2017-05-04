# libglpk dependencies 
subdir = libSwarmOps
include $(subdir)/swarmops.mk

PG_CPPFLAGS := -I$(subdir) -I$(swdir)/ -I../SolverAPI/

SHLIB_LINK = ../SolverAPI/libsolverapi.a -L. -lSwarmOps
SHLIB_PREREQS = libSwarmOps.so

MODULE_big = solversw
OBJS = solversw.o

MODULES = libSwarmOps
EXTENSION = solversw
DATA = solversw--1.0.sql

# REGRESS = lpsolver

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

.DEFAULT_GOAL := all
