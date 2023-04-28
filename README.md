# AES128 RTL implementation

Implementation of the AES128 encryption/decryption algorithm into synthesizable RTL.
The encryption/decryption takes place over multiple cycles inline with the aes's rounds, for
aes128 it take 12 cycles for the module to produce an output.

## RTL

This synthesizable implementation of AES128 includes two separate desings : one for encryption and another for decryption.
Our implementation breaks down the more difficult rounds of the AES algorithm into there own module, simpler rounds are
performed in the top level. 

Modules :
|    | Encryption      | Decryption |
| -- | --------------- | ----------- |
|top | aes       | iaes    |
|sbox| sbox  | isbox      |
|mix columns | mixw  | imixw      |
|key scheduling| ks  | iks  |


### Top 

The top level module contains the main control logic for the aes algorithm.
This module includes :

- FSM keeping track of the aes round we are currently

- flops for the data an:d key

- shift row round 


#### encryption interface

```
module aes(
	input clk,
	input nreset,
	
	input          data_v_i, // input valid
	input [127:0]  data_i,   // message to encode
	input [127:0]  key_i,    // key
	output         res_v_o,  // result valid
	output [127:0] res_o     // result
	);
``` 

#### Decryption interface
```
module iaes(
	input clk,
	input nreset,
	 
	input          data_v_i, // input valid
	input  [127:0] data_i,	 // message to decode
	input  [127:0] key_i,    // key ( encoded version )
	output         res_v_o,  // result valid
	output [127:0] res_o     // result
	);
```

### Sbox

Sbox module output the corresponding byte according to the Rijndael S-box substitution.

We do not store the sbox lookup table in memory but rater calculate it on the fly.
 
#### encryption interface
```
module sbox(
    input  [7:0] data_i,
    output [7:0] data_o
    );
```
#### Decryption interface
```
module isbox(
    input  [7:0] data_i,
    output [7:0] data_o
    );
```

### Mix Columns

This module takes in 4 bytes and treats them as a 4 term polynomial and multiplies them with a predetermined 4x4 matrix.
These operations are done in a Galois field, as such the definition of operations such as "multiplication" and "addition"
is different.

Encryption :
![Mix column math!](/doc/mixw.png)
Decryption :
![Invert mix column math!](/doc/imixw.png)

#### encryption interface
```
 module mixw(
	input  [31:0] w_i,
	output [31:0] mixw_o
	);
```

#### Decryption interface
```
module imixw(
	input  [31:0] w_i,
	output [31:0] mixw_o
	);
```

### Key scheduling 

This module derives the new 4 byte key and 1 byte round constrant (rcon) for the current aes round by taking in the previous round key and rcon. 
Internally this module also calls on the sbox module during operations on the higher order byte.

encryption : 
![Key schedulaing, source : https://braincoke.fr/blog/2020/08/the-aes-key-schedule-explained/!](doc/ks.png)

#### encryption interface
```
module ks(
	input  wire [127:0] key_i,
	input  wire [7:0]   key_rcon_i,
	output wire [127:0] key_next_o,
	output wire [7:0]   key_rcon_o
	);
```
#### Decryption interface
```
module iks(
	input  wire [127:0] key_i,
	input  wire [7:0]   key_rcon_i,
	output wire [127:0] key_next_o,
	output wire [7:0]   key_rcon_o
	);
```
## Test bench
