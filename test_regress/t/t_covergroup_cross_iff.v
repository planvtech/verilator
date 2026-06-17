// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// Test 'iff' guard on a covergroup cross (IEEE 1800-2023 19.6): a cross sample is
// collected only when the guard is true.  The crossed coverpoints are not guarded,
// so they sample on every call.  Per-bin hit counts below are confirmed in Questa.

module t;
  logic [1:0] addr;
  logic cmd;
  logic en, mask;

  // Simple iff guard, with en toggled across samples of the same cross bin.
  covergroup cg_iff;
    cp_addr: coverpoint addr {bins addr0 = {0}; bins addr1 = {1};}
    cp_cmd: coverpoint cmd {bins read = {0}; bins write = {1};}
    addr_cmd: cross cp_addr, cp_cmd iff (en);
  endgroup

  // Compound iff guard (exercises the width path for a non-trivial expression).
  covergroup cg_iff2;
    cp_addr: coverpoint addr {bins addr0 = {0}; bins addr1 = {1};}
    cp_cmd: coverpoint cmd {bins read = {0}; bins write = {1};}
    addr_cmd: cross cp_addr, cp_cmd iff (en && !mask);
  endgroup

  cg_iff cg_iff_inst = new;
  cg_iff2 cg_iff2_inst = new;

  initial begin
    // cg_iff: addr0_x_read sampled en=1 then en=0 -> counts only the en=1 hit.
    en = 1;
    addr = 0;
    cmd = 0;
    cg_iff_inst.sample();
    en = 0;
    addr = 0;
    cmd = 0;
    cg_iff_inst.sample();  // gated
    en = 1;
    addr = 1;
    cmd = 1;
    cg_iff_inst.sample();  // addr1_x_write counted
    en = 0;
    addr = 0;
    cmd = 1;
    cg_iff_inst.sample();  // addr0_x_write gated
    en = 0;
    addr = 1;
    cmd = 0;
    cg_iff_inst.sample();  // addr1_x_read gated

    // cg_iff2: only the en=1 && mask=0 sample collects the cross.
    en = 1;
    mask = 0;
    addr = 0;
    cmd = 0;
    cg_iff2_inst.sample();  // counted
    en = 1;
    mask = 1;
    addr = 1;
    cmd = 1;
    cg_iff2_inst.sample();  // gated (mask)
    en = 0;
    mask = 0;
    addr = 0;
    cmd = 1;
    cg_iff2_inst.sample();  // gated (en)
    en = 0;
    mask = 1;
    addr = 1;
    cmd = 0;
    cg_iff2_inst.sample();  // gated

    // Expected cross-bin hits (golden .out), all confirmed against Questa 2022.3:
    //   cg_iff.addr_cmd  : addr0_x_read=1 addr0_x_write=0 addr1_x_read=0 addr1_x_write=1
    //   cg_iff2.addr_cmd : addr0_x_read=1 addr0_x_write=0 addr1_x_read=0 addr1_x_write=0
    // With the iff ignored, every gated sample would also count its cross bin.
    $write("*-* All Finished *-*\n");
    $finish;
  end

endmodule
