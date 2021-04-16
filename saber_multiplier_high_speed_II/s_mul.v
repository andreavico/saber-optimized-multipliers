`timescale 1ns / 1ps

module small_alu1 (clk, s0, s1, a0, a1, a0s0, a0s1_a1s0, a1s1);
input clk;
input [12:0] a0, a1;
input  [3:0] s0, s1;
output [12:0] a0s0, a0s1_a1s0, a1s1;

reg [2:0] buf0, buf1, buf2, buf3;

always @(posedge clk) begin
	buf0 <= {a1[0] & s1[0], s1[3], s0[3]};
end

always @(posedge clk) begin
	buf1 <= buf0;
end

always @(posedge clk) begin
	buf2 <= buf1;
end

always @(posedge clk) begin
	buf3 <= buf2;
end

wire [12:0] a_0 = ((s0[3] ^ s1[3]) == 1) ? -a0 : a0;

wire [26:0] A = {1'b0, a1[10:0], 2'b0, a_0};
wire [17:0] S = {1'b0, s1[1:0], 12'b0, s0[2:0]};

wire [26:0] a_sp = s1[2] == 2'd0 ? 27'b0 : A;
wire [17:0] ap_s = a1[12:11] == 2'd0 ? 17'b0 :
				   a1[12:11] == 2'd1 ? S :
				   a1[12:11] == 2'd2 ? {S, 1'b0} :
				   S[16:0] + {S[16:0], 1'b0};

wire [47:0] result;
wire [47:0] C = {a_sp, 17'b0} + {ap_s, 26'b0};

dsp_1827 DSP(.clk(clk), .A(A), .B(S), .C(C), .P(result));

wire [12:0] a0s0 = buf3[1] ? -result[12:0]  : result[12:0];
wire [12:0] a0s1_a1s0 = buf3[0] ? -result[27:15] : result[27:15];
wire [12:0] a1s1_ = buf3[2] == result[30] ? result[42:30] : result[42:30] - 1'b1;
wire [12:0] a1s1 = 	buf3[1] ? -a1s1_ : a1s1_;

wire error = buf3[2] != result[30];
wire [12:0] a0s0_corr = s0[3] == 1'b1 ? -a0*s0[2:0] : -a0*s0[2:0];
wire [12:0] a1s1_corr = s1[3] == 1'b1 ? -a1*s1[2:0] : -a1*s1[2:0];

endmodule
