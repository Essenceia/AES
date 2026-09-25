
import cocotb 
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout
from cocotb.types import Logic, LogicArray, Range 

import Crypto
from Crypto.Cipher import AES

import random

TXT_W = 128
TXT_BYTES_W = 16 
COL_W = 32
COL_BYTE_W = 4

AES_CYCLES = 64 

def set_all_enc(dut, \
	data_v: Logic, \
	data_idx: LogicArray, 
	data: LogicArray, \
	key_v: Logic, \
	key: LogicArray): 
	dut.enc_data_v.value = data_v
	dut.enc_data_idx.value = data_idx
	dut.enc_data.value = data
	dut.enc_key_v.value = key_v
	dut.enc_key.value = key

def set_enc_invalid_data(dut): 
	dut.enc_start.value = 0
	set_all_enc(dut, \
		0, LogicArray('XX', Range(1, 'downto', 0)), "X"*COL_W, \
		0, LogicArray('XX', Range(1, 'downto', 0)), "X"*TXT_W)

async def enc128(dut, 
	data: bytearray, \
	key:  bytearray, 
	KEY_W: int = 128):
	
	cocotb.log.info(f"key 0x{key.hex()} data 0x{data.hex()}")
	
	dut.enc_start.value = 0
	ki = 0 # key sent 
	pi = 0 # plain text collumn next send index

	# add random gaps between cycles when writting data, the only 
	# constraint is that the key collumn must be sent before the 
	# equivalent data collumn
	while pi < 4: 
		
		# send plain text
		if (random.randint(0, 100) < 40) and (pi < 4) and (ki > 0):
			data_v = 1
			data_idx = pi 
			data_col = LogicArray.from_bytes(data[data_idx*COL_BYTE_W:(data_idx+1)*COL_BYTE_W], byteorder="big")
			pi = pi + 1
			cocotb.log.debug(f"txt col{pi} {hex(data_col)}")	
		else: 
			data_v = 0 
			data_idx = LogicArray('XX', Range(1, 'downto', 0)) 
			data_col = "X"*COL_W

		# send key
		if (random.randint(0, 100) < 40) and (ki < 1):
			key_v = 1
			key_idx = ki 
			key_data = LogicArray.from_bytes(key, byteorder="big") 	
			ki = ki + 1
		else: 
			key_v = 0
			key_data = "X"*COL_W

		set_all_enc(dut, data_v, data_idx, data_col, key_v, key_data)
		if pi == 4:
			dut.enc_start.value = 1
		await ClockCycles(dut.clk, 1) 
	set_enc_invalid_data(dut)
	
	timeout = 0 
	res = b''
	max_timeout = AES_CYCLES - 5 # max timeout time is 64 cycles to get data and we need at least 5 cycle to send data
	while (timeout < max_timeout): 
		if (dut.enc_res_v.value == 1):
			res = dut.enc_res.value	
			break
	
		await ClockCycles(dut.clk, 1)
		timeout=timeout+1

	assert timeout < max_timeout, "timeout reached without res_v"
 
	cipher = AES.new(key, AES.MODE_ECB)
	ciphertext = cipher.encrypt(data)

	assert len(ciphertext) == TXT_BYTES_W, f"gotten length {len(ciphertext)}"
	assert res == LogicArray.from_bytes(ciphertext, byteorder="big"), f"cipher result missmatch\nexpected res 0x{ciphertext.hex()} ({len(ciphertext)})"
 
	

