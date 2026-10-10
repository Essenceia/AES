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
localparam FSM_IDLE     = 3'd0; 
localparam FSM_A        = 3'd1; 
localparam FSM_C        = 3'd2; 
localparam FSM_ICV_CALC = 3'd3; 
localparam FSM_ICV      = 3'd4; 
reg [2:0] fsm_q; 

localparam FSM_GHASH_IDLE          = 3'd0; 
localparam FSM_GHASH_LD_H          = 3'd1; 
localparam FSM_GHASH_HASH_A        = 3'd2; // authentification data
localparam FSM_GHASH_HASH_A_PAD    = 3'd3; // authentification data
localparam FSM_GHASH_HASH_C        = 3'd4; // ciphered data
localparam FSM_GHASH_HASH_C_PAD    = 3'd5; // ciphered data
localparam FSM_GHASH_HASH_L        = 3'd6; // lengths
localparam FSM_GHASH_RES           = 3'd7;
reg [2:0] fsm_gh_q;


wire [PHY_W-1:0] data_xor_aes; 

// key must be fully stored outside of aes as is needs to be refresed before 
// each block
reg [W-1:0] key_q;
wire        key_v;  

always @(posedge clk) 
	if (sram_v_i & sram_k_i) key_q <= {key_q[W-SRAM_W-1:0], sram_i};  

assign key_v = sram_v_i & sram_h_i; // H is after K

localparam B_CNT_MAX = W/PHY_W;
localparam B_CNT_W = $clog2(B_CNT_MAX); 
/* verilator lint_off WIDTHTRUNC */
localparam [B_CNT_W-1:0] B_CNT_MAX_MIN1 = B_CNT_MAX - 1; 
localparam [B_CNT_W-1:0] B_CNT_MAX_MIN2 = B_CNT_MAX - 2; 
/* verilator lint_on WIDTHTRUNC */

// C block count, assuming a max of 16k Bytes
// init value at 2 to not need an additional inc_32 before first aes 
// cipher
// Increment at the start of any new block 
reg [C_CNT_W-1:0] iv_cnt_q; 
reg [C_CNT_W-1:0] c_cnt_msb_q; 
reg [A_CNT_W-1:0] a_cnt_msb_q;
wire c_cnt_msb_en; // aes result finished and we can start next block 
wire a_cnt_msb_en; 

reg  [B_CNT_W-1:0] b_cnt_q; 
wire [B_CNT_W-1:0] b_cnt_next; 
reg  [B_CNT_W-1:0] tag_cnt_q; 
wire b_cnt_rst; 

