import random
from typing import NamedTuple


class sram_config(NamedTuple): 
	pn: bytes = bytes(8) #64b 
	sci: bytes = bytes(8) 
	k: bytes = bytes(16) # 128 for now
	h: bytes = bytes(16) 

	def random(self): 
		self.pn = random.randbytes(8) 
		self.sci = random.randbytes(8) 
		self.k = random.randbytes(16) 
		self.h = random.randbytes(16) 
