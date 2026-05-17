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
  rand int q[$];
  constraint c_size {q.size() == 3;}
endclass

class Derived extends Base;
  constraint c_inc {foreach (q[i]) q[i] == i * 10;}
endclass

module t;

  initial begin
    static Derived d = new();

    repeat (5) begin
      `checkd(d.randomize(), 1)
      `checkd(d.q.size(), 3)
      foreach (d.q[i]) `checkd(d.q[i], i * 10)
    end

    $write("*-* All Finished *-*\n");
    $finish;
  end

endmodule
