/*
Copyright Julia Desmazes, 2026, all rights reserved

Ghash function needs 32 cycles to hash each new data block 
*/
module ghash #(
	localparam W = 128,
	parameter  SRAM_W = 8
)(
	input wire clk, 
	input wire rst_n, 

	// X
	input wire         data_v_i, // new block can only be provided every 64 cycles
	input wire [W-1:0] data_i, 

	// sub key, H stays constant for the entire hash
	// is providable before the first data block
	input wire              h_v_i, // causes reset of the ghash block 
	input wire [SRAM_W-1:0] h_i, 
	
	output wire         res_v_o,
	output wire [W-1:0] res_o
);
localparam STEPS_CYCLE_N = 4; 

localparam CNT_MAX = W / STEPS_CYCLE_N; 
localparam CNT_W = $clog2(CNT_MAX);
localparam [CNT_W-1:0] CNT_MAX_MIN1 = CNT_MAX - 1;

localparam [W-1:0] R = {8'b11100001, {120{1'b0}}};

// fsm 
localparam IDLE =  1'd0;
localparam BLOCK = 1'd1;
reg             fsm_q;
reg [CNT_W-1:0]  cnt_q;
wire [CNT_W-1:0] cnt_next;
wire            block_finished; 

always @(posedge clk) begin
	if (~rst_n ) begin
		fsm_q <= IDLE; 
		cnt_q <= {CNT_W{1'b0}};
	end else begin
		case(fsm_q)
			IDLE: begin
				fsm_q <= data_v_i ? BLOCK : IDLE; 
				cnt_q <= {CNT_W{1'b0}};	
			end
			BLOCK: begin
				fsm_q <= block_finished ? (data_v_i ? BLOCK : IDLE): BLOCK; 
				cnt_q <= data_v_i ? {CNT_W{1'b0}}: cnt_next; 
			end
		endcase
	end
end

assign cnt_next = cnt_q + {{CNT_W-1{1'b0}}, 1'b1};
assign block_finished = cnt_q == CNT_MAX_MIN1;
reg res_v_q; 
always @(posedge clk) 
	res_v_q <= block_finished; 

// galois dot product
reg [W-1:0]  v_q, z_q;

// X
reg [W-1:0] x_q; 
wire xi[STEPS_CYCLE_N];
 
always @(posedge clk) 
	if (data_v_i) x_q <= data_i ^ z_q; // { x0, x1, x2 ... x127}
	else x_q <= {x_q[W-STEPS_CYCLE_N-1:0], {STEPS_CYCLE_N{1'bx}} }; // implied fsm_q == BLOCK 
	
reg [W-1:0] v0_q;
always @(posedge clk) 
	if (h_v_i) v0_q <= {v0_q[W-SRAM_W-1:0], h_i}; 

// V_i, Z_i internal state
wire [W-1:0] vi_inc[STEPS_CYCLE_N];
wire [W-1:0] zi_inc[STEPS_CYCLE_N]; 

always @(posedge clk)
	if (h_v_i | data_v_i | ~rst_n) z_q <= {W{1'b0}};
	else if (fsm_q == BLOCK) z_q <= zi_inc[STEPS_CYCLE_N]; 

always @(posedge clk) 
	if (data_v_i ) v_q <= v0_q;
	else           v_q <= vi_inc[STEPS_CYCLE_N];

assign vi_inc[0] = v_q; 
assign zi_inc[0] = z_q; 

genvar i; 
generate 
	for(i = 0; i < STEPS_CYCLE_N; i = i + 1) begin : g_steps
		assign xi[i] = x_q[W-1-i];

		// V_(i+1) = V_i[0] ? (V_i >> 1)^R : V_i >> 1
		ghash_v_partial_dot_porduct m_vi(
			.vi_i(v_inc[i]), .vi_inc_o(vi_inc[i+1]));
		
		// Z_(i+1) = x_i ? Z_i ^ V_i : Z_i
		assign zi_inc[i+1] = z_inc[i] ^ ({W{xi[i]}} & v_inc[i]);
	end
endgenerate

// // V_(i+1) = V_i[0] ? (V_i >> 1)^R : V_i >> 1
// ghash_v_partial_dot_porduct m_vi(
// 	.vi_i(v_q), .vi_inc_o(vi));
// 
// ghash_v_partial_dot_porduct m_vi_inc(
// 	.vi_i(vi), .vi_inc_o(vi_inc));
// 
// // Z_(i+1) = x_i ? Z_i ^ V_i : Z_i
// assign zi     = z_q ^ ({W{xi}} & v_q);
// assign zi_inc = zi ^ ({W{xi_inc}} & vi);

// output 
assign res_v_o = res_v_q; 
assign res_o   = z_q;

endmodule
