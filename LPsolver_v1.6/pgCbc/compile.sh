# -DCOIN_NOTEST_DUPLICATE is needed to prevent index duplication error, for some small problems
cd Cbc-2.9.4
./configure CPPFLAGS='-fpic -DCOIN_NOTEST_DUPLICATE' --enable-static --without-lapack --disable-bzlib
