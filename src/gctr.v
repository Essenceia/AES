/* Copyright 2026, Julia Desmazes

GCTR function */
module gctr #(
	localparam W    = 128,
	localparam CB_W = 96,
	localparam S    = 32, // increment
	parameter  CNT_W = 10, // block counter, support have a max payload of 16*10^2 Bytes (+16kB)
	parameter  DATA_W = 2 // data stream interface
)(
	input wire clk, 
	input wire rst_n, 

	input wire            init_i, 

	input wire            icb_v_i, 
	input wire [CB_W-1:0] icb_i,
	input wire            icb_inc_i, // increment icb before use 

	// key 
	input wire [W-1:0]    key_i, 
	// RX data
	input wire              x_v_i, 
	input wire [DATA_W-1:0] x_i, 

	// TX
	output wire             data_v_o, 
	output wire [W-1:0]     data_o,

	output wire [CNT_W-1:0] cnt_o // encrypted block count 
);

// 


endmodule 
