module parallel_Mults1 #(parameter NUM_MAC = 8) (acc, secret, a_coeff, result);
input [NUM_MAC * 16 - 1:0] acc;
input [NUM_MAC *  4 - 1:0] secret;
input [12:0] a_coeff;
output [NUM_MAC * 16 - 1:0] result;

wire [12:0] ax2 = {a_coeff[11:0], 1'b0};
wire [12:0] ax3 = a_coeff + {a_coeff[11:0], 1'b0};
wire [12:0] ax4 = {a_coeff[10:0], 2'b00};

genvar i;
generate
    for (i=0; i<NUM_MAC; i=i+1) begin : MAC_units
    small_alu1 sa0(
             acc[i*16 + 12 : i*16],
             secret[i*4+3:i*4],
             a_coeff, ax2, ax3, ax4,
             result[i*16 + 15 : i*16]);
end 
endgenerate

endmodule