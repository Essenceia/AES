// ^    : +
// &    : x
// ~(^) : #

module aes_inv_sbox(
    input  [7:0] data_i,
    output [7:0] data_o
    );

	wire[0:7] u, w;
	
	wire [63:0] m;
	wire [27:0] t;
	wire [19:0] r;
	wire [5:5]  y;
	wire [29:0] p;
	// input
	assign u = data_i;
	
	// aes sbox on a byte
	assign t[23] =  u[0]  ^ u[3];
	assign t[22] = ~(u[1]  ^ u[3]);
	assign t[2]  = ~(u[0]  ^ u[1]);
	assign t[1]  =  u[3]  ^ u[4];
	assign t[24] = ~(u[4]  ^ u[7]);
	assign r[5]  =  u[6]  ^ u[7];
	assign t[8]  = ~(u[1]  ^ t[23]);
	assign t[19] =  t[22] ^ r[5];
	assign t[9]  = ~(u[7]  ^ t[1]);
	assign t[10] =  t[2]  ^ t[24];
	assign t[13] =  t[2]  ^ r[5];
	assign t[3]  =  t[1]  ^ r[5];
	assign t[25] = ~(u[2]  ^ t[1]);
	assign r[13] =  u[1]  ^ u[6];
	assign t[17] = ~(u[2]  ^ t[19]);
	assign t[20] =  t[24] ^ r[13];
	assign t[4]  =  u[4]  ^ t[8];
	assign r[17] = ~(u[2]  ^ u[5]);
	assign r[18] = ~(u[5]  ^ u[6]);
	assign r[19] = ~(u[2]  ^ u[4]);
	assign y[5]  =  u[0]  ^ r[17];
	assign t[6]  =  t[22] ^ r[17];
	assign t[16] =  r[13] ^ r[19];
	assign t[27] =  t[1]  ^ r[18];
	assign t[15] =  t[10] ^ t[27];
	assign t[14] =  t[10] ^ r[18];
	assign t[26] =  t[3]  ^ t[16];
	assign m[1]  =  t[13] & t[6];
	assign m[2]  =  t[23] & t[8];
	assign m[3]  =  t[14] ^ m[1];
	assign m[4]  =  t[19] & y[5];
	assign m[5]  =  m[4]  ^ m[1];
	assign m[6]  =  t[3]  & t[16];
	assign m[7]  =  t[22] & t[9];
	assign m[8]  =  t[26] ^ m[6];
	assign m[9]  =  t[20] & t[17];
	assign m[10] =  m[9]  ^ m[6];
	assign m[11] =  t[1]  & t[15];
	assign m[12] =  t[4]  & t[27];
	assign m[13] =  m[12] ^ m[11];
	assign m[14] =  t[2]  & t[10];
	assign m[15] =  m[14] ^ m[11];
	assign m[16] =  m[3]  ^ m[2];
	assign m[17] =  m[5]  ^ t[24];
	assign m[18] =  m[8]  ^ m[7];
	assign m[19] =  m[10] ^ m[15];
	assign m[20] =  m[16] ^ m[13];
	assign m[21] =  m[17] ^ m[15];
	assign m[22] =  m[18] ^ m[13];
	assign m[23] =  m[19] ^ t[25];
	assign m[24] =  m[22] ^ m[23];
	assign m[25] =  m[22] & m[20];
	assign m[26] =  m[21] ^ m[25];
	assign m[27] =  m[20] ^ m[21];
	assign m[28] =  m[23] ^ m[25];
	assign m[29] =  m[28] & m[27];
	assign m[30] =  m[26] & m[24];
	assign m[31] =  m[20] & m[23];
	assign m[32] =  m[27] & m[31];
	assign m[33] =  m[27] ^ m[25];
	assign m[34] =  m[21] & m[22];
	assign m[35] =  m[24] & m[34];
	assign m[36] =  m[24] ^ m[25];
	assign m[37] =  m[21] ^ m[29];
	assign m[38] =  m[32] ^ m[33];
	assign m[39] =  m[23] ^ m[30];
	assign m[40] =  m[35] ^ m[36];
	assign m[41] =  m[38] ^ m[40];
	assign m[42] =  m[37] ^ m[39];
	assign m[43] =  m[37] ^ m[38];
	assign m[44] =  m[39] ^ m[40];
	assign m[45] =  m[42] ^ m[41];
	assign m[46] =  m[44] & t[6];
	assign m[47] =  m[40] & t[8];
	assign m[48] =  m[39] & y[5];
	assign m[49] =  m[43] & t[16];
	assign m[50] =  m[38] & t[9];
	assign m[51] =  m[37] & t[17];
	assign m[52] =  m[42] & t[15];
	assign m[53] =  m[45] & t[27];
	assign m[54] =  m[41] & t[10];
	assign m[55] =  m[44] & t[13];
	assign m[56] =  m[40] & t[23];
	assign m[57] =  m[39] & t[19];
	assign m[58] =  m[43] & t[3];
	assign m[59] =  m[38] & t[22];
	assign m[60] =  m[37] & t[20];
	assign m[61] =  m[42] & t[1];
	assign m[62] =  m[45] & t[4];
	assign m[63] =  m[41] & t[2];
	assign p[0]  =  m[52] ^ m[61];
	assign p[1]  =  m[58] ^ m[59];
	assign p[2]  =  m[54] ^ m[62];
	assign p[3]  =  m[47] ^ m[50];
	assign p[4]  =  m[48] ^ m[56];
	assign p[5]  =  m[46] ^ m[51];
	assign p[6]  =  m[49] ^ m[60];
	assign p[7]  =  p[0]  ^ p[1];
	assign p[8]  =  m[50] ^ m[53];
	assign p[9]  =  m[55] ^ m[63];
	assign p[10] =  m[57] ^ p[4];
	assign p[11] =  p[0]  ^ p[3];
	assign p[12] =  m[46] ^ m[48];
	assign p[13] =  m[49] ^ m[51];
	assign p[14] =  m[49] ^ m[62];
	assign p[15] =  m[54] ^ m[59];
	assign p[16] =  m[57] ^ m[61];
	assign p[17] =  m[58] ^ p[2];
	assign p[18] =  m[63] ^ p[5];
	assign p[19] =  p[2]  ^ p[3];
	assign p[20] =  p[4]  ^ p[6];
	assign p[22] =  p[2]  ^ p[7];
	assign p[23] =  p[7]  ^ p[8];
	assign p[24] =  p[5]  ^ p[7];
	assign p[25] =  p[6]  ^ p[10];
	assign p[26] =  p[9]  ^ p[11];
	assign p[27] =  p[10] ^ p[18];
	assign p[28] =  p[11] ^ p[25];
	assign p[29] =  p[15] ^ p[20];
	assign w[0]  =  p[13] ^ p[22];
	assign w[1]  =  p[26] ^ p[29];
	assign w[2]  =  p[17] ^ p[28];
	assign w[3]  =  p[12] ^ p[22];
	assign w[4]  =  p[23] ^ p[27];
	assign w[5]  =  p[19] ^ p[24];
	assign w[6]  =  p[14] ^ p[23];
	assign w[7]  =  p[9]  ^ p[16];
	
	// output 
	assign data_o = w;

endmodule
