
// CLOCK: 12MHz => 83.33 ns ~= 84 ns
module LCD(
  input        i_clk,
  input        i_rst,
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

// time counter
logic [19:0] timer;
logic flag_timer_rst;
logic flag_39us;
logic flag_43us;
logic flag_100us;
logic flag_4100us;
logic flag_15000us;

//=======================================================
//-------------------Define States-----------------------
//=======================================================

enum {INIT, IDLE, RECORD, STOP, PLAY, PAUSE} state_w, state_r;
enum {INIT_1, INIT_2, INIT_3, INIT_4, INIT_5, INIT_6, INIT_7, INIT_8} init_state_w, init_state_r;


//=======================================================
//--------------------Time Counter-----------------------
//=======================================================

always_ff @(posedge i_clk) begin
  if (flag_timer_rst) begin
    timer        <= 20'b0;
    flag_39us    <= 1'b0;
    flag_43us    <= 1'b0;
    flag_100us   <= 1'b0;
    flag_4100us  <= 1'b0;
    flag_15000us <= 1'b0;
  end else begin
    timer <= timer + 1;

    if (timer >= t_39us) begin
      flag_39us <= 1'b1;
    end else begin
      flag_39us <= flag_39us;
    end

    if (timer >= t_43us) begin
      flag_43us <= 1'b1;
    end else begin
      flag_43us <= flag_43us;
    end

    if (timer >= t_100us) begin
      flag_100us <= 1'b1;
    end else begin
      flag_100us <= flag_100us;
    end

    if (timer >= t_4100us) begin
      flag_4100us <= 1'b1;
    end else begin
      flag_4100us <= flag_4100us;
    end

    if (timer >= t_15000us) begin
      flag_15000us <= 1'b1;
    end else begin
      flag_15000us <= flag_15000us;
    end
  end
end


always_comb begin
  case(state_r)
    INIT: begin
      case(init_state_r)
        INIT_1: begin
        end
        INIT_2: begin
        end
        INIT_3: begin
        end
        INIT_4: begin
        end
        INIT_5: begin
        end
        INIT_6: begin
        end
        INIT_7: begin
        end
        INIT_8: begin
        end
    end

    IDLE: begin
    end

    RECORD: begin
    end
    
    STOP: begin
    end
    
    PLAY: begin
    end
    
    PAUSE: begin
    end
end

always_ff @(posedge i_clk or posedge i_rst) begin
  if (i_rst) begin
    state_r      <= INIT;
    init_state_r <= INIT_1;
    flag_timer_rst <= 1'b1;
  end
end



endmodule