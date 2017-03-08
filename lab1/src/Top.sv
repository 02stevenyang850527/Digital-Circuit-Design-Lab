module Top(
	input i_clk,
	input i_rst,
	input i_start,
	output [3:0] o_random_out
);
`ifdef FAST_SIM
	parameter FREQ_HZ = 1000;
`elsif
	parameter FREQ_HZ = 50000000;
`endif

	parameter MAX_VAL = 15;
	parameter MIN_VAL = 0;

	enum {IDLE, RUN} state_w, state_r;
//	logic state_w, state_r;
	logic [31:0] 	counter_w, counter_r;
	logic [3:0]		random_w, random_r;

	logic i_start_tmp;
	initial begin
		#5 i_start_tmp = 0;
		#5 i_start_tmp = 1;
		#5 i_start_tmp = 0;
	end


	assign o_random_out = random_r;

	always_comb begin
		counter_w = counter_r + 1;
		state_w = state_r;
		random_w = random_r;

		case(state_r)
			IDLE:	
					if (i_start == 1) begin
						state_w = RUN;
						counter_w = 0;
						random_w = 0;
						end

			RUN:	
					case(counter_r)
						500,
						1000,
						1500,
						3000,
						6000: 	begin
								random_w = $urandom_range(MAX_VAL,MIN_VAL);
								end

						10000:	begin
								state_w = IDLE;
								counter_w = 0;
								end
					endcase
		endcase // state_r
	end


	always_ff @(posedge i_clk) begin
		counter_r <= counter_w;
		state_r <= state_w;
		random_r <= random_w;
	end
endmodule
