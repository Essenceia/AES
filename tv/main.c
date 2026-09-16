#include <stdio.h>
#include "aes.h"
#include "file.h"
#include "rand.h"

// AES cypher size in bytes, aes128 by default
#define TXT_SIZE 16
#define AES_SIZE 16

#define AES_ROUNDS (AES_SIZE == 16 ? 10: AES_SIZE == 32? 14:12)
// number of test vectors to be generated
#define TEST_NUM 1
			
#define PRINT_COL(i, data) printf("col%d: 0x%02x 0x%02x 0x%02x 0x%02x (0,1,2,3)\n", i, data[4*i+0], data[4*i+1], data[4*i+2], data[4*i+3])

#define PRINT_MATRIX(data) print_matrix((uint8_t*)data, sizeof(data), #data, false)

int main() {

	uint8_t  in[TXT_SIZE] = {0x32, 0x43, 0xf6, 0xa8, 0x88, 0x5a, 0x30, 0x8d, 0x31, 0x31, 0x98, 0xa2, 0xe0, 0x37, 0x07, 0x34}; 
	uint8_t key[AES_SIZE] = {0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c};
	uint8_t out[TXT_SIZE];
	uint8_t *w; // expanded key
	tvf_s *f;
		
	w = aes_init(sizeof(key));
	f = setup_files();
	setup_rand();
	
	// generate multiple test vectors and write them to file	
	for(uint8_t j=0; j<TEST_NUM; j++){

		/*
		// generate new random input and key
		gen_rand((uint8_t*)&in, AES_SIZE);
		gen_rand((uint8_t*)&key, AES_SIZE);
		*/ 

		//for(uint8_t i; i < AES_SIZE; i++) key[i] = i; 
		//for(uint8_t i; i < TXT_SIZE; i++) in[i] = i; 

		aes_key_expansion(key, w);
	
		#ifdef DEBUG
		printf("Plaintext message - ");
		PRINT_MATRIX(in);
	
		printf("key - ");
		PRINT_MATRIX(key);
		#endif
		
		aes_cipher(in /* in */, out /* out */, w /* expanded key */);
		
		#ifdef DEBUG
		printf("Ciphered message - ");
		PRINT_MATRIX(out);
		
		// last key pointer
		uint8_t *d = &w[AES_ROUNDS * (AES_SIZE/4)]; 
		printf("last key - ");
		print_matrix(d, AES_SIZE, "d", false);
	
		printf("write file, data in, key, out, expanded key:\n");
		#endif
		write_data8(f->f[0], (uint8_t*)&in,  sizeof(in));
		write_data8(f->f[1], (uint8_t*)&key, sizeof(key));
		write_data8(f->f[2], (uint8_t*)&out, sizeof(out));
		write_data8(f->f[3], (uint8_t*)&w[AES_ROUNDS * (AES_SIZE/4)], sizeof(key));
		
	}
	
	free(w);
	close_files(f);

	return 0;
}
