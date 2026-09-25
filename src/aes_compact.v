`timescale 1ns / 1ps

`default_nettype none

/* 
Compact AES implementation with 32b wide 
datapath, encrypting 1 plain text collumn per
cycle. 

For AES-128 it takes: 
round 0:
- 1 early cycle to pre-load key collumn ahead of equivalent
	plain text collumn. This was done to re-use key collumn mux to data paths.
- 4 cycles to initally load plain txt per 32b chunks
rounds 1-9:
- 4 cycles per collumn
last round: 
- 4 cycles per collumn 
So a total of at least 45 cycles.

Given in our target system data is arriving at a rate of 2b per cycle we have
64 cycles available to us to compute 128, which makes this fast enought for the
current line rate needs. 

Right now this implementation is focusing on supporting only AES-128
but I might add AES-256 depending on how much area and time before tapeout
I have left. 

A hypotetical implementation of AES-256 would take: 
- 128 bits of extra storage for the key
- deeper logic level on the key collumn calc to allow computing per cycle : 
	- 0 : key collum 0 (ks_col_last(col7) xor col0)
	- 1 : key collumns 1,2,3 (3 lvl deep xor)
	- 2 : key col4 (sbox(col3) xor col4)
	- 3 : key collumns 5, 6, 7
round 0: 
- 1 extra cycle to preload key col equivalent ahead of plain txt (like AES-128)
- 4 plain txt (like AES-128)
- 3 extra cycle to finish loading key columns <---
rounds 1-13:
- 4 cycle, 1 per collumn, same as AES-128
last round: 
- 4 cycle, 1 per collumn, same as AES-128
For a total of at least 64 cycles, which is exactly how much time we have. 
*/
module aes_compact #(
	localparam TXT_W = 128, // regardless of cipher
	localparam COL_N = 4,
	localparam COL_W = TXT_W/COL_N,
	localparam COL_IDX_W = $clog2(COL_N),
	parameter  KEY_W = 128,
	localparam KCOL_N = KEY_W/COL_W,
	localparam KCOL_IDX_W = $clog2(KCOL_N)
)(
	input  wire clk,
	input  wire rst_n,
	input  wire                 start_i, 

	input  wire                 data_v_i, // input valid
	input  wire [COL_IDX_W-1:0] data_idx_i, // collumn index
	input  wire [COL_W-1:0]     data_i,   // message to decode

	input  wire                  key_v_i,
	input  wire [KEY_W-1:0]      key_i,    // key

	output wire             res_v_o,  // result valid
	output wire [TXT_W-1:0] res_o     // result
);
// not implementing 196
localparam RND_CNT_MAX = KEY_W == 128 ? 10 : 14;
localparam RND_CNT_W = $clog2(RND_CNT_MAX); 

// fsm 
localparam RND_FIRST  = 2'd0;
localparam RND_BUBBLE = 2'd1;
localparam RND_INNER  = 2'd2;  
localparam RND_LAST   = 2'd3;  

reg [1:0]            fsm_q; 
reg [RND_CNT_W-1:0]  rnd_q; 
reg [COL_IDX_W-1:0]  col_cnt_q;
reg [KCOL_IDX_W-1:0] kcol_cnt_q;
wire                 rnd_inc; 
wire                 rnd_last_next; 

