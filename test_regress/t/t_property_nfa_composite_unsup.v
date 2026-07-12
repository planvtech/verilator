// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t (
    input clk
);

  bit a;
  bit b;
  bit c;
  bit d;

  // A one-bit merge cannot retain the start-cycle identity of alternatives
  // that finish at different times.
  assert property (@(posedge clk) (a ##1 b) or (c ##2 d));

  // A persistent global doneL/doneR pair can combine arms from different
  // attempts when one arm has an unbounded end.
  cover property (@(posedge clk) (a ##[1:$] b) and (c ##1 d));

  // Flattening repeated impure predicates would evaluate the predicate once
  // per synthetic clone instead of once per sampled expression.
  assert property (@(posedge clk) ((|($random | $random))[*2]) and (1'b1 ##1 1'b1));

  // Fixed-trace synthesis must obey --assert-unroll-limit before allocating an
  // O(N) map/AST.
  assert property (@(posedge clk) (a[*2000]) and (1'b1 ##1 1'b1));

endmodule
