CC=g++
CPPFLAGS :=             -Wall -I. -I../ -I./Tools -I./Methods -I./Methods/Helpers -I./Statistics -I./RandomOps

# determine all sources and from that all targets
sources :=              $(wildcard *.c) $(wildcard */*.c)
objects=$(sources:.c=.o)

# build all and strip programs afterwards 
all: 	$(objects)
	$(CC) $(CPPFLAGS) $(objects) -o $@

.c.o: 
	$(CC) $(CPPFLAGS) -c $^ -o $@


clean:
	rm -f $(objects)
