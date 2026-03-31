// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t(input clk);
  logic a, b, c;

  // throughout with temporal sequence 'and' (unsupported)
  // (b ##1 c) is a true sequence, so 'and' stays as AstSAnd
  assert property (@(posedge clk)
    a throughout ((b ##1 c) and (c ##1 b)));

endmodule
