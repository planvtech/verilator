// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// A lowered NFA action executes in Reactive, after the current clock's NBA
// commits.  $past must nevertheless return the previous sampled value, not the
// just-committed stage of its sampling pipeline.

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0h exp=%0h\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t (
    input clk
);

  bit data = 0;
  bit history[0:4] = '{default: 0};
  int history_count = 0;

  // The current sampled value alternates on every clock.  Because this update
  // is an NBA, a Reactive reader of the first $past pipeline stage would see
  // the current sample and produce the inverse of the expected history.
  always @(posedge clk) data <= ~data;

  assert property (@(posedge clk) 1'b1 ##1 1'b1) begin
    if (history_count < 5) history[history_count] = $past(data);
    history_count++;
  end

  initial begin
    repeat (6) @(negedge clk);
    `checkd(history_count, 5);
    `checkd(history[0], 0);
    `checkd(history[1], 1);
    `checkd(history[2], 0);
    `checkd(history[3], 1);
    `checkd(history[4], 0);
    $write("*-* All Finished *-*\n");
    $finish;
  end

endmodule
