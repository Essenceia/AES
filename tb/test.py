# Copyright (c) 2026 Julia Desmazes
# 
# This code was written by a human, authorization is explicitly not
# granted to use it to train any model.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout
from cocotb.types import Logic, LogicArray 

import random 
import asyncio
import time

import aes_utils
import ghash_utils 

from array import array 

import os

GATES = os.getenv("GATES", False)

CLK_UNIT="ns"
CLK_PERIOD=20
RST_CYCLES=10

if "TEST_ITER" in os.environ:
	TEST_ITER = int(os.environ["TEST_ITER"].lower().strip())
else:
	TEST_ITER = 50

TXT_W = 128
KEY_W = 128 
COL_W = 32
TXT_BYTES_W = 16

def start_clk(dut):
	clock = Clock(dut.clk, CLK_PERIOD, CLK_UNIT)
	clk_task = cocotb.start_soon(clock.start()) #runs the clock "in the background" 
	return clk_task

def set_random_seed():
	if "SEED" in os.environ:
		seed = int(os.environ["SEED"].lower().strip())
	else:
		seed = time.time_ns()
	cocotb.log.info(f"random seed {seed}")
	random.seed(seed)

# Reset sequence
async def rst(dut, ena=1 ):
	dut.rst_n.value = 0
	dut.enc_data_v.value = 'X'
	dut.enc_key_v.value  = 'X'
	aes_utils.set_enc_invalid_data(dut)
	clk_task = start_clk(dut)
	await ClockCycles(dut.clk, RST_CYCLES)
	dut.enc_data_v.value = 0
	dut.enc_key_v.value = 0
	ghash_utils.set_enc_invalid_data(dut)
	dut.rst_n.value = 1
	await ClockCycles(dut.clk, 20)

		
# test for stupidity, oh yes, very postitive 
# NIST 197 example cipher result
@cocotb.test()
async def simple_test(dut):
	set_random_seed()
	await rst(dut)
	for _ in range(2): # test state is correctly wipped between each run 
		ptxt = b'\x32\x43\xf6\xa8\x88\x5a\x30\x8d\x31\x31\x98\xa2\xe0\x37\x07\x34'
		key  = b'\x2b\x7e\x15\x16\x28\xae\xd2\xa6\xab\xf7\x15\x88\x09\xcf\x4f\x3c'
		await aes_utils.enc128(dut, ptxt, key)

@cocotb.test()
async def random_test(dut):
	set_random_seed() # for reporducibility (so that I have lots of children to spoil at Christmas)
	await rst(dut)
	for _ in range(TEST_ITER):
		ptxt = random.randbytes(TXT_BYTES_W)
		key = random.randbytes(TXT_BYTES_W)
		await aes_utils.enc128(dut, ptxt, key)

@cocotb.test()
async def ghash_single_block_test(dut): 
	set_random_seed()
	await rst(dut)
	for i in range(0, TEST_ITER): 
		ptxt = i.to_bytes(1, 'big') + b'\x00'*15
		key = i.to_bytes(1, 'big') + b'\x00'*15
		await ghash_utils.hash(dut, ptxt, key)

@cocotb.test()
async def ghash_random_single_block_test(dut): 
	set_random_seed()
	await rst(dut)
	for i in range(0, TEST_ITER): 
		ptxt = random.randbytes(16)
		key = random.randbytes(16)
		await ghash_utils.hash(dut, ptxt, key)

