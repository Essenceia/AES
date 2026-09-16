
import cocotb 
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout
from cocotb.types import Logic, LogicArray 

TXT_W = 128 

def set_all_enc(dut, \
	data_v: Logic, data: LogicArray, \
	key_v: Logic, key: LogicArray): 
	dut.enc_data_v.value = data_v
	dut.enc_data.value = data
	dut.enc_key_v.value = key_v
	dut.enc_key.value = key

async def enc(dut, 
	data: LogicArray, \
	key: LogicArray, 
	KEY_W: int = 128): 
	set_all_enc(dut, 1, data, 1, key)
	await ClockCycles(dut.clk, 1) 
	set_all_enc(dut, 0, "X"*TXT_W, 0, "X"*KEY_W)
	await ClockCycles(dut.clk, 16) 
	

