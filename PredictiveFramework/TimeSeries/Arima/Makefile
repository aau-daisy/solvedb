EXTENSION = arima_solver
DATA = arima_solver--1.0.sql

# REGRESS = lpsolver

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

.DEFAULT_GOAL := all
