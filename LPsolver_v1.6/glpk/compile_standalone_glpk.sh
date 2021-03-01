#!/bin/bash
cd ./glpk-4.47/
./configure --enable-odbc=unix --enable-dl
make