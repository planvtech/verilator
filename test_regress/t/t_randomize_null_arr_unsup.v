// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

class Foo;
  rand int q[$];
  int x;
  constraint c {x >= 0;}
endclass

module t;
  initial begin
    automatic Foo foo = new;
    void'(foo.randomize(null));
  end
endmodule
