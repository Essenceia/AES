# AES128 RTL implementation

Implementation of the AES128 encyption/decryption algorithm into synthesizable RTL.

## RTL

This synthesizable implementation of AES128 includes two spearate desings : one for encryption and another for decryption.
Our implementation breaks down the more difficult steps of the AES alogrythem into there own module, simpler steps are
performaed in the top level. 

List of modules
| Encryption      | Decryption |
| --------------- | ----------- |
| top       | itop    |
| sbox  | isbox      |
| mixw  | imixw      |
| key\_schedulating  | ikey\_schedualing  |




## Testbench
