// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// $past in 'final' reads the correct stage for on-tick and between-tick ends

module t;

  bit clk = 0;
  bit data = 0;
  bit offedge = 0;

  always #1 clk = ~clk;
  always @(posedge clk) data <= ~data;

  default clocking cb @(posedge clk);
  endclocking

  initial begin
    offedge = $test$plusargs("offedge") != 0;
    if (offedge) #6;
    else #5;
    $write("*-* All Finished *-*\n");
    $finish;
  end

  final begin
    if ($past(data) !== (offedge ? 1'b0 : 1'b1)) begin
      $display("%%Error: wrong $past in final: got=%0b offedge=%0b", $past(data), offedge);
      $stop;
    end
  end

endmodule
