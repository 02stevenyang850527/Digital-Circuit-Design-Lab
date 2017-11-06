///////////////////////////////////////////////////////////////////
//
// 2017 NTU DCLab - Final Project
//
//
// File:    hough_circle.sv
// 
// Module:  hough_circle
//
// Device:  Altera DE2-115
//
// Description: Takes a input gray-scale image and detect if 
//              there is circle within the image. Uses Fast
//              Hough-transform algorithm.
//
///////////////////////////////////////////////////////////////////
//
// Specifications / Special Notes
//
//
// * SDRAM address calculation:
//
//     Given point (x, y, r) in parameter space,
//     addr = r * img_width * img_height + y * img_width + x + offset
//
//
// * SRAM address calculation:
//
//     Given point (x, y) in image,
//     addr = y * img_width + x
//
//
// * Floating point number handle:
//
//     16bit after the decimal point.
//
//
// * Incremental Hough Transform:
//
//     Increment step of theta = 2^(-6) = 0.8952 degree
//     Loop 402 times -> 359.8891 degree
//
///////////////////////////////////////////////////////////////////

/*
// Global constants setting
`define IMG_WIDTH  10'd120   
`define IMG_HEIGHT 10'd160 
`define RADIUS_MIN 8'd5     // The minimum r recognized as circle
`define THETA_MAX  9'd402   // Number of iteration of theta
`define EDGE_THRES 8'd80    // Max value of pixel recognized as edge point
`define SDRAM_ADDR_MAX 25'b1_1111_1111_1111_1111_1111
`define ADDR_OFFSET 24'h800000
*/

