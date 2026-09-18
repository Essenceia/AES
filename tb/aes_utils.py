
import cocotb 
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout
from cocotb.types import Logic, LogicArray, Range 

import Crypto
from Crypto.Cipher import AES

TXT_W = 128 
COL_W = 32
COL_BYTE_W = 4

def set_all_enc(dut, \
	data_v: Logic, \
	data_idx: LogicArray, 
	data: LogicArray, \
	key_v: Logic, \
	key_idx: LogicArray, \
	key: LogicArray): 
	dut.enc_data_v.value = data_v
	dut.enc_data_idx.value = data_idx
	dut.enc_data.value = data
	dut.enc_key_v.value = key_v
	dut.enc_key_idx.value = key_idx
	dut.enc_key.value = key

def set_enc_invalid_data(dut): 
	dut.enc_start.value = 0
	set_all_enc(dut, \
		0, LogicArray('XX', Range(1, 'downto', 0)), "X"*COL_W, \
		0, LogicArray('XX', Range(1, 'downto', 0)), "X"*COL_W)

async def enc128(dut, 
	data: bytearray, \
	key:  bytearray, 
	KEY_W: int = 128):
	
	dut.enc_start.value = 0
	for i in range(5): 
		data_v = 1 if i > 0 else 0
		data_idx = i-1 if i > 0 else LogicArray('XX', Range(1, 'downto', 0)) 
		key_v = 1 if i < 4 else 0
		key_idx = i if i < 4 else LogicArray('XX', Range(1, 'downto', 0)) 

		if i > 0:
			data_col = LogicArray.from_bytes(data[data_idx*COL_BYTE_W:(data_idx+1)*COL_BYTE_W], byteorder="big")
			cocotb.log.info(f"txt col{i} {hex(data_col)}")	
		else: 
			data_col = "X"*COL_W

		if i < 4:
			key_col = LogicArray.from_bytes(key[key_idx*COL_BYTE_W:(key_idx+1)*COL_BYTE_W], byteorder="big") 	
		else: 
			key_col = "X"*COL_W

		set_all_enc(dut, data_v, data_idx, data_col, key_v, key_idx, key_col)
		if i == 4:
			dut.enc_start.value = 1
		await ClockCycles(dut.clk, 1) 
	set_enc_invalid_data(dut)
	
	timeout = 0 
	res = b''
	while (timeout < 64): 
		if (dut.enc_res_v.value == 1):
			res = dut.enc_res.value	
			cocotb.log.info(f"res {hex(res)}")
			break
	
		await ClockCycles(dut.clk, 1)
		timeout=timeout+1

	cipher = AES.new(key, AES.MODE_EAX)
	ciphertext, tag = cipher.encrypt_and_digest(data)

	cocotb.log.info(f"ciphertext {ciphertext.hex()} tag {tag.hex()}")

 
	

