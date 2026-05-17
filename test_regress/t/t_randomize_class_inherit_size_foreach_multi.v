// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class GrandParent;
  rand int arr[];
  constraint c_size {arr.size() == 5;}
endclass

class Parent extends GrandParent;
endclass

class Child extends Parent;
  constraint c_inc {foreach (arr[i]) arr[i] == i + 100;}
endclass

module t;

  initial begin
    static Child c = new();

    repeat (5) begin
      `checkd(c.randomize(), 1)
      `checkd(c.arr.size(), 5)
      foreach (c.arr[i]) `checkd(c.arr[i], i + 100)
    end

    $write("*-* All Finished *-*\n");
    $finish;
  end

endmodule
