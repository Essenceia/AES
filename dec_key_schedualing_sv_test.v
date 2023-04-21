`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   15:04:40 10/26/2021
// Design Name:   aes_key_shedualing
// Module Name:   /home/ise/Documents/test_ase_1/aes_key_schedual_sv_test.v
// Project Name:  test_ase_1
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: aes_key_shedualing
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module aes_inv_key_schedual_sv_test;

	wire [127:0] key_next;
	reg  [127:0] key_q;
	wire [127:0] debug_key_next;
	reg  [127:0] debug_key_q;
	wire [7:0]   key_rcon_next;
	reg  [127:0] error_v;
	reg  [7:0]   key_rcon_q;
	reg clk;
	reg nreset;
	wire [127:0] debug_key_expanded[10:0];
	
	// test vector to compare results against
	assign debug_key_expanded[0] = 128'h00000000000000000000000000000000;
	assign debug_key_expanded[1] = 128'h62636363626363636263636362636363; 
	assign debug_key_expanded[2] = 128'h9b9898c9f9fbfbaa9b9898c9f9fbfbaa; 
	assign debug_key_expanded[3] = 128'h90973450696ccffaf2f457330b0fac99; 
	assign debug_key_expanded[4] = 128'hee06da7b876a1581759e42b27e91ee2b; 
	assign debug_key_expanded[5] = 128'h7f2e2b88f8443e098dda7cbbf34b9290; 
	assign debug_key_expanded[6] = 128'hec614b851425758c99ff09376ab49ba7; 
	assign debug_key_expanded[7] = 128'h217517873550620bacaf6b3cc61bf09b; 
	assign debug_key_expanded[8] = 128'h0ef903333ba9613897060a04511dfa9f; 
	assign debug_key_expanded[9] = 128'hb1d4d8e28a7db9da1d7bb3de4c664941; 
	assign debug_key_expanded[10]= 128'hb4ef5bcb3e92e21123e951cf6f8f188e;
	
	// Instantiate the Unit Under Test (UUT)
	aes_inv_key_shedualing uut (
		.key_i(key_q), 
		.key_rcon_i(key_rcon_q), 
		.key_next_o(key_next), 
		.key_rcon_o(key_rcon_next)
	);
	
	always #5 clk = ~clk;
	
	always @(posedge clk) begin
		if (~nreset) 
			key_rcon_q <= 8'b0000_0001;
		else
			key_rcon_q <= key_rcon_next;		
	end
	
	always @(posedge clk) begin
		if (~nreset) 
			key_q <=  128'haf7f67980cb7ad0047d9e8590f1571c9 ;
		else
			key_q <= key_next;			
	end 

	//assign key_i =  128'haf7f67980cb7ad0047d9e8590f1571c9;
	//assign key_i = 128'h0;
	//assign key_next = key_q;
	initial begin
		nreset = 1'b1;
		clk    = 1'b1;
		#10
		nreset = 1'b0;
		#10 
		nreset = ~nreset;
	end
	

   
endmodule

