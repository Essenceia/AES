/*
Copyright Julia Desmazes, 2026, all rights reserved

Ghash partial dot product for calculating V_(i+1) based on V_i
*/
module ghash_v_partial_dot_porduct#(
	localparam W = 128
)(
	input  wire [W-1:0] vi_i,
	output wire [W-1:0] vi_inc_o
);
	// (Vi >> 1) ^ R with R implied
	assign vi_inc_o[127]     = vi_i[0];
	assign vi_inc_o[126]     = vi_i[127] ^ vi_i[0];
	assign vi_inc_o[125]     = vi_i[126] ^ vi_i[0];
	assign vi_inc_o[124:121] = vi_i[125:122];
	assign vi_inc_o[120]     = vi_i[121] ^ vi_i[0];
	assign vi_inc_o[119:0]   = vi_i[120:1];
endmodule