module hough_circle (
	input clk,       // Clock
	// input clk_en,    // Clock Enable
	input rst_n,     // Asynchronous reset active low
	input i_start,   // Start signal

	// SDRAM signals (vote data)
	input  dram_ack,   // SDRAM controller ack
	output dram_we,    // SDRAM write enable
	output dram_stb,   // SDRAM controller enable
	output [24:0] dram_addr,      // SDRAM address
	input  [31:0] dram_data_in,   // SDRAM read data
	output [31:0] dram_data_out,  // SDRAM write data

	output is_circle,
	output finish,

	output [19:0] sram_addr,
	input  [15:0] sram_data,
	output sram_we_n,
	output sram_oe_n
);

	parameter IMG_WIDTH  = 10'd320;   
	parameter IMG_HEIGHT = 10'd240; 
	parameter RADIUS_MIN = 8'd5;     // The minimum r recognized as circle
	parameter THETA_MAX  = 9'd402;   // Number of iteration of theta
	parameter EDGE_THRES = 8'd80;    // Max value of pixel recognized as edge point
	parameter SDRAM_ADDR_MAX = 25'b1_1111_1111_1111_1111_1111_1111;
	parameter ADDR_OFFSET = 25'h1000000;

	enum { IDLE,               // Idle 
		   INIT,               // Clear SDRAM
		   FIND_EDGE,          // Find edge point
		   MAX_RADIUS_SELECT,  // Choose r range
		   RADIUS_SELECT,      // Iterate over r
		   VOTE_POS_CAL,       // Calculate position
		   VOTE                // Read/Write SDRAM
		 } state_r, state_w;

	logic [9:0]  edge_x_r, edge_x_w;  // x position of edge point
	logic [9:0]  edge_y_r, edge_y_w;  // y position of edge point
	logic [7:0]  r_max_r, r_max_w;    // max value of r
	logic [7:0]  r_r, r_w;            // r iterater
	logic [8:0]  theta_r,theta_w;     // theta iterater
	logic [25:0] x0_r, x0_w;	      // x, y position to vote
	logic [25:0] y0_r, y0_w;	      // 25:16 interger 15:0 floating point
	logic [24:0] dram_addr_r, dram_addr_w;  // SDRAM address
	logic [31:0] dram_data_r, dram_data_w;  // SDRAM data to read/write
	logic [7:0]  max_r_r, max_r_w;          // current max vote r
	logic [9:0]  max_vote_r, max_vote_w;    // current max vote
	logic [24:0] max_vote_addr_r, max_vote_addr_w;    // current max vote address
	logic we_r, we_w;   // SDRAM write enable
	logic is_circle_r, is_circle_w;
	logic finish_w, finish_r;

	logic [9:0]  margin_x, margin_y;  // used to determine max r
	logic [9:0]  tmp;

	assign dram_we = we_r;
	assign dram_stb = (state_r == VOTE) || (state_r == INIT) || (state_r == FIND_EDGE);
	assign dram_data_out = dram_data_r;
	assign sram_addr = (edge_y_r * 2 * 640 + edge_x_r * 2);
	assign dram_addr = dram_addr_r;
	assign tmp = max_r_r * 3;
	assign is_circle = is_circle_r;
	assign margin_x = (edge_x_r < (IMG_WIDTH >> 1))? edge_x_r : (IMG_WIDTH - edge_x_r - 1);
	assign margin_y = (edge_y_r < (IMG_HEIGHT >> 1))? edge_y_r : (IMG_HEIGHT - edge_y_r - 1);
	assign finish = finish_r;
	assign sram_oe_n =  (state_r == IDLE);
	assign sram_we_n = !(state_r == IDLE);

	always_comb begin
		state_w = state_r;
		edge_x_w = edge_x_r;
		edge_y_w = edge_y_r;
		r_max_w = r_max_r;
		r_w = r_r;
		theta_w = theta_r;
		x0_w = x0_r;
		y0_w = y0_r;
		dram_addr_w = dram_addr_r;
		dram_data_w = dram_data_r;
		we_w = we_r;
		max_vote_w = max_vote_r; 
		max_vote_addr_w = max_vote_addr_r; 
		max_r_w = max_r_r;
		is_circle_w = is_circle_r;
		finish_w = finish_r;

		case (state_r)
			IDLE: begin
				if (tmp < max_vote_r) begin
					is_circle_w = 1;
				end else begin
					is_circle_w = 0;
				end
				finish_w = 0;
				if (i_start) begin
					state_w = INIT;
					dram_addr_w = 0;
					dram_data_w = 0;
					we_w = 1;
				end
			end

			// Clear the SDRAM and back to idle
			INIT: begin
				if (dram_ack) begin
					dram_addr_w = dram_addr_r + 1;
				end
				if (dram_addr_r == SDRAM_ADDR_MAX) begin
					state_w = FIND_EDGE;
					edge_x_w = 0;
					edge_y_w = 0;
					max_vote_w = 0;
					max_vote_addr_w = 0;
					max_r_w = 0;
					dram_addr_w = 0;
					we_w = 0;
				end
			end

			// Iterate over the image and find edge points
			// passes the point to next steps
			FIND_EDGE: begin
				if (edge_x_r >= IMG_WIDTH) begin
					edge_x_w = 0;
					if (edge_y_r >= IMG_HEIGHT - 1) begin // End of image 
						edge_y_w = 0; 
						state_w = IDLE;
						finish_w = 1;
					end else begin
						edge_y_w = edge_y_r + 1;
					end
				end else if (sram_data < EDGE_THRES) begin  // Recognized as edge point
					state_w = MAX_RADIUS_SELECT;
				end else begin 
					edge_x_w = edge_x_r + 1;
				end
			end

			// Find the min distance of the edge point to the image boundary
			// this is the max r value in the proceeding hough transform
			MAX_RADIUS_SELECT: begin
				//margin_x = (edge_x_r < (IMG_WIDTH >> 1))? edge_x_r : (IMG_WIDTH - edge_x_r);
				//margin_y = (edge_y_r < (IMG_HEIGHT >> 1))? edge_y_r : (IMG_HEIGHT - edge_y_r);
				r_max_w = (margin_x < margin_y)? margin_x : margin_y;
				state_w = RADIUS_SELECT;
				r_w = RADIUS_MIN;
			end

			// Iterate over r until reach r_max
			RADIUS_SELECT: begin
				if (r_r >= r_max_r) begin
					state_w = FIND_EDGE;
					edge_x_w = edge_x_r + 1;
				end else begin
					state_w = VOTE_POS_CAL;
					theta_w = 0;
					x0_w = {edge_x_r - r_r, 16'b0};  //***** MAY BE FAULTY *****//
					y0_w = {edge_y_r, 16'b0};
				end
			end

			// Iterate over theta and calculate the RAM address to vote
			VOTE_POS_CAL: begin
				if (theta_r == THETA_MAX) begin
					state_w = RADIUS_SELECT;
					r_w = r_r + 1;
				end else begin
					x0_w = x0_r + {6'b0, edge_y_r, 10'b0} - (y0_r >> 6);
					y0_w = y0_r - {6'b0, edge_x_r, 10'b0} + (x0_r >> 6);
					dram_addr_w = (r_r * IMG_HEIGHT + y0_r[25:16]) * IMG_WIDTH + x0_r[25:16] + ADDR_OFFSET;
					state_w = VOTE;
					theta_w = theta_r + 1;
					we_w = 0;
				end
			end

			// Retrieve the vote data from SDRAM and +1
			// Also keep track of max vote 
			VOTE: begin
				if (dram_ack) begin
					if (we_r) begin // Write data completes
						state_w = VOTE_POS_CAL;
						we_w = 0;
					end else begin  // Read data arrives 
						dram_data_w = dram_data_in[31:16] + 1;
						we_w = 1;
					end
				end else begin  // check the max vote
					if (dram_data_r[9:0] > max_vote_r) begin
						max_vote_w = dram_data_r[9:0];
						max_vote_addr_w = dram_addr_r;
						max_r_w = r_r;
					end
				end
			end
		endcase // state_r
	end

	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			state_r <= IDLE;
			edge_x_r <= 0;
			edge_y_r <= 0;
			r_max_r <= 0;
			r_r <= 0;
			theta_r <= 0;
			x0_r <= 0;
			y0_r <= 0;
			dram_addr_r <= 0;
			dram_data_r <= 0;
			we_r <= 0;
			max_vote_r <= 0; 
			max_vote_addr_r <= 0;
			max_r_r <= 0;
			is_circle_r <= 0;
			finish_r <= 0;
		end else begin
			state_r <= state_w;
			edge_x_r <= edge_x_w;
			edge_y_r <= edge_y_w;
			r_max_r <= r_max_w;
			r_r <= r_w;
			theta_r <= theta_w;
			x0_r <= x0_w;
			y0_r <= y0_w;
			dram_addr_r <= dram_addr_w;
			dram_data_r <= dram_data_w;
			we_r <= we_w;
			max_vote_r <= max_vote_w; 
			max_vote_addr_r <= max_vote_addr_w;
			max_r_r <= max_r_w;
			is_circle_r <= is_circle_w;
			finish_r <= finish_w;
		end
	end

endmodule


/*
module hough_circle (
	input clk,       // Clock
	// input clk_en,    // Clock Enable
	input rst_n,     // Asynchronous reset active low
	input i_start,   // Start signal

	// SDRAM signals (vote data)
	input  dram_ack,   // SDRAM controller ack
	output dram_we,    // SDRAM write enable
	output dram_stb,   // SDRAM controller enable
	output [24:0] dram_addr,      // SDRAM address
	input  [31:0] dram_data_in,   // SDRAM read data
	output [31:0] dram_data_out,  // SDRAM write data

	output is_circle,
	output finish,

	output [19:0] sram_addr,
	output sram_we_n,
	output sram_oe_n
);

	parameter IMG_WIDTH  = 10'd320;   
	parameter IMG_HEIGHT = 10'd240; 
	parameter RADIUS_MIN = 8'd5;     // The minimum r recognized as circle
	parameter THETA_MAX  = 9'd402;   // Number of iteration of theta
	parameter EDGE_THRES = 8'd80;    // Max value of pixel recognized as edge point
	parameter SDRAM_ADDR_MAX = 25'b1_1111_1111_1111_1111_1111;
	parameter ADDR_OFFSET = 24'h800000;

	enum { IDLE,               // Idle 
		   INIT,               // Clear SDRAM
		   FIND_EDGE,          // Find edge point
		   MAX_RADIUS_SELECT,  // Choose r range
		   RADIUS_SELECT,      // Iterate over r
		   VOTE_POS_CAL,       // Calculate position
		   VOTE                // Read/Write SDRAM
		 } state_r, state_w;

	logic [9:0]  edge_x_r, edge_x_w;  // x position of edge point
	logic [9:0]  edge_y_r, edge_y_w;  // y position of edge point
	logic [7:0]  r_max_r, r_max_w;    // max value of r
	logic [7:0]  r_r, r_w;            // r iterater
	logic [8:0]  theta_r,theta_w;     // theta iterater
	logic [25:0] x0_r, x0_w;	      // x, y position to vote
	logic [25:0] y0_r, y0_w;	      // 25:16 interger 15:0 floating point
	logic [24:0] dram_addr_r, dram_addr_w;  // SDRAM address
	logic [31:0] dram_data_r, dram_data_w;  // SDRAM data to read/write
	logic [7:0]  max_r_r, max_r_w;          // current max vote r
	logic [9:0]  max_vote_r, max_vote_w;    // current max vote
	logic [24:0] max_vote_addr_r, max_vote_addr_w;    // current max vote address
	logic we_r, we_w;   // SDRAM write enable
	logic is_circle_r, is_circle_w;
	logic finish_w, finish_r;

	logic [9:0]  margin_x, margin_y;  // used to determine max r
	logic [24:0] dram_addr_img, dram_addr_vote;  // used to determine max r
	logic [9:0]  tmp;

	assign dram_we = we_r;
	assign dram_stb = (state_r == VOTE) || (state_r == INIT) || (state_r == FIND_EDGE);
	assign dram_data_out = dram_data_r;
	assign dram_addr_img  = (edge_y_r * 640 + edge_x_r);
	assign dram_addr_vote = dram_addr_r + ADDR_OFFSET;
	assign dram_addr = (state_r == FIND_EDGE)? dram_addr_img : dram_addr_vote;
	assign tmp = max_r_r * 3;
	assign is_circle = is_circle_r;
	assign margin_x = (edge_x_r < (IMG_WIDTH >> 1))? edge_x_r : (IMG_WIDTH - edge_x_r);
	assign margin_y = (edge_y_r < (IMG_HEIGHT >> 1))? edge_y_r : (IMG_HEIGHT - edge_y_r);
	assign finish = finish_r;
	assign sram_oe_n =  (state_r == IDLE);
	assign sram_we_n = !(state_r == IDLE);

	always_comb begin
		state_w = state_r;
		edge_x_w = edge_x_r;
		edge_y_w = edge_y_r;
		r_max_w = r_max_r;
		r_w = r_r;
		theta_w = theta_r;
		x0_w = x0_r;
		y0_w = y0_r;
		dram_addr_w = dram_addr_r;
		dram_data_w = dram_data_r;
		we_w = we_r;
		max_vote_w = max_vote_r; 
		max_vote_addr_w = max_vote_addr_r; 
		max_r_w = max_r_r;
		is_circle_w = is_circle_r;
		finish_w = finish_r;

		case (state_r)
			IDLE: begin
				if (tmp < max_vote_r) begin
					is_circle_w = 1;
				end else begin
					is_circle_w = 0;
				end
				finish_w = 0;
				if (i_start) begin
					state_w = INIT;
					dram_addr_w = 0;
					dram_data_w = 0;
					we_w = 1;
				end
			end

			// Clear the SDRAM and back to idle
			INIT: begin
				if (dram_ack) begin
					dram_addr_w = dram_addr_r + 1;
				end
				if (dram_addr_r == SDRAM_ADDR_MAX - ADDR_OFFSET) begin
					state_w = FIND_EDGE;
					edge_x_w = 0;
					edge_y_w = 0;
					max_vote_w = 0;
					max_vote_addr_w = 0;
					max_r_w = 0;
					dram_addr_w = 0;
					we_w = 0;
				end
			end

			// Iterate over the image and find edge points
			// passes the point to next steps
			FIND_EDGE: begin
				if (edge_x_r >= IMG_WIDTH) begin
					edge_x_w = 0;
					if (edge_y_r >= IMG_HEIGHT - 0) begin // End of image 
						edge_y_w = 0; 
						state_w = IDLE;
						finish_w = 1;
					end else begin
						edge_y_w = edge_y_r + 1;
					end
				end else if (dram_ack) begin
				    if (dram_data_in[15:0] < EDGE_THRES) begin  // Recognized as edge point
						state_w = MAX_RADIUS_SELECT;
					end else begin
						edge_x_w = edge_x_r + 1;
					end
				end 
			end

			// Find the min distance of the edge point to the image boundary
			// this is the max r value in the proceeding hough transform
			MAX_RADIUS_SELECT: begin
				//margin_x = (edge_x_r < (IMG_WIDTH >> 1))? edge_x_r : (IMG_WIDTH - edge_x_r);
				//margin_y = (edge_y_r < (IMG_HEIGHT >> 1))? edge_y_r : (IMG_HEIGHT - edge_y_r);
				r_max_w = (margin_x < margin_y)? margin_x : margin_y;
				state_w = RADIUS_SELECT;
				r_w = RADIUS_MIN;
			end

			// Iterate over r until reach r_max
			RADIUS_SELECT: begin
				if (r_r >= r_max_r) begin
					state_w = FIND_EDGE;
					edge_x_w = edge_x_r + 1;
				end else begin
					state_w = VOTE_POS_CAL;
					theta_w = 0;
					x0_w = {edge_x_r - r_r, 16'b0};  //***** MAY BE FAULTY *****
					y0_w = {edge_y_r, 16'b0};
				end
			end

			// Iterate over theta and calculate the RAM address to vote
			VOTE_POS_CAL: begin
				if (theta_r == THETA_MAX) begin
					state_w = RADIUS_SELECT;
					r_w = r_r + 1;
				end else begin
					x0_w = x0_r + {6'b0, edge_y_r, 10'b0} - (y0_r >> 6);
					y0_w = y0_r - {6'b0, edge_x_r, 10'b0} + (x0_r >> 6);
					dram_addr_w = (r_r * IMG_HEIGHT + y0_r[25:16]) * IMG_WIDTH + x0_r[25:16];
					state_w = VOTE;
					theta_w = theta_r + 1;
					we_w = 0;
				end
			end

			// Retrieve the vote data from SDRAM and +1
			// Also keep track of max vote 
			VOTE: begin
				if (dram_ack) begin
					if (we_r) begin // Write data completes
						state_w = VOTE_POS_CAL;
						we_w = 0;
					end else begin  // Read data arrives 
						dram_data_w = dram_data_in[15:0] + 1;
						we_w = 1;
					end
				end else begin  // check the max vote
					if (dram_data_r[9:0] > max_vote_r) begin
						max_vote_w = dram_data_r[9:0];
						max_vote_addr_w = dram_addr_r;
						max_r_w = r_r;
					end
				end
			end
		endcase // state_r
	end

	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			state_r <= IDLE;
			edge_x_r <= 0;
			edge_y_r <= 0;
			r_max_r <= 0;
			r_r <= 0;
			theta_r <= 0;
			x0_r <= 0;
			y0_r <= 0;
			dram_addr_r <= 0;
			dram_data_r <= 0;
			we_r <= 0;
			max_vote_r <= 0; 
			max_vote_addr_r <= 0;
			max_r_r <= 0;
			is_circle_r <= 0;
			finish_r <= 0;
		end else begin
			state_r <= state_w;
			edge_x_r <= edge_x_w;
			edge_y_r <= edge_y_w;
			r_max_r <= r_max_w;
			r_r <= r_w;
			theta_r <= theta_w;
			x0_r <= x0_w;
			y0_r <= y0_w;
			dram_addr_r <= dram_addr_w;
			dram_data_r <= dram_data_w;
			we_r <= we_w;
			max_vote_r <= max_vote_w; 
			max_vote_addr_r <= max_vote_addr_w;
			max_r_r <= max_r_w;
			is_circle_r <= is_circle_w;
			finish_r <= finish_w;
		end
	end

endmodule
*/
/*
module hough_circle (
	input clk,       // Clock
	// input clk_en,    // Clock Enable
	input rst_n,     // Asynchronous reset active low
	input i_start,   // Start signal

	// SDRAM signals (vote data)
	input  dram_ack,   // SDRAM controller ack
	output dram_we,    // SDRAM write enable
	output dram_stb,   // SDRAM controller enable
	output [24:0] dram_addr,      // SDRAM address
	input  [31:0] dram_data_in,   // SDRAM read data
	output [31:0] dram_data_out,  // SDRAM write data

	output is_circle,
	output finish
);

	parameter IMG_WIDTH  = 10'd320;   
	parameter IMG_HEIGHT = 10'd240; 
	parameter RADIUS_MIN = 8'd5;     // The minimum r recognized as circle
	parameter THETA_MAX  = 9'd402;   // Number of iteration of theta
	parameter EDGE_THRES = 8'd80;    // Max value of pixel recognized as edge point
	parameter SDRAM_ADDR_MAX = 25'b1_1111_1111_1111_1111_1111;
	parameter ADDR_OFFSET = 24'h800000;

	enum { IDLE,               // Idle 
		   INIT,               // Clear SDRAM
		   FIND_EDGE,          // Find edge point
		   MAX_RADIUS_SELECT,  // Choose r range
		   RADIUS_SELECT,      // Iterate over r
		   VOTE_POS_CAL,       // Calculate position
		   VOTE                // Read/Write SDRAM
		 } state_r, state_w;

	logic [9:0]  edge_x_r, edge_x_w;  // x position of edge point
	logic [9:0]  edge_y_r, edge_y_w;  // y position of edge point
	logic [7:0]  r_max_r, r_max_w;    // max value of r
	logic [7:0]  r_r, r_w;            // r iterater
	logic [8:0]  theta_r,theta_w;     // theta iterater
	logic [25:0] x0_r, x0_w;	      // x, y position to vote
	logic [25:0] y0_r, y0_w;	      // 25:16 interger 15:0 floating point
	logic [24:0] dram_addr_r, dram_addr_w;  // SDRAM address
	logic [31:0] dram_data_r, dram_data_w;  // SDRAM data to read/write
	logic [7:0]  max_r_r, max_r_w;          // current max vote r
	logic [9:0]  max_vote_r, max_vote_w;    // current max vote
	logic [24:0] max_vote_addr_r, max_vote_addr_w;    // current max vote address
	logic we_r, we_w;   // SDRAM write enable
	logic is_circle_r, is_circle_w;
	logic finish_w, finish_r;

	logic [9:0]  margin_x, margin_y;  // used to determine max r
	logic [24:0] dram_addr_img, dram_addr_vote;  // used to determine max r
	logic [9:0]  tmp;

	assign dram_we = we_r;
	assign dram_stb = (state_r == VOTE) || (state_r == INIT) || (state_r == FIND_EDGE);
	assign dram_data_out = dram_data_r;
	assign dram_addr_img  = (edge_y_r * 640 + edge_x_r);
	assign dram_addr_vote = dram_addr_r + ADDR_OFFSET;
	assign dram_addr = (state_r == FIND_EDGE)? dram_addr_img : dram_addr_vote;
	assign tmp = max_r_r * 3;
	assign is_circle = is_circle_r;
	assign margin_x = (edge_x_r < (IMG_WIDTH >> 1))? edge_x_r : (IMG_WIDTH - edge_x_r);
	assign margin_y = (edge_y_r < (IMG_HEIGHT >> 1))? edge_y_r : (IMG_HEIGHT - edge_y_r);
	assign finish = finish_r;

	always_comb begin
		state_w = state_r;
		edge_x_w = edge_x_r;
		edge_y_w = edge_y_r;
		r_max_w = r_max_r;
		r_w = r_r;
		theta_w = theta_r;
		x0_w = x0_r;
		y0_w = y0_r;
		dram_addr_w = dram_addr_r;
		dram_data_w = dram_data_r;
		we_w = we_r;
		max_vote_w = max_vote_r; 
		max_vote_addr_w = max_vote_addr_r; 
		max_r_w = max_r_r;
		is_circle_w = is_circle_r;
		finish_w = finish_r;

		case (state_r)
			IDLE: begin
				finish_w = 0;
				if (i_start) begin
					state_w = INIT;
					edge_x_w = 0;
					edge_y_w = 0;
					max_vote_w = 0;
					max_vote_addr_w = 0;
					max_r_w = 0;
				end
			end

			// Clear the SDRAM and back to idle
			INIT: begin
				if (tmp < max_vote_r) begin
					is_circle_w = 1;
				end else begin
					is_circle_w = 0;
				end
				if (dram_ack) begin
					dram_addr_w = dram_addr_r + 1;
				end
				if (dram_addr_r == SDRAM_ADDR_MAX) begin
					state_w = IDLE;
					finish_w = 1;
				end
			end

			// Iterate over the image and find edge points
			// passes the point to next steps
			FIND_EDGE: begin
				if (edge_x_r >= IMG_WIDTH) begin
					edge_x_w = 0;
					if (edge_y_r >= IMG_HEIGHT - 0) begin // End of image 
						edge_y_w = 0; 
						state_w = INIT;
					end else begin
						edge_y_w = edge_y_r + 1;
					end
				end else if (dram_ack) begin
				    if (dram_data_in[15:0] < EDGE_THRES) begin  // Recognized as edge point
						state_w = MAX_RADIUS_SELECT;
					end else begin
						edge_x_w = edge_x_r + 1;
					end
				end 
			end

			// Find the min distance of the edge point to the image boundary
			// this is the max r value in the proceeding hough transform
			MAX_RADIUS_SELECT: begin
				//margin_x = (edge_x_r < (IMG_WIDTH >> 1))? edge_x_r : (IMG_WIDTH - edge_x_r);
				//margin_y = (edge_y_r < (IMG_HEIGHT >> 1))? edge_y_r : (IMG_HEIGHT - edge_y_r);
				r_max_w = (margin_x < margin_y)? margin_x : margin_y;
				state_w = RADIUS_SELECT;
				r_w = RADIUS_MIN;
			end

			// Iterate over r until reach r_max
			RADIUS_SELECT: begin
				if (r_r >= r_max_r) begin
					state_w = FIND_EDGE;
					edge_x_w = edge_x_r + 1;
				end else begin
					state_w = VOTE_POS_CAL;
					theta_w = 0;
					x0_w = {edge_x_r - r_r, 16'b0};  //***** MAY BE FAULTY *****
					y0_w = {edge_y_r, 16'b0};
				end
			end

			// Iterate over theta and calculate the RAM address to vote
			VOTE_POS_CAL: begin
				if (theta_r == THETA_MAX) begin
					state_w = RADIUS_SELECT;
					r_w = r_r + 1;
				end else begin
					x0_w = x0_r + {6'b0, edge_y_r, 10'b0} - (y0_r >> 6);
					y0_w = y0_r - {6'b0, edge_x_r, 10'b0} + (x0_r >> 6);
					dram_addr_w = (r_r * IMG_HEIGHT + y0_r[25:16]) * IMG_WIDTH + x0_r[25:16];
					state_w = VOTE;
					theta_w = theta_r + 1;
					we_w = 0;
				end
			end

			// Retrieve the vote data from SDRAM and +1
			// Also keep track of max vote 
			VOTE: begin
				if (dram_ack) begin
					if (we_r) begin // Write data completes
						state_w = VOTE_POS_CAL;
						we_w = 0;
					end else begin  // Read data arrives 
						dram_data_w = dram_data_in[15:0] + 1;
						we_w = 1;
					end
				end else begin  // check the max vote
					if (dram_data_r > max_vote_r) begin
						max_vote_w = dram_data_r[9:0];
						max_vote_addr_w = dram_addr_r;
						max_r_w = r_r;
					end
				end
			end
		endcase // state_r
	end

	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			state_r <= IDLE;
			edge_x_r <= 0;
			edge_y_r <= 0;
			r_max_r <= 0;
			r_r <= 0;
			theta_r <= 0;
			x0_r <= 0;
			y0_r <= 0;
			dram_addr_r <= 0;
			dram_data_r <= 0;
			we_r <= 0;
			max_vote_r <= 0; 
			max_vote_addr_r <= 0;
			max_r_r <= 0;
			is_circle_r <= 0;
			finish_r <= 0;
		end else begin
			state_r <= state_w;
			edge_x_r <= edge_x_w;
			edge_y_r <= edge_y_w;
			r_max_r <= r_max_w;
			r_r <= r_w;
			theta_r <= theta_w;
			x0_r <= x0_w;
			y0_r <= y0_w;
			dram_addr_r <= dram_addr_w;
			dram_data_r <= dram_data_w;
			we_r <= we_w;
			max_vote_r <= max_vote_w; 
			max_vote_addr_r <= max_vote_addr_w;
			max_r_r <= max_r_w;
			is_circle_r <= is_circle_w;
			finish_r <= finish_w;
		end
	end

endmodule
*/

/*
module hough_circle (
	input clk,       // Clock
	// input clk_en,    // Clock Enable
	input rst_n,     // Asynchronous reset active low
	input i_start,   // Start signal

	// SDRAM signals (vote data)
	input  dram_ack,   // SDRAM controller ack
	output dram_we,    // SDRAM write enable
	output dram_stb,   // SDRAM controller enable
	output [24:0] dram_addr,      // SDRAM address
	input  [31:0] dram_data_in,   // SDRAM read data
	output [31:0] dram_data_out,  // SDRAM write data

	// SRAM signals (image data)
	output [19:0] sram_addr,
	input  [16:0] sram_data,
);

	enum { IDLE,               // Idle 
		   INIT,               // Clear SDRAM
		   FIND_EDGE,          // Find edge point
		   MAX_RADIUS_SELECT,  // Choose r range
		   RADIUS_SELECT,      // Iterate over r
		   VOTE_POS_CAL,       // Calculate position
		   VOTE                // Read/Write SDRAM
		 } state_r, state_w;

	logic [9:0]  edge_x_r, edge_x_w;  // x position of edge point
	logic [9:0]  edge_y_r, edge_y_w;  // y position of edge point
	logic [7:0]  r_max_r, r_max_w;    // max value of r
	logic [7:0]  r_r, r_w;            // r iterater
	logic [8:0]  theta_r,theta_w;     // theta iterater
	logic [25:0] x0_r, x0_w;	      // x, y position to vote
	logic [25:0] y0_r, y0_w;	      // 25:16 interger 15:0 floating point
	logic [24:0] dram_addr_r, dram_addr_w;  // SDRAM address
	logic [31:0] dram_data_r, dram_data_w;  // SDRAM data to read/write
	logic [9:0]  max_vote_r, max_vote_w;    // current max vote
	logic [24:0] max_vote_addr_r, max_vote_addr_w;    // current max vote address
	logic we_r, we_w;   // SDRAM write enable

	logic [9:0] margin_x, margin_y;  // used to determine max r

	assign dram_we = we_r;
	assign dram_stb = (state_r == VOTE) || (state_r == INIT);
	assign dram_addr = dram_addr_r + offset;
	assign dram_data_out = dram_data_r;
	assign sram_addr = edge_y_r * IMG_WIDTH + edge_x_r;

	always_comb begin
		edge_x_w = edge_x_r;
		edge_y_w = edge_y_r;
		r_max_w = r_max_r;
		r_w = r_r;
		theta_w = theta_r;
		x0_w = x0_r;
		y0_w = y0_r;
		dram_addr_w = dram_addr_r;
		dram_data_w = dram_data_r;
		we_w = we_r;
		max_vote_w = max_vote_r; 
		max_vote_addr_w = max_vote_addr_r; 

		case (state_r)
			IDLE: begin
				if (i_start) begin
					state_w = FIND_EDGE;
					edge_x_w = 0;
					edge_y_w = 0;
				end
			end

			// Clear the SDRAM and back to idle
			INIT: begin
				if (dram_ack) begin
					dram_addr_w = dram_addr_r + 1;
				end
				if (dram_addr_r == SDRAM_ADDR_MAX) begin
					state_w = IDLE;
				end
			end

			// Iterate over the image and find edge points
			// passes the point to next steps
			FIND_EDGE: begin
				if (edge_x_r == IMG_WIDTH) begin
					edge_x_w = 0;
					if (edge_y_r == IMG_HEIGHT - 1) begin // End of image 
						edge_y_w = 0; 
						state_w = INIT;
					end else begin
						edge_y_w = edge_y_r + 1;
					end
				end else if (sram_data < EDGE_THRES) begin  // Recognized as edge point
					state_w = MAX_RADIUS_SELECT;
				end 
			end

			// Find the min distance of the edge point to the image boundary
			// this is the max r value in the proceeding hough transform
			MAX_RADIUS_SELECT: begin
				margin_x = (edge_x_r < (IMG_WIDTH >> 1))? edge_x_r : (IMG_WIDTH - edge_x_r);
				margin_y = (edge_y_r < (IMG_HEIGHT >> 1))? edge_y_r : (IMG_HEIGHT - edge_y_r);
				r_max_w = (margin_x < margin_y)? margin_x : margin_y;
				state_w = RADIUS_SELECT;
				r_w = RADIUS_MIN;
			end

			// Iterate over r until reach r_max
			RADIUS_SELECT: begin
				if (r_r == r_max_r) begin
					state_w = FIND_EDGE;
					edge_x_w = edge_x_r + 1;
				end
				end else begin
					state_w = VOTE_POS_CAL;
					theta_w = 0;
					x0_w = {edge_x_r - r_r, 16'b0};  
					y0_w = {edge_y_r, 16'b0};
				end
			end

			// Iterate over theta and calculate the RAM address to vote
			VOTE_POS_CAL: begin
				if (theta_r == THETA_MAX) begin
					state_w = RADIUS_SELECT;
					r_w = r_r + 1;
				end else begin
					x0_w = x0_r + {6'b0, edge_y_r, 10'b0} - (y0_r >> 6);
					y0_w = y0_r - {6'b0, edge_x_r, 10'b0} + (x0_r >> 6);
					dram_addr_w = (r_r * IMG_HEIGHT + y0_r[25:16]) * IMG_WIDTH + x0_r[25:16];
					state_w = VOTE;
					theta_w = theta_r + 1;
					we_w = 0;
				end
			end

			// Retrieve the vote data from SDRAM and +1
			// Also keep track of max vote 
			VOTE: begin
				if (dram_ack) begin
					if (we_r) begin // Write data completes
						state_w = VOTE_POS_CAL;
						we_w = 0;
					end else begin  // Read data arrives 
						dram_data_w = dram_dq + 1;
						we_w = 1;
					end
				end else begin  // check the max vote
					if (dram_data_r > max_vote_r) begin
						max_vote_w = dram_data_r[9:0];
						max_vote_addr_w = dram_addr_r;
					end
				end
			end
		endcase // state_r
	end

	always_ff @(posedge clk or negedge rst_n) begin
		if (~rst_n) begin
			state_r <= IDLE;
			edge_x_r <= 0;
			edge_y_r <= 0;
			r_max_r <= 0;
			r_r <= 0;
			theta_r <= 0;
			x0_r <= 0;
			y0_r <= 0;
			dram_addr_r <= 0;
			dram_data_r <= 0;
			we_r <= 0;
			max_vote_r <= 0; 
			max_vote_addr_r <= 0;
		end else begin
			state_r <= state_w;
			edge_x_r <= edge_x_w;
			edge_y_r <= edge_y_w;
			r_max_r <= r_max_w;
			r_r <= r_w;
			theta_r <= theta_w;
			x0_r <= x0_w;
			y0_r <= y0_w;
			dram_addr_r <= dram_addr_w;
			dram_data_r <= dram_data_w;
			we_r <= we_w;
			max_vote_r <= max_vote_w; 
			max_vote_addr_r <= max_vote_addr_w;
		end
	end

endmodule
*/