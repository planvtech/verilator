// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

class packet;
   rand bit [7:0] a;
   rand bit [7:0] b;
   constraint c {
      a > 8'd10;
      b < 8'd200;
      a != b;
   }
endclass

module t(/*AUTOARG*/);
   packet p;
   int npass;
   initial begin
      p = new;
      npass = 0;
      for (int i = 0; i < 5; i++) begin
         if (p.randomize() != 0) begin
            if (p.a > 10 && p.b < 200 && p.a != p.b) npass++;
         end
      end
      if (npass == 5) begin
         $write("*-* All Finished *-*\n");
         $finish;
      end
      else begin
         $write("FAILED npass=%0d/5\n", npass);
         $stop;
      end
   end
endmodule
