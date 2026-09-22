/*
Copyright Julia Desmazes, 2026, all rights reserved

Ghash function needs 64 cycles to hash each new data block 
*/

function [127:0] VI_INC1 (input [127:0] vi_prev);
begin 
	// (Vi >> 1) ^ R with R implied
	assign VI_INC1[127]     = vi_prev[0];
	assign VI_INC1[126]     = vi_prev[127] ^ vi_prev[0];
	assign VI_INC1[125]     = vi_prev[126] ^ vi_prev[0];
	assign VI_INC1[124:121] = vi_prev[125:122];
	assign VI_INC1[120]     = vi_prev[121] ^ vi_prev[0];
	assign VI_INC1[119:0]   = vi_prev[120:1];
end
endfunction

module ghash #(
	parameter W = 128
)(
	input wire clk, 
	input wire rst_n, 

	input wire         new_v_i, // reset ghash, new hash
	// X
	input wire         data_v_i, // new block can only be provided every 64 cycles
	input wire [W-1:0] data_i, 

	// sub key, H stays constant for the entire hash
	// is providable before the first data block
	input wire         h_v_i,
	input wire [W-1:0] h_i, 
	
	output wire         res_v_o,
	output wire [W-1:0] res_o
);
localparam SHIFT_N = 2; 

localparam CNT_MAX = W / SHIFT_N; 
localparam CNT_W = $clog2(CNT_MAX);
localparam [CNT_W-1:0] CNT_MAX_MIN1 = CNT_MAX - 1;

localparam [W-1:0] R = {8'b11100001, {120{1'b0}}};

// fsm 
localparam IDLE =  1'd0;
localparam BLOCK = 1'd1;
reg  fsm_q;
wire block_finished; 

always @(posedge clk) begin
	if (~rst_n | new_v_i ) begin
		fsm_q <= IDLE; 
		cnt_q <= {CNT_W{1'b0}};
	end else begin
		case(fsm_q)
			IDLE: begin
				fsm_q <= data_v_i ? BLOCK : IDLE; 
				cnt_q <= {CNT_W{1'b0}};	
			end
			BLOCK: begin
				fsm_q <= block_finished ? IDLE: BLOCK; 
				cnt_q <= cnt_q + {{CNT_W-1{1'b0}}, 1'b0}; 
			end
		endcase
	end
end

assign block_finished = cnt_q == CNT_MAX_MIN1;
reg res_v_q; 
always @(posedge clk) 
	res_v_q <= block_finished; 

// galois dot product
// X
reg [W-1:0] x_q; 
wire xi, xi_inc; 
always @(posedge clk) 
	if (data_v_i) x_q <= data_i; // { x0, x1, x2 ... x127}
	else x_q <= {x_q[W-SHIFT_N-1:0], {SHIFT_N{1'bx}} }; // implied fsm_q == BLOCK 
	
assign xi = x_q[W-1];
assign xi_inc = x_q[W-2];

reg [W-1:0] v0_q;
always @(posedge clk) 
	if (h_v_i) v0_q <= h_i; 

// V_i, Z_i
reg [W-1:0]  v_q, z_q;
wire [W-1:0] vi, vi_inc, zi, zi_inc; 

always @(posedge clk) begin 
	if (data_v_i) begin
		z_q <= {W{1'b0}};
		v_q <= v0_q;
	end else begin
		z_q <= zi_inc; 
		v_q <= vi_ic;
	end
end
assign vi     = VI_INC1(v_q);
assign vi_inc = VI_INC1(vi);

assign zi     = z_q ^ ({W{xi}} & vi);
assign zi_inc = zi ^ ({W{xi_inc}} & vi_inc);

// output 
assign res_v_o = res_v_q; 
assign res_o   = z_q;

endmodule
