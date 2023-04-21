#ifndef RAND_H
#define RAND_H

#include <time.h>
#include <stdlib.h>
#include <stdint.h>

// Random number generator utils

// setup random number generator with a unique seed
static inline void setup_rand(){time(NULL);};

// generate random array to fill array r of size l
void gen_rand(uint8_t *r, size_t rl);

#endif // RAND_H
