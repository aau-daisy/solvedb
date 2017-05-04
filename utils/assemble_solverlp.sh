#/bin/bash

cd LPsolver_v1.5
if [ $? -ne 0 ]; then
  echo -e "This script is run in a wrong directory"
  exit
fi

SOLVERDIR=$(pwd)

# Fetch and configure the GLPK

cd glpk
if [ $? -ne 0 ]; then
  echo -e "Unexpected directory structure!"
  exit
fi


# Get the GLPK solver package from the web
echo -e "Fetching the GLPK from the web..."

FILE=glpk-4.47.tar.gz
#DIR=glpk-4.47

wget -O $FILE https://ftp.gnu.org/gnu/glpk/$FILE

if [ ! -f $FILE ]; then
  echo -e "GLPK download failed!"
  exit
fi

# Extract the sources
tar -xvzf $FILE

if [ $? -ne 0 ]; then
  echo -e "Failed extracting the GLPK sources!"
  exit
fi

# Fetch and configure CBC

cd $SOLVERDIR
cd pgCbc
if [ $? -ne 0 ]; then
  echo -e "Unexpected directory structure!"
  exit
fi
FILE=Cbc-2.9.4.zip
wget -O $FILE https://www.coin-or.org/download/source/Cbc/Cbc-2.9.4.zip

if [ ! -f $FILE ]; then
  echo -e "Downloading the CBC sources failed!"
  exit
fi

unzip -o $FILE

if [ $? -ne 0 ]; then
  echo -e "Failed extracting the GLPK sources"
  exit
fi

echo -e "Done! Please compile the solver with 'make'."