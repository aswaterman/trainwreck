//----------------------------------------------------------------------------
// File:        lcd.sv
// Author:      Andrew Waterman
// Description: XUPV5-LX110T LCD controller
//----------------------------------------------------------------------------

`timescale 1ns / 1ps

import liblcd::*;
import libstd::*;
import libconf::*;

module lcd_base
(
  input  bit         clk,
  input  bit         rst,
  input  bit [7:0]   write_byte,
  input  bit         write_en,
  input  bit         write_special,
  output bit         busy,
  output lcd_pins_t  lcd_pins
);

  `ifdef MODEL_TECH
    parameter int LCD_DELAY = 3;
  `else
    parameter int LCD_DELAY = 2000; // 2 ms delay between some LCD ops
  `endif
  parameter int CLOCKS_PER_USEC = int'(1000*CLKMUL/(CLKIN_PERIOD*CLKDIV));

  typedef enum { init0, init1, init2, init3, init4, init5, init6, init7, ready,
                 write_nibble, write_nibble_clk, wait_for_ctr } state_t;
  logic [3:0] r_state, v_state, r_wait_for_ctr_state, v_wait_for_ctr_state;
  lcd_pins_t v_lcd_pins, r_lcd_pins;
  logic v_which_nibble, r_which_nibble;
  logic [log2x(LCD_DELAY*CLOCKS_PER_USEC)-1:0] v_ctr, r_ctr;
  logic [7:0] r_write_byte;

  always_comb begin
    v_state = 'x;
    v_wait_for_ctr_state = r_wait_for_ctr_state;
    v_which_nibble = r_which_nibble;
    v_ctr = r_ctr-1;
    v_lcd_pins = r_lcd_pins;

    case(r_state)
      init0: begin
        v_lcd_pins.rw = 0;
        v_lcd_pins.rs = 0;
        v_lcd_pins.e = 0;
        v_lcd_pins.db = 0;
        v_ctr = LCD_DELAY*CLOCKS_PER_USEC;
        v_state = wait_for_ctr;
        v_wait_for_ctr_state = init1;
      end
      init1: begin
        v_lcd_pins.db[5] = 1;
        v_ctr = CLOCKS_PER_USEC;
        v_state = wait_for_ctr;
        v_wait_for_ctr_state = init2;
      end
      init2, init3, init4, init5, init6, init7: begin
        v_lcd_pins.e = !r_lcd_pins.e; // toggle clock 6 times
        v_ctr = r_state == init7 ? LCD_DELAY*CLOCKS_PER_USEC : CLOCKS_PER_USEC;
        v_state = wait_for_ctr;
        v_wait_for_ctr_state = r_state+1;
      end
      ready: begin
        if(write_en) begin
          v_lcd_pins.rs = !write_special;
          v_state = r_lcd_pins.rs != v_lcd_pins.rs ? wait_for_ctr:write_nibble;
        end else
          v_state = ready;
        v_ctr = CLOCKS_PER_USEC;
        v_which_nibble = 1;
        v_wait_for_ctr_state = write_nibble;
      end
      write_nibble: begin
        v_lcd_pins.db = r_which_nibble ? r_write_byte[7:4] : r_write_byte[3:0];
        v_state = wait_for_ctr;
        v_ctr = CLOCKS_PER_USEC;
        v_wait_for_ctr_state = write_nibble_clk;
      end
      write_nibble_clk: begin
        v_lcd_pins.e = !r_lcd_pins.e;
        v_ctr = LCD_DELAY*CLOCKS_PER_USEC; // could be faster if not clearing
        if(r_lcd_pins.e)
          v_which_nibble = 0;
        v_state = wait_for_ctr;
        v_wait_for_ctr_state = !r_lcd_pins.e ? write_nibble_clk :
                                 (r_which_nibble ? write_nibble : ready);
      end
      wait_for_ctr:
        v_state = r_ctr == 0 ? r_wait_for_ctr_state : wait_for_ctr;
    endcase

    if(rst)
      v_state = init0;
  end

  always_ff @(posedge clk) begin
    r_lcd_pins <= v_lcd_pins;
    r_ctr <= v_ctr;
    r_state <= v_state;
    r_wait_for_ctr_state <= v_wait_for_ctr_state;
    if(write_en)
      r_write_byte <= write_byte;
    r_which_nibble <= v_which_nibble;
  end

  assign busy = r_state != ready;
  assign lcd_pins = r_lcd_pins;

