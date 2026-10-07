// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t (
    input clk
);

  bit a = 0;
  bit b = 0;

  property q;
    b;
  endproperty

  cover property (@(posedge clk) a |-> q);

endmodule
