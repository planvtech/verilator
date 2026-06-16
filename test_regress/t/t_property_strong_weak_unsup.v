// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t (
    input clk,
    input a,
    input b,
    input c
);
  default clocking @(posedge clk); endclocking

  // strong/weak are only handled as a maximal property operator (top level or
  // implication consequent). As an operand of and/or they are unsupported.
  a1 : assert property ((strong(a ##[1:$] b)) and c);
  a2 : assert property (c or weak(a ##[1:$] b));

  // weak in a cover is not modelled -- gracefully dropped (suppressible).
  c1 : cover property (weak(a ##[1:$] b));
endmodule
