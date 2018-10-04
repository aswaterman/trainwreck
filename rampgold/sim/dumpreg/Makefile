CC=gcc
CFLAGS=-O4 -fPIC -Wall -pedantic #-ansi

all : dumpreg

%.o: %.c
	$(CC) $(CFLAGS) -I. -I$(MTI_HOME)/include -c $<

dumpreg: dumpreg.o
	$(CC) -shared -Wl,-Bsymbolic -Wl,-export-dynamic -o dumpreg.so dumpreg.o

clean:
	-rm -f *.o dumpreg.so