assign b_cnt_rst  = init_i | ((fsm_q == FSM_A) & data_v_i & data_enc_i); // rst block cnt when switching from A->C
assign b_cnt_next = b_cnt_q + {{B_CNT_W-1{1'b0}}, 1'b1};

always @(posedge clk) 
	if (b_cnt_rst) b_cnt_q <= {B_CNT_W{1'b0}};
	else if (data_v_i) b_cnt_q <= b_cnt_next;

assign a_cnt_msb_en = (b_cnt_q == B_CNT_MAX_MIN1) & (fsm_q == FSM_A) & data_v_i & ~data_enc_i; 
assign c_cnt_msb_en = (b_cnt_q == B_CNT_MAX_MIN1) & (fsm_q == FSM_C) & data_v_i; 
always @(posedge clk) begin
	if (init_i) begin
		 iv_cnt_q 	 <= {{C_CNT_W-2{1'b0}}, 2'd2}; 
		 c_cnt_msb_q <= {C_CNT_W{1'b0}}; 
	end else if (c_cnt_msb_en) begin
		iv_cnt_q     <= iv_cnt_q    + {{C_CNT_W-1{1'b0}}, c_cnt_msb_en}; 
		c_cnt_msb_q  <= c_cnt_msb_q + {{C_CNT_W-1{1'b0}}, c_cnt_msb_en};
	end
end
always @(posedge clk) 
	if (init_i) a_cnt_msb_q <= {A_CNT_W{1'b0}};
	else if (a_cnt_msb_en) a_cnt_msb_q <= a_cnt_msb_q + {{A_CNT_W-1{1'b0}}, 1'b1};

// lsb
reg [B_CNT_W-1:0] a_cnt_lsb_q;  
reg [B_CNT_W-1:0] c_cnt_lsb_q;  
wire c_cnt_lsb_en; 
wire a_cnt_lsb_en; 

assign c_cnt_lsb_en = (fsm_q == FSM_C) & data_v_i & data_last_i; 
always @(posedge clk)
	if (init_i) c_cnt_lsb_q <= {B_CNT_W{1'b0}}; // need to rst since there might not be any C in pkt
	else if (c_cnt_lsb_en) c_cnt_lsb_q <= b_cnt_next; 

assign a_cnt_lsb_en = (fsm_q == FSM_A) & data_v_i & (data_enc_i | data_last_i); 
always @(posedge clk)
	if (a_cnt_lsb_en) a_cnt_lsb_q <= b_cnt_next;  

wire gh_res_v; 
wire gh_res_early_v; 
always @(posedge clk) 
	if (gh_res_early_v) tag_cnt_q <= {B_CNT_W{1'b0}};
	else tag_cnt_q <= tag_cnt_q + {{B_CNT_W-1{1'b0}}, 1'b1};

// main fsm 

wire pkt_end;  // last data seen 
wire tag_v; 

assign pkt_end = data_v_i & data_last_i; 
always @(posedge clk) begin
	if (~rst_n) fsm_q <= FSM_IDLE; 
	else case (fsm_q)
		FSM_IDLE:     fsm_q <= init_i ? FSM_A: FSM_IDLE; 
		FSM_A:        fsm_q <= (data_v_i & data_enc_i)? FSM_C : 
					           pkt_end ? FSM_ICV_CALC: FSM_A; 
		FSM_C:        fsm_q <= pkt_end ? FSM_ICV_CALC: FSM_C; 
		FSM_ICV_CALC: fsm_q <= gh_res_v & (fsm_gh_q == FSM_GHASH_RES) ? FSM_ICV: FSM_ICV_CALC; 
		FSM_ICV:      fsm_q <= tag_cnt_q == B_CNT_MAX_MIN1 ? FSM_IDLE: FSM_ICV;
		default:      fsm_q <= FSM_IDLE; 
	endcase
end
assign tag_v = (fsm_q == FSM_ICV) | (fsm_gh_q == FSM_GHASH_RES & gh_res_v); 
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
wire aes_hash_set; 
wire aes_force_tag; // force dropping of current block hash and calculation of tag hash
assign aes_force_tag = data_v_i & data_last_i; 
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
		default:         fsm_aes_q <= FSM_AES_IDLE;  
	endcase
end

reg pkt_end_q; // indicated whether we are calculating the aes for the tag or the plain text 
always @(posedge clk) 
	if (~rst_n | init_i) pkt_end_q <= 1'b0; 
	else pkt_end_q <= pkt_end_q | pkt_end; 


// previous aes hash
wire         aes_hash_shift; 
wire [W-1:0] aes_res; 
reg          aes_hash_v_q;  

assign aes_hash_set = (b_cnt_q == B_CNT_MAX_MIN1 & fsm_q == FSM_C)
					| (aes_res_v & fsm_q == FSM_A & ~aes_hash_v_q)
					| (aes_res_v & fsm_q == FSM_ICV_CALC); 
`ifdef TB
assert(aes_hash_set |-> aes_rev_v | fsm_aes_q == FSM_AES_RES); 
`endif 
always @(posedge clk) 
	if (init_i) aes_hash_v_q <= 1'b0;  
	else aes_hash_v_q <= aes_hash_v_q | aes_res_v; 

assign aes_hash_shift = (data_v_i & data_enc_i) | tag_v; 
always @(posedge clk) 
	if (aes_hash_set) aes_hash_q <= aes_res; 
	else if (aes_hash_shift) aes_hash_q <= {aes_hash_q[W-PHY_W-1:0], {PHY_W{1'bx}}};

// J0 is the same as the C block counter + 1, IV is 96 bits and is constant during 
// then entire encryption
wire [W-1:0]    iv; 
wire [C_CNT_W-1:0] iv_lsb;
assign iv_lsb = (fsm_q != FSM_ICV_CALC) ? iv_cnt_q : {{C_CNT_W-1{1'b0}}, 1'b1};
assign iv     = {sci_i, pn_i, {32-C_CNT_W{1'b0}}, iv_lsb}; 

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
wire             gh_active; 
wire [PHY_W-1:0] gh_res;
wire             gh_l_start_next; 
reg              fsm_gh_c_next_q; 
wire             gh_buff_a_shift_done; 
wire             gh_buff_c_shift_done; 


always @(posedge clk) 
	if (init_i | (fsm_gh_q == FSM_GHASH_HASH_C)) fsm_gh_c_next_q <= 1'b0; 
	else fsm_gh_c_next_q <= fsm_gh_c_next_q | (data_v_i & data_enc_i);
 
always @(posedge clk) begin
	if (~rst_n) fsm_gh_q <= FSM_GHASH_IDLE; 
	else case (fsm_gh_q) 
		FSM_GHASH_IDLE:       fsm_gh_q <=  sram_v_i & sram_h_i ? FSM_GHASH_LD_H:   FSM_GHASH_IDLE; 
		FSM_GHASH_LD_H:       fsm_gh_q <= ~sram_v_i & data_v_i ? FSM_GHASH_HASH_A: FSM_GHASH_LD_H; 
		FSM_GHASH_HASH_A:     fsm_gh_q <= ~(data_enc_i | data_last_i) ? FSM_GHASH_HASH_A:
							  			   (b_cnt_q == B_CNT_MAX_MIN1) ? (data_enc_i ? FSM_GHASH_HASH_C : FSM_GHASH_HASH_L):// transition, is block on boundary else go to pad
						                   FSM_GHASH_HASH_A_PAD;
		FSM_GHASH_HASH_A_PAD: fsm_gh_q <= ~gh_active & gh_buff_a_shift_done ? (fsm_gh_c_next_q ? FSM_GHASH_HASH_C: FSM_GHASH_HASH_L) :
							  		       FSM_GHASH_HASH_A_PAD; 
		FSM_GHASH_HASH_C:     fsm_gh_q <= (data_last_i | pkt_end_q)? ((b_cnt_q == B_CNT_MAX_MIN1) ? FSM_GHASH_HASH_L : FSM_GHASH_HASH_C_PAD) :
							  			   FSM_GHASH_HASH_C;
		FSM_GHASH_HASH_C_PAD: fsm_gh_q <= ~gh_active ? FSM_GHASH_HASH_L: FSM_GHASH_HASH_C_PAD; 
		FSM_GHASH_HASH_L:     fsm_gh_q <= ~gh_active? FSM_GHASH_RES:  FSM_GHASH_HASH_L;
		FSM_GHASH_RES:        fsm_gh_q <=  gh_res_v? FSM_GHASH_IDLE: FSM_GHASH_RES;  
		default:              fsm_gh_q <=  FSM_GHASH_IDLE;  
	endcase
end

/* next data to hash, shift in data PHY_W bits at a time, 
clean to 0s when we trigger a partial block hash */
wire         gh_start; 
 
// A, L buffers
wire         gh_buff_rst; 
reg  [W-1:0] gh_buff_q;  
wire [W-1:0] gh_buff_rst_next; 
// C buffers 
wire          gh_buff_c_rst; 
reg  [W-1:0]  gh_buff_c_q; 

reg           gh_buff_full_q; 
always @(posedge clk) 
	gh_buff_full_q <= (b_cnt_q == B_CNT_MAX_MIN1); 

assign gh_start = ((fsm_gh_q == FSM_GHASH_HASH_A | fsm_gh_q == FSM_GHASH_HASH_C) & gh_buff_full_q)
                | (~gh_active & ( 
					(fsm_gh_q == FSM_GHASH_HASH_A_PAD & gh_buff_a_shift_done) 
				   |(fsm_gh_q == FSM_GHASH_HASH_C_PAD & gh_buff_c_shift_done) 
                   | fsm_gh_q == FSM_GHASH_HASH_L));
// buffer shift counters
localparam SHIFT_CNT_W = B_CNT_W - 2;// $clog2(8/PHY_W);
localparam SHIFT_CNT_MAX = 15; 
 
reg [SHIFT_CNT_W-1:0] gh_buff_a_shift_q; 
reg [SHIFT_CNT_W-1:0] gh_buff_c_shift_q; 
assign gh_buff_a_shift_done = gh_buff_a_shift_q == SHIFT_CNT_MAX; 
assign gh_buff_c_shift_done = gh_buff_c_shift_q == SHIFT_CNT_MAX; 

always @(posedge clk) 
	if (fsm_gh_q == FSM_GHASH_HASH_A) gh_buff_a_shift_q <= b_cnt_q[B_CNT_W-1:2];
	else if (~gh_buff_a_shift_done) gh_buff_a_shift_q <= gh_buff_a_shift_q + {{SHIFT_CNT_W-1{1'b0}}, 1'b1};
always @(posedge clk) 
	if (fsm_gh_q == FSM_GHASH_HASH_C) gh_buff_c_shift_q <= b_cnt_q[B_CNT_W-1:2];
	else if (~gh_buff_c_shift_done) gh_buff_c_shift_q <= gh_buff_c_shift_q + {{SHIFT_CNT_W-1{1'b0}}, 1'b1};

// L
localparam GHASH_BLOCK_CNT_W = 64;
wire [PHY_W-1:0] res_next; 
wire [W-1:0]     gh_buff_l;
wire [W-1:0]     gh_buff_l_swap;

wire [GHASH_BLOCK_CNT_W-1:0] gh_l_a = { {GHASH_BLOCK_CNT_W-A_CNT_W-B_CNT_W-1{1'b0}}, a_cnt_msb_q, a_cnt_lsb_q , 1'b0};
wire [GHASH_BLOCK_CNT_W-1:0] gh_l_c = { {GHASH_BLOCK_CNT_W-A_CNT_W-B_CNT_W-1{1'b0}}, c_cnt_msb_q, c_cnt_lsb_q , 1'b0};
assign gh_buff_l = {gh_l_a, gh_l_c};
byteswap #(.W(W/8)) m_gh_l_byteswap(
	.i(gh_buff_l), 
	.o(gh_buff_l_swap));

// A, L gh buffer
wire [W-1:0] gh_buff_rst_next_data; // iverilog bugs
wire [W-1:0] gh_buff_next; 
 
assign gh_buff_rst_next_data[W-1-:PHY_W]  = data_i;
assign gh_buff_rst_next_data[W-PHY_W-1:0] = {W-PHY_W{1'bx}};
assign gh_buff_rst_next = (fsm_gh_q == FSM_GHASH_HASH_L) ? gh_buff_l_swap: gh_buff_rst_next_data; 

assign gh_buff_next[W-1-:PHY_W]  = data_i; 
assign gh_buff_next[W-PHY_W-1:0] = gh_buff_q[W-1:PHY_W];

assign gh_buff_rst = (fsm_q == FSM_A) & ~|b_cnt_q // A block start, even if A is guarantied to be at least 16B on init, this allows us to do zero append 
				   | (fsm_gh_q == FSM_GHASH_HASH_L); 

always @(posedge clk) 
	if (gh_buff_rst)  gh_buff_q <= gh_buff_rst_next; // A data guaranties 4 cycles minumum so it will be set for A
	else if (data_v_i & ~data_enc_i) gh_buff_q <= gh_buff_next; // do not shift on L
	else if ((fsm_gh_q == FSM_GHASH_HASH_A_PAD) & (gh_buff_a_shift_q!= SHIFT_CNT_MAX)) gh_buff_q <= {{8{1'b0}}, gh_buff_q[W-1:8]}; // we have at least a 32 cycle gap while previous buff is being calculated to perform the shift 

// C gh buffer
assign gh_buff_c_rst = (fsm_q == FSM_C) & ~|b_cnt_q; 
always @(posedge clk) 
	if (gh_buff_c_rst) gh_buff_c_q <= {data_xor_aes,{W-PHY_W{1'b0}}};
	else if (data_v_i & data_enc_i) gh_buff_c_q <= {data_xor_aes, gh_buff_c_q[W-1:PHY_W]};

wire [W-1:0] gh_data; 
wire [W-1:0] gh_data_swap; 
assign gh_data = (fsm_gh_q == FSM_GHASH_HASH_C) ? gh_buff_c_q : gh_buff_q;

byteswap #(.W(W/8)) m_gh_byteswap(
	.i(gh_data), 
	.o(gh_data_swap));

ghash #(.SRAM_W(SRAM_W), .PHY_W(PHY_W)) m_ghash(
	.clk  (clk), 
	.rst_n(rst_n), 

	.data_v_i(gh_start), 
	.data_i  (gh_data_swap),
 
	.h_v_i(sram_v_i & sram_h_i), 
	.h_i  (sram_i), 

	.res_shift_i   (tag_v),
	.res_early_v_o (gh_res_early_v),
	.res_v_o       (gh_res_v),
	.res_o         (gh_res),

	.active_o      (gh_active) 
	);


// data pipe 
wire [PHY_W-1:0] data; // next data

assign data = tag_v ? gh_res : data_i; 
assign data_xor_aes = data ^ aes_hash_q[W-1-:PHY_W]; 
assign res_next = fsm_q == FSM_A ? data : data_xor_aes;


// output 
assign data_v_o     = ((fsm_gh_q == FSM_GHASH_RES) & gh_res_v) | (fsm_q == FSM_ICV) | data_v_i; 
assign data_start_o = 1'bx; 
assign data_last_o  = tag_v & (tag_cnt_q == B_CNT_MAX_MIN1); 
assign data_o       = res_next;

// debug 
wire [127:0] debug_ghash_final = 128'h1BDA7DB505D8A165264986A703A6920D;
wire [127:0] debug_aes_final   = 128'hEB4E051CB548A6B5490F6F11A27CB7D0;

wire [127:0] debug_t_final = debug_ghash_final ^ debug_aes_final; 
endmodule
