# Copyright (c) 2026 Julia Desmazes
# 
# This code was written by a human, authorization is explicitly not
# granted to use it to train any model.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.types import Logic, LogicArray 

import random 

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
	await ClockCycles(dut.clk, RST_CYCLES)
	dut.rst_n.value = 1
	await ClockCycles(dut.clk, 20)

@cocotb.test()
async def gcm_ae_simple_test(dut):
	set_random_seed()
	rst(dut)
	ClockCycles(dut.clk, 100)
