#include "file.h"
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

#define PRINTF_BINARY_PATTERN_INT8 "%c%c%c%c%c%c%c%c"
#define PRINTF_BYTE_TO_BINARY_INT8(i)    \
    (((i) & 0x80ll) ? '1' : '0'), \
    (((i) & 0x40ll) ? '1' : '0'), \
    (((i) & 0x20ll) ? '1' : '0'), \
    (((i) & 0x10ll) ? '1' : '0'), \
    (((i) & 0x08ll) ? '1' : '0'), \
    (((i) & 0x04ll) ? '1' : '0'), \
    (((i) & 0x02ll) ? '1' : '0'), \
    (((i) & 0x01ll) ? '1' : '0')

#define PRINTF_BINARY_PATTERN_INT16 \
    PRINTF_BINARY_PATTERN_INT8              PRINTF_BINARY_PATTERN_INT8
#define PRINTF_BYTE_TO_BINARY_INT16(i) \
    PRINTF_BYTE_TO_BINARY_INT8((i) >> 8),   PRINTF_BYTE_TO_BINARY_INT8(i)
#define PRINTF_BINARY_PATTERN_INT32 \
    PRINTF_BINARY_PATTERN_INT16             PRINTF_BINARY_PATTERN_INT16
#define PRINTF_BYTE_TO_BINARY_INT32(i) \
    PRINTF_BYTE_TO_BINARY_INT16((i) >> 16), PRINTF_BYTE_TO_BINARY_INT16(i)
#define PRINTF_BINARY_PATTERN_INT64    \
    PRINTF_BINARY_PATTERN_INT32             PRINTF_BINARY_PATTERN_INT32
#define PRINTF_BYTE_TO_BINARY_INT64(i) \
    PRINTF_BYTE_TO_BINARY_INT32((i) >> 32), PRINTF_BYTE_TO_BINARY_INT32(i)

tvf_s* setup_files(){
	int i;
	tvf_s* tv;
	// alloc struct
	tv = (tvf_s*) malloc(sizeof(tvf_s));
	if ( tv == NULL ){
		printf("Error allocating memory\n");
		return NULL;
	}
	// open files and create it if it does not exist
	for( i = 0; i<FILE_N; i++){
		tv->f[i] = fopen(FILE_STR[i],"w");
		if(tv->f[i]==NULL){
			printf("Error opening file %s\n",FILE_STR[i]);
		}
	}
	return tv;
}	

int close_files(tvf_s* tv){
	int i,r,t = 0;
	// close files, or to capture any error
	for(i=0;i<FILE_N;i++){
		fclose(tv->f[i]);
		if (errno != 0){
			printf("Error closing file %s, errnum %d\n",					FILE_STR[i], errno);
		}
		r |= t;
	}
	// free memory
	free(tv);
	return r;
};

int write_data64(FILE *f, uint8_t *d, size_t l){
	int j;
	size_t i, idx;
	size_t nl = l / 8;
	for(i=0;i<nl;i++){
		#ifdef DEBUG
		if( i % 3 == 0)printf("\n");
		#endif
		for(j=7;j>=0;j--){
			idx = i*8+j;
			fprintf(f,
				PRINTF_BINARY_PATTERN_INT8,
				PRINTF_BYTE_TO_BINARY_INT8(d[idx]));
	
			#ifdef DEBUG
			printf("%02X",d[idx]);
			#endif
		}
		#ifdef DEBUG
		printf(" ");
		#endif
	}
	# ifdef DEBUG
	printf("\n");
	#endif
	// add newline if we have written data
	if(l!=0)fprintf(f,"\n");	
	return errno;
};

int write_data8(FILE *f, uint8_t *d, size_t l){
	int i;
	for(i=l-1;i>=0;i--){
		fprintf(f,
			PRINTF_BINARY_PATTERN_INT8,
			PRINTF_BYTE_TO_BINARY_INT8(d[i]));
		#ifdef DEBUG
		printf(	"[%d] %02X\n",i, d[i]);
		#endif
	}
	# ifdef DEBUG
	printf("\n");
	#endif
	// add newline if we have written data
	if(l!=0)fprintf(f,"\n");	
	return errno;
};
