// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// verilog_format: off
module t (
    input clk
);
  reg [15:0] lfsr;
  logic req = 0, ack = 0;

  default clocking @(posedge clk); endclocking

  // strong(seq): an attempt still pending at end-of-trace is a failure.
  // weak(seq): no end-of-trace obligation (IEEE 1800-2023 16.12.2).
  // Use $display (not $write): a strong end-of-trace failure fires in the final
  // time step, where $write output is buffered and dropped at $finish.
  as_strong : assert property (req |-> strong(##[1:$] ack)) else $display("strong fail");
  as_weak   : assert property (req |-> weak(##[1:$] ack))   else $display("weak fail");

  initial begin
    lfsr = 16'hACE1;
    // LFSR-random req with frequent ack: every started attempt is eventually
    // acked, so strong and weak both pass (no failures fire).
    for (int i = 0; i < 30; i++) begin
      @(posedge clk);
      req <= lfsr[0];
      ack <= lfsr[3] | lfsr[7] | lfsr[11];
      lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end
    // Drain: ack high clears every still-pending attempt.
    repeat (3) begin
      @(posedge clk);
      req <= 0;
      ack <= 1;
    end
    // One req, never acked -> strong fails at end-of-trace, weak passes.
    @(posedge clk);
    req <= 1;
    ack <= 0;
    @(posedge clk);
    req <= 0;
    repeat (5) @(posedge clk);
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
