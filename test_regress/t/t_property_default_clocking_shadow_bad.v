// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// Boundary: parent has no default clocking; submodule does.
// Module-scoped scan in V3AssertNfa::collectModuleDefaults must not
// pick up the child's default. Parent's unclocked assertion must error.
//
// IEEE 1800-2023 16.14.5: a concurrent assertion begins evaluation "at every
// occurrence of its leading clock event" -- a clock is required. 16.6 spells
// out the failure mode: "It shall be an error if the clock is required, but
// cannot be inferred in the instantiation context." 16.14.6's example
// "a1: assert(($past(a))); // Illegal: no clock can be inferred" applies
// the same rule. Verilator emits a hard `%Error:` here. Questa 2022.3 also
// rejects: vlog-1957 (suppressible) at compile, then vsim-8299 "Use of
// unclocked directive ... is illegal" at design load.

module child(input clk);
  default clocking @(posedge clk); endclocking
endmodule

module t(input clk, input a, b);
  child u_child(.clk(clk));
  // Single-cycle boolean -- a multi-cycle SExpr here would also surface a
  // pre-existing unclocked-SExpr ICE unrelated to #7472. Boolean is enough
  // to confirm the parent does not pick up the child module's default.
  assert property (a |=> b);
endmodule
