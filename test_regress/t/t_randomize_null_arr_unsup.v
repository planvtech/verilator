// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

class FooQ;
  rand int q[$];
  int x;
  constraint c {x >= 0;}
endclass

class FooU;
  rand int u[3];
  int x;
  constraint c {x >= 0;}
endclass

class FooD;
  rand int d[];
  int x;
  constraint c {x >= 0;}
endclass

class FooA;
  rand int a[string];
  int x;
  constraint c {x >= 0;}
endclass

class FooW;
  rand int w[*];
  int x;
  constraint c {x >= 0;}
endclass

module t;
  initial begin
    automatic FooQ fq = new;
    automatic FooU fu = new;
    automatic FooD fd = new;
    automatic FooA fa = new;
    automatic FooW fw = new;
    void'(fq.randomize(null));
    void'(fu.randomize(null));
    void'(fd.randomize(null));
    void'(fa.randomize(null));
    void'(fw.randomize(null));
  end
endmodule
