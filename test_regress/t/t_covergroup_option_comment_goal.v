// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define checkr(gotv,expv) do if ((gotv) != (expv)) begin $write("%%Error: %s:%0d:  got=%f exp=%f\n", `__FILE__,`__LINE__, (gotv), (expv)); $stop; end while(0);
// verilog_format: on

module t;
  logic [2:0] data;

  // Same 50% coverage in both covergroups; only option.goal differs.  Per IEEE
  // 1800-2023 19.11, get_inst_coverage() is independent of option.goal, so both
  // return 50.0; a coverage report uses option.goal to judge cg_hi not-yet-covered
  // (50 < 90) and cg_lo covered (50 >= 40).  option.comment (Table 19-1) is saved
  // in the coverage database for the report.
  covergroup cg_hi;
    option.per_instance = 1;
    option.comment = "high goal group";
    option.goal = 90;
    cp: coverpoint data {bins lo = {[0 : 3]}; bins hi = {[4 : 7]};}
  endgroup

  covergroup cg_lo;
    option.per_instance = 1;
    option.comment = "low goal group";
    option.goal = 40;
    cp: coverpoint data {bins lo = {[0 : 3]}; bins hi = {[4 : 7]};}
  endgroup

  cg_hi cg_hi_inst;
  cg_lo cg_lo_inst;

  initial begin
    cg_hi_inst = new;
    cg_lo_inst = new;
    data = 0;
    cg_hi_inst.sample();  // hits bin lo
    cg_lo_inst.sample();  // hits bin lo
    // 1 of 2 bins -> 50.0% in both (option.goal does not change this value)
    // Questa 2022.3: both get_inst_coverage = 50.000000
    `checkr(cg_hi_inst.get_inst_coverage(), 50.0);
    `checkr(cg_lo_inst.get_inst_coverage(), 50.0);
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