endmodule

// LCD controller.
// When busy=0, assert write_en to write write_data to the LCD.
// Write 0xFF to clear the LCD.  To move character positions,
// use write_data = { 1, line_num, 0, 0, column_num }.
module lcd_ctrl
(
  input  bit         clk,
  input  bit         rst,

  output bit         rdy,
  input  bit         val,
  input  bit [7:0]   bits,

  output lcd_pins_t  lcd_pins
);

  bit clear;
  bit[1:0] r_pos;
  bit lcd_busy, lcd_write_en, lcd_write_special;
  bit [7:0] r_write_byte, lcd_write_byte;

  typedef enum { ready, normal_write, clear_write, normal_wait, clear_wait,
                 reset } lcd_state_t;
  lcd_state_t v_state,r_state;

  lcd_base mylcd(.*,.write_byte(lcd_write_byte),.write_en(lcd_write_en),
                 .write_special(lcd_write_special),.busy(lcd_busy));

  always_comb begin
    clear = bits == '1;

    case(r_pos)
      0:  lcd_write_byte = 8'h28;
      1:  lcd_write_byte = 8'h0C;
      2:  lcd_write_byte = 8'h06;
      3:  lcd_write_byte = 8'h01;
      default: lcd_write_byte = 'x;
    endcase

    case(r_state)
      ready: v_state = clear && val ? clear_write : (val ? normal_write : ready);
      reset: v_state = clear_write;
      normal_write: v_state = normal_wait;
      clear_write: v_state = clear_wait;
      clear_wait: v_state = lcd_busy ? clear_wait : (r_pos ? clear_write:ready);
      normal_wait: v_state = lcd_busy ? normal_wait : ready;
      default: v_state = lcd_state_t'('x);
    endcase

    rdy = r_state == ready;
    lcd_write_en = r_state == normal_write || r_state == clear_write;
    lcd_write_special = r_state == clear_write || r_write_byte[7];
    if(r_state == normal_write)
      lcd_write_byte = r_write_byte;
  end

  always_ff @(posedge clk) begin
    if(rst)
      r_pos <= 0;
    else if(r_state == clear_write)
      r_pos <= r_pos+1;

    if(rst)
      r_state <= reset;
    else
      r_state <= v_state;

    if(rdy)
      r_write_byte <= bits;

    //synthesis translate_off
    if(rdy && val)
      $display("lcd write %c",bits);
    //synthesis translate_on
  end

endmodule

module lcd_test
(
  input  bit         clk,
  input  bit         rst,
  output lcd_pins_t  lcd_pins
);

  parameter int msglen = 22;

  bit r_done, rdy, val;
  bit[log2x(msglen)-1:0] r_pos;
  bit[7:0] bits;

  always_comb begin
    case(r_pos)
       0: bits = "H";
       1: bits = "e";
       2: bits = "l";
       3: bits = "l";
       4: bits = "o";
       5: bits = " ";
       6: bits = "f";
       7: bits = "r";
       8: bits = "o";
       9: bits = "m";
      10: bits = "\n";
      11: bits = "M";
      12: bits = "i";
      13: bits = "d";
      14: bits = "a";
      15: bits = "s";
      16: bits = " ";
      17: bits = "F";
      18: bits = "A";
      19: bits = "M";
      20: bits = "E";
      21: bits = "\n";
      default: bits = 'x;
    endcase
  end

  assign val = !r_done;

  lcd_ctrl mylcd(.*);

  always_ff @(posedge clk) begin
    if(rst) begin
      r_done <= 0;
      r_pos <= 0;
    end else if(val && rdy) begin
      r_done <= (r_pos == msglen-1);
      r_pos <= r_pos+1;
      $display("write %x",bits);
    end
  end

endmodule
