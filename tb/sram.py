import random
from dataclasses import dataclass, field

@dataclass
class sram_config: 
	pn: bytes  = field(default_factory= lambda: bytes(8)) #64b 
	sci: bytes = field(default_factory= lambda: bytes(8)) 
	k: bytes   = field(default_factory= lambda: bytes(16)) # 128 for now
	h: bytes   = field(default_factory= lambda: bytes(16)) 

	def random(self): 
		self.pn = random.randbytes(8) 
		self.sci = random.randbytes(8) 
		self.k = random.randbytes(16) 
		self.h = random.randbytes(16) 
	def raw(self) -> bytearray:
		r = bytearray()
		r += self.pn 
		r += self.sci 
		r += self.k
		r += self.h 
		return r
	def __str__(self) -> str: 
		return f"sram_config:\n\tpn= {self.pn.hex()}\n\tsci={self.sci.hex()}\n\tk=  {self.k.hex()}\n\th=  {self.h.hex()}\n"
