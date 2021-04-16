`timescale 1ns / 1ps

module buffer_muxer1
                    #(parameter MULTIPLIERS = 1)
                    (input0, input1, input2, input3,
					input4, input5, input6, input7,
					input8, input9, input10, input11,
					input12, input_ten_bit_0, input_ten_bit_1,
					selector, ten_bit_coeff, out);

input [12 + 13 * MULTIPLIERS : 0] input0, input1, input2, input3, input4, input5, input6, input7, 
			 input8, input9, input10, input11, input12;
input [15 + 16 * MULTIPLIERS : 0] input_ten_bit_0, input_ten_bit_1;
input ten_bit_coeff;
input [3:0] selector;

output wire [12 + 13*MULTIPLIERS : 0] out;


wire [12 + 13 * MULTIPLIERS : 0] input_filtered_0 = MULTIPLIERS == 1 ? {input_ten_bit_0[28 : 16], input_ten_bit_0[12 : 0]} : input_ten_bit_0[12:0];
wire [12 + 13 * MULTIPLIERS : 0] input_filtered_1 = MULTIPLIERS == 1 ? {input_ten_bit_1[28 : 16], input_ten_bit_1[12 : 0]} : input_ten_bit_1[12:0];
    
assign out = ten_bit_coeff ? selector == 0 ? input_filtered_0 : input_filtered_1 :
				selector == 0 ? input0 :
				selector == 1 ? input1 :
				selector == 2 ? input2 :
				selector == 3 ? input3 :
				selector == 4 ? input4 :
				selector == 5 ? input5 :
				selector == 6 ? input6 :
				selector == 7 ? input7 :
				selector == 8 ? input8 :
				selector == 9 ? input9 :
				selector == 10 ? input10 :
				selector == 11 ? input11 :
				input12;
			
endmodule