always @(posedge clk) begin
	if (~rst_n) begin
		fsm_q <= RND_FIRST; 
		rnd_q <= {RND_CNT_W{1'b0}}; 
	end else begin
		case(fsm_q) 
		RND_FIRST: begin	
			fsm_q <= start_i ? RND_BUBBLE : RND_FIRST; 
			rnd_q <= {RND_CNT_W{1'b0}};
		end
		RND_BUBBLE: begin
			fsm_q <= RND_INNER; 
			rnd_q <= {{RND_CNT_W-1{1'b0}}, 1'b1}; 
		end
		RND_INNER: begin
			fsm_q <= rnd_last_next ? RND_LAST: RND_INNER;
			rnd_q <= rnd_q + {{RND_CNT_W-1{1'b0}}, rnd_inc}; 
		end
		RND_LAST: begin
			fsm_q <= rnd_inc ? RND_FIRST: RND_LAST; 
			rnd_q <= rnd_inc ? {RND_CNT_W{1'b0}}: rnd_q;
		end
		endcase
	end
end

/* verilator lint_off WIDTHTRUNC */
localparam [COL_IDX_W-1:0] COL_MAX =  COL_N - 1; 
localparam [RND_CNT_W-1:0] RND_MAX_MIN1 = RND_CNT_MAX - 1; 
/* verilator lint_on WIDTHTRUNC */

assign rnd_last_next = rnd_inc & (rnd_q == RND_MAX_MIN1);  

reg res_v_q; 
always @(posedge clk) 
	res_v_q <= fsm_q == RND_LAST & rnd_inc; 

// column selection counter
assign rnd_inc = col_cnt_q == COL_MAX; 
always @(posedge clk) 
	if (~rst_n | (fsm_q == RND_BUBBLE)) col_cnt_q <= {COL_IDX_W{1'b0}};
	else col_cnt_q <= col_cnt_q + {{COL_IDX_W-1{1'b0}}, 1'b1};

always @(posedge clk) 
	if (~rst_n | (fsm_q == RND_FIRST)) kcol_cnt_q <= {KCOL_IDX_W{1'b0}};
	else kcol_cnt_q <= kcol_cnt_q + {{KCOL_IDX_W-1{1'b0}}, 1'b1};


/* 4x4
Organized by collumns 
{ col0, col1, col2, col3 }
*/
reg [TXT_W-1:0] data_q; // current rnd data
reg [TXT_W-1:COL_W] data_cache_q; // next rnd data 

localparam ROW_W = COL_W; 

// shift rows - redundant to make gtkwave not blind, I know what I am doing don't worry
// no actual logic here just made readable for my meatbrain
wire [ROW_W-1:0] row0, row1, row2, row3;
wire [COL_W-1:0] col0, col1, col2, col3;

assign row0 = {data_q[TXT_W-1-:8],     data_q[TXT_W-COL_W-1-:8],     data_q[TXT_W-2*COL_W-1-:8],     data_q[TXT_W-3*COL_W-1-:8]};
assign row1 = {data_q[TXT_W-1-8-:8],   data_q[TXT_W-COL_W-8-1-:8],   data_q[TXT_W-2*COL_W-8-1-:8],   data_q[TXT_W-3*COL_W-8-1-:8]};
assign row2 = {data_q[TXT_W-1-2*8-:8], data_q[TXT_W-COL_W-2*8-1-:8], data_q[TXT_W-2*COL_W-2*8-1-:8], data_q[TXT_W-3*COL_W-2*8-1-:8]};
assign row3 = {data_q[TXT_W-1-3*8-:8], data_q[TXT_W-COL_W-3*8-1-:8], data_q[TXT_W-2*COL_W-3*8-1-:8], data_q[TXT_W-3*COL_W-3*8-1-:8]};

wire [TXT_W-1:0] data_sr; 
assign data_sr = { row0, 
				{row1[ROW_W-8-1:0],  row1[ROW_W-1-:8]}, 
				{row2[ROW_W-16-1:0], row2[ROW_W-1-:16]},
				{row3[ROW_W-24-1:0], row3[ROW_W-1-:24]}};

assign col0 = {data_sr[TXT_W-1-:8],     data_sr[TXT_W-ROW_W-1-:8],     data_sr[TXT_W-2*ROW_W-1-:8],     data_sr[TXT_W-3*ROW_W-1-:8]};
assign col1 = {data_sr[TXT_W-1-8-:8],   data_sr[TXT_W-ROW_W-8-1-:8],   data_sr[TXT_W-2*ROW_W-8-1-:8],   data_sr[TXT_W-3*ROW_W-8-1-:8]};
assign col2 = {data_sr[TXT_W-1-2*8-:8], data_sr[TXT_W-ROW_W-2*8-1-:8], data_sr[TXT_W-2*ROW_W-2*8-1-:8], data_sr[TXT_W-3*ROW_W-2*8-1-:8]};
assign col3 = {data_sr[TXT_W-1-3*8-:8], data_sr[TXT_W-ROW_W-3*8-1-:8], data_sr[TXT_W-2*ROW_W-3*8-1-:8], data_sr[TXT_W-3*ROW_W-3*8-1-:8]};

reg [COL_W-1:0]     col_sr;
always @(*) begin 
	case(col_cnt_q) 
		2'd0: col_sr = col0;
		2'd1: col_sr = col1;
		2'd2: col_sr = col2;
		2'd3: col_sr = col3;
	endcase
end

// Sbox
wire [COL_W-1:0] col_sb;
genvar sb_i;
generate 
for (sb_i=0; sb_i<4; sb_i=sb_i+1) begin : loop_gen_sb_i				
	sbox m_sbox(
		.data_i( col_sr[(sb_i+1)*8-1-:8]),
		.data_o( col_sb[(sb_i+1)*8-1-:8])
    );
end
endgenerate

// MixColumns
wire skip_mc; 
wire [COL_W-1:0] col_mc;
wire [COL_W-1:0] col_mc_swap, col_sb_swap;	

assign col_sb_swap[COL_W-1-:8]     = col_sb[8-1:0];
assign col_sb_swap[COL_W-8-1-:8]   = col_sb[2*8-1-:8];
assign col_sb_swap[COL_W-2*8-1-:8] = col_sb[3*8-1-:8];
assign col_sb_swap[COL_W-3*8-1-:8] = col_sb[4*8-1-:8];

assign col_mc[COL_W-1-:8]     = col_mc_swap[8-1:0];
assign col_mc[COL_W-8-1-:8]   = col_mc_swap[2*8-1-:8];
assign col_mc[COL_W-2*8-1-:8] = col_mc_swap[3*8-1-:8];
assign col_mc[COL_W-3*8-1-:8] = col_mc_swap[4*8-1-:8];

mixw m_mixw( 
	.w_i(col_sb_swap), 
	.mixw_o(col_mc_swap)
);

localparam KCOL_W = COL_W; 

wire [KCOL_W-1:0] kcol0, kcol1, kcol2, kcol3; 
reg  [COL_W-1:0] key_col; 
wire [COL_W-1:0] col_rk; 
wire [COL_W-1:0] col_rk_inner; 

wire [KCOL_IDX_W-1:0] kcol_rd_idx; 
assign kcol_rd_idx = data_v_i ? data_idx_i: col_cnt_q; 

always @(*) begin
	case(kcol_rd_idx) 
		2'd0: key_col = kcol0;
		2'd1: key_col = kcol1;
		2'd2: key_col = kcol2;
		2'd3: key_col = kcol3;
	endcase
end

assign skip_mc = (fsm_q == RND_LAST); 

assign col_rk_inner = data_v_i ? data_i:
					  skip_mc  ? col_sb: col_mc;
assign col_rk = col_rk_inner ^ key_col; 

// write-back
wire [COL_N-1:0]     data_wr_en;
wire [COL_IDX_W-1:0] col_wr_sel; 

assign col_wr_sel = data_v_i ? data_idx_i: col_cnt_q;
assign data_wr_en[0] = (col_wr_sel == 2'd0) & (data_v_i | ((fsm_q != RND_FIRST) & (fsm_q != RND_BUBBLE))); 
assign data_wr_en[1] = (col_wr_sel == 2'd1) & (data_v_i | ((fsm_q != RND_FIRST) & (fsm_q != RND_BUBBLE))); 
assign data_wr_en[2] = (col_wr_sel == 2'd2) & (data_v_i | ((fsm_q != RND_FIRST) & (fsm_q != RND_BUBBLE))); 
assign data_wr_en[3] = (col_wr_sel == 2'd3) & (data_v_i | ((fsm_q != RND_FIRST) & (fsm_q != RND_BUBBLE))); 

// sdff to come
always @(posedge clk) begin 
	if (data_wr_en[0]) data_cache_q[TXT_W-1-:COL_W]         <= col_rk; 
	if (data_wr_en[1]) data_cache_q[TXT_W-COL_W-1-:COL_W]   <= col_rk; 
	if (data_wr_en[2]) data_cache_q[TXT_W-2*COL_W-1-:COL_W] <= col_rk; 
	if (data_wr_en[3]) data_q                               <= {data_cache_q, col_rk};
end

wire [COL_W-1:0] debug_data_col0;
wire [COL_W-1:0] debug_data_col1;
wire [COL_W-1:0] debug_data_col2;
wire [COL_W-1:0] debug_data_col3;
assign debug_data_col0 = data_q[TXT_W-1-:COL_W];
assign debug_data_col1 = data_q[TXT_W-COL_W-1-:COL_W];
assign debug_data_col2 = data_q[TXT_W-2*COL_W-1-:COL_W];
assign debug_data_col3 = data_q[TXT_W-3*COL_W-1-:COL_W];

// key schedulaing 
localparam RCON_W = 8;

reg [KEY_W-1:0]  key_q; 

reg  [RCON_W-1:0] rcon_q;
wire [RCON_W-1:0] rcon_next;

wire [KCOL_W-1:0] kcol0_xor, kcol1_xor, kcol2_xor, kcol3_xor; 
wire [KCOL_W-1:0] kcol0_next, kcol1_next, kcol2_next, kcol3_next; 
wire [KCOL_W-1:0] kcol3_rcon;

assign kcol0 = key_q[KEY_W-1-:KCOL_W];
assign kcol1 = key_q[KEY_W-KCOL_W-1-:KCOL_W];
assign kcol2 = key_q[KEY_W-2*KCOL_W-1-:KCOL_W];
assign kcol3 = key_q[KEY_W-3*KCOL_W-1-:KCOL_W];

ks_col3 m_key_col_first(
.key_w3_i  (kcol3),
.key_rcon_i(rcon_q),
.key_w3_next_o(kcol3_rcon),
.key_rcon_o(rcon_next)
);

always @(posedge clk)
	if(fsm_q == RND_FIRST) rcon_q <= 8'h01;  
	else if(kcol_cnt_q == COL_MAX) rcon_q <= rcon_next; 

// Cheaper to splurge and just do everything in parallel
assign kcol0_xor = kcol0 ^ kcol3_rcon; 
assign kcol1_xor = kcol1 ^ kcol0;
assign kcol2_xor = kcol2 ^ kcol1;
assign kcol3_xor = kcol3 ^ kcol2;

assign kcol0_next = key_v_i? key_i[KEY_W-1-:KCOL_W]         : kcol0_xor;
assign kcol1_next = key_v_i? key_i[KEY_W-KCOL_W-1-:KCOL_W]  : kcol1_xor;
assign kcol2_next = key_v_i? key_i[KEY_W-2*KCOL_W-1-:KCOL_W]: kcol2_xor;
assign kcol3_next = key_v_i? key_i[KEY_W-3*KCOL_W-1-:KCOL_W]: kcol3_xor;

wire [KCOL_N-1:0]     key_wr_en; 
wire [KCOL_IDX_W-1:0] kcol_wr_sel; 

assign kcol_wr_sel  = kcol_cnt_q; 
assign key_wr_en[0] = ((kcol_wr_sel == 2'd0) & (fsm_q != RND_FIRST)) | key_v_i; 
assign key_wr_en[1] = ((kcol_wr_sel == 2'd1) & (fsm_q != RND_FIRST)) | key_v_i; 
assign key_wr_en[2] = ((kcol_wr_sel == 2'd2) & (fsm_q != RND_FIRST)) | key_v_i; 
assign key_wr_en[3] = ((kcol_wr_sel == 2'd3) & (fsm_q != RND_FIRST)) | key_v_i; 

always @(posedge clk) begin
	if (key_wr_en[0]) key_q[KEY_W-1-:KCOL_W]          <= kcol0_next;
	if (key_wr_en[1]) key_q[KEY_W-KCOL_W-1-:KCOL_W]   <= kcol1_next;
	if (key_wr_en[2]) key_q[KEY_W-2*KCOL_W-1-:KCOL_W] <= kcol2_next;
	if (key_wr_en[3]) key_q[KEY_W-3*KCOL_W-1-:KCOL_W] <= kcol3_next;
end

// output
assign res_o   = data_q; 
assign res_v_o = res_v_q;

endmodule
