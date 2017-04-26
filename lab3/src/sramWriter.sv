module sramWriter(
	input i_clk,
	input i_rst,
	input i_enable, // From SW
	input i_pause,  // From KEY
	input i_stop,	// From KEY
	input i_ready,  // From I2C
	output o_write,
	output [19:0] o_addr,
	output o_done
);

	enum {IDLE, WAIT, WRITE, PAUSE, STOP} state_w, state_r;

	logic [19:0] addr_w, addr_r;
	logic write_w, write_r;

	assign o_addr = addr_r;
	assign o_write = write_r;
	assign o_done = (state_r == DONE);


	always_comb begin
		state_w = state_r;
		addr_w = addr_r;
		write_w = write_r;

		case (state_r) begin

			// When top is not in record mode
			IDLE: begin
					if (i_enable) begin
						state_w = STOP;
						addr_w = 0;
						write_w = 0;
					end
			end

			// Wait for the data from I2C is ready
			WAIT: begin
					if (!i_enable) begin
						state_w = IDLE;
					end else if (i_pause) begin
						state_w = PAUSE;
					end else if (i_ready) begin
						state_w = WRITE;
						write_w = 1;
					end
			end

			// Write the data into the sRAM 
			WRITE: begin
					state_w = WAIT;
					write_w = 0;
					if (!i_enable) begin
						state_w = IDLE;
					end else if (addr_r == 1048575) begin
						addr_w = 0;
						state_w = STOP;
					end else begin
						addr_w = addr_r + 1;
					end

			end

			// Pause and do nothing
			PAUSE: begin
					if (!i_enable) begin
						state_w = IDLE;
					end else if (i_pause) begin
						state_w = WAIT;
					end else if (i_stop) begin 
						state_w = STOP;
						addr_w = 0;
					end
			end

			// When reach the end of sRAM
			STOP: begin
					if (!i_enable) begin
						state_w = IDLE;
					end else if (i_pause) begin
						state_w = WAIT;
					end
			end

		endcase // state_r


	end

	always_ff @(posedge i_clk or negedge i_rst) begin
		if(~rst_n) begin
			 <= 0;
		end else begin
			state_r <= state_w;
			write_r <= write_w;
			addr_r <= addr_w;
		end
	end



endmodule // sramWriter