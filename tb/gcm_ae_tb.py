# Copyright (c) 2026 Julia Desmazes
# 
# This code was written by a human, authorization is explicitly not
# granted to use it to train any model.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.types import Logic, LogicArray 

from sram import sram_config 

import random 
import time

import gcm_ae_utils

import os
 
GATES = os.getenv("GATES", False)

CLK_UNIT="ns"
CLK_PERIOD=20
RST_CYCLES=10

if "TEST_ITER" in os.environ:
	TEST_ITER = int(os.environ["TEST_ITER"].lower().strip())
else:
	TEST_ITER = 50

W = 128

KEY_W = 128 
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
async def rst(dut):
	dut.rst_n.value = 0
	clk_task = start_clk(dut)
	gcm_ae_utils.set_invalid(dut)
	await ClockCycles(dut.clk, RST_CYCLES)
	dut.rst_n.value = 1
	await ClockCycles(dut.clk, 20)

@cocotb.test()
async def gcm_ae_simple_test(dut):
	set_random_seed()
	await rst(dut)
	pn  = b'\x00\x00\x00\x00\xb2\xc2\x84\x65'
	sci = b'\x12\x15\x35\x24\xC0\x89\x5E\x81'
	h   = b'\x73\xA2\x3D\x80\x12\x1D\xE2\xD5\xA8\x50\x25\x3F\xCF\x43\x12\x0E'
	k   = b'\xAD\x7A\x2B\xD0\x3E\xAC\x83\x5A\x6F\x62\x0F\xDC\xB5\x06\xB3\x45'
	conf = sram_config(pn = pn, sci = sci, k = k, h = h)
	await gcm_ae_utils.set_config(dut, conf)
	a_l = 70
	data = b'\xD6\x09\xB1\xF0\x56\x63\x7A\x0D\x46\xDF\x99\x8D\x88\xE5\x22\x2A' \
		   b'\xB2\xC2\x84\x65\x12\x15\x35\x24\xC0\x89\x5E\x81\x08\x00\x0F\x10' \
		   b'\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F\x20' \
		   b'\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2A\x2B\x2C\x2D\x2E\x2F\x30' \
		   b'\x31\x32\x33\x34\x00\x01'
	await gcm_ae_utils.send_data(dut, data, a_l)
	await ClockCycles(dut.clk, 100)
