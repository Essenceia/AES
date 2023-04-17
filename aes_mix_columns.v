`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    06:44:26 10/26/2021 
// Design Name: 
// Module Name:    aes_mix_columns 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

 //----------------------------------------------------------------
  // Round functions with sub functions.
  //----------------------------------------------------------------
 module aes_gm2(
	input  [7:0] op_i,
	output [7:0] gm2_o
	);
   
   assign gm2_o = {op_i[6 : 0], 1'b0} ^ (8'h1b & {8{op_i[7]}});

endmodule // gm2

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
 
	assign b0 = w_i[31 : 24];
	assign b1 = w_i[23 : 16];
	assign b2 = w_i[15 : 8];
	assign b3 = w_i[07 : 0];
	
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

	assign mixw_o = {mb0, mb1, mb2, mb3};
 
 endmodule // mixw


  
//module aes_mix_columns(
//    input  [31 : 0] data_col_i[3:0],
//    output [31 : 0] data_col_o[3:0]
//    );
	 
//	wire [31:0] mix_columns[3:0];
	
	//aes_mixw mixw3( .w_i(data_i[127:96]), .mixw_o(mix_columns[127:96]));
	//aes_mixw mixw2( .w_i(data_i[95:64]),  .mixw_o(mix_columns[95:64]));
	//aes_mixw mixw1( .w_i(data_i[63:32]),  .mixw_o(mix_columns[63:32]));
	//aes_mixw mixw0( .w_i(data_i[31:0]),   .mixw_o(mix_columns[31:0]));

//	aes_mixw mixw3( .w_i(data_col_i[3]), .mixw_o(data_col_o[3]));
//	aes_mixw mixw2( .w_i(data_col_i[2]), .mixw_o(data_col_o[2]));
//	aes_mixw mixw1( .w_i(data_col_i[1]), .mixw_o(data_col_o[1]));
//	aes_mixw mixw0( .w_i(data_col_i[0]), .mixw_o(data_col_o[0]));
	
//endmodule
