// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// Submodule has default clocking; parent does not. Parent's bare assert
// must not inherit the child's default.

module child(input clk);
  default clocking @(posedge clk); endclocking
endmodule

module t(input clk, input a);
  child u_child(.clk(clk));
  assert property (a);
endmodule
