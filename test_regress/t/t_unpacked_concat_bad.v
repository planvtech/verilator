// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed into the Public Domain, for any use,
// without warranty, 2019 by Driss Hafdi.
// SPDX-License-Identifier: CC0-1.0

module t (/*AUTOARG*/);

   typedef logic [15:0] count_t;
   typedef bit [31:0]   bit_int_t;

   localparam bit_int_t count_bits [1:0] = {2{$bits(count_t)}};
   localparam bit_int_t count_bitsc [1:0] = {$bits(count_t), $bits(count_t)};

   initial begin
      if (count_bits[0] != 16) $stop;
      if (count_bits[1] != 16) $stop;
      if (count_bitsc[0] != 16) $stop;
      if (count_bitsc[1] != 16) $stop;
      $write("*-* All Finished *-*\n");
      $finish;
   end
endmodule
