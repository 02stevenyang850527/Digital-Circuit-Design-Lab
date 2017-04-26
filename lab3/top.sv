module top (
    input  	i_clk,
    input  	i_rst,
    input  	i_start,
    input	i_pause,
    input	i_switch,

    output 	I2C_SCLK,
    inout 	I2C_SDAT,

	output 	[19:0] o_SRAM_ADDR,
	output 	o_SRAM_CE_N,
	inout 	[15:0] SRAM_DQ,
	output 	o_SRAM_LB_N,
	output 	o_SRAM_OE_N,
	output 	o_SRAM_UB_N,
	output 	o_SRAM_WE_N, 

/*****  Audio signals  *****\
	output I2C_SCLK,
	inout I2C_SDAT,
	input AUD_ADCDAT,
	inout AUD_ADCLRCK,
	inout AUD_BCLK,
	output AUD_DACDAT,
	inout AUD_DACLRCK,
	output AUD_XCK,
\***************************/

/******  sRAM signals  ******\
	output [19:0] SRAM_ADDR,
	output SRAM_CE_N,
	inout [15:0] SRAM_DQ,
	output SRAM_LB_N,
	output SRAM_OE_N,
	output SRAM_UB_N,
	output SRAM_WE_N,
\****************************/

/******  LCD signals  ******\
	output LCD_BLON,
	inout [7:0] LCD_DATA,
	output LCD_EN,
	output LCD_ON,
	output LCD_RS,
	output LCD_RW,
\***************************/
);

	enum {INIT, PLAY_PAUSE, PLAY, RECORD_PAUSE, RECORD} state_w, state_r;

	logic [19:0] addr_w, addr_r;
	logic write_w, write_r;
	logic read_w, read_r;




	always_comb begin
		// _w = _r
		state_w = state_r;
		addr_w = addr_r;

		case (state_r) 
			INIT: begin
					// pass the settings to WM8731
					// Welcome page on LCD ?
					if (/* WM8731 initialize complete */) begin
						state_w = RECORD_PAUSE;
						addr_w = 0;
					end
			end

			PLAY_PAUSE: begin
					if (/* countinue play */) begin
						state_w = PLAY;
					end
					if (/* switch mode */) begin
						state_w = RECORD_PAUSE;
					end
			end


			PLAY: begin
					if (/* pause */) begin
						state_w = PLAY_PAUSE;
					end
			end


			RECORD: begin 
					write_w = 1;
					if (/* pause */) begin
						state_w = RECORD_PAUSE;
					end
					if (/* 16bit data from I2C ready */) begin
						write_w = 0;


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




endmodule