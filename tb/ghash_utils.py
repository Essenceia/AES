
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
	cocotb.log.info(f"Galois dot product inputs\nX {hex(x)}\nY {hex(y)}")

	z = 0
	v = y

	# Process bits from most-significant to least-significant
	for i in range(127, -1, -1):
		cocotb.log.debug(f"{128-i} x {(x>>i):#0{34}x} match {(x>>i) & i} - i {i}")
		if (x >> i) & 1:
			cocotb.log.debug(f"{128-i} x {(x>>i):#0{34}x}")
			z ^= v
		if v & 1:
			v = (v >> 1) ^ GHASH_POLY
		else:
			v = v >> 1
		cocotb.log.info(f"{128-i} z {z:#0{34}x} v {v:#0{34}x}")

	return z

def __ghash(h_key: bytes, payload: bytes) -> bytes:
	assert len(payload) % 16 == 0, f"expencted length payload to be a multiple of 16 got {len(payload)}"
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
	set_all_enc(dut, \
		0, "X"*GHASH_W, \
		0, "X"*GHASH_W)

async def hash(dut, 
	data: bytearray, \
	key:  bytearray):
	

	assert len(data) % 16 == 0
	max_pi = int(len(data) / 16)
	
	cocotb.log.info(f"partial key 0x{key.hex()} data 0x{data.hex()} (blocks {max_pi})")
	
	ki = 0 # key block sent
	pi = 0 # plain text block sent

	# add random gaps between cycles when writting data, the only 
	# constraint is that the key collumn must be sent before the 
	# equivalent data collumn
	while pi < max_pi: 
		
		# send plain text
		if (random.randint(0, 100) < 40) and (ki > 0):
			data_v = 1
			data_col = LogicArray.from_bytes(data[pi*16:(pi+1)*16], byteorder="big")
			pi = pi + 1
			cocotb.log.debug(f"txt col{pi} {hex(data_col)}")
			send = True	
		else: 
			data_v = 0 
			data_col = "X"*GHASH_W
			send = False

		# send key
		if (random.randint(0, 100) < 40) and (ki < 1):
			key_v = 1
			key_col = LogicArray.from_bytes(key, byteorder="big") 
			ki = ki + 1	
		else: 
			key_v = 0
			key_col = "X"*GHASH_W

		set_all_enc(dut, data_v, data_col, key_v, key_col)
		if send:
			await ClockCycles(dut.clk, 1) 
			set_enc_invalid_data(dut)
			await ClockCycles(dut.clk, 63) 
		else:
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

	ghash_expected = __ghash(data, key) 
	cocotb.log.info(f"expected 0x{ghash_expected.hex()}\ngotten {hex(res)}") 
#	cipher = AES.new(key, AES.MODE_ECB)
#	ciphertext = cipher.encrypt(data)
#
	assert res == LogicArray.from_bytes(ghash_expected, byteorder="big"), f"cipher result missmatch\nexpected 0x{ghash_expected.hex()}\ngotten   {hex(res)}"
 
	

