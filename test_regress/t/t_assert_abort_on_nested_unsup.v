// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t (
    input clk
);
  logic a, b, c;

  assert property (@(posedge clk) a |-> accept_on (b) c);
  assert property (@(posedge clk) a |-> reject_on (b) c);
  assert property (@(posedge clk) a |-> sync_accept_on (b) c);
  assert property (@(posedge clk) a |-> sync_reject_on (b) c);

endmodule
