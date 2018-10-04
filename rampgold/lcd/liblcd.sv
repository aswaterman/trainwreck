//----------------------------------------------------------------------------
// File:        liblcd.sv
// Author:      Andrew Waterman
// Description: XUPV5-LX110T LCD controller
//----------------------------------------------------------------------------

`timescale 1ns / 1ps

package liblcd;

typedef struct packed
{
  bit [7:4] db;
  bit       rw;
  bit       rs;
  bit       e;
} lcd_pins_t;

endpackage
