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
	dut.gcm_rx_first.value = "X"
	dut.gcm_rx_enc.value = "X"
	dut.gcm_rx_enc_early.value = "X"
	dut.gcm_rx_last.value = "X"
	dut.gcm_rx.value = "X"*2

async def wr_sram_config(dut, conf: sram_config):
	raw_config = bytearray(b'')
	raw_config += conf.raw()
	dut.gcm_pn.value = "X" * 32
	dut.gcm_sci.value = "X" * 64

	pn  = dut.gcm_pn.value 
	sci = dut.gcm_sci.value 
	s = dut.gcm_sram.value
	cocotb.log.info(f"writing sram config {conf}")
	for i, b in enumerate(raw_config):
		if i in range(0,4): # 32 lsb of PN
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
	cocotb.log.info("config wr finished") 	

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
	cocotb.log.info(f"data 0x{data.hex()} A_length={a_l} ({a_l*8}b), C_length={l - a_l} ({(l-a_l)*8}b)")
	for i in range(0, l*4): 
		dut.gcm_rx_v.value = 1 
		if i % 4 == 0:
			b = data[int(i/4)]  
		dut.gcm_rx.value =0x3 & (b >> (i%4)*2)
		dut.gcm_rx_first.value = 1 if i == 0 else 0 
		dut.gcm_rx_last.value = 1 if i == 4*l-1 else 0 
		dut.gcm_rx_enc_early.value = 1 if i in range(a_l*4-1, l*4-1) else 0
		dut.gcm_rx_enc.value = 1 if i in range(a_l*4, l*4) else 0
		await ClockCycles(dut.clk, 1)
	dut.gcm_rx_v.value = 0 
	dut.gcm_rx_enc_early.value = "X"
	dut.gcm_rx_enc.value = "X"
	dut.gcm_rx_first.value = "X"
	dut.gcm_rx_last.value = "X"
	dut.gcm_rx.value = "X"*2
	cocotb.log.info("set_data finished") 	

async def read_data(dut):
	res = bytearray(b'')
	b = 0
	i = 0
	t = 0
	cocotb.log.info("rd data start") 	
	while (t < TIMEOUT):
		if (dut.gcm_tx_v.value == 1):
			tmp = int(dut.gcm_tx.value)
			b = b | (tmp << 2*(i%4)) 
			if i % 4 == 3:
				cocotb.log.info(f"{int(i/4)} {hex(b)}") 
				res.append(b) 
				b = 0	
			i = i + 1
			if dut.gcm_tx_last.value == 1:
				break
		t = t + 1
		await ClockCycles(dut.clk, 1)	
	await ClockCycles(dut.clk, 1) # prevent capturing previous data rd end	
	return res

async def send_data_check_result(dut, data: bytearray, config:sram_config, a_l:int): 

	# trigger threads at the time 	
	conf = cocotb.start_soon(set_config(dut, config))
	rd = cocotb.start_soon(read_data(dut))
	await ClockCycles(dut.clk, 1) # wait for init cycle 
	wr = cocotb.start_soon(set_data(dut, data, a_l)) 
	await conf
	await wr
	result = await rd
	cocotb.log.info(f"res  0x{result.hex()} length={len(result)}")
	check_result(plain=data, config=config, a_l=a_l, result=result)

def check_result(plain: bytearray, config:sram_config, a_l:int, result:bytearray):
	assert (len(plain) + 16) == len(result), f"length of reults is expact to be 16 longer than length of original expected {len(plain)+16} got {len(result)}" 
	match = True	

	cipher = AES.new(config.k, AES.MODE_GCM, nonce=config.get_iv())
	cipher.update(plain[0:a_l])
	exp_c, exp_t = cipher.encrypt_and_digest(plain[a_l:])
	expected_res = plain[0:a_l] + exp_c + exp_t
	cocotb.log.info(f"cipher 0x{exp_c.hex()}")
	cocotb.log.info(f"tag    0x{exp_t.hex()}")

	got_p = result[:a_l]
	exp_p = plain[:a_l]
	if got_p != exp_p: 
		cocotb.log.error(f"missmatch plain\n\tgot: 0x{got_p.hex()}\n\texp: 0x{exp_p.hex()}")
		match = False

	l = len(plain)
	got_c = result[a_l:l]
	if got_c != exp_c: 
		cocotb.log.error(f"missmatch C\n\tgot: 0x{got_c.hex()}\n\texp: 0x{exp_c.hex()}")
		match = False

	got_t = result[-16:]
	if got_t != exp_t:
		cocotb.log.error(f"missmatch tag\n\tgot: 0x{got_t.hex()}\n\texp: 0x{exp_t.hex()}")
		match = False
		# calculate inner aes
		J0 = config.get_iv() + b'\x00\x00\x00\x01'
		assert(len(J0) == 16)
		k = config.k
		inner_aes = AES.new(k, AES.MODE_ECB)
		tag_aes = inner_aes.encrypt(J0)
		tag_ghash = bytearray(16)
		for i in range(len(exp_t)): 
			tag_ghash[i] = tag_aes[i] ^ exp_t[i]
		cocotb.log.error(f"\nexp tag aes: 0x{tag_aes.hex()}\nexp tag gh:  0x{tag_ghash.hex()}")
	
	assert match, "missmatch between expected and gotten"
		
