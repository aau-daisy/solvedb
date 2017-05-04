#/bin/bash

cd SolveDB
if [ $? -ne 0 ]; then
  echo -e "This script is run in a wrong directory"
  exit
fi

echo -e "Downloading the original PostgreSQL sources..."

FILE=postgresql-9.6.0.tar.gz
wget -O $FILE https://ftp.postgresql.org/pub/source/v9.6.0/$FILE

if [ ! -f $FILE ]; then
  echo -e "PostgreSQL download failed!"
  exit
fi

echo -e "Extracting PostgreSQL sources..."

tar -xvzf $FILE

if [ $? -ne 0 ]; then
  echo -e "Failed extracting PostgreSQL sources..."
  exit
fi

echo -e "Patching PostgreSQL sources to upgrade it so SolveDB..."
patch -s -p0 -N < solvedb.patch

if [ $? -ne 0 ]; then
  echo -e "Upgrading PostgreSQL to SolveDB has failed!"
  exit
fi

echo -e "PostgreSQL was successfully updated to SolveDB! Please follow the PostgreSQL (SolveDB) manual for compiling the system."
