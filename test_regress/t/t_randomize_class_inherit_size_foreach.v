// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class Base;
  rand logic [31:0] p_d[];
  constraint c_size {p_d.size() == 4;}
endclass

class Derived extends Base;
  constraint c_inc {foreach (p_d[i]) p_d[i] == i;}
endclass

module t;

  initial begin
    static Derived d = new();

    repeat (5) begin
      `checkd(d.randomize(), 1)
      `checkd(d.p_d.size(), 4)
      foreach (d.p_d[i]) `checkd(d.p_d[i], i)
    end

    $write("*-* All Finished *-*\n");
    $finish;
  end

endmodule
