module Rsa256Wrapper(
	input avm_rst,
	input avm_clk,
	output [4:0] avm_address,
	output avm_read,
	input [31:0] avm_readdata,
	output avm_write,
	output [31:0] avm_writedata,
	input avm_waitrequest
);
	localparam RX_BASE     = 0*4;
	localparam TX_BASE     = 1*4;
	localparam STATUS_BASE = 2*4;
	localparam TX_OK_BIT = 6;
	localparam RX_OK_BIT = 7;

	localparam S_GET_KEY = 0;
	localparam S_GET_DATA = 1;
	localparam S_WAIT_CALCULATE = 2;
	localparam S_SEND_DATA = 3;
	localparam S_GET_READ = 4;
	localparam S_GET_WRITE = 5;

	logic [255:0] n_r, n_w, e_r, e_w, enc_r, enc_w, dec_r, dec_w;
	logic [2:0] state_r, state_w;
	logic [6:0] bytes_counter_r, bytes_counter_w;
	logic [4:0] avm_address_r, avm_address_w;
	logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;
	logic read_ne_w, read_ne_r;

	logic rsa_start_r, rsa_start_w;
	logic rsa_finished;
	logic [255:0] rsa_dec;

	assign avm_address = avm_address_r;
	assign avm_read = avm_read_r;
	assign avm_write = avm_write_r;
	assign avm_writedata = dec_r[247-:8];

	Rsa256Core rsa256_core(
		.i_clk(avm_clk),
		.i_rst(avm_rst),
		.i_start(rsa_start_r),
		.i_a(enc_r),
		.i_e(e_r),
		.i_n(n_r),
		.o_a_pow_e(rsa_dec),
		.o_finished(rsa_finished)
	);

	task StartRead;
		input [4:0] addr;
		begin
			avm_read_w = 1;
			avm_write_w = 0;
			avm_address_w = addr;
		end
	endtask
	task StartWrite;
		input [4:0] addr;
		begin
			avm_read_w = 0;
			avm_write_w = 1;
			avm_address_w = addr;
		end
	endtask
	task Reset;
		begin
			avm_read_w = 0;
			avm_write_w = 0;
		end
	endtask

	always_comb begin
		// TODO
		n_w = n_r;
		e_w = e_r;
		enc_w = enc_r;
		dec_w = dec_r;
		avm_address_w = avm_address_r;
		avm_read_w = avm_read_r;
		avm_write_w = avm_write_r;
		state_w = state_r;
		bytes_counter_w = bytes_counter_r;
		rsa_start_w = rsa_start_r;
		read_ne_w = read_ne_r;
		
		case (state_r)
			S_GET_READ: begin
				StartRead(STATUS_BASE);
				if (avm_waitrequest == 1'b0 && avm_read_r == 1'b1) begin
					if (avm_readdata[RX_OK_BIT] == 1'b1) begin
						StartRead(RX_BASE);
						if (read_ne_r == 1'b1) begin
							state_w = S_GET_KEY;
						end else begin
							state_w = S_GET_DATA;
						end
					end
				end
			end
			S_GET_WRITE: begin
				StartRead(STATUS_BASE);
				if (avm_waitrequest == 1'b0 && avm_read_r == 1'b1) begin
					if (avm_readdata[TX_OK_BIT] == 1'b1) begin
						StartWrite(TX_BASE);
						state_w = S_SEND_DATA;
					end
				end
			end
			S_GET_KEY: begin
				if (avm_waitrequest == 1'b0 && avm_read_r == 1'b1) begin
					Reset();
					bytes_counter_w = bytes_counter_r + 1;
					state_w = S_GET_READ;

					if (bytes_counter_r < 32) begin
						n_w = n_r << 8;
						n_w[7:0] = avm_readdata[7:0];
					end else if (bytes_counter_r < 64) begin
						e_w = e_r << 8;
						e_w[7:0] = avm_readdata[7:0];
					end
					if (bytes_counter_r == 63) begin
						read_ne_w = 1'b0;
						bytes_counter_w = 0;
					end
				end
			end
			S_GET_DATA: begin
				if (avm_waitrequest == 1'b0 && avm_read_r == 1'b1) begin
					Reset();
					if (bytes_counter_r < 32) begin
						bytes_counter_w = bytes_counter_r + 1;
						enc_w = enc_r << 8;
						enc_w[7:0] = avm_readdata[7:0];
						state_w = S_GET_READ;
					end
					if (bytes_counter_r == 31) begin
						bytes_counter_w = 0;
						rsa_start_w = 1'b1;
						state_w = S_WAIT_CALCULATE;
					end
				end
			end
			S_WAIT_CALCULATE: begin
				rsa_start_w = 1'b0;
				if (rsa_finished == 1'b1) begin
					dec_w = rsa_dec;
					state_w = S_GET_WRITE;
				end
			end
			S_SEND_DATA: begin
				if (avm_waitrequest == 1'b0 && avm_write_r == 1'b1) begin
					Reset();
					if (bytes_counter_r < 30) begin
						bytes_counter_w = bytes_counter_r + 1;
						dec_w = dec_r << 8;
						state_w = S_GET_WRITE;
					end else if (bytes_counter_r == 30) begin
						bytes_counter_w = 0;
						state_w = S_GET_READ;
					end
				end
			end
		endcase
	end


	always_ff @(posedge avm_clk or posedge avm_rst) begin
		if (avm_rst) begin
			n_r <= 0;
			e_r <= 0;
			enc_r <= 0;
			dec_r <= 0;
			avm_address_r <= STATUS_BASE;
			avm_read_r <= 1;
			avm_write_r <= 0;
			state_r <= S_GET_READ;
			bytes_counter_r <= 0;
			rsa_start_r <= 0;
			read_ne_r <= 1;
		end else begin
			n_r <= n_w;
			e_r <= e_w;
			enc_r <= enc_w;
			dec_r <= dec_w;
			avm_address_r <= avm_address_w;
			avm_read_r <= avm_read_w;
			avm_write_r <= avm_write_w;
			state_r <= state_w;
			bytes_counter_r <= bytes_counter_w;
			rsa_start_r <= rsa_start_w;
			read_ne_r <= read_ne_w;
		end
	end
endmodule
