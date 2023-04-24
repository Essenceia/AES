#include <stdio.h>
#include "aes.h"
#include "file.h"
#include "rand.h"

// AES cypher size in bytes, aes128 by default
#define AES_SIZE 16

// number of test vectors to be generated
#define TEST_NUM 10


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
			printf("%02x %02x %02x %02x ", in[4*i+0], in[4*i+1], in[4*i+2], in[4*i+3]);
		}
		printf("\n");
		#endif
		
		aes_cipher(in /* in */, out /* out */, w /* expanded key */);
		
		#ifdef DEBUG
		printf("Ciphered message:\n");
		for (i = 0; i < 4; i++) {
			printf("%02x %02x %02x %02x ", out[4*i+0], out[4*i+1], out[4*i+2], out[4*i+3]);
		}
		printf("\n");
		#endif
	
		write_data8(f->f[0], &in,  sizeof(in));
		write_data8(f->f[1], &key, sizeof(key));
		write_data8(f->f[2], &out, sizeof(out));
		write_data8(f->f[3], &w+12, sizeof(key));
		
	}
	
	free(w);
	close_files(f);

	return 0;
}
