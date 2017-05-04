#/bin/bash

DIR=$(pwd)

# Install PostgreSQL dependencies
sudo apt-get install libreadline-dev zlib1g-dev flex bison

#install postgresql
cd $DIR/SolveDB/postgresql-9*

# make clean
./configure
make -j 2
sudo make install
PATH=/usr/local/pgsql/bin:$PATH
export PATH
hash -r
sudo ln -s /usr/local/pgsql/lib/libpq.so.5 /usr/lib/libpq.so.5
sudo ln -s /usr/local/pgsql/bin/pg_config /usr/local/bin/pg_config
sudo ln -s /usr/local/pgsql/bin/psql /usr/bin/psql

cd $DIR/SolverAPI/
make clean
make -j 2
sudo make install -j 2


cd $DIR/LPsolver_v1.5/
make clean
make -j 2
sudo make install -j 2

cd $DIR/SwarmSolver/
make clean
make -j 2
sudo make install -j 2

