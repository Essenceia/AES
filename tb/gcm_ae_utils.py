from sram import sram_config

import cocotb
from cocotb.triggers import ClockCycles 

async def wr_sram_config(dut, conf: sram_config):
	raw_config = bytearray(b'')
	raw_config += conf.raw()
	dut.gcm_pn.value = "X" * 32
	dut.gcm_sci.value = "X" * 64
	for i, b in enumerate(raw_config):
		if i in range(0,4):
			dut.gcm_pn.value[(i+1)*8-1:i*8] = b
		if i in range(8,16):
			dut.gcm_sci.value[(i-8+1)*8-1:(i-8)*8] = b
		dut.gcm_sram_v.value = i in range(16, 48)  		 	
		dut.gcm_sram_k.value = i in range(16,32) 	
		dut.gcm_sram_h.value = i in range(32,48) 
		dut.gcm_sram.value = b
		ClockCycles(dut.clk, 1) 
	dut.gcm_sram_v.value = 0		

async def set_random_config(dut): 
	dut.gcm_init.value = 1
	ClockCycles(dut.clk, 1) 
	dut.gcm_init.value = 0
	conf = sram_config()
	conf.random()
	await wr_sram_config(dut, conf) 
	
	
