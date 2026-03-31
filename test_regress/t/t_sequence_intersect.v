// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t (
    input clk
);
  integer cyc = 0;
  logic a, b, c, d, e;

  int seq_pass = 0;
  int bool_pass = 0;
  int diff_pass = 0;

  always_ff @(posedge clk) begin
    cyc <= cyc + 1;
    a <= 1'b0; b <= 1'b0; c <= 1'b0; d <= 1'b0; e <= 1'b0;

    // Scenario 1 (cyc 3-5): both sides match with ##2
    if (cyc == 3) begin a <= 1'b1; c <= 1'b1; end
    if (cyc == 5) begin b <= 1'b1; d <= 1'b1; end

    // Scenario 2 (cyc 8-10): only LHS matches, intersect fails
    if (cyc == 8) a <= 1'b1;
    if (cyc == 10) b <= 1'b1;

    // Scenario 3 (cyc 13-15): different structures, same total delay (2)
    if (cyc == 13) begin a <= 1'b1; d <= 1'b1; end
    if (cyc == 14) b <= 1'b1;
    if (cyc == 15) begin c <= 1'b1; e <= 1'b1; end

    if (cyc == 20) begin
      `checkd(seq_pass, 1);
      `checkd(bool_pass, 1);
      `checkd(diff_pass, 1);
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end

  // Test 1: intersect of two fixed-delay sequences (same ##2)
  assert property (@(posedge clk)
    (a ##2 b) intersect (c ##2 d)
  ) seq_pass++;

  // Test 2: boolean intersect (degenerates to AND)
  assert property (@(posedge clk)
    a intersect c
  ) bool_pass++;

  // Test 3: different internal structure, same total delay
  assert property (@(posedge clk)
    (a ##1 b ##1 c) intersect (d ##2 e)
  ) diff_pass++;

endmodule
