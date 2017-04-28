
// CLOCK: 12MHz => 83.33 ns ~= 84 ns
module LCD(
  input        i_clk,
  input        i_rst,
  // LCD module connection
  inout  [7:0] LCD_DATA,
  output       LCD_EN,
  output       LCD_RW,
  output       LCD_RS,
  output       LCD_ON,
  output       LCD_BLON,
  // self designed inout
  input        INPUT_STATE,
  output       READY
);

//=======================================================
//-----------------Default Assumption--------------------
//=======================================================

// Turn LCD ON
assign LCD_ON   = 1'b1;
// LCD modules used on DE2-115 boards do not have backlight.
assign LCD_BLON = 1'b0;

//=======================================================
//------------Define Basic Instruction Set---------------
//=======================================================

parameter [7:0] ZERO        = 8'b00000000; // zeros
parameter [7:0] CLEAR       = 8'b00000001; // Execution time = 1.53ms, Clear Display
parameter [7:0] ENTRY_N     = 8'b00000110; // Execution time = 39us,   Normal Entry, Cursor increments, Display is not shifted
parameter [7:0] DISPLAY_ON  = 8'b00001100; // Execution time = 39us,   Turn ON Display
parameter [7:0] FUNCT_SET   = 8'b00111000; // Execution time = 39us,   sets to 8-bit interface, 2-line display, 5x8 dots

//=======================================================
//--------------Define Timing Parameters-----------------
//=======================================================

parameter [19:0] t_39us     = 465;      //39us      ~= 465    clks
parameter [19:0] t_43us     = 512;      //43us      ~= 512    clks
parameter [19:0] t_100us    = 1191;     //100us     ~= 1191   clks
parameter [19:0] t_1530us   = 18215;    //1.53ms    ~= 18215  clks
parameter [19:0] t_4100us   = 48810;    //4.1ms     ~= 48810  clks
parameter [19:0] t_15000us  = 178572;   //15ms      ~= 178572 clks

// time counter and flags
logic [19:0] timer_w, timer_r;
logic flag_timer_rst_w, flag_timer_rst_r;
logic flag_39us;
logic flag_43us;
logic flag_100us;
logic flag_1530us;
logic flag_4100us;
logic flag_15000us;

//=======================================================
//-------------------Define States-----------------------
//=======================================================

// LCD Module States
enum {INIT, IDLE, RECORD, STOP, PLAY, PAUSE} state_w, state_r;
enum {SUB_1, SUB_2, SUB_3, SUB_4, SUB_5, SUB_6, SUB_7, SUB_8} substate_w, substate_r;
enum {SHOW_NOTHING, SHOW_READY, SHOW_RECORD, SHOW_STOP, SHOW_PLAY, SHOW_PAUSE} show_state_w, show_state_r;

// INPUT_STATE ( input from Top module in Top.sv )
parameter [2:0] INPUT_INIT   = 3'b000;
parameter [2:0] INPUT_IDLE   = 3'b001;
parameter [2:0] INPUT_RECORD = 3'b010;
parameter [2:0] INPUT_STOP   = 3'b011;
parameter [2:0] INPUT_PLAY   = 3'b100;
parameter [2:0] INPUT_PAUSE  = 3'b101;


//=======================================================
//--------------------Time Counter-----------------------
//=======================================================

always_comb begin
  if (flag_timer_rst_r) begin
    timer_w      = 20'b0;
    flag_39us    = 1'b0;
    flag_43us    = 1'b0;
    flag_100us   = 1'b0;
    flag_1530us  = 1'b0;
    flag_4100us  = 1'b0;
    flag_15000us = 1'b0;
  end else begin
    timer_w = timer_r + 1;

    if (timer_r >= t_39us) begin
      flag_39us = 1'b1;
    end else begin
      flag_39us = flag_39us;
    end

    if (timer_r >= t_43us) begin
      flag_43us = 1'b1;
    end else begin
      flag_43us = flag_43us;
    end

    if (timer_r >= t_100us) begin
      flag_100us = 1'b1;
    end else begin
      flag_100us = flag_100us;
    end

    if (timer_r >= t_1530us) begin
      flag_1530us = 1'b1;
    end else begin
      flag_1530us = flag_1530us;
    end

    if (timer_r >= t_4100us) begin
      flag_4100us = 1'b1;
    end else begin
      flag_4100us = flag_4100us;
    end

    if (timer_r >= t_15000us) begin
      flag_15000us = 1'b1;
    end else begin
      flag_15000us = flag_15000us;
    end
  end
