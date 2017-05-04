# Static library 
libsolverapi:
	$(MAKE) -f libsolverapi.mk

# Shared library (PG extension)
MODULE_big = solverapi
OBJS = solverapi.o
SHLIB_PREREQS = libsolverapi
SHLIB_LINK = libsolverapi.a

EXTENSION = solverapi
DATA = solverapi--1.2.sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

clean-libsolverapi:
	$(MAKE) -f libsolverapi.mk clean

clean:	clean-libsolverapi

.DEFAULT_GOAL := all
