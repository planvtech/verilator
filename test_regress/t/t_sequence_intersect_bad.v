// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t (input clk);
  logic a, b, c, d;

  // Different constant lengths: LHS=1, RHS=3 -- should produce E_UNSUPPORTED
  assert property (@(posedge clk)
    (a ##1 b) intersect (c ##3 d)
  );

endmodule
