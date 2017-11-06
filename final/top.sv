module top (
	input i_clk,
	input i_clk2,
	input i_rst,

	input i_music_1_enb,
	input i_music_2_enb,
	input i_music_3_enb,
	input i_music_4_enb,
	input i_music_5_enb,
	
	output [22:0] FL_ADDR,
	output        FL_CE_N,
	inout  [7:0]  FL_DQ,
	output        FL_OE_N,
	output        FL_RST_N,
	input         FL_RY,
	output        FL_WE_N,
	output        FL_WP_N,

	output        o_I2C_SCLK,
	inout         I2C_SDAT,
	output        o_AUD_DACDAT,
	inout         DACLRCK
);

	enum {INIT, PLAY} state_w, state_r;
	enum {PLAY_0, PLAY_1, PLAY_2, PLAY_3, PLAY_4, PLAY_5, PLAY_6} substate_w, substate_r;
	/*
	parameter PLAY_0 = 3'b000; 
	parameter PLAY_1 = 3'b001;
	parameter PLAY_2 = 3'b010;
	parameter PLAY_3 = 3'b011;
	parameter PLAY_4 = 3'b100;
	parameter PLAY_5 = 3'b101;
	parameter PLAY_6 = 3'b110;

	logic [2:0] substate_w, substate_r;
	*/
	
	logic [15:0] play_data_r, play_data_w;
	logic [18:0] play_data_temp_r, play_data_temp_w;
	logic pre_DACLRCK_w, pre_DACLRCK_r;
	logic start_play_w, start_play_r;

	logic [31:0] data_out;
	logic [20:0] addr_read_r, addr_read_w;
	logic [15:0] play_data;
	logic start_init, done_init;
	logic start_play, done_play;
	logic ack;

	logic [20:0] counter_r , counter_w;

	assign start_init = (state_r == INIT);
	assign start_play = (pre_DACLRCK_r != DACLRCK);
	
	I2Cinitialize init(
	   .i_clk(i_clk2),
	   .i_start(start_init),
	   .i_rst(i_rst),
	   .o_scl(o_I2C_SCLK),
	   .o_finished(done_init),
	   .o_sda(I2C_SDAT)
	);

	Para2Seri p2s(
	   .i_clk(i_clk),
	   .i_rst(i_rst),
	   .i_start(start_play),
	   .sram_dq(play_data_r), // data 
	   .aud_dacdat(o_AUD_DACDAT),
	   .o_finished(done_play)
	);

	rom flash(
	   .clk(i_clk), 
	   .rst(i_rst),
      .stb(start_play_r), 
	   .we(0), 
	   .addr(addr_read_r),
      .data_out(data_out), 
	   .ack(ack),
      .ce_n(FL_CE_N), 
	   .oe_n(FL_OE_N), 
	   .we_n(FL_WE_N),
      .wp_n(FL_WP_N), 
	   .rst_n(FL_RST_N), 
	   .a(FL_ADDR), 
	   .d(FL_DQ)
	);
	
	always_comb begin
		// _w = _r
		state_w = state_r;
		substate_w = substate_r;
		counter_w = counter_r;
		pre_DACLRCK_w = DACLRCK;
		play_data_temp_w = play_data_temp_r;
		addr_read_w = addr_read_r;
		start_play_w = start_play_r;

		if (start_play && (DACLRCK == 0)) begin
			if (play_data_temp_r[18:15] == 4'b0000) begin // positive no overflow
				play_data_w = play_data_temp_r[15:0];
			end else if (play_data_temp_r[18:15] == 4'b1111) begin // negetive no overflow
				play_data_w = play_data_temp_r[15:0];
			end else if ((play_data_temp_r[18] == 1'b0) && (play_data_temp_r[17:15] != 3'b0)) begin // positive overflow
				play_data_w = {1'b0, 15'b111_1111_1111_1111};
			end else begin // negative overflow
				play_data_w = {1'b1, 15'b0};
			end
		end else begin
			play_data_w = play_data_r;
		end

		//play_data_w = (start_play && (DACLRCK == 0)) ? play_data_temp_r[15:0] : play_data_r;
		
		
		case (state_r) 
			INIT: begin
				if (done_init) begin
					state_w = PLAY;
					substate_w = PLAY_0;
				end
			end

			PLAY: begin
				case (substate_r)
					PLAY_0: begin
						if (start_play && (DACLRCK == 0)) begin
							substate_w = PLAY_1;
							start_play_w = 1;
							play_data_temp_w = 0;
						end
					end
					PLAY_1: begin
						addr_read_w = 21'b0_0000_0000_0000_0000_0000 + counter_r;
						if (ack) begin
							if (i_music_1_enb) begin
								if (data_out[23] == 1'b0) begin
									play_data_temp_w = play_data_temp_r + {3'b0, data_out[23:8]};
								end else begin
									play_data_temp_w = play_data_temp_r + {3'b111, data_out[23:8]};
								end
							end
							substate_w = PLAY_2;
							start_play_w = 1;
						end else begin
							start_play_w = 0;
						end
					end

					PLAY_2: begin
						addr_read_w = 21'b0_0110_0000_0000_0000_0000 + counter_r;
						if (ack) begin
							if (i_music_2_enb) begin
								if (data_out[23] == 1'b0) begin
									play_data_temp_w = play_data_temp_r + {3'b0, data_out[23:8]};
								end else begin
									play_data_temp_w = play_data_temp_r + {3'b111, data_out[23:8]};
								end
							end
							substate_w = PLAY_3;
							start_play_w = 1;
						end else begin
							start_play_w = 0;
						end
					end

					PLAY_3: begin
						addr_read_w = 21'b0_1100_0000_0000_0000_0000 + counter_r;
						if (ack) begin
							if (i_music_3_enb) begin
								if (data_out[23] == 1'b0) begin
									play_data_temp_w = play_data_temp_r + {3'b0, data_out[23:8]};
								end else begin
									play_data_temp_w = play_data_temp_r + {3'b111, data_out[23:8]};
								end
							end
							substate_w = PLAY_4;
							start_play_w = 1;
						end else begin
							start_play_w = 0;
						end
					end

					PLAY_4: begin
						addr_read_w = 21'b1_0010_0000_0000_0000_0000 + counter_r;
						if (ack) begin
							if (i_music_4_enb) begin
								if (data_out[23] == 1'b0) begin
									play_data_temp_w = play_data_temp_r + {3'b0, data_out[23:8]};
								end else begin
									play_data_temp_w = play_data_temp_r + {3'b111, data_out[23:8]};
								end
							end
							substate_w = PLAY_5;
							start_play_w = 1;
						end else begin
							start_play_w = 0;
						end
					end

					PLAY_5: begin
						addr_read_w = 21'b1_1000_0000_0000_0000_0000 + counter_r;
						if (ack) begin
							if (i_music_5_enb) begin
								if (data_out[23] == 1'b0) begin
									play_data_temp_w = play_data_temp_r + {3'b0, data_out[23:8]};
								end else begin
									play_data_temp_w = play_data_temp_r + {3'b111, data_out[23:8]};
								end
							end
							substate_w = PLAY_6;
						end else begin
							start_play_w = 0;
						end
					end

					PLAY_6: begin
				    	//play_data_w = play_data_temp_r;
				    	
						if (counter_r == 21'b0_0101_1000_0000_0000_0000) begin
							counter_w = 21'b0_0000_0000_0000_0000_1011;
				    	end else begin
							counter_w = counter_r + 1;
						end
						
				    	substate_w = PLAY_0;
				    end

				endcase // substate_r
			end
		endcase // state_r
	end

	always_ff @(posedge i_clk or posedge i_rst) begin
		if(i_rst) begin
			state_r       <= INIT;
			substate_r    <= PLAY_0;
			pre_DACLRCK_r <= 0;
			play_data_r   <= 0;
			counter_r     <= 0;
			play_data_temp_r <= 0;
			addr_read_r   <= 0;
			start_play_r  <= 0;
		end else begin
			state_r       <= state_w;
			substate_r    <= substate_w;
			pre_DACLRCK_r <= pre_DACLRCK_w;
			play_data_r   <= play_data_w;
			counter_r     <= counter_w;
			play_data_temp_r <= play_data_temp_w;
			addr_read_r   <= addr_read_w;
			start_play_r  <= start_play_w;
		end
	end
endmodule