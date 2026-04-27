// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkh(gotv, expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got='h%x exp='h%x\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
`define checkd(gotv, expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

// IEEE 1800-2023 14.12 / 16.15: default clocking and default disable iff
// must flow into assertions with multi-cycle SVA bodies (SExpr, SThroughout).

// wsn: wsnyder's exact reproducer from verilator/verilator#7472
// (`sva_throughout.sv`), instrumented with a failure counter.
module wsn (
  input clk,
  input a, b, c, d
);
  default clocking @(posedge clk); endclocking
  int fail = 0;
  assert property (
      a |=> b throughout (c ##1 d)
  ) else fail <= fail + 1;
endmodule

// clk_override: explicit-clock override of default clocking.
// Exercises the `if (!propSpecp->sensesp())` guard so explicit `@(edge)`
// still wins -- fix must not replace a user-specified clock.
// (A multi-senitem default clocking like
// `default clocking @(posedge a or posedge b)` would exercise the
// `cloneTree(true)` next-chain copy; Verilator currently rejects that
// shape at the AST layer -- `AstClocking::sensesp` is a single senitem,
// not a list -- so that path is recorded as a known limitation rather
// than tested here.)
module clk_override (
  input clk_default,
  input clk_explicit,
  input a, b, c, d
);
  default clocking @(posedge clk_default); endclocking
  int default_fail = 0;
  int explicit_fail = 0;
  // Uses default clocking (clk_default).
  assert property (a |=> b throughout (c ##1 d))
    else default_fail <= default_fail + 1;
  // Explicit @(posedge clk_explicit) must override the default.
  assert property (@(posedge clk_explicit) a |=> b throughout (c ##1 d))
    else explicit_fail <= explicit_fail + 1;
endmodule

// dgate: `default disable iff` vs explicit `disable iff` override.
// The first assertion inherits default disable; the second overrides with
// `disable iff (1'b0)` (never disabled), so it fires on exactly the
// cycles the default would have masked.
module dgate (
  input clk,
  input rst,
  input a, b, c, d
);
  default clocking @(posedge clk); endclocking
  default disable iff (rst);
  int default_dis_fail = 0;
  int explicit_dis_fail = 0;
  assert property (a |=> b throughout (c ##1 d))
    else default_dis_fail <= default_dis_fail + 1;
  assert property (disable iff (1'b0) a |=> b throughout (c ##1 d))
    else explicit_dis_fail <= explicit_dis_fail + 1;
endmodule

// nodef: negative control -- no default clocking, no default disable.
// Explicit clock on assertion. Fix must not alter this path.
module nodef (
  input clk,
  input a, b, c, d
);
  int fail = 0;
  assert property (@(posedge clk) a |=> b throughout (c ##1 d))
    else fail <= fail + 1;
endmodule

module t (
  input clk
);
  integer cyc = 0;
  reg [63:0] crc = '0;

  wire a = crc[0];
  wire b = crc[4];
  wire c = crc[8];
  wire d = crc[12];

  // Derived alt clock and reset for submodules (test_regress drives only clk).
  wire clk_alt = ~clk;
  wire rst    = (cyc < 10);

  default clocking @(posedge clk); endclocking
  default disable iff (cyc < 10);

  int count_fail1 = 0;
  int count_fail2 = 0;
  int count_fail3 = 0;
  int count_fail4 = 0;

  // Issue #7472 exact shape, inline: default clocking + |=> + throughout +
  // inner multi-cycle sequence (c ##1 d).
  assert property (a |=> b throughout (c ##1 d))
    else count_fail1 <= count_fail1 + 1;

  // Overlapped form -- same NFA default-clocking entry.
  assert property (a |-> b throughout (c ##1 d))
    else count_fail2 <= count_fail2 + 1;

  // Baseline: default clocking + multi-cycle SExpr without throughout.
  assert property (a |=> c ##1 d)
    else count_fail3 <= count_fail3 + 1;

  // Nested throughout under default clocking.
  assert property (a |=> b throughout (c throughout (c ##1 d)))
    else count_fail4 <= count_fail4 + 1;

  // Cover paths: range-delay throughout (mid-source wiring) + non-overlap
  // throughout (cover-specific reject deletion). Confirm they lower without
  // the "Unexpected Call" fatal at V3Clean.
  cover property (a throughout (c ##[1:2] d));
  cover property (a |=> b throughout (c ##1 d));

  // Generate-scope assertion: enclosing module's default clocking must reach
  // assertions inside generate blocks (collectModuleDefaults' module-wide
  // foreach is required for this).
  generate
    if (1) begin : g
      int gen_fail = 0;
      assert property (a |=> b throughout (c ##1 d))
        else gen_fail <= gen_fail + 1;
    end
  endgenerate

  wsn          u_wsn      (.clk(clk), .a(a), .b(b), .c(c), .d(d));
  clk_override u_override (.clk_default(clk), .clk_explicit(clk_alt),
                           .a(a), .b(b), .c(c), .d(d));
  dgate        u_dgate    (.clk(clk), .rst(rst), .a(a), .b(b), .c(c), .d(d));
  nodef        u_nodef    (.clk(clk), .a(a), .b(b), .c(c), .d(d));

  always_ff @(posedge clk) begin
    cyc <= cyc + 1;
    crc <= {crc[62:0], crc[63] ^ crc[2] ^ crc[0]};
    if (cyc == 0) begin
      crc <= 64'h5aef0c8d_d70a4497;
    end else if (cyc == 99) begin
      `checkh(crc, 64'hc77bb9b3784ea091);
      `checkd(count_fail1, 35);  // Questa: 35
      `checkd(count_fail2, 36);  // Questa: 36
      `checkd(count_fail3, 29);  // Questa: 29
      `checkd(count_fail4, 35);  // Questa: 35
      `checkd(u_wsn.fail,                  39);  // Questa: 39 -- wsnyder repro
      `checkd(u_override.default_fail,     39);  // Questa: 39 -- default @posedge clk
      `checkd(u_override.explicit_fail,    39);  // Questa: 39 -- explicit clk_alt (~clk) samples same CRC shift, so count matches
      `checkd(u_dgate.default_dis_fail,    35);  // Questa: 35 -- rst (cyc<10) masks 4 firings
      `checkd(u_dgate.explicit_dis_fail,   39);  // Questa: 39 -- disable iff(1'b0) overrides default, no mask
      `checkd(u_nodef.fail,                39);  // Questa: 39 -- negative control: no default, fix must not affect
      `checkd(g.gen_fail,                  35);  // Questa: 35 -- generate-scope, same shape as count_fail1
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule
