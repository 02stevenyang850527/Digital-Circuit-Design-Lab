module Top(
	input i_clk,
	input i_start,
	output [3:0] o_random_out
);
`ifdef FAST_SIM
	parameter FREQ_HZ = 1000;
`elsif
	parameter FREQ_HZ = 50000000;
`endif

	localparam MAX_VAL = 15;
	localparam MIN_VAL = 0;
	localparam OUTPUT_TIME_1 = 50;
	localparam OUTPUT_TIME_2 = 100;
	localparam OUTPUT_TIME_3 = 150;
	localparam OUTPUT_TIME_4 = 300;
	localparam OUTPUT_TIME_5 = 600;
	reg [31:0] counter;
	reg [ 3:0]  temp;

	always_comb begin

	end

	always_ff @(posedge i_clk or posedge i_start) begin
		if(i_start) begin
			counter <= 32'b0;
		end else begin
			temp <= $urandom_range(MAX_VAL, MIN_VAL);
			counter <= counter + 32'b1;
		end

		case(counter)
			OUTPUT_TIME_1:
			OUTPUT_TIME_2:
			OUTPUT_TIME_3:
			OUTPUT_TIME_4:
			OUTPUT_TIME_5:
			begin o_random_out <= temp; end
		endcase
	end

endmodule