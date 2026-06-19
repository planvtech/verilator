// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define check_ok(gotv) do if ((gotv) !== 1) begin $write("%%Error: %s:%0d:  randomize() failed\n", `__FILE__,`__LINE__); `stop; end while(0);
`define check_range(gotv,minv,maxv) do if ((gotv) < (minv) || (gotv) > (maxv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d-%0d\n", `__FILE__,`__LINE__, (gotv), (minv), (maxv)); `stop; end while(0);
// verilog_format: on

// A solve...before that names an associative array pulls the array into a phased
// solving layer. The solver returns the whole-array model `((as const ...) ...)`
// for the bare array symbol, which used to desync the persistent solver pipe and
// make every following randomize() in the process fail. Check that the array is
// solved within its constraints and that an unrelated object randomized right
// afterwards keeps succeeding (i.e. the pipe is not poisoned).

module t;

  /* verilator lint_off SIDEEFFECT */
  class Cfg;
    rand int unsigned tbl[string];
    rand int unsigned sel;
    constraint c {
      sel inside {[5:100]};
      foreach (tbl[k]) tbl[k] inside {[5:100]};
      solve tbl before sel;
    }
    function new();
      tbl["a"] = 0;
      tbl["b"] = 0;
      tbl["c"] = 0;
    endfunction
  endclass
  /* verilator lint_on SIDEEFFECT */

  class Victim;
    rand int unsigned val;
    constraint c {val inside {[5:100]};}
  endclass

  Cfg cfg;
  Victim vic;
  int ok;
  int unsigned prev;
  bit varied;

  initial begin
    cfg = new();
    vic = new();
    prev = 0;
    varied = 0;
    for (int i = 0; i < 20; i++) begin
      ok = cfg.randomize();
      `check_ok(ok)
      `check_range(cfg.sel, 5, 100)
      foreach (cfg.tbl[k]) `check_range(cfg.tbl[k], 5, 100)
      // The unrelated follow-on randomize must still succeed every iteration.
      ok = vic.randomize();
      `check_ok(ok)
      `check_range(vic.val, 5, 100)
      if (i > 0 && vic.val != prev) varied = 1;
      prev = vic.val;
    end
    // A poisoned pipe leaves the victim stuck at a single fallback value.
    if (!varied) begin
      $write("%%Error: %s:%0d:  victim did not vary -- solver pipe desynced\n", `__FILE__,
             `__LINE__);
      $stop;
    end
    $write("*-* All Finished *-*\n");
    $finish;
  end

endmodule
