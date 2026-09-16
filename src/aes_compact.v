`timescale 1ns / 1ps

`default_nettype none

module aes_compact #(
	localparam TXT_W = 128, // regardless of cipher
	parameter  KEY_W = 128
)(
	input  wire clk,
	input  wire rst_n,
	input  wire             data_v_i, // input valid
	input  wire [TXT_W-1:0] data_i,   // message to decode
	input  wire             key_v_i,
	input  wire [KEY_W-1:0] key_i,    // key
	output wire             res_v_o,  // result valid
	output wire [TXT_W-1:0] res_o     // result
);

/* 4x4
Organized by collumns 
{ col0, col1, col2, col3 }
*/
reg [TXT_W-1:0] data_q; // 4x4 - organized by columns 

localparam COL_N = 4;
localparam COL_W = TXT_W / COL_N;
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


reg [COL_W-1:0] col_sr;

`define ANDOR_RED
`ifdef ANDOR_RED
reg [COL_N-1:0] col_sel_q; 

always @(posedge clk) // TODO set/rst
	if (~rst_n) col_sel_q <= 4'b0001;
	else col_sel_q <= {col_sel_q[COL_N-2:0], col_sel_q[COL_N-1]};

assign col_sr = col0 & {COL_W{col_sel_q[0]}} |
				col1 & {COL_W{col_sel_q[1]}} |	 
				col2 & {COL_W{col_sel_q[2]}} |	 
				col3 & {COL_W{col_sel_q[3]}};
`else
localparam SEL_W = $clog2(COL_N);
reg [SEL_W-1:0] col_sel_q;

always @(posedge clk) 
	if (~rst_n) col_sel_q <= {SEL_W{1'b0}};
	else col_sel_q <= col_sel_q + {{SEL_W-1{1'b0}}, 1'b1};

always @(*) 
	case(col_sel_q) 
		2'd0: col_sr <= col0;
		2'd1: col_sr <= col1;
		2'd2: col_sr <= col2;
		2'd3: col_sr <= col3;
	endcase
`endif

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
localparam KCOL_N = KEY_W / KCOL_W;

wire [KCOL_W-1:0] kcol0, kcol1, kcol2, kcol3; 
wire [COL_W-1:0] key_col; 
wire [COL_W-1:0] col_rk; 

assign key_col = kcol0 & {COL_W{col_sel_q[0]}} |
				 kcol1 & {COL_W{col_sel_q[1]}} |	 
				 kcol2 & {COL_W{col_sel_q[2]}} |	 
				 kcol3 & {COL_W{col_sel_q[3]}};

assign col_rk = col_mc ^ key_col; 

// write-back
wire [COL_N-1:0] data_en; 
wire [COL_W-1:0] data_i_col0, data_i_col1, data_i_col2, data_i_col3; 
wire [COL_W-1:0] col0_next, col1_next, col2_next, col3_next; 

// TODO fix - organize by col 
assign data_i_col0 = {data_i[TXT_W-1-:8],     data_i[TXT_W-ROW_W-1-:8],     data_i[TXT_W-2*ROW_W-1-:8],     data_i[TXT_W-3*ROW_W-1-:8]};
assign data_i_col1 = {data_i[TXT_W-1-8-:8],   data_i[TXT_W-ROW_W-8-1-:8],   data_i[TXT_W-2*ROW_W-8-1-:8],   data_i[TXT_W-3*ROW_W-8-1-:8]};
assign data_i_col2 = {data_i[TXT_W-1-2*8-:8], data_i[TXT_W-ROW_W-2*8-1-:8], data_i[TXT_W-2*ROW_W-2*8-1-:8], data_i[TXT_W-3*ROW_W-2*8-1-:8]};
assign data_i_col3 = {data_i[TXT_W-1-3*8-:8], data_i[TXT_W-ROW_W-3*8-1-:8], data_i[TXT_W-2*ROW_W-3*8-1-:8], data_i[TXT_W-3*ROW_W-3*8-1-:8]};

assign col0_next = data_v_i ? data_i_col0 : col_rk; 
assign col1_next = data_v_i ? data_i_col1 : col_rk; 
assign col2_next = data_v_i ? data_i_col2 : col_rk; 
assign col3_next = data_v_i ? data_i_col3 : col_rk; 

assign data_en = col_sel_q | {COL_N{data_v_i}};
// sdff to come
always @(posedge clk) begin 
	if (data_en[0]) data_q[TXT_W-1-:COL_W]         <= col0_next; 
	if (data_en[1]) data_q[TXT_W-COL_W-1-:COL_W]   <= col1_next; 
	if (data_en[2]) data_q[TXT_W-2*COL_W-1-:COL_W] <= col2_next; 
	if (data_en[3]) data_q[TXT_W-3*COL_W-1-:COL_W] <= col3_next;
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

assign kcol0_next = key_v_i? key_i[KEY_W-1-:KCOL_W]         : kcol0_xor;
assign kcol1_next = key_v_i? key_i[KEY_W-KCOL_W-1-:KCOL_W]  : kcol1_xor;
assign kcol2_next = key_v_i? key_i[KEY_W-2*KCOL_W-1-:KCOL_W]: kcol2_xor;
assign kcol3_next = key_v_i? key_i[KEY_W-3*KCOL_W-1-:KCOL_W]: kcol3_xor;

wire [KCOL_N-1:0] kcol_en; 
assign kcol_en = col_sel_q | {KCOL_N{key_v_i}}; // TODO
always @(posedge clk) begin
	if (kcol_en[0]) key_q[KEY_W-1-:KCOL_W]          <= kcol0_next;
	if (kcol_en[1]) key_q[KEY_W-KCOL_W-1-:KCOL_W]   <= kcol1_next;
	if (kcol_en[2]) key_q[KEY_W-2*KCOL_W-1-:KCOL_W] <= kcol2_next;
	if (kcol_en[2]) key_q[KEY_W-3*KCOL_W-1-:KCOL_W] <= kcol3_next;
end

// tmp 
assign res_o = data_q; 
assign res_v_o = 1'b0;

endmodule
