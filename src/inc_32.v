/* Copyright Julia Desmazes, 2026, all rights reserved

Incrementing Function as per NIST spec  */
module inc_32 #(
	parameter S = 32, 
	parameter W = 96
)(
	input  wire [W-1:0] data_i, 
	output wire [W-1:0] data_o
);
// inc_S(X) = MSB_{len(X)-S} || [LSB_S(X) + 1 mod 2^S ]_S
wire [S-1:0] inc;
wire inc_unused; 

assign {inc_unused, inc} = data_i[S-1:0] + {{S-1{1'b0}}, 1'b1};
assign data_o = {data_i[W-1:S] ,  inc};

endmodule
