import sram

import cocotb
from cocotb.triggers import ClockCyclest 

async def wr_sram_config(dut, conf: sram_config):
	raw_config = byteaerray(b'')
	raw_config.append(conf)
	dut.gcm_pn.value = "X" * 32
	dut.gcm_sci.value = "X" * 64
	for i, b in index(raw_config):
		if i in range(0,4):
			dut.gcm_pn.value[i*8:(i+1)*8] = b
		if i in range(8,16):
			dut.gcm_sci.value[i*8:(i+1)*8] = b
		dut.gcm_sram_v.value = i in range(16, 48)  		 	
		dut.gcm_sram_k.value = i in range(16,32) 	
		dut.gcm_sram_h.value = i in range(32,48) 
		dut.gcm_sram.value = b
		ClockCyclest(dut.clk, 1) 
	dut.gcm_sram_v.value = 0		

async def set_random_config(dut): 
	dut.gcm_init.value = 1
	ClockCyclest(dut.clk, 1) 
	dut.gcm_init.value = 0
	conf = sram.random()
	await wr_sram_config(dut, conf) 
	
	
