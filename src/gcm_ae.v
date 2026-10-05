/* Copyright Julia Desmazes, 2026, all rights reserved 

Pre-load aes(H) and K from SRAM 
*/

`default_nettype none 

module gcm_ae #(
	parameter PHY_W = 2, 
	localparam SCI_W = 64,
	parameter W = 128,
	parameter  SRAM_W = 16, 
	parameter C_CNT_W = 10, // cipher block count
	parameter A_CNT_W = 10  // clear text block count
)(
	input wire clk, 
	input wire rst_n, 
	
	input wire                   init_i, 
	
	input wire                   sram_v_i,
	input wire                   sram_k_i,
	input wire                   sram_h_i,
	input wire [SRAM_W-1:0]      sram_i,
	
	// RX Eth - post address table lookup and match
	input wire                   data_v_i, 
	input wire                   data_enc_i, // encrypt incoming data
	input wire                   data_last_i, 
	input wire [PHY_W-1:0]       data_i, 
	// TX Eth
	output wire                  data_v_o, 
	output wire                  data_start_o, // start tx packet streamout 
	output wire                  data_last_o, 
	output wire [PHY_W-1:0]      data_o, 
	
	// read from RAM and shared over common interface
	input wire [31:0]            pn_i, // bottom 32b of the PN
	input wire [SCI_W-1:0]       sci_i 
);
reg [2:0] fsm_q; 

wire gh_hash_v; // ghash final hash valid

// key must be fully stored outside of aes as is needs to be refresed before 
// each block
reg [W-1:0] key_q; 
reg         key_v; // has complete key

always @(posedge clk) 
	if (sram_v_i & sram_k_i) key_q <= {key_q[W-SRAM_W-1:0], sram_i};  

assign key_v = sram_v_i & sram_h_i; // H is after K

localparam B_CNT_MAX = W/PHY_W;
localparam B_CNT_W = $clog2(B_CNT_MAX); 
/* verilator lint_off WIDTHTRUNC */
localparam [B_CNT_W-1:0] B_CNT_MAX_MIN1 = B_CNT_MAX - 1; 
/* verilator lint_on WIDTHTRUNC */

// C block count, assuming a max of 16k Bytes
// init value at 2 to not need an additional inc_32 before first aes 
// cipher
// Increment at the start of any new block 
reg [C_CNT_W-1:0] iv_cnt_q; 
reg [C_CNT_W-1:0] c_cnt_q; 
reg [A_CNT_W-1:0] a_cnt_q; 
wire c_inc_v; // aes result finished and we can start next block 
wire a_inc_v; 

reg [B_CNT_W-1:0] b_cnt_q; 
wire b_cnt_rst; 

assign b_cnt_rst = init_i | ((fsm_q == FSM_A) & data_v_i & data_enc_i); // rst block cnt when switching from A->C

always @(posedge clk) begin
	if (b_cnt_rst) b_cnt_q <= {B_CNT_W{1'b0}};
	else b_cnt_q <= b_cnt_q + {{B_CNT_W-1{1'b0}}, data_v_i};
end

assign a_inc_v = ~|b_cnt_q & (fsm_q == FSM_A) & data_v_i & ~data_enc_i; 
assign c_inc_v = ~|b_cnt_q & (fsm_q == FSM_C) & data_v_i; 
always @(posedge clk) begin
	if (init_i) begin
		 iv_cnt_q <= {{C_CNT_W-2{1'b0}}, 2'd2}; 
		 c_cnt_q  <= {C_CNT_W{1'b0}}; 
		 a_cnt_q  <= {A_CNT_W{1'b0}}; 
	end else begin
		iv_cnt_q <= iv_cnt_q + {{C_CNT_W-1{1'b0}}, c_inc_v}; 
		c_cnt_q  <=  c_cnt_q + {{C_CNT_W-1{1'b0}}, c_inc_v};
		a_cnt_q  <=  a_cnt_q + {{A_CNT_W-1{1'b0}}, a_inc_v};
	end
end

// main fsm 
localparam FSM_IDLE     = 3'd0; 
localparam FSM_A        = 3'd1; 
localparam FSM_C        = 3'd2; 
localparam FSM_ICV_CALC = 3'd3; 
localparam FSM_ICV      = 3'd4; 
wire payload_finished;  // last data seen 

assign payload_finished = data_v_i & data_last_i; 
always @(posedge clk) begin
	if (~rst_n) fsm_q <= FSM_IDLE; 
	else case (fsm_q)
		FSM_IDLE:     fsm_q <= init_i ? FSM_A: FSM_IDLE; 
		FSM_A:        fsm_q <= (data_v_i & data_enc_i)? FSM_C : 
					           payload_finished ? FSM_ICV_CALC: FSM_A; 
		FSM_C:        fsm_q <= payload_finished ? FSM_ICV_CALC: FSM_C; 
		FSM_ICV_CALC: fsm_q <= gh_hash_v  ? FSM_ICV: FSM_ICV_CALC; 
		FSM_ICV:      fsm_q <= ~gh_hash_v ? FSM_IDLE: FSM_ICV;
		default:      fsm_q <= FSM_IDLE; 
	endcase
end

/* 
Calculate the next aes block hash one block ahead such that we can 
apply the hash to the incoming data as it streams in and directly 
store it to the ghash input buffer. 
Drop current calculation and hash block hash when we need to calculate
tag hash. 
*/
reg [W-1:0] aes_hash_q; 

// aes fsm
localparam FSM_AES_IDLE    = 3'd0; 
localparam FSM_AES_LD_KEY  = 3'd1; 
localparam FSM_AES_LD_DATA = 3'd2; 
localparam FSM_AES_HASH    = 3'd3; 
localparam FSM_AES_RES     = 3'd4; 
reg [2:0] fsm_aes_q; 


wire aes_res_v; 
wire aes_force_tag; // force dropping of current block hash and calculation of tag hash
assign aes_force_tag = 1'b0; // TODO
always @(posedge clk) begin
	if (~rst_n | init_i) fsm_aes_q <= FSM_AES_IDLE; 
	else case(fsm_aes_q) 
		FSM_AES_IDLE:    fsm_aes_q <= key_v ? FSM_AES_LD_KEY : FSM_AES_IDLE;
		FSM_AES_LD_KEY:  fsm_aes_q <= FSM_AES_LD_DATA; // load key
		FSM_AES_LD_DATA: fsm_aes_q <= FSM_AES_HASH;
		FSM_AES_HASH:    fsm_aes_q <= aes_force_tag ? FSM_AES_LD_KEY : 
                                      aes_res_v ? FSM_AES_RES: FSM_AES_HASH; 
		FSM_AES_RES:     fsm_aes_q <= aes_force_tag ? FSM_AES_LD_KEY : 
                                      aes_hash_set ? FSM_AES_LD_KEY: FSM_AES_RES; // hold res until we have used up previous block's hash 
		default:  fsm_aes_q <= FSM_AES_IDLE;  
	endcase
end

reg aes_tag_v_q; // indicated whether we are calculating the aes for the tag or the plain text 
always @(posedge clk) 
	if (~rst_n | init_i) aes_tag_v_q <= 1'b0; 
	else aes_tag_v_q <= aes_tag_v_q | payload_finished; 


// previous aes hash
wire aes_hash_set; 
wire aes_hash_shift; 

wire [W-1:0]      aes_res;  

assign aes_hash_set   = b_cnt_q == B_CNT_MAX_MIN1; 
`ifdef TB
assert(aes_hash_set |-> aes_rev_v | fsm_aes_q == FSM_AES_RES); 
`endif 
 
assign aes_hash_shift = (data_v_i & data_enc_i) | gh_hash_v; 
always @(posedge clk) 
	if (aes_hash_set) aes_hash_q <= aes_res; 
	else if (aes_hash_shift) aes_hash_q <= {aes_hash_q[W-PHY_W-1:0], {PHY_W{1'b0}}};

// J0 is the same as the C block counter + 1, IV is 96 bits and is constant during 
// then entire encryption
wire [W-1:0]    iv; 
wire [C_CNT_W-1:0] iv_lsb;
assign iv_lsb = (fsm_q == FSM_ICV_CALC) ? c_cnt_q : {{C_CNT_W-1{1'b0}}, 1'b1};
assign iv     = { sci_i, pn_i, {32-C_CNT_W{1'b0}}, iv_lsb}; 

aes_compact m_aes(
	.clk(clk), 
	.rst_n(rst_n), 
	
	.start_i (fsm_aes_q == FSM_AES_LD_DATA), 
	.data_v_i(fsm_aes_q == FSM_AES_LD_DATA),
	.data_i  (iv), 
	
	.key_v_i(fsm_aes_q == FSM_AES_LD_KEY), 
	.key_i  (key_q), 
	
	.res_v_o(aes_res_v),
	.res_o  (aes_res)
);

/* GHASH fsm
Tracks what the current ghash module is hashing at the moment and what it should hash next.
 */ 
localparam FSM_GHASH_IDLE    = 3'd0; 
localparam FSM_GHASH_LD_H    = 3'd1; 
localparam FSM_GHASH_HASH_A  = 3'd2; // authentification data
localparam FSM_GHASH_HASH_C  = 3'd3; // ciphered data
localparam FSM_GHASH_HASH_L  = 3'd4; // lengths
localparam FSM_GHASH_RES     = 3'd5;

reg [2:0] fsm_gh_q;
always @(posedge clk) begin
	if (~rst_n) fsm_gh_q <= FSM_GHASH_IDLE; 
	else case (fsm_gh_q) 
		FSM_GHASH_IDLE:   fsm_gh_q <= sram_v_i & sram_h_i ? FSM_GHASH_LD_H: FSM_GHASH_IDLE; 
		FSM_GHASH_LD_H:   fsm_gh_q <= ~sram_h_i ? FSM_GHASH_HASH_A: FSM_GHASH_LD_H; 
		FSM_GHASH_HASH_A: fsm_gh_q <= data_v_i & data_enc_i? FSM_GHASH_HASH_C :
                                      data_v_i & data_last_i ? FSM_GHASH_HASH_L: FSM_GHASH_HASH_A;  
		FSM_GHASH_HASH_C: fsm_gh_q <= payload_finished & gh_res_v ? FSM_GHASH_HASH_L: FSM_GHASH_HASH_C;
		FSM_GHASH_HASH_L: fsm_gh_q <= gh_res_v? FSM_GHASH_RES: FSM_GHASH_HASH_L;
		FSM_GHASH_RES:    fsm_gh_q <= ~gh_res_v? FSM_GHASH_IDLE: FSM_GHASH_RES;  
		default:          fsm_gh_q <= FSM_GHASH_IDLE;  
	endcase
end

wire             gh_res_v; 
wire [PHY_W-1:0] gh_res;
wire             gh_hash_res_early_unused; 

// GHASH final hash is valid for xor with aes hash to produce icv
assign gh_hash_v = gh_res_v & ((fsm_gh_q == FSM_GHASH_HASH_L) | (fsm_gh_q == FSM_GHASH_RES)); 

/* next data to hash, shift in data PHY_W bits at a time, 
clean to 0s when we trigger a partial block hash */
wire         gh_start_early; 
wire         gh_start;  // start ghash on full block 
reg  [W-1:0] gh_buff_q;  
wire [W-1:0] gh_buff_rst; 

assign gh_start_early = (fsm_gh_q == FSM_GHASH_HASH_A & (data_v_i & data_enc_i)) // A->C
					  | payload_finished; // A->L, C->L

assign gh_start = 1'b0; // TODO 
// guarantied to at least have 16B of A, so we do not need to clear on init
localparam GHASH_BLOCK_CNT_W = 64;
wire [W-1:0]     gh_buff_l;
wire [PHY_W-1:0] res_next; 
 
assign gh_buff_l   = {{GHASH_BLOCK_CNT_W-A_CNT_W{1'b0}}, a_cnt_q, {GHASH_BLOCK_CNT_W-C_CNT_W{1'b0}}, c_cnt_q};
assign gh_buff_rst = payload_finished ? gh_buff_l : {res_next, {W-PHY_W{1'b0}}};
always @(posedge clk) 
	if (gh_start_early) gh_buff_q <= gh_buff_rst; 
	else if (data_v_i) 	gh_buff_q <= { res_next , gh_buff_q[W-1:PHY_W]}; // do not shift on L 

ghash #(.SRAM_W(SRAM_W), .PHY_W(PHY_W)) m_ghash(
	.clk  (clk), 
	.rst_n(rst_n), 

	.data_v_i(gh_start), 
	.data_i  (gh_buff_q),
 
	.h_v_i(sram_v_i & sram_h_i), 
	.h_i  (sram_i), 

	.res_shift_i   (gh_hash_v),
	.res_early_v_o (gh_hash_res_early_unused),
	.res_v_o       (gh_res_v),
	.res_o         (gh_res)
	);


// data pipe 
wire [PHY_W-1:0] data; // next data
wire [PHY_W-1:0] data_xor_aes; 

assign data = gh_hash_v ? gh_res : data_i; 
assign data_xor_aes = data ^ aes_hash_q[W-1-:PHY_W]; 
assign res_next = fsm_q == FSM_A ? data : data_xor_aes;


// output 
assign data_v_o     = 1'bx; 
assign data_start_o = 1'bx; 
assign data_last_o  = 1'bx; 
assign data_o       = res_next; 
endmodule
