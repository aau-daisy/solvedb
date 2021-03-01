cd ./postgresql-11.2
./configure CFLAGS='-g -O0 -ggdb -g3 -ggdb3' --enable-debug --enable-cassert --with-llvm LLVM_CONFIG='/usr/bin/llvm-config-3.9'
