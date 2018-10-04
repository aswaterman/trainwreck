// fpu_recoded.vh -- Common definitions for the recoded FPU blocks.
// Author: Brian Richards, 10/31/2010

`ifndef _fpu_recoded_vh
`define _fpu_recoded_vh

// Rounding modes:
`define round_nearest_even 2'b00
`define round_minMag       2'b01
`define round_min          2'b10
`define round_max          2'b11

// Integer type codes:
`define type_uint32        2'b00
`define type_int32         2'b01
`define type_uint64        2'b10
`define type_int64         2'b11

// FPU data type codes:
`define fpu_type_f32       3'b000
`define fpu_type_f64       3'b001
`define fpu_type_uint32    3'b100
`define fpu_type_int32     3'b101
`define fpu_type_uint64    3'b110
`define fpu_type_int64     3'b111

// synopsys translate_off
// Debugging C routine
//extern "C" void readHex_ui8_sp( output bit [31:0] );
//extern "C" void readHex_ui8_n( output bit [31:0] );
//extern "C" void readHex_ui32_sp( output bit [31:0] );
//extern "C" void readHex_ui32_n( output bit [31:0] );
//extern "C" void readHex_ui64_sp( output bit [63:0] );
//extern "C" void readHex_ui64_n( output bit [63:0] );
//extern "C" void writeHex_ui8_sp( input bit [31:0] );
//extern "C" void writeHex_ui8_n( input bit [31:0] );
//extern "C" void writeHex_ui32_sp( input bit [31:0] );
//extern "C" void writeHex_ui32_n( input bit [31:0] );
//extern "C" void writeHex_ui64_sp( input bit [63:0] );
//extern "C" void writeHex_ui64_n( input bit [63:0] );

// synopsys translate_on
`endif // _fpu_recoded_vh_
