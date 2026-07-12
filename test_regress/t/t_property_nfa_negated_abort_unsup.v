// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

module t (
    input clk
);

  bit a;
  bit b;
  bit abort_cond;

  // Async abort must observe every simulation time step while a multi-cycle
  // attempt is live; the property-clock Observed tick is insufficient.
  assert property (@(posedge clk) accept_on (abort_cond) (a ##1 b));

  // A non-prefix abort needs per-attempt local state termination and priority;
  // a graph-wide overlay cannot preserve multiplicity.
  assert property (@(posedge clk) not (sync_accept_on (abort_cond) (a ##1 b)));

  // Forced accept is vacuous.  Multi-cycle cover needs a separate vacuity-aware
  // cover channel before it can be lowered without misclassifying a hit.
  cover property (@(posedge clk) sync_accept_on (abort_cond) (a ##1 b));

endmodule
