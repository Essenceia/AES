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

from array import array 

import os

GATES = os.getenv("GATES", False)

CLK_UNIT="ns"
CLK_PERIOD=20
RST_CYCLES=10

TXT_W = 128
KEY_W = 128 

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
	aes_utils.set_all_enc(dut, 0, "X"*TXT_W, 0, "X"*KEY_W)
	clk_task = start_clk(dut)
	await ClockCycles(dut.clk, RST_CYCLES)
	dut.rst_n.value = 1
	await ClockCycles(dut.clk, 20)

		
# test for stupidity, oh yes, very postitive 
@cocotb.test()
async def simple_test(dut):
	set_random_seed()
	await rst(dut) 
	ptxt = LogicArray.from_bytes(b'\x32\x43\xf6\xa8\x88\x5a\x30\x8d\x31\x31\x98\xa2\xe0\x37\x07\x34', byteorder="big")
	key  = LogicArray.from_bytes(b'\x2b\x7e\x15\x16\x28\xae\xd2\xa6\xab\xf7\x15\x88\x09\xcf\x4f\x3c', byteorder="big")
	await aes_utils.enc(dut, ptxt, key)
	await ClockCycles(dut.clk, 10)