end

//=======================================================
//--------------------State Machine----------------------
//=======================================================

always_comb begin
  case(state_r)
//------------------------INIT---------------------------
    INIT: begin
      case(substate_r)
        SUB_1: begin // wait 15ms after Vcc rises to 4.5V
          LCD_DATA = 8'b0;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_15000us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_2;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_2: begin // wait for more than 4.1ms
          LCD_DATA = FUNCT_SET;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_4100us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_3;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_3: begin // wait for more than 100us
          LCD_DATA = FUNCT_SET;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_100us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_4;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_4: begin // Function Set, wait for 39us
          LCD_DATA = FUNCT_SET;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_39us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_5;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_5: begin // Display On, wait for 39us
          LCD_DATA = DISPLAY_ON;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_39us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_6;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_6: begin // Display Clear, wait for 1.53ms
          LCD_DATA = CLEAR;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_1530us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_7;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_7: begin // Entry Mode Set, wait for 39us
          LCD_DATA = ENTRY_N;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          if (!flag_39us) begin
            substate_w = substate_r;
            flag_timer_rst_w = 1'b0;
          end else begin
            substate_w = SUB_8;
            flag_timer_rst_w = 1'b1;
          end
        end

        SUB_8: begin // goto state IDLE
          LCD_DATA = ZERO;
          LCD_EN   = 1'b0;
          LCD_RW   = 1'b0;
          LCD_RS   = 1'b0;
          READY    = 1'b0;
          state_w  = IDLE;
          substate_w = SUB_1;
          flag_timer_rst_w = 1'b1;
        end
      endcase
    end

//------------------------IDLE---------------------------
    IDLE: begin
      READY = 1'b1;
      case(INPUT_STATE)
        INPUT_INIT: begin
          state_w          <= INIT;
          substate_w       <= SUB_1;
          flag_timer_rst_w <= 1'b1;
        end

        INPUT_IDLE: begin
          state_w          <= state_r;
          substate_w       <= substate_r;
          flag_timer_rst_w <= flag_timer_rst_r;
        end

        INPUT_RECORD: begin
          state_w          <= RECORD;
          substate_w       <= SUB_1;
          flag_timer_rst_w <= 1'b1;
        end

        INPUT_STOP: begin
          state_w          <= STOP;
          substate_w       <= SUB_1;
          flag_timer_rst_w <= 1'b1;
        end

        INPUT_PLAY: begin
          state_w          <= PLAY;
          substate_w       <= SUB_1;
          flag_timer_rst_w <= 1'b1;
        end

        INPUT_PAUSE: begin
          state_w          <= PAUSE;
          substate_w       <= SUB_1;
          flag_timer_rst_w <= 1'b1;
        end
      endcase
    end

//-----------------------RECORD--------------------------
    RECORD: begin
    end
//------------------------STOP---------------------------
   
    STOP: begin
    end
//------------------------PLAY---------------------------
    
    PLAY: begin
    end
//-----------------------PAUSE---------------------------
    
    PAUSE: begin
    end
  endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
  if (i_rst) begin
    timer_r          <= 10'b0;
    state_r          <= INIT;
    substate_r       <= SUB_1;
    flag_timer_rst_r <= 1'b1;
  end else begin
    timer_r          <= timer_w;
    state_r          <= state_w;
    substate_r       <= substate_w;
    flag_timer_rst_r <= flag_timer_rst_w;
  end
end



endmodule