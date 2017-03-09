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
	logic [31:0] counter_w, counter_r;
	logic [3:0] random_w, random_r;

//	logic i_start_tmp;
//	initial begin
//		#5 i_start_tmp = 0;
//		#5 i_start_tmp = 1;
//		#5 i_start_tmp = 0;
//		state_w = IDLE;
//		$finish;
//	end

	assign o_random_out = random_w;

	always_comb begin

		if (state_r == IDLE)
			begin
				random_w = random_r;
				counter_w = 0;
			end

		else begin
					counter_w = counter_r + 1;
					case(counter_r)
						50,
						100,
						150,
						200,
						250,
						300,
						500,
						800,
						1200,
						1700,
						2300,
						3000,
						3800,
						4700: 	begin
								random_w = $urandom_range(MAX_VAL,MIN_VAL);
								end

						4750:	begin
								state_w = IDLE;
								counter_w = 0;
								end
						default: random_w = random_r;
					endcase
		end
		if (i_start) begin
			state_w = RUN;
			counter_w = 0;
		end

	end


	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			state_r <= IDLE;
			random_r <= 0;
			counter_r <= 0;
			end
		else begin
			counter_r <= counter_w;
			state_r <= state_w;
			random_r <= random_w;
			end
	end
endmodule
