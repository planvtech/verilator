// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// Composite sequence operators the per-attempt count engine cannot lower.

module t (
    input clk
);

  bit a;
  bit b;
  bit c;
  bit d;

  assert property (@(posedge clk) (a ##1 b) or (c ##2 d));

  cover property (@(posedge clk) (a ##[1:$] b) and (c ##1 d));

  assert property (@(posedge clk) ((|($random | $random))[*2]) and (1'b1 ##1 1'b1));

  assert property (@(posedge clk) (a[*2000]) and (1'b1 ##1 1'b1));

endmodule
