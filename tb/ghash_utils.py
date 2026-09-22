
import cocotb 
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout
from cocotb.types import Logic, LogicArray, Range 

import Crypto
from Crypto.Cipher import AES

import random

GHASH_W = 128

# code taken from stack overflow https://crypto.stackexchange.com/questions/61347/aes-gcm-conformance-test
GHASH_POLY = 0xE1000000000000000000000000000000

def __ghash_gf_multiply(x: int, y: int) -> int:
	res = 0
	# Process bits from most-significant to least-significant
	for i in range(127, -1, -1):
		if (y >> i) & 1:
			res ^= x
		if x & 1:
			x = (x >> 1) ^ GHASH_POLY
		else:
			x >>= 1
	return res

def __ghash(h_key: bytes, payload: bytes) -> bytes:
	"""
	Computes the GHASH authentication tag over Associated Data (AAD) and Ciphertext.
	"""
	assert(len(payload) % 16 == 0)
	assert(len(h_key) % 16 == 0)
	
	# Parse the Hash Key (H) into an integer
	h_int = int.from_bytes(h_key, 'big')
	
	# 3. Main GHASH processing loop
	tag_accum = 0
	for i in range(0, len(payload), 16):
		block = int.from_bytes(payload[i:i+16], 'big')
		tag_accum ^= block
		tag_accum = __ghash_gf_multiply(tag_accum, h_int)
		
	return tag_accum.to_bytes(16, 'big')

def set_all_enc(dut, \
	data_v: Logic, \
	data: LogicArray, \
	key_v: Logic, \
	key: LogicArray): 
	dut.gh_data_v.value = data_v
	dut.gh_data.value = data
	dut.gh_key_v.value = key_v
	dut.gh_key.value = key

def set_enc_invalid_data(dut): 
	dut.gh_new_v.value = 0
	set_all_enc(dut, \
		0, "X"*GHASH_W, \
		0, "X"*GHASH_W)

async def hash(dut, 
	data: bytearray, \
	key:  bytearray):
	
	cocotb.log.info(f"partial key 0x{key.hex()} data 0x{data.hex()}")
	
	dut.gh_new_v.value = 0
	
	ki = 0 # key block sent
	pi = 0 # plain text block sent

	# add random gaps between cycles when writting data, the only 
	# constraint is that the key collumn must be sent before the 
	# equivalent data collumn
	while pi < 1: 
		
		# send plain text
		if (random.randint(0, 100) < 40) and (pi < ki):
			data_v = 1
			data_col = LogicArray.from_bytes(data, byteorder="big")
			pi = pi + 1
			cocotb.log.debug(f"txt col{pi} {hex(data_col)}")	
		else: 
			data_v = 0 
			data_col = "X"*GHASH_W

		# send key
		if (random.randint(0, 100) < 40) and (ki < 1):
			key_v = 1
			key_col = LogicArray.from_bytes(key, byteorder="big") 
			ki = ki + 1	
		else: 
			key_v = 0
			key_col = "X"*GHASH_W

		set_all_enc(dut, data_v, data_col, key_v, key_col)
		if pi == 1:
			dut.gh_new_v.value = 1
		await ClockCycles(dut.clk, 1) 
	set_enc_invalid_data(dut)
	
	timeout = 0 
	res = b''
	max_timeout = 64 + 5 
	while (timeout <= max_timeout): 
		if (dut.gh_res_v.value == 1):
			res = dut.gh_res.value	
			break
	
		await ClockCycles(dut.clk, 1)
		timeout=timeout+1

	assert timeout < max_timeout, "timeout reached without res_v"

	ghash_expected = __ghash(key, data) 
	cocotb.log.info(f"expected 0x{ghash_expected.hex()}\ngotten {hex(res)}") 
#	cipher = AES.new(key, AES.MODE_ECB)
#	ciphertext = cipher.encrypt(data)
#
#	assert len(ciphertext) == TXT_BYTES_W, f"gotten length {len(ciphertext)}"
#	assert res == LogicArray.from_bytes(ciphertext, byteorder="big"), f"cipher result missmatch\nexpected res 0x{ciphertext.hex()} ({len(ciphertext)})"
 
	

