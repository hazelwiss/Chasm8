SOURCE_FILES:= $(shell find -name "*.asm")
ASMC:= nasm
ASMFLAGS:= -g -f elf64
CC= gcc 
CFLAGS:= -no-pie -O0 -g -lSDL2
BIN:= a.out

%.o: %.asm
	$(ASMC) $(ASMFLAGS) $<  -o $@

all: $(SOURCE_FILES:.asm=.o)
	$(CC) $(CFLAGS) sdl.c -c
	$(CC) $(CFLAGS) $(SOURCE_FILES:.asm=.o) sdl.o -o $(BIN)

clean:
	find -name "*.o" -delete