// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkh(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0x exp=%0x (%s !== %s)\n", `__FILE__,`__LINE__, (gotv), (expv), `"gotv`", `"expv`"); `stop; end while(0);
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t (
    input clk
);

  // These multi-cycle counts are a nonvacuous-attempt oracle.
  initial $assertvacuousoff;

  int cyc;
  reg [63:0] crc;

  // Non-adjacent CRC bits to avoid LFSR shift correlation
  wire a = crc[0];
  wire b = crc[4];
  wire cnd_a = crc[8];
  wire cnd_r = crc[12];
  wire cnd = crc[16];
  wire body = a | b;

  int count_fail1 = 0;
  int count_fail2 = 0;
  int count_fail3 = 0;
  int count_fail4 = 0;
  int count_fail5 = 0;
  int count_fail6 = 0;
  int count_fail7 = 0;
  int count_fail8 = 0;
  int count_fail9 = 0;
  int count_fail10 = 0;
  int multi_pass_pair1 = 0;
  int multi_fail_pair1 = 0;
  int multi_pass_pair2 = 0;
  int multi_fail_pair2 = 0;
  int multi_pass_nested = 0;
  int multi_fail_nested = 0;

  // Test 1: accept_on (async) -- property succeeds when cnd_a fires
  assert property (@(posedge clk) disable iff (cyc < 2) accept_on (cnd_a) body)
  else count_fail1 <= count_fail1 + 1;

  // Test 2: reject_on (async) -- property fails when cnd_r fires
  assert property (@(posedge clk) disable iff (cyc < 2) reject_on (cnd_r) body)
  else count_fail2 <= count_fail2 + 1;

  // Test 3: sync_accept_on -- sampled at matured clocking event
  assert property (@(posedge clk) disable iff (cyc < 2) sync_accept_on (cnd_a) body)
  else count_fail3 <= count_fail3 + 1;

  // Test 4: sync_reject_on
  assert property (@(posedge clk) disable iff (cyc < 2) sync_reject_on (cnd_r) body)
  else count_fail4 <= count_fail4 + 1;

  // Test 5: outer accept_on wraps inner reject_on -- outer wins per 16.12.14
  assert property (@(posedge clk) disable iff (cyc < 2) accept_on (cnd_a) reject_on (cnd_r) body)
  else count_fail5 <= count_fail5 + 1;

  // Test 6: outer reject_on wraps inner accept_on
  assert property (@(posedge clk) disable iff (cyc < 2) reject_on (cnd_r) accept_on (cnd_a) body)
  else count_fail6 <= count_fail6 + 1;

  // Test 7: named property form with accept_on inside
  property p_named;
    accept_on (cnd_a) body;
  endproperty
  assert property (@(posedge clk) disable iff (cyc < 2) p_named)
  else count_fail7 <= count_fail7 + 1;

  // Test 8: disable iff over a sync_accept_on with a second disabled window
  assert property (@(posedge clk) disable iff (cyc < 2 || (cyc >= 50 && cyc < 60))
                   sync_accept_on (cnd) body)
  else count_fail8 <= count_fail8 + 1;

  // Test 9 / 10: async vs sync divergence hook -- identical encoding must
  // produce identical fail counts under current implementation
  assert property (@(posedge clk) disable iff (cyc < 2) accept_on (cnd_a) body)
  else count_fail9 <= count_fail9 + 1;

  assert property (@(posedge clk) disable iff (cyc < 2) sync_accept_on (cnd_a) body)
  else count_fail10 <= count_fail10 + 1;

  // Multi-cycle sync abort forms; accept-forced passes suppressed by $assertvacuousoff.
  assert property (@(posedge clk) sync_accept_on (cnd_a) (a |-> ##1 b)) multi_pass_pair1++;
  else multi_fail_pair1++;

  assert property (@(posedge clk) sync_reject_on (cnd_r) (a |-> b))
  else multi_fail_pair1++;

  assert property (@(posedge clk) sync_accept_on (cnd_a) b) multi_pass_pair2++;
  else multi_fail_pair2++;

  assert property (@(posedge clk) sync_reject_on (cnd_r) (a |-> ##2 b)) multi_pass_pair2++;
  else multi_fail_pair2++;

  assert property (@(posedge clk) sync_accept_on (cnd_a) sync_reject_on (cnd_r) (a |-> b))
    multi_pass_nested++;
  else multi_fail_nested++;

  always @(posedge clk) begin
`ifdef TEST_VERBOSE
    $write("[%0t] cyc==%0d crc=%x body=%b cnd_a=%b cnd_r=%b cnd=%b\n", $time, cyc, crc, body,
           cnd_a, cnd_r, cnd);
`endif
    cyc <= cyc + 1;
    crc <= {crc[62:0], crc[63] ^ crc[2] ^ crc[0]};
    if (cyc == 0) begin
      crc <= 64'h5aef0c8d_d70a4497;
    end
    else if (cyc == 99) begin
      `checkh(crc, 64'hc77bb9b3784ea091);
      `checkd(count_fail1, 14);
      `checkd(count_fail2, 64);  // One other sim: 66
      `checkd(count_fail3, 14);
      `checkd(count_fail4, 64);
      `checkd(count_fail5, 31);
      `checkd(count_fail6, 59);
      `checkd(count_fail7, 14);
      `checkd(count_fail8, 10);
      `checkd(count_fail9, 14);
      `checkd(count_fail10, 14);
      `checkd(multi_pass_pair1, 5);  // Other sims: 42
      `checkd(multi_fail_pair1, 65);  // Other sims: 39
      `checkd(multi_pass_pair2, 24);  // Other sims: 74
      `checkd(multi_fail_pair2, 99);  // Other sims: 73
      `checkd(multi_pass_nested, 7);  // Other sims: 30
      `checkd(multi_fail_nested, 27);  // Other sims: 18
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule
