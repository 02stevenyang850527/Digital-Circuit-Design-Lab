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

	enum {IDLE, RUN} state_w, state_r;
	logic [31:0] counter_w, counter_r;
	logic [3:0]  random_w, random_r;
	logic [31:0] random_seed_w, random_seed_r;

	assign o_random_out = random_w;

	always_comb begin

		if (state_r == IDLE) begin
			random_w = random_r;
			state_w = IDLE;
			counter_w = 0;
			random_seed_w = random_seed_r;
		end else begin
			counter_w = counter_r + 1;
			case(counter_r)
				 5000000,
				10000000,
				15000000,
				20000000,
				25000000,
				30000000,
				37000000,
				46000000,
				57000000,
				70000000,
				85000000,
				102000000,
				121000000,
				142000000: 	begin
									random_seed_w = random_seed_r * 16807 % 2147483647;
									random_w = random_seed_r[23:6] % 16;
									state_w = state_r;
								end

				142000001:	begin
									state_w = IDLE;
									random_w = random_r;
									random_seed_w = random_seed_r;
								end
						default: begin
									random_w = random_r;
									state_w = state_r;
									random_seed_w = random_seed_r;
									end
					endcase
		end
		if (i_start) begin
			state_w = RUN;
			counter_w = 0;
		end
/*		else begin 
			state_w = state_r;
		end
*/	end


	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			state_r <= IDLE;
			random_r <= 0;
			counter_r <= 0;
			random_seed_r <= 32134;
			end
		else begin
			counter_r <= counter_w;
			state_r <= state_w;
			random_r <= random_w;
			random_seed_r <= random_seed_w;
			end
	end
endmodule
