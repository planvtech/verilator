// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// NBAs from a Reactive assertion action commit in the same time slot

// verilog_format: off
`define stop $stop
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0h exp=%0h\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0);
// verilog_format: on

module t (
    input clk
);

  int cyc = 0;
  bit a = 1;
  bit b = 0;

  // This variable is deliberately blocking: it gives each execution of the
  // multiplicity loop a distinct ordinal for the NBA RHS and LHS indices.
  int action_ordinal = 0;
  int lhs_index_calls = 0;

  function automatic int next_lhs_index(ref int calls);
    /* verilator no_inline_task */
    next_lhs_index = calls;
    calls++;
  endfunction

  typedef logic [7:0] unpacked_pair_t[0:1];
  logic [7:0] scalar = 8'h80;
  logic [15:0] packed_parts = 16'h0000;
  unpacked_pair_t unpacked_whole = '{8'ha0, 8'hb0};
  unpacked_pair_t whole_first = '{8'h11, 8'h19};
  unpacked_pair_t whole_last = '{8'h22, 8'h2a};
  logic [7:0] unpacked_elements[0:3] = '{default: 8'h00};

  // Targets for Reactive-NBA lowering schemes beyond a simple shadow variable
  logic [15:0] masked_parts = 16'h0000;
  logic [7:0] unique_flag = 8'h00;
  /* verilator lint_off MULTIDRIVEN */
  logic [7:0] mixed_nba = 8'h90;
  logic [15:0] queued_parts[0:1] = '{default: 16'hf000};
  /* verilator lint_on MULTIDRIVEN */
  logic [7:0] second_wave = 8'h00;

  time match_slot_time = 0;
  bit renba_event_seen = 0;
  bit masked_event_seen = 0;
  bit unique_event_seen = 0;
  bit queue_event_seen = 0;

  assert property (@(posedge clk) a ##[1:2] b) begin
    action_ordinal++;

    // Both executions target this scalar.  The last NBA must win.
    scalar <= action_ordinal[7:0];

    // Preserve two distinct partial updates, while the repeated update of the
    // high nibble checks last-NBA-wins for a packed partial select.
    packed_parts[next_lhs_index(lhs_index_calls)*4+:4] <= action_ordinal[3:0];
    packed_parts[15:12] <= 4'h8 + action_ordinal[3:0];

    // Whole unpacked-array NBAs use the last complete value.  Array-valued
    // sources keep this as a whole-array assignment through elaboration.
    if (action_ordinal == 1) unpacked_whole <= whole_first;
    else unpacked_whole <= whole_last;

    // Element NBAs must retain distinct queued updates, and repeated writes to
    // element 3 must commit in source order with the final write winning.
    unpacked_elements[action_ordinal-1] <= 8'h30 + action_ordinal[7:0];
    unpacked_elements[3] <= 8'h40 + action_ordinal[7:0];

    // Mixed blocking/nonblocking updates to disjoint bits select
    // ShadowVarMasked.  The Re-NBA commit must preserve the final low byte.
    masked_parts[7:0] = action_ordinal[7:0];
    masked_parts[15:8] <= 8'h60 + action_ordinal[7:0];

    // Partial unpacked-element updates go through the value/mask commit queue
    queued_parts[(action_ordinal-1)%2][7:0] <= 8'h70 + action_ordinal[7:0];
    queued_parts[1][15:12] <= action_ordinal[3:0];

    // A normal NBA to this target also fires in each match slot.  Re-NBA must
    // win over it, and a later normal-only NBA must not replay stale state.
    mixed_nba <= 8'ha0 + action_ordinal[7:0];

    // The fork makes the whole Reactive process suspendable
    fork
      unique_flag <= 8'h50 + action_ordinal[7:0];
    join
  end

  always @(posedge clk) begin
    cyc <= cyc + 1;
    if (cyc == 0) begin
      a <= 1;
      b <= 0;
    end
    else if (cyc == 1) begin
      a <= 0;
      b <= 1;
    end
    else if (cyc == 3) begin
      a <= 1;
      b <= 0;
    end
    else if (cyc == 4) begin
      a <= 0;
      b <= 1;
    end

    if (cyc == 2) begin
      mixed_nba <= 8'h55;
      match_slot_time = $time;
      // Arguments are evaluated in Postponed, after the assertion's Reactive
      // action and the resulting Re-NBA commits in this same time slot.
      $strobe("RE-NBA scalar=%02x packed=%04x whole=%02x,%02x elems=%02x,%02x,%02x,%02x", scalar,
              packed_parts, unpacked_whole[0], unpacked_whole[1], unpacked_elements[0],
              unpacked_elements[1], unpacked_elements[2], unpacked_elements[3]);
    end
    else if (cyc == 3) begin
      mixed_nba <= 8'h66;
    end
    else if (cyc == 5) begin
      mixed_nba <= 8'h77;
    end
  end

  // Same-slot observation via a process sensitive to the Re-NBA commit
  always @(scalar) begin
    if (scalar == 8'h02) begin
      `checkd($time, match_slot_time);
      `checkd(action_ordinal, 2);
      renba_event_seen = 1;
      // A process awakened by the first Re-NBA wave can enqueue another NBA;
      // that second wave must also drain before this time slot ends.
      second_wave <= scalar + 8'h10;
    end
  end

  always @(second_wave) begin
    if (second_wave == 8'h12) `checkd($time, match_slot_time);
  end

  // Each scheme must commit from Reactive into Re-NBA in the match slot.
  always @(masked_parts) begin
    if (masked_parts == 16'h6202) begin
      `checkd($time, match_slot_time);
      masked_event_seen = 1;
    end
  end

  always @(unique_flag) begin
    if (unique_flag == 8'h52) begin
      `checkd($time, match_slot_time);
      unique_event_seen = 1;
    end
  end

  always @(queued_parts[0] or queued_parts[1]) begin
    if (queued_parts[0] == 16'hf071 && queued_parts[1] == 16'h2072) begin
      `checkd($time, match_slot_time);
      queue_event_seen = 1;
    end
  end

  initial begin
    repeat (3) @(negedge clk);
    `checkd(renba_event_seen, 1);
    `checkd(action_ordinal, 2);
    `checkd(lhs_index_calls, 2);
    `checkd(scalar, 8'h02);
    `checkd(second_wave, 8'h12);
    `checkd(packed_parts, 16'ha021);
    `checkd(unpacked_whole[0], 8'h22);
    `checkd(unpacked_whole[1], 8'h2a);
    `checkd(unpacked_elements[0], 8'h31);
    `checkd(unpacked_elements[1], 8'h32);
    `checkd(unpacked_elements[2], 8'h00);
    `checkd(unpacked_elements[3], 8'h42);
    `checkd(masked_event_seen, 1);
    `checkd(masked_parts, 16'h6202);
    `checkd(unique_event_seen, 1);
    `checkd(unique_flag, 8'h52);
    `checkd(mixed_nba, 8'ha2);
    `checkd(queue_event_seen, 1);
    `checkd(queued_parts[0], 16'hf071);
    `checkd(queued_parts[1], 16'h2072);

    // The Re-NBA event, shadow pending bits, masks, flags, and queues must all
    // be drained before an ordinary NBA in the following slot.
    @(negedge clk);
    `checkd(mixed_nba, 8'h66);

    // A second, independent match proves the event and per-scheme state reset.
    repeat (2) @(negedge clk);
    `checkd(action_ordinal, 3);
    `checkd(lhs_index_calls, 3);
    `checkd(scalar, 8'h03);
    `checkd(packed_parts, 16'hb321);
    `checkd(unpacked_whole[0], 8'h22);
    `checkd(unpacked_whole[1], 8'h2a);
    `checkd(unpacked_elements[2], 8'h33);
    `checkd(unpacked_elements[3], 8'h43);
    `checkd(masked_parts, 16'h6303);
    `checkd(unique_flag, 8'h53);
    `checkd(mixed_nba, 8'ha3);
    `checkd(queued_parts[0], 16'hf073);
    `checkd(queued_parts[1], 16'h3072);
    $write("*-* All Finished *-*\n");
    $finish;
  end

endmodule
