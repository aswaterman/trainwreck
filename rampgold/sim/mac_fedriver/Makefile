CC=gcc
CFLAGS=-O3 -fPIC -Wall -pedantic -std=gnu99 #-ansi

all : check_dependencies mac_fedriver

.PHONY: check_dependencies

check_dependencies:
	@if test ! -e "mac_fedriver.h"; then \
		echo "please use 'vlog -dpiheader' to generate mac_fedriver.h"; exit 1; \
	fi; \

	@if test -z "$(MTI_HOME)"; then \
		echo "modelsim is not correctly installed and MTI_HOME is undefined"; exit 1; \
	fi

%.o: %.c
	$(CC) $(CFLAGS) -I. -I$(MTI_HOME)/include  -c $<

mac_fedriver: mac_fedriver.o socket.o

	$(CC) -shared -Wl,-Bsymbolic -Wl,-export-dynamic -lpthread -o mac_fedriver.so socket.o mac_fedriver.o

clean:
	-rm -f *.o mac_fedriver.so

