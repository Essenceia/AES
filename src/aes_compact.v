`timescale 1ns / 1ps

`default_nettype none

// Focusing on supporting only AES-128 
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
	input  wire [KCOL_IDX_W-1:0] key_idx_i,
	input  wire [COL_W-1:0]      key_i,    // key

	output wire             res_v_o,  // result valid
	output wire [TXT_W-1:0] res_o     // result
);
// not implementing 196
localparam RND_CNT_MAX = KEY_W == 128 ? 10 : 14;
localparam RND_CNT_W = $clog2(RND_CNT_MAX); 

// fsm 
localparam RND_FIRST = 2'd0;
localparam RND_INNER = 2'd1;  
localparam RND_LAST  = 2'd2;  

reg [1:0]           fsm_q; 
reg [RND_CNT_W-1:0] rnd_q; 
reg [COL_IDX_W-1:0] col_cnt_q;
wire                rnd_inc; 
wire                rnd_last_next; 

always @(posedge clk) begin
	if (~rst_n) begin
		fsm_q <= RND_FIRST; 
		rnd_q <= {RND_CNT_W{1'b0}}; 
	end else begin
		case(fsm_q) 
		RND_FIRST: begin	
			fsm_q <= start_i ? RND_INNER : RND_FIRST; 
			rnd_q <= start_i ? {{RND_CNT_W-1{1'b0}}, 1'b1}: {RND_CNT_W{1'b0}};
		end
		RND_INNER: begin
			fsm_q <= rnd_last_next ? RND_LAST: RND_INNER;
			rnd_q <= rnd_q + {{RND_CNT_W-1{1'b0}}, rnd_inc}; 
		end
		RND_LAST: begin
			fsm_q <= rnd_inc ? RND_FIRST: RND_LAST; 
			rnd_q <= rnd_inc ? {RND_CNT_W{1'b0}}: rnd_q;
		end
		default: begin
			fsm_q <= RND_FIRST; 
			rnd_q <= {RND_CNT_W{1'b0}};
		end
		endcase
	end
end

/* verilator lint_off WIDTHTRUNC */
localparam [COL_IDX_W-1:0] COL_MAX =  COL_N - 1; 
localparam [RND_CNT_W-1:0] RND_MAX_MIN2 = RND_CNT_MAX - 2; 
/* verilator lint_on WIDTHTRUNC */

assign rnd_last_next = rnd_inc & (rnd_q == RND_MAX_MIN2);  

// column selection counter
assign rnd_inc = col_cnt_q == COL_MAX; 
always @(posedge clk) 
	if (~rst_n | (fsm_q == RND_FIRST)) col_cnt_q <= {COL_IDX_W{1'b0}};
	else col_cnt_q <= col_cnt_q + {{COL_IDX_W-1{1'b0}}, 1'b1};

/* 4x4
Organized by collumns 
{ col0, col1, col2, col3 }
*/
reg [TXT_W-1:0] data_q; // 4x4 - organized by columns 

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
mixw m_mixw( 
	.w_i(col_sb), 
	.mixw_o(col_mc)
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
		2'd1: key_col = kcol0;
		2'd2: key_col = kcol0;
		2'd3: key_col = kcol0;
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
assign data_wr_en[0] = (col_wr_sel == 2'd0) & (data_v_i | (fsm_q != RND_FIRST)); 
assign data_wr_en[1] = (col_wr_sel == 2'd1) & (data_v_i | (fsm_q != RND_FIRST)); 
assign data_wr_en[2] = (col_wr_sel == 2'd2) & (data_v_i | (fsm_q != RND_FIRST)); 
assign data_wr_en[3] = (col_wr_sel == 2'd3) & (data_v_i | (fsm_q != RND_FIRST)); 

// sdff to come
always @(posedge clk) begin 
	if (data_wr_en[0]) data_q[TXT_W-1-:COL_W]         <= col_rk; 
	if (data_wr_en[1]) data_q[TXT_W-COL_W-1-:COL_W]   <= col_rk; 
	if (data_wr_en[2]) data_q[TXT_W-2*COL_W-1-:COL_W] <= col_rk; 
	if (data_wr_en[3]) data_q[TXT_W-3*COL_W-1-:COL_W] <= col_rk;
end


// key schedulaing 
localparam RCON_MAX = KEY_W == 128 ? 'h36 : KEY_W == 198 ? 'h40 : 'h80;
localparam RCON_W = $clog2(RCON_MAX);
localparam RCON_PAD_W = 8 - RCON_W; 

reg [KEY_W-1:0]  key_q; 

reg  [RCON_W-1:0] rcon_q;
wire [RCON_W-1:0] rcon_next;

wire [RCON_PAD_W-1:0] rcon_pad, rcon_pad_next_unused; 

wire [KCOL_W-1:0] kcol0_xor, kcol1_xor, kcol2_xor, kcol3_xor; 
wire [KCOL_W-1:0] kcol0_next, kcol1_next, kcol2_next, kcol3_next; 
wire [KCOL_W-1:0] kcol3_rcon;

assign kcol0 = key_q[KEY_W-1-:KCOL_W];
assign kcol1 = key_q[KEY_W-KCOL_W-1-:KCOL_W];
assign kcol2 = key_q[KEY_W-2*KCOL_W-1-:KCOL_W];
assign kcol3 = key_q[KEY_W-3*KCOL_W-1-:KCOL_W];

assign rcon_pad = {RCON_PAD_W{1'b0}};

aes_key_first_col m_key_col_first(
.key_w3_i  (kcol3),
.key_rcon_i({rcon_pad, rcon_q}),
.key_w3_next_o(kcol3_rcon),
.key_rcon_o({rcon_pad_next_unused, rcon_next})
);

always @(posedge clk) 
	rcon_q <= rcon_next; 

// Cheaper to splurge and just do everything in parallel
assign kcol0_xor = kcol0 ^ kcol3_rcon; 
assign kcol1_xor = kcol1 ^ kcol0;
assign kcol2_xor = kcol2 ^ kcol1;
assign kcol3_xor = kcol3 ^ kcol2;

assign kcol0_next = key_v_i? key_i: kcol0_xor;
assign kcol1_next = key_v_i? key_i: kcol1_xor;
assign kcol2_next = key_v_i? key_i: kcol2_xor;
assign kcol3_next = key_v_i? key_i: kcol3_xor;

wire [KCOL_N-1:0]     key_wr_en; 
wire [KCOL_IDX_W-1:0] kcol_wr_sel; 

assign kcol_wr_sel  = key_v_i ? key_idx_i : col_cnt_q; 
assign key_wr_en[0] = (kcol_wr_sel == 2'd0) & (key_v_i | (fsm_q != RND_FIRST)); 
assign key_wr_en[1] = (kcol_wr_sel == 2'd1) & (key_v_i | (fsm_q != RND_FIRST)); 
assign key_wr_en[2] = (kcol_wr_sel == 2'd2) & (key_v_i | (fsm_q != RND_FIRST)); 
assign key_wr_en[3] = (kcol_wr_sel == 2'd3) & (key_v_i | (fsm_q != RND_FIRST)); 

always @(posedge clk) begin
	if (key_wr_en[0]) key_q[KEY_W-1-:KCOL_W]          <= kcol0_next;
	if (key_wr_en[1]) key_q[KEY_W-KCOL_W-1-:KCOL_W]   <= kcol1_next;
	if (key_wr_en[2]) key_q[KEY_W-2*KCOL_W-1-:KCOL_W] <= kcol2_next;
	if (key_wr_en[3]) key_q[KEY_W-3*KCOL_W-1-:KCOL_W] <= kcol3_next;
end

// tmp 
assign res_o = data_q; 
assign res_v_o = (fsm_q == RND_LAST) & rnd_inc;

endmodule
