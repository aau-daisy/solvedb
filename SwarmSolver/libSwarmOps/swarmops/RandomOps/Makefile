CC=g++
CPPFLAGS :=             -Wall -I. -I./../

# determine all sources and from that all targets
sources :=              $(wildcard *.c) $(wildcard */*.c)
objects=$(sources:.c=.o)

# build all and strip programs afterwards 
all:    $(objects) librandom.a

librandom.a: 
	ar -cvq $@ $(objects)

.c.o: 
	$(CC) $(CPPFLAGS) -c $^ -o $@


clean:
	rm -f $(objects)
