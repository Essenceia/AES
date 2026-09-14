`timescale 1ns / 1ps
// static void aes128_key_schedule_inv_round(uint8_t p_key[AES128_KEY_SIZE], uint8_t rcon)
// {
//     uint_fast8_t    round;
//     uint8_t       * p_key_0 = p_key + AES128_KEY_SIZE - AES_KEY_SCHEDULE_WORD_SIZE;
//     uint8_t       * p_key_m1 = p_key_0 - AES_KEY_SCHEDULE_WORD_SIZE;
// 
//     for (round = 1; round < AES128_KEY_SIZE / AES_KEY_SCHEDULE_WORD_SIZE; ++round)
//     {
//         /* XOR in previous word */
//         p_key_0[0] ^= p_key_m1[0];
//         p_key_0[1] ^= p_key_m1[1];
//         p_key_0[2] ^= p_key_m1[2];
//         p_key_0[3] ^= p_key_m1[3];
// 
//         p_key_0 = p_key_m1;
//         p_key_m1 -= AES_KEY_SCHEDULE_WORD_SIZE;
//     }
// 
//     /* Rotate previous word and apply S-box. Also XOR Rcon for first byte. */
//     p_key_m1 = p_key + AES128_KEY_SIZE - AES_KEY_SCHEDULE_WORD_SIZE;
//     p_key_0[0] ^= aes_sbox(p_key_m1[1]) ^ rcon;
//     p_key_0[1] ^= aes_sbox(p_key_m1[2]);
//     p_key_0[2] ^= aes_sbox(p_key_m1[3]);
//     p_key_0[3] ^= aes_sbox(p_key_m1[0]);
// }

module aes_inv_key_first_col(
	input  wire [31:0] key_w3_i,
	input  wire [7:0]  key_rcon_i,
	output wire [31:0] key_w3_next_o,
	output wire [7:0]  key_rcon_o
	);
	
	wire [31:0] key_rot;
	wire [31:0] key_sbox;
	wire [31:0] key_xor;
	wire [7:0]  rcon_next;
	wire [7:0]  rcon_next_pq;
	wire        rcon_is27;
	
	// rotation, shift right by 8b
	assign key_rot[31:24] = key_w3_i[7:0];
	assign key_rot[23:16] = key_w3_i[31:24];
	assign key_rot[15:8]  = key_w3_i[23:16];
	assign key_rot[7:0]   = key_w3_i[15:8];
	// sbox
	genvar i;
	generate
		for(i=0; i<4; i=i+1) begin : loop_gen_key_sbox
			sbox key_sbox(
				.data_i(key_rot[(i*8)+7:(i*8)]),
				.data_o(key_sbox[(i*8)+7:(i*8)])
			);
		end
	endgenerate

	assign key_xor           = { key_sbox[31:8] ,  key_rcon_i ^ key_sbox[7:0] };
	assign rcon_is27         =  key_rcon_i[1] & key_rcon_i[0]; // XXXX_XX11
	assign rcon_next_pq[7:0] = {  1'b0 , key_rcon_i[7:1]}; // shift right
	assign rcon_next         = ( {8{ rcon_is27}} & 8'h80 ) // rcon == x1b then rcon_next = x80  
				 | ( {8{~rcon_is27}} & rcon_next_pq);
	// output
	assign key_w3_next_o   = key_xor;
	assign key_rcon_o[7:0] = rcon_next[7:0];
endmodule // aes_key_first_col

module iks(
	input  wire [127:0] key_i,
	input  wire [7:0]   key_rcon_i,
	output wire [127:0] key_next_o,
	output wire [7:0]   key_rcon_o
	);
	wire [31:0] key_col[3:0];
	wire [31:0] key_col_xor[3:0];
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
			assign key_next_o[(i*32)+31:(i*32)] = key_col_xor[i];
		end
	endgenerate
	assign key_col_xor[3] = key_col[2] ^ key_col[3];
	assign key_col_xor[2] = key_col[1] ^ key_col[2];
	assign key_col_xor[1] = key_col[0] ^ key_col[1];

	// special treatement for the first colon ( 3rd one in our case )
	aes_inv_key_first_col aes_inv_key_w3(
		.key_w3_i(      key_col_xor[3]),
		.key_rcon_i(    key_rcon_i),
		.key_w3_next_o( key_col_w3),
		.key_rcon_o(    key_rcon_next)
	);
	assign key_col_xor[0] = key_col[0] ^ key_col_w3; 

	// output new rcon
	assign key_rcon_o = key_rcon_next;

endmodule // aes_key_shedualing


