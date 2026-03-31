// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

// IEEE 1800-2023 16.9.9: exp throughout seq
// Test: cond throughout (1'b1 ##3 1'b1) is equivalent to
//   "cond must be true for 4 consecutive ticks (start + 3 delay ticks)".
// Using constant expressions isolates throughout as the sole failure source.

module t;
  logic clk = 0;
  always #5 clk = ~clk;

  logic cond = 1;
  int cyc = 0;
  int pass_count = 0;
  int fail_count = 0;

  always @(posedge clk) begin
    cyc <= cyc + 1;
    case (cyc)
      // Single-cycle cond violation: cond<=0 at cyc 5, visible (sampled) at cyc 6
      // cond<=1 at cyc 6, visible at cyc 7. So cond=0 only at sample tick 6.
      //
      // Assertions spanning tick 6 fail (throughout violation);
      // assertions NOT spanning tick 6 pass.
      5: cond <= 0;
      6: cond <= 1;

      20: begin
        `checkd(pass_count > 0, 1)
        `checkd(fail_count > 0, 1)
        $write("*-* All Finished *-*\n");
        $finish;
      end
    endcase
  end

  assert property (@(posedge clk)
    cond throughout (1'b1 ##3 1'b1))
    pass_count++;
  else fail_count++;

endmodule
