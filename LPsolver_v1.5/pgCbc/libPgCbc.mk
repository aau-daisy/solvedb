CC           = g++
cbcDIR       = $(shell pwd)/pgCbc
cbcDIRfull   = $(cbcDIR)/Cbc-2.9.4
cbcOBJS      = $(cbcDIR)/libPgCbc.o
ECPPFLAGS    = -I$(cbcDIRfull)/include/coin/ -fPIC -O3
#-g -O0
cbcLIBso     = $(cbcDIRfull)/lib/libCbc.a $(cbcDIRfull)/lib/libCbcSolver.a $(cbcDIRfull)/lib/libOsi.a $(cbcDIRfull)/lib/libOsiCbc.a $(cbcDIRfull)/lib/libOsiClp.a $(cbcDIRfull)/lib/libClp.a $(cbcDIRfull)/lib/libCgl.a $(cbcDIRfull)/lib/libCoinUtils.a
cbcSHLIB     = -L$(cbcDIRfull)/lib/ -Wl,-Bstatic -Wl,--start-group -lCbc -lCbcSolver -lOsi -lOsiCbc -lOsiClp -lClp -lCgl -lCoinUtils -Wl,--end-group -Wl,-Bdynamic -lstdc++ -lz -Wl,--as-needed 



#all: libPgCbc.a
.PHONY: clean_pgcbc

libPgCbc.so: $(cbcLIBso) $(cbcOBJS)
	g++ -shared $(CPPFLAGS) -o $@ $(cbcOBJS) $(cbcSHLIB)

$(cbcOBJS): $(@:.o=.cpp)
	$(CC) -c $(CPPFLAGS) $(ECPPFLAGS) $(@:.o=.cpp) -o $@

$(cbcLIBso): make_LIBs

make_LIBs:
	cd $(cbcDIRfull); ./configure CPPFLAGS='-fpic -DCOIN_NOTEST_DUPLICATE' --enable-static --without-lapack --disable-bzlib
	$(MAKE) -C $(cbcDIRfull)
	$(MAKE) -C $(cbcDIRfull) install


clean_pgcbc:
	rm $(cbcOBJS)


# EXTRA_CLEAN=$(cbcOBJSOD)
