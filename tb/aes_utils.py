
import cocotb 
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout
from cocotb.types import Logic, LogicArray 

TXT_W = 128 
COL_W = 32

def set_all_enc(dut, \
	data_v: Logic, \
	data_idx: int, 
	data: LogicArray, \
	key_v: Logic, \
	key_idx: int, \
	key: LogicArray): 
	dut.enc_data_v.value = data_v
	dut.enc_data_idx.value = data_idx
	dut.enc_data.value = data
	dut.enc_key_v.value = key_v
	dut.enc_key_idx.value = key_idx
	dut.enc_key.value = key

async def enc128(dut, 
	data: bytearray, \
	key:  bytearray, 
	KEY_W: int = 128):

	for i in range(4): 
		data_col = LogicArray.from_bytes(data[i*COL_W:(i+1)*COL_W], byteorder="big")
		key_col = LogicArray.from_bytes(key[i*COL_W:(i+1)*COL_W], byteorder="big") 		
		set_all_enc(dut, 1, i, data, 1, i, key)
		if i == 3:
			dut.enc_start.value = 1
		await ClockCycles(dut.clk, 1) 
	await ClockCycles(dut.clk, 16) 
	

