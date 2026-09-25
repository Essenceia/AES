/* Copyright Julia Desmazes, 2026, all rights reserved 

Pre-load aes(H) and K from SRAM 
*/
module gcm_ae #(
	parameter PHY_W = 2, 
	parameter IV_W = 96,
	parameter W = 128,
	parameter  SRAM_W = 8, 
	localparam SRAM_ADDR_W = 5, 
	localparam [SRAM_ADDR_W-1:0] SRAM_H_ADDR = 5'h0,
	localparam [SRAM_ADDR_W-1:0] SRAM_K_ADDR = 5'h16
)(
input wire clk, 
input wire rst_n, 

input wire                   sram_v_i,
input wire                   sram_k_i,
input wire                   sram_h_i,
input wire [SRAM_W-1:0]      sram_data_i,

// plain text packet
input wire             tx_v_i,
input wire [PHY_W-1:0] tx_i, 
input wire             tx_encypt_i // indicates this section should be encrypted
);
// fsm 
localparam IDLE        = 'd0; 
localparam SREAM_A     = 'd1; 
localparam PAD_A       = 'd2;
localparam STREAM_C    = 'd3; 
localparam PAD_C       = 'd4; 
localparam GHASH_SIZES = 'd5; 

// key must be fully stored outside of aes as is needs to be refresed before 
// each block
reg [W-1:0] key_q; 
always @(posedge clk) 
	if (sram_v_i & sram_k_i) key_q <= {key_q[W-SRAM_W-1:0], sram_i};  

// GCTR 
//
// inc32
// aes

//aes_compact m_aes(
//.clk(clk), 
//.rst_n(rst_n), 
//
//.start_i(), // might have to change this
// WIP  

// preload H 
wire         gh_res_v; 
wire [W-1:0] gh_res;
ghash #(.SRAM_W(SRAM_W)) m_ghash(
.clk(clk), 
.rst_n(rst_n), 
.data_v_i(), 
.data_i(), 
.h_v_i(sram_v_i & sram_h_i), 
.h_i(sram_data_i), 
.res_v_o(gh_res_v),
.res_o(gh_res)
);


endmodule
