`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:32:37 04/18/2019 
// Design Name: 
// Module Name:    poly_mul256 
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

module poly_mul256_parallel_in2 #(parameter NUM_MAC = 4)
                               (clk, rst, acc_clear, pol_load_coeff4x,
								bram_address_relative, pol_64bit_in,  
								s_address, s_vec_64, load_selector,
								acc_address_in, acc64_in,
								acc_address_out, write_to_BRAM, coeff4x_out, pol_mul_done);								
								
input clk, rst;
input pol_load_coeff4x; // If 1 then input data contains 4 uint16_t coefficients
input acc_clear; // clears accumulator register
output reg [6:0] bram_address_relative; //FIXME: can be smaller
input [63:0] pol_64bit_in;								
output reg [3:0] s_address;	// Assumes s is in BRAM. There is 1 cycle delay between address and data. 
input [63:0] s_vec_64;
output reg [1:0] load_selector;  // 0: a_polynomial, 1: secret, 2: accumulator

output [5:0] acc_address_in, acc_address_out;
input [63:0] acc64_in;
output reg write_to_BRAM;

output [63:0] coeff4x_out;	// 4 coefficients, each as uint16_t
output pol_mul_done;

reg rst_s_load;

reg poly_load;

reg shift_secret, acc_en, bram_address_inc;
reg [3:0] state, nextstate;
reg [8:0] counter;
wire counter_finish;
wire [12:0] a_coeff;

reg result_out;

reg [127:0] a_buffer;
reg [1:0] a_load_counter;
wire a_load_done;
wire a_done;

reg poly_shift;
wire buffer_empty, buffer_half_empty;

reg [2:0] buffer_counter;
reg rst_buffer_counter;
wire buffer_counter_finish;

reg [5:0] mult_counter;
wire mult_counter_finish;

reg [1:0] partial_mult_counter;
// wire partial_mult_done;

reg [1:0] write_block_index;


reg [127:0] secret;
reg [4:0] s_buffer_counter;
reg [3:0] s_block_counter;
reg [1:0] s_load_counter;
reg s_load, load_s_after_a, s_negate;
wire s_load_done, s_buffer_empty;

reg [63:0] acc;
wire [NUM_MAC * 16 - 1:0] result;

// wire error;
// assign error = poly_load & load_accumulator;

//poly_load_control_BRAM1 PLC(clk, rst, s_address, s_load, s_load_done);

buffer_muxer1 BUFFMUX(a_buffer[23:0], // values for 13-bit
					 a_buffer[60 : 48], // values for 16-bit
					 mult_counter, pol_load_coeff4x, a_coeff);


parallel_Mults1 #(NUM_MAC) PMULTs (acc64_in, secret[79:64], a_coeff, result);


always @(posedge clk) // load s
begin
    if (rst || state == 0 || (state == 1 && !s_load_done) || (s_buffer_empty && !buffer_half_empty && !buffer_empty) || (state == 4 && load_s_after_a) || (state == 2 && load_s_after_a && a_load_done) || state == 6)
        load_selector <= 2'd1;
	else if (s_load_done || (state == 2 && !a_load_done) || buffer_half_empty || buffer_empty)
		load_selector <= 2'd0;
    else
        load_selector <= 2'd2;
end











always @(posedge clk)
begin
    if (rst || state == 4'd5)
        load_s_after_a <= 1'b0;
	else if ((buffer_empty || buffer_half_empty) && s_buffer_empty)
	begin
		load_s_after_a <= 1'b1;
    end
end








always @(posedge clk) // load s
begin
    if (rst)
        s_block_counter <= 4'd0;
	else if (s_load_done)
		s_block_counter <= s_block_counter + 4'd1;
    else
        s_block_counter <= s_block_counter;
end


always @(posedge clk) // load s
begin
    if (rst) begin
        secret <= 128'd0;
	end else if (state == 1) begin
		secret <= {secret[63:0], s_vec_64};
	end else if (state == 5) begin
		secret <= {secret[127:64], s_vec_64};
    end else if (state == 3) begin
    	if (partial_mult_done)
    		secret <= {secret[75:64], secret[127:80], secret[63] ^ s_negate, secret[62:0], 4'b0};
    	else
			secret <= {secret[79:64], secret[127:80], secret[63:0]};
    end
end


always @(posedge clk) // load s
begin
    if (rst) begin
        s_address <= 3'b0;
	end else if (state == 0 || (state == 1 && !s_load_done) || state == 5 || state == 6) begin
		s_address <= s_address - 3'b1;
    end else if (a_done) begin
		s_address <= s_block_counter;
	end
end

always @(posedge clk) // load s
begin
    if(rst || state == 6)
        s_load_counter <= 2'd0;
	else if (state == 1)
	begin
		s_load_counter <= s_load_counter + 2'b1;
    end
end

always @(posedge clk) // keep count of buffer shifts                 
begin                                                                
	if (rst || state == 12 || state == 6)
		s_buffer_counter <= 6'd0;                                              
	else if (state == 3 && partial_mult_done)   
		s_buffer_counter <= s_buffer_counter + 6'd1;                               
	else                                                                
		s_buffer_counter <= s_buffer_counter;                                      
end 

assign s_load_done = s_load_counter == 2'd1; //FIXME: reduce counter size to 1 bit
assign s_load_happens_now = (state==4'd0 || state==4'd1) ? 1'b1 : 1'b0;
assign s_buffer_empty = partial_mult_done && s_buffer_counter == 4'd15; //mult_counter == 15 mod 16
// assign s_negate = mult_counter >= 4*(s_block_counter - 1);

always @(posedge clk) // keep count of buffer shifts                 
begin                                                                
	if (rst || state == 1)
		s_negate <= 2'd0;                                              
	else if (s_address == 14 || s_block_counter == 1)   
		s_negate <= 2'd1;                               
	else                                                                
		s_negate <= s_negate;                                      
end 

















always @(posedge clk)
begin
    if (rst || state == 0 || state == 6)
        bram_address_relative <= 0;
	else if ((state == 2 && !a_load_done) || state == 4)
	begin
		bram_address_relative <= bram_address_relative + 1;
    end
end

always @(posedge clk) // load and shift polynomial
begin
	if (rst)
		a_buffer <= 128'b0;
	else if (pol_load_coeff4x == 0)
		begin
			if (state == 2 && !s_load_done && !buffer_empty) begin
			    a_buffer <= {pol_64bit_in, a_buffer[127:64]};
		    end else if (state == 3 && partial_mult_done) begin
		        a_buffer <= {13'b0, a_buffer[127:13]};
		    end else if (state == 4) begin
		        a_buffer <= {pol_64bit_in, a_buffer[63:0]};
		    end
		end
	else
		begin
			if (state == 2 && !s_load_done && !buffer_empty) begin
			    a_buffer <= {pol_64bit_in, a_buffer[127:64]};
		    end else if (state == 3 && partial_mult_done) begin
		        a_buffer <= {16'b0, a_buffer[127:16]};
		    end else if (state == 4) begin
		        a_buffer <= {pol_64bit_in, a_buffer[63:0]};
		    end
		end
end

always @(posedge clk) // keep count of buffer shifts                 
begin                                                                
	if (rst || state == 2)
		mult_counter <= 6'd0;                                              
	else if (state == 3 && partial_mult_done)   
		mult_counter <= mult_counter + 6'd1;                               
	else                                                                
		mult_counter <= mult_counter;                                      
end   

always @(posedge clk) // keep count of buffer shifts                 
begin                                                                
	if (rst || state == 2 || state == 4)                                      
		buffer_counter <= 6'd0;                                              
	else if (state == 3 && partial_mult_done)   
		buffer_counter <= buffer_counter + 6'd1;                               
	else                                                                
		buffer_counter <= buffer_counter;                                      
end                                                                  

assign buffer_half_empty = buffer_counter == (pol_load_coeff4x ? 3 : 4) && partial_mult_done && mult_counter < 57;
assign buffer_empty = mult_counter == 63 && partial_mult_done && bram_address_relative != (pol_load_coeff4x ? 64 : 52);
assign a_done = mult_counter == 63 && partial_mult_done && bram_address_relative == (pol_load_coeff4x ? 64 : 52);

always @(posedge clk) // load s
begin
    if (rst || state == 3)
        a_load_counter <= 2'd0;
	else if (state == 2)
	begin
		a_load_counter <= a_load_counter + 2'b1;
    end
end
assign a_load_done = a_load_counter == 2'd2;



assign acc_address_out = ((s_block_counter - 1) << 2) + (write_block_index == 0 ? 3 : write_block_index == 1 ? 0 : write_block_index == 2 ? 1 : 2); 
assign acc_address_in =  ((s_block_counter - 1) << 2) + (write_block_index); // == 0 ? 1 : write_block_index == 1 ? 2 : write_block_index == 2 ? 3: 0); 

always @(posedge clk) // loads results into the accumulator 
begin
	// if (state == 3 && !buffer_half_empty || state == 10) 
	if ((state == 3 || state == 10) && !buffer_empty && !buffer_half_empty && !s_buffer_empty)
		write_to_BRAM <= 1;
	else
		write_to_BRAM <= 0;
end

always @(posedge clk) // loads results into the accumulator 
begin
	if (acc_clear)
		acc <= 64'd0;
	else if (state == 3)
		acc <= acc64_in;
end

assign coeff4x_out = result;


always @(posedge clk)                     
begin                                     
	if (rst || state == 1)                                 
		write_block_index <= 2'd0;                         
	else if ((state == 3 || state == 10) && !buffer_half_empty && !s_buffer_empty) // && !a_done) // && !s_buffer_empty)
		write_block_index <= write_block_index + 2'd1;              
	else                                     
		write_block_index <= write_block_index;                     
end   


always @(posedge clk)                     
begin                                     
	if (rst || state == 1)                                 
		partial_mult_counter <= -1;                         
	else if (state == 3) //((state == 3 || state == 10) && !buffer_half_empty) // && !s_buffer_empty)
		partial_mult_counter <= partial_mult_counter + 2'd1;              
	else                                     
		partial_mult_counter <= partial_mult_counter;                     
end                                       
                                          
assign partial_mult_done = partial_mult_counter == 2; //(256/NUM_MAC - 1);



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
				shift_secret<=1'b0; bram_address_inc<=1'b0; poly_load <= 0; poly_shift <= 0; rst_buffer_counter <= 0; result_out <= 0;
		   end
		1: begin // load the secret 's'. 20 cycle, once
				s_load <= 1'b1; shift_secret<=1'b0; bram_address_inc<=1'b0; poly_load <= 0; poly_shift <= 0; rst_buffer_counter <= 0;
		   end		
		2: begin // start things with a two-cycle delay (bram_address_inc). 1 cycle, once
				s_load <= 1'b0; shift_secret<=1'b0; bram_address_inc<=1'b1; poly_load <= 0; poly_shift <= 0; rst_buffer_counter <= 1;
		   end
		3: begin // load the first 64 bits (practically the first round of state 4). 1 cycle, once
				shift_secret<=1'b0; bram_address_inc<=1'b1; poly_load <= 1; poly_shift <= 0; rst_buffer_counter <= 1; result_out <= 1;
		   end
		4: begin // load the rest of a, while doing multiplications using the buffer muxer. 12 cycles, 4 times
				shift_secret<=1'b1; bram_address_inc<=1'b1; poly_load <= 1; poly_shift <= 0; rst_buffer_counter <= 0; 
		   end
		5: begin // multiply the last 13 bits of the buffer with s, without loading any more data, 50 cycles, 4 times
				shift_secret<=1'b1; bram_address_inc<=1'b0; poly_load <= 0; poly_shift <= 1; rst_buffer_counter <= 0;
		   end
		9: begin // multiply the last 13 bits of the buffer with s, without loading any more data, 50 cycles, 4 times
                shift_secret<=1'b1; bram_address_inc<=1'b1; poly_load <= 1; poly_shift <= 0; rst_buffer_counter <= 0;
                      end
        10: begin // load the first 64 bits (practically the first round of state 4). 1 cycle, once
                                      shift_secret<=1'b1; bram_address_inc<=1'b1; poly_load <= 1; poly_shift <= 0; rst_buffer_counter <= 1; result_out <= 1;
                                 end
		6: begin // "penultimate" round of state 5, turn bram_address_inc because of two-cycle delay. 1 cycle, 4 times
				shift_secret<=1'b1; bram_address_inc<=1'b0; poly_load <= 0; poly_shift <= 1; rst_buffer_counter <= 0;
		   end
		7: begin // "last" round of state 5, load the next 64 bit. 1 cycle, 4 times
				shift_secret<=1'b1; bram_address_inc<=1'b0; poly_load <= 1; poly_shift <= 0; rst_buffer_counter <= 1;
		   end	
		8: begin // final state, computation has terminated.
				shift_secret<=1'b0; bram_address_inc<=1'b0; poly_load <= 0; poly_shift <= 0; rst_buffer_counter <= 0;
		   end			
		default: begin
				shift_secret<=1'b0; bram_address_inc<=1'b0; poly_load <= 0; poly_shift <= 0; rst_buffer_counter <= 0;
		   end			
	endcase
end	

always @(state or counter_finish or s_load_done or a_load_done or buffer_empty or buffer_half_empty or s_buffer_empty or s_block_counter)
begin
	case(state)
		0: nextstate <= 1;
		1: begin // load s, at start
				if (s_load_done)
					nextstate <= 2;
				else
					nextstate <= 1;
			  end
		2: begin // load a, at start
              if (a_load_done) begin
              	if (s_buffer_empty || load_s_after_a)
					nextstate <= 12;
				else
                 	nextstate <= 10;

              end else
                  nextstate <= 2;
            end
		3: begin // compute..!
				if (a_done) begin // it's important that this goes before buffer_empty
					if (s_block_counter == 4'd0)
						nextstate <= 7;
					else
                		nextstate <= 6;
                end
				else if (buffer_half_empty) begin                   
					nextstate <= 11;

				end else if (buffer_empty) begin                   
                   	nextstate <= 2;                  
                end  
                else if (s_buffer_empty || load_s_after_a)
                	nextstate <= 12;
				else
  					nextstate <= 3;
            end
       	11: begin
       			nextstate <= 4;
       		end
		4: begin // load a, during computations
				if (s_buffer_empty || load_s_after_a)
					nextstate <= 12;
				else
					nextstate <= 10;
				end
		12: begin
       			nextstate <= 5;
       		end
		5: begin // load s, during computations
				nextstate <= 10;
		    end
		6: begin // pre-load s, during computations
				nextstate <= 1;
		    end
		7: begin // done!
				nextstate <= 7;
		    end
		10: nextstate <= 3;

	   //  9: nextstate <= 10;
	   // 10: nextstate <= 4;
		// 6: nextstate <= 7;
		// 7: begin	
		// 		if (counter_finish)
		// 			nextstate <= 8;
		// 		else
		// 			nextstate <= 5;
		// 	  end
		// 8: nextstate <= 8;
		default: nextstate <= 0;
	endcase
end

wire pol_mul_done = (state == 4'd7) ? 1'b1 : 1'b0;

endmodule
