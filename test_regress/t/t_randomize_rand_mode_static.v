// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
`define check_range(gotv,minv,maxv) do if ((gotv) < (minv) || (gotv) > (maxv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d-%0d\n", `__FILE__,`__LINE__, (gotv), (minv), (maxv)); `stop; end while(0);
// verilog_format: on

// Tests rand_mode() support for `static rand` class members per IEEE 1800-2023
// Section 18.5.10 and Section 18.4. Static rand_mode state is shared across all
// instances of a class.

class Simple;
  static rand int sx;
  rand int dy;
  constraint c {
    sx > 0;
    sx < 12;
    dy > 100;
    dy < 200;
  }
endclass

class Base;
  static rand bit [3:0] base_sx;
  rand bit [3:0] base_dy;
  constraint base_c {
    base_sx > 0;
    base_dy > 0;
  }
endclass

class Derived extends Base;
  rand bit [3:0] der_dy;
  constraint der_c {
    der_dy > 0;
  }
endclass

module t;
  Simple s1, s2;
  Derived d1, d2;
  int saved_sx;
  int saved_dy;
  bit [3:0] saved_base_sx;
  int rok;

  initial begin
    s1 = new;
    s2 = new;

    // ---- Test 1: getter on static rand var (initial state is enabled)
    `checkd(s1.sx.rand_mode(), 1);
    `checkd(s2.sx.rand_mode(), 1);

    // ---- Test 2: randomize() with all rand_modes enabled satisfies constraints
    repeat (20) begin
      rok = s1.randomize();
      `checkd(rok, 1);
      `check_range(Simple::sx, 1, 11);
      `check_range(s1.dy, 101, 199);
    end

    // ---- Test 3: per-member set on a static rand var is shared across instances
    s1.sx.rand_mode(0);
    `checkd(s1.sx.rand_mode(), 0);
    `checkd(s2.sx.rand_mode(), 0);

    // Non-static dy stays independent on each instance
    `checkd(s1.dy.rand_mode(), 1);
    `checkd(s2.dy.rand_mode(), 1);

    // ---- Test 4: solver respects rand_mode(0) on static rand var.
    // sx is currently a valid value from Test 2; with rand_mode disabled it
    // must stay at that value across multiple randomize() calls.
    saved_sx = Simple::sx;
    repeat (20) begin
      rok = s1.randomize();
      `checkd(rok, 1);
      `checkd(Simple::sx, saved_sx);
      `check_range(s1.dy, 101, 199);
    end

    // Re-enable rand_mode for sx via the OTHER instance (sharing test).
    s2.sx.rand_mode(1);
    `checkd(s1.sx.rand_mode(), 1);

    repeat (20) begin
      rok = s1.randomize();
      `checkd(rok, 1);
      `check_range(Simple::sx, 1, 11);
      `check_range(s1.dy, 101, 199);
    end

    // ---- Test 5: class-level obj.rand_mode(0) flushes both per-instance
    // and static arrays. Disable everything on s1.
    s1.rand_mode(0);
    `checkd(s1.sx.rand_mode(), 0);
    `checkd(s1.dy.rand_mode(), 0);
    // Static sx is shared, so s2 sees it disabled too.
    `checkd(s2.sx.rand_mode(), 0);
    // Non-static dy on s2 is independent of s1's class-level call.
    `checkd(s2.dy.rand_mode(), 1);

    // Re-randomize s1 with everything off - both fields unchanged.
    saved_sx = Simple::sx;
    saved_dy = s1.dy;
    repeat (10) begin
      rok = s1.randomize();
      `checkd(rok, 1);
      `checkd(Simple::sx, saved_sx);
      `checkd(s1.dy, saved_dy);
    end

    // Class-level enable resets both arrays to 1.
    s1.rand_mode(1);
    `checkd(s1.sx.rand_mode(), 1);
    `checkd(s1.dy.rand_mode(), 1);
    `checkd(s2.sx.rand_mode(), 1);

    // ---- Test 6: inheritance - static rand var declared in base class,
    // accessed via a derived-class instance.
    d1 = new;
    d2 = new;

    `checkd(d1.base_sx.rand_mode(), 1);

    // Randomize first so base_sx satisfies its constraint, then disable it.
    rok = d1.randomize();
    `checkd(rok, 1);
    if (Base::base_sx == 0) $stop;

    d1.base_sx.rand_mode(0);
    `checkd(d1.base_sx.rand_mode(), 0);
    `checkd(d2.base_sx.rand_mode(), 0);  // Shared via base class

    // Derived class member dy is non-static, independent.
    `checkd(d1.der_dy.rand_mode(), 1);
    `checkd(d2.der_dy.rand_mode(), 1);

    saved_base_sx = Base::base_sx;
    repeat (20) begin
      rok = d1.randomize();
      `checkd(rok, 1);
      `checkd(Base::base_sx, saved_base_sx);  // disabled - unchanged
      if (d1.der_dy == 0) $stop;
      if (d1.base_dy == 0) $stop;
    end

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
