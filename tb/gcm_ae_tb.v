/*
Copyright (c) 2026 Julia Desmazes 

This code was written by a human, authorization is explicitly not 
granted to use it to train any model. 
*/

`default_nettype none
`timescale 1ns / 10ps

module gcm_ae_tb ();

initial begin
	$dumpfile("gcm_ae_tb.vcd");
	$dumpvars(0, gcm_ae_tb);
	#1;
end
localparam SRAM_W = 16;
localparam PHY_W  = 2;

wire clk;
wire rst_n;

wire              gcm_init;
 
wire              gcm_sram_v; 
wire              gcm_sram_k; 
wire              gcm_sram_h;
wire [SRAM_W-1:0] gcm_sram;

wire              gcm_rx_v; 
wire              gcm_rx_enc; 
wire [PHY_W-1:0]  gcm_rx;
wire              gcm_rx_last; 

wire              gcm_tx_v; 
wire              gcm_tx_start; 
wire              gcm_tx_last; 
wire [PHY_W-1:0]  gcm_tx;

wire [31:0]       gcm_pn; 
wire [63:0]       gcm_sci; 

gcm_ae m_gcm_ae(
.clk         (clk), 
.rst_n       (rst_n), 

.init_i      (gcm_init), 

.sram_v_i    (gcm_sram_v),
.sram_k_i    (gcm_sram_k),
.sram_h_i    (gcm_sram_h),
.sram_i      (gcm_sram),

.data_v_i    (gcm_rx_v),
.data_enc_i  (gcm_rx_enc),
.data_i      (gcm_rx), 
.data_last_i (gcm_rx_last),

.data_v_o    (gcm_tx_v),
.data_start_o(gcm_tx_start),
.data_last_o (gcm_tx_last),
.data_o      (gcm_tx),

.pn_i        (gcm_pn),
.sci_i       (gcm_sci)
);

endmodule
