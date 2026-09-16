`timescale 1ns / 1ps

`default_nettype none

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
reg [COL_IDX_W-1:0] col_sel_q;

always @(posedge clk) 
	if (~rst_n | start_i) col_sel_q <= {COL_IDX_W{1'b0}};
	else col_sel_q <= col_sel_q + {{COL_IDX_W-1{1'b0}}, 1'b1};

always @(*) 
	case(col_sel_q) 
		2'd0: col_sr <= col0;
		2'd1: col_sr <= col1;
		2'd2: col_sr <= col2;
		2'd3: col_sr <= col3;
	endcase

// Sbox
wire [COL_W-1:0] col_sb;
genvar sb_i;
generate 
for (genvar sb_i=0; sb_i<4; sb_i=sb_i+1) begin : loop_gen_sb_i				
	sbox m_sbox(
		.data_i( col_sr[(sb_i+1)*8-1-:8]),
		.data_o( col_sb[(sb_i+1)*8-1-:8])
    );
end
endgenerate

// MixColumns
wire [COL_W-1:0] col_mc;	
mixw m_mixw( 
	.w_i(col_sb), 
	.mixw_o(col_mc)
);

localparam KCOL_W = COL_W; 

wire [KCOL_W-1:0] kcol0, kcol1, kcol2, kcol3; 
wire [COL_W-1:0] key_col; 
wire [COL_W-1:0] col_rk; 
wire [COL_W-1:0] col_rk_inner; 

assign key_col = kcol0 & {COL_W{col_sel_q == 2'd0}} |
				 kcol1 & {COL_W{col_sel_q == 2'd1}} |	 
				 kcol2 & {COL_W{col_sel_q == 2'd2}} |	 
				 kcol3 & {COL_W{col_sel_q == 2'd3}};

assign col_rk_inner = data_v_i ? data_i: col_mc;
assign col_rk = col_rk_inner ^ key_col; 

// write-back
wire [COL_N-1:0] data_en; 

assign data_en = data_v_i ? data_idx_i: col_sel_q;
// sdff to come
always @(posedge clk) begin 
	if (data_en == 2'd0) data_q[TXT_W-1-:COL_W]         <= col_rk; 
	if (data_en == 2'd1) data_q[TXT_W-COL_W-1-:COL_W]   <= col_rk; 
	if (data_en == 2'd2) data_q[TXT_W-2*COL_W-1-:COL_W] <= col_rk; 
	if (data_en == 2'd3) data_q[TXT_W-3*COL_W-1-:COL_W] <= col_rk;
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

wire [KCOL_IDX_W-1:0] kcol_en; 
assign kcol_en = key_v_i ? key_idx_i : col_sel_q; // TODO
always @(posedge clk) begin
	if (kcol_en == 2'd0) key_q[KEY_W-1-:KCOL_W]          <= kcol0_next;
	if (kcol_en == 2'd1) key_q[KEY_W-KCOL_W-1-:KCOL_W]   <= kcol1_next;
	if (kcol_en == 2'd2) key_q[KEY_W-2*KCOL_W-1-:KCOL_W] <= kcol2_next;
	if (kcol_en == 2'd3) key_q[KEY_W-3*KCOL_W-1-:KCOL_W] <= kcol3_next;
end

// tmp 
assign res_o = data_q; 
assign res_v_o = 1'b0;

endmodule
