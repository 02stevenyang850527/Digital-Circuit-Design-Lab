module SRAM_Control(
	input clk,
	input rst_n,
	input DVAL,
	input [15:0] data,

	output		[19:0]		SRAM_ADDR,
	output		      		SRAM_CE_N,
	inout		[15:0]		SRAM_DQ,
	output		      		SRAM_LB_N,
	output		      		SRAM_OE_N,
	output		      		SRAM_UB_N,
	output		      		SRAM_WE_N

);
	
	assign SRAM_CE_N = 0;
	assign SRAM_UB_N = 0;
	assign SRAM_LB_N = 0;

	always_comb begin
		

	end

	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			 <= 0;
		end else begin
			 <= ;
		end
	end

endmodule // SRAM_Control