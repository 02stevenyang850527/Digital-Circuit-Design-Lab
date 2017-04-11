// calculate a ^ e mod n
module Rsa256Core(
    input  i_clk,
    input  i_rst,
    input  i_start,
    input  [255:0] i_a,
    input  [255:0] i_e,
    input  [255:0] i_n,
    output [255:0] o_a_pow_e,
    output o_finished
);

    enum {IDLE, MOD_PROD, MONT, MONT_CAL, DONE} state_w, state_r;

    logic [255:0] ans_r, ans_w, t_w, t_r;
	logic [255:0] a_r, a_w, e_r, e_w, n_r, n_w;
	logic [  8:0] k_r, k_w; // counter
	logic [  1:0] mc_r, mc_w; 
    logic         finished_w, finished_r;
    
    logic [255:0] result_mod_prod, result_mod;
    logic         start_mod_prod_r, start_mod_prod_w;
    logic         finish_mod_prod;

    logic [255:0] result_mont_1, result_mont_2;
    logic         start_mont_1_r, start_mont_1_w, start_mont_2_r, start_mont_2_w;
    logic         finish_mont_1, finish_mont_2;
    logic [255:0] a_mont_1_w, a_mont_1_r, a_mont_2_w, a_mont_2_r;
    logic [255:0] b_mont_1_w, b_mont_1_r, b_mont_2_w, b_mont_2_r;

    ModuloProduct modulo_product(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_start(start_mod_prod_r),
        .i_n({1'b0,n_r}), // concat 1 bit to MSB since i_n [256:0]
        .i_a({1'b1,{256{1'b0}}}), // a = 2^256
        .i_b({1'b0,a_r}),
        .o_result(result_mod_prod),
        .o_finished(finish_mod_prod)
    );

    Mongomery mongomery_1(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_start(start_mont_1_r),
        .i_a(a_mont_1_r),
        .i_b(b_mont_1_r),
        .i_n(n_r),
        .o_result(result_mont_1),
        .o_finished(finish_mont_1)
    );

    Mongomery mongomery_2(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_start(start_mont_2_r),
        .i_a(a_mont_2_r),
        .i_b(b_mont_2_r),
        .i_n(n_r),
        .o_result(result_mont_2),
        .o_finished(finish_mont_2)
    );

    assign o_finished = finished_r;
    assign o_a_pow_e = ans_r;

    always_comb begin
        state_w = state_r;
		ans_w = ans_r;
		t_w = t_r;
		a_w = a_r;
		e_w = e_r;
		n_w = n_r;
    	k_w = k_r; // counter
        finished_w = finished_r;
        start_mod_prod_w = start_mod_prod_r;
    	start_mont_1_w = start_mont_1_r;
		start_mont_2_w = start_mont_2_r;
    	a_mont_1_w = a_mont_1_r;
	   	a_mont_2_w = a_mont_2_r;
    	b_mont_1_w = b_mont_1_r;
	   	b_mont_2_w = b_mont_2_r;
		mc_w = mc_r;

        case (state_r)
            IDLE: begin
                finished_w = 0;
                ans_w = 0;
            end

            MOD_PROD: begin
                start_mod_prod_w = 0;
                if (finish_mod_prod == 1) begin
                    state_w = MONT;
                    t_w = result_mod_prod;
                end
            end

            MONT: begin
                if (e_r[k_r] == 1) begin
					start_mont_1_w = 1;
					a_mont_1_w = ans_r;
					b_mont_1_w = t_r;
                end else begin
					mc_w = mc_r + 1;
				end

				start_mont_2_w = 1;
			    a_mont_2_w = t_r;
				b_mont_2_w = t_r;

				state_w = MONT_CAL;
            end

			MONT_CAL: begin
				start_mont_1_w = 0;
				start_mont_2_w = 0;
				if (finish_mont_1) begin
					mc_w[0] = 1;
					ans_w = result_mont_1;
				end
				if (finish_mont_2) begin
					mc_w[1] = 1;
					t_w = result_mont_2;
				end
				if (mc_r == 3) begin
					if (k_r == 255) begin
						state_w = DONE;
						finished_w = 1;
						mc_w = 0;
						k_w = 0;
					end else begin
						state_w = MONT;
						mc_w = 0;
						k_w = k_r + 1;
					end
				end
			end

            DONE: begin
                state_w = IDLE;
                finished_w = 0;
            end

		endcase
        
        if (i_start) begin
            state_w = MOD_PROD;
			start_mod_prod_w = 1;
            ans_w = 1;
            k_w = 0;
			a_w = i_a;
			e_w = i_e;
			n_w = i_n;
			mc_w = 0;
		end
    end

    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            ans_r <= 1;
            state_r <= IDLE;
			t_r <= 0;
			k_r <= 0;
			finished_r <= 0;
	   	    start_mod_prod_r <= 0;
   		 	start_mont_1_r <= 0;
			start_mont_2_r <= 0;
    		a_mont_1_r <= 0;
		   	a_mont_2_r <= 0;
    		b_mont_1_r <= 0;
	   		b_mont_2_r <= 0;
			a_r <= 0;
			e_r <= 0;
			n_r <= 0;
			mc_r <= 0;
			end else begin
	        state_r <= state_w;
			ans_r <= ans_w;
			t_r <= t_w;
   	 		k_r <= k_w; // counter
   	    	finished_r <= finished_w;
   	    	start_mod_prod_r <= start_mod_prod_w;
   		 	start_mont_1_r <= start_mont_1_w;
			start_mont_2_r <= start_mont_2_w;
   		 	a_mont_1_r <= a_mont_1_w;
		   	a_mont_2_r <= a_mont_2_w;
    		b_mont_1_r <= b_mont_1_w;
	   		b_mont_2_r <= b_mont_2_w;
			a_r <= a_w;
			e_r <= e_w;
			n_r <= n_w;
			mc_r <= mc_w;
        end
    end
endmodule



// calculating a x b x 2^(−256) mod N
module Mongomery(
	input  i_clk,
    input  i_rst,
    input  i_start,
    input  [255:0] i_a,
    input  [255:0] i_b,
    input  [255:0] i_n,
    output [255:0] o_result,
    output         o_finished
);

    enum  {IDLE, RUN, DONE} state_w, state_r;
    logic [257:0] result_w, result_r;
    logic [257:0] cal_w, cal_r;
	 logic [255:0] a_w, a_r, b_w, b_r, n_w, n_r;
    logic [257:0] tmp_1, tmp_2;
    logic         finished_w, finished_r;
    logic [  8:0] counter_w, counter_r; // counter

    assign o_finished = finished_r;
    assign o_result = result_r[255:0];
	 assign tmp_1 = (b_r[counter_r])? (cal_r + a_r) : cal_r;
	 assign tmp_2 = (tmp_1 & 1)? (tmp_1 + n_r) : tmp_1;

    always_comb begin
        result_w = result_r;
        finished_w = finished_r;
        cal_w = cal_r;
        state_w = state_r;
        counter_w = counter_r;
		  a_w = a_r;
		  b_w = b_r;
		  n_w = n_r;

        case (state_r)
            IDLE:   begin
                        if (i_start) begin
                            state_w = RUN;
							a_w = i_a;
							b_w = i_b;
							n_w = i_n;
							counter_w = 0;
							cal_w = 0;
						end
                    end

            RUN:    begin                      
                        cal_w = tmp_2 >> 1;

                        if (counter_r == 255) begin
                            state_w = DONE;
                            finished_w = 1;
                            counter_w = 0;
                            if (cal_w >= n_r) begin
                                result_w = cal_w - n_r;
                            end else begin
                                result_w = cal_w;
                            end
                        end else begin
                            counter_w = counter_r + 1;
                        end
                    end

            DONE:   begin
                        finished_w = 0;
                        state_w = IDLE;
                    end
        endcase // state_r
    end

    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            state_r <= IDLE;
            counter_r <= 0;
            finished_r <= 0;
            result_r <= 0;
            cal_r <= 0;
			a_r <= 0;
			b_r <= 0;
			n_r <= 0;
        end else begin 
            state_r <= state_w;
            counter_r <= counter_w;
            finished_r <= finished_w;
            result_r <= result_w;
            cal_r <= cal_w;
			a_r <= a_w;
			b_r <= b_w;
			n_r <= n_w;
        end 
    end

endmodule

module ModuloProduct(
    input  i_clk,
    input  i_rst,
    input  i_start,
    input  [256:0] i_n,
    input  [256:0] i_a,
    input  [256:0] i_b,
    output [255:0] o_result, // 256 bits only
    output         o_finished
);


    enum  {IDLE, RUN, DONE} state_w, state_r;
    logic [256:0] result_w, result_r;
    logic [256:0] cal_w, cal_r;
    logic [256:0] tmp_1;
    logic         finished_w, finished_r;
    logic [  8:0] counter_w, counter_r; // counter

    assign o_finished = finished_r;
    assign o_result = result_r[255:0];
	 assign tmp_1 = cal_r << 1;
    always_comb begin
        result_w = result_r;
        finished_w = finished_r;
        cal_w = cal_r;
        state_w = state_r;
        counter_w = counter_r;

        case (state_r)
            IDLE:   begin
                        if (i_start) begin
                            state_w = RUN;
							cal_w = i_b;
                        end
                    end

            RUN:    begin
                        if (tmp_1 >= i_n) begin
                            cal_w = tmp_1 - i_n;
                        end else begin
                            cal_w = tmp_1;
                        end

                        if (counter_r == 255) begin
                            state_w = DONE;
                            finished_w = 1;
                            counter_w = 0;
                            if (cal_w >= i_n) begin
                                result_w = cal_w - i_n;
                            end else begin
                                result_w = cal_w;
                            end
                        end else begin
                            counter_w = counter_r + 1;
                        end
                    end

            DONE:   begin
                        finished_w = 0;
                        state_w = IDLE;
                    end
        endcase // state_r
    end

    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            state_r <= IDLE;
            counter_r <= 0;
            finished_r <= 0;
            result_r <= 0;
            cal_r <= 0;
        end else begin 
            state_r <= state_w;
            counter_r <= counter_w;
            finished_r <= finished_w;
            result_r <= result_w;
            cal_r <= cal_w;
        end 
    end

endmodule
