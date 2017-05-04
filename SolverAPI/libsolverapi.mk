# Static library
MODULE_big = solverapi
OBJS = low_level_utils.o solverapi_utils.o libsolverapi.o

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

.DEFAULT_GOAL := all-static-lib