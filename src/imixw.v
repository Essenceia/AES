`timescale 1ns / 1ps
// gm2
module gm2(
	input  [7:0] op_i,
	output [7:0] gm2_o
	);
	assign gm2_o = {op_i[6 : 0], 1'b0} ^ (8'h1b & {8{op_i[7]}});
endmodule

// gm4
module gm4(
	input  [7:0] op_i,
	output [7:0] gm4_o
	);
	wire [7:0] gm2_p0;
	wire [7:0] gm2_p1;
	gm2 m_gm2_p0(.op_i(op_i),   .gm2_o(gm2_p0));
	gm2 m_gm2_p1(.op_i(gm2_p0), .gm2_o(gm2_p1));
	// gm4 = gm2(gm2(op));
	assign gm4_o = gm2_p1;
endmodule

// gm8
module gm8(
	input  [7:0] op_i,
	output [7:0] gm8_o
	);
	wire [7:0] gm2;
	wire [7:0] gm4;
	gm4 m_gm4(.op_i(op_i), .gm4_o(gm4));
	gm2 m_gm2(.op_i(gm4),  .gm2_o(gm2));
	// gm8 = gm2(gm4(op));
	assign gm8_o = gm2;
endmodule

// gm09
module gm09(
	input  [7:0] op_i,
	output [7:0] gm09_o
	);
	wire [7:0] gm8;
	gm8 m_gm8(.op_i(op_i), .gm8_o(gm8));
	// gm09 = gm8(op) ^ op;
	assign gm09_o = gm8 ^ op_i;
endmodule 

// gm11
module gm11(
	input  [7:0] op_i,
	output [7:0] gm11_o
	);
	wire [7:0] gm2;
	wire [7:0] gm8;
	gm8 m_gm8(.op_i(op_i), .gm8_o(gm8));
	gm2 m_gm2(.op_i(op_i), .gm2_o(gm2));
	// gm11 = gm8(op) ^ gm2(op) ^ op;
	assign gm11_o = gm8 ^ gm2 ^ op_i;
endmodule

// gm13
module gm13(
	input  [7:0] op_i,
	output [7:0] gm13_o
	);
	wire [7:0] gm4;
	wire [7:0] gm8;
	gm8 m_gm8(.op_i(op_i), .gm8_o(gm8));
	gm4 m_gm4(.op_i(op_i), .gm4_o(gm4));
	// gm13 = gm8(op) ^ gm4(op) ^ op;
	assign gm13_o = gm8 ^ gm4 ^ op_i;
endmodule

// gm14
module gm14(
	input  [7:0] op_i,
	output [7:0] gm14_o
	);
	wire [7:0] gm2;
	wire [7:0] gm4;
	wire [7:0] gm8;
	gm8 m_gm8(.op_i(op_i), .gm8_o(gm8));
	gm4 m_gm4(.op_i(op_i), .gm4_o(gm4));
	gm2 m_gm2(.op_i(op_i), .gm2_o(gm2));
	// gm13 = gm8(op) ^ gm4(op) ^ op;
	assign gm14_o = gm8 ^ gm4 ^ gm2;
endmodule  

module imixw(
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
   
	wire [7:0] gm09_b0;
	wire [7:0] gm09_b1;
	wire [7:0] gm09_b2;
	wire [7:0] gm09_b3;

	wire [7:0] gm11_b0;
	wire [7:0] gm11_b1;
	wire [7:0] gm11_b2;
	wire [7:0] gm11_b3;

	wire [7:0] gm13_b0;
	wire [7:0] gm13_b1;
	wire [7:0] gm13_b2;
	wire [7:0] gm13_b3;

	wire [7:0] gm14_b0;
	wire [7:0] gm14_b1;
	wire [7:0] gm14_b2;
	wire [7:0] gm14_b3;

	gm09 m_gm09_b0(.op_i(b0), .gm09_o(gm09_b0));
	gm09 m_gm09_b1(.op_i(b1), .gm09_o(gm09_b1));
	gm09 m_gm09_b2(.op_i(b2), .gm09_o(gm09_b2));
	gm09 m_gm09_b3(.op_i(b3), .gm09_o(gm09_b3));

	gm11 m_gm11_b0(.op_i(b0), .gm11_o(gm11_b0));
	gm11 m_gm11_b1(.op_i(b1), .gm11_o(gm11_b1));
	gm11 m_gm11_b2(.op_i(b2), .gm11_o(gm11_b2));
	gm11 m_gm11_b3(.op_i(b3), .gm11_o(gm11_b3));

	gm13 m_gm13_b0(.op_i(b0), .gm13_o(gm13_b0));
	gm13 m_gm13_b1(.op_i(b1), .gm13_o(gm13_b1));
	gm13 m_gm13_b2(.op_i(b2), .gm13_o(gm13_b2));
	gm13 m_gm13_b3(.op_i(b3), .gm13_o(gm13_b3));

	gm14 m_gm14_b0(.op_i(b0), .gm14_o(gm14_b0));
	gm14 m_gm14_b1(.op_i(b1), .gm14_o(gm14_b1));
	gm14 m_gm14_b2(.op_i(b2), .gm14_o(gm14_b2));
	gm14 m_gm14_b3(.op_i(b3), .gm14_o(gm14_b3));
		
	assign b3 = w_i[31 : 24];
	assign b2 = w_i[23 : 16];
	assign b1 = w_i[15 : 08];
	assign b0 = w_i[07 : 00];

	assign mb0 = gm14_b0 ^ gm11_b1 ^ gm13_b2 ^ gm09_b3;
	assign mb1 = gm09_b0 ^ gm14_b1 ^ gm11_b2 ^ gm13_b3;
	assign mb2 = gm13_b0 ^ gm09_b1 ^ gm14_b2 ^ gm11_b3;
	assign mb3 = gm11_b0 ^ gm13_b1 ^ gm09_b2 ^ gm14_b3;
	
	assign mixw_o = {mb3, mb2, mb1, mb0};
endmodule



