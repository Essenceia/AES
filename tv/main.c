#include <stdio.h>
#include "aes.h"
#include "file.h"
#include "rand.h"

// AES cypher size in bytes, aes128 by default
#define AES_SIZE 16
#define AES_ROUNDS (AES_SIZE == 16 ? 10: AES_SIZE == 32? 14:12)
// number of test vectors to be generated
#define TEST_NUM 10
			
#define PRINT_COL(i, data) printf("col%d: %02x %02x %02x %02x (0,1,2,3)\n", i, data[4*i+0], data[4*i+1], data[4*i+2], data[4*i+3])


int main() {

	uint8_t i, j;
	uint8_t  in[AES_SIZE]; 
	uint8_t key[AES_SIZE];
	uint8_t out[AES_SIZE];
	uint8_t key_out[AES_SIZE];
	uint8_t *w; // expanded key
	tvf_s *f;
		
	w = aes_init(sizeof(key));
	f = setup_files();
	setup_rand();
	
	// generate multiple test vectors and write them to file	
	for(j=0; j<TEST_NUM; j++){
		// generate new random input and key
		gen_rand(&in, AES_SIZE);
		gen_rand(&key, AES_SIZE);

		aes_key_expansion(key, w);
	
		#ifdef DEBUG
		printf("Plaintext message:\n");
		for (i = 0; i < 4; i++) {
			PRINT_COL(i, in);
		}
		printf("\nkey:\n");
		for (i = 0; i < AES_SIZE/4; i++) {
			PRINT_COL(i, key);
		}
		printf("\n");	
		#endif
		
		aes_cipher(in /* in */, out /* out */, w /* expanded key */);
		
		#ifdef DEBUG
		printf("Ciphered message:\n");
		for (i = 0; i < 4; i++) {
			PRINT_COL(i, out);
		}
		printf("\n");
		// last key pointer
		size_t last_key_idx = AES_ROUNDS * (AES_SIZE/4);
		uint8_t *d = &w[last_key_idx]; 
		printf("key:\n");
		for (i = 0; i < AES_SIZE/4 ; i++) {
			PRINT_COL(i, d);
		}
		printf("\n");
		#endif
	
		write_data8(f->f[0], &in,  sizeof(in));
		write_data8(f->f[1], &key, sizeof(key));
		write_data8(f->f[2], &out, sizeof(out));
		write_data8(f->f[3], &w[last_key_idx], sizeof(key));
		
	}
	
	free(w);
	close_files(f);

	return 0;
}
