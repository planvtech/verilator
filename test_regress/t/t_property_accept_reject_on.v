// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
`define stop $stop
`define checkd(gotv, expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t (
    input clk
);
  integer cyc = 0;
  reg [63:0] crc = 64'h5aef0c8d_d70a4497;

  // CRC-derived signals. Abort conditions sample a single far-offset bit
  // so the fire rate is ~50% and both pass (accept/reject fires) and fail
  // (body determines outcome) paths are exercised.
  wire a = crc[0];
  wire b = crc[1];
  wire cnd = crc[2];
  wire d = crc[3];
  wire e = crc[4];

  wire abort_accept = crc[12];
  wire abort_reject = crc[24];

  int accept_pass = 0;
  int accept_fail = 0;
  int reject_pass = 0;
  int reject_fail = 0;
  int sync_accept_pass = 0;
  int sync_accept_fail = 0;
  int sync_reject_pass = 0;
  int sync_reject_fail = 0;
  int outer_accept_pass = 0;
  int outer_accept_fail = 0;
  int outer_reject_pass = 0;
  int outer_reject_fail = 0;
  int named_accept_pass = 0;
  int named_accept_fail = 0;
  int disable_accept_pass = 0;
  int disable_accept_fail = 0;
  // Hook for future async vs sync divergence (IEEE 1800-2023 16.16):
  // same body, same abort signal, but one uses sync and one async.
  // Both forms currently collapse to the same per-cycle NFA check; these
  // counters will diverge if the encoding is ever refined, letting this
  // test catch such a regression.
  int async_divergence_pass = 0;
  int async_divergence_fail = 0;
  int sync_divergence_pass = 0;
  int sync_divergence_fail = 0;

  always_ff @(posedge clk) begin
    cyc <= cyc + 1;
    crc <= {crc[62:0], crc[63] ^ crc[2] ^ crc[0]};
    if (cyc == 99) begin
      $write("accept=%0d/%0d reject=%0d/%0d sync_accept=%0d/%0d sync_reject=%0d/%0d\n",
             accept_pass, accept_fail, reject_pass, reject_fail,
             sync_accept_pass, sync_accept_fail, sync_reject_pass, sync_reject_fail);
      $write("outer_accept=%0d/%0d outer_reject=%0d/%0d named=%0d/%0d disable=%0d/%0d\n",
             outer_accept_pass, outer_accept_fail, outer_reject_pass, outer_reject_fail,
             named_accept_pass, named_accept_fail, disable_accept_pass, disable_accept_fail);
      $write("async_div=%0d/%0d sync_div=%0d/%0d\n",
             async_divergence_pass, async_divergence_fail,
             sync_divergence_pass, sync_divergence_fail);
      // Sanity: every CRC-driven counter exercises both pass and fail paths
      // (non-vacuous match required per pattern 23, 24; lesson 17, 33).
      if (!(accept_pass > 0 && accept_fail > 0))
        `stop;
      if (!(reject_pass > 0 && reject_fail > 0))
        `stop;
      if (!(sync_accept_pass > 0 && sync_accept_fail > 0))
        `stop;
      if (!(sync_reject_pass > 0 && sync_reject_fail > 0))
        `stop;
      if (!(outer_accept_pass > 0 && outer_accept_fail > 0))
        `stop;
      if (!(outer_reject_pass > 0 && outer_reject_fail > 0))
        `stop;
      if (!(named_accept_pass > 0 && named_accept_fail > 0))
        `stop;
      if (!(disable_accept_pass > 0 && disable_accept_fail > 0))
        `stop;
      if (!(async_divergence_pass > 0 && async_divergence_fail > 0))
        `stop;
      if (!(sync_divergence_pass > 0 && sync_divergence_fail > 0))
        `stop;
      // Under the current encoding async and sync must match exactly.
      `checkd(async_divergence_pass, sync_divergence_pass)
      `checkd(async_divergence_fail, sync_divergence_fail)
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end

  // Body expression that actually has fails mixed with passes under CRC.
  wire body = a | b;

  // IEEE 1800-2023 16.16 async accept_on: if accept fires at any live step,
  // the property matches regardless of body outcome.
  assert property (@(posedge clk) disable iff (cyc < 2)
    accept_on (abort_accept) body)
    accept_pass++;
  else accept_fail++;

  // IEEE 1800-2023 16.16 async reject_on: if reject fires, property fails.
  assert property (@(posedge clk) disable iff (cyc < 2)
    reject_on (abort_reject) body)
    reject_pass++;
  else reject_fail++;

  // IEEE 1800-2023 16.16 sync_accept_on: sampled at matured clocking event.
  assert property (@(posedge clk) disable iff (cyc < 2)
    sync_accept_on (abort_accept) body)
    sync_accept_pass++;
  else sync_accept_fail++;

  // IEEE 1800-2023 16.16 sync_reject_on.
  assert property (@(posedge clk) disable iff (cyc < 2)
    sync_reject_on (abort_reject) body)
    sync_reject_pass++;
  else sync_reject_fail++;

  // Outer-wraps-inner precedence (IEEE 1800-2023 example 16-23):
  // when both abort conditions fire simultaneously, the outer operator wins.
  assert property (@(posedge clk) disable iff (cyc < 2)
    accept_on (abort_accept) reject_on (abort_reject) body)
    outer_accept_pass++;
  else outer_accept_fail++;

  assert property (@(posedge clk) disable iff (cyc < 2)
    reject_on (abort_reject) accept_on (abort_accept) body)
    outer_reject_pass++;
  else outer_reject_fail++;

  // Named property form: accept_on inside a `property ... endproperty` block.
  property p_named;
    accept_on (abort_accept) body;
  endproperty
  assert property (@(posedge clk) disable iff (cyc < 2) p_named)
    named_accept_pass++;
  else named_accept_fail++;

  // disable iff + sync_accept_on: disable iff kills the assertion entirely
  // before abort fires, matching IEEE priority. Use a simpler disable gate
  // (cyc-based reset window) so both pass and fail paths are exercised.
  assert property (@(posedge clk) disable iff (cyc < 2 || (cyc >= 50 && cyc < 60))
    sync_accept_on (cnd) body)
    disable_accept_pass++;
  else disable_accept_fail++;

  // Async vs sync divergence hook: identical bodies and abort signals under
  // both forms. Currently identical encoding -> counters must match.
  assert property (@(posedge clk) disable iff (cyc < 2)
    accept_on (abort_accept) body)
    async_divergence_pass++;
  else async_divergence_fail++;

  assert property (@(posedge clk) disable iff (cyc < 2)
    sync_accept_on (abort_accept) body)
    sync_divergence_pass++;
  else sync_divergence_fail++;

endmodule
