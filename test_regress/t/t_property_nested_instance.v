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

  // Non-adjacent CRC bits to avoid LFSR shift correlation
  wire a = crc[0];
  wire b = crc[4];
  wire c = crc[8];

  int count_fail1 = 0;
  int count_fail2 = 0;
  int count_fail3 = 0;
  int count_fail4 = 0;
  int count_fail5 = 0;
  int count_fail6 = 0;
  int count_fail7 = 0;

  property p_b;
    b;
  endproperty

  property p_arg(logic x);
    x;
  endproperty

  property p_outer;
    a |-> p_b;
  endproperty

  // Test 1/2: nested instance under implication vs inline body
  assert property (@(posedge clk) disable iff (cyc < 2) a |-> p_b)
  else count_fail1 <= count_fail1 + 1;

  assert property (@(posedge clk) disable iff (cyc < 2) a |-> b)
  else count_fail2 <= count_fail2 + 1;

  // Test 3/4: nested instance with an argument
  assert property (@(posedge clk) disable iff (cyc < 2) a |-> p_arg(c))
  else count_fail3 <= count_fail3 + 1;

  assert property (@(posedge clk) disable iff (cyc < 2) a |-> c)
  else count_fail4 <= count_fail4 + 1;

  // Test 5/6: nested instance under not
  assert property (@(posedge clk) disable iff (cyc < 2) not p_b)
  else count_fail5 <= count_fail5 + 1;

  assert property (@(posedge clk) disable iff (cyc < 2) not b)
  else count_fail6 <= count_fail6 + 1;

  // Test 7: nested instance inside another property's body, compared with test 2
  assert property (@(posedge clk) disable iff (cyc < 2) p_outer)
  else count_fail7 <= count_fail7 + 1;

  always @(posedge clk) begin
`ifdef TEST_VERBOSE
    $write("[%0t] cyc==%0d crc=%x a=%b b=%b c=%b\n", $time, cyc, crc, a, b, c);
`endif
    cyc <= cyc + 1;
    crc <= {crc[62:0], crc[63] ^ crc[2] ^ crc[0]};
    if (cyc == 0) begin
      crc <= 64'h5aef0c8d_d70a4497;
    end
    else if (cyc == 99) begin
      `checkh(crc, 64'hc77bb9b3784ea091);
      `checkd(count_fail1, 20);
      `checkd(count_fail2, 20);
      `checkd(count_fail3, 24);
      `checkd(count_fail4, 24);
      `checkd(count_fail5, 49);
      `checkd(count_fail6, 49);
      `checkd(count_fail7, 20);
      $write("*-* All Finished *-*\n");
      $finish;
    end
  end
endmodule
