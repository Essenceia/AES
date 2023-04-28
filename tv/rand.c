#include "rand.h"


void gen_rand(uint8_t *r, size_t l){
	size_t i;
	uint8_t g;
	for( i=0; i < l;i++){
		// cast rand()'s output to uint8_t
		g = (uint8_t) rand(); 
		r[i] = g;
	} 
}
