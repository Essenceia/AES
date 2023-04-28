ifndef debug
#debug :=
endif

FLAGS = -Wall -Wextra -Wconversion -Wshadow -Wundef -fno-common  -Wno-unused-parameter -Wno-type-limits
CC = cc $(if $(debug),-DDEBUG -g)
LD = cc

aes : main.o file.o gmult.o aes.o rand.o
	$(LD) -o aes -g main.o file.o gmult.o aes.o rand.o

main.o : main.c
	$(CC) -c main.c $(FLAGS)

file.o : file.c file.h
	$(CC) -c file.c $(FLAGS)

gmult.o : gmult.c gmult.h
	$(CC) -c gmult.c $(FLAGS)

aes.o : aes.c aes.h
	$(CC) -c aes.c $(FLAGS)

rand.o : rand.c rand.h
	$(CC) -c rand.c $(FLAGS)

clean :
	rm -f aes *.o
	rm -f *_i.txt *_o.txt
