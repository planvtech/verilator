// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
`define checkh(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got='h%x exp='h%x\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

class A;
  rand int x;
  int v;
  constraint c_lt {x < v;}
endclass

class Multi;
  rand int x;
  rand int y;
  int lo;
  int hi;
  constraint c_x {x >= lo; x <= hi;}
  constraint c_y {y > x;}

  function int self_check;
    return this.randomize(null);
  endfunction
endclass

class Trivial;
  rand int p;
  rand bit [3:0] q;
endclass

class Base;
  rand int x;
  int v;
  constraint c_base {x <= v;}
endclass

class Derived extends Base;
  rand int y;
  constraint c_derived {y > x;}
endclass

class Wide;
  rand bit [64:0] w65;
  rand bit [95:0] w96;
  bit [64:0] lo65;
  bit [95:0] lo96;
  constraint c_wide {w65 >= lo65; w96 >= lo96;}
endclass

class Cyc;
  randc bit [1:0] c;
  bit [1:0] lo;
  constraint c_range {c >= lo;}
endclass

module t;
  A a;
  Multi m;
  Trivial triv;
  Derived d;
  Wide w;
  Cyc cyc;
  int i;
  int ok0;
  int ok1;

  initial begin
    // 1. Original issue reproducer: unsat keeps values, sat preserves them.
    a = new;
    a.x = 2; a.v = 1;
    i = a.randomize(null);
    `checkd(i, 0);
    `checkd(a.x, 2);
    `checkd(a.v, 1);

    a.x = 1; a.v = 2;
    i = a.randomize(null);
    `checkd(i, 1);
    `checkd(a.x, 1);
    `checkd(a.v, 2);

    // 2. Multiple rand members, multiple constraints, plus implicit-this path.
    m = new;
    m.x = 5; m.y = 7; m.lo = 0; m.hi = 10;
    i = m.randomize(null);
    `checkd(i, 1);
    `checkd(m.x, 5);
    `checkd(m.y, 7);

    m.x = -1; m.y = 7; m.lo = 0; m.hi = 10;
    i = m.randomize(null);
    `checkd(i, 0);
    `checkd(m.x, -1);

    m.x = 5; m.y = 5; m.lo = 0; m.hi = 10;
    i = m.randomize(null);
    `checkd(i, 0);
    `checkd(m.y, 5);

    m.x = 3; m.y = 9; m.lo = 0; m.hi = 10;
    i = m.self_check();
    `checkd(i, 1);

    // 3. Class with rand vars and no constraints: always sat, values untouched.
    triv = new;
    triv.p = 42;
    triv.q = 4'h5;
    i = triv.randomize(null);
    `checkd(i, 1);
    `checkd(triv.p, 42);
    `checkh(triv.q, 4'h5);

    // 4. Inheritance: base and derived constraints validated together.
    d = new;
    d.x = 2; d.y = 5; d.v = 10;
    i = d.randomize(null);
    `checkd(i, 1);
    `checkd(d.x, 2);
    `checkd(d.y, 5);

    d.x = 11; d.y = 20; d.v = 10;
    i = d.randomize(null);
    `checkd(i, 0);
    `checkd(d.x, 11);

    d.x = 3; d.y = 1; d.v = 10;
    i = d.randomize(null);
    `checkd(i, 0);
    `checkd(d.y, 1);

    // 5. Wide (65-bit, 96-bit) rand vars: current-value pin must be bit-exact.
    w = new;
    w.w65 = 65'h1_0000_0000_0000_0000;
    w.w96 = 96'hDEAD_BEEF_CAFE_0000_0000_0001;
    w.lo65 = 65'h0_FFFF_FFFF_FFFF_FFFF;
    w.lo96 = 96'h0;
    i = w.randomize(null);
    `checkd(i, 1);
    `checkh(w.w65, 65'h1_0000_0000_0000_0000);
    `checkh(w.w96, 96'hDEAD_BEEF_CAFE_0000_0000_0001);

    w.w65 = 65'h0_1234_5678_9ABC_DEF0;
    w.lo65 = 65'h1_FFFF_FFFF_FFFF_FFFF;
    i = w.randomize(null);
    `checkd(i, 0);
    `checkh(w.w65, 65'h0_1234_5678_9ABC_DEF0);

    // 6. randc: null-call must NOT be poisoned by the exclusion history nor
    //    record values itself; a subsequent real randomize() must still cycle.
    cyc = new;
    cyc.lo = 2'd0;
    repeat (4) begin
      i = cyc.randomize();
      `checkd(i, 1);
    end

    cyc.c = 2'd0; cyc.lo = 2'd0;
    i = cyc.randomize(null);
    `checkd(i, 1);
    `checkd(cyc.c, 2'd0);

    cyc.c = 2'd3; cyc.lo = 2'd0;
    i = cyc.randomize(null);
    `checkd(i, 1);
    `checkd(cyc.c, 2'd3);

    cyc.c = 2'd0; cyc.lo = 2'd1;
    i = cyc.randomize(null);
    `checkd(i, 0);
    `checkd(cyc.c, 2'd0);

    cyc.lo = 2'd0;
    ok0 = 0; ok1 = 0;
    repeat (20) begin
      i = cyc.randomize();
      `checkd(i, 1);
      if (cyc.c == 2'd0) ok0 = 1;
      if (cyc.c == 2'd1) ok1 = 1;
    end
    `checkd(ok0, 1);
    `checkd(ok1, 1);

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
