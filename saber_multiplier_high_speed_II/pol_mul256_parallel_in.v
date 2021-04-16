`timescale 1ns / 1ps

module poly_mul256_parallel_in2 
                                #(parameter MULTIPLIERS = 1) // 0 for 256 multipliers, 1 for 512
                                (clk, rst, acc_clear, pol_load_coeff4x,
								bram_address_relative, pol_64bit_in,  
								s_address, s_vec_64, s_load_happens_now,
								read, coeff4x_out, pol_mul_done);
								
								
input clk, rst;
input pol_load_coeff4x; // If 1 then input data contains 4 uint16_t coefficients
input acc_clear; // clears accumulator register
output reg [6:0] bram_address_relative;
input [63:0] pol_64bit_in;								
output [7:0] s_address;	// Assumes s is in BRAM. There is 1 cycle delay between address and data. 
input [63:0] s_vec_64;
output s_load_happens_now;  // This is 1 when secret is loaded from RAM. When polynomial is loaded then this signal is 0. Used to mux sec/pol
input read;

output [63:0] coeff4x_out;	// 4 coefficients, each as uint16_t
output pol_mul_done;

reg rst_s_load;
wire s_load, s_load_done;

reg poly_load;

reg shift_secret, acc_en, bram_address_inc;
reg [3:0] state, nextstate;
reg [8:0] counter;
wire counter_finish;
wire [12 + 13 * MULTIPLIERS:0] a_coeff;

reg [675:0] a_buffer; // 676 = lcm(64, 13) - 12*13. If MULTIPLIERS == 1, only 520 bits are needed
reg poly_shift;
wire buffer_empty;

reg [3:0] buffer_counter;
reg rst_buffer_counter;
wire buffer_counter_finish;

reg [5:0] mult_counter;
reg rst_mult_counter;
wire mult_counter_finish;

reg [1023:0] secret;
reg [3327:0] acc;
wire [3327:0] result;


poly_load_control_BRAM1 PLC(clk, rst, s_address, s_load, s_load_done);

buffer_muxer1 #(.MULTIPLIERS(MULTIPLIERS))
            BUFFMUX(MULTIPLIERS == 1 ? a_buffer[481 : 456] : a_buffer[624 : 612], 
                    MULTIPLIERS == 1 ? a_buffer[443 : 418] : a_buffer[573 : 561], 
                    MULTIPLIERS == 1 ? a_buffer[405 : 380] : a_buffer[522 : 510], 
                    MULTIPLIERS == 1 ? a_buffer[367 : 342] : a_buffer[471 : 459], 
                    MULTIPLIERS == 1 ? a_buffer[329 : 304] : a_buffer[420 : 408], 
                    MULTIPLIERS == 1 ? a_buffer[291 : 266] : a_buffer[369 : 357], 
                    MULTIPLIERS == 1 ? a_buffer[253 : 228] : a_buffer[318 : 306], 
                    MULTIPLIERS == 1 ? a_buffer[215 : 190] : a_buffer[267 : 255], 
                    MULTIPLIERS == 1 ? a_buffer[177 : 152] : a_buffer[216 : 204], 
                    MULTIPLIERS == 1 ? a_buffer[139 : 114] : a_buffer[165 : 153], 
                    MULTIPLIERS == 1 ? a_buffer[101 : 76] : a_buffer[114 : 102], 
                    MULTIPLIERS == 1 ? a_buffer[63 : 38] : a_buffer[63 : 51], 
                    MULTIPLIERS == 1 ? a_buffer[25 : 0] : a_buffer[12 : 0], // values for 13-bit
                    
                    MULTIPLIERS == 1 ? a_buffer[63 : 32] : a_buffer[63 : 48], 
                    MULTIPLIERS == 1 ? a_buffer[31 : 0] : a_buffer[15 : 0], // values for 16-bit
                    
					buffer_counter, pol_load_coeff4x, a_coeff);

parallel_Mults1 PMULTs(clk, acc, secret, a_coeff, result);




always @(posedge clk) // load s
begin
    if(rst)
        secret <= 1024'd0;
	else if (s_load)
	begin
		secret <= {s_vec_64, secret[1023:64]};   
     end   
	else if (shift_secret)
		begin
		    if (MULTIPLIERS == 0)
			     secret <= {secret[1019:0], secret[1023:1020] ^ 4'b1000}; // xor with 1000 to flip the sign
			else
			     secret <= {secret[1015:0], secret[1023:1016] ^ 8'b10001000}; // xor with 1000 to flip the sign  
		end
	else
	   begin
	       secret <= secret;
	   end	
	

end

always @(posedge clk) // load and shift polynomial
begin
	if (pol_load_coeff4x == 0)
		begin
			if (poly_load)
				begin
				    if (MULTIPLIERS == 1)
					   a_buffer[519:0] <= {pol_64bit_in, a_buffer[519:64]};
					else
					   a_buffer <= {pol_64bit_in, a_buffer[675:64]};
				end
			else if (poly_shift)
				begin
				    if (MULTIPLIERS == 1)
					   a_buffer <= {26'b0, a_buffer[519:26]};
					else
					   a_buffer <= {13'b0, a_buffer[675:13]};
				end
		end
	else
		begin
			if (poly_load) begin
			    if (MULTIPLIERS == 1)
				    a_buffer[95:0] <= {pol_64bit_in, a_buffer[95:64]};
				else
				    a_buffer[111:0] <= {pol_64bit_in, a_buffer[111:64]}; // 112 = 128 - 16
				   
			end else if (poly_shift) begin
			    if (MULTIPLIERS == 1)
				    a_buffer[95:0] <= {32'b0, a_buffer[95:32]};
				else
				    a_buffer[111:0] <= {16'b0, a_buffer[111:16]};
			end
		end
end


wire ccounter =  counter > 3;

always @(posedge clk) // loads results into the accumulator 
begin
	if (acc_clear)
		acc <= 3328'd0;
	else if (shift_secret && ccounter)
		acc <= result;
	else if (read)
		acc <= {acc[51:0], acc[3327:52]};
end

assign coeff4x_out = pol_load_coeff4x ?
					  {6'd0, acc[48:39], 6'd0, acc[35:26], 6'd0, acc[22:13], 6'd0, acc[9:0]} :
					  {3'd0, acc[51:39], 3'd0, acc[38:26], 3'd0, acc[25:13], 3'd0, acc[12:0]};


always @(posedge clk)
begin
	if (rst)
		bram_address_relative <= 7'd0;
	else if (bram_address_inc && !buffer_counter_finish) // '&& !buffer_counter_finish' prevents one increase too many on state change
		bram_address_relative <= bram_address_relative + 7'd1;
	else
		bram_address_relative <= bram_address_relative;
end
		


always @(posedge clk) // keep count of buffer shifts
begin
	if (rst || rst_buffer_counter)
		buffer_counter <= 4'd0;
	else if (bram_address_inc)
		buffer_counter <= buffer_counter + 4'd1;
	else
		buffer_counter <= buffer_counter;
end

assign buffer_counter_finish = pol_load_coeff4x ? (state == 4'd4) : buffer_counter == 4'd11 ? 1'b1 : 1'b0;

assign s_load_happens_now = (state==4'd0 || state==4'd1) ? 1'b1 : 1'b0;

always @(posedge clk) // keep count of buffer shifts
begin
	if (rst || rst_buffer_counter)
		mult_counter <= 6'd0;
	else if (poly_shift)
		mult_counter <= mult_counter + 6'd1;
	else
		mult_counter <= mult_counter;
end

assign buffer_empty = pol_load_coeff4x ? (mult_counter == (MULTIPLIERS == 1 ? 6'd0 : 6'd4) ? 1'b1 : 1'b0) : 
                                          mult_counter == (MULTIPLIERS == 1 ? 6'd17 : 6'd49) ? 1'b1 : 1'b0;


always @(posedge clk)
begin
	if (rst)
		counter <= 9'd0;
	else if (shift_secret)
		counter <= counter + 9'd1;
	else
		counter <= counter;
end

assign counter_finish = counter >= (MULTIPLIERS == 1 ? 9'd130 : 9'd255) + 9'd1;


///// State management ///////////////////////////////////////////

always @(posedge clk)
begin
	if (rst)
		state <= 4'd0;
	else 
		state <= nextstate;
end

always @(state)
begin
	case(state)
		0: begin // beginning. 1 cycle, once
				shift_secret<=1'b0; bram_address_inc<=1'b0; poly_load <= 0; poly_shift <= 0; rst_buffer_counter <= 0; rst_mult_counter <= 0;
		   end
		1: begin // load the secret 's'. 20 cycle, once
				shift_secret<=1'b0; bram_address_inc<=1'b0; poly_load <= 0; poly_shift <= 0; rst_buffer_counter <= 0; rst_mult_counter <= 0;
		   end		
		2: begin // start things with a two-cycle delay (bram_address_inc). 1 cycle, once
				shift_secret<=1'b0; bram_address_inc<=1'b1; poly_load <= 0; poly_shift <= 0; rst_buffer_counter <= 1; rst_mult_counter <= 0;
		   end
		3: begin // load the first 64 bits (practically the first round of state 4). 1 cycle, once
				shift_secret<=1'b0; bram_address_inc<=1'b1; poly_load <= 1; poly_shift <= 0; rst_buffer_counter <= 1; rst_mult_counter <= 0;
		   end
		4: begin // load the rest of a, while doing multiplications using the buffer muxer. 12 cycles, 4 times
				shift_secret<=1'b1; bram_address_inc<=1'b1; poly_load <= 1; poly_shift <= 0; rst_buffer_counter <= 0; rst_mult_counter <= 0;
		   end
		5: begin // multiply the last 13 bits of the buffer with s, without loading any more data, 50 cycles, 4 times
				shift_secret<=1'b1; bram_address_inc<=1'b0; poly_load <= 0; poly_shift <= 1; rst_buffer_counter <= 0; rst_mult_counter <= 0;
		   end
		6: begin // "penultimate" round of state 5, turn bram_address_inc because of two-cycle delay. 1 cycle, 4 times
				shift_secret<=1'b1; bram_address_inc<=1'b1; poly_load <= 0; poly_shift <= 1; rst_buffer_counter <= 0; rst_mult_counter <= 0;
		   end
		7: begin // "last" round of state 5, load the next 64 bit. 1 cycle, 4 times
				shift_secret<=1'b1; bram_address_inc<=1'b1; poly_load <= 1; poly_shift <= 0; rst_buffer_counter <= 1; rst_mult_counter <= 1;
		   end	
		8: begin // final state, computation has terminated.
				shift_secret<=1'b0; bram_address_inc<=1'b0; poly_load <= 0; poly_shift <= 0; rst_buffer_counter <= 0; rst_mult_counter <= 0;
		   end			
		default: begin
				shift_secret<=1'b0; bram_address_inc<=1'b0; poly_load <= 0; poly_shift <= 0; rst_buffer_counter <= 0; rst_mult_counter <= 0;
		   end			
	endcase
end	

always @(state or counter_finish or s_load_done or buffer_counter_finish or buffer_empty)
begin
	case(state)
		0: nextstate <= 1;
		1: begin
				if (s_load_done)
					nextstate <= 2;
				else
					nextstate <= 1;
			  end
		2: nextstate <= 3;
		3: nextstate <= 4;
		4: begin
		        if (counter_finish)
					nextstate <= 8;
				else if (buffer_counter_finish)
					nextstate <= 5;
				else
					nextstate <= 4;
			  end
		5: begin
		        if (counter_finish)
					nextstate <= 8;
				else if (buffer_empty)
					nextstate <= 6;
				else
					nextstate <= 5;
			  end
		6: nextstate <= 7;
		7: begin
				if (counter_finish)
					nextstate <= 8;
				else
					nextstate <= 4;
			  end
		8: nextstate <= 8;
		default: nextstate <= 0;
	endcase
end

wire pol_mul_done = (state == 4'd8) ? 1'b1 : 1'b0;

	
endmodule