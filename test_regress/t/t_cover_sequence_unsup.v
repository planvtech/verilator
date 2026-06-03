// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t (
    input clk
);

  logic a, b, c;

  default clocking cb @(posedge clk);
  endclocking

  // cover sequence (IEEE 1800-2023 16.18) counts every end-of-match. The
  // following forms have a sub-sequence that itself ends more than once but is
  // consumed by an operator that forwards only its final end, so they are
  // rejected rather than under-counted.

  // 'or' operand with several ends (ranged cycle delay).
  cover sequence ((a ##[1:3] b) or 1'b0);

  // 'or' operand with several ends (consecutive repetition).
  cover sequence ((a [* 1: 3]) or 1'b0);

  // Ranged cycle delay before a multi-cycle sequence (nested-sequence merge).
  cover sequence (a ##[1:2] (b ##1 c));

  // Ranged cycle delay wide enough to use the counter FSM.
  cover sequence (a ##[1:300] b);

endmodule
