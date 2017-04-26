module sramReader(
	input i_bclk,
	input i_rst,
	input i_enable,
	input i_pause,		// From KEY
	input i_stop,		// From KEY
	input i_speed_up,	// From KEY
	input i_speed_down,	// From KEY
	input i_interpol,
	input i_DACLRCK,
	input [15:0] i_SRAM_DQ,

	output [19:0] o_addr,
	output [15:0] o_DACDAT,

);

	/**********************************
		i_speed representation 
		1xxx: fast
		0xxx: slow	 
		xxx represents the speed
		ex. 1011: 3 time faster
			0101: 1/5 time slower
	**********************************/


	enum {IDLE, STOP, PLAY, PAUSE} state_w, state_r;
	enum {NORMAL, FAST, SLOW} play_mode_w, play_mode_r;
	logic [15:0] data_w, data_r;
	logic [15:0] data_pre_w, data_pre_r;
	logic [15:0] output_data_w, output_data_r;
	logic [19:0] addr_w, addr_r;
	logic [2:0]  speed_w, speed_r;
	logic [2:0]  spd_counter_w, spd_counter_r;

	assign o_addr = addr_r;
	assign o_DACDAT = output_data_r;

	always_comb begin
		state_w = state_r;

		case (state_r)
			IDLE: begin
					if (i_enable) begin
						state_w = STOP;
						addr_w = 0;

					end
			end

			STOP: begin
					if (!i_enable) begin
						state_w = IDLE;
					end else if (i_pause) begin
						state_w = PLAY;
					end
			end

			PLAY: begin 
					if (!i_enable) begin
						state_w = IDLE;
					end else (i_pause) begin
						state_w = PAUSE;
					end

					case (play_mode_r)
						NORMAL: begin
								output_data_w = i_SRAM_DQ;
								addr_w = addr_r + 1;
								if (i_speed_up) begin
									play_mode_w = FAST;
									speed_w = 1;
								end else if (i_speed_down) begin
									play_mode_w = SLOW;
									speed_w = 1;
								end
						end

						FAST: begin 
								output_data_w = i_SRAM_DQ;
								addr_w = addr_r + 1 + speed_r;
								if (i_speed_up) begin
									if (speed_r != 7) begin
										speed_w = speed_r + 1;
									end
								end else if (i_speed_down) begin
									if (speed_r == 1) begin
										play_mode_w = NORMAL;
										speed_w = 0;
									end else begin
										speed_w = speed_r - 1;
									end
								end
						end

						SLOW: begin 
								case (speed_r)
									3'b001: begin
												if (spd_counter_r == 1) begin
													ratio_a = 16'b1000_0000_0000_0000;
													ratio_b = 16'b1000_0000_0000_0000;
												end
									end
									3'b010: begin
												if (spd_counter_r == 1) begin
													ratio_a = 16'b0101_0101_0101_0101;
													ratio_b = 16'b1010_1010_1010_1010;
												end else if (spd_counter_r == 2) begin
													ratio_a = 16'b1010_1010_1010_1010;
													ratio_b = 16'b0101_0101_0101_0101;
												end
									end
									3'b011: begin
												if (spd_counter_r == 1) begin
													ratio_a = 16'b0100_0000_0000_0000;
													ratio_b = 16'b1100_0000_0000_0000;
												end else if (spd_counter_r == 2) begin
													ratio_a = 16'b1000_0000_0000_0000;
													ratio_b = 16'b1000_0000_0000_0000;
												end else if (spd_counter_r == 3) begin
													ratio_a = 16'b1100_0000_0000_0000;
													ratio_b = 16'b0100_0000_0000_0000;
												end
									end									
									3'b100: begin
												if (spd_counter_r == 1) begin
													ratio_a = 16'b0011_0011_0011_0011;
													ratio_b = 16'b1100_1100_1100_1100;
												end else if (spd_counter_r == 2) begin
													ratio_a = 16'b0110_0110_0110_0110;
													ratio_b = 16'b1001_1001_1001_1001;
												end else if (spd_counter_r == 3) begin
													ratio_a = 16'b1001_1001_1001_1001;
													ratio_b = 16'b0110_0110_0110_0110;
												end else if (spd_counter_r == 4) begin
													ratio_a = 16'b1100_1100_1100_1100;
													ratio_b = 16'b0011_0011_0011_0011;
												end
									end									
									3'b101: begin
												if (spd_counter_r == 1) begin
													ratio_a = 16'b0010_1010_1010_1010;
													ratio_b = 16'b1101_0101_0101_0101;
												end else if (spd_counter_r == 2) begin
													ratio_a = 16'b0101_0101_0101_0101;
													ratio_b = 16'b1010_1010_1010_1010;
												end else if (spd_counter_r == 3) begin
													ratio_a = 16'b1000_0000_0000_0000;
													ratio_b = 16'b1000_0000_0000_0000;
												end else if (spd_counter_r == 4) begin
													ratio_a = 16'b1010_1010_1010_1010;
													ratio_b = 16'b0101_0101_0101_0101;
												end else if (spd_counter_r == 5) begin
													ratio_a = 16'b1101_0101_0101_0101;
													ratio_b = 16'b0010_1010_1010_1010;
												end 
									end									
									3'b110: begin
												if (spd_counter_r == 1) begin
													ratio_a = 16'b0010_0100_1001_0010;
													ratio_b = 16'b1101_1011_0110_1101;
												end else if (spd_counter_r == 2) begin
													ratio_a = 16'b0100_1001_0010_0100;
													ratio_b = 16'b1011_0110_1101_1011;
												end else if (spd_counter_r == 3) begin
													ratio_a = 16'b0110_1101_1011_0110;
													ratio_b = 16'b1001_0010_0100_1001;
												end else if (spd_counter_r == 4) begin
													ratio_a = 16'b1001_0010_0100_1001;
													ratio_b = 16'b0110_1101_1011_0110;
												end else if (spd_counter_r == 5) begin
													ratio_a = 16'b1011_0110_1101_1011;
													ratio_b = 16'b0100_1001_0010_0100;
												end else if (spd_counter_r == 6) begin
													ratio_a = 16'b1101_1011_0110_1101;
													ratio_b = 16'b0010_0100_1001_0010;
												end 
									end									
									3'b111: begin
												if (spd_counter_r == 1) begin
													ratio_a = 16'b0010_0000_0000_0000;
													ratio_b = 16'b1110_0000_0000_0000;
												end else if (spd_counter_r == 2) begin
													ratio_a = 16'b0100_0000_0000_0000;
													ratio_b = 16'b1100_0000_0000_0000;
												end else if (spd_counter_r == 3) begin
													ratio_a = 16'b0110_0000_0000_0000;
													ratio_b = 16'b1010_0000_0000_0000;
												end else if (spd_counter_r == 4) begin
													ratio_a = 16'b1000_0000_0000_0000;
													ratio_b = 16'b1000_0000_0000_0000;
												end else if (spd_counter_r == 5) begin
													ratio_a = 16'b1010_0000_0000_0000;
													ratio_b = 16'b0110_0000_0000_0000;
												end else if (spd_counter_r == 6) begin
													ratio_a = 16'b1100_0000_0000_0000;
													ratio_b = 16'b0100_0000_0000_0000;
												end else if (spd_counter_r == 7) begin
													ratio_a = 16'b1110_0000_0000_0000;
													ratio_b = 16'b0010_0000_0000_0000;
												end 
									end
								endcase // speed_r

								if (data_pre_r[15] == 1) begin
									interpol_a = ~data_pre_r + 1




						end
					endcase // play_mode_r
			end

			PAUSE: begin
					if (!i_enable) begin
						state_w = IDLE;
					end else if (i_stop) begin 
						state_w = STOP;
					end
			end


		endcase // state_r

	end

	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			 <= 0;
		end else begin
			 <= ;
		end
	end




endmodule // sramReader