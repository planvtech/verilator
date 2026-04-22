// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t (/*AUTOARG*/
   // Inputs
   clk
   );

   input clk;
   logic [63:0] crc = 64'h5aef0c8dd70a4497;
   logic rst_n = 1'b0;
   logic a, b, c, d, e;
   int   cyc = 0;

   int   hit_simple = 0;
   int   hit_clocked = 0;
   int   hit_clocked_disable = 0;
   int   hit_default_disable = 0;

   default clocking cb @(posedge clk);
   endclocking

   always @(posedge clk) begin
      if (cyc == 2) rst_n <= 1'b1;
      crc <= {crc[62:0], crc[63] ^ crc[2] ^ crc[1] ^ crc[0]};
      cyc <= cyc + 1;
      if (cyc >= 99) begin
         $write("*-* All Finished *-*\n");
         $display("hit_simple=%0d hit_clocked=%0d hit_clocked_disable=%0d hit_default_disable=%0d",
                  hit_simple, hit_clocked, hit_clocked_disable, hit_default_disable);
         // Expect non-zero hits on every counter (non-vacuous match paths).
         if (hit_simple == 0) $stop;
         if (hit_clocked == 0) $stop;
         if (hit_clocked_disable == 0) $stop;
         if (hit_default_disable == 0) $stop;
         $finish;
      end
   end

   assign a = crc[0];
   assign b = crc[5];
   assign c = crc[10];
   assign d = crc[15];
   assign e = crc[20];

   // Form 1: cover sequence ( sexpr ) stmt
   //   -- picks up default clocking, no disable iff
   cover sequence (a | b | c | d | e) hit_simple++;

   // Form 2: cover sequence ( clocking_event sexpr ) stmt
   //   -- explicit clock, bounded range delay
   cover sequence (@(posedge clk) (a | b | c | d | e) ##[1:3] b)
     hit_clocked++;

   // Form 3: cover sequence ( clocking_event disable iff (expr) sexpr ) stmt
   //   -- explicit clock + disable iff
   cover sequence (@(posedge clk) disable iff (!rst_n) a ##1 b)
     hit_clocked_disable++;

   // Form 4: cover sequence ( disable iff (expr) sexpr ) stmt
   //   -- default clocking + disable iff only
   cover sequence (disable iff (!rst_n) a ##1 c)
     hit_default_disable++;

endmodule
