mescale 1ns/100ps

module tb;
    localparam CLK = 10;
    localparam HCLK = CLK/2;

    logic clk, sta, fin, rst, sclk;
    wire sdat;
    logic [1:0] state;
    initial clk = 0;
    always #HCLK clk = ~clk;

    I2Csender core(
        .i_clk(clk),
        .i_rst(rst),
        .i_data(24'h890abc),
        .i_start(sta),
        .o_finished(fin),
        .o_scl(sclk),
        .o_sda(sdat)
    );

    initial begin
        $fsdbDumpfile("lab3_i2c.fsdb");
        $fsdbDumpvars;
        rst = 1;
        #(2*CLK)
        rst = 0;
        #(2*CLK)
        //rst = 1;
        for (int j = 0; j < 3; j++) begin
            @(posedge clk);
        end
        sta <= 1;
        @(posedge clk)
        sta <= 0;
        @(posedge fin)
        // again
        @(posedge clk)
        sta <= 1;
        @(posedge clk)
        sta <= 0;
        @(posedge fin)
        #(10*CLK)
        $finish;
    end

    initial begin
        #(300*CLK)
        $display("Too slow, abort.");
        $finish;
    end

endmodule
