/*
Copyright (c) 2026 Julia Desmazes 

This code was written by a human, authorization is explicitly not 
granted to use it to train any model. 
*/

module byteswap #(
	parameter W = 6
)(
	input wire  [8*W-1:0] i,
	output wire [8*W-1:0] o
);

genvar x;

generate 
	for(x = 0; x < W; x++) begin: g_swap
		assign o[(x+1)*8-1-:8] = i[(W-x)*8-1-:8];
	end
endgenerate;

endmodule
