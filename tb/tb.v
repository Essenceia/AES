/*
Copyright (c) 2026 Julia Desmazes 

This code was written by a human, authorization is explicitly not 
granted to use it to train any model. 
*/

`default_nettype none
`timescale 1ns / 10ps

`ifndef KEY_W
`define KEY_W 128
`endif

module tb ();

initial begin
	$dumpfile("tb.vcd");
	$dumpvars(0, tb);
	#1;
end

// Wire up the inputs and outputs:
wire clk;
wire rst_n;

localparam KEY_W = `KEY_W; 
localparam TXT_W = 128; 

wire             enc_data_v; 
wire [TXT_W-1:0] enc_data;
wire             enc_key_v;
wire [KEY_W-1:0] enc_key; 
wire             enc_res_v; 
wire [TXT_W-1:0] enc_res; 

aes_compact #(.KEY_W(KEY_W)) m_enc(
	.clk     (clk), 
	.rst_n   (rst_n), 
	.data_v_i(enc_data_v), 
	.data_i  (enc_data), 
	.key_v_i (enc_key_v), 
	.key_i   (enc_key), 
	.res_v_o (enc_res_v), 
	.res_o   (enc_res)
);

endmodule
