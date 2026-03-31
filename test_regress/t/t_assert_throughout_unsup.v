// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t(input clk);
  logic a, b, c;

  // throughout with range delay sequence (unsupported)
  assert property (@(posedge clk)
    a throughout (b ##[1:2] c));

  // throughout with complex sequence operator (unsupported)
  assert property (@(posedge clk)
    a throughout (b and c));

endmodule
