`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:48:55 10/25/2021 
// Design Name: 
// Module Name:    aes_top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module aes_enc(
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
	// wire [127:0] data_current;
	
	reg  [3:0] fsm_q;
	wire [3:0] fsm_next;
	wire       fsm_en;
	wire       finished_v;
	wire       last_iter_v;
	
	wire       unused_fsm_sum_msb;
	
	
	// SubBytes
	wire [127:0] sub_bytes;
	wire [31:0]  sub_bytes_row[3:0];
	// ShiftRow
	wire [127:0] shift_row;
	wire [31:0]  shift_row_row[3:0];
	// ShiftRow
	wire [127:0] mix_columns;
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
	
	
	// Sbox
	genvar sb_i;
	generate 
		for (sb_i=0; sb_i<16; sb_i=sb_i+1) begin : loop_gen_sb_i				
			aes_sbox sb(
				.data_i( data_q[(sb_i*8)+7:(sb_i*8)]),
				//.data_i( 8'h0),
				.data_o( sub_bytes[(sb_i*8)+7:(sb_i*8)])
		        	);
		end
	endgenerate
	
	// ShiftRows : rows : [ 3,
	//								2,
	//								1,
	//								0 ]
	genvar sr_r;
	generate 
		for (sr_r=0; sr_r<4; sr_r=sr_r+1) begin : loop_gen_sr_r
			assign sub_bytes_row[sr_r] = { sub_bytes[3*32+8*sr_r+7:3*32+8*sr_r],
													 sub_bytes[2*32+8*sr_r+7:2*32+8*sr_r],
													 sub_bytes[32+8*sr_r+7:32+8*sr_r],
													 sub_bytes[8*sr_r+7:8*sr_r] };
			assign { shift_row[3*32+8*sr_r+7:3*32+8*sr_r],
						shift_row[2*32+8*sr_r+7:2*32+8*sr_r],
						shift_row[1*32+8*sr_r+7:1*32+8*sr_r],
						shift_row[0*32+8*sr_r+7:0*32+8*sr_r] } = shift_row_row[sr_r];
		end
	endgenerate
		
	assign shift_row_row[3]  =  sub_bytes_row[3]; // row0 no shift
	assign shift_row_row[2]  =  { sub_bytes_row[2][23:16], sub_bytes_row[2][15:8],  sub_bytes_row[2][7:0] ,  sub_bytes_row[2][31:24] }; // row1 0,1,2,3 -> 1,2,3,0
	assign shift_row_row[1]  =  { sub_bytes_row[1][15:8],  sub_bytes_row[1][7:0],   sub_bytes_row[1][31:24], sub_bytes_row[1][23:16] }; // row2 0,1,2,3 -> 2,3,0,1
	assign shift_row_row[0]  =  { sub_bytes_row[0][7:0] ,  sub_bytes_row[0][31:24], sub_bytes_row[0][23:16], sub_bytes_row[0][15:8] };  // row3 0,1,2,3 -> 3,0,1,2 : d,c,b,a -> a,d,c

	// MixColumns
	genvar mc_c; // collumn [ 3, 2, 1, 0 ]
	generate 
		for (mc_c=0; mc_c<4; mc_c=mc_c+1) begin : loop_gen_mc_c
			// assign shift_row_col[mc_c] = { shift_row[3*32+8*mc_c+7:3*32+8*mc_c],shift_row[2*32+8*mc_c+7:2*32+8*mc_c],shift_row[32+8*mc_c+7:32+8*mc_c],shift_row[8*mc_c+7:8*mc_c] };
			
			aes_mixw mixw ( 
				.w_i(    shift_row[  mc_c*32+31:mc_c*32] ), 
				.mixw_o( mix_columns[mc_c*32+31:mc_c*32])
			);
			
//			assign { mix_columns[3*32+8*mc_c+7:3*32+8*mc_c],
//						mix_columns[2*32+8*mc_c+7:2*32+8*mc_c],
//						mix_columns[32+8*mc_c+7:32+8*mc_c],
//						mix_columns[8*mc_c+7:8*mc_c] } = mix_columns_col[mc_c];
		end
	endgenerate
	
	// AddRoundKey : bitwise XOR
	// bypass mix columns for last round
	assign round_key_next = data_v_i ? data_i :( last_iter_v ?  shift_row : mix_columns );
	assign round_key = round_key_next ^ key_current;
	assign data_next = round_key;
	
	// Key calculation 	
	assign key_current      = data_v_i ? key_i        : key_q;
	assign key_rcon_current = data_v_i ? 8'b0000_0001 : key_rcon_q;
	
	aes_key_shedualing m_key_shedualing(
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
