// aes decode , order of main round and operations differ from encode
// decode round :
// 1 - Inv Shift Rows
// 2 - Inv Sub Bytes
// 3 - Inv Mix Columns
// 4 - Add round key ( same )
module aes_dec(
	input clk,
	input nreset,
	 
	output [127:0] res_o,  // result
	output         res_v_o,// valid result
	input          data_v_i,
	input [127:0]  data_i,
	input [127:0]  key_i
	);

	reg  [127:0] data_q;
	wire [127:0] data_next;
	
	reg  [3:0] fsm_q;
	wire [3:0] fsm_next;
	wire       fsm_en;
	wire       finished_v;
	wire       last_iter_v;
	
	wire       unused_fsm_sum_msb;
	
	
	// InvSubBytes
	wire [127:0] inv_sbox_bytes;
	wire [31:0]  debug_inv_sbox[3:0];
	// ShiftRow
	wire [31:0]  data_q_row[3:0];
	wire [127:0] inv_shift_row;
	wire [31:0]  inv_shift_row_row[3:0];
	// Mix columns
	wire [127:0] inv_mix_columns;
	wire [31:0]  debug_inv_mix_columns[3:0];
	// AddRoundKey
	wire [127:0] round_key_next;
	wire [127:0] round_key;
	// key
	reg  [127:0] key_q;
	wire [127:0] key_next;
	wire [127:0] key_current;
	reg  [7:0]   key_rcon_q;
	wire [7:0]   key_rcon_next;
	wire [7:0]   key_rcon_current;
	
	assign fsm_en = |(fsm_q) | data_v_i;
	// increment the fsm next value unless we are on the 11th round ( fsm_q == 4'b1011 is 11 in dec )
	// if we are on the 11 th round we write out the output value and set to valid 
	assign finished_v = fsm_q[3] & fsm_q[1] & fsm_q[0];
	assign {unused_fsm_sum_msb,fsm_next} = finished_v ? 5'b00000 : fsm_q + 4'b0001 ;
	// last iteration to bypass last algo on 10th pass ( fsm_q == 4'b1010 is 10 in dec )
	assign last_iter_v = fsm_q[3] & fsm_q[1]; 
	
	always@(posedge clk) 
	begin : fsm_dff
		if (!nreset) 
			fsm_q <= 4'b0000;
		else
		if ( fsm_en ) 
			fsm_q <= fsm_next;
	end 
	
	always @(posedge clk)
		begin : data_dff
		 data_q <= data_next;
	end 
	
	// Inv ShiftRows : rows : [ 3,
	//			    2,
	//			    1,
	//			    0 ]
	genvar sr_r;
	generate 
		for (sr_r=0; sr_r<4; sr_r=sr_r+1) begin : loop_gen_sr_r
			assign data_q_row[sr_r] = { data_q[3*32+8*sr_r+7:3*32+8*sr_r],// 3
						    data_q[2*32+8*sr_r+7:2*32+8*sr_r],// 2
						    data_q[32+8*sr_r+7:32+8*sr_r],    // 1
						    data_q[8*sr_r+7:8*sr_r] };        // 0
														  
			// debug
			assign debug_inv_sbox[sr_r] = { inv_sbox_bytes[3*32+8*sr_r+7:3*32+8*sr_r],// 3
							inv_sbox_bytes[2*32+8*sr_r+7:2*32+8*sr_r],// 2
							inv_sbox_bytes[32+8*sr_r+7:32+8*sr_r],    // 1
							inv_sbox_bytes[8*sr_r+7:8*sr_r] };        // 0
			assign debug_inv_mix_columns[sr_r] = { inv_mix_columns[3*32+8*sr_r+7:3*32+8*sr_r],// 3
							       inv_mix_columns[2*32+8*sr_r+7:2*32+8*sr_r],// 2
							       inv_mix_columns[32+8*sr_r+7:32+8*sr_r],    // 1
							       inv_mix_columns[8*sr_r+7:8*sr_r] };        // 0
													 
			assign { inv_shift_row[3*32+8*sr_r+7:3*32+8*sr_r],
				 inv_shift_row[2*32+8*sr_r+7:2*32+8*sr_r],
				 inv_shift_row[1*32+8*sr_r+7:1*32+8*sr_r],
				 inv_shift_row[0*32+8*sr_r+7:0*32+8*sr_r] } = inv_shift_row_row[sr_r];
		end
	endgenerate
	// The first row is left unchanged, the second
	// row is shifted to the right by one byte, the third row to the right
	// by two bytes, and the last row to the right by three bytes, all
	// shifts being circular.	
	assign inv_shift_row_row[0]  =  data_q_row[0]; // row0 no shift
	assign inv_shift_row_row[1]  = { data_q_row[1][24:16],   data_q_row[1][15:8], data_q_row[1][7:0], data_q_row[1][31:24]  }; // row1 0,1,2,3 -> 3,0,1,2
	assign inv_shift_row_row[2]  =  { data_q_row[2][15:8],  data_q_row[2][7:0],   data_q_row[2][31:24], data_q_row[2][23:16] }; // row2 0,1,2,3 -> 2,3,0,1
	assign inv_shift_row_row[3]  =  { data_q_row[3][7:0], data_q_row[3][31:24],  data_q_row[3][23:16],   data_q_row[3][15:8] }; // row3 0,1,2,3 -> 1,2,3,0

	// Inv Sbox
	genvar sb_i;
	generate 
		for (sb_i=0; sb_i<16; sb_i=sb_i+1) begin : loop_gen_sb_i				
			aes_inv_sbox isb(
				.data_i( inv_shift_row[(sb_i*8)+7:(sb_i*8)]),
				.data_o( inv_sbox_bytes[(sb_i*8)+7:(sb_i*8)])
			);
		end
	endgenerate
	

	// InvMixColumns
	genvar mc_c; // collumn [ 3, 2, 1, 0 ]
	generate 
		for (mc_c=0; mc_c<4; mc_c=mc_c+1) begin : loop_gen_mc_c
			// assign inv_shift_row_col[mc_c] = { inv_shift_row[3*32+8*mc_c+7:3*32+8*mc_c],inv_shift_row[2*32+8*mc_c+7:2*32+8*mc_c],inv_shift_row[32+8*mc_c+7:32+8*mc_c],inv_shift_row[8*mc_c+7:8*mc_c] };
			
			aes_inv_mixw m_inv_mixw ( 
				.w_i(    round_key[      mc_c*32+31:mc_c*32] ), 
				.mixw_o( inv_mix_columns[mc_c*32+31:mc_c*32])
			);
			
	end
	endgenerate
	
	// AddRoundKey : bitwise XOR
	// bypass mix columns for last round
	//assign round_key_next = data_v_i ? data_i :( last_iter_v ?  inv_sbox_bytes : inv_mix_columns );
	assign round_key_next = data_v_i ? data_i : inv_sbox_bytes ;
	assign round_key = round_key_next ^ key_current;
	
	assign data_next = ( last_iter_v | data_v_i ) ? round_key : inv_mix_columns;
	
	// Key calculation 	
	assign key_current      = data_v_i ? key_i        : key_q;
	assign key_rcon_current = data_v_i ? 8'b0011_0110 : key_rcon_q; // init value at 57
	
	aes_inv_key_shedualing m_inv_key_shedualing(
		 .key_i     (key_current),
		 .key_rcon_i(key_rcon_current),
		 .key_next_o(key_next),
		 .key_rcon_o(key_rcon_next)
    );
	 always @(posedge clk) begin
		 if ( fsm_en ) begin : key_dff
			key_q      <= key_next;
			key_rcon_q <= key_rcon_next;
		 end
	 end
	
	// output
	assign res_v_o = finished_v; // aes is on the 11 th round
	assign res_o   = data_q;

endmodule
