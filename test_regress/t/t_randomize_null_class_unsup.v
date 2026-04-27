// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

class Inner;
  rand int x;
  constraint c_in {x > 0;}
endclass

class Outer;
  rand Inner inner;
  rand int y;
  constraint c_out {y > 0;}
endclass

module t;
  initial begin
    automatic Outer o = new;
    o.inner = new;
    void'(o.randomize(null));
  end
endmodule
