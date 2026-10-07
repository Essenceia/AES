from sram import sram_config

import cocotb
from cocotb.triggers import ClockCycles 

import Crypto
from Crypto.Cipher import AES

import random 

TIMEOUT = 2000

def set_invalid(dut): 
	dut.gcm_init.value = 0 
	dut.gcm_pn.value = "X" * 32
	dut.gcm_sci.value = "X" * 64
	dut.gcm_sram_v.value = 0 
	dut.gcm_sram_k.value = "X"
	dut.gcm_sram_h.value = "X"
	dut.gcm_sram.value = "X"*16
	dut.gcm_rx_v.value = 0	
	dut.gcm_rx_enc.value = "X"
	dut.gcm_rx_last.value = "X"
	dut.gcm_rx.value = "X"*2

async def wr_sram_config(dut, conf: sram_config):
	raw_config = bytearray(b'')
	raw_config += conf.raw()
	dut.gcm_pn.value = "X" * 32
	dut.gcm_sci.value = "X" * 64

	pn = dut.gcm_pn.value 
	sci = dut.gcm_sci.value 
	s = dut.gcm_sram.value
	cocotb.log.info(f"writing sram config {conf}")
	for i, b in enumerate(raw_config):
		if i in range(4,8): # 32 lsb of PN
			pn[31:8] = pn[23:0] 
			pn[7:0] = b
			dut.gcm_pn.value = pn
		if i in range(8,16):
			sci[63:8] = sci[63-8:0]
			sci[7:0] = b
			dut.gcm_sci.value = sci
		dut.gcm_sram_v.value = i in range(16, 48)  		 	
		dut.gcm_sram_k.value = i in range(16,32) 	
		dut.gcm_sram_h.value = i in range(32,48) 
		s[((i+1)%2+1)*8-1:((i+1)%2)*8] = b
		dut.gcm_sram.value = s
		if i % 2 == 1:
			await ClockCycles(dut.clk, 1) 
	dut.gcm_sram_h.value = "X"		
	dut.gcm_sram_k.value = "X"		
	dut.gcm_sram.value = "X" * 16 		
	dut.gcm_sram_v.value = 0		

async def set_random_config(dut): 
	conf = sram_config()
	conf.random()
	await set_config(conf)	

async def set_config(dut, conf: sram_config): 
	dut.gcm_init.value = 1
	await ClockCycles(dut.clk, 1) 
	dut.gcm_init.value = 0
	await wr_sram_config(dut, conf) 

# assuming no bubble in data 
async def set_data(dut, data:bytearray, a_l:int):
	l = len(data)
	assert(a_l <= l)
	assert(l >= 14)
	cocotb.log.info(f"data 0x{data.hex()} A_length={a_l}")
	for i in range(0, l*4): 
		dut.gcm_rx_v.value = 1 
		if i % 4 == 0: 
			b = data[int(i/4)]  
		dut.gcm_rx.value =0x3 & (b >> (i%4)*2)
		dut.gcm_rx_last.value = 1 if i == 4*l-1 else 0 
		dut.gcm_rx_enc.value = i in range(a_l*4, l*4)
		await ClockCycles(dut.clk, 1)
	dut.gcm_rx_v.value = 0 
	dut.gcm_rx_enc.value = "X"
	dut.gcm_rx_last.value = "X"
	dut.gcm_rx.value = "X"*2

async def read_data(dut):
	res = bytearray(b'')
	b = 0
	i = 0
	t = 0
	while (t < TIMEOUT):
		if (dut.gcm_tx_v.value == 1):
			tmp = int(dut.gcm_tx.value)
			b = b | (tmp << 2*(i%4)) 
			if i % 4 == 3: 
				res.append(b) 
				b = 0	
			i = i + 1
		t = t + 1
		if (dut.gcm_tx_v.value == 1 and dut.gcm_tx_last.value == 1):
			break
		await ClockCycles(dut.clk, 1)	
	return res

async def send_data(dut, data: bytearray, a_l:int): 
	# trigger both threads at the time 	
	wr = cocotb.start_soon(set_data(dut, data, a_l)) 
	rd = cocotb.start_soon(read_data(dut))
	await wr
	result = await rd
	cocotb.log.info(f"res  0x{result.hex()} length={len(result)}")
	check_result(data, a_l, result)

def check_result(plain: bytearray, a_l:int, result:bytearray):
	assert (len(plain) + 16) == len(result), f"length of reults is expact to be 16 longer than length of original expected {len(plain)+16} got {len(result)}" 
	key = random.randbytes(16)
	cipher = AES.new(key, AES.MODE_GCM)
	cipher.update(plain[0:a_l])
	ciphertext, tag = cipher.encrypt_and_digest(plain[a_l:])
	expected_res = plain[0:a_l] + ciphertext + tag
	cocotb.log.info(f"cipher 0x{ciphertext.hex()}")
	cocotb.log.info(f"tag    0x{tag.hex()}")
	assert expected_res == result, f"missmatch\ngot: 0x{result.hex()}\nexp: 0x{expected_res.hex()}"	
