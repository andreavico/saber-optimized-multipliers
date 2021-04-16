`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:04:11 02/17/2020 
// Design Name: 
// Module Name:    buffer_muxer 
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
module buffer_muxer1(buffer_end, input_ten_bit_0, selector, ten_bit_coeff, out);

input [23:0] buffer_end;
input [12:0] input_ten_bit_0;
input ten_bit_coeff;
input [5:0] selector;

output wire [12:0] out;


assign out = ten_bit_coeff ? (buffer_end[12:0]) : //selector == 0 ? input_ten_bit_0 : 
		selector  <  9 ? buffer_end[12:0] :
                selector ==  9 ? {buffer_end[13:12], buffer_end[10:0]} :
                selector  < 14 ? buffer_end[13:1] :
                selector == 14 ? {buffer_end[14:12], buffer_end[10:1]} :
                selector  < 19 ? buffer_end[14:2] :
                selector == 19 ? {buffer_end[15:12], buffer_end[10:2]} :
                selector  < 24 ? buffer_end[15:3] :
                selector == 24 ? {buffer_end[16:12], buffer_end[10:3]} :
                selector  < 29 ? buffer_end[16:4] :
                selector == 29 ? {buffer_end[17:12], buffer_end[10:4]} :
                selector  < 34 ? buffer_end[17:5] :
                selector == 34 ? {buffer_end[18:12], buffer_end[10:5]} :
                selector  < 39 ? buffer_end[18:6] :
                selector == 39 ? {buffer_end[19:12], buffer_end[10:6]} :
                selector  < 44 ? buffer_end[19:7] :
                selector == 44 ? {buffer_end[20:12], buffer_end[10:7]} :
                selector  < 49 ? buffer_end[20:8] :
                selector == 49 ? {buffer_end[21:12], buffer_end[10:8]} :
                selector  < 54 ? buffer_end[21:9] :
                selector == 54 ? {buffer_end[22:12], buffer_end[10:9]} :
                selector  < 59 ? buffer_end[22:10] :
                selector == 59 ? {buffer_end[23:12], buffer_end[10]} :
                buffer_end[23:11];
			
endmodule