`timescale 1ns / 1ps

// module to calcule the first column of the new key
// implements : rotation + sbox + xor 
module aes_key_first_col(
	input  wire [31:0] key_w3_i,
	input  wire [7:0]  key_rcon_i,
	output wire [31:0] key_w3_next_o,
	output wire [7:0]  key_rcon_o
	);
	
	wire [31:0] key_rot;
	wire [31:0] key_sbox;
	wire [31:0] key_xor;
	wire [7:0]  rcon_next;
	wire [7:0]  debug_rcon_next;
	wire        rcon_overflow;
	
	// rotation, shift left by 8b, eg : [l:h] abcd -> bcda 
	assign key_rot[31:24] = key_w3_i[7:0];
	assign key_rot[23:16] = key_w3_i[31:24];
	assign key_rot[15:8]  = key_w3_i[23:16];
	assign key_rot[7:0]   = key_w3_i[15:8];
	// sbox
	genvar i;
	generate
		for(i=0; i<4; i=i+1) begin : loop_gen_key_sbox
			sbox m_key_sbox(
				.data_i(key_rot[(i*8)+7:(i*8)]),
				.data_o(key_sbox[(i*8)+7:(i*8)])
			);
		end
	endgenerate
	// xor, multiplied by rcon(round) :
	//{ x01, x02, x04, x08, x10, x20, x40, x80, x1b, x36 }
	//{ 0000_0001, 0000_0010,  0000_0100, 0000_1000,
	//  0001_0000, 0010_0000,  0100_0000, 1000_0000,
	//  0001_1011, 0011_0110 }
	// only xor the msb Byte with the rcon
	assign key_xor         = { key_sbox[31:8], key_sbox[7:0] ^ key_rcon_i };
	assign rcon_overflow   = key_rcon_i[7];
	assign rcon_next[7:0]  = { key_rcon_i[6:0], 1'b0} ;
	assign debug_rcon_next = ( {8{ rcon_overflow}} & 8'h1b ) 
			       			| ( {8{~rcon_overflow}} & rcon_next);
			
	// output
	assign key_w3_next_o   = key_xor;
	assign key_rcon_o[7:0] = debug_rcon_next[7:0];
	
endmodule // aes_key_first_col

module ks(
	input  wire [127:0] key_i,
	input  wire [7:0]   key_rcon_i,
	output wire [127:0] key_next_o,
	output wire [7:0]   key_rcon_o
	);
	wire [31:0] key_col[3:0];
	wire [31:0] key_col_w3;
	wire [31:0] key_col_next[3:0];
	wire [7:0]  key_rcon_next;
		
	// get colons and format back to array after calculations are finished
	genvar i; // row
	generate
		for(i=0; i<4; i=i+1) begin : loop_gen_key_col
			// input
			assign key_col[i] = key_i[(i*32)+31:(i*32)];
			// output
			assign key_next_o[(i*32)+31:(i*32)] = key_col_next[i];
		end
	endgenerate
	// special treatement for the first colon ( 3rd one in our case )
	aes_key_first_col aes_key_w3(
		.key_w3_i(key_col[3]),
		.key_rcon_i(key_rcon_i),
		.key_w3_next_o(key_col_w3),
		.key_rcon_o(key_rcon_next)
	);
	assign key_col_next[0] = key_col[0] ^ key_col_w3;
	// colon 2, 1, 0
	assign key_col_next[1] = key_col_next[0] ^ key_col[1];
	assign key_col_next[2] = key_col_next[1] ^ key_col[2];
	assign key_col_next[3] = key_col_next[2] ^ key_col[3];
	
	// output new rcon
	assign key_rcon_o = key_rcon_next;

endmodule // aes_key_shedualing
