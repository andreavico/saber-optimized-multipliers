`timescale 1ns / 1ps

module small_alu1(Ri, s, a, ax2, ax3, ax4, result);
input [12:0] Ri, a, ax2, ax3, ax4;
input [3:0] s;
output [12:0] result;

wire [12:0] a_mul_s = s[2:0] == 3'd0 ? 13'd0
					: s[2:0] == 3'd1 ? a
					: s[2:0] == 3'd2 ? ax2
					: s[2:0] == 3'd3 ? ax3
					: ax4;
					
wire [12:0] result = s[3] ? Ri - a_mul_s : Ri + a_mul_s;

endmodule
