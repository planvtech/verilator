// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// Planner corner shapes: negated liveness pass, single-cycle cover abort, strong cover or

module t (
    input clk
);

  logic a = 0, b = 0, c = 0, x = 0;
  int cyc = 0;

  // verilog_format: off
  assert property (@(posedge clk) not (##[1:$] b)) $display("np");

  cover property (@(posedge clk) accept_on (x) c);

  cover property (@(posedge clk) (s_always [1:2] a) or (s_always [1:2] c));

  assert property (@(posedge clk) ((a ##2 b) or (c ##2 b)) |-> s_always [1:2] a) else $display("sf");
  // verilog_format: on

  always @(posedge clk) begin
    cyc <= cyc + 1;
    if (cyc == 5) begin
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end

endmodule
