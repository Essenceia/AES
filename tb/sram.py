import Crypto
from Crypto.Cipher import AES

import random
from dataclasses import dataclass, field

@dataclass
class sram_config: 
	pn:  bytes = field(default_factory= lambda: bytes(8)) #64b 
	sci: bytes = field(default_factory= lambda: bytes(8)) 
	k:   bytes = field(default_factory= lambda: bytes(16)) # 128 for now
	h:   bytes = field(default_factory= lambda: bytes(16)) 

	def __init__(self, pn: bytes(8), sci:bytes(8), k:bytes(16)):
		self.pn = pn
		self.sci = sci 
		self.k = k 
		# H is the result of AES(K, 0)	
		cipher = AES.new(k, AES.MODE_ECB)
		self.h = cipher.encrypt(bytearray(16))

	def raw(self) -> bytearray:
		r = bytearray()
		r += self.pn 
		r += self.sci 
		r += self.k
		r += self.h 
		return r
	def __str__(self) -> str: 
		return f"sram_config:\n\tpn= {self.pn.hex()}\n\tsci={self.sci.hex()}\n\tiv= {self.get_iv().hex()}\n\tk=  {self.k.hex()}\n\th=  {self.h.hex()}\n"
	
	def get_iv(self) -> bytearray:
		iv = bytearray()
		iv += self.sci
		iv += self.pn[0:4]
		assert(len(iv) == 12)
		return iv

def create_random_config() -> sram_config: 
	pn = random.randbytes(8) 
	sci = random.randbytes(8) 
	k = random.randbytes(16) 
	conf = sram_config(pn=pn, sci = sci, k = k)
	return conf 





