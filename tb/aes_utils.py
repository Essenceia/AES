
import cocotb 
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout
from cocotb.types import Logic, LogicArray, Range 

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
	for i in range(4): 
		data_col = LogicArray.from_bytes(data[i*COL_BYTE_W:(i+1)*COL_BYTE_W], byteorder="big")
		key_col = LogicArray.from_bytes(key[i*COL_BYTE_W:(i+1)*COL_BYTE_W], byteorder="big") 	
		cocotb.log.info(f"txt col{i} {hex(data_col)}")	
		set_all_enc(dut, 1, i, data_col, 1, i, key_col)
		if i == 3:
			dut.enc_start.value = 1
		await ClockCycles(dut.clk, 1) 
	set_enc_invalid_data(dut)
	await ClockCycles(dut.clk, 16) 
	

