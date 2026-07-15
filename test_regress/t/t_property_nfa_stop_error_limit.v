// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// A $stop ignored by the runtime error limit must not suppress later evaluation

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t (
    input clk
);

  int cyc = 0;
  int passes = 0;

  assert property (@(posedge clk) 1'b1 ##1 1'b1) passes++;

  initial $stop;

  always @(posedge clk) cyc <= cyc + 1;

  always @(negedge clk) begin
    if (cyc == 9) begin
      `checkd(passes, 9);
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end

endmodule
