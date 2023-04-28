// Manage produced file containing the test vectors

#ifndef FILE_H
#define FILE_H

#include <stdio.h>
#include <stdint.h>

// number of files
#define FILE_N 4
// file names
#define FILE_STR (char*[FILE_N]) {"aes_enc_data_i.txt","aes_enc_key_i.txt","aes_enc_res_o.txt", "aes_enc_key_o.txt"}

// file pointers
typedef struct{
	FILE* f[FILE_N];
} tvf_s;

// create files if they are missing, return error code
tvf_s* setup_files();

// close files, return error code
int close_files(tvf_s* tv);

// write data
int write_data64(FILE *f, uint8_t *d, size_t l);
int write_data8(FILE *f, uint8_t *d, size_t l);
	
#endif
