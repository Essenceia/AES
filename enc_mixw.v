`timescale 1ns / 1ps
//----------------------------------------------------------------
// Mix column : Galois Field Arithmetic 
//----------------------------------------------------------------
 
module aes_gm2(
	input  [7:0] op_i,
	output [7:0] gm2_o
	);
   
 assign gm2_o = {op_i[6 : 0], 1'b0} ^ (8'h1b & {8{op_i[7]}});

endmodule // gm2

// Multiply by 3
 module aes_gm3(
	input  [7:0] op_i,
	output [7:0] gm3_o
	);
	wire [7:0] gm2;
	
	aes_gm2 m_gm2(.op_i(op_i), .gm2_o(gm2));
	
   assign gm3_o = gm2 ^ op_i;

 endmodule // gm3

 module aes_mixw(
	input  [31:0] w_i,
	output [31:0] mixw_o
	);
	wire [7:0] b0;
	wire [7:0] b1;
	wire [7:0] b2;
	wire [7:0] b3;
	wire [7:0] mb0;
	wire [7:0] mb1;
	wire [7:0] mb2;
	wire [7:0] mb3;
	
	// mb0
	wire [7:0] gm2_b0;
	wire [7:0] gm3_b1;
	// mb1
	wire [7:0] gm2_b1;
	wire [7:0] gm3_b2;
	// mb2
	wire [7:0] gm2_b2;
	wire [7:0] gm3_b3;
	// mb3
	wire [7:0] gm2_b3;
	wire [7:0] gm3_b0;
 
	assign b3 = w_i[31 : 24];
	assign b2 = w_i[23 : 16];
	assign b1 = w_i[15 : 8];
	assign b0 = w_i[07 : 0];
	
	// mb0
	aes_gm2 m0_gm2(.op_i(b0), .gm2_o(gm2_b0));
	aes_gm3 m0_gm3(.op_i(b1), .gm3_o(gm3_b1));
	// mb1
	aes_gm2 m1_gm2(.op_i(b1), .gm2_o(gm2_b1));
	aes_gm3 m1_gm3(.op_i(b2), .gm3_o(gm3_b2));
	//mb2
	aes_gm2 m2_gm2(.op_i(b2), .gm2_o(gm2_b2));
	aes_gm3 m2_gm3(.op_i(b3), .gm3_o(gm3_b3));
	// mb3
	aes_gm3 m3_gm3(.op_i(b0), .gm3_o(gm3_b0));
	aes_gm2 m3_gm2(.op_i(b3), .gm2_o(gm2_b3));

	assign mb0 = gm2_b0  ^ gm3_b1  ^ b2      ^ b3;
	assign mb1 = b0      ^ gm2_b1  ^ gm3_b2  ^ b3;
	assign mb2 = b0      ^ b1      ^ gm2_b2  ^ gm3_b3;
	assign mb3 = gm3_b0  ^ b1      ^ b2      ^ gm2_b3;

	assign mixw_o = {mb3, mb2, mb1, mb0};
 
 endmodule // mixw
