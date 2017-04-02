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

    enum {IDLE, MOD_PROD, MONT, DONE} state_w, state_r;

    logic [255:0] ans_r, ans_w, t;
    logic [  8:0] k; // counter
    logic         finished_w;
    
    logic [255:0] result_mod_prod;
    logic         start_mod_prod;
    logic         finish_mod_prod;

    logic [255:0] result_mont_1, result_mont_2;
    logic         start_mont_1, start_mont_2;
    logic         finish_mont_1_w, finish_mont_2_w;
    logic         finish_mont_1_r, finish_mont_2_r;


    ModuloProduct modulo_product(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_start(start_mod_prod),
        .i_n({0,n_r}), // concat 1 bit to MSB since i_n [256:0]
        .i_a({1,{256{1'b0}}}), // a = 2^256
        .i_b({0,a_r}),
        .o_result(result_mod_prod),
        .o_finished(finish_mod_prod_r)
    );

    Mongomery mongomery_1(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_start(start_mont_1),
        .i_a(a_mont_1),
        .i_b(b_mont_1),
        .i_n(i_n),
        .o_result(result_mont_1),
        .o_finished(finish_mont_1_w)
    );

    Mongomery mongomery_2(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_start(start_mont_2),
        .i_a(a_mont_2),
        .i_b(b_mont_2),
        .i_n(i_n),
        .o_result(result_mont_2),
        .o_finished(finish_mont_2_w)
    );

    assign o_finished = finished_w;
    assign o_a_pow_e = ans_w;

    always_comb begin
        state_w = state_r;
        if (state_w == IDLE || state_w == MOD_PROD || state_w == MONT) begin
            finished_w = 0;
            ans_w = 0;
        end else begin // state_w == DONE
            finished_w = 1;
            ans_w = ans_r;
        end
    end

    always_ff @(posedge i_clk or posedge i_rst or posedge i_start) begin
        if (i_rst) begin
            ans_r <= 1;
            state_r <= IDLE;
            finish_mod_prod <= 0;
            k <= 0;
        end else if (i_start) begin
            ans_r <= 1;
            state_r <= MOD_PROD;
            finish_mod_prod <= 0;
            k <= 0;
        end else begin
            if (state_w == IDLE) begin
                // do nothing
            end else if (state_w == MOD_PROD) begin
                start_mod_prod <= 1;
                if (finish_mod_prod == 1) begin
                    state_r <= MONT;
                    t <= result_mod_prod;
                end
            end else if (state_w == MONT) begin
                if (i_e[k] == 1) begin
                    if (finish_mont_1_w == 1) begin
                        ans_r <= result_mont_1;
                        start_mont_1 <= 0;
                        finish_mont_1_r <= 1;
                    end else begin
                        start_mont_1 <= 1;
                        a_mont_1 <= ans_r;
                        b_mont_1 <= t;
                    end
                end else begin
                    finish_mont_1_r <= 1;
                end

                if (finish_mont_2_w == 1) begin
                    ans_r <= result_mont_1;
                    start_mont_1 <= 0;
                    finish_mont_2_r <= 1;
                end else begin
                    start_mont_1 <= 1;
                    a_mont_1 <= ans_r;
                    b_mont_1 <= t;
                end

                if (finish_mont_1_r && finish_mont_2_r) begin
                    if (k == 256) begin
                        state_r <= DONE;
                    end else begin
                        k <= k + 1;
                    end
                    finish_mont_1_r <= 0;
                    finish_mont_2_r <= 0;
                end
            end else begin // state_w == DONE
                state_r <= IDLE;
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

    enum {IDLE, RUN, DONE} state_w, state_r;
    enum {STEP_1, STEP_2} state_mont;
    logic [255:0] ans;
    logic [255:0] result_w, result_r;
    logic         finished_w, finished_r;
    logic [  8:0] k; // counter

    assign o_finished = finished_w;
    assign o_result = result_w;

    always_comb begin
        state_w = state_r;
        if (state_r == IDLE || state_r == RUN) begin
            finished_w = 0;
            result_w = 0;
        end else begin // DONE
            finished_w = finished_r;
            result_w = result_r;
        end
    end

    always_ff @(posedge i_clk or posedge i_rst or posedge i_start) begin
        if (i_rst) begin
            state_r <= IDLE;
            ans <= 0;
            k <= 0;
            state_mont <= STEP_1;
        end else if (i_start) begin 
            state_r <= RUN;
            ans <= 0;
            k <= 0;
            state_mont <= STEP_1;
        end else begin
            if (state_w == IDLE) begin
                // do nothing
            end else begin
                if (k == 256 && state_w == RUN ) begin
                    state_r <= DONE;
                    finished_r <= 1;
                    if (ans >= i_n) begin
                        result_r <= ans - i_n;
                    end else begin
                        result_r <= ans;
                    end
                end else if (k == 256 && state_w == DONE) begin
                    state_r <= IDLE;
                    finished_r <= 0; // turn off finish signal
                    result_r <= 0;
                end else begin
                    if (state_mont == STEP_1) begin
                        if (i_a[k] == 1) begin
                            ans <= ans + i_b;
                        end
                        state_mont <= STEP_2;
                    end else begin
                        if (ans[0] == 1) begin
                            ans <= ans + i_n;
                        end else begin
                            ans <= (ans >> 1);
                        end
                        state_mont <= STEP_1;
                        k <= k + 1;
                    end
                end
            end
        end
    end

endmodule

// calculate a x b mod n
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

    enum {IDLE, RUN, IDLE} state_r, state_w;
    logic [256:0] b;
    logic [256:0] ans;
    logic [  8:0] k; // counter from 0 to 255
    logic [256:0] tmp_1;
    logic [256:0] tmp_2;
    logic [255:0] result_r;
    logic finished_r;

    assign o_finished = finished_r;
    assign o_result = result_r;

    always_comb begin
        state_w = state_r;
        tmp_1 = ans + b;
        tmp_2 = (b << 1);
    end

    always_ff @(posedge i_clk or posedge i_rst or posedge i_start) begin
        if (i_rst || i_start) begin
            if (i_rst) begin 
                state_r <= IDLE;
            end else begin
                state_r <= RUN;
            end
            k <= 0;
            b <= i_b;
            ans <= 0;
            tmp_1 <= 0;
            tmp_2 <= 0;
            finished_r <= 0;
            result_r <= 0;
        end else begin
            if (state_w == RUN) begin
                if (k == 256) begin
                    state_r <= DONE;
                    result_r <= ans[255:0];
                    finished_r <= 1;
                end else begin
                     k <= k + 1; // counter++

                    // ans = (ans + b) mod n = tmp_1 mod n
                    if (i_a[k] == 1) begin
                        if (tmp_1 >= i_n) begin
                            ans <= tmp_1 - i_n;
                        end else begin
                            ans <= tmp_1;
                        end
                    end else begin
                        // do nothing
                    end

                    // b = (b x 2) mod n = tmp_2 mod n
                    if (tmp_2 >= i_n) begin
                        b <= tmp_2 - i_n;
                    end else begin
                        b <= tmp_2;
                    end
                end
            end else begin
                if (state_w == DONE) begin
                    state_r <= IDLE;
                end
                finished_r <= 0;
                result_r <= 0;
            end
        end
    end
endmodule