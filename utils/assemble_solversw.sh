#/bin/bash

cd SwarmSolver
if [ $? -ne 0 ]; then
  echo -e "This script is run in a wrong directory"
  exit
fi

SOLVERDIR=$(pwd)

# Fetch and configure the SwarmOps

cd libSwarmOps
if [ $? -ne 0 ]; then
  echo -e "Unexpected directory structure!"
  exit
fi


# Get the SwarmOps solver package and RandomOps from the web
echo -e "Fetching the SwarmOPS from the web..."

DIR=SwarmOps
FILE_SO=SwarmOps1_2.zip
FILE_RO=RandomOps1_2.zip

wget -O $FILE_SO http://www.hvass-labs.org/projects/swarmops/c/files/$FILE_SO

if [ ! -f $FILE_SO ]; then
  echo -e "Downloading the SwarmOps sources failed!"
  exit
fi

wget -O $FILE_RO http://www.hvass-labs.org/projects/randomops/c/files/$FILE_RO

if [ ! -f $FILE_RO ]; then
  echo -e "Downloading the RandomOps sources failed!"
  exit
fi

# Extract the sources
unzip -o $FILE_SO

if [ $? -ne 0 ]; then
  echo -e "Failed extracting the SwarmOps sources"
  exit
fi

unzip -o $FILE_RO -d $DIR

# Applying patch to the SwarmOps
patch -s -p0 -N < $DIR/swarmops.patch

if [ $? -ne 0 ]; then
  echo -e "Patching SwarmOps has failed!"
  exit
fi

echo -e "Done! Please compile the solver with 'make'."