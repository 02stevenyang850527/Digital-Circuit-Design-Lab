
// CLOCK: 12MHz => 83.33 ns ~= 84 ns
module LCD(
  input        CLK,
  input        RST,
  inout  [7:0] LCD_DATA,
  output       LCD_EN,
  output       LCD_RW,
  output       LCD_RS,
  output       LCD_ON,
  output       LCD_BLON,

  output       READY
);

//=======================================================
//------------Define Basic Instruction Set---------------
//=======================================================

parameter [7:0] CLEAR      = 8'b00000001; // Execution time = 1.53ms, Clear Display
parameter [7:0] ENTRY_N    = 8'b00000110; // Execution time = 39us,   Normal Entry, Cursor increments, Display is not shifted
parameter [7:0] DISPLAY_ON = 8'b00001100; // Execution time = 39us,   Turn ON Display
parameter [7:0] FUNCT_SET  = 8'b00111000; // Execution time = 39us,   sets to 8-bit interface, 2-line display, 5x8 dots

//=======================================================
//--------------Define Timing Parameters-----------------
//=======================================================

parameter [19:0] t_39us     = 465       //39us      ~= 465    clks
parameter [19:0] t_43us     = 512       //43us      ~= 512    clks
parameter [19:0] t_100us    = 1191;     //100us     ~= 1191   clks
parameter [19:0] t_4100us   = 48810;    //4.1ms     ~= 48810  clks
parameter [19:0] t_15000us  = 178572;   //15ms      ~= 178572 clks

always_comb begin

always_ff @(posedge i_clk or negedge i_rst) begin


endmodule