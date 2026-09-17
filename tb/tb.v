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
localparam COL_W = 32; 
localparam COL_IDX_W  = 2;
localparam KCOL_IDX_W = $clog2(KEY_W/COL_W);

wire enc_start; 

wire                 enc_data_v; 
wire [COL_IDX_W-1:0] enc_data_idx;
wire [COL_W-1:0]     enc_data;

wire                  enc_key_v;
wire [KCOL_IDX_W-1:0] enc_key_idx;
wire [COL_W-1:0]      enc_key; 

wire             enc_res_v; 
wire [COL_W-1:0] enc_res; 

aes_compact #(.KEY_W(KEY_W)) m_enc(
	.clk     (clk), 
	.rst_n   (rst_n), 
	.start_i (enc_start),

	.data_v_i  (enc_data_v), 
	.data_idx_i(enc_data_idx),
	.data_i    (enc_data), 

	.key_v_i  (enc_key_v), 
	.key_idx_i(enc_key_idx),
	.key_i    (enc_key), 

	.res_v_o (enc_res_v), 
	.res_o   (enc_res)
);

endmodule
