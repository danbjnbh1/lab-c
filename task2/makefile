all: task2

task2: main.o util.o start.o
	ld -m elf_i386 start.o main.o util.o -o task2

main.o: main.c util.h
	gcc -m32 -Wall -ansi -c -nostdlib -fno-stack-protector -fno-builtin main.c -o main.o

util.o: util.c util.h
	gcc -m32 -Wall -ansi -c -nostdlib -fno-stack-protector -fno-builtin util.c -o util.o

start.o: start.s
	nasm -f elf32 start.s -o start.o

clean:
	rm -f *.o task2

