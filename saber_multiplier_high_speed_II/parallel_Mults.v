`timescale 1ns / 1ps

module parallel_Mults1 (clk, acc, secret, a_coeff, result);
input clk;
input [3327:0] acc;
input [1023:0] secret;
input [25:0] a_coeff;
output [3327:0] result;

wire [1663:0] a0s0_wire, a1s1_wire, a0s1_s0a1_wire; 

genvar i;
generate
for (i=0; i<128; i=i+1) begin : MAC_units
small_alu1 sa0(clk, 
         secret[i*8+3:i*8], secret[i*8+7:i*8+4],
         a_coeff[12:0], a_coeff[25:13],
         a0s0_wire[13*i+12 : 13*i],
         a0s1_s0a1_wire[13*i+12 : 13*i],
         a1s1_wire[13*i+12 : 13*i]);


assign result[26*i+12 : 26*i] = a0s0_wire[13*i+12 : 13*i] + 
                                (i == 0 ? -a1s1_wire[13*127+12 : 13*127] : a1s1_wire[13*(i-1)+12 : 13*(i-1)]) + 
                                acc[26*i+12 : 26*i];

assign result[26*i+25 : 26*i+13] = a0s1_s0a1_wire[13*i+12 : 13*i] + 
                                   acc[26*i+25 : 26*i+13];

end 
endgenerate



endmodule