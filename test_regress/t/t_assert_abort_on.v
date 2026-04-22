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

  int cyc;
  reg [63:0] crc;

  // Derive signals from non-adjacent CRC bits to avoid LFSR shift correlation
  wire a = crc[0];
  wire b = crc[4];
  wire acond = crc[8];   // accept abort condition (sparse)
  wire rcond = crc[12];  // reject abort condition (sparse)

  int pass1 = 0, fail1 = 0;
  int pass2 = 0, fail2 = 0;
  int pass3 = 0, fail3 = 0;
  int pass4 = 0, fail4 = 0;
  int pass5 = 0, fail5 = 0;
  int pass6 = 0, fail6 = 0;

  // Test 1: async accept_on wraps |->. Pass when acond=1 OR (a implies b).
  assert property (@(posedge clk) accept_on(acond) (a |-> b)) pass1++;
  else fail1++;

  // Test 2: async reject_on wraps |->. Fail when rcond=1 OR (a && !b).
  assert property (@(posedge clk) reject_on(rcond) (a |-> b)) pass2++;
  else fail2++;

  // Test 3: sync_accept_on wraps bare expression b. Pass when $sampled(acond) OR b.
  assert property (@(posedge clk) sync_accept_on(acond) b) pass3++;
  else fail3++;

  // Test 4: sync_reject_on wraps |->. Fail when $sampled(rcond) OR (a && !b).
  assert property (@(posedge clk) sync_reject_on(rcond) (a |-> b)) pass4++;
  else fail4++;

  // Test 5: nested accept_on(acond) reject_on(rcond) (a |-> b).
  // Priority: accept dominates reject (IEEE 1800-2023 16.16 Example 16-23).
  assert property (@(posedge clk) accept_on(acond) reject_on(rcond) (a |-> b))
    pass5++;
  else fail5++;

  // Test 6: negated abort. `not accept_on(c) P` swaps roles (IEEE 1800-2023
  // 16.12.1): accept-firing becomes a FAIL, reject-firing becomes a PASS,
  // and the underlying verdict is the negation of P.
  assert property (@(posedge clk) not accept_on(acond) b) pass6++;
  else fail6++;

  always @(posedge clk) begin
`ifdef TEST_VERBOSE
    $write("[%0t] cyc==%0d a=%b b=%b acond=%b rcond=%b\n",
           $time, cyc, a, b, acond, rcond);
`endif
    cyc <= cyc + 1;
    crc <= {crc[62:0], crc[63] ^ crc[2] ^ crc[0]};
    if (cyc == 0) begin
      crc <= 64'h5aef0c8d_d70a4497;
    end else if (cyc == 99) begin
      `checkh(crc, 64'hc77bb9b3784ea091);
      `checkd(pass1, 84); `checkd(fail1, 16);
      `checkd(pass2, 62); `checkd(fail2, 38);
      `checkd(pass3, 73); `checkd(fail3, 27);
      `checkd(pass4, 41); `checkd(fail4, 59);
      `checkd(pass5, 71); `checkd(fail5, 29);
      `checkd(pass6, 49); `checkd(fail6, 62);
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule
