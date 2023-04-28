# Test vector generation

Generate aes128 encode test vector, written in binary format

To build : 
```
make 
```

To build in debug mode :
```
make debug=1
```

To run :
```
./aes
```

Output will be written to files : 

- `aes_enc_data_i.txt`

- `aes_enc_key_i.txt`

- `aes_enc_res_o.txt`


## Configuration

Generator behavior can be modified via macro's in `main.c`.

- `TEST_NUM` number of test vectors to be generated and written to file, default value is `10`

- `AES_SIZE` aes cypher size in bytes, default is `16`